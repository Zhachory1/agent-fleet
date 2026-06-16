#!/usr/bin/env bash
# Test suite for lib/blind-judge.sh. Covers PLAN Rev 2 Chunks 2, 3, 4 (prepare, parser fixtures,
# record/judge/concurrency). Transcript distinct-rendering (Chunk 7) is exercised here too as a
# round-trip check that the @@from: blind-judge#judge-N line is correctly written.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIXDIR="$DIR/test/fixtures/blind-judge"

fail=0
note() { printf '  %s\n' "$*"; }
expect_pass() { local name="$1" cmd="$2"; if eval "$cmd" >/dev/null 2>&1; then note "PASS $name"; else note "FAIL $name"; fail=1; fi; }
expect_fail_msg() {
  local name="$1" cmd="$2" expected="$3"
  local out rc
  set +e; out=$(eval "$cmd" 2>&1); rc=$?; set -e
  if [ "$rc" -eq 0 ]; then note "FAIL $name (expected nonzero exit, got 0)"; fail=1; return; fi
  if grep -qF "$expected" <<<"$out"; then note "PASS $name"; else note "FAIL $name (missing '$expected' in: $out)"; fail=1; fi
}

# Test temp-dir tracking: mktemp_d() creates a dir under a per-test parent so the trap
# can rm -rf the whole parent in one shot. Avoids subshell-pollution issues (subshell
# appends to an array don't escape; we use a directory-tree approach instead).
TEST_PARENT_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_PARENT_TMP"' EXIT
mktemp_d() { mktemp -d "$TEST_PARENT_TMP/d.XXXXXX"; }

# Set up isolated env
AGENT_CHAT_ROOT="$(mktemp_d)"; export AGENT_CHAT_ROOT
AGENT_FLEET_JOURNAL="$(mktemp_d)/j.jsonl"; export AGENT_FLEET_JOURNAL
ROOM=council-prepare-test
mkdir -p "$AGENT_CHAT_ROOT/rooms/$ROOM"
echo "diff text here" > "$AGENT_CHAT_ROOT/rooms/$ROOM/artifact.txt"

bash "$DIR/lib/transcript.sh" capture "$ROOM" <<EOF >/dev/null
@@from: ml-scientist#r1
verdict: BLOCK
- [BLOCKER] train/serve skew
@@from: synthesis
Council verdict: BLOCK
1. [BLOCKER] train/serve skew
EOF
bash "$DIR/lib/journal.sh" append "$ROOM" "prepare-test" "ship as-is" "ml-scientist" \
  true "" true 0 false null 1 design --synthesis-word-count 7 >/dev/null

echo "## prepare (Chunk 2)"

# Five sentinels + family banner + SHAs
OUT=$(bash "$DIR/lib/blind-judge.sh" prepare "$ROOM" --phase1 judge-a)
for sec in '==== ARTIFACT ====' '==== SOLO_DECISION ====' '==== PERSONA_POSITIONS ====' \
           '==== OPERATOR_SYNTHESIS ====' '==== PERSONA_LIST ===='; do
  grep -qF "$sec" <<<"$OUT" || { note "FAIL: prepare missing section $sec"; fail=1; }
done
grep -q "diff text here" <<<"$OUT" || { note "FAIL: prepare artifact not rendered"; fail=1; }

# PERSONA_POSITIONS contains the ml-scientist#r1 marker; OPERATOR_SYNTHESIS does not
ps_block=$(awk '/==== PERSONA_POSITIONS ====/,/==== OPERATOR_SYNTHESIS ====/' <<<"$OUT")
os_block=$(awk '/==== OPERATOR_SYNTHESIS ====/,/==== PERSONA_LIST ====/' <<<"$OUT")
grep -q "ml-scientist#r1" <<<"$ps_block" || { note "FAIL: persona position not in PERSONA_POSITIONS"; fail=1; }
grep -q "Council verdict" <<<"$os_block" || { note "FAIL: synthesis not in OPERATOR_SYNTHESIS"; fail=1; }
if grep -q "ml-scientist#r1" <<<"$os_block"; then note "FAIL: persona position leaked into OPERATOR_SYNTHESIS"; fail=1; fi

grep -qE 'judge_template_sha256: [0-9a-f]{64}' <<<"$OUT" || { note "FAIL: template SHA256 missing"; fail=1; }
grep -qE 'judge_render_sha256: [0-9a-f]{64}' <<<"$OUT" || { note "FAIL: render SHA256 missing"; fail=1; }
grep -qiF "SWITCH CONTEXTS NOW" <<<"$OUT" || { note "FAIL: banner missing"; fail=1; }
grep -qiF "different model family" <<<"$OUT" || { note "FAIL: banner doesn't name family pattern"; fail=1; }
note "PASS prepare-rendering"

