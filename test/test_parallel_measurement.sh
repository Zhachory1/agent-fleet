#!/usr/bin/env bash
# Test: #36 parallel-vs-single measurement helper.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
note() { printf '  %s\n' "$*"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export AGENT_CHAT_ROOT="$WORK/agent-chat"
export AGENT_FLEET_JOURNAL="$WORK/journal.jsonl"
STUDY="$WORK/study"

make_room() {
  local room="$1" note="$2"
  mkdir -p "$AGENT_CHAT_ROOT/rooms/$room"
  printf 'artifact for %s\n' "$room" > "$AGENT_CHAT_ROOT/rooms/$room/artifact.txt"
  bash "$DIR/lib/transcript.sh" capture "$room" <<EOF >/dev/null
@@from: red-team#r1
POSITION (persona: red-team)
- verdict: BLOCK
- [MAJOR] $note
@@from: synthesis
Council verdict: BLOCK
EOF
  bash "$DIR/lib/journal.sh" append \
    --room "$room" --task "$room" --solo "ship" --personas "red-team" \
    --net-new-catch true --acted-on true --issues-raised 1 --run-kind design >/dev/null
}

make_room council-pair-1-parallel "parallel finding"
make_room council-pair-1-single "single finding"
printf 'mode-reveal phrase outside log: Task tool\n' >> "$AGENT_CHAT_ROOT/rooms/council-pair-1-single/artifact.txt"

OUT=$(bash "$DIR/lib/parallel-vs-single.sh" anonymize \
  --pair-id 1 --parallel-room council-pair-1-parallel --single-room council-pair-1-single \
  --study-dir "$STUDY" 2>&1)
echo "$OUT" | grep -q 'mapping:' || { echo "FAIL: anonymize did not print mapping path: $OUT"; exit 1; }
note "PASS anonymize prints mapping"
echo "$OUT" | grep -q 'WARN: .*copied content may contain mode-revealing text' \
  || { echo "FAIL: recursive mode-leak warning did not fire for artifact.txt: $OUT"; exit 1; }
note "PASS recursive mode-leak warning scans files beyond log.jsonl"

[ -f "$STUDY/mapping.jsonl" ] || { echo "FAIL: mapping.jsonl missing"; exit 1; }
[ "$(jq -s 'length' "$STUDY/mapping.jsonl")" = "2" ] || { echo "FAIL: expected 2 mapping rows"; exit 1; }
note "PASS mapping has two rows"

parallel_anon=$(jq -r 'select(.mode=="parallel") | .anon_room' "$STUDY/mapping.jsonl")
single_anon=$(jq -r 'select(.mode=="single") | .anon_room' "$STUDY/mapping.jsonl")
[ -d "$AGENT_CHAT_ROOT/rooms/$parallel_anon" ] || { echo "FAIL: parallel anon room missing"; exit 1; }
[ -d "$AGENT_CHAT_ROOT/rooms/$single_anon" ] || { echo "FAIL: single anon room missing"; exit 1; }
case "$parallel_anon $single_anon" in *parallel*|*single*) echo "FAIL: anon room leaked mode names"; exit 1;; esac
note "PASS anonymized rooms created without mode names"

jq -e --arg p "$parallel_anon" --arg s "$single_anon" '
  select(.room==$p or .room==$s) | .task==.room and .judge_blinded==false and .judge_blinded_catch==null
' "$AGENT_FLEET_JOURNAL" >/dev/null || { echo "FAIL: anonymized journal rows not reset for judging or task not anonymized"; exit 1; }
note "PASS anonymized journal rows reset judge fields and task"

# Simulate judged anon rows as sparse appended rows: parallel agrees with self, single disagrees.
jq -cn --arg room "$parallel_anon" '{room:$room, judge_blinded:true, judge_blinded_catch:true, judge_why:"agree"}' >> "$AGENT_FLEET_JOURNAL"
jq -cn --arg room "$single_anon" '{room:$room, judge_blinded:true, judge_blinded_catch:false, judge_why:"disagree"}' >> "$AGENT_FLEET_JOURNAL"

SUMMARY=$(bash "$DIR/lib/parallel-vs-single.sh" analyze --study-dir "$STUDY")
echo "$SUMMARY" | grep -q 'parallel agreement: 1/1' || { echo "FAIL: parallel agreement wrong: $SUMMARY"; exit 1; }
echo "$SUMMARY" | grep -q 'single agreement: 0/1' || { echo "FAIL: single agreement wrong: $SUMMARY"; exit 1; }
echo "$SUMMARY" | grep -q 'complete judged pairs: 1' || { echo "FAIL: complete pairs wrong: $SUMMARY"; exit 1; }
echo "$SUMMARY" | grep -q 'mean paired delta (parallel-single): 100%' || { echo "FAIL: paired delta wrong: $SUMMARY"; exit 1; }
echo "$SUMMARY" | grep -q 'median paired delta (parallel-single): 100%' || { echo "FAIL: median paired delta wrong: $SUMMARY"; exit 1; }
echo "$SUMMARY" | grep -q 'paired distribution: parallel_wins=1, single_wins=0, ties=0' || { echo "FAIL: paired distribution wrong: $SUMMARY"; exit 1; }
note "PASS analyze summarizes agreement and paired delta distribution"

echo "PASS test_parallel_measurement"
