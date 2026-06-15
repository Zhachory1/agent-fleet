#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export AGENT_CHAT_ROOT="$(mktemp -d)"
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
echo "PASS test_transcript"
