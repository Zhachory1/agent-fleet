#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-V" ]; then
  cat "$(dirname "$0")/../VERSION" 2>/dev/null || echo unknown; exit 0
fi
command -v jq >/dev/null 2>&1 || { echo "council-guard: jq required" >&2; exit 1; }

if [ -n "${AGENT_CHAT_ROOT:-}" ]; then :
elif [ -d "$HOME/.claude/agent-chat" ]; then AGENT_CHAT_ROOT="$HOME/.claude/agent-chat"
else AGENT_CHAT_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/agent-fleet/agent-chat"
fi
ROOMS="$AGENT_CHAT_ROOT/rooms"

safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1"; else sha256sum "$1"; fi | awk '{print $1}'
}

lock() {
  local d="$1/.manifest.lockdir" waited=0
  while ! mkdir "$d" 2>/dev/null; do
    sleep 0.05
    waited=$((waited + 1))
    [ "$waited" -lt 600 ] || { echo "council-guard: timed out acquiring room lock" >&2; exit 1; }
  done
  printf '%s' "$d"
}
unlock() { rmdir "$1" 2>/dev/null || true; }

artifact() {
  local file="${1:?artifact path}" kind field
  [ -f "$file" ] || { echo "NEED-MORE-INFO: artifact not found" >&2; return 1; }
  case "$(head -n1 "$file")" in
    'council_artifact_kind: infrastructure') kind=infrastructure;;
    'council_artifact_kind: general') kind=general;;
    *) echo "NEED-MORE-INFO: first line must declare council_artifact_kind" >&2; return 1;;
  esac
  [ "$(grep -c '^council_artifact_kind:' "$file" || true)" -eq 1 ] || { echo "NEED-MORE-INFO: artifact kind must appear exactly once" >&2; return 1; }
  if [ "$kind" = infrastructure ]; then
    grep -qx '## Capability Reuse Inventory' "$file" || { echo "NEED-MORE-INFO: missing Capability Reuse Inventory" >&2; return 1; }
    while IFS= read -r field; do
      grep -Eq "^- $field:[[:space:]]*[^[:space:]]" "$file" || { echo "NEED-MORE-INFO: inventory field '$field' is required" >&2; return 1; }
    done <<'EOF'
plausible existing capabilities
owner/source of truth
current consumers
access contract
evidence for rejection
EOF
  fi
  jq -cn --arg kind "$kind" --arg sha "$(sha256 "$file")" '{kind:$kind, artifact_sha256:$sha, inventory_valid:true}'
}

begin() {
  local room
  room="$(safe "${1:?room}")"
  local artifact_file="${2:?artifact path}" mode="${3:?mode}" csv="${4:?personas csv}"
  local receipt roster manifest rd lockdir rationale="${COUNCIL_SELECTION_RATIONALE:-}" execution_mode="${COUNCIL_EXECUTION_MODE:-}"
  case "$mode" in ship|research|domain|exec|minimal) ;; *) echo "council-guard: invalid mode '$mode'" >&2; exit 1;; esac
  case "$execution_mode" in spawned|lens-simulation) ;; *) echo "council-guard: COUNCIL_EXECUTION_MODE must be spawned or lens-simulation" >&2; exit 1;; esac
  [ -n "${rationale//[[:space:]]/}" ] || { echo "council-guard: COUNCIL_SELECTION_RATIONALE is required" >&2; exit 1; }
  artifact_file="$(cd "$(dirname "$artifact_file")" && pwd)/$(basename "$artifact_file")"
  receipt="$(artifact "$artifact_file")" || exit 1
  roster="$(jq -cn --arg csv "$csv" '$csv | split(",") | map(gsub("^[[:space:]]+|[[:space:]]+$"; "")) as $p | if any($p[]; . == "") or any($p[]; test("^[A-Za-z0-9._-]+$") | not) then error("invalid persona") else $p | unique end')" || { echo "council-guard: invalid persona roster" >&2; exit 1; }
  [ "$(jq 'length' <<<"$roster")" -ge 3 ] && [ "$(jq 'length' <<<"$roster")" -le 6 ] || { echo "council-guard: roster must contain 3-6 unique personas" >&2; exit 1; }
  rd="$ROOMS/$room"; mkdir -p "$rd"; manifest="$rd/manifest.json"
  lockdir="$(lock "$rd")"
  if [ -e "$manifest" ]; then unlock "$lockdir"; echo "council-guard: room '$room' already has a manifest" >&2; exit 1; fi
  jq -cn --argjson artifact "$receipt" --arg artifact_path "$artifact_file" --arg mode "$mode" --arg execution_mode "$execution_mode" --argjson personas "$roster" --arg ts "$(now)" --arg rationale "$rationale" \
    '{schema_version:2, artifact_path:$artifact_path, artifact_sha256:$artifact.artifact_sha256, artifact_kind:$artifact.kind, inventory_valid:$artifact.inventory_valid, mode:$mode, execution_mode:$execution_mode, personas:$personas, selection_rationale:$rationale, state:"pending", created_at:$ts, rounds:[]}' \
    > "$manifest.tmp"
  mv "$manifest.tmp" "$manifest"
  unlock "$lockdir"
  printf '%s\n' "$manifest"
}

