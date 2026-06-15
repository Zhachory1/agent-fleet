# AGENTS.md — agent-fleet

This repo is a portable **council of specialist review personas** + an orchestrator that convenes
2-4 of them, runs a bounded N-iteration reflection debate (critique-before-concede; default 2,
cap 4), and synthesizes a decision-grade answer with named dissents.
Tools that read `AGENTS.md` (Codex, opencode, …) pick this up automatically. Cursor reads
`.cursor/rules/` instead — `install.sh --target ./.cursor/rules --copy` places the personas +
orchestrator prompt where Cursor will find them.

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
  oppositional to red-team and pre-mortem — cuts scope where they add).
- **Executive** — `cto` (3-5yr platform/tech arc), `ceo` (strategy / narrative / opportunity cost),
  `vp-eng` (capacity / sequencing / staffing reality).

Pick 2-4 by task — see `agents/INDEX.md` for the catalog + decision tree (including overlap flags),
and the orchestrator prompt's selection table for the routing rules.

## What you get depends on your tool
- **Subagent-capable** (Claude Code Task tool, opencode subagents): each persona's round-1
  POSITION is generated in an isolated context, then the orchestrator synthesizes.
- **Single-context** (Codex, Cursor, generic chat): the agent adopts each persona's prompt in
  sequence within one context. Round-1 POSITIONs have potential cross-persona contamination
  (persona 4 has seen personas 1–3's outputs in-context). Reflection rounds (round 2+) work
  in both modes — each persona reads peers' prior POSITIONs and must REFUTE-FIRST before
  conceding. The magnitude of round-1 contamination is not measured; the lens-baseline arm
  in `journal.sh stats` compares any council mode against same-lenses-single-pass, not the
  two modes against each other.

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
