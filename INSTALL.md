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

No npm package is published yet. There is no `npx agent-fleet` installer today. Clone/download this repo and run `install.sh`.

Future `npx` support should only wrap the same behavior: copy the payload into the TUI resource folder, with `--dir` as the escape hatch for unknown tools.
