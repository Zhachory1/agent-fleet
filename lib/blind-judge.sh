#!/usr/bin/env bash
# Blinded-judge sample mechanism. Spec: docs/features/blinded-judge/{PRD,DD,PLAN}.md (Rev 3).
#
# Subcommands:
#   prepare <room> [--phase1 judge-a|judge-b]            assemble 5 blobs, render against rubric, clipboard+banner
#   record  <room> --catch ... --why ... [more flags]    validate + write judge_* fields + transcript line
#   judge   <room> [--phase1 ...]                        prepare + 10min stdin wait + parse + record
#   backfill-artifact <room> --from <path>               rescue legacy rooms predating FR9 (deferred to PR C)
#   parse   <response-file> <op-synthesis-file>          stand-alone parser for testing
#
# Bash + jq + flock + sha256sum. No new runtime dep.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_CHAT_ROOT="${AGENT_CHAT_ROOT:-$HOME/.claude/agent-chat}"
AGENT_FLEET_JOURNAL="${AGENT_FLEET_JOURNAL:-$HOME/.claude/agent-fleet-journal.jsonl}"

die() { printf 'blind-judge: %s\n' "$*" >&2; exit 1; }

# Portable advisory lock using mkdir (atomic on POSIX). flock isn't on mac by default.
# Usage: acquire_lock <lockdir>; ... ; release_lock <lockdir>
# Waits up to 30s, then dies.
acquire_lock() {
  local lockdir="$1"
  local waited=0
  while ! mkdir "$lockdir" 2>/dev/null; do
    sleep 0.05
    waited=$((waited + 1))
    if [ "$waited" -gt 600 ]; then
      die "timed out acquiring lock $lockdir"
    fi
  done
  trap 'rmdir "'"$lockdir"'" 2>/dev/null || true' EXIT
}
release_lock() {
  local lockdir="$1"
  rmdir "$lockdir" 2>/dev/null || true
  trap - EXIT
}

# extract_field BLOCK FIELD STOP_REGEX -> stdout. STOP_REGEX is an awk alternation pattern of
# field-name-prefixes (without colons) that should terminate the capture. The sentinel ===END===
# is matched as its own anchored pattern (it has no trailing colon, unlike the field prefixes).
# Empty STOP_REGEX is allowed (terminate at ===END=== only). Collapses internal newlines to
# single spaces in the captured value.
extract_field() {
  local block="$1" field="$2" stop_re="$3"
  local stop_pat
  # Two stop patterns: field-name-with-colon-prefix OR ===END=== sentinel.
  if [ -n "$stop_re" ]; then
    stop_pat="^(${stop_re}):|^===END===\$"
  else
    stop_pat='^===END===$'
  fi
  awk -v F="^${field}:" -v S="$stop_pat" '
    $0 ~ F  { flag=1; sub(F"[ \t]*", ""); print; next }
    $0 ~ S  { flag=0 }
    flag    { print }
  ' <<<"$block" | tr '\n' ' ' | tr -s '[:space:]' ' ' | sed 's/[[:space:]]*$//'
}

