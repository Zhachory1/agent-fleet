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

# Set up isolated env
export AGENT_CHAT_ROOT="$(mktemp -d)"
export AGENT_FLEET_JOURNAL="$(mktemp -d)/j.jsonl"
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
  true "" true 0 false null 1 design --synthesis-word-count 8 >/dev/null

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
# multi-line-why-actual: WHY has EVIDENCE: appearing mid-block due to multi-sentence WHY confusion
# (we test this implicitly via missing-evidence behavior; here we ensure that a WHY block which
# breaks the field discipline still parses something sane)
cat > "$FIXDIR/multi-line-why-actual.txt" <<'EOF'
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
expect_fail_msg "fixture-evidence-quotes-synthesis" "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/evidence-quotes-synthesis.txt' '$OP_SYNTH_FILE'" "EVIDENCE quotes OPERATOR_SYNTHESIS verbatim"
expect_fail_msg "fixture-implied-without-implied-by" "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/implied-without-implied-by.txt' '$OP_SYNTH_FILE'" "IMPLIED_BY required"
# multi-line-why-actual: has EVIDENCE field present but NET_NEW_CATCH=false → "EVIDENCE must be empty"
expect_fail_msg "fixture-multi-line-why-actual" "bash '$DIR/lib/blind-judge.sh' parse '$FIXDIR/multi-line-why-actual.txt' '$OP_SYNTH_FILE'" "EVIDENCE must be empty"

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

echo "---"
if [ "$fail" = "0" ]; then echo "PASS test_blind_judge"; else echo "FAIL test_blind_judge"; exit 1; fi
