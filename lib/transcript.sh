#!/usr/bin/env bash
# Council transcript — agent-chat room JSONL format.
# Usage:
#   transcript.sh append <room> <from> <text>   append one line (text may be a full POSITION block)
#   transcript.sh show   [room]                  pretty-print a room (default: newest)
#   transcript.sh rooms                          list council rooms, newest first
set -euo pipefail
# Default agent-chat root: AGENT_CHAT_ROOT env var if set, else legacy ~/.claude/agent-chat
# if it exists (back-compat), else XDG. Same precedence as journal.sh.
if [ -n "${AGENT_CHAT_ROOT:-}" ]; then :
elif [ -d "$HOME/.claude/agent-chat" ]; then AGENT_CHAT_ROOT="$HOME/.claude/agent-chat"
else AGENT_CHAT_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/agent-fleet/agent-chat"
fi
ROOMS="$AGENT_CHAT_ROOT/rooms"
ac_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ac_safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64; }

cmd="${1:-}"; shift || true
case "$cmd" in
  append)
    room="$(ac_safe "${1:?room}")"; from="${2:?from}"; text="${3:?text}"
    rd="$ROOMS/$room"; mkdir -p "$rd"
    line="$(jq -cn --arg ts "$(ac_now)" --arg from "$from" --arg text "$text" \
      '{ts:$ts, from:$from, text:$text}')"
    printf '%s\n' "$line" >> "$rd/log.jsonl"
    ;;
  capture)
    # Batch-persist ALL positions in ONE call (orchestrator pipes them on stdin).
    # Format: blocks delimited by a line beginning '@@from: <persona>'; everything
    # until the next '@@from:' (or EOF) is that persona's full POSITION text.
    # One call instead of an N-iteration append loop = far harder for the
    # orchestrator to skip (the reliability bug this fixes).
    room="$(ac_safe "${1:?room}")"; rd="$ROOMS/$room"; mkdir -p "$rd"
    _from=""; _buf=""; _n=0
    _flush() {
      [ -n "$_from" ] || return 0
      jq -cn --arg ts "$(ac_now)" --arg from "$_from" --arg text "$_buf" \
        '{ts:$ts, from:$from, text:$text}' >> "$rd/log.jsonl"
      _n=$((_n+1))
    }
    while IFS= read -r ln || [ -n "$ln" ]; do
      case "$ln" in
        "@@from: "*) _flush; _from="${ln#@@from: }"; _buf="" ;;
        *) if [ -z "$_buf" ]; then _buf="$ln"; else _buf="$_buf
$ln"; fi ;;
      esac
    done
    _flush
    [ "$_n" -gt 0 ] || { echo "capture: no '@@from:' blocks on stdin" >&2; exit 1; }
    echo "captured $_n position(s) to room '$room'"
    ;;
  rooms)
    [ -d "$ROOMS" ] || { echo "(no rooms yet)"; exit 0; }
    ls -1t "$ROOMS" 2>/dev/null | sed 's/^/  /' || echo "(no rooms yet)"
    ;;
  show)
    room="${1:-}"
    if [ -z "$room" ]; then room="$(ls -1t "$ROOMS" 2>/dev/null | head -1)"; fi
    [ -n "$room" ] || { echo "(no rooms yet)"; exit 0; }
    room="$(ac_safe "$room")"; log="$ROOMS/$room/log.jsonl"
    [ -f "$log" ] || { echo "no transcript for room '$room'"; exit 1; }
    printf '═══ council transcript: %s ═══\n\n' "$room"
    # emit "round<TAB>from<TAB>ts<TAB>text"; round = trailing #r<digits> on from (else 0).
    # gsub("\n";"\\n"): jq -r decodes \n to REAL newlines, which would break the tab-record parse —
    # re-escape so each log entry stays ONE awk record; awk re-splits on the literal \n.
    # sort: numeric on round (k1), then plain string on from (k2) for deterministic in-round order.
    jq -r '. as $e | ($e.from | capture("#r(?<n>[0-9]+)$").n // "0") as $r
           | "\($r)\t\($e.from|gsub("\t";" "))\t\($e.ts|gsub("\t";" "))\t\($e.text|gsub("\t";" ")|gsub("\n";"\\n"))"' "$log" \
    | sort -s -k1,1n -k2,2 -t$'\t' \
    | awk -F'\t' '
        BEGIN { prev = "" }
        { r=$1; from=$2; gsub(/#r[0-9]+$/,"",from); ts=$3; text=$4
          is_judge = (from ~ /^blind-judge#judge-/)
          if (is_judge) { sub(/^blind-judge#judge-/, "JUDGE ", from) }
          if (r!=prev) { if (r=="0") printf "── round — ──\n"; else printf "── round %s ──\n", r; prev=r }
          if (is_judge) {
            printf "╔═ [⚖ %s]  %s\n", from, ts
            n=split(text, L, /\\n/); for(i=1;i<=n;i++) printf "║ %s\n", L[i]
            printf "╚═\n"
          } else {
            printf "┌─ [%s]  %s\n", from, ts
            n=split(text, L, /\\n/); for(i=1;i<=n;i++) printf "│ %s\n", L[i]
            printf "└─\n"
          }
        }'
    ;;
  *) echo "usage: transcript.sh {append <room> <from> <text> | show [room] | rooms}" >&2; exit 1;;
esac
