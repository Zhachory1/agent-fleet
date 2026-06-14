# AGENTS.md — agent-fleet

This repo is a portable **council of specialist review personas** + an orchestrator that convenes
2-4 of them, runs a bounded N-iteration reflection debate (critique-before-concede; default 2,
cap 4), and synthesizes a decision-grade answer with named dissents.
Tools that read `AGENTS.md` (Codex, opencode, Cursor, …) pick this up automatically.

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
  red-team's attack-the-artifact lens).
- **Executive** — `cto` (3-5yr platform/tech arc), `ceo` (strategy / narrative / opportunity cost),
  `vp-eng` (capacity / sequencing / staffing reality).

Pick 2-4 by task — see `agents/INDEX.md` for the catalog + decision tree (including overlap flags),
and the orchestrator prompt's selection table for the routing rules.

## What you get depends on your tool
- **Subagent-capable** (Claude Code Task tool, opencode subagents): true parallel multi-agent
  council — each persona runs in isolation, then the orchestrator synthesizes.
- **Single-context** (Codex, Cursor, generic chat): the agent adopts each persona's prompt in
  sequence within one context ("solo council"). Useful, but closer to a single-context-multi-lens
  pass than a true multi-agent debate.

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
