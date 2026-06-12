#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export AGENT_FLEET_JOURNAL="$(mktemp -d)/journal.jsonl"
"$DIR/lib/journal.sh" append "review-model-x" "ship as-is" "ml-scientist,ab-critic" true "missed skew" true 1
[ -f "$AGENT_FLEET_JOURNAL" ] || { echo "FAIL: no journal"; exit 1; }
jq -e '.net_new_catch==true and .acted_on==true and .dismissed_count==1' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: fields wrong"; exit 1; }
# backward-compat: 7-arg call defaults the new fields
jq -e '.lens_baseline_run==false and .council_beat_baseline==null and .issues_raised==0' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: new-field defaults wrong"; exit 1; }
# full call with baseline + issues_raised
"$DIR/lib/journal.sh" append "t2" "solo" "red-team" true "n" true 2 true true 5
jq -se '.[1] | .lens_baseline_run==true and .council_beat_baseline==true and .issues_raised==5' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: full-arg fields wrong"; exit 1; }
# stats: catch rate 2/2=100% PASS gate; false-alarm (1+2)/(0+5)=60%? -> dismissed 1+2=3 raised 0+5=5 = 60% FAIL
OUT="$("$DIR/lib/journal.sh" stats)"
echo "$OUT" | grep -q "net-new catch rate : 2/2" || { echo "FAIL: stats catch count wrong: $OUT"; exit 1; }
echo "$OUT" | grep -q "gate ≥40%: PASS" || { echo "FAIL: stats gate not PASS"; exit 1; }
echo "$OUT" | grep -q "false-alarm rate   : 3/5" || { echo "FAIL: stats false-alarm denom wrong: $OUT"; exit 1; }
# empty journal → graceful
export AGENT_FLEET_JOURNAL="$(mktemp -d)/empty.jsonl"; touch "$AGENT_FLEET_JOURNAL"
"$DIR/lib/journal.sh" stats | grep -q "no runs logged yet" || { echo "FAIL: empty-journal stats not graceful"; exit 1; }
echo "PASS test_journal"