# parse_response RESPONSE_TEXT OPERATOR_SYNTHESIS -> outputs 6 lines: catch, why, evidence, implied_by, reasoning, dissent_diff
parse_response() {
  local resp="$1" op_synth="$2"
  grep -q '^===JUDGE OUTPUT===$' <<<"$resp" || die "missing ===JUDGE OUTPUT=== sentinel"
  grep -q '^===END===$' <<<"$resp"           || die "missing ===END=== sentinel"
  local block
  block=$(sed -n '/^===JUDGE OUTPUT===$/,/^===END===$/p' <<<"$resp" | sed '1d;$d')

  local reasoning dissent_diff catch why evidence implied_by
  reasoning=$(extract_field "$block" REASONING 'DISSENT_DIFF|NET_NEW_CATCH|WHY|EVIDENCE|IMPLIED_BY')
  [ -n "$reasoning" ] || die "REASONING field required (multi-step materiality test cannot be zero-shot)"
  dissent_diff=$(extract_field "$block" DISSENT_DIFF 'NET_NEW_CATCH|WHY|EVIDENCE|IMPLIED_BY')
  [ -n "$dissent_diff" ] || die "DISSENT_DIFF field required (use '- (none)' if no erasures found)"

  # NET_NEW_CATCH: whitespace + case tolerant
  catch=$(awk -F'[: \t]+' '/^NET_NEW_CATCH:/ {print tolower($2); exit}' <<<"$block" | tr -d '[:space:]')
  case "$catch" in true|false) ;; *) die "NET_NEW_CATCH must be 'true' or 'false', got: '$catch'";; esac

  why=$(extract_field "$block" WHY 'EVIDENCE|IMPLIED_BY')
  [ -n "$why" ] || die "WHY field required"

  evidence=$(extract_field "$block" EVIDENCE 'IMPLIED_BY')
  if [ "$catch" = "true" ] && [ -z "$evidence" ]; then
    die "EVIDENCE required when NET_NEW_CATCH=true (must quote verbatim line from PERSONA_POSITIONS)"
  fi
  if [ "$catch" = "false" ] && [ -n "$evidence" ]; then
    die "EVIDENCE must be empty when NET_NEW_CATCH=false (got: $evidence)"
  fi
  # Self-quote guard (Gemini's BLOCKER fix, hardened post-/code-review):
  # EVIDENCE must not appear AS A SUBSTRING of OPERATOR_SYNTHESIS. Using -F (not -Fx) catches
  # the case where the operator's framing covers the same finding in slightly different words
  # and the judge quotes the shared phrase. Exact-line check (-Fx) only catches a full-line copy.
  if [ -n "$evidence" ] && [ -n "$op_synth" ]; then
    if grep -qF -- "$evidence" <<<"$op_synth"; then
      die "EVIDENCE appears in OPERATOR_SYNTHESIS ('$evidence'); must quote PERSONA_POSITIONS only"
    fi
  fi

  implied_by=$(extract_field "$block" IMPLIED_BY '')
  if [ "$catch" = "false" ] && [[ "$why" =~ (implied|already.named|already.covered) ]]; then
    [ -n "$implied_by" ] || die "IMPLIED_BY required when WHY claims SOLO_DECISION already covered the finding"
  fi

  printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$catch" "$why" "$evidence" "$implied_by" "$reasoning" "$dissent_diff"
}

# count_judged_rows -> integer; 0 if journal missing
count_judged_rows() {
  [ -f "$AGENT_FLEET_JOURNAL" ] || { echo 0; return; }
  jq -s '[.[] | select((.judge_blinded // false) == true)] | length' "$AGENT_FLEET_JOURNAL" 2>/dev/null || echo 0
}

# count_judge_b_rows -> integer; how many rows have phase1==judge-b recorded
# (we store phase1 in the transcript as part of @@from: blind-judge#judge-N#judge-X tag,
#  but for now the helper records phase1 in a journal field `judge_phase1` ad-hoc; see record())
count_distinct_judged_rooms() {
  [ -f "$AGENT_FLEET_JOURNAL" ] || { echo 0; return; }
  jq -s '[.[] | select((.judge_blinded // false) == true) | .room] | unique | length' "$AGENT_FLEET_JOURNAL" 2>/dev/null || echo 0
}
count_judge_b_rows() {
  [ -f "$AGENT_FLEET_JOURNAL" ] || { echo 0; return; }
  jq -s '[.[] | select((.judge_blinded // false) == true and (.judge_phase1 // "") == "judge-b")] | length' "$AGENT_FLEET_JOURNAL" 2>/dev/null || echo 0
}

