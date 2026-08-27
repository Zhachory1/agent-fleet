#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_PARENT_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_PARENT_TMP"' EXIT
mktemp_d() { mktemp -d "$TEST_PARENT_TMP/d.XXXXXX"; }
AGENT_CHAT_ROOT="$(mktemp_d)"; export AGENT_CHAT_ROOT
ROOM="test-room"
"$DIR/lib/transcript.sh" append "$ROOM" "ml-scientist" "verdict=BLOCK calibration off"
"$DIR/lib/transcript.sh" append "$ROOM" "red-team" "what about cold start"
LOG="$AGENT_CHAT_ROOT/rooms/$ROOM/log.jsonl"
[ -f "$LOG" ] || { echo "FAIL: log not created"; exit 1; }
[ "$(wc -l < "$LOG" | tr -d ' ')" = "2" ] || { echo "FAIL: expected 2 lines"; exit 1; }
jq -e . "$LOG" >/dev/null || { echo "FAIL: invalid JSONL"; exit 1; }
FROM=$(sed -n '1p' "$LOG" | jq -r .from)
[ "$FROM" = "ml-scientist" ] || { echo "FAIL: from mismatch"; exit 1; }
# multi-line POSITION block survives round-trip (full thinking, not just one-liner)
"$DIR/lib/transcript.sh" append "$ROOM" "software-architect" "$(printf 'verdict: SHIP\ntop_issues:\n- [MAJOR] coupling')"
LINES=$(wc -l < "$LOG" | tr -d ' '); [ "$LINES" = "3" ] || { echo "FAIL: multiline not one JSONL line (got $LINES)"; exit 1; }
sed -n '3p' "$LOG" | jq -e '.text | contains("top_issues")' >/dev/null || { echo "FAIL: multiline text lost"; exit 1; }
# show renders the room
OUT="$("$DIR/lib/transcript.sh" show "$ROOM")"
echo "$OUT" | grep -q "council transcript: $ROOM" || { echo "FAIL: show header missing"; exit 1; }
echo "$OUT" | grep -q "software-architect" || { echo "FAIL: show missing persona"; exit 1; }
echo "$OUT" | grep -q "│ top_issues:" || { echo "FAIL: show didn't render multiline body"; exit 1; }
# rooms lists it
"$DIR/lib/transcript.sh" rooms | grep -q "$ROOM" || { echo "FAIL: rooms didn't list room"; exit 1; }
# batch capture: 2 multiline blocks → 2 JSONL lines, full text preserved
CROOM="cap-room"
printf '@@from: red-team\nverdict: BLOCK\n- [BLOCKER] x\n@@from: generalist-swe\nverdict: SHIP\n- [MINOR] y\n' \
  | "$DIR/lib/transcript.sh" capture "$CROOM"
CLOG="$AGENT_CHAT_ROOT/rooms/$CROOM/log.jsonl"
[ "$(wc -l < "$CLOG" | tr -d ' ')" = "2" ] || { echo "FAIL: capture didn't make 2 lines"; exit 1; }
sed -n '1p' "$CLOG" | jq -e '.from=="red-team" and (.text|contains("[BLOCKER]"))' >/dev/null || { echo "FAIL: capture block-1 wrong"; exit 1; }
sed -n '2p' "$CLOG" | jq -e '.from=="generalist-swe"' >/dev/null || { echo "FAIL: capture block-2 wrong"; exit 1; }
# capture with no blocks → error (loud, not silent skip)
printf 'no markers here\n' | "$DIR/lib/transcript.sh" capture "$CROOM" 2>/dev/null && { echo "FAIL: capture should reject markerless stdin"; exit 1; } || true
# round-tagged capture stored RAW; show groups by round
RR=round-room
printf '@@from: red-team#r1\nverdict: BLOCK\n@@from: red-team#r2\nverdict: SHIP\n' | "$DIR/lib/transcript.sh" capture "$RR"
grep -q '"from":"red-team#r2"' "$AGENT_CHAT_ROOT/rooms/$RR/log.jsonl" || { echo "FAIL: #rN not stored raw"; exit 1; }
SHOW="$("$DIR/lib/transcript.sh" show "$RR")"
echo "$SHOW" | grep -q '── round 1 ──' || { echo "FAIL: no round1 header"; exit 1; }
echo "$SHOW" | grep -q '── round 2 ──' || { echo "FAIL: no round2 header"; exit 1; }
# MULTI-LINE block must render intact (catches the jq-real-newline vs awk-tab bug)
ML=ml-room
printf '@@from: red-team#r1\nverdict: BLOCK\ntop_issues:\n- [BLOCKER] x\n' | "$DIR/lib/transcript.sh" capture "$ML"
MOUT="$("$DIR/lib/transcript.sh" show "$ML")"
echo "$MOUT" | grep -q '│ top_issues:' || { echo "FAIL: multiline body not rendered (jq/awk newline bug)"; exit 1; }
echo "$MOUT" | grep -cq '── round' && [ "$(echo "$MOUT" | grep -c '── round')" = 1 ] || { echo "FAIL: multiline split into spurious rounds"; exit 1; }
# negative: a '#' that is NOT a round suffix must not be grouped as a round
NR=neg-room
printf '@@from: persona#hashtag\nverdict: SHIP\n' | "$DIR/lib/transcript.sh" capture "$NR"
"$DIR/lib/transcript.sh" show "$NR" | grep -qE '── round [0-9]+ ──' && { echo "FAIL: #hashtag misread as round"; exit 1; } || true

