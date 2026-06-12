#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
# overlay hook must be conditional ("if exists") so absence is not an error
for f in "$DIR"/agents/ml-scientist.md "$DIR"/agents/red-team.md; do
  grep -qi "if .*_rokt-overlay.md exists" "$f" || grep -qi "If \`~/.claude/agents/_rokt-overlay.md\` exists" "$f" \
    || { echo "FAIL: $(basename $f) overlay hook not conditional"; exit 1; }
done
[ ! -e "$DIR/agents/_rokt-overlay.md" ] || echo "(note: real overlay present locally — fine)"
echo "PASS test_overlay_absent"
