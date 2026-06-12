#!/usr/bin/env bash
# Symlink agent-fleet into ~/.claude (reversible). Usage: install.sh [--uninstall]
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
AGENTS_DST="$HOME/.claude/agents"
SKILL_DST="$HOME/.claude/skills/council"
if [ "${1:-}" = "--uninstall" ]; then
  for f in "$SRC"/agents/*.md; do
    [ "$(basename "$f")" = "_rokt-overlay.md.example" ] && continue
    rm -f "$AGENTS_DST/$(basename "$f")"
  done
  rm -f "$SKILL_DST"
  echo "agent-fleet: uninstalled symlinks."
  exit 0
fi
mkdir -p "$AGENTS_DST" "$HOME/.claude/skills"
for f in "$SRC"/agents/*.md; do
  [ "$(basename "$f")" = "_rokt-overlay.md.example" ] && continue
  ln -sf "$f" "$AGENTS_DST/$(basename "$f")"
done
ln -sfn "$SRC/skills/council" "$SKILL_DST"
echo "agent-fleet: installed. Agents → $AGENTS_DST ; skill → $SKILL_DST"
echo "Optional: cp agents/_rokt-overlay.md.example agents/_rokt-overlay.md and edit (stays private)."