# Chunk 7: blind-judge entries render with a distinct marker
BJ=blind-judge-rendering-room
printf '@@from: blind-judge#judge-1\nNET_NEW_CATCH: true\nWHY: y\n' | "$DIR/lib/transcript.sh" capture "$BJ"
BJSHOW="$("$DIR/lib/transcript.sh" show "$BJ")"
if ! grep -q '⚖ JUDGE 1' <<<"$BJSHOW"; then echo "FAIL: blind-judge entry not rendered with distinct ⚖ JUDGE marker"; echo "---"; echo "$BJSHOW"; exit 1; fi
if grep -q '┌─ \[blind-judge' <<<"$BJSHOW"; then echo "FAIL: blind-judge rendered with normal box-drawing chars"; exit 1; fi

# Issue #78: managed rooms accept only strict, complete per-round POSITION receipts.
ART="$TEST_PARENT_TMP/artifact.txt"
printf 'council_artifact_kind: general\nreview this\n' > "$ART"
MROOM=managed-room
export COUNCIL_SELECTION_RATIONALE="adversarial coverage"
export COUNCIL_EXECUTION_MODE=spawned
"$DIR/lib/council-guard.sh" begin "$MROOM" "$ART" ship 'red-team,mvp,occams-razor' >/dev/null
MLOG="$AGENT_CHAT_ROOT/rooms/$MROOM/log.jsonl"
set +e
"$DIR/lib/transcript.sh" append "$MROOM" red-team 'untyped roster entry' >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] && [ ! -e "$MLOG" ] || { echo "FAIL: generic managed append accepted untagged roster sender"; exit 1; }
set +e
printf '@@from: unknown\n  POSITION (persona: unknown)\n' | "$DIR/lib/transcript.sh" capture "$MROOM" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] && [ ! -e "$MLOG" ] || { echo "FAIL: generic managed capture accepted untagged whitespace POSITION"; exit 1; }
set +e
printf '@@from: unknown#r1\n POSITION (persona: unknown)\n' | "$DIR/lib/transcript.sh" capture "$MROOM" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] && [ ! -e "$MLOG" ] || { echo "FAIL: generic managed #rN capture accepted unknown whitespace POSITION"; exit 1; }
set +e
printf '@@from: red-team#r1\nPOSITION (persona: red-team)\n- verdict: BLOCK\n' | "$DIR/lib/transcript.sh" capture "$MROOM" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] && [ ! -e "$MLOG" ] || { echo "FAIL: generic managed POSITION capture should fail without rows"; exit 1; }
set +e
printf '@@from: red-team#r1\nPOSITION (persona: red-team)\n- verdict: BLOCK\n- top_issues:\n- confidence: high\n- one_line: block\n' | "$DIR/lib/transcript.sh" capture-positions "$MROOM" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] && [ ! -e "$MLOG" ] || { echo "FAIL: incomplete strict batch wrote rows"; exit 1; }
cat <<'EOF' | "$DIR/lib/transcript.sh" capture-positions "$MROOM" >/dev/null
@@from: red-team#r1
POSITION (persona: red-team)
- verdict: BLOCK
- top_issues:
- strongest_counterargument: transport may be enough
- confidence: high
- one_line: block
@@from: mvp#r1
POSITION (persona: mvp)
- verdict: SHIP
- top_issues:
- strongest_counterargument: scope may grow
- confidence: med
- one_line: ship
@@from: occams-razor#r1
POSITION (persona: occams-razor)
- verdict: SHIP-WITH-CHANGES
- top_issues:
- strongest_counterargument: changes may be needless
- confidence: low
- one_line: trim it
EOF
[ "$(wc -l < "$MLOG" | tr -d ' ')" = "3" ] || { echo "FAIL: strict capture did not atomically write roster"; exit 1; }
jq -e '.state=="running" and (.rounds|length==1) and .rounds[0].round==1' "$AGENT_CHAT_ROOT/rooms/$MROOM/manifest.json" >/dev/null \
  || { echo "FAIL: strict capture did not write round receipt"; exit 1; }