echo "## --phase1 forcing rule (Chunk 2)"

# Phase 1: REFUSES without flag (judged_count=0)
expect_fail_msg "prepare-without-phase1-refuses" \
  "bash '$DIR/lib/blind-judge.sh' prepare '$ROOM'" \
  "required during Phase 1"

# (After 5 judged rows we'd test the no-flag case; tested below after Chunk 4 lands records.)

# PR C correctness fix: distinct-rooms boundary (not total-rows).
# Old code would refuse --phase1 on a 6th distinct room if 5 calls hit 4 rooms.
# New code: phase boundary is distinct rooms judged, repeats on the same room don't tip.
PHASE_JOURNAL=$(mktemp_d)/phase.jsonl
export AGENT_FLEET_JOURNAL="$PHASE_JOURNAL"
for i in 1 2 3 4; do
  R=phase-room-$i
  mkdir -p "$AGENT_CHAT_ROOT/rooms/$R"
  echo "a" > "$AGENT_CHAT_ROOT/rooms/$R/artifact.txt"
  bash "$DIR/lib/transcript.sh" capture "$R" <<EOF >/dev/null
@@from: x#r1
p
@@from: synthesis
s
EOF
  bash "$DIR/lib/journal.sh" append "$R" "t" "s" "x" true "" true 0 false null 1 design \
    --synthesis-word-count 1 >/dev/null
done
# Add 4 judge_blinded=true rows across 4 distinct rooms (via record).
# Mix in 3 judge-b's so the run-5-needs-3-judge-b guard passes.
bash "$DIR/lib/blind-judge.sh" record "phase-room-1" --catch true --why w1 --evidence "- p" --reasoning r --dissent-diff "- (none)" --phase1 judge-a >/dev/null
bash "$DIR/lib/blind-judge.sh" record "phase-room-2" --catch true --why w2 --evidence "- p" --reasoning r --dissent-diff "- (none)" --phase1 judge-b >/dev/null
bash "$DIR/lib/blind-judge.sh" record "phase-room-3" --catch true --why w3 --evidence "- p" --reasoning r --dissent-diff "- (none)" --phase1 judge-b >/dev/null
bash "$DIR/lib/blind-judge.sh" record "phase-room-4" --catch true --why w4 --evidence "- p" --reasoning r --dissent-diff "- (none)" --phase1 judge-b >/dev/null
# Now distinct_rooms=4. Repeat-record on phase-room-1 with judge-b: room_already_judged=true, distinct stays 4.
bash "$DIR/lib/blind-judge.sh" record "phase-room-1" --catch true --why w1b --evidence "- p" --reasoning r --dissent-diff "- (none)" --phase1 judge-b --force >/dev/null
# Setup a 5th room (the boundary case) — prepare should require --phase1 (still in Phase 1).
R5=phase-room-5
mkdir -p "$AGENT_CHAT_ROOT/rooms/$R5"
echo "a" > "$AGENT_CHAT_ROOT/rooms/$R5/artifact.txt"
bash "$DIR/lib/transcript.sh" capture "$R5" <<EOF >/dev/null
@@from: x#r1
p
@@from: synthesis
s
EOF
bash "$DIR/lib/journal.sh" append "$R5" "t" "s" "x" true "" true 0 false null 1 design \
  --synthesis-word-count 1 >/dev/null
# distinct_rooms=4, R5 is new -> prepare on R5 should REQUIRE --phase1
expect_fail_msg "phase1-required-on-new-5th-room" "bash '$DIR/lib/blind-judge.sh' prepare '$R5'" "required during Phase 1"
# Same R5 + --phase1 judge-b: should succeed (judge_b_count=4 already, so the >=3 guard passes)
bash "$DIR/lib/blind-judge.sh" prepare "$R5" --phase1 judge-b >/dev/null 2>&1 \
  && note "PASS phase1-judge-b-ok-on-5th-room" || { note "FAIL phase1-judge-b-ok-on-5th-room"; fail=1; }
# Reset env for downstream tests
AGENT_CHAT_ROOT="$(mktemp_d)"; export AGENT_CHAT_ROOT
AGENT_FLEET_JOURNAL="$(mktemp_d)/j.jsonl"; export AGENT_FLEET_JOURNAL
ROOM=council-prepare-test
mkdir -p "$AGENT_CHAT_ROOT/rooms/$ROOM"
echo "diff text here" > "$AGENT_CHAT_ROOT/rooms/$ROOM/artifact.txt"
bash "$DIR/lib/transcript.sh" capture "$ROOM" <<EOF >/dev/null
@@from: ml-scientist#r1
verdict: BLOCK
- [BLOCKER] train/serve skew
@@from: synthesis
Council verdict: BLOCK
1. [BLOCKER] train/serve skew
EOF
bash "$DIR/lib/journal.sh" append "$ROOM" "prepare-test" "ship as-is" "ml-scientist" \
  true "" true 0 false null 1 design --synthesis-word-count 7 >/dev/null

