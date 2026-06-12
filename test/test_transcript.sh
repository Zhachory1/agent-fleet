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
echo "PASS test_transcript"