position() {
  local persona="${1:?persona}" text header count value
  text="$(cat)"
  header="POSITION (persona: $persona)"
  [ "$(printf '%s\n' "$text" | grep -Fx "$header" | wc -l | tr -d ' ')" -eq 1 ] || { echo "council-guard: POSITION header must match '$persona'" >&2; exit 1; }
  [ "$(printf '%s\n' "$text" | grep -c '^POSITION (persona: ' || true)" -eq 1 ] || { echo "council-guard: POSITION must have one header" >&2; exit 1; }
  while IFS='|' read -r field pattern; do
    count="$(printf '%s\n' "$text" | grep -c "^- $field:" || true)"
    [ "$count" -eq 1 ] || { echo "council-guard: '$field' must appear once" >&2; exit 1; }
    value="$(printf '%s\n' "$text" | sed -n "s/^- $field:[[:space:]]*//p")"
    if [ "$field" != top_issues ]; then
      [ -n "${value//[[:space:]]/}" ] || { echo "council-guard: '$field' must be non-empty" >&2; exit 1; }
    fi
    [ -z "$pattern" ] || printf '%s\n' "$value" | grep -Eq "$pattern" || { echo "council-guard: invalid '$field'" >&2; exit 1; }
  done <<'EOF'
verdict|^(SHIP|SHIP-WITH-CHANGES|BLOCK|NEED-MORE-INFO)$
top_issues|
strongest_counterargument|
confidence|^(low|med|high)$
one_line|
EOF
}

verify_room_artifact() {
  local room
  room="$(safe "${1:?room}")"
  local rd manifest artifact_file receipt
  rd="$ROOMS/$room"; manifest="$rd/manifest.json"; artifact_file="$rd/artifact.txt"
  [ -f "$manifest" ] || { echo "council-guard: no manifest for room '$room'" >&2; exit 1; }
  receipt="$(artifact "$artifact_file")" || exit 1
  jq -e --argjson artifact "$receipt" '.artifact_sha256 == $artifact.artifact_sha256' "$manifest" >/dev/null \
    || { echo "council-guard: room artifact changed or is invalid; refuse" >&2; exit 1; }
}

finish() {
  local room
  room="$(safe "${1:?room}")"
  local round="${2:?round}" manifest rd lockdir
  [[ "$round" =~ ^[1-9][0-9]*$ ]] || { echo "council-guard: invalid round" >&2; exit 1; }
  rd="$ROOMS/$room"; manifest="$rd/manifest.json"; [ -f "$manifest" ] || { echo "council-guard: no manifest for room '$room'" >&2; exit 1; }
  lockdir="$(lock "$rd")"
  jq -e --argjson round "$round" '.state == "running" and any(.rounds[]; .round == $round)' "$manifest" >/dev/null || { unlock "$lockdir"; echo "council-guard: finish requires a captured running round" >&2; exit 1; }
  local artifact_file receipt
  artifact_file="$(jq -r '.artifact_path // empty' "$manifest")"
  [ -n "$artifact_file" ] || { unlock "$lockdir"; echo "council-guard: finish requires an artifact path" >&2; exit 1; }
  receipt="$(artifact "$artifact_file")" || { unlock "$lockdir"; exit 1; }
  jq -e --argjson artifact "$receipt" '.artifact_sha256 == $artifact.artifact_sha256' "$manifest" >/dev/null || { unlock "$lockdir"; echo "council-guard: artifact changed after begin; use a new room" >&2; exit 1; }
  jq --arg ts "$(now)" --argjson round "$round" '.state="complete" | .completed_round=$round | .completed_at=$ts' "$manifest" > "$manifest.tmp"
  mv "$manifest.tmp" "$manifest"
  unlock "$lockdir"
}

state() {
  local room
  room="$(safe "${1:?room}")"
  local target="${2:?state}" manifest rd lockdir
  [ "$target" = incomplete ] || { echo "council-guard: unsupported state '$target'" >&2; exit 1; }
  rd="$ROOMS/$room"; manifest="$rd/manifest.json"; [ -f "$manifest" ] || { echo "council-guard: no manifest for room '$room'" >&2; exit 1; }
  lockdir="$(lock "$rd")"
  jq -e '.state == "pending" or .state == "running"' "$manifest" >/dev/null || { unlock "$lockdir"; echo "council-guard: room is already terminal" >&2; exit 1; }
  jq --arg ts "$(now)" '.state="incomplete" | .incomplete_at=$ts | .incomplete_journal_retry_used=false' "$manifest" > "$manifest.tmp"
  mv "$manifest.tmp" "$manifest"
  unlock "$lockdir"
}

retry_incomplete() {
  local room
  room="$(safe "${1:?room}")"
  local manifest rd lockdir
  rd="$ROOMS/$room"; manifest="$rd/manifest.json"; [ -f "$manifest" ] || { echo "council-guard: no manifest for room '$room'" >&2; exit 1; }
  lockdir="$(lock "$rd")"
  jq -e '.state == "incomplete" and (.incomplete_journal_retry_used // false | not)' "$manifest" >/dev/null || { unlock "$lockdir"; echo "council-guard: incomplete journal retry already used" >&2; exit 1; }
  jq '.incomplete_journal_retry_used=true' "$manifest" > "$manifest.tmp"
  mv "$manifest.tmp" "$manifest"
  unlock "$lockdir"
}

case "${1:-}" in
  artifact) shift; artifact "$@";;
  begin) shift; begin "$@";;
  position) shift; position "$@";;
  verify-room-artifact) shift; verify_room_artifact "$@";;
  finish) shift; finish "$@";;
  state) shift; state "$@";;
  retry-incomplete) shift; retry_incomplete "$@";;
  *) echo "usage: council-guard.sh {artifact <path>|begin <room> <artifact-path> <mode> <personas-csv>|position <persona>|verify-room-artifact <room>|finish <room> <round>|state <room> incomplete|retry-incomplete <room>}" >&2; exit 1;;
esac