echo "## parser fixtures (Chunk 3)"

# Fixtures dir is populated below. For now, programmatically build & test each fixture.
mkdir -p "$FIXDIR"

# OPERATOR_SYNTHESIS used by self-quote check
OP_SYNTH_FILE="$FIXDIR/op-synth.txt"
cat > "$OP_SYNTH_FILE" <<'EOF'
Council verdict: BLOCK
1. [BLOCKER] train/serve skew detected
EOF

# Helper: build a valid response (used as scaffold for negative fixtures)
build_valid_true() {
  cat <<'EOF'
===JUDGE OUTPUT===
REASONING: The synthesis surfaces a calibration drift the solo did not name; clause (a) and (b) of materiality both hold (engineer would change rollout; postmortem would cite).
DISSENT_DIFF: - (none)
NET_NEW_CATCH: true
WHY: ml-scientist flagged a calibration drift in the ranker that the operator did not include in pre-decision risks.
EVIDENCE: - [BLOCKER] calibration drift in ranker after retraining
===END===
EOF
}
build_valid_false() {
  cat <<'EOF'
===JUDGE OUTPUT===
REASONING: Each council finding is either already named in SOLO_DECISION or fails the materiality test.
DISSENT_DIFF: - (none)
NET_NEW_CATCH: false
WHY: closest pair: synthesis's "train/serve skew" matches solo's "feature drift between offline and online"
===END===
EOF
}
build_valid_erasure() {
  cat <<'EOF'
===JUDGE OUTPUT===
REASONING: red-team's BLOCKER on rollout-asymmetry is in PERSONA_POSITIONS but absent from OPERATOR_SYNTHESIS.
DISSENT_DIFF: - red-team: rollout asymmetry across regions is missing from operator synthesis
NET_NEW_CATCH: true
WHY: red-team raised a rollout-asymmetry concern that was erased from the operator synthesis.
EVIDENCE: - [BLOCKER] rollout asymmetry across regions invalidates the SLO claim
===END===
EOF
}

write_fixture() { local name="$1"; cat > "$FIXDIR/$name"; }

# Build all 17 fixtures
build_valid_true       | write_fixture valid-true.txt
build_valid_false      | write_fixture valid-false.txt
build_valid_erasure    | write_fixture valid-erasure.txt
build_valid_true | sed '/^===JUDGE OUTPUT===$/d' | write_fixture missing-sentinel.txt
build_valid_true | sed '/^===END===$/d'          | write_fixture missing-end.txt
build_valid_true | sed '/^REASONING:/d'          | write_fixture missing-reasoning.txt
build_valid_true | sed '/^DISSENT_DIFF:/d'       | write_fixture missing-dissent-diff.txt
build_valid_true | sed 's/^NET_NEW_CATCH: true/NET_NEW_CATCH:true/' | write_fixture no-space.txt
build_valid_true | sed 's/^NET_NEW_CATCH: true/NET_NEW_CATCH: True/' | write_fixture caps.txt
build_valid_true | sed 's/^NET_NEW_CATCH: true/NET_NEW_CATCH: true   /' | write_fixture trailing-ws.txt
build_valid_true | sed 's/^NET_NEW_CATCH: true/NET_NEW_CATCH: yes/' | write_fixture bad-value.txt
build_valid_true | sed '/^EVIDENCE:/d'           | write_fixture missing-evidence.txt
# evidence-on-false: catch=false but EVIDENCE present
cat > "$FIXDIR/evidence-on-false.txt" <<'EOF'
===JUDGE OUTPUT===
REASONING: solo covers it.
DISSENT_DIFF: - (none)
NET_NEW_CATCH: false
WHY: covered already
EVIDENCE: - [BLOCKER] should not be here
===END===
EOF
# evidence-quotes-synthesis: EVIDENCE matches a line in op-synth
cat > "$FIXDIR/evidence-quotes-synthesis.txt" <<'EOF'
===JUDGE OUTPUT===
REASONING: r.
DISSENT_DIFF: - (none)
NET_NEW_CATCH: true
WHY: copying op synth as a shortcut.
EVIDENCE: 1. [BLOCKER] train/serve skew detected
===END===
EOF
# implied-without-implied-by: WHY says "already implied" but no IMPLIED_BY field
cat > "$FIXDIR/implied-without-implied-by.txt" <<'EOF'
===JUDGE OUTPUT===
REASONING: already implied in solo.
DISSENT_DIFF: - (none)
NET_NEW_CATCH: false
WHY: closest pair: synthesis was already implied by the solo's "we already considered drift" line
===END===
EOF
# multi-line-why-wrapped: WHY value is on 2 lines but the second line is just continuation
cat > "$FIXDIR/multi-line-why-wrapped.txt" <<'EOF'
===JUDGE OUTPUT===
REASONING: r.
DISSENT_DIFF: - (none)
NET_NEW_CATCH: true
WHY: ml-scientist flagged a calibration drift in the ranker that the operator did not include
in pre-decision risks.
EVIDENCE: - [BLOCKER] calibration drift in ranker after retraining
===END===
EOF
# false-with-evidence: catch=false has a non-empty EVIDENCE field (the WHY structure is loose
# but the rejection path is 'EVIDENCE must be empty when false', not a WHY-parse issue).
# Originally named multi-line-why-actual which misleadingly suggested a WHY-parse test.
cat > "$FIXDIR/false-with-evidence.txt" <<'EOF'
===JUDGE OUTPUT===
REASONING: r.
DISSENT_DIFF: - (none)
NET_NEW_CATCH: false
WHY: this is sentence one.
also this is sentence two.
EVIDENCE: should-not-be-here
===END===
EOF

