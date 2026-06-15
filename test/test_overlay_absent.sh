#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
# overlay hook must be conditional ("if exists") so absence is not an error.
# Accepts either the legacy ~/.claude/agents/_overlay.md or the new $AGENT_FLEET_HOME path.
for f in "$DIR"/agents/ml-scientist.md "$DIR"/agents/red-team.md; do
  if grep -qi 'if .*_overlay\.md.*exists' "$f"; then
    :
  elif grep -qi 'If \`~/\.claude/agents/_overlay\.md\` exists' "$f"; then
    :
  elif grep -qi 'If \`\$AGENT_FLEET_HOME/agents/_overlay\.md\` exists' "$f"; then
    :
  else
    echo "FAIL: $(basename "$f") overlay hook not conditional"; exit 1
  fi
done
[ ! -e "$DIR/agents/_overlay.md" ] || echo "(note: real overlay present locally — fine)"
echo "PASS test_overlay_absent"

# #6 acceptance: grep ~/code/agent-fleet in skills/ prompts/ agents/ must be 0
# shellcheck disable=SC2088 # intentional literal tilde: searching for hardcoded user paths in committed files
bad_paths=$(grep -rln '~/code/agent-fleet' "$DIR"/skills "$DIR"/prompts "$DIR"/agents 2>/dev/null || true)
if [ -n "$bad_paths" ]; then
  echo "FAIL: hardcoded ~/code/agent-fleet found in:"; echo "$bad_paths"; exit 1
fi

# #6 acceptance: grep ~/.claude/agents/_overlay.md in agents/ must be 0
# shellcheck disable=SC2088 # intentional literal tilde: searching for legacy hardcoded paths
legacy_overlay=$(grep -rln '~/\.claude/agents/_overlay\.md' "$DIR"/agents 2>/dev/null || true)
if [ -n "$legacy_overlay" ]; then
  echo "FAIL: legacy ~/.claude overlay path found in agents/:"; echo "$legacy_overlay"; exit 1
fi
echo "PASS test_overlay_absent (#6 acceptance: no hardcoded ~/code/agent-fleet or ~/.claude/agents)"
