#!/usr/bin/env bash
# Counterfactual journal — powers the catch-rate KPI + the kill-gate.
# Usage:
#   journal.sh append <room> <task> <solo_decision> <personas_csv> <net_new_catch> <catch_note> \
#                     <acted_on> <dismissed_count> \
#                     [lens_baseline_run] [council_beat_baseline] [issues_raised] [run_kind]
#   journal.sh stats  [N]      summarize last N runs (0/omitted = all) vs the gate
#
# GUARD: append REFUSES (exit 2) unless room '<room>' has a non-empty transcript — you cannot
#        journal a run whose thinking was not captured (this is what silently failed on real
#        runs). Capture first: `transcript.sh capture <room> <<EOF ... EOF`.
#        Override only for tests: AGENT_FLEET_REQUIRE_TRANSCRIPT=0.
#
# lens_baseline_run     (bool, default false): did this run ALSO produce a single-context
#                       baseline with the SAME lenses, to test "do the lenses help" (honest null)
#                       rather than "do multiple agents help"?
# council_beat_baseline (bool|null, default null): did the council add a net-new catch the
#                       lens-baseline did NOT? null when no baseline was run.
# issues_raised         (int, default 0): how many issues the council raised total — denominator
#                       for false-alarm rate (= dismissed / raised).
# run_kind              (string, default "code"): one of code | investigation | design.
#                       Investigations naturally produce many hypotheses that are NOT all acted on
#                       — separating them keeps the acted-on rate honest. Code/design runs are
#                       counted in the actionable arm; investigations are tracked separately.
set -euo pipefail
JOURNAL="${AGENT_FLEET_JOURNAL:-$HOME/.claude/agent-fleet-journal.jsonl}"
ac_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
cmd="${1:-}"; shift || true
case "$cmd" in
  append)
    room="${1:?room (use 'council-<slug>')}"; task="${2:?}"; solo="${3:?}"; personas="${4:?}"
    catch="${5:?}"; note="${6:-}"; acted="${7:?}"; dis="${8:-0}"
    base_run="${9:-false}"; beat="${10:-null}"; raised="${11:-0}"; kind="${12:-code}"
    case "$kind" in code|investigation|design) ;; *) echo "journal: invalid run_kind '$kind' (want code|investigation|design)" >&2; exit 1;; esac
    # GUARD: no transcript -> no journal. Prevents the 'journaled but skipped capture' data loss.
    if [ "${AGENT_FLEET_REQUIRE_TRANSCRIPT:-1}" = "1" ]; then
      ACR="${AGENT_CHAT_ROOT:-$HOME/.claude/agent-chat}"; rlog="$ACR/rooms/$room/log.jsonl"
      if [ ! -s "$rlog" ]; then
        {
          echo "journal: REFUSING — no transcript for room '$room' ($rlog)."
          echo "  Capture the council's full positions FIRST:"
          echo "    bash $(dirname "$0")/transcript.sh capture $room <<'EOF' ... EOF"
          echo "  then re-run this journal append. (test-only override: AGENT_FLEET_REQUIRE_TRANSCRIPT=0)"
        } >&2
        exit 2
      fi
    fi
    mkdir -p "$(dirname "$JOURNAL")"
    jq -cn --arg ts "$(ac_now)" --arg room "$room" --arg task "$task" --arg solo "$solo" \
      --arg personas "$personas" --argjson catch "$catch" --arg note "$note" \
      --argjson acted "$acted" --argjson dis "$dis" \
      --argjson base_run "$base_run" --argjson beat "$beat" --argjson raised "$raised" \
      --arg kind "$kind" \
      '{ts:$ts, room:$room, task:$task, solo_decision:$solo, personas:($personas|split(",")),
        net_new_catch:$catch, catch_note:$note, acted_on:$acted, dismissed_count:$dis,
        lens_baseline_run:$base_run, council_beat_baseline:$beat, issues_raised:$raised,
        run_kind:$kind}' \
      >> "$JOURNAL"
    ;;
  stats)
    n="${1:-0}"
    [ -f "$JOURNAL" ] || { echo "no journal yet at $JOURNAL"; exit 0; }
    jq -rs --argjson n "$n" '
      (if $n > 0 then .[-$n:] else . end) as $r
      | ($r | length) as $t
      | if $t == 0 then "no runs logged yet" else
        # backward-compat: rows logged before run_kind existed default to "code"
        ([$r[] | . + {run_kind: (.run_kind // "code")}]) as $r
      | ([$r[]|select(.net_new_catch)]|length) as $catches
      | ([$r[]|.dismissed_count // 0]|add) as $dis
      | ([$r[]|.issues_raised // 0]|add) as $raised
      | ([$r[]|select(.lens_baseline_run==true)]|length) as $bruns
      | ([$r[]|select(.council_beat_baseline==true)]|length) as $bwins
      | ([$r[]|select(.run_kind=="code" or .run_kind=="design")]) as $act
      | ([$r[]|select(.run_kind=="investigation")]) as $inv
      | ($act|length) as $actN
      | ($inv|length) as $invN
      | ([$act[]|select(.acted_on)]|length) as $actWins
      | ([$inv[]|select(.acted_on)]|length) as $invWins
      | ([$r[]|select(.run_kind=="code")]|length) as $cN
      | ([$r[]|select(.run_kind=="design")]|length) as $dN
      | (($catches/$t)*100|floor) as $catchpct
      | (if $raised>0 then (($dis/$raised)*100|floor) else -1 end) as $fapct
      | "═══ council journal — last \($t) run(s) ═══",
        "net-new catch rate : \($catches)/\($t) = \($catchpct)%   [gate ≥40%: \(if $catchpct>=40 then "PASS ✓" else "FAIL ✗" end)]",
        "acted-on (code+design): \(if $actN>0 then "\($actWins)/\($actN) = \((($actWins/$actN)*100|floor))%" else "n/a (no code/design runs)" end)",
        "hypotheses pursued (investigations): \(if $invN>0 then "\($invWins)/\($invN) = \((($invWins/$invN)*100|floor))%   (no gate — investigations surface many hypotheses by design)" else "n/a (no investigation runs)" end)",
        "false-alarm rate   : \(if $fapct>=0 then "\($dis)/\($raised) issues dismissed = \($fapct)%   [gate <50%: \(if $fapct<50 then "PASS ✓" else "FAIL ✗" end)]" else "n/a (no issues_raised logged)" end)",
        # lens-baseline gate: require bruns>=10 AND bwins/bruns >= 0.4. A single cherry-picked
        # baseline-win (bwins>0) is NOT enough — p-hacking shape flagged by the council self-review.
        # Until bruns>=10 the arm is INSUFFICIENT, not pass/fail.
        (if $bruns>0 then (($bwins/$bruns)*100|floor) else -1 end) as $bpct
      | (if $bruns>=10 and $bpct>=40 then "PASS"
         elif $bruns>=10 then "FAIL"
         else "INSUFFICIENT" end) as $bgate
      | "lens-baseline arm  : \($bwins)/\($bruns) council beat same-lenses single pass\(if $bruns==0 then " (⚠ unrun — you are testing 'agents' not 'lenses')" elif $bgate=="INSUFFICIENT" then "   [gate needs n≥10: INSUFFICIENT ⚠]" else "   [gate n≥10 & ≥40%: \($bgate) \(if $bgate=="PASS" then "✓" else "✗" end)]" end)",
        "runs by kind       : code=\($cN), design=\($dN), investigation=\($invN)",
        "",
        "verdict: \(if $t<20 then "keep going — \(20-$t) more run(s) to the gate" elif $bgate=="INSUFFICIENT" then "INSUFFICIENT BASELINE DATA — council cannot be judged until \(10-$bruns) more lens-baseline run(s) (gate needs n≥10)" elif $catchpct>=40 and ($fapct<50 or $fapct<0) and $bgate=="PASS" then "KEEP — council earns its cost" else "KILL CANDIDATE — collapse to a single lens-prompt" end)"
      end' "$JOURNAL"
    ;;
  *) echo "usage: journal.sh {append ... | stats [N]}" >&2; exit 1;;
esac
