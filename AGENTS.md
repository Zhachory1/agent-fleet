# AGENTS.md — agent-fleet

This repo is a portable **council of specialist review personas** + an orchestrator that convenes
3-6 of them, runs a bounded N-iteration reflection debate (critique-before-concede; default 2,
cap 4 iterations), and synthesizes a decision-grade answer with named dissents.
Tools that read `AGENTS.md` (Codex, opencode, …) pick this up automatically. Cursor reads
`.cursor/rules/` instead — `npx @zhachory1/agent-fleet install --target ./.cursor/rules --copy` places the personas +
orchestrator prompt where Cursor will find them.

## Installing agent-fleet into a TUI

If you are an AI coding agent installing this repo for a user: **do not vendor this repo into the user's project**. Install only the payload files into the TUI's resource folder:

- council personas: `agents/*.md`
- ship implementation agents: `ship-agents/*.md`
- skills: `skills/council/`, `skills/ship/`
- prompts: `prompts/council-orchestrator.md`, `prompts/ship-orchestrator.md`

Decision tree:

- Claude Code: `npx @zhachory1/agent-fleet install --tool claude` → `~/.claude/agents` + `~/.claude/skills/{council,ship}`
- Codex CLI: `npx @zhachory1/agent-fleet install --tool codex` → `~/.codex/skills/{council,ship}` + `~/.codex/agent-fleet`
- Cave project: `npx @zhachory1/agent-fleet install --tool cave` → `./.cave/{agents,skills,prompts}`
- Cave user-global: `npx @zhachory1/agent-fleet install --tool cave --user` → `${CAVE_HOME:-~/.cave}`
- Cursor: `npx @zhachory1/agent-fleet install --tool cursor` → `./.cursor/rules`
- opencode: `npx @zhachory1/agent-fleet install --tool opencode` → `./.agent-fleet`
- Unknown TUI with a global config dir: ask the user for that dir, then run `npx @zhachory1/agent-fleet install --dir <DIR>`
  - Example: Mewrite → `npx @zhachory1/agent-fleet install --dir ~/.mewrite`
- Generic flat rules dir: `npx @zhachory1/agent-fleet install --target <DIR> --copy`

Spawned personas and ship agents default to cheaper `model: haiku`; set `AGENT_FLEET_SUBAGENT_MODEL=<model>` while installing to rewrite installed agent copies to another model.

Use `bash install.sh ...` only as the fallback when npm/npx is unavailable.

Before guessing, run `npx @zhachory1/agent-fleet install --agent-instructions` or read `INSTALL.md` / `install.manifest.json`.

## To run a council
Load the orchestrator prompt at `prompts/council-orchestrator.md` and follow it. The reviewer
personas live in `agents/*.md` — each is a self-contained system prompt (one judgment lens).
For accepted implementation work, load `prompts/ship-orchestrator.md` or invoke the `ship` skill;
its implementation agents live in `ship-agents/*.md`.

Personas:
- **Core six** — `ml-scientist` (model quality), `ab-critic` (experiment validity),
  `reliability-sentinel` (production/blast-radius), `software-architect` (boundaries/coupling),
  `generalist-swe` (simplicity/correctness), `red-team` (adversarial).
- **Promoted dogfood-validated** — `data-engineer` (pipelines/schemas/backfills), `perf-engineer`
  (tail latency / throughput), `product-pm` (user value / scope), `cost-finops` ($/req / TCO /
  build-vs-buy), `docs-dx` (API ergonomics / onboarding friction), `mvp` (smallest-real-signal
  advocate; cuts scope), `occams-razor` (complexity-cutter), `cto` (3-5yr platform / tech arc),
  `ceo` (strategy / narrative / opportunity cost), `vp-eng` (capacity / sequencing / staffing reality).
- **Experimental** — `pre-mortem` (work backward from imagined catastrophe).

Pick 3-6 by task (Rev 3: was 2-4). Rev 5: `--mode ship` and no-flag default auto-include
`red-team`, `mvp`, and `occams-razor` as standing scope-and-realism controls; `--mode research`,
`--mode domain`, `--mode exec`, and `--mode minimal` do not auto-include all three. `--personas`
forces an exact 3-6 persona roster. See `agents/INDEX.md` for the catalog + decision tree
(including overlap flags), and the orchestrator prompt's selection table for routing rules. At >4
personas, overlap check is mandatory: high persona counts amplify false-consensus pressure if
multiple picks share a same-group lens.

## What you get depends on your tool
- **Subagent-capable** (Claude Code Task tool, opencode subagents): each persona's round-1
  POSITION is generated in an isolated context, then the orchestrator synthesizes.
- **Single-context** (Codex, Cursor, generic chat): the agent adopts each persona's prompt in
  sequence within one context. Round-1 POSITIONs have potential cross-persona contamination
  (persona 4 has seen personas 1–3's outputs in-context). Reflection rounds (round 2+) work
  in both modes — each persona reads peers' prior POSITIONs and must REFUTE-FIRST before
  conceding. In the 10-pair dogfood measurement, parallel self-vs-blinded-judge agreement was
  10/10 vs single-context 8/10 (mean paired delta +20pp; median 0pp, with 8/10 pairs tied).
  Prefer true parallel subagents when available; single-context remains usable with this caveat.

## Helpers (any environment with bash + jq)
Set `AGENT_FLEET_HOME` to this repo, then:
- `lib/transcript.sh capture|show|rooms` — persist + view the full per-persona reasoning.
- `lib/journal.sh append|stats` — counterfactual catch-rate log + gate dashboard (append refuses
  unless the run's transcript was captured).
- `lib/synth.sh flag` — deterministic consensus/dissent flag.

## Private overlay (optional)
If `agents/_overlay.md` exists, personas load it for your org's domain specifics (KPIs, stack,
hot paths, current priorities). It is gitignored — keep anything org-confidential out of the
committed personas and confined to your private overlay. See `agents/_overlay.md.example`.

Full design + rationale: `docs/{PRD,DD,PLAN}.md`. Install per tool: `README.md`.