# Good fixtures pass
expect_pass "fixture-valid-true"    "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/valid-true.txt' '$OP_SYNTH_FILE'"
expect_pass "fixture-valid-false"   "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/valid-false.txt' '$OP_SYNTH_FILE'"
expect_pass "fixture-valid-erasure" "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/valid-erasure.txt' '$OP_SYNTH_FILE'"
expect_pass "fixture-multi-line-why-wrapped" "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/multi-line-why-wrapped.txt' '$OP_SYNTH_FILE'"
# no-space / caps / trailing-ws SHOULD pass (parser is tolerant)
expect_pass "fixture-no-space"     "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/no-space.txt' '$OP_SYNTH_FILE'"
expect_pass "fixture-caps"         "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/caps.txt' '$OP_SYNTH_FILE'"
expect_pass "fixture-trailing-ws"  "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/trailing-ws.txt' '$OP_SYNTH_FILE'"

# Bad fixtures fail with expected error substrings
expect_fail_msg "fixture-missing-sentinel"   "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/missing-sentinel.txt' '$OP_SYNTH_FILE'"   "missing ===JUDGE OUTPUT==="
expect_fail_msg "fixture-missing-end"        "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/missing-end.txt' '$OP_SYNTH_FILE'"        "missing ===END==="
expect_fail_msg "fixture-missing-reasoning"  "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/missing-reasoning.txt' '$OP_SYNTH_FILE'"  "REASONING field required"
expect_fail_msg "fixture-missing-dissent"    "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/missing-dissent-diff.txt' '$OP_SYNTH_FILE'" "DISSENT_DIFF field required"
expect_fail_msg "fixture-bad-value"          "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/bad-value.txt' '$OP_SYNTH_FILE'"           "NET_NEW_CATCH must be"
expect_fail_msg "fixture-missing-evidence"   "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/missing-evidence.txt' '$OP_SYNTH_FILE'"    "EVIDENCE required"
expect_fail_msg "fixture-evidence-on-false"  "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/evidence-on-false.txt' '$OP_SYNTH_FILE'"   "EVIDENCE must be empty"
expect_fail_msg "fixture-evidence-quotes-synthesis" "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/evidence-quotes-synthesis.txt' '$OP_SYNTH_FILE'" "EVIDENCE appears in OPERATOR_SYNTHESIS"

# Post-/code-review hardening: substring (not just line-exact) attack on EVIDENCE
# operator's synthesis contains "train/serve skew detected" as part of a longer line;
# judge quotes the phrase, not the whole line; -F (not -Fx) catches it.
cat > "$FIXDIR/evidence-quotes-synthesis-substring.txt" <<'EOF'
===JUDGE OUTPUT===
REASONING: r.
DISSENT_DIFF: - (none)
NET_NEW_CATCH: true
WHY: phrase from op synth.
EVIDENCE: train/serve skew detected
===END===
EOF
expect_fail_msg "fixture-evidence-substring-of-synthesis" "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/evidence-quotes-synthesis-substring.txt' '$OP_SYNTH_FILE'" "EVIDENCE appears in OPERATOR_SYNTHESIS"

# Post-/council hardening: EVIDENCE must also not match SOLO_DECISION (the operator's
# pre-decision risks cannot self-validate either). Same attack shape, separate guard.
SOLO_FILE="$FIXDIR/solo.txt"
cat > "$SOLO_FILE" <<'EOF'
there are calibration risks I already see
feature drift could be a problem
EOF
cat > "$FIXDIR/evidence-quotes-solo.txt" <<'EOF'
===JUDGE OUTPUT===
REASONING: r.
DISSENT_DIFF: - (none)
NET_NEW_CATCH: true
WHY: phrase from solo.
EVIDENCE: calibration risks I already see
===END===
EOF
expect_fail_msg "fixture-evidence-quotes-solo" "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/evidence-quotes-solo.txt' '$OP_SYNTH_FILE' '$SOLO_FILE'" "EVIDENCE appears in SOLO_DECISION"

