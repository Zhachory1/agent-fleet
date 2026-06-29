#!/usr/bin/env bash
# Helper for docs/measurement/parallel-vs-single-context.md (#36).
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "parallel-vs-single.sh: jq required" >&2; exit 1; }
DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_STUDY_DIR="$DIR/docs/measurement/parallel-vs-single-data"

if [ -n "${AGENT_CHAT_ROOT:-}" ]; then :
elif [ -d "$HOME/.claude/agent-chat" ]; then AGENT_CHAT_ROOT="$HOME/.claude/agent-chat"
else AGENT_CHAT_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/agent-fleet/agent-chat"
fi
if [ -n "${AGENT_FLEET_JOURNAL:-}" ]; then JOURNAL="$AGENT_FLEET_JOURNAL"
elif [ -f "$HOME/.claude/agent-fleet-journal.jsonl" ]; then JOURNAL="$HOME/.claude/agent-fleet-journal.jsonl"
else JOURNAL="${XDG_DATA_HOME:-$HOME/.local/share}/agent-fleet/journal.jsonl"
fi

usage() {
  cat <<'HELP'
Usage:
  parallel-vs-single.sh anonymize --pair-id <id> --parallel-room <room> --single-room <room> [--study-dir DIR]
  parallel-vs-single.sh analyze [--study-dir DIR]

anonymize:
  Copies the two source rooms to anonymized room names and appends cloned journal rows
  with judge_* fields reset. Then run blind-judge.sh judge against the anonymized rooms.

analyze:
  Reads <study-dir>/mapping.jsonl plus AGENT_FLEET_JOURNAL and prints agreement by mode.
HELP
}

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
safe_id() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-40; }
rand8() { printf '%s:%s:%s:%s:%s\n' "$1" "$2" "$$" "$(date +%s)" "$RANDOM" | cksum | awk '{printf "%08x", $1}'; }
die() { echo "parallel-vs-single: $*" >&2; exit 1; }

