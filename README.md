# agent-fleet

A portable **council of specialist review personas** for high-stakes engineering decisions —
model changes, experiment readouts, design docs, serving-path PRs, architecture / build-vs-buy.

You convene 2-4 orthogonal personas, they review an artifact from independent angles, and an
orchestrator synthesizes one decision-grade answer with **ranked issues, named dissents, and a
false-consensus flag**. It's built to *disagree with you* — to catch what a single pass misses.

```
your decision  ──▶  /council <task>
                      ├─ pick 2-4 personas (by task)
                      ├─ each reviews from its lens  ─┐
                      │                               │  ml-scientist · ab-critic
                      │                               │  reliability-sentinel · red-team
                      │                               │  software-architect · generalist-swe
                      └─ synthesize ◀─────────────────┘
                         ranked issues · named dissents · ⚠ false-consensus
```

## The personas (each a self-contained system prompt in `agents/`)

| Persona | Lens | Catches |
|---|---|---|
| `ml-scientist` | skeptical ML researcher | calibration, train/serve skew, leakage, metric choice, drift |
| `ab-critic` | experiment statistician | power/MDE, peeking, interference (SUTVA), holdout hygiene |
| `reliability-sentinel` | SRE | blast radius, rollback, SLO/latency, fallback, hot-path risk |
| `software-architect` | boundaries-first | coupling, bounded contexts, evolvability, build-vs-buy, contracts |
| `generalist-swe` | pragmatic IC | simplicity, over-engineering, correctness, edge cases, test gaps |
| `red-team` | adversary | strongest case against, hand-waved assumptions, what breaks first |

Personas are generic. A private, gitignored `agents/_overlay.md` (see the `.example`) adds
domain specifics when present; absent, they run generic with no error.

## What you get depends on your tool

The personas and the bash helpers are portable everywhere. The **parallel multi-agent** part needs
a subagent primitive:

| Tool | Council mode | How |
|---|---|---|
| **Claude Code** | full parallel (Task tool) | `install.sh` → native agents + `/council` skill |
| **opencode** | full parallel (subagents) | `AGENTS.md` + `--target` personas; orchestrate via subagents |
| **Codex CLI** | solo council (single context) | reads root `AGENTS.md`; run the orchestrator prompt |
| **Cursor** | solo council (single context) | drop personas into `.cursor/rules/`; paste orchestrator prompt |
| **any AI chat** | solo council (single context) | `install.sh --print` → paste the prompt |

> **Honest note:** "solo council" = the agent adopts each persona's prompt in sequence within one
> context. That's closer to a *single-context-multi-lens* pass than a true multi-agent debate. The
> journal's lens-baseline arm exists precisely to measure whether the multi-agent version earns its
> extra cost over this.

## Install

### Claude Code (full council)
```bash
git clone <repo> ~/code/agent-fleet && cd ~/code/agent-fleet
bash install.sh                     # symlinks agents → ~/.claude/agents, skill → ~/.claude/skills/council
# then in Claude Code:  /council review this diff …
bash install.sh --uninstall         # reversible
```

### Codex CLI / opencode (AGENTS.md-aware)
```bash
export AGENT_FLEET_HOME=~/code/agent-fleet
# these tools read AGENTS.md at the repo root automatically. From inside your project, point them
# at the personas + orchestrator prompt:
bash "$AGENT_FLEET_HOME/install.sh" --target ./.agent-fleet --copy
# then ask the agent: "act as the council orchestrator in ./.agent-fleet/council-orchestrator.md"
```
On opencode, map Step 3's persona spawns to its subagent mechanism for a true parallel council.

### Cursor
```bash
bash ~/code/agent-fleet/install.sh --target ./.cursor/rules --copy
# Cursor loads .cursor/rules; invoke with: "run the council (see council-orchestrator.md)"
```

### Any AI editor / chat (no install)
```bash
bash ~/code/agent-fleet/install.sh --print   # prints the orchestrator prompt — paste into the chat
# then paste the 2-4 relevant agents/*.md persona prompts when asked
```

## Helpers (any environment with bash + jq)
```bash
export AGENT_FLEET_HOME=~/code/agent-fleet
$AGENT_FLEET_HOME/lib/transcript.sh show [council-<slug>]   # full per-persona reasoning, boxed
$AGENT_FLEET_HOME/lib/transcript.sh rooms                   # past councils
$AGENT_FLEET_HOME/lib/journal.sh stats [N]                  # catch-rate / false-alarm / gate verdict
```
The journal append **refuses** unless the run's transcript was captured — you can't record a
council whose thinking wasn't saved.

## How it works (design)
Personas are stateless one-shot reviewers; the **orchestrator** sequences rounds and holds all
state (subagents can't talk live — there's no reader left alive to listen mid-turn). It runs N
**reflection iterations** (`--council --iterations N`, default 2, hard cap 4): iteration 1 is
blind, later iterations inject peers' full prior positions and personas revise via
**critique-before-concede** (refute first, concede only what you can't refute), with a deterministic
convergence + capitulation detector. ≤4 personas, then synthesizes. Full rationale + the validation
gate in `docs/{PRD,DD,PLAN}.md`; the iteration feature in
`docs/features/iterative-reflection/{PRD,DD,PLAN}.md`.

## Tests
```bash
for t in test/*.sh; do bash "$t"; done
```

## Run it on this repo
A council was run on this project's own design doc during development; browse it:
```bash
bash lib/transcript.sh show council-dd-review
```