# Post-/code-review hardening: IMPLIED_BY may legitimately contain colon-prefixed text;
# the extract_field regex must not stop at a literal "foo:" inside the value.
cat > "$FIXDIR/valid-false-implied-by-colon.txt" <<'EOF'
===JUDGE OUTPUT===
REASONING: solo named this risk explicitly with a quoted line.
DISSENT_DIFF: - (none)
NET_NEW_CATCH: false
WHY: closest pair: synthesis was already implied by the solo's line about regression
IMPLIED_BY: solo line about regression: we already considered model drift between v1 and v2
===END===
EOF
expect_pass "fixture-implied-by-with-colon" "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/valid-false-implied-by-colon.txt' '$OP_SYNTH_FILE'"
expect_fail_msg "fixture-implied-without-implied-by" "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/implied-without-implied-by.txt' '$OP_SYNTH_FILE'" "IMPLIED_BY required"
# multi-line-why-actual: has EVIDENCE field present but NET_NEW_CATCH=false → "EVIDENCE must be empty"
expect_fail_msg "fixture-false-with-evidence" "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/false-with-evidence.txt' '$OP_SYNTH_FILE'" "EVIDENCE must be empty"

echo "## record (Chunk 4) — in-place update on existing row"

# Build a response and pipe to `judge` to exercise the full chain
RESP=$(build_valid_true)
echo "$RESP" | bash "$DIR/lib/blind-judge.sh" judge "$ROOM" --phase1 judge-a >/dev/null 2>&1 \
  && note "PASS judge-end-to-end" || { note "FAIL judge-end-to-end"; fail=1; }

# Journal row should now have judge_blinded=true
jq -e --arg r "$ROOM" 'select(.room==$r and .judge_blinded==true and .judge_blinded_catch==true)' \
  "$AGENT_FLEET_JOURNAL" >/dev/null \
  && note "PASS journal-row-updated-with-judge-fields" \
  || { note "FAIL journal-row-update"; fail=1; }

# Transcript should have a @@from: blind-judge#judge-1 line
grep -q '"from":"blind-judge#judge-1"' "$AGENT_CHAT_ROOT/rooms/$ROOM/log.jsonl" \
  && note "PASS transcript-blind-judge-line" \
  || { note "FAIL transcript-blind-judge-line"; fail=1; }

echo "## record warn-and-confirm on different answer"

# Record a DIFFERENT catch without --force → must fail
expect_fail_msg "record-different-without-force" \
  "bash '$DIR/lib/blind-judge.sh' record '$ROOM' --catch false --why 'flipping' --reasoning 'r' --dissent-diff '- (none)'" \
  "already has judge_blinded_catch=true"

# With --force → succeeds
bash "$DIR/lib/blind-judge.sh" record "$ROOM" --catch false --why "actually no" \
  --reasoning "on reflection covered by solo" --dissent-diff "- (none)" --force \
  && note "PASS record-different-with-force" \
  || { note "FAIL record-different-with-force"; fail=1; }

echo "## record judge-only row when no journal row exists"

ROOM_J=council-judge-only-test
mkdir -p "$AGENT_CHAT_ROOT/rooms/$ROOM_J"
bash "$DIR/lib/transcript.sh" capture "$ROOM_J" <<EOF >/dev/null
@@from: a#r1
some position
@@from: synthesis
some synthesis
EOF
# Note: no journal.sh append for this room
bash "$DIR/lib/blind-judge.sh" record "$ROOM_J" --catch false \
  --why "stand-alone judge" --reasoning "r" --dissent-diff "- (none)" \
  && note "PASS record-judge-only-row" \
  || { note "FAIL record-judge-only-row"; fail=1; }
jq -se --arg r "$ROOM_J" 'map(select(.room==$r)) | .[-1] | .judge_blinded==true and .net_new_catch==null and .acted_on==null' \
  "$AGENT_FLEET_JOURNAL" >/dev/null \
  && note "PASS judge-only-row-has-null-self-report" \
  || { note "FAIL judge-only-row-shape"; fail=1; }

echo "## concurrency (flock serializes two-terminal race)"

ROOM_C=council-concurrent-test
mkdir -p "$AGENT_CHAT_ROOT/rooms/$ROOM_C"
echo "art" > "$AGENT_CHAT_ROOT/rooms/$ROOM_C/artifact.txt"
bash "$DIR/lib/transcript.sh" capture "$ROOM_C" <<EOF >/dev/null
@@from: a#r1
p
@@from: synthesis
s
EOF
# Add a normal journal row so record can update in-place
bash "$DIR/lib/journal.sh" append "$ROOM_C" "concurrent-test" "x" "a" \
  true "" true 0 false null 1 design --synthesis-word-count 1 >/dev/null