study_dir="$DEFAULT_STUDY_DIR"
cmd="${1:-}"; shift || true
case "$cmd" in
  --help|-h|"") usage; [ -n "$cmd" ] || exit 1; exit 0;;
  anonymize)
    pair_id=""; parallel_room=""; single_room=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --pair-id) pair_id="$(safe_id "$2")"; shift 2;;
        --parallel-room) parallel_room="$2"; shift 2;;
        --single-room) single_room="$2"; shift 2;;
        --study-dir) study_dir="$2"; shift 2;;
        *) die "unknown flag '$1'";;
      esac
    done
    [ -n "$pair_id" ] || die "--pair-id required"
    [ -n "$parallel_room" ] || die "--parallel-room required"
    [ -n "$single_room" ] || die "--single-room required"
    [ -f "$JOURNAL" ] && [ -s "$JOURNAL" ] || die "journal not found or empty: $JOURNAL"
    mkdir -p "$study_dir"
    map_file="$study_dir/mapping.jsonl"
    staged_journal=$(mktemp)
    staged_map=$(mktemp)
    trap 'rm -f "$staged_journal" "$staged_map"' EXIT

    for mode in parallel single; do
      if [ "$mode" = "parallel" ]; then src_room="$parallel_room"; else src_room="$single_room"; fi
      src_dir="$AGENT_CHAT_ROOT/rooms/$src_room"
      [ -d "$src_dir" ] || die "room not found: $src_room ($src_dir)"
      [ -f "$src_dir/log.jsonl" ] || die "room has no log.jsonl: $src_room"
      row=$(jq -c --arg r "$src_room" 'select(.room==$r)' "$JOURNAL" | tail -n 1)
      [ -n "$row" ] || die "no journal row for room: $src_room"

      anon_room="council-paired-${pair_id}-anon-$(rand8 "$pair_id" "$mode")"
      dst_dir="$AGENT_CHAT_ROOT/rooms/$anon_room"
      [ ! -e "$dst_dir" ] || die "anonymized room already exists: $anon_room (remove it manually before rerunning)"
      mkdir -p "$(dirname "$dst_dir")"
      cp -R "$src_dir" "$dst_dir"
      find "$dst_dir" -name '*.lockdir' -type d -prune -exec rm -rf {} + 2>/dev/null || true

      if grep -rEiq 'parallel-subagent|single-context|Task tool|Codex|Cursor IDE|Claude Code' "$dst_dir"; then
        echo "WARN: $anon_room copied content may contain mode-revealing text; inspect before judging" >&2
      fi

      jq -c --arg room "$anon_room" --arg ts "$(now_utc)" \
        '. + {ts:$ts, room:$room, task:$room, judge_blinded:false, judge_blinded_catch:null,
              judge_why:"", judge_evidence:"", judge_implied_by:"", judge_reasoning:"",
              judge_dissent_diff:"", judge_model_family_self_reported:"",
              judge_prompt_version:"", judge_template_sha256:"", judge_render_sha256:"",
              judge_phase1:""}' <<<"$row" >> "$staged_journal"

      jq -cn --arg pair_id "$pair_id" --arg mode "$mode" --arg original_room "$src_room" \
        --arg anon_room "$anon_room" --arg created_at "$(now_utc)" \
        '{pair_id:$pair_id, mode:$mode, original_room:$original_room,
          anon_room:$anon_room, created_at:$created_at}' >> "$staged_map"
      echo "$mode: $src_room -> $anon_room"
    done
    cat "$staged_journal" >> "$JOURNAL"
    cat "$staged_map" >> "$map_file"
    echo "mapping: $map_file"
    echo "next: bash lib/blind-judge.sh judge <anon_room> for each anonymized room"
    ;;

  analyze)
    while [ $# -gt 0 ]; do
      case "$1" in
        --study-dir) study_dir="$2"; shift 2;;
        *) die "unknown flag '$1'";;
      esac
    done
    map_file="$study_dir/mapping.jsonl"
    [ -f "$map_file" ] || die "mapping file not found: $map_file"
    [ -f "$JOURNAL" ] && [ -s "$JOURNAL" ] || die "journal not found or empty: $JOURNAL"
    jq -nr --slurpfile map "$map_file" --slurpfile rows "$JOURNAL" '
      def merged($room): ([$rows[] | select(.room==$room)] | reduce .[] as $r ({}; . + $r));
      def boolstr($v): if $v == null then "pending" else ($v|tostring) end;
      ($map | unique_by(.anon_room)) as $m
      | [$m[] | . as $x | (merged($x.anon_room)) as $r
          | {pair_id:$x.pair_id, mode:$x.mode, anon_room:$x.anon_room,
             original_room:$x.original_room,
             self:(if ($r|has("net_new_catch")) then $r.net_new_catch else null end),
             judge:(if (($r.judge_blinded // false) == true)
                    then (if ($r|has("judge_blinded_catch")) then $r.judge_blinded_catch else null end)
                    else null end)}
          | . + {agreement:(if (.self == null or .judge == null) then null else (.self == .judge) end)}] as $runs
      | "# parallel-vs-single measurement summary",
        "",
        "| pair | mode | self | judge | agree | anon_room |",
        "|---|---|---:|---:|---:|---|",
        ($runs[] | "| \(.pair_id) | \(.mode) | \(boolstr(.self)) | \(boolstr(.judge)) | \(boolstr(.agreement)) | `\(.anon_room)` |"),
        "",
        ([$runs[] | select(.mode=="parallel" and .agreement!=null)] | length) as $pn
      | ([$runs[] | select(.mode=="parallel" and .agreement==true)] | length) as $pa
      | ([$runs[] | select(.mode=="single" and .agreement!=null)] | length) as $sn
      | ([$runs[] | select(.mode=="single" and .agreement==true)] | length) as $sa
      | "parallel agreement: \($pa)/\($pn)",
        "single agreement: \($sa)/\($sn)",
        "",
        ([$runs | group_by(.pair_id)[]
          | (map(select(.mode=="parallel")) | length) as $pc
          | (map(select(.mode=="single")) | length) as $sc
          | if length == 2 and $pc == 1 and $sc == 1 and all(.agreement != null) then
              {pair_id:.[0].pair_id,
               delta: ((map(select(.mode=="parallel"))[0].agreement | if . then 1 else 0 end) -
                       (map(select(.mode=="single"))[0].agreement | if . then 1 else 0 end))}
            else empty end]) as $pairs
      | "complete judged pairs: \($pairs|length)",
        (if ($pairs|length)>0 then
           ([$pairs[].delta] | sort) as $deltas
           | ($deltas | length) as $dn
           | (($deltas[(($dn - 1) / 2 | floor)] + $deltas[($dn / 2 | floor)]) / 2) as $median
           | "mean paired delta (parallel-single): \((([$pairs[].delta] | add) / ($pairs | length)) * 100)%",
             "median paired delta (parallel-single): \($median * 100)%",
             "paired distribution: parallel_wins=\(([$pairs[] | select(.delta==1)] | length)), single_wins=\(([$pairs[] | select(.delta==-1)] | length)), ties=\(([$pairs[] | select(.delta==0)] | length))"
         else
           "mean paired delta (parallel-single): pending",
           "median paired delta (parallel-single): pending",
           "paired distribution: pending"
         end)
    '
    ;;
  *) die "unknown subcommand '$cmd' (try --help)";;
esac
