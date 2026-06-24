# AGENTS.md — agent-fleet

This repo is a portable **council of specialist review personas** + an orchestrator that convenes
3-6 of them, runs a bounded N-iteration reflection debate (critique-before-concede; default 2,
cap 4 iterations), and synthesizes a decision-grade answer with named dissents.
Tools that read `AGENTS.md` (Codex, opencode, …) pick this up automatically. Cursor reads
`.cursor/rules/` instead — `install.sh --target ./.cursor/rules --copy` places the personas +
orchestrator prompt where Cursor will find them.

## Installing agent-fleet into a TUI

If you are an AI coding agent installing this repo for a user: **do not vendor this repo into the user's project**. Install only the payload files into the TUI's resource folder:

- personas: `agents/*.md`
- skill: `skills/council/`
- prompt: `prompts/council-orchestrator.md`

Decision tree:

- Claude Code: `bash install.sh --tool claude` → `~/.claude/agents` + `~/.claude/skills/council`
- Codex CLI: `bash install.sh --tool codex` → `~/.codex/skills/council` + `~/.codex/agent-fleet`
- Cave project: `bash install.sh --tool cave` → `./.cave/{agents,skills,prompts}`
- Cave user-global: `bash install.sh --tool cave --user` → `${CAVE_HOME:-~/.cave}`
- Cursor: `bash install.sh --tool cursor` → `./.cursor/rules`
- opencode: `bash install.sh --tool opencode` → `./.agent-fleet`
- Unknown TUI with a global config dir: ask the user for that dir, then run `bash install.sh --dir <DIR>`
  - Example: Mewrite → `bash install.sh --dir ~/.mewrite`
- Generic flat rules dir: `bash install.sh --target <DIR> --copy`

Before guessing, run `bash install.sh --agent-instructions` or read `INSTALL.md` / `install.manifest.json`.

## To run a council
Load the orchestrator prompt at `prompts/council-orchestrator.md` and follow it. The reviewer
personas live in `agents/*.md` — each is a self-contained system prompt (one judgment lens).

Personas:
- **Core six** — `ml-scientist` (model quality), `ab-critic` (experiment validity),
  `reliability-sentinel` (production/blast-radius), `software-architect` (boundaries/coupling),
  `generalist-swe` (simplicity/correctness), `red-team` (adversarial).
- **Domain** — `data-engineer` (pipelines/schemas/backfills), `perf-engineer` (tail latency /
  throughput), `product-pm` (user value / scope), `cost-finops` ($/req / TCO / build-vs-buy),
  `docs-dx` (API ergonomics / onboarding friction).
- **Adversarial complement** — `pre-mortem` (work backward from imagined catastrophe; complement to
  red-team's attack-the-artifact lens), `mvp` (smallest-real-signal advocate; deliberately
  oppositional to red-team and pre-mortem — cuts scope where they add), `occams-razor`
  (complexity-cutter; cuts abstractions/layers until the payoff is real).
- **Executive** — `cto` (3-5yr platform/tech arc), `ceo` (strategy / narrative / opportunity cost),
  `vp-eng` (capacity / sequencing / staffing reality).

Pick 3-6 by task (Rev 3: was 2-4). Rev 4: `red-team`, `mvp`, `occams-razor` are auto-included
in every council as the standing scope-and-realism controls (opt out per-call with reason). See
`agents/INDEX.md` for the catalog + decision tree (including
overlap flags), and the orchestrator prompt's selection table for the routing rules. At >4 personas,
the overlap check is mandatory: high persona counts amplify false-consensus pressure if multiple picks
share a same-group lens.

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
