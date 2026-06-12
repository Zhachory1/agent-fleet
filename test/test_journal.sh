#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export AGENT_CHAT_ROOT="$(mktemp -d)"
export AGENT_FLEET_JOURNAL="$(mktemp -d)/journal.jsonl"
ROOM="council-review-model-x"

# GUARD: append must REFUSE (exit 2) when the room has no transcript
set +e
"$DIR/lib/journal.sh" append "$ROOM" "review-model-x" "ship as-is" "ml-scientist,ab-critic" true "missed skew" true 1 2>/dev/null
rc=$?; set -e
[ "$rc" = "2" ] || { echo "FAIL: journal should refuse (exit 2) without transcript, got $rc"; exit 1; }
[ ! -s "$AGENT_FLEET_JOURNAL" ] || { echo "FAIL: journal wrote a line despite no transcript"; exit 1; }

# capture a transcript -> now append succeeds
printf '@@from: ml-scientist\nverdict: BLOCK\n- [BLOCKER] skew\n' | "$DIR/lib/transcript.sh" capture "$ROOM"
"$DIR/lib/journal.sh" append "$ROOM" "review-model-x" "ship as-is" "ml-scientist,ab-critic" true "missed skew" true 1
[ -s "$AGENT_FLEET_JOURNAL" ] || { echo "FAIL: journal not written after capture"; exit 1; }
jq -e '.room=="'"$ROOM"'" and .net_new_catch==true and .acted_on==true and .dismissed_count==1' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: fields wrong"; exit 1; }
# backward-compat defaults for the new optional fields
jq -e '.lens_baseline_run==false and .council_beat_baseline==null and .issues_raised==0' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: new-field defaults wrong"; exit 1; }

# full call with baseline + issues_raised (same room, already has transcript)
"$DIR/lib/journal.sh" append "$ROOM" "t2" "solo" "red-team" true "n" true 2 true true 5
jq -se '.[1] | .lens_baseline_run==true and .council_beat_baseline==true and .issues_raised==5' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: full-arg fields wrong"; exit 1; }

# test override lets append through with no transcript (for harnesses/tests)
export AGENT_FLEET_REQUIRE_TRANSCRIPT=0
"$DIR/lib/journal.sh" append "council-no-room" "t3" "solo" "ml-scientist" false "n" false 0 \
  || { echo "FAIL: override should allow append without transcript"; exit 1; }
unset AGENT_FLEET_REQUIRE_TRANSCRIPT

# stats: 3 runs, 2 catches -> 66% PASS; false-alarm (1+2+0)/(0+5+0)=3/5
OUT="$("$DIR/lib/journal.sh" stats)"
echo "$OUT" | grep -q "net-new catch rate : 2/3" || { echo "FAIL: stats catch count wrong: $OUT"; exit 1; }
echo "$OUT" | grep -q "gate ≥40%: PASS" || { echo "FAIL: stats gate not PASS"; exit 1; }
echo "$OUT" | grep -q "false-alarm rate   : 3/5" || { echo "FAIL: stats false-alarm denom wrong: $OUT"; exit 1; }

# empty journal -> graceful
export AGENT_FLEET_JOURNAL="$(mktemp -d)/empty.jsonl"; touch "$AGENT_FLEET_JOURNAL"
"$DIR/lib/journal.sh" stats | grep -q "no runs logged yet" || { echo "FAIL: empty-journal stats not graceful"; exit 1; }
echo "PASS test_journal"