# Race two records, both with SAME catch=true (idempotent, no warn)
(
  bash "$DIR/lib/blind-judge.sh" record "$ROOM_C" --catch true --why "first" \
    --evidence "- p" --reasoning "r1" --dissent-diff "- (none)" 2>&1
) &
PID1=$!
(
  bash "$DIR/lib/blind-judge.sh" record "$ROOM_C" --catch true --why "second" \
    --evidence "- p" --reasoning "r2" --dissent-diff "- (none)" 2>&1
) &
PID2=$!
wait $PID1 || true
wait $PID2 || true

# Journal must have exactly one row for ROOM_C
n=$(jq -s --arg r "$ROOM_C" '[.[] | select(.room==$r)] | length' "$AGENT_FLEET_JOURNAL")
[ "$n" = "1" ] && note "PASS concurrency-single-journal-row" || { note "FAIL concurrency: got $n rows"; fail=1; }

# PR C correctness fix (#23 MAJOR #2): per-room lock in `judge` spans prepare→record.
# Race two judge calls on the SAME room (with piped responses). Second one MUST block
# on the room lock until the first releases, then either record or fail-gracefully.
ROOM_J=council-judge-race-test
mkdir -p "$AGENT_CHAT_ROOT/rooms/$ROOM_J"
echo "art" > "$AGENT_CHAT_ROOT/rooms/$ROOM_J/artifact.txt"
bash "$DIR/lib/transcript.sh" capture "$ROOM_J" <<EOF >/dev/null
@@from: a#r1
p
@@from: synthesis
s
EOF
bash "$DIR/lib/journal.sh" append "$ROOM_J" "judge-race-test" "x" "a" \
  true "" true 0 false null 1 design --synthesis-word-count 1 >/dev/null

RESP_TRUE=$(build_valid_true)
# /council MAJOR #1 fix (PR C). Earlier version of this test just verified the lock dir was
# created+removed, which a no-op lock would pass. The fix: time the FAST judge call alone.
# If the lock works, FAST must wait for SLOW to finish (~1s). If the lock is a no-op,
# FAST returns immediately (<200ms). The difference is the actual serialization assertion.
#
# Pass --phase1 because the test env is still in Phase 1 (distinct_rooms<5 here); pairing
# both judges with judge-a means they hit each other's lock without phase-validation eating
# the assertion.
(
  ( sleep 1; echo "$RESP_TRUE" ) | bash "$DIR/lib/blind-judge.sh" judge "$ROOM_J" --phase1 judge-a >/dev/null 2>&1
) &
JPID1=$!
sleep 0.2  # let SLOW reach acquire_lock first
fast_start=$(date +%s%N 2>/dev/null || date +%s)  # nanoseconds on GNU date, fallback seconds
echo "$RESP_TRUE" | bash "$DIR/lib/blind-judge.sh" judge "$ROOM_J" --phase1 judge-a >/dev/null 2>&1
fast_end=$(date +%s%N 2>/dev/null || date +%s)
wait $JPID1 || true
# fast_elapsed in milliseconds (or seconds if date +%s%N unavailable on this platform).
# date +%s%N on macOS without coreutils returns the literal string "%N" — detect + fallback.
if [[ "$fast_start" == *N* ]] || [[ "$fast_end" == *N* ]]; then
  fast_elapsed_ms=$(( (fast_end - fast_start) * 1000 ))
else
  fast_elapsed_ms=$(( (fast_end - fast_start) / 1000000 ))
fi

# Exactly ONE journal row for ROOM_J (both judges wrote the same answer; idempotent)
n=$(jq -s --arg r "$ROOM_J" '[.[] | select(.room==$r)] | length' "$AGENT_FLEET_JOURNAL")
[ "$n" = "1" ] && note "PASS judge-race-single-journal-row" || { note "FAIL judge-race: got $n rows"; fail=1; }
# Lock dir must be cleaned up
[ ! -d "$AGENT_CHAT_ROOT/rooms/$ROOM_J/.judge.lockdir" ] \
  && note "PASS judge-race-lock-cleaned-up" || { note "FAIL judge-race-lock-orphaned"; fail=1; }
# Serialization: FAST must have waited for SLOW (>=500ms). A no-op lock would let FAST
# return in <200ms (it has nothing else to do).
if [ "$fast_elapsed_ms" -ge 500 ]; then
  note "PASS judge-race-lock-actually-serializes (fast waited ${fast_elapsed_ms}ms)"
