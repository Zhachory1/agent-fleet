#!/usr/bin/env bash
# Counterfactual journal — powers the catch-rate KPI + the kill-gate.
#
# CONTRACT: blind-judge.sh reads judge_* fields from this file's row format.
# Field-name changes to the 13 judge_* fields are breaking changes.
#
# Usage:
#   journal.sh append <room> <task> <solo_decision> <personas_csv> <net_new_catch> <catch_note> \
#                     <acted_on> <dismissed_count> \
#                     [lens_baseline_run] [council_beat_baseline] [issues_raised] [run_kind] \
#                     [--judge-blinded <bool>] [--judge-catch <bool>] [--judge-why <str>] \
#                     [--judge-evidence <str>] [--judge-implied-by <str>] [--judge-reasoning <str>] \
#                     [--judge-dissent-diff <str>] [--judge-model-family <str>] \
#                     [--judge-prompt-version <str>] [--judge-template-sha256 <hex>] \
#                     [--judge-render-sha256 <hex>] [--solo-decision-word-count <int>] \
#                     [--synthesis-word-count <int>]
#   journal.sh append-judge-only <room> <task> --judge-* ...  (judge-only row, self-report=null)
#   journal.sh stats  [N]      summarize last N runs (0/omitted = all) vs the gate
#   journal.sh stats  --judged     show last 5 judged rows (timestamp | self | judge | why | evidence)
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

print_help() {
  cat <<'HELP'
Usage: journal.sh <subcommand> [args]

Subcommands:
  append [options]            record a council run (see below)
  append-judge-only ...       record a judge-only row (used when journal.sh append failed but
                              blind-judge.sh judge ran; writes self-report fields as NULL)
  stats [N]                   print catch-rate / false-alarm / gate verdict (last N runs; 0=all)
  --help                      this message

journal.sh append (kw-args form, PREFERRED):
  --room <slug>                e.g. council-foo
  --task <task>
  --solo <text>                operator's pre-council decision + risks-they-already-saw
  --personas <a,b,c>           comma-separated
  --net-new-catch true|false   did the council surface a net-new issue?
  --acted-on true|false        did the operator act on the council's finding?
  --note <text>                catch-note (optional)
  --dismissed-count <int>      issues raised but dismissed as noise (default 0)
  --lens-baseline true|false   did this run produce a same-lenses single-pass baseline? (default false)
  --council-beat-baseline <bool|null>  did the council beat the baseline? (default null)
  --issues-raised <int>        total issues raised by the council (default 0)
  --run-kind code|design|investigation  (default code)
  --judge-blinded true|false   was this run blinded-judged?
  --judge-catch true|false|null  judge's NET_NEW_CATCH answer
  --judge-why <text>           judge's WHY one-liner
  --judge-evidence <text>      judge's EVIDENCE verbatim quote (when catch=true)
  --judge-implied-by <text>    judge's IMPLIED_BY (when claiming closely-implied)
  --judge-reasoning <text>     judge's REASONING scratchpad (audit-only)
  --judge-dissent-diff <text>  judge's DISSENT_DIFF scratchpad (audit-only)
  --judge-model-family <str>   self-reported model family (claude|gpt|gemini|other|...)
  --judge-prompt-version <vN>  rubric version that was used
  --judge-template-sha256 <hex>  drift-detection hash of the rubric template
  --judge-render-sha256 <hex>    per-call audit hash of the full prepared prompt
  --solo-decision-word-count <int>   confound; auto-computed from --solo if 0
  --synthesis-word-count <int>      confound; auto-computed from transcript if 0

journal.sh append (LEGACY positional form, still supported):
  journal.sh append <room> <task> <solo> <personas> <net_new_catch> <note> \
                    <acted_on> <dismissed_count> \
                    [lens_baseline] [council_beat_baseline] [issues_raised] [run_kind] \
                    [--judge-* kw-args after position 12]
  Up to 12 positional args plus narrow --judge-* extension.

Examples:
  journal.sh append --room council-foo --task foo --solo "ship as-is" \
    --personas ml-scientist,ab-critic --net-new-catch true --acted-on true \
    --issues-raised 3 --run-kind design
HELP
}

# Top-level --help / -h
if [ "$cmd" = "--help" ] || [ "$cmd" = "-h" ]; then print_help; exit 0; fi

