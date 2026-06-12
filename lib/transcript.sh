#!/usr/bin/env bash
# Serial JSONL transcript append — agent-chat room format, write-only.
# Usage: transcript.sh append <room> <from> <text>
set -euo pipefail
AGENT_CHAT_ROOT="${AGENT_CHAT_ROOT:-$HOME/.claude/agent-chat}"
ac_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ac_safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64; }

cmd="${1:-}"; shift || true
case "$cmd" in
  append)
    room="$(ac_safe "${1:?room}")"; from="${2:?from}"; text="${3:?text}"
    rd="$AGENT_CHAT_ROOT/rooms/$room"; mkdir -p "$rd"
    line="$(jq -cn --arg ts "$(ac_now)" --arg from "$from" --arg text "$text" \
      '{ts:$ts, from:$from, text:$text}')"
    printf '%s\n' "$line" >> "$rd/log.jsonl"
    ;;
  *) echo "usage: transcript.sh append <room> <from> <text>" >&2; exit 1;;
esac