# resolve_artifact ROOM -> stdout the artifact content; die on unresolvable pointer.
resolve_artifact() {
  local room="$1"
  local artifact_path="$AGENT_CHAT_ROOT/rooms/$room/artifact.txt"
  [ -f "$artifact_path" ] || die "no artifact in room '$room'; orchestrator did not persist it (FR9). Re-run the council (backfill-artifact deferred to PR C)."
  local content
  content=$(<"$artifact_path")
  if [[ "$content" =~ ^@file:\ (.+)$ ]]; then
    local file_path="${BASH_REMATCH[1]}"
    [ -f "$file_path" ] || die "artifact pointer @file: $file_path is not resolvable; refuse (would be confabulation surface)"
    cat "$file_path"
  elif [[ "$content" =~ ^@diff:\ (.+)$ ]]; then
    local diff_ref="${BASH_REMATCH[1]}"
    git show "$diff_ref" 2>/dev/null || die "artifact pointer @diff: $diff_ref failed (git show); refuse (would be confabulation surface)"
  else
    printf '%s' "$content"
  fi
}

# extract_persona_positions ROOM_LOG -> stdout: all '@@from: <persona>#r<N>' position blocks
extract_persona_positions() {
  local room_log="$1"
  jq -r 'select(.from | test("#r[0-9]+$")) | "@@from: \(.from)\n\(.text)\n"' "$room_log" 2>/dev/null
}

# extract_operator_synthesis ROOM_LOG -> stdout: the synthesis block (last @@from: synthesis entry)
extract_operator_synthesis() {
  local room_log="$1"
  jq -rs '[.[] | select(.from=="synthesis")] | last | (.text // "")' "$room_log" 2>/dev/null
}

# enforce_phase1 PHASE1_FLAG  -> die if forcing rule violated
enforce_phase1() {
  local phase1="$1"
  local judged_count distinct_rooms judge_b_count
  judged_count=$(count_judged_rows)
  if [ "$judged_count" -lt 5 ]; then
    if [ -z "$phase1" ] || { [ "$phase1" != "judge-a" ] && [ "$phase1" != "judge-b" ]; }; then
      die "REFUSES: --phase1 judge-a|judge-b required during Phase 1 (judged_count=$judged_count/5)"
    fi
    if [ "$judged_count" -eq 4 ]; then
      distinct_rooms=$(count_distinct_judged_rooms)
      judge_b_count=$(count_judge_b_rows)
      if [ "$distinct_rooms" -lt 4 ]; then
        echo "blind-judge: WARNING after this run Phase 1 has <5 distinct rooms (sequencing-exploit shape)" >&2
      fi
      if [ "$phase1" = "judge-a" ] && [ "$judge_b_count" -lt 3 ]; then
        die "REFUSES: Phase 1 needs >=3 judge-b runs by run 5; you passed --phase1 judge-a with only $judge_b_count judge-b so far"
      fi
    fi
  else
    [ -n "$phase1" ] && die "REFUSES: --phase1 may not be used after Phase 1 (judged_count=$judged_count, max 5)"
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  prepare)
    room="${1:?room}"; shift || true
    phase1=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --phase1) phase1="$2"; shift 2;;
        --synthesis) shift 2;;
        *) die "unknown flag '$1'";;
      esac
    done
    enforce_phase1 "$phase1"

    artifact_content=$(resolve_artifact "$room")
    room_log="$AGENT_CHAT_ROOT/rooms/$room/log.jsonl"
    [ -f "$room_log" ] || die "no transcript for room '$room'"

    [ -f "$AGENT_FLEET_JOURNAL" ] && [ -s "$AGENT_FLEET_JOURNAL" ] || die "no journal row for room '$room'"
    row=$(jq -c --arg room "$room" 'select(.room==$room)' "$AGENT_FLEET_JOURNAL" | tail -1)
    [ -n "$row" ] || die "no journal row for room '$room'; run journal.sh append first"
    SOLO_DECISION=$(jq -r '.solo_decision // ""' <<<"$row")
    [ -n "$SOLO_DECISION" ] || die "no solo_decision in journal for room '$room'"
    PERSONA_LIST=$(jq -r '.personas // [] | join(", ")' <<<"$row")
    PERSONA_POSITIONS=$(extract_persona_positions "$room_log")
    OPERATOR_SYNTHESIS=$(extract_operator_synthesis "$room_log")

    rubric_file="$DIR/blind-judge-prompt.v2.txt"
    [ -f "$rubric_file" ] || die "rubric file missing: $rubric_file"
    template=$(<"$rubric_file")

    rendered="$template"
    rendered="${rendered//\{ARTIFACT\}/$artifact_content}"
    rendered="${rendered//\{SOLO_DECISION\}/$SOLO_DECISION}"
    rendered="${rendered//\{PERSONA_POSITIONS\}/$PERSONA_POSITIONS}"
    rendered="${rendered//\{OPERATOR_SYNTHESIS\}/$OPERATOR_SYNTHESIS}"
    rendered="${rendered//\{PERSONA_LIST\}/$PERSONA_LIST}"

    judge_template_sha256=$(sha256sum "$rubric_file" | awk '{print $1}')
    judge_render_sha256=$(printf '%s' "$rendered" | sha256sum | awk '{print $1}')

    if [ -z "${SSH_CONNECTION:-}" ]; then
      if command -v pbcopy >/dev/null 2>&1; then
        printf '%s' "$rendered" | pbcopy
      elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$rendered" | xclip -selection clipboard
      fi
    fi

    echo "judge_template_sha256: $judge_template_sha256"
    echo "judge_render_sha256: $judge_render_sha256"
    echo ""
    cat <<'BANNER'
