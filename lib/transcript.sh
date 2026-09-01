#!/usr/bin/env bash
# Council transcript — agent-chat room JSONL format.
set -euo pipefail
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-V" ]; then
  cat "$(dirname "$0")/../VERSION" 2>/dev/null || echo unknown; exit 0
fi
command -v jq >/dev/null 2>&1 || { echo "transcript.sh: jq required (install: brew install jq | apt-get install jq)" >&2; exit 1; }
if [ -n "${AGENT_CHAT_ROOT:-}" ]; then :
elif [ -d "$HOME/.claude/agent-chat" ]; then AGENT_CHAT_ROOT="$HOME/.claude/agent-chat"
else AGENT_CHAT_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/agent-fleet/agent-chat"
fi
ROOMS="$AGENT_CHAT_ROOT/rooms"
DIR="$(cd "$(dirname "$0")" && pwd)"
ac_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ac_safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64; }
manifest() { printf '%s/%s/manifest.json' "$ROOMS" "$1"; }
managed_entry_allowed() {
  local room="$1" from="$2" text="$3" mf
  mf="$(manifest "$room")"
  [ -f "$mf" ] || return 0
  if [ "$from" = synthesis ]; then
    jq -e '.state == "complete"' "$mf" >/dev/null || { echo "capture: synthesis requires complete manifest" >&2; return 1; }
    return 0
  fi
  if [[ "$from" =~ ^blind-judge#judge-[1-9][0-9]*$ ]]; then return 0; fi
  if [[ "$from" =~ \#r[0-9]+$ ]] \
    || jq -e --arg from "$from" '.personas | index($from) != null' "$mf" >/dev/null \
    || grep -qE '^[[:space:]]*POSITION \(persona:' <<<"$text"; then
    echo "capture: managed rooms require capture-positions for persona evidence" >&2
    return 1
  fi
}
room_lock() {
  local rd="$1"
  local lockdir="$rd/.manifest.lockdir" waited=0
  while ! mkdir "$lockdir" 2>/dev/null; do
    sleep 0.05
    waited=$((waited + 1))
    [ "$waited" -lt 600 ] || { echo "capture: timed out acquiring room lock" >&2; exit 1; }
  done
  printf '%s' "$lockdir"
}
release_room_lock() { rmdir "$1" 2>/dev/null || true; }

cmd="${1:-}"; shift || true
case "$cmd" in
  append)
    room="$(ac_safe "${1:?room}")"; from="${2:?from}"; text="${3:?text}"
    managed_entry_allowed "$room" "$from" "$text"
    rd="$ROOMS/$room"; mkdir -p "$rd"
    jq -cn --arg ts "$(ac_now)" --arg from "$from" --arg text "$text" '{ts:$ts, from:$from, text:$text}' >> "$rd/log.jsonl"
    ;;
  capture)
    room="$(ac_safe "${1:?room}")"; rd="$ROOMS/$room"; mkdir -p "$rd"
    tmp="$(mktemp "$rd/.capture.XXXXXX")"; trap 'rm -f "$tmp"' EXIT
    _from=""; _buf=""; _n=0
    _flush() {
      [ -n "$_from" ] || return 0
      managed_entry_allowed "$room" "$_from" "$_buf" || exit 1
      jq -cn --arg ts "$(ac_now)" --arg from "$_from" --arg text "$_buf" '{ts:$ts, from:$from, text:$text}' >> "$tmp"
      _n=$((_n + 1))
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
    cat "$tmp" >> "$rd/log.jsonl"
    rm -f "$tmp"; trap - EXIT
    echo "captured $_n entry(s) to room '$room'"
    ;;
  capture-positions)
    room="$(ac_safe "${1:?room}")"; rd="$ROOMS/$room"; mf="$(manifest "$room")"
    [ -f "$mf" ] || { echo "capture-positions: no manifest for room '$room'" >&2; exit 1; }
    jq -e '.state == "pending" or .state == "running"' "$mf" >/dev/null || { echo "capture-positions: room is not captureable" >&2; exit 1; }
    roster="$(jq -c '.personas' "$mf")"; tmp="$(mktemp "$rd/.positions.XXXXXX")"; trap 'rm -f "$tmp"' EXIT
    _from=""; _buf=""; _n=0; _round=""; _seen=""
    _flush_position() {
      local persona round
      [ -n "$_from" ] || return 0
      [[ "$_from" =~ ^([A-Za-z0-9._-]+)#r([1-9][0-9]*)$ ]] || { echo "capture-positions: invalid sender '$_from'" >&2; exit 1; }
      persona="${BASH_REMATCH[1]}"; round="${BASH_REMATCH[2]}"
      jq -e --arg persona "$persona" '.personas | index($persona) != null' "$mf" >/dev/null || { echo "capture-positions: unknown persona '$persona'" >&2; exit 1; }
      case "|$_seen|" in *"|$_from|"*) echo "capture-positions: duplicate persona '$persona'" >&2; exit 1;; esac
      _seen="$_seen|$_from"
      [ -z "$_round" ] && _round="$round"
      [ "$_round" = "$round" ] || { echo "capture-positions: mixed rounds" >&2; exit 1; }
      "$DIR/council-guard.sh" position "$persona" <<<"$_buf" >/dev/null 2>&1 || { echo "capture-positions: invalid POSITION for '$persona'" >&2; exit 1; }
      jq -cn --arg ts "$(ac_now)" --arg from "$_from" --arg text "$_buf" '{ts:$ts, from:$from, text:$text}' >> "$tmp"
      _n=$((_n + 1))
    }
    while IFS= read -r ln || [ -n "$ln" ]; do
      case "$ln" in
        "@@from: "*) _flush_position; _from="${ln#@@from: }"; _buf="" ;;
        *) if [ -z "$_buf" ]; then _buf="$ln"; else _buf="$_buf
$ln"; fi ;;
      esac
    done
    _flush_position
    [ "$_n" -gt 0 ] || { echo "capture-positions: no '@@from:' blocks on stdin" >&2; exit 1; }
    [ "$_n" -eq "$(jq 'length' <<<"$roster")" ] || { echo "capture-positions: missing required persona" >&2; exit 1; }
    lockdir="$(room_lock "$rd")"
    jq -e '(.state == "pending" or .state == "running")' "$mf" >/dev/null || { release_room_lock "$lockdir"; echo "capture-positions: room is not captureable" >&2; exit 1; }
    jq -e --argjson round "$_round" 'any(.rounds[]?; .round == $round)' "$mf" >/dev/null && { release_room_lock "$lockdir"; echo "capture-positions: round already captured" >&2; exit 1; }
    if [ -f "$rd/log.jsonl" ] && jq -e --argjson round "$_round" 'select(.from | test("#r" + ($round|tostring) + "$"))' "$rd/log.jsonl" >/dev/null; then
      release_room_lock "$lockdir"; echo "capture-positions: unreceipted rows exist for round $_round; use a new room" >&2; exit 1
    fi
    cat "$tmp" >> "$rd/log.jsonl"
    jq --arg ts "$(ac_now)" --argjson round "$_round" --argjson personas "$roster" '.state="running" | .rounds += [{round:$round, personas:$personas, captured_at:$ts}]' "$mf" > "$mf.tmp"
    mv "$mf.tmp" "$mf"
    release_room_lock "$lockdir"
    rm -f "$tmp"; trap - EXIT
    echo "captured $_n strict position(s) for round $_round to room '$room'"
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
    jq -r '. as $e | ($e.from | capture("#r(?<n>[0-9]+)$").n // "0") as $r | "\($r)\t\($e.from|gsub("\t";" "))\t\($e.ts|gsub("\t";" "))\t\($e.text|gsub("\t";" ")|gsub("\n";"\\n"))"' "$log" \
    | sort -s -k1,1n -k2,2 -t$'\t' \
    | awk -F'\t' '
        BEGIN { prev = "" }
        { r=$1; from=$2; gsub(/#r[0-9]+$/, "", from); ts=$3; text=$4
          is_judge = (from ~ /^blind-judge#judge-/)
          if (is_judge) { sub(/^blind-judge#judge-/, "JUDGE ", from) }
          if (r!=prev) { if (r=="0") printf "── round — ──\n"; else printf "── round %s ──\n", r; prev=r }
          if (is_judge) { printf "╔═ [⚖ %s]  %s\n", from, ts; n=split(text,L,/\\n/); for(i=1;i<=n;i++) printf "║ %s\n",L[i]; printf "╚═\n" }
          else { printf "┌─ [%s]  %s\n",from,ts; n=split(text,L,/\\n/); for(i=1;i<=n;i++) printf "│ %s\n",L[i]; printf "└─\n" }
        }'
    ;;
  *) echo "usage: transcript.sh {append <room> <from> <text> | capture <room> | capture-positions <room> | show [room] | rooms}" >&2; exit 1;;
esac
