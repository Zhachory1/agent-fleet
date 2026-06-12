#!/usr/bin/env bash
# Counterfactual journal append — powers the catch-rate KPI.
# Usage: journal.sh append <task> <solo_decision> <personas_csv> <net_new_catch> \
#                          <catch_note> <acted_on> <dismissed_count> \
#                          [lens_baseline_run] [council_beat_baseline]
#
# lens_baseline_run     (bool, default false): did this run ALSO generate a single-context
#                       baseline prompted with the SAME lenses, to test "do the lenses help"
#                       (the honest null hypothesis) rather than "do multiple agents help"?
# council_beat_baseline (bool|null, default null): did the multi-persona council produce a
#                       net-new catch the lens-baseline did NOT? null when no baseline was run.
set -euo pipefail
JOURNAL="${AGENT_FLEET_JOURNAL:-$HOME/.claude/agent-fleet-journal.jsonl}"
ac_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
cmd="${1:-}"; shift || true
case "$cmd" in
  append)
    task="${1:?}"; solo="${2:?}"; personas="${3:?}"; catch="${4:?}"; note="${5:-}"; acted="${6:?}"; dis="${7:-0}"
    base_run="${8:-false}"; beat="${9:-null}"
    mkdir -p "$(dirname "$JOURNAL")"
    jq -cn --arg ts "$(ac_now)" --arg task "$task" --arg solo "$solo" \
      --arg personas "$personas" --argjson catch "$catch" --arg note "$note" \
      --argjson acted "$acted" --argjson dis "$dis" \
      --argjson base_run "$base_run" --argjson beat "$beat" \
      '{ts:$ts, task:$task, solo_decision:$solo, personas:($personas|split(",")),
        net_new_catch:$catch, catch_note:$note, acted_on:$acted, dismissed_count:$dis,
        lens_baseline_run:$base_run, council_beat_baseline:$beat}' \
      >> "$JOURNAL"
    ;;
  *) echo "usage: journal.sh append ... [lens_baseline_run] [council_beat_baseline]" >&2; exit 1;;
esac