else
  note "FAIL judge-race-lock-no-op (fast finished in ${fast_elapsed_ms}ms; should have waited >=500ms for SLOW)"
  fail=1
fi

echo "## end-to-end smoke (Chunk 8)"

# Fresh state: orchestrator writes durable artifact, captures transcript, journal appends,
# operator runs blind-judge.sh judge, journal row updates, transcript gets blind-judge#judge-N line.
SMOKE_DIR=$(mktemp_d); SMOKE_J="$SMOKE_DIR/j.jsonl"
export AGENT_CHAT_ROOT="$SMOKE_DIR/agent-chat"
export AGENT_FLEET_JOURNAL="$SMOKE_J"
SMOKE_ROOM=council-e2e-smoke
mkdir -p "$AGENT_CHAT_ROOT/rooms/$SMOKE_ROOM"
echo "smoke artifact: a 3-line proposal that adds a feature flag" > "$AGENT_CHAT_ROOT/rooms/$SMOKE_ROOM/artifact.txt"
bash "$DIR/lib/transcript.sh" capture "$SMOKE_ROOM" <<EOF >/dev/null
@@from: red-team#r1
verdict: BLOCK
- [BLOCKER] feature flag has no rollback test
@@from: synthesis
Council verdict: BLOCK
1. [BLOCKER] feature flag has no rollback test
EOF
bash "$DIR/lib/journal.sh" append "$SMOKE_ROOM" "e2e-smoke" \
  "ship the feature flag as-is" "red-team" true "" true 0 false null 1 design \
  --synthesis-word-count 9 >/dev/null
# Feed a valid judge response through the full chain (judge subcommand)
SMOKE_RESPONSE=$(build_valid_erasure)  # erasure response = catch=true with EVIDENCE
echo "$SMOKE_RESPONSE" | bash "$DIR/lib/blind-judge.sh" judge "$SMOKE_ROOM" --phase1 judge-a >/dev/null 2>&1 \
  && note "PASS smoke-judge-chain-completes" || { note "FAIL smoke-judge-chain-completes"; fail=1; }
# Verify: journal row has judge_blinded=true AND transcript has @@from: blind-judge#judge-1
jq -e --arg r "$SMOKE_ROOM" 'select(.room==$r and .judge_blinded==true and .judge_blinded_catch==true)' "$SMOKE_J" >/dev/null \
  && note "PASS smoke-journal-row-updated" || { note "FAIL smoke-journal-row-updated"; fail=1; }
grep -q '"from":"blind-judge#judge-1"' "$AGENT_CHAT_ROOT/rooms/$SMOKE_ROOM/log.jsonl" \
  && note "PASS smoke-transcript-judge-line" || { note "FAIL smoke-transcript-judge-line"; fail=1; }
# stats should now report 1 judged run on this isolated journal
stats=$(AGENT_FLEET_JOURNAL="$SMOKE_J" bash "$DIR/lib/journal.sh" stats 2>&1)
echo "$stats" | grep -q 'blinded-judge sample : 1 of 1' \
  && note "PASS smoke-stats-reports-judged" || { note "FAIL smoke-stats-reports-judged (got: $stats)"; fail=1; }

# Reset env for downstream tests (none after smoke today, but keep the discipline)
AGENT_CHAT_ROOT="$(mktemp_d)"; export AGENT_CHAT_ROOT
AGENT_FLEET_JOURNAL="$(mktemp_d)/j.jsonl"; export AGENT_FLEET_JOURNAL

echo "## backfill-artifact (Chunk 5)"

ROOM_BF=council-backfill-test
mkdir -p "$AGENT_CHAT_ROOT/rooms/$ROOM_BF"
# Use a git-tracked file in this repo as the legitimate --from source
GIT_TRACKED_SOURCE="$DIR/lib/blind-judge-prompt.v2.txt"
UNTRACKED_SOURCE=$(mktemp); echo "fabricated artifact content" > "$UNTRACKED_SOURCE"

# Refuses without --from
expect_fail_msg "backfill-without-from" \
  "bash '$DIR/lib/blind-judge.sh' backfill-artifact '$ROOM_BF'" \
  "required"
# Refuses if --from path doesn't exist
expect_fail_msg "backfill-from-nonexistent" \
  "bash '$DIR/lib/blind-judge.sh' backfill-artifact '$ROOM_BF' --from /nonexistent/path" \
  "path does not exist"
# Refuses untracked file without --i-confirm
expect_fail_msg "backfill-untracked-without-confirm" \
  "bash '$DIR/lib/blind-judge.sh' backfill-artifact '$ROOM_BF' --from '$UNTRACKED_SOURCE'" \
  "not a git-tracked file"
