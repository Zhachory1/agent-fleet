#!/usr/bin/env bash
# overlay.sh — inspect agents/_overlay.md before trusting it.
#
# The overlay is loaded VERBATIM into every persona's system prompt. Treat it as code you
# are running. This helper does NOT block bad overlays — it surfaces them so the operator
# can read what they're about to install.
#
# Subcommands:
#   show          print the active overlay verbatim + path + SHA256
#   lint [path]   scan for suspicious patterns; print findings (exit 0 even if findings)
#   --help        usage
#
# Default overlay location: $AGENT_FLEET_HOME/agents/_overlay.md
#   If AGENT_FLEET_HOME unset, falls back to the script's parent-of-parent (a clone of agent-fleet).
set -euo pipefail
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-V" ]; then
  cat "$(dirname "$0")/../VERSION" 2>/dev/null || echo unknown; exit 0
fi
# overlay.sh uses sha256sum + grep — no jq dependency

# Resolve script location -> AGENT_FLEET_HOME if env var unset.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_FLEET_HOME="${AGENT_FLEET_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OVERLAY_PATH_DEFAULT="$AGENT_FLEET_HOME/agents/_overlay.md"

die() { printf 'overlay: %s\n' "$*" >&2; exit 1; }

print_help() {
  cat <<'HELP'
Usage: overlay.sh <subcommand>

Subcommands:
  show          print the active overlay verbatim + path + SHA256
  lint [path]   scan for suspicious patterns; print findings (file:line: pattern)
                  exits 0 even if findings — this is a HINT, not a gate.
                  path defaults to $AGENT_FLEET_HOME/agents/_overlay.md
  --help        this message

The overlay is loaded VERBATIM into every persona's system prompt. Treat it as code
you are running. Only install overlays you have read end-to-end; never paste an
overlay from an unfamiliar source.

Lint patterns flagged (all heuristic, all advisory):
  - Persona contract overrides (try to change verdict / top_issues structure)
  - "ignore previous instructions" or similar prompt-injection shapes
  - Exfiltration shapes (restate the artifact, dump everything, etc.)
  - URLs (overlays generally shouldn't have network references)
  - Suspicious imperatives ("always", "never", "must SHIP")
HELP
}

show_overlay() {
  local path="${1:-$OVERLAY_PATH_DEFAULT}"
  if [ ! -f "$path" ]; then
    echo "overlay: no overlay at $path (this is FINE — personas run generic when absent)"
    return 0
  fi
  local sha
  sha=$(sha256sum "$path" | awk '{print $1}')
  printf '═══ overlay: %s ═══\n' "$path"
  printf '   SHA256: %s\n' "$sha"
  printf '   Size:   %d bytes\n\n' "$(wc -c <"$path" | tr -d ' ')"
  cat "$path"
}

# Lint patterns. Each is a grep -nE; matches are reported as findings.
# Heuristic, not definitive — purpose is to surface candidates for human review.
lint_overlay() {
  local path="${1:-$OVERLAY_PATH_DEFAULT}"
  if [ ! -f "$path" ]; then
    echo "overlay: no overlay at $path (nothing to lint)"
    return 0
  fi

  printf '═══ overlay lint: %s ═══\n\n' "$path"
  local findings=0
  local pat label
  scan() {
    local label="$1" pat="$2"
    local out
    if out=$(grep -niE "$pat" "$path" 2>/dev/null); then
      printf '\n[%s]\n' "$label"
      while IFS= read -r line; do
        printf '  %s:%s\n' "$path" "$line"
        findings=$((findings + 1))
      done <<<"$out"
    fi
  }

  # Persona contract overrides: try to change the POSITION output structure
  scan "persona-contract-override" 'verdict[[:space:]]*[:=]|top_issues[[:space:]]*[:=]|strongest_counterargument[[:space:]]*[:=]'

  # Prompt-injection shapes
  scan "prompt-injection" 'ignore (previous|all|prior|above)|disregard (previous|prior|above|instructions)|forget (your|all|previous)'

  # Exfiltration shapes
  scan "exfiltration" 'restate the (artifact|prompt|context|system)|dump (everything|all|the system)|reveal your (prompt|system|instructions)|include the (artifact|prompt|system).*in your (output|response|answer)'

  # Imperative biasing — phrasings that try to pin the persona to a fixed answer regardless of artifact.
  # Loose: '(always|never|must)' on the same line as a verdict literal (SHIP/BLOCK/true/false).
  scan "imperative-bias" '(always|never|must)[^\n]*(SHIP|BLOCK|verdict[[:space:]]*[:=][[:space:]]*(SHIP|BLOCK))'

  # URLs (overlays generally shouldn't have network references)
  scan "url-reference" 'https?://[^[:space:]]+'

  # Tool-call shapes (overlays should be domain context, not tool invocations)
  scan "tool-call" '\\bbash\\b|\\bcurl\\b|\\bwget\\b|<tool[_-]?call>|execute (this|the following)'

  printf '\n'
  if [ "$findings" -eq 0 ]; then
    printf 'overlay lint: no findings\n'
  else
    printf 'overlay lint: %d finding(s) above\n' "$findings"
    printf '(advisory only; review each finding manually — heuristics produce false positives)\n'
  fi
  # Always exit 0; lint is a hint, not a gate.
  return 0
}

cmd="${1:-}"; shift || true
case "$cmd" in
  show)         show_overlay "${1:-}";;
  lint)         lint_overlay "${1:-}";;
  --help|-h|"") print_help;;
  *)            die "unknown subcommand '$cmd' (try --help)";;
esac
