# Installing agent-fleet

If you are an AI coding agent installing agent-fleet for a user, follow this file.

## Rule

Do **not** vendor this repo into another project. Install only the agent-fleet payload:

- council persona prompts from `agents/*.md`
- ship implementation agents from `ship-agents/*.md`
- council skill from `skills/council/`
- ship skill from `skills/ship/`
- orchestrator prompts from `prompts/council-orchestrator.md` and `prompts/ship-orchestrator.md`

Put that payload in the AI TUI's normal resource folder.

Use npm/npx first. Use `install.sh` only as the fallback when npm is unavailable.

Spawned personas and ship agents default to cheaper `model: haiku`; the parent/orchestrator stays on the operator-selected model. To install spawned agents with another model, run:

```bash
AGENT_FLEET_SUBAGENT_MODEL=<model> npx @zhachory1/agent-fleet install ...
```

The override rewrites installed agent frontmatter at install time. Rerun the installer to change it later.

## Decision table

| If user uses... | Run | Installs to |
|---|---|---|
| Claude Code | `npx @zhachory1/agent-fleet install --tool claude` | `~/.claude/agents`, `~/.claude/skills/{council,ship}` |
| Codex CLI | `npx @zhachory1/agent-fleet install --tool codex` | `~/.codex/skills/{council,ship}`, `~/.codex/agent-fleet` |
| Cave project | `npx @zhachory1/agent-fleet install --tool cave` | `./.cave/{agents,skills,prompts}` |
| Cave user-global | `npx @zhachory1/agent-fleet install --tool cave --user` | `${CAVE_HOME:-~/.cave}` |
| Cursor | `npx @zhachory1/agent-fleet install --tool cursor` | `./.cursor/rules` |
| opencode | `npx @zhachory1/agent-fleet install --tool opencode` | `./.agent-fleet` |
| Unknown TUI with global config dir | `npx @zhachory1/agent-fleet install --dir <DIR>` | `<DIR>/agents`, `<DIR>/skills/{council,ship}`, `<DIR>/prompts` |
| Any generic flat rules dir | `npx @zhachory1/agent-fleet install --target <DIR> --copy` | `<DIR>/*.md` flat payload |

## Unknown TUI rule

If this repo does not know the TUI by name, ask the user for the TUI config/resource directory and use `--dir`.

Example:

```bash
npx @zhachory1/agent-fleet install --dir ~/.mewrite
```

This creates:

```text
~/.mewrite/agents/*.md
~/.mewrite/skills/council/SKILL.md
~/.mewrite/skills/ship/SKILL.md
~/.mewrite/prompts/council-orchestrator.md
~/.mewrite/prompts/ship-orchestrator.md
```

Uninstall:

```bash
npx @zhachory1/agent-fleet install --dir ~/.mewrite --uninstall
```

## Verify

```bash
npx @zhachory1/agent-fleet install --agent-instructions
npx @zhachory1/agent-fleet install --help
```

After install, verify expected files exist in the TUI resource dir. Do not guess paths if the TUI documents a different directory.

## Fallback without npm/npx

If npm/npx is unavailable, clone/download this repo and run the fallback script with the same flags:

```bash
git clone https://github.com/Zhachory1/agent-fleet ~/code/agent-fleet
cd ~/code/agent-fleet
bash install.sh --tool claude
```

The npm CLI intentionally delegates to the same installer logic so `npx @zhachory1/agent-fleet install ...` and `bash install.sh ...` stay aligned.
