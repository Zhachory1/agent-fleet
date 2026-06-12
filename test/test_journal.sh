#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export AGENT_FLEET_JOURNAL="$(mktemp -d)/journal.jsonl"
"$DIR/lib/journal.sh" append "review-model-x" "ship as-is" "ml-scientist,ab-critic" true "missed skew" true 1
[ -f "$AGENT_FLEET_JOURNAL" ] || { echo "FAIL: no journal"; exit 1; }
jq -e '.net_new_catch==true and .acted_on==true and .dismissed_count==1' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: fields wrong"; exit 1; }
echo "PASS test_journal"
