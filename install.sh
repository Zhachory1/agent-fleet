#!/usr/bin/env bash
# agent-fleet installer — works across AI coding tools.
#
# Primary usage:
#   npx @zhachory1/agent-fleet install --tool claude
#
# Fallback usage when npm/npx is unavailable:
#   install.sh                      # default: --tool claude
#   install.sh --tool claude        # symlink personas -> ~/.claude/agents, skill -> ~/.claude/skills/council
#                                   # (copies personas instead when AGENT_FLEET_SUBAGENT_MODEL is set)
#   install.sh --tool claude --uninstall
#   install.sh --tool cursor        # COPY personas + orchestrator -> ./.cursor/rules/ (current repo)
#   install.sh --tool opencode      # COPY personas + orchestrator -> ./.agent-fleet/ (current repo)
#   install.sh --tool codex         # COPY project refs -> ./.agent-fleet/ and global payload -> ~/.codex/
#   install.sh --tool cave          # COPY cave-compatible personas -> ./.cave/agents, skill -> ./.cave/skills/council
#   install.sh --dir DIR            # COPY generic global payload -> DIR/{agents,skills,prompts}
#   install.sh --target DIR [--copy]# place personas + orchestrator prompt into DIR (any tool)
#                                   #   symlink by default; --copy to copy instead (for tools that
#                                   #   don't follow symlinks, or sandboxed dirs)
#   install.sh --agent-instructions # print install decision tree for AI agents
#   install.sh --print              # print the portable orchestrator prompt to stdout (paste anywhere)
#
# AGENT_FLEET_HOME is this repo. Personas (agents/*.md) and the portable prompt
# (prompts/council-orchestrator.md) are the cross-tool payload; the council skill
# (skills/council) is installed for tools with local skill directories.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(cat "$SRC/VERSION" 2>/dev/null || echo 'unknown')"
TOOL="claude"; TARGET=""; INSTALL_DIR=""; COPY="${AGENT_FLEET_INSTALL_COPY:-0}"; UNINSTALL=0; PRINT=0; AGENT_INSTRUCTIONS=0; SCOPE="project"
SUBAGENT_MODEL_OVERRIDE="${AGENT_FLEET_SUBAGENT_MODEL:-}"

