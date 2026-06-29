# Installing agent-fleet

If you are an AI coding agent installing agent-fleet for a user, follow this file.

## Rule

Do **not** vendor this repo into another project. Install only the council payload:

- persona prompts from `agents/*.md`
- council skill from `skills/council/`
- orchestrator prompt from `prompts/council-orchestrator.md`

Put that payload in the AI TUI's normal resource folder.

## Decision table

| If user uses... | Run | Installs to |
|---|---|---|
| Claude Code | `bash install.sh --tool claude` | `~/.claude/agents`, `~/.claude/skills/council` |
| Codex CLI | `bash install.sh --tool codex` | `~/.codex/skills/council`, `~/.codex/agent-fleet` |
| Cave project | `bash install.sh --tool cave` | `./.cave/{agents,skills,prompts}` |
| Cave user-global | `bash install.sh --tool cave --user` | `${CAVE_HOME:-~/.cave}` |
| Cursor | `bash install.sh --tool cursor` | `./.cursor/rules` |
| opencode | `bash install.sh --tool opencode` | `./.agent-fleet` |
| Unknown TUI with global config dir | `bash install.sh --dir <DIR>` | `<DIR>/agents`, `<DIR>/skills/council`, `<DIR>/prompts` |
| Any generic flat rules dir | `bash install.sh --target <DIR> --copy` | `<DIR>/*.md` flat payload |

## Unknown TUI rule

If this repo does not know the TUI by name, ask the user for the TUI config/resource directory and use `--dir`.

Example:

```bash
bash install.sh --dir ~/.mewrite
```

This creates:

```text
~/.mewrite/agents/*.md
~/.mewrite/skills/council/SKILL.md
~/.mewrite/prompts/council-orchestrator.md
```

Uninstall:

```bash
bash install.sh --dir ~/.mewrite --uninstall
```

## Verify

```bash
bash install.sh --agent-instructions
bash install.sh --help
```

After install, verify expected files exist in the TUI resource dir. Do not guess paths if the TUI documents a different directory.

## npx/npm

Use the scoped package. The unscoped npm name `agent-fleet` belongs to another project.

```bash
npx @zhachory1/agent-fleet install --tool claude
npx @zhachory1/agent-fleet install --tool cave --user
npx @zhachory1/agent-fleet install --dir ~/.mewrite
npx @zhachory1/agent-fleet --print
```

The npm wrapper delegates to `install.sh` and defaults to copying payload files, so installs do not depend on symlinks into npm's cache. For repeated use across repos, a global install gives a stable helper path:

```bash
npm install -g @zhachory1/agent-fleet
export AGENT_FLEET_HOME="$(agent-fleet home)"
agent-fleet install --tool claude
```

Clone/download installs remain supported; direct `bash install.sh --tool claude` keeps its symlink behavior.
