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
# personas: enumerate the actual persona files. Excludes:
#   - _overlay.md.example  (overlay template, not a persona)
#   - INDEX.md             (the catalog, not a persona)
personas() {
  for f in "$SRC"/agents/*.md; do
    case "$(basename "$f")" in
      _overlay.md.example|INDEX.md) continue ;;
    esac
    echo "$f"
  done
}

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
    echo ""
    echo "Optional next steps:"
    echo "  - Set a private overlay for your org's KPIs/stack/hot-paths/priorities:"
    echo "      ls $SRC/agents/_overlay.example/   # pick the closest industry starter"
    echo "      cp $SRC/agents/_overlay.example/<industry>.md $SRC/agents/_overlay.md"
    echo "      \$EDITOR $SRC/agents/_overlay.md  # customize; this file is gitignored"
    echo "  - Or start from the bare skeleton:"
    echo "      cp $SRC/agents/_overlay.md.example $SRC/agents/_overlay.md"
    echo "  - Inspect any overlay before trusting it (loaded VERBATIM into persona prompts):"
    echo "      bash $SRC/lib/overlay.sh show"
    echo "      bash $SRC/lib/overlay.sh lint"
    ;;
  *) echo "install.sh: --tool '$TOOL' has no native layout; use --target DIR (see README)." >&2; exit 1;;
esac