print_agent_instructions() {
  cat <<'HELP'
AGENT-FLEET INSTALL INSTRUCTIONS FOR AI AGENTS

Rule: do NOT vendor this repo into the user's project. Install only:
- agents/*.md council persona files
- ship-agents/*.md implementation agent files
- skills/council/ and skills/ship/ skill directories
- prompts/council-orchestrator.md and prompts/ship-orchestrator.md prompts

Use npm/npx first. Keep this script as the fallback when npm is unavailable.

Spawned agents default to cheaper `model: haiku`. To rewrite installed agent copies to another model:
  AGENT_FLEET_SUBAGENT_MODEL=<model> npx @zhachory1/agent-fleet install ...
  # fallback: AGENT_FLEET_SUBAGENT_MODEL=<model> bash install.sh ...

Pick one:
- Claude Code: npx @zhachory1/agent-fleet install --tool claude
  -> ~/.claude/agents + ~/.claude/skills/{council,ship}
  fallback: bash install.sh --tool claude
- Codex CLI: npx @zhachory1/agent-fleet install --tool codex
  -> ~/.codex/skills/{council,ship} + ~/.codex/agent-fleet
  fallback: bash install.sh --tool codex
- Cave project: npx @zhachory1/agent-fleet install --tool cave
  -> ./.cave/{agents,skills,prompts}
  fallback: bash install.sh --tool cave
- Cave user-global: npx @zhachory1/agent-fleet install --tool cave --user
  -> ${CAVE_HOME:-~/.cave}
  fallback: bash install.sh --tool cave --user
- Cursor: npx @zhachory1/agent-fleet install --tool cursor
  -> ./.cursor/rules
  fallback: bash install.sh --tool cursor
- opencode: npx @zhachory1/agent-fleet install --tool opencode
  -> ./.agent-fleet
  fallback: bash install.sh --tool opencode
- Unknown TUI with global config dir: ask user for dir, then:
  npx @zhachory1/agent-fleet install --dir <DIR>
  Example: npx @zhachory1/agent-fleet install --dir ~/.mewrite
  -> <DIR>/agents + <DIR>/skills/{council,ship} + <DIR>/prompts
  fallback: bash install.sh --dir ~/.mewrite
- Generic flat rules dir:
  npx @zhachory1/agent-fleet install --target <DIR> --copy
  fallback: bash install.sh --target <DIR> --copy

More: INSTALL.md and install.manifest.json.
HELP
}

print_help() {
  cat <<HELP
agent-fleet installer v${VERSION}

Primary npm UX:
  npx @zhachory1/agent-fleet install [options]

Fallback script UX:
  install.sh [options]

Options:
  --tool claude              Default. Symlink personas → ~/.claude/agents,
                             skill → ~/.claude/skills/council
                             (copies personas when AGENT_FLEET_SUBAGENT_MODEL is set)
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
  --dir DIR                  Generic user-global install for tools not known here
                             (example: --dir ~/.mewrite). Copies:
                             agents → DIR/agents,
                             skill → DIR/skills/council,
                             prompt → DIR/prompts/council-orchestrator.md
  --dir DIR --uninstall      Remove the generic install from DIR
  --project                  Cave only. Project-scope install (default)
  --user                     Cave only. User-scope install
  --target DIR               Place personas + orchestrator prompt into DIR
                             (any tool; explicit override of --tool defaults)
  --copy                     Used with --target: copy files instead of symlinking
                             (for tools that don't follow symlinks or sandboxed dirs)
  --agent-instructions       Print the install decision tree for AI coding agents
  --print                    Print the portable orchestrator prompt to stdout
                             (paste into any AI chat that doesn't have a plugin model)
  --version, -V              Print version and exit
  --help, -h                 This message

Examples:
  npx @zhachory1/agent-fleet install --tool claude                    # Claude Code, durable copies
  npx @zhachory1/agent-fleet install --tool cursor                    # Cursor: copy into ./.cursor/rules/
  npx @zhachory1/agent-fleet install --tool opencode                  # opencode: copy into ./.agent-fleet/
  npx @zhachory1/agent-fleet install --tool codex                     # Codex: copy prompt/personas + install skill
  npx @zhachory1/agent-fleet install --tool cave                      # Cave: install into ./.cave/{agents,skills,prompts}
  npx @zhachory1/agent-fleet install --dir ~/.mewrite                 # unknown TUI: generic global DIR/{agents,skills,prompts}
  npx @zhachory1/agent-fleet install --target ./custom/path --copy    # explicit flat target override
  npx @zhachory1/agent-fleet install --agent-instructions             # agent-facing install decision tree
  npx @zhachory1/agent-fleet install --print | pbcopy                 # copy prompt to clipboard for chat tools

Fallback examples when npm/npx is unavailable:
  bash install.sh --tool claude      # symlinks from local clone by default
  AGENT_FLEET_INSTALL_COPY=1 bash install.sh --tool claude
  bash install.sh --dir ~/.mewrite

Model override:
  Spawned agents default to cheaper \`model: haiku\`. Set
  AGENT_FLEET_SUBAGENT_MODEL=<model> during install to rewrite installed
  agent frontmatter. This does not change the parent/orchestrator model.

Copy mode:
  AGENT_FLEET_INSTALL_COPY=1 forces copy mode for native installs. The npm CLI
  sets this automatically so one-shot npx installs do not point at npm cache paths.

Requirements: bash for install; jq for council journal/transcript helpers.
  Run \`bash $SRC/lib/journal.sh --help\` for journal CLI usage.
HELP
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tool) TOOL="${2:?}"; shift 2;;
    --target) TARGET="${2:?}"; shift 2;;
    --dir) INSTALL_DIR="${2:?}"; shift 2;;
    --copy) COPY=1; shift;;
    --uninstall) UNINSTALL=1; shift;;
    --project) SCOPE="project"; shift;;
    --user) SCOPE="user"; shift;;
    --agent-instructions) AGENT_INSTRUCTIONS=1; shift;;
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
if [ "$AGENT_INSTRUCTIONS" = "1" ]; then
  print_agent_instructions
  exit 0
fi
if [ "$PRINT" = "1" ]; then
  cat "$SRC/prompts/council-orchestrator.md"
  exit 0
fi

if [ -n "$SUBAGENT_MODEL_OVERRIDE" ]; then
  case "$SUBAGENT_MODEL_OVERRIDE" in
    *$'\n'*|*$'\r'*) echo "install.sh: AGENT_FLEET_SUBAGENT_MODEL must be a single-line model id." >&2; exit 1;;
  esac
  if ! printf '%s' "$SUBAGENT_MODEL_OVERRIDE" | grep -Eq '^[[:alnum:]_.:/+-]+$'; then
    echo "install.sh: AGENT_FLEET_SUBAGENT_MODEL contains unsupported characters: $SUBAGENT_MODEL_OVERRIDE" >&2
    exit 1
  fi
fi

# jq is required by journal/transcript helpers, but not by payload installation itself.
# Keep install low-friction; warn instead of blocking npm/npx installs.
if ! command -v jq >/dev/null 2>&1; then
  echo "install.sh: WARN jq not found. Install still proceeds, but council journal/transcript helpers require jq." >&2
  echo "  macOS:  brew install jq" >&2
  echo "  Debian: apt-get install jq" >&2
  echo "  Other:  https://jqlang.github.io/jq/download/" >&2
fi

place() { # place <src-file> <dst-path>
  mkdir -p "$(dirname "$2")"
  rm -f "$2"
  if [ "$COPY" = "1" ]; then cp -f "$1" "$2"; else ln -sf "$1" "$2"; fi
}
place_dir() { # place_dir <src-dir> <dst-dir>; copy-only for sandboxed tool resource dirs
  mkdir -p "$(dirname "$2")"
  if [ -L "$2" ] || [ -f "$2" ]; then rm -f "$2"; fi
  mkdir -p "$2"
  cp -R "$1"/. "$2"/
}
place_agent() { # place_agent <src-file> <dst-path>
  local tmp
  mkdir -p "$(dirname "$2")"
  if [ -z "$SUBAGENT_MODEL_OVERRIDE" ]; then
    place "$1" "$2"
    return
  fi
  tmp="$2.tmp.$$"
  if ! awk -v model="$SUBAGENT_MODEL_OVERRIDE" '
    BEGIN { in_frontmatter = 0; replaced = 0 }
    NR == 1 && $0 == "---" { in_frontmatter = 1; print; next }
    in_frontmatter && $0 == "---" { in_frontmatter = 0; print; next }
    in_frontmatter && /^model:[[:space:]]*/ { print "model: " model; replaced = 1; next }
    { print }
    END { if (!replaced) exit 42 }
  ' "$1" > "$tmp"; then
    echo "install.sh: failed to rewrite model frontmatter for $1" >&2
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$2"
}
place_cave_persona() { # place_cave_persona <src-file> <dst-path>
  local tmp
  mkdir -p "$(dirname "$2")"
  # Cave's tool registry uses lowercase canonical tool names. Keep source personas
  # Claude-Code-compatible; transform only the Cave install copies.
  tmp="$2.tmp.$$"
  if ! awk -v model="$SUBAGENT_MODEL_OVERRIDE" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    BEGIN {
      in_frontmatter = 0; replaced = (model == "")
      map["Read"] = "read"; map["Bash"] = "bash"; map["Edit"] = "edit"; map["Write"] = "write"
      map["Grep"] = "grep"; map["Glob"] = "find"; map["LS"] = "ls"; map["Ls"] = "ls"
    }
    NR == 1 && $0 == "---" { in_frontmatter = 1; print; next }
    in_frontmatter && $0 == "---" { in_frontmatter = 0; print; next }
    in_frontmatter && model != "" && /^model:[[:space:]]*/ {
      print "model: " model
      replaced = 1
      next
    }
    in_frontmatter && /^tools:[[:space:]]*/ {
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
    END { if (!replaced) exit 42 }
  ' "$1" > "$tmp"; then
    echo "install.sh: failed to transform Cave persona $1" >&2
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$2"
}
remove_agents() { # remove_agents <dst-dir>
  local f
  while IFS= read -r f; do rm -f "$1/$(basename "$f")"; done < <(agent_payloads)
}
place_agents() { # place_agents <dst-dir>
  local f
  while IFS= read -r f; do place_agent "$f" "$1/$(basename "$f")"; done < <(agent_payloads)
}
place_cave_personas() { # place_cave_personas <dst-dir>
  local f
  while IFS= read -r f; do place_cave_persona "$f" "$1/$(basename "$f")"; done < <(agent_payloads)
}
# personas: enumerate the actual persona files. Excludes:
#   - _overlay.md          (private overlay, not a persona; gitignored)
#   - _rokt-overlay.md     (legacy private overlay name; gitignored)
#   - _overlay.md.example  (overlay template, not a persona)
#   - INDEX.md             (the catalog, not a persona)
personas() {
  for f in "$SRC"/agents/*.md; do
    case "$(basename "$f")" in
      _overlay.md|_rokt-overlay.md|_overlay.md.example|INDEX.md) continue ;;
    esac
    echo "$f"
  done
}

ship_agents() {
  for f in "$SRC"/ship-agents/*.md; do
    [ -e "$f" ] || continue
    echo "$f"
  done
}
agent_payloads() {
  personas
  ship_agents
}

# Generic global install for unknown TUI home dirs (for example ~/.mewrite).
# This is intentionally copy-only and uses the conventional {agents,skills,prompts}
# resource layout. Use --target for a flat directory instead.
if [ -n "$INSTALL_DIR" ]; then
  AGENTS_DST="$INSTALL_DIR/agents"
  SKILL_DST="$INSTALL_DIR/skills/council"
  SHIP_SKILL_DST="$INSTALL_DIR/skills/ship"
  PROMPT_DST="$INSTALL_DIR/prompts/council-orchestrator.md"
  SHIP_PROMPT_DST="$INSTALL_DIR/prompts/ship-orchestrator.md"
  if [ "$UNINSTALL" = "1" ]; then
    remove_agents "$AGENTS_DST"
    rm -f "$PROMPT_DST" "$SHIP_PROMPT_DST"
    rm -rf "$SKILL_DST" "$SHIP_SKILL_DST"
    echo "agent-fleet: uninstalled generic payload from $INSTALL_DIR"
    exit 0
  fi
  COPY=1
  place_agents "$AGENTS_DST"
  place_dir "$SRC/skills/council" "$SKILL_DST"
  place_dir "$SRC/skills/ship" "$SHIP_SKILL_DST"
  place "$SRC/prompts/council-orchestrator.md" "$PROMPT_DST"
  place "$SRC/prompts/ship-orchestrator.md" "$SHIP_PROMPT_DST"
  echo "agent-fleet: installed generic agents → $AGENTS_DST"
  echo "agent-fleet: installed generic council skill → $SKILL_DST"
  echo "agent-fleet: installed generic ship skill → $SHIP_SKILL_DST"
  echo "agent-fleet: installed generic council prompt → $PROMPT_DST"
  echo "agent-fleet: installed generic ship prompt → $SHIP_PROMPT_DST"
  echo "Set AGENT_FLEET_HOME=$SRC so the lib/ helpers (transcript/journal) resolve."
  exit 0
fi

# Generic target: drop personas + the portable orchestrator prompt into DIR.
if [ -n "$TARGET" ]; then
  place_agents "$TARGET"
  place "$SRC/prompts/council-orchestrator.md" "$TARGET/council-orchestrator.md"
  place "$SRC/prompts/ship-orchestrator.md" "$TARGET/ship-orchestrator.md"
  echo "agent-fleet: placed $(agent_payloads | wc -l | tr -d ' ') agents + council + ship prompts into $TARGET"
  echo "Set AGENT_FLEET_HOME=$SRC so the lib/ helpers (transcript/journal) resolve."
  exit 0
fi

# Tool shortcuts for tools with project-local layouts.
case "$TOOL" in
  cursor)
    [ -n "$TARGET" ] || TARGET="./.cursor/rules"
    COPY=1  # Cursor's rules dir doesn't follow symlinks reliably
    place_agents "$TARGET"
    place "$SRC/prompts/council-orchestrator.md" "$TARGET/council-orchestrator.md"
    place "$SRC/prompts/ship-orchestrator.md" "$TARGET/ship-orchestrator.md"
    echo "agent-fleet: placed $(agent_payloads | wc -l | tr -d ' ') agents + council + ship prompts into $TARGET"
    echo "Cursor will auto-load .cursor/rules/. Set AGENT_FLEET_HOME=$SRC so the lib/ helpers resolve."
    exit 0
    ;;
  opencode)
    [ -n "$TARGET" ] || TARGET="./.agent-fleet"
    COPY=1
    place_agents "$TARGET"
    place "$SRC/prompts/council-orchestrator.md" "$TARGET/council-orchestrator.md"
    place "$SRC/prompts/ship-orchestrator.md" "$TARGET/ship-orchestrator.md"
    echo "agent-fleet: placed $(agent_payloads | wc -l | tr -d ' ') agents + council + ship prompts into $TARGET"
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
    CODEX_SHIP_SKILL_DST="$CODEX_BASE/skills/ship"
    CODEX_BUNDLE_DST="$CODEX_BASE/agent-fleet"
    if [ "$UNINSTALL" = "1" ]; then
      remove_agents "$TARGET"
      rm -f "$TARGET/council-orchestrator.md" "$TARGET/ship-orchestrator.md"
      rm -rf "$CODEX_SKILL_DST" "$CODEX_SHIP_SKILL_DST" "$CODEX_BUNDLE_DST"
      echo "agent-fleet: uninstalled Codex project files from $TARGET and global payload from $CODEX_BASE"
      exit 0
    fi
    place_agents "$TARGET"
    place "$SRC/prompts/council-orchestrator.md" "$TARGET/council-orchestrator.md"
    place "$SRC/prompts/ship-orchestrator.md" "$TARGET/ship-orchestrator.md"
    place_dir "$SRC/skills/council" "$CODEX_SKILL_DST"
    place_dir "$SRC/skills/ship" "$CODEX_SHIP_SKILL_DST"
    mkdir -p "$CODEX_BUNDLE_DST/agents" "$CODEX_BUNDLE_DST/prompts"
    place_agents "$CODEX_BUNDLE_DST/agents"
    place "$SRC/prompts/council-orchestrator.md" "$CODEX_BUNDLE_DST/prompts/council-orchestrator.md"
    place "$SRC/prompts/ship-orchestrator.md" "$CODEX_BUNDLE_DST/prompts/ship-orchestrator.md"
    echo "agent-fleet: placed $(agent_payloads | wc -l | tr -d ' ') agents + council + ship prompts into $TARGET"
    echo "agent-fleet: installed Codex council skill → $CODEX_SKILL_DST"
    echo "agent-fleet: installed Codex ship skill → $CODEX_SHIP_SKILL_DST"
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
      CAVE_SHIP_SKILL_DST="$CAVE_BASE/skills/ship"
      CAVE_PROMPT_DST="$CAVE_BASE/prompts/council-orchestrator.md"
      CAVE_SHIP_PROMPT_DST="$CAVE_BASE/prompts/ship-orchestrator.md"
    else
      CAVE_AGENTS_DST="./.cave/agents"
      CAVE_SKILL_DST="./.cave/skills/council"
      CAVE_SHIP_SKILL_DST="./.cave/skills/ship"
      CAVE_PROMPT_DST="./.cave/prompts/council-orchestrator.md"
      CAVE_SHIP_PROMPT_DST="./.cave/prompts/ship-orchestrator.md"
    fi
    if [ "$UNINSTALL" = "1" ]; then
      remove_agents "$CAVE_AGENTS_DST"
      rm -f "$CAVE_PROMPT_DST" "$CAVE_SHIP_PROMPT_DST"
      rm -rf "$CAVE_SKILL_DST" "$CAVE_SHIP_SKILL_DST"
      echo "agent-fleet: uninstalled Cave $SCOPE-scope files."
      exit 0
    fi
    place_cave_personas "$CAVE_AGENTS_DST"
    place "$SRC/prompts/council-orchestrator.md" "$CAVE_PROMPT_DST"
    place "$SRC/prompts/ship-orchestrator.md" "$CAVE_SHIP_PROMPT_DST"
    place_dir "$SRC/skills/council" "$CAVE_SKILL_DST"
    place_dir "$SRC/skills/ship" "$CAVE_SHIP_SKILL_DST"
    echo "agent-fleet: installed Cave $SCOPE-scope agents → $CAVE_AGENTS_DST"
    echo "agent-fleet: installed Cave council skill → $CAVE_SKILL_DST"
    echo "agent-fleet: installed Cave ship skill → $CAVE_SHIP_SKILL_DST"
    echo "agent-fleet: installed Cave council prompt → $CAVE_PROMPT_DST"
    echo "agent-fleet: installed Cave ship prompt → $CAVE_SHIP_PROMPT_DST"
    echo "Cave agent copies map Claude-Code tool names to Cave lowercase names."
    echo "Set AGENT_FLEET_HOME=$SRC so the lib/ helpers (transcript/journal) resolve."
    exit 0
    ;;
esac

# Claude Code (default): native agents + skill dirs.
case "$TOOL" in
  claude)
    AGENTS_DST="$HOME/.claude/agents"; SKILL_DST="$HOME/.claude/skills/council"; SHIP_SKILL_DST="$HOME/.claude/skills/ship"
    if [ "$UNINSTALL" = "1" ]; then
      remove_agents "$AGENTS_DST"
      rm -rf "$SKILL_DST" "$SHIP_SKILL_DST"; echo "agent-fleet: uninstalled Claude files."; exit 0
    fi
    mkdir -p "$AGENTS_DST" "$HOME/.claude/skills"
    place_agents "$AGENTS_DST"
    if [ "$COPY" = "1" ]; then
      place_dir "$SRC/skills/council" "$SKILL_DST"
      place_dir "$SRC/skills/ship" "$SHIP_SKILL_DST"
    else
      ln -sfn "$SRC/skills/council" "$SKILL_DST"
      ln -sfn "$SRC/skills/ship" "$SHIP_SKILL_DST"
    fi
    echo "agent-fleet: installed for Claude Code. agents → $AGENTS_DST ; council skill → $SKILL_DST ; ship skill → $SHIP_SKILL_DST"
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
