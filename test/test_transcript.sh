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
echo "PASS test_transcript"