⚠ SWITCH CONTEXTS NOW
   Open a NEW chat in a DIFFERENT account, or a DIFFERENT model family
   (Claude/GPT/Gemini/Llama/Mistral/...) — different model family + different
   account = strongest blinding. Same-family fresh-account is OK but inherits
   family-level biases.

   Prompt has been copied to your clipboard (pbcopy/xclip).
   Paste it. Then come back and paste the response below.

   Format expected:
       ===JUDGE OUTPUT===
       REASONING: ...
       DISSENT_DIFF: ...
       NET_NEW_CATCH: true|false
       WHY: ...
       EVIDENCE: ... (if NET_NEW_CATCH=true; from PERSONA_POSITIONS only)
       IMPLIED_BY: ... (if NET_NEW_CATCH=false and WHY claims implication)
       ===END===

BANNER
    printf '%s\n' "$rendered"
    ;;

  parse)
    # parse <response-file> <operator-synthesis-file>  — for testing
    rf="${1:?response file}"; of="${2:?operator-synthesis file}"
    [ -f "$rf" ] || die "no response file: $rf"
    [ -f "$of" ] || die "no operator-synthesis file: $of"
    parse_response "$(<"$rf")" "$(<"$of")"
    ;;

  record)
    room="${1:?room}"; shift || true
    catch=""; why=""; evidence=""; implied_by=""; reasoning=""; dissent_diff=""
    model_family=""; prompt_version="v2"; template_sha=""; render_sha=""
    phase1=""; force=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --catch)            catch="$2"; shift 2;;
        --why)              why="$2"; shift 2;;
        --evidence)         evidence="$2"; shift 2;;
        --implied-by)       implied_by="$2"; shift 2;;
        --reasoning)        reasoning="$2"; shift 2;;
        --dissent-diff)     dissent_diff="$2"; shift 2;;
        --model-family)     model_family="$2"; shift 2;;
        --prompt-version)   prompt_version="$2"; shift 2;;
        --template-sha256)  template_sha="$2"; shift 2;;
        --render-sha256)    render_sha="$2"; shift 2;;
        --phase1)           phase1="$2"; shift 2;;
        --force)            force=1; shift;;
        *) die "unknown flag '$1'";;
      esac
    done
    [ -n "$catch" ] || die "--catch required"
    case "$catch" in true|false) ;; *) die "--catch must be 'true' or 'false'";; esac
    [ -n "$why" ] || die "--why required"
    [ -n "$reasoning" ] || die "--reasoning required (parser-enforced)"
    [ -n "$dissent_diff" ] || die "--dissent-diff required (use '- (none)' if no erasures)"
    if [ "$catch" = "true" ] && [ -z "$evidence" ]; then
      die "--evidence required when --catch=true"
    fi
    if [ "$catch" = "false" ] && [ -n "$evidence" ]; then
      die "--evidence must be empty when --catch=false"
    fi
    # EVIDENCE self-quote guard
    if [ -n "$evidence" ]; then
      room_log="$AGENT_CHAT_ROOT/rooms/$room/log.jsonl"
      [ -f "$room_log" ] || die "no transcript for room '$room'"
      op_synth=$(extract_operator_synthesis "$room_log")
      if [ -n "$op_synth" ] && grep -qFx -- "$evidence" <<<"$op_synth"; then
        die "EVIDENCE quotes OPERATOR_SYNTHESIS verbatim; must quote PERSONA_POSITIONS only"
      fi
    fi

    # Lock the journal for the read-check + write (portable: mkdir-based)
    lockdir="${AGENT_FLEET_JOURNAL}.lockdir"
    mkdir -p "$(dirname "$lockdir")"
    acquire_lock "$lockdir"

    # Find existing row for this room (latest)
    existing=""
    if [ -f "$AGENT_FLEET_JOURNAL" ] && [ -s "$AGENT_FLEET_JOURNAL" ]; then
      existing=$(jq -c --arg r "$room" 'select(.room==$r)' "$AGENT_FLEET_JOURNAL" | tail -1)
    fi
    if [ -n "$existing" ]; then
      prior_judged=$(jq -r '.judge_blinded // false' <<<"$existing")
      prior_catch=$(jq -r '.judge_blinded_catch // "null"' <<<"$existing")
      if [ "$prior_judged" = "true" ] && [ "$prior_catch" != "$catch" ] && [ "$prior_catch" != "null" ] && [ "$force" != "1" ]; then
        die "room '$room' already has judge_blinded_catch=$prior_catch; rerunning with $catch — pass --force to override"
      fi
      # Mutate in place: rewrite the journal with this row's judge_* fields updated.
      tmp=$(mktemp)
      jq -c --arg r "$room" \
        --argjson catch "$catch" \
        --arg why "$why" \
        --arg ev "$evidence" \
        --arg ib "$implied_by" \
        --arg reas "$reasoning" \
        --arg dd "$dissent_diff" \
        --arg mf "$model_family" \
        --arg pv "$prompt_version" \
        --arg tsh "$template_sha" \
        --arg rsh "$render_sha" \
        --arg p1 "$phase1" \
        'if .room==$r and ((.judge_blinded // false) != true)
           then . + {judge_blinded:true, judge_blinded_catch:$catch, judge_why:$why,
                    judge_evidence:$ev, judge_implied_by:$ib, judge_reasoning:$reas,
                    judge_dissent_diff:$dd, judge_model_family_self_reported:$mf,
                    judge_prompt_version:$pv, judge_template_sha256:$tsh,
                    judge_render_sha256:$rsh, judge_phase1:$p1}
         elif .room==$r and ((.judge_blinded // false) == true)
           then . + {judge_blinded:true, judge_blinded_catch:$catch, judge_why:$why,
                    judge_evidence:$ev, judge_implied_by:$ib, judge_reasoning:$reas,
                    judge_dissent_diff:$dd, judge_model_family_self_reported:$mf,
                    judge_prompt_version:$pv, judge_template_sha256:$tsh,
                    judge_render_sha256:$rsh, judge_phase1:$p1}
         else . end' "$AGENT_FLEET_JOURNAL" > "$tmp"
      mv "$tmp" "$AGENT_FLEET_JOURNAL"
    else
      # No row exists — write a judge-only row (FR8 step-3-when-step-2-failed)
      jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg room "$room" \
        --argjson catch "$catch" \
        --arg why "$why" --arg ev "$evidence" --arg ib "$implied_by" \
        --arg reas "$reasoning" --arg dd "$dissent_diff" \
        --arg mf "$model_family" --arg pv "$prompt_version" \
        --arg tsh "$template_sha" --arg rsh "$render_sha" --arg p1 "$phase1" \
        '{ts:$ts, room:$room, task:"", solo_decision:null, personas:[],
          net_new_catch:null, catch_note:"", acted_on:null, dismissed_count:0,
          lens_baseline_run:false, council_beat_baseline:null, issues_raised:0,
          run_kind:"code",
          judge_blinded:true, judge_blinded_catch:$catch, judge_why:$why,
          judge_evidence:$ev, judge_implied_by:$ib, judge_reasoning:$reas,
          judge_dissent_diff:$dd, judge_model_family_self_reported:$mf,
          judge_prompt_version:$pv, judge_template_sha256:$tsh,
          judge_render_sha256:$rsh, judge_phase1:$p1,
          solo_decision_word_count:0, synthesis_word_count:0}' \
        >> "$AGENT_FLEET_JOURNAL"
    fi
    release_lock "$lockdir"

    # Append @@from: blind-judge#judge-N to room transcript
    room_log="$AGENT_CHAT_ROOT/rooms/$room/log.jsonl"
    judge_n=1
    if [ -f "$room_log" ]; then
      prior=$(grep -c '"from":"blind-judge#judge-' "$room_log" 2>/dev/null) || prior=0
      judge_n=$((prior + 1))
    fi
    summary=$(printf 'NET_NEW_CATCH: %s\nWHY: %s' "$catch" "$why")
    [ -n "$evidence" ] && summary+=$'\nEVIDENCE: '"$evidence"
    [ -n "$implied_by" ] && summary+=$'\nIMPLIED_BY: '"$implied_by"
    bash "$DIR/transcript.sh" capture "$room" <<EOF >/dev/null
@@from: blind-judge#judge-$judge_n
$summary
EOF
    echo "recorded judge-$judge_n (catch=$catch) for room '$room'"
    ;;

  judge)
    room="${1:?room}"; shift || true
    phase1=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --phase1) phase1="$2"; shift 2;;
        *) die "unknown flag '$1'";;
      esac
    done
    # Prepare prints to stdout; we want it printed PLUS the operator pastes the response on stdin
    if [ -n "$phase1" ]; then
      "$0" prepare "$room" --phase1 "$phase1"
    else
      "$0" prepare "$room"
    fi
    echo ""
    echo "Paste the judge response below (ending with ===END===), then Ctrl-D:"
    response=$(cat)
    room_log="$AGENT_CHAT_ROOT/rooms/$room/log.jsonl"
    op_synth=$(extract_operator_synthesis "$room_log")
    parsed=$(parse_response "$response" "$op_synth")
    catch=$(sed -n '1p' <<<"$parsed")
    why=$(sed -n '2p' <<<"$parsed")
    evidence=$(sed -n '3p' <<<"$parsed")
    implied_by=$(sed -n '4p' <<<"$parsed")
    reasoning=$(sed -n '5p' <<<"$parsed")
    dissent_diff=$(sed -n '6p' <<<"$parsed")

    rec_args=("$room" --catch "$catch" --why "$why" --reasoning "$reasoning" --dissent-diff "$dissent_diff")
    [ -n "$evidence" ]   && rec_args+=(--evidence "$evidence")
    [ -n "$implied_by" ] && rec_args+=(--implied-by "$implied_by")
    [ -n "$phase1" ]     && rec_args+=(--phase1 "$phase1")
    "$0" record "${rec_args[@]}"
    ;;

  backfill-artifact)
    die "not implemented in PR B; see PR C / Chunk 5"
    ;;

  *)
    die "usage: blind-judge.sh {prepare|record|judge|parse|backfill-artifact} <room> [...]"
    ;;
esac
