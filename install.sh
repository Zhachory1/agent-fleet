#!/usr/bin/env bash
# agent-fleet installer — works across AI coding tools.
#
# Usage:
#   install.sh                      # default: --tool claude
#   install.sh --tool claude        # symlink personas -> ~/.claude/agents, skill -> ~/.claude/skills/council
#   install.sh --tool claude --uninstall
#   install.sh --tool cursor        # COPY personas + orchestrator -> ./.cursor/rules/ (current repo)
#   install.sh --tool opencode      # COPY personas + orchestrator -> ./.agent-fleet/ (current repo)
#   install.sh --tool codex         # COPY personas + orchestrator -> ./.agent-fleet/ (current repo);
#                                   #   point your AGENTS.md at ./.agent-fleet/council-orchestrator.md
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
VERSION="$(cat "$SRC/VERSION" 2>/dev/null || echo 'unknown')"
TOOL="claude"; TARGET=""; COPY=0; UNINSTALL=0; PRINT=0

print_help() {
  cat <<HELP
agent-fleet installer v${VERSION}

Usage:
  install.sh [options]

Options:
  --tool claude              Default. Symlink personas → ~/.claude/agents,
                             skill → ~/.claude/skills/council
  --tool claude --uninstall  Reverse a Claude Code install
  --tool cursor              COPY personas + orchestrator → ./.cursor/rules/
                             (Cursor reads .cursor/rules/, not AGENTS.md)
  --tool opencode            COPY personas + orchestrator → ./.agent-fleet/
                             (opencode reads AGENTS.md from repo root + subagents)
  --tool codex               COPY personas + orchestrator → ./.agent-fleet/
                             (Codex reads AGENTS.md from repo root)
  --target DIR               Place personas + orchestrator prompt into DIR
                             (any tool; explicit override of --tool defaults)
  --copy                     Used with --target: copy files instead of symlinking
                             (for tools that don't follow symlinks or sandboxed dirs)
  --print                    Print the portable orchestrator prompt to stdout
                             (paste into any AI chat that doesn't have a plugin model)
  --version, -V              Print version and exit
  --help, -h                 This message

Examples:
  install.sh                                  # Claude Code, default symlinks
  install.sh --tool cursor                    # Cursor: copy into ./.cursor/rules/
  install.sh --tool opencode                  # opencode/Codex: copy into ./.agent-fleet/
  install.sh --target ./custom/path --copy    # explicit target override
  install.sh --print | pbcopy                 # copy prompt to clipboard for chat tools

Requirements: bash, jq (and git for full functionality).
  Run \`bash $SRC/lib/journal.sh --help\` for journal CLI usage.
HELP
}

# Dependency precheck (fast-fail with a clear message if jq missing).
if ! command -v jq >/dev/null 2>&1; then
  echo "install.sh: jq is required but not found on PATH." >&2
  echo "  macOS:  brew install jq" >&2
  echo "  Debian: apt-get install jq" >&2
  echo "  Other:  https://jqlang.github.io/jq/download/" >&2
  exit 1
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --tool) TOOL="${2:?}"; shift 2;;
    --target) TARGET="${2:?}"; shift 2;;
    --copy) COPY=1; shift;;
    --uninstall) UNINSTALL=1; shift;;
    --print) PRINT=1; shift;;
    --version|-V) echo "$VERSION"; exit 0;;
    --help|-h) print_help; exit 0;;
    *) echo "install.sh: unknown arg '$1' (try --help)" >&2; exit 1;;
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

# Tool shortcuts for tools without a native dir layout: set sensible TARGET defaults and
# re-enter the generic --target path. Each is a thin alias; no new install logic.
case "$TOOL" in
  cursor)
    [ -n "$TARGET" ] || TARGET="./.cursor/rules"
    COPY=1  # Cursor's rules dir doesn't follow symlinks reliably
    for f in $(personas); do place "$f" "$TARGET/$(basename "$f")"; done
    place "$SRC/prompts/council-orchestrator.md" "$TARGET/council-orchestrator.md"
    echo "agent-fleet: placed $(personas | wc -l | tr -d ' ') personas + orchestrator prompt into $TARGET"
    echo "Cursor will auto-load .cursor/rules/. Set AGENT_FLEET_HOME=$SRC so the lib/ helpers resolve."
    exit 0
    ;;
  opencode|codex)
    [ -n "$TARGET" ] || TARGET="./.agent-fleet"
    COPY=1
    for f in $(personas); do place "$f" "$TARGET/$(basename "$f")"; done
    place "$SRC/prompts/council-orchestrator.md" "$TARGET/council-orchestrator.md"
    echo "agent-fleet: placed $(personas | wc -l | tr -d ' ') personas + orchestrator prompt into $TARGET"
    echo ""
    echo "Next: ensure your project's AGENTS.md references the orchestrator at:"
    echo "  $TARGET/council-orchestrator.md"
    echo "opencode also picks up subagents from $TARGET/<persona>.md automatically."
    echo "Set AGENT_FLEET_HOME=$SRC so the lib/ helpers (transcript/journal) resolve."
    exit 0
    ;;
esac

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
