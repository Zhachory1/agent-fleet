#!/usr/bin/env bash
# agent-fleet installer — works across AI coding tools.
#
# Usage:
#   install.sh                      # default: --tool claude
#   install.sh --tool claude        # symlink personas -> ~/.claude/agents, skill -> ~/.claude/skills/council
#   install.sh --tool claude --uninstall
#   install.sh --tool cursor        # COPY personas + orchestrator -> ./.cursor/rules/ (current repo)
#   install.sh --tool opencode      # COPY personas + orchestrator -> ./.agent-fleet/ (current repo)
#   install.sh --tool codex         # COPY project refs -> ./.agent-fleet/ and global payload -> ~/.codex/
#   install.sh --tool cave          # COPY cave-compatible personas -> ./.cave/agents, skill -> ./.cave/skills/council
#   install.sh --target DIR [--copy]# place personas + orchestrator prompt into DIR (any tool)
#                                   #   symlink by default; --copy to copy instead (for tools that
#                                   #   don't follow symlinks, or sandboxed dirs)
#   install.sh --print              # print the portable orchestrator prompt to stdout (paste anywhere)
#
# AGENT_FLEET_HOME is this repo. Personas (agents/*.md) and the portable prompt
# (prompts/council-orchestrator.md) are the cross-tool payload; the council skill
# (skills/council) is installed for tools with local skill directories.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(cat "$SRC/VERSION" 2>/dev/null || echo 'unknown')"
TOOL="claude"; TARGET=""; COPY=0; UNINSTALL=0; PRINT=0; SCOPE="project"

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
  --tool codex               COPY project refs → ./.agent-fleet/ AND install
                             global Codex payload under \${CODEX_HOME:-~/.codex}:
                             skill → .../skills/council,
                             personas/prompt → .../agent-fleet/
                             (Codex has no native persona dir; skill loads these by path)
  --tool cave                COPY cave-compatible personas → ./.cave/agents/,
                             skill → ./.cave/skills/council,
                             prompt → ./.cave/prompts/council-orchestrator.md
  --tool cave --user         User-scope Cave install under \${CAVE_HOME:-~/.cave}:
                             agents → \${CAVE_HOME:-~/.cave}/agent/agents,
                             skill → \${CAVE_HOME:-~/.cave}/skills/council,
                             prompt → \${CAVE_HOME:-~/.cave}/prompts/council-orchestrator.md
  --project                  Cave only. Project-scope install (default)
  --user                     Cave only. User-scope install
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
  install.sh --tool opencode                  # opencode: copy into ./.agent-fleet/
  install.sh --tool codex                     # Codex: copy prompt/personas + install skill
  install.sh --tool cave                      # Cave: install into ./.cave/{agents,skills,prompts}
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
    --project) SCOPE="project"; shift;;
    --user) SCOPE="user"; shift;;
    --print) PRINT=1; shift;;
    --version|-V) echo "$VERSION"; exit 0;;
    --help|-h) print_help; exit 0;;
    *) echo "install.sh: unknown arg '$1' (try --help)" >&2; exit 1;;
  esac
done
if [ "$SCOPE" != "project" ] && [ "$TOOL" != "cave" ]; then
  echo "install.sh: --user/--project only applies to --tool cave" >&2
  exit 1
fi

