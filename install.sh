#!/usr/bin/env bash
# agent-fleet installer — works across AI coding tools.
#
# Usage:
#   install.sh                      # default: --tool claude
#   install.sh --tool claude        # symlink personas -> ~/.claude/agents, skill -> ~/.claude/skills/council
#   install.sh --tool claude --uninstall
#   install.sh --target DIR [--copy]# place personas + orchestrator prompt into DIR (any tool)
#                                   #   symlink by default; --copy to copy instead (for tools that
#                                   #   don't follow symlinks, or sandboxed dirs)
#   install.sh --print              # print the portable orchestrator prompt to stdout (paste anywhere)
#
# AGENT_FLEET_HOME is this repo. Personas (agents/*.md) and the portable prompt
# (prompts/council-orchestrator.md) are the cross-tool payload; the Claude skill
# (skills/council) is Claude-Code-specific.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
TOOL="claude"; TARGET=""; COPY=0; UNINSTALL=0; PRINT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --tool) TOOL="${2:?}"; shift 2;;
    --target) TARGET="${2:?}"; shift 2;;
    --copy) COPY=1; shift;;
    --uninstall) UNINSTALL=1; shift;;
    --print) PRINT=1; shift;;
    *) echo "install.sh: unknown arg $1" >&2; exit 1;;
  esac
done

place() { # place <src-file> <dst-path>
  mkdir -p "$(dirname "$2")"
  if [ "$COPY" = "1" ]; then cp -f "$1" "$2"; else ln -sf "$1" "$2"; fi
}
personas() { for f in "$SRC"/agents/*.md; do [ "$(basename "$f")" = "_overlay.md.example" ] && continue; echo "$f"; done; }

if [ "$PRINT" = "1" ]; then
  cat "$SRC/prompts/council-orchestrator.md"; exit 0
fi

# Generic target: drop personas + the portable orchestrator prompt into DIR.
if [ -n "$TARGET" ]; then
  for f in $(personas); do place "$f" "$TARGET/$(basename "$f")"; done
  place "$SRC/prompts/council-orchestrator.md" "$TARGET/council-orchestrator.md"
  echo "agent-fleet: placed $(personas | wc -l | tr -d ' ') personas + orchestrator prompt into $TARGET"
  echo "Set AGENT_FLEET_HOME=$SRC so the lib/ helpers (transcript/journal) resolve."
  exit 0
fi

# Claude Code (default): native agents + skill dirs.
case "$TOOL" in
  claude)
    AGENTS_DST="$HOME/.claude/agents"; SKILL_DST="$HOME/.claude/skills/council"
    if [ "$UNINSTALL" = "1" ]; then
      for f in $(personas); do rm -f "$AGENTS_DST/$(basename "$f")"; done
      rm -f "$SKILL_DST"; echo "agent-fleet: uninstalled Claude symlinks."; exit 0
    fi
    mkdir -p "$AGENTS_DST" "$HOME/.claude/skills"
    for f in $(personas); do ln -sf "$f" "$AGENTS_DST/$(basename "$f")"; done
    ln -sfn "$SRC/skills/council" "$SKILL_DST"
    echo "agent-fleet: installed for Claude Code. agents → $AGENTS_DST ; skill → $SKILL_DST"
    echo "Optional: cp agents/_overlay.md.example agents/_overlay.md and edit (stays private)."
    ;;
  *) echo "install.sh: --tool '$TOOL' has no native layout; use --target DIR (see README)." >&2; exit 1;;
esac