# Succeeds with --i-confirm on untracked
bash "$DIR/lib/blind-judge.sh" backfill-artifact "$ROOM_BF" --from "$UNTRACKED_SOURCE" --i-confirm-this-is-the-original >/dev/null \
  && note "PASS backfill-untracked-with-confirm" || { note "FAIL backfill-untracked-with-confirm"; fail=1; }
[ -f "$AGENT_CHAT_ROOT/rooms/$ROOM_BF/artifact.txt" ] \
  && note "PASS backfill-artifact-file-created" || { note "FAIL backfill-artifact-file-created"; fail=1; }
grep -q "fabricated artifact content" "$AGENT_CHAT_ROOT/rooms/$ROOM_BF/artifact.txt" \
  && note "PASS backfill-content-matches" || { note "FAIL backfill-content-matches"; fail=1; }
# Idempotent on same content
bash "$DIR/lib/blind-judge.sh" backfill-artifact "$ROOM_BF" --from "$UNTRACKED_SOURCE" --i-confirm-this-is-the-original 2>&1 \
  | grep -q "idempotent" && note "PASS backfill-idempotent" || { note "FAIL backfill-idempotent"; fail=1; }
# Succeeds without --i-confirm on git-tracked file (different room)
ROOM_BF2=council-backfill-tracked
mkdir -p "$AGENT_CHAT_ROOT/rooms/$ROOM_BF2"
bash "$DIR/lib/blind-judge.sh" backfill-artifact "$ROOM_BF2" --from "$GIT_TRACKED_SOURCE" >/dev/null \
  && note "PASS backfill-git-tracked-no-confirm-needed" || { note "FAIL backfill-git-tracked-no-confirm-needed"; fail=1; }
# Replace with different content prints a warning to stderr
UNTRACKED_SOURCE2=$(mktemp); echo "different content" > "$UNTRACKED_SOURCE2"
rout=$(bash "$DIR/lib/blind-judge.sh" backfill-artifact "$ROOM_BF" --from "$UNTRACKED_SOURCE2" --i-confirm-this-is-the-original 2>&1 1>/dev/null || true)
echo "$rout" | grep -q "REPLACED" \
  && note "PASS backfill-warns-on-replace" || { note "FAIL backfill-warns-on-replace (got: $rout)"; fail=1; }
rm -f "$UNTRACKED_SOURCE" "$UNTRACKED_SOURCE2"

echo "## extract_operator_synthesis: multi-synthesis-block picks LAST (issue #44 item #4)"
# DD contract: when a room has 2+ @@from: synthesis blocks across rounds, the parser MUST
# pick the LAST one (`| last` in jq). This guards against early-round synthesis drafts being
# used in place of the final synthesis the operator actually committed to.
ROOM_MS=council-multi-synthesis
mkdir -p "$AGENT_CHAT_ROOT/rooms/$ROOM_MS"
echo "artifact" > "$AGENT_CHAT_ROOT/rooms/$ROOM_MS/artifact.txt"
bash "$DIR/lib/transcript.sh" capture "$ROOM_MS" <<EOF >/dev/null
@@from: ml-scientist#r1
verdict: BLOCK
- [BLOCKER] early-round finding
@@from: synthesis
DRAFT round-1 synthesis: BLOCK with early finding
@@from: ml-scientist#r2
verdict: SHIP-WITH-CHANGES
- [MAJOR] revised finding
@@from: synthesis
FINAL synthesis: SHIP-WITH-CHANGES with revised finding
EOF

# Source the helper functions to call extract_operator_synthesis directly.
# blind-judge.sh runs main when not sourced; we invoke `prepare` so the same code path that
# uses extract_operator_synthesis fires end-to-end.
bash "$DIR/lib/journal.sh" append "$ROOM_MS" "multi-synth" "ship" "ml-scientist" \
  true "" true 0 false null 1 design --synthesis-word-count 7 >/dev/null
MS_OUT=$(bash "$DIR/lib/blind-judge.sh" prepare "$ROOM_MS" --phase1 judge-a)
os_block=$(awk '/==== OPERATOR_SYNTHESIS ====/,/==== PERSONA_LIST ====/' <<<"$MS_OUT")
grep -q "FINAL synthesis" <<<"$os_block" \
  && note "PASS multi-synthesis-picks-last (FINAL present)" \
  || { note "FAIL multi-synthesis: FINAL synthesis missing from OPERATOR_SYNTHESIS block"; fail=1; }
if grep -q "DRAFT round-1" <<<"$os_block"; then
  note "FAIL multi-synthesis: DRAFT round-1 synthesis leaked into OPERATOR_SYNTHESIS (parser used wrong block)"
  fail=1
else
  note "PASS multi-synthesis-rejects-earlier-drafts (DRAFT absent)"
fi

echo "---"
if [ "$fail" = "0" ]; then echo "PASS test_blind_judge"; else echo "FAIL test_blind_judge"; exit 1; fi