place() { # place <src-file> <dst-path>
  mkdir -p "$(dirname "$2")"
  if [ "$COPY" = "1" ]; then cp -f "$1" "$2"; else ln -sf "$1" "$2"; fi
}
place_dir() { # place_dir <src-dir> <dst-dir>; copy-only for sandboxed tool resource dirs
  mkdir -p "$(dirname "$2")" "$2"
  cp -R "$1"/. "$2"/
}
place_cave_persona() { # place_cave_persona <src-file> <dst-path>
  local tmp
  mkdir -p "$(dirname "$2")"
  # Cave's tool registry uses lowercase canonical tool names. Keep source personas
  # Claude-Code-compatible; transform only the Cave install copies.
  tmp="$2.tmp.$$"
  awk '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    BEGIN {
      map["Read"] = "read"; map["Bash"] = "bash"; map["Edit"] = "edit"; map["Write"] = "write"
      map["Grep"] = "grep"; map["Glob"] = "find"; map["LS"] = "ls"; map["Ls"] = "ls"
    }
    /^tools:[[:space:]]*/ {
      tools = $0; sub(/^tools:[[:space:]]*/, "", tools)
      n = split(tools, raw, ",")
      out = ""
      for (i = 1; i <= n; i++) {
        t = trim(raw[i])
        mapped = (t in map) ? map[t] : t
        if (!(t in map)) printf "install.sh: WARN Cave tool has no mapping: %s\n", t > "/dev/stderr"
        out = out (out == "" ? "" : ", ") mapped
      }
      print "tools: " out
      next
    }
    { print }
  ' "$1" > "$tmp" && mv "$tmp" "$2" || { rm -f "$tmp"; return 1; }
}
# personas: enumerate the actual persona files. Excludes:
#   - _overlay.md          (private overlay, not a persona; gitignored)
#   - _overlay.md.example  (overlay template, not a persona)
#   - INDEX.md             (the catalog, not a persona)
personas() {
  for f in "$SRC"/agents/*.md; do
    case "$(basename "$f")" in
      _overlay.md|_overlay.md.example|INDEX.md) continue ;;
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

# Tool shortcuts for tools with project-local layouts.
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
  opencode)
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
  codex)
    [ -n "$TARGET" ] || TARGET="./.agent-fleet"
    COPY=1
    CODEX_BASE="${CODEX_HOME:-$HOME/.codex}"
    CODEX_SKILL_DST="$CODEX_BASE/skills/council"
    CODEX_BUNDLE_DST="$CODEX_BASE/agent-fleet"
    if [ "$UNINSTALL" = "1" ]; then
      for f in $(personas); do rm -f "$TARGET/$(basename "$f")"; done
      rm -f "$TARGET/council-orchestrator.md"
      rm -rf "$CODEX_SKILL_DST" "$CODEX_BUNDLE_DST"
      echo "agent-fleet: uninstalled Codex project files from $TARGET and global payload from $CODEX_BASE"
      exit 0
    fi
    for f in $(personas); do place "$f" "$TARGET/$(basename "$f")"; done
    place "$SRC/prompts/council-orchestrator.md" "$TARGET/council-orchestrator.md"
    place_dir "$SRC/skills/council" "$CODEX_SKILL_DST"
    mkdir -p "$CODEX_BUNDLE_DST/agents" "$CODEX_BUNDLE_DST/prompts"
    for f in $(personas); do place "$f" "$CODEX_BUNDLE_DST/agents/$(basename "$f")"; done
    place "$SRC/prompts/council-orchestrator.md" "$CODEX_BUNDLE_DST/prompts/council-orchestrator.md"
    echo "agent-fleet: placed $(personas | wc -l | tr -d ' ') personas + orchestrator prompt into $TARGET"
    echo "agent-fleet: installed Codex skill → $CODEX_SKILL_DST"
    echo "agent-fleet: installed Codex global payload → $CODEX_BUNDLE_DST"
    echo ""
    echo "Next: ensure your project's AGENTS.md references the orchestrator at:"
    echo "  $TARGET/council-orchestrator.md"
    echo "Set AGENT_FLEET_HOME=$SRC so the lib/ helpers (transcript/journal) resolve."
    exit 0
    ;;
  cave)
    COPY=1
    if [ "$SCOPE" = "user" ]; then
      CAVE_BASE="${CAVE_HOME:-$HOME/.cave}"
      CAVE_AGENTS_DST="$CAVE_BASE/agent/agents"
      CAVE_SKILL_DST="$CAVE_BASE/skills/council"
      CAVE_PROMPT_DST="$CAVE_BASE/prompts/council-orchestrator.md"
    else
      CAVE_AGENTS_DST="./.cave/agents"
      CAVE_SKILL_DST="./.cave/skills/council"
      CAVE_PROMPT_DST="./.cave/prompts/council-orchestrator.md"
    fi
    if [ "$UNINSTALL" = "1" ]; then
      for f in $(personas); do rm -f "$CAVE_AGENTS_DST/$(basename "$f")"; done
      rm -f "$CAVE_PROMPT_DST"
      rm -rf "$CAVE_SKILL_DST"
      echo "agent-fleet: uninstalled Cave $SCOPE-scope files."
      exit 0
    fi
    for f in $(personas); do place_cave_persona "$f" "$CAVE_AGENTS_DST/$(basename "$f")"; done
    place "$SRC/prompts/council-orchestrator.md" "$CAVE_PROMPT_DST"
    place_dir "$SRC/skills/council" "$CAVE_SKILL_DST"
    echo "agent-fleet: installed Cave $SCOPE-scope agents → $CAVE_AGENTS_DST"
    echo "agent-fleet: installed Cave skill → $CAVE_SKILL_DST"
    echo "agent-fleet: installed Cave prompt → $CAVE_PROMPT_DST"
    echo "Cave agent copies map Claude-Code tool names to Cave lowercase names."
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