case "$cmd" in
  append)
    # Detect invocation style: if the FIRST argument starts with '--', this is a kw-args call.
    # Otherwise it's the legacy 12-positional form. Both shapes set the same internal variables
    # and fall through to the shared validation + write block below. Closes #3.
    room=""; task=""; solo=""; personas=""
    catch=""; note=""; acted=""; dis="0"
    base_run="false"; beat="null"; raised="0"; kind="code"
    judge_blinded=false; judge_catch=null; judge_why=""; judge_evidence=""
    judge_implied_by=""; judge_reasoning=""; judge_dissent_diff=""
    judge_model_family=""; judge_prompt_version=""
    judge_template_sha256=""; judge_render_sha256=""
    solo_wc=0; synth_wc=0

    if [ $# -gt 0 ] && [ "${1#--}" != "$1" ]; then
      # Pure kw-args invocation. Each --flag has a value (no boolean-style --net-new shorthand;
      # value strings stay 'true'/'false' for back-compat with how positional args are passed).
      while [ $# -gt 0 ]; do
        case "$1" in
          --room) room="$2"; shift 2;;
          --task) task="$2"; shift 2;;
          --solo|--solo-decision) solo="$2"; shift 2;;
          --personas) personas="$2"; shift 2;;
          --net-new-catch|--catch) catch="$2"; shift 2;;
          --note|--catch-note) note="$2"; shift 2;;
          --acted-on) acted="$2"; shift 2;;
          --dismissed-count) dis="$2"; shift 2;;
          --lens-baseline|--lens-baseline-run) base_run="$2"; shift 2;;
          --council-beat-baseline) beat="$2"; shift 2;;
          --issues-raised) raised="$2"; shift 2;;
          --run-kind) kind="$2"; shift 2;;
          --judge-blinded) judge_blinded="$2"; shift 2;;
          --judge-catch) judge_catch="$2"; shift 2;;
          --judge-why) judge_why="$2"; shift 2;;
          --judge-evidence) judge_evidence="$2"; shift 2;;
          --judge-implied-by) judge_implied_by="$2"; shift 2;;
          --judge-reasoning) judge_reasoning="$2"; shift 2;;
          --judge-dissent-diff) judge_dissent_diff="$2"; shift 2;;
          --judge-model-family) judge_model_family="$2"; shift 2;;
          --judge-prompt-version) judge_prompt_version="$2"; shift 2;;
          --judge-template-sha256) judge_template_sha256="$2"; shift 2;;
          --judge-render-sha256) judge_render_sha256="$2"; shift 2;;
          --solo-decision-word-count) solo_wc="$2"; shift 2;;
          --synthesis-word-count) synth_wc="$2"; shift 2;;
          --help|-h) print_help; exit 0;;
          *) echo "journal: unknown flag '$1'" >&2; exit 1;;
        esac
      done
      # Validate required fields in kw-args mode
      [ -n "$room" ]    || { echo "journal: --room required" >&2; exit 1; }
      [ -n "$task" ]    || { echo "journal: --task required" >&2; exit 1; }
      [ -n "$solo" ]    || { echo "journal: --solo required" >&2; exit 1; }
      [ -n "$personas" ] || { echo "journal: --personas required" >&2; exit 1; }
      [ -n "$catch" ]   || { echo "journal: --net-new-catch required" >&2; exit 1; }
      [ -n "$acted" ]   || { echo "journal: --acted-on required" >&2; exit 1; }
    else
      # Legacy positional invocation. Asserting #<=24 (12 positional + up to 12 narrow
      # --judge-* kw-args) so a future 13th positional fails loudly instead of being parsed
      # as a kw-args value.
      room="${1:?room (use 'council-<slug>')}"; task="${2:?}"; solo="${3:?}"; personas="${4:?}"
      catch="${5:?}"; note="${6:-}"; acted="${7:?}"; dis="${8:-0}"
      base_run="${9:-false}"; beat="${10:-null}"; raised="${11:-0}"; kind="${12:-code}"
      # Parse --judge-* kw-args AFTER position 12 (narrow scope kept for PLAN Rev 2 callers)
      shift_n=12; [ $# -lt 12 ] && shift_n=$#
      shift $shift_n
      while [ $# -gt 0 ]; do
        case "$1" in
          --judge-blinded) judge_blinded="$2"; shift 2;;
          --judge-catch) judge_catch="$2"; shift 2;;
          --judge-why) judge_why="$2"; shift 2;;
          --judge-evidence) judge_evidence="$2"; shift 2;;
          --judge-implied-by) judge_implied_by="$2"; shift 2;;
          --judge-reasoning) judge_reasoning="$2"; shift 2;;
          --judge-dissent-diff) judge_dissent_diff="$2"; shift 2;;
          --judge-model-family) judge_model_family="$2"; shift 2;;
          --judge-prompt-version) judge_prompt_version="$2"; shift 2;;
          --judge-template-sha256) judge_template_sha256="$2"; shift 2;;
          --judge-render-sha256) judge_render_sha256="$2"; shift 2;;
          --solo-decision-word-count) solo_wc="$2"; shift 2;;
          --synthesis-word-count) synth_wc="$2"; shift 2;;
          *) echo "journal: unknown flag '$1' (legacy positional mode accepts only --judge-* and word-count kw-args)" >&2; exit 1;;
        esac
      done
    fi
    # Auto-compute word counts if not provided (per council MAJOR, data-engineer)
    [ "$solo_wc" -gt 0 ] || solo_wc=$(echo "$solo" | wc -w | tr -d ' ')
    if [ "$synth_wc" -eq 0 ]; then
      ACR="${AGENT_CHAT_ROOT:-$HOME/.claude/agent-chat}"; rlog="$ACR/rooms/$room/log.jsonl"
      if [ -f "$rlog" ]; then
        synth_wc=$(jq -r 'select(.from=="synthesis") | .text' "$rlog" 2>/dev/null | wc -w | tr -d ' ' || echo 0)
      fi
    fi
    # Data-quality invariants (council MAJOR, data-engineer)
    if [ "$judge_blinded" = "false" ]; then
      # judge_blinded=false => all other judge_* fields must be empty/null
      if [ "$judge_catch" != "null" ] || [ -n "$judge_why" ] || [ -n "$judge_evidence" ] || \
         [ -n "$judge_implied_by" ] || [ -n "$judge_reasoning" ] || [ -n "$judge_dissent_diff" ] || \
         [ -n "$judge_model_family" ] || [ -n "$judge_prompt_version" ] || \
         [ -n "$judge_template_sha256" ] || [ -n "$judge_render_sha256" ]; then
        echo "journal: invariant violated — judge_blinded=false but judge_* fields populated" >&2
        exit 1
      fi
    fi
    if [ "$judge_catch" = "true" ] && [ -z "$judge_evidence" ]; then
      echo "journal: invariant violated — judge_blinded_catch=true requires judge_evidence non-empty" >&2
      exit 1
    fi
    if [ "$judge_catch" = "false" ] && [ -n "$judge_evidence" ]; then
      echo "journal: invariant violated — judge_blinded_catch=false requires judge_evidence empty" >&2
      exit 1
    fi
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
    # flock wrapper (Rev 2: added in Chunk 1 per PLAN)
    # Detect flock availability (Linux has it, macOS may need brew install util-linux)
    if command -v flock >/dev/null 2>&1; then
      (
        flock -x 200
        jq -cn --arg ts "$(ac_now)" --arg room "$room" --arg task "$task" --arg solo "$solo" \
          --arg personas "$personas" --argjson catch "$catch" --arg note "$note" \
          --argjson acted "$acted" --argjson dis "$dis" \
          --argjson base_run "$base_run" --argjson beat "$beat" --argjson raised "$raised" \
          --arg kind "$kind" \
          --argjson judge_blinded "$judge_blinded" --argjson judge_catch "$judge_catch" \
          --arg judge_why "$judge_why" --arg judge_evidence "$judge_evidence" \
          --arg judge_implied_by "$judge_implied_by" --arg judge_reasoning "$judge_reasoning" \
          --arg judge_dissent_diff "$judge_dissent_diff" \
          --arg judge_model_family "$judge_model_family" --arg judge_prompt_version "$judge_prompt_version" \
          --arg judge_template_sha256 "$judge_template_sha256" --arg judge_render_sha256 "$judge_render_sha256" \
          --argjson solo_wc "$solo_wc" --argjson synth_wc "$synth_wc" \
          '{ts:$ts, room:$room, task:$task, solo_decision:$solo, personas:($personas|split(",")),
            net_new_catch:$catch, catch_note:$note, acted_on:$acted, dismissed_count:$dis,
            lens_baseline_run:$base_run, council_beat_baseline:$beat, issues_raised:$raised,
            run_kind:$kind, judge_blinded:$judge_blinded, judge_blinded_catch:$judge_catch,
            judge_why:$judge_why, judge_evidence:$judge_evidence, judge_implied_by:$judge_implied_by,
            judge_reasoning:$judge_reasoning, judge_dissent_diff:$judge_dissent_diff,
            judge_model_family_self_reported:$judge_model_family, judge_prompt_version:(if $judge_prompt_version=="" then null else $judge_prompt_version end),
            judge_template_sha256:$judge_template_sha256, judge_render_sha256:$judge_render_sha256,
            solo_decision_word_count:$solo_wc, synthesis_word_count:$synth_wc}' \
          >> "$JOURNAL"
      ) 200>"$JOURNAL.lock"
    else
      # Fallback: no locking (macOS without util-linux)
      jq -cn --arg ts "$(ac_now)" --arg room "$room" --arg task "$task" --arg solo "$solo" \
        --arg personas "$personas" --argjson catch "$catch" --arg note "$note" \
        --argjson acted "$acted" --argjson dis "$dis" \
        --argjson base_run "$base_run" --argjson beat "$beat" --argjson raised "$raised" \
        --arg kind "$kind" \
        --argjson judge_blinded "$judge_blinded" --argjson judge_catch "$judge_catch" \
        --arg judge_why "$judge_why" --arg judge_evidence "$judge_evidence" \
        --arg judge_implied_by "$judge_implied_by" --arg judge_reasoning "$judge_reasoning" \
        --arg judge_dissent_diff "$judge_dissent_diff" \
        --arg judge_model_family "$judge_model_family" --arg judge_prompt_version "$judge_prompt_version" \
        --arg judge_template_sha256 "$judge_template_sha256" --arg judge_render_sha256 "$judge_render_sha256" \
        --argjson solo_wc "$solo_wc" --argjson synth_wc "$synth_wc" \
        '{ts:$ts, room:$room, task:$task, solo_decision:$solo, personas:($personas|split(",")),
          net_new_catch:$catch, catch_note:$note, acted_on:$acted, dismissed_count:$dis,
          lens_baseline_run:$base_run, council_beat_baseline:$beat, issues_raised:$raised,
          run_kind:$kind, judge_blinded:$judge_blinded, judge_blinded_catch:$judge_catch,
          judge_why:$judge_why, judge_evidence:$judge_evidence, judge_implied_by:$judge_implied_by,
          judge_reasoning:$judge_reasoning, judge_dissent_diff:$judge_dissent_diff,
          judge_model_family_self_reported:$judge_model_family, judge_prompt_version:(if $judge_prompt_version=="" then null else $judge_prompt_version end),
          judge_template_sha256:$judge_template_sha256, judge_render_sha256:$judge_render_sha256,
          solo_decision_word_count:$solo_wc, synthesis_word_count:$synth_wc}' \
        >> "$JOURNAL"
    fi
    ;;
  append-judge-only)
    # Judge-only row: write a fresh row with all self-report fields NULL, only judge_* fields populated.
    # Used when step 2 (journal.sh append) failed but step 3 (blind-judge.sh judge) still ran.
    room="${1:?room}"; task="${2:?task}"
    shift 2 || true
    # Parse --judge-* kw-args (same parser as append)
    judge_blinded=false; judge_catch=null; judge_why=""; judge_evidence=""
    judge_implied_by=""; judge_reasoning=""; judge_dissent_diff=""
    judge_model_family=""; judge_prompt_version=""
    judge_template_sha256=""; judge_render_sha256=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --judge-blinded) judge_blinded="$2"; shift 2;;
        --judge-catch) judge_catch="$2"; shift 2;;
        --judge-why) judge_why="$2"; shift 2;;
        --judge-evidence) judge_evidence="$2"; shift 2;;
        --judge-implied-by) judge_implied_by="$2"; shift 2;;
        --judge-reasoning) judge_reasoning="$2"; shift 2;;
        --judge-dissent-diff) judge_dissent_diff="$2"; shift 2;;
        --judge-model-family) judge_model_family="$2"; shift 2;;
        --judge-prompt-version) judge_prompt_version="$2"; shift 2;;
        --judge-template-sha256) judge_template_sha256="$2"; shift 2;;
        --judge-render-sha256) judge_render_sha256="$2"; shift 2;;
        *) echo "journal: unknown flag '$1' (append-judge-only accepts only --judge-* flags)" >&2; exit 1;;
      esac
    done
    # Data-quality invariants (same as append)
    if [ "$judge_blinded" = "false" ]; then
      if [ "$judge_catch" != "null" ] || [ -n "$judge_why" ] || [ -n "$judge_evidence" ] || \
         [ -n "$judge_implied_by" ] || [ -n "$judge_reasoning" ] || [ -n "$judge_dissent_diff" ] || \
         [ -n "$judge_model_family" ] || [ -n "$judge_prompt_version" ] || \
         [ -n "$judge_template_sha256" ] || [ -n "$judge_render_sha256" ]; then
        echo "journal: invariant violated — judge_blinded=false but judge_* fields populated" >&2
        exit 1
      fi
    fi
    if [ "$judge_catch" = "true" ] && [ -z "$judge_evidence" ]; then
      echo "journal: invariant violated — judge_blinded_catch=true requires judge_evidence non-empty" >&2
      exit 1
    fi
    if [ "$judge_catch" = "false" ] && [ -n "$judge_evidence" ]; then
      echo "journal: invariant violated — judge_blinded_catch=false requires judge_evidence empty" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$JOURNAL")"
    # flock wrapper
    if command -v flock >/dev/null 2>&1; then
      (
        flock -x 200
        jq -cn --arg ts "$(ac_now)" --arg room "$room" --arg task "$task" \
          --argjson judge_blinded "$judge_blinded" --argjson judge_catch "$judge_catch" \
          --arg judge_why "$judge_why" --arg judge_evidence "$judge_evidence" \
          --arg judge_implied_by "$judge_implied_by" --arg judge_reasoning "$judge_reasoning" \
          --arg judge_dissent_diff "$judge_dissent_diff" \
          --arg judge_model_family "$judge_model_family" --arg judge_prompt_version "$judge_prompt_version" \
          --arg judge_template_sha256 "$judge_template_sha256" --arg judge_render_sha256 "$judge_render_sha256" \
          '{ts:$ts, room:$room, task:$task, solo_decision:null, personas:null,
            net_new_catch:null, catch_note:null, acted_on:null, dismissed_count:null,
            lens_baseline_run:null, council_beat_baseline:null, issues_raised:null,
            run_kind:null, judge_blinded:$judge_blinded, judge_blinded_catch:$judge_catch,
            judge_why:$judge_why, judge_evidence:$judge_evidence, judge_implied_by:$judge_implied_by,
            judge_reasoning:$judge_reasoning, judge_dissent_diff:$judge_dissent_diff,
            judge_model_family_self_reported:$judge_model_family, judge_prompt_version:(if $judge_prompt_version=="" then null else $judge_prompt_version end),
            judge_template_sha256:$judge_template_sha256, judge_render_sha256:$judge_render_sha256,
            solo_decision_word_count:null, synthesis_word_count:null}' \
          >> "$JOURNAL"
      ) 200>"$JOURNAL.lock"
    else
      jq -cn --arg ts "$(ac_now)" --arg room "$room" --arg task "$task" \
        --argjson judge_blinded "$judge_blinded" --argjson judge_catch "$judge_catch" \
        --arg judge_why "$judge_why" --arg judge_evidence "$judge_evidence" \
        --arg judge_implied_by "$judge_implied_by" --arg judge_reasoning "$judge_reasoning" \
        --arg judge_dissent_diff "$judge_dissent_diff" \
        --arg judge_model_family "$judge_model_family" --arg judge_prompt_version "$judge_prompt_version" \
        --arg judge_template_sha256 "$judge_template_sha256" --arg judge_render_sha256 "$judge_render_sha256" \
        '{ts:$ts, room:$room, task:$task, solo_decision:null, personas:null,
          net_new_catch:null, catch_note:null, acted_on:null, dismissed_count:null,
          lens_baseline_run:null, council_beat_baseline:null, issues_raised:null,
          run_kind:null, judge_blinded:$judge_blinded, judge_blinded_catch:$judge_catch,
          judge_why:$judge_why, judge_evidence:$judge_evidence, judge_implied_by:$judge_implied_by,
          judge_reasoning:$judge_reasoning, judge_dissent_diff:$judge_dissent_diff,
          judge_model_family_self_reported:$judge_model_family, judge_prompt_version:(if $judge_prompt_version=="" then null else $judge_prompt_version end),
          judge_template_sha256:$judge_template_sha256, judge_render_sha256:$judge_render_sha256,
          solo_decision_word_count:null, synthesis_word_count:null}' \
        >> "$JOURNAL"
    fi
    ;;
  stats)
    flag="${1:-}"
    if [ "$flag" = "--judged" ]; then
      # Show last 5 judged rows as table
      [ -f "$JOURNAL" ] || { echo "no judged rows yet"; exit 0; }
      jq -r '. + {judge_blinded: (.judge_blinded // false),
                   judge_blinded_catch: (.judge_blinded_catch // null),
                   net_new_catch: (.net_new_catch // null),
                   judge_why: (.judge_why // ""),
                   judge_evidence: (.judge_evidence // "")} |
             select(.judge_blinded==true) |
             [.ts[0:10], (.net_new_catch|tostring), (.judge_blinded_catch|tostring),
              .judge_why, .judge_evidence] | @tsv' "$JOURNAL" \
        | tail -5 \
        | { printf "timestamp\tself_catch\tjudge_catch\twhy\tevidence\n"; cat; }
      exit 0
    fi
    n="$flag"
    [ -z "$n" ] && n=0 || :
    [ -f "$JOURNAL" ] || { echo "no journal yet at $JOURNAL"; exit 0; }
    jq -rs --argjson n "$n" '
      (if $n > 0 then .[-$n:] else . end) as $r
      | ($r | length) as $t
      | if $t == 0 then "no runs logged yet" else
        # backward-compat: rows logged before run_kind existed default to "code";
        # rows before judge_blinded existed default to judge_blinded=false
        ([$r[] | . + {run_kind: (.run_kind // "code"),
                      judge_blinded: (.judge_blinded // false),
                      judge_blinded_catch: (.judge_blinded_catch // null),
                      net_new_catch: (.net_new_catch // null)}]) as $r
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
        # blinded-judge arm (Rev 3 schema)
        ([$r[]|select(.judge_blinded==true)]|length) as $judged
      | ([$r[]|select(.judge_blinded==true and .net_new_catch!=null)]|length) as $judged_with_self
      | ([$r[]|select(.judge_blinded==true and .net_new_catch!=null and .net_new_catch==.judge_blinded_catch)]|length) as $agree
      | ([$r[]|select(.judge_blinded==true and .net_new_catch==null)]|length) as $judge_only
      | (if $judged>0 then ((($judged/$t)*100)|floor) else 0 end) as $judged_pct
      | (if $judged_with_self>0 then ((($agree/$judged_with_self)*100)|floor) else -1 end) as $agree_pct
      | "blinded-judge sample : \($judged) of \($t) runs judged = \($judged_pct)%",
        (if $judged<5 then "self-vs-blind        : [calibration phase — \($judged)/5 Phase 1, dual-judging required via --phase1 judge-a|judge-b]"
         elif $judged<50 then "self-vs-blind        : \($agree)/\($judged_with_self) agree = \($agree_pct)%   [Phase 2: \($judged)/50 judged]"
         else "self-vs-blind        : \($agree)/\($judged_with_self) agree = \($agree_pct)%   [bands: heuristic-pending-recalibration]"
         end),
        (if $judge_only>0 then "judge-only rows     : \($judge_only)" else empty end),
        "runs by kind       : code=\($cN), design=\($dN), investigation=\($invN)",
        "",
        "verdict: \(if $t<20 then "keep going — \(20-$t) more run(s) to the gate" elif $bgate=="INSUFFICIENT" then "INSUFFICIENT BASELINE DATA — council cannot be judged until \(10-$bruns) more lens-baseline run(s) (gate needs n≥10)" elif $catchpct>=40 and ($fapct<50 or $fapct<0) and $bgate=="PASS" then "KEEP — council earns its cost" else "KILL CANDIDATE — collapse to a single lens-prompt" end)"
      end' "$JOURNAL"
    ;;
  *) echo "usage: journal.sh {append ... | stats [N]}" >&2; exit 1;;
esac
