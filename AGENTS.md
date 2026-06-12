# AGENTS.md — agent-fleet

This repo is a portable **council of specialist review personas** + an orchestrator that convenes
2-4 of them, runs a bounded debate, and synthesizes a decision-grade answer with named dissents.
Tools that read `AGENTS.md` (Codex, opencode, Cursor, …) pick this up automatically.

## To run a council
Load the orchestrator prompt at `prompts/council-orchestrator.md` and follow it. The reviewer
personas live in `agents/*.md` — each is a self-contained system prompt (one judgment lens).

Personas: `ml-scientist` (model quality), `ab-critic` (experiment validity), `reliability-sentinel`
(production/blast-radius), `software-architect` (boundaries/coupling), `generalist-swe`
(simplicity/correctness), `red-team` (adversarial). Pick 2-4 by task — see the orchestrator prompt's
selection table.

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

## Rokt overlay (optional, private)
If `agents/_rokt-overlay.md` exists, personas load it for domain specifics. It is gitignored — keep
Rokt-confidential context out of the committed personas. See `agents/_rokt-overlay.md.example`.

Full design + rationale: `docs/{PRD,DD,PLAN}.md`. Install per tool: `README.md`.