jq -cn --arg ts now --arg from 'stale#r2' --arg text stale '{ts:$ts,from:$from,text:$text}' >> "$MLOG"
set +e
cat <<'EOF' | "$DIR/lib/transcript.sh" capture-positions "$MROOM" >/dev/null 2>&1
@@from: red-team#r2
POSITION (persona: red-team)
- verdict: BLOCK
- top_issues:
- strongest_counterargument: transport may be enough
- confidence: high
- one_line: block
@@from: mvp#r2
POSITION (persona: mvp)
- verdict: SHIP
- top_issues:
- strongest_counterargument: scope may grow
- confidence: med
- one_line: ship
@@from: occams-razor#r2
POSITION (persona: occams-razor)
- verdict: SHIP-WITH-CHANGES
- top_issues:
- strongest_counterargument: changes may be needless
- confidence: low
- one_line: trim it
EOF
rc=$?
set -e
[ "$rc" -ne 0 ] && [ "$(wc -l < "$MLOG" | tr -d ' ')" = "4" ] || { echo "FAIL: unreceipted strict round did not force a new room"; exit 1; }
set +e
cat <<'EOF' | "$DIR/lib/transcript.sh" capture-positions "$MROOM" >/dev/null 2>&1
@@from: red-team#r1
POSITION (persona: red-team)
- verdict: BLOCK
- top_issues:
- strongest_counterargument: transport may be enough
- confidence: high
- one_line: block
@@from: mvp#r1
POSITION (persona: mvp)
- verdict: SHIP
- top_issues:
- strongest_counterargument: scope may grow
- confidence: med
- one_line: ship
@@from: occams-razor#r1
POSITION (persona: occams-razor)
- verdict: SHIP-WITH-CHANGES
- top_issues:
- strongest_counterargument: changes may be needless
- confidence: low
- one_line: trim it
EOF
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: duplicate strict round accepted"; exit 1; }
printf 'council_artifact_kind: general\nchanged\n' > "$ART"
set +e
"$DIR/lib/council-guard.sh" finish "$MROOM" 1 >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: finish accepted changed artifact"; exit 1; }
printf 'council_artifact_kind: general\nreview this\n' > "$ART"
set +e
printf '@@from: synthesis\nverdict\n' | "$DIR/lib/transcript.sh" capture "$MROOM" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: synthesis before finish accepted"; exit 1; }
"$DIR/lib/council-guard.sh" finish "$MROOM" 1
printf '@@from: synthesis\nverdict\n' | "$DIR/lib/transcript.sh" capture "$MROOM" >/dev/null
printf '@@from: blind-judge#judge-1\nNET_NEW_CATCH: false\n' | "$DIR/lib/transcript.sh" capture "$MROOM" >/dev/null

grep -q '"from":"blind-judge#judge-1"' "$MLOG" || { echo "FAIL: managed room rejected typed judge"; exit 1; }

IROOM=incomplete-room
"$DIR/lib/council-guard.sh" begin "$IROOM" "$ART" ship 'red-team,mvp,occams-razor' >/dev/null
"$DIR/lib/council-guard.sh" state "$IROOM" incomplete
set +e
printf '@@from: red-team#r1\n' | "$DIR/lib/transcript.sh" capture-positions "$IROOM" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: incomplete room accepted position capture"; exit 1; }
set +e
"$DIR/lib/council-guard.sh" finish "$IROOM" 1 >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: incomplete room accepted finish"; exit 1; }
set +e
printf '@@from: synthesis\nverdict\n' | "$DIR/lib/transcript.sh" capture "$IROOM" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: incomplete room accepted synthesis"; exit 1; }
echo "PASS test_transcript"
