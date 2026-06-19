# agent-fleet

![agent-fleet banner](assets/fleet.jpg)

[![tests](https://github.com/Zhachory1/agent-fleet/actions/workflows/test.yml/badge.svg)](https://github.com/Zhachory1/agent-fleet/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A portable **council of specialist review personas** for high-stakes engineering decisions.
You convene 3–6 orthogonal reviewers, they critique your artifact from independent angles, and
an orchestrator runs a bounded reflection debate (critique-before-concede, ≤4 rounds), then
synthesizes one decision-grade answer with **ranked issues, named dissents, and a
false-consensus flag**. Built to *disagree with you* — catch what a single pass misses.

> ⚠ **Research-grade, not production-grade.** This is a tool I built for myself and am
> publishing openly. Current dogfood journal snapshot: net-new catch rate is high
> (42/44 = 95%), but it is still mostly author/operator-run. The lens-baseline arm remains
> insufficient (4/4; gate needs n≥10), and the blinded-judge Phase 2 arm is in progress
> (21/50 rooms judged, 19/21 self-vs-blind agreement). Treat all metrics as directional
> dogfood evidence until [issue #1](../../issues/1) completes the 50-run Phase 2 decision.

## Current status

| Area | Current state |
|---|---|
| Personas | 17 total: 6 core + 11 experimental |
| Tool support | Claude Code, Cave, opencode, Codex, Cursor, generic chat |
| Tests | 18 shell test scripts; same loop runs in CI |
| Parallel vs single-context | 10-pair dogfood complete: parallel 10/10, single-context 8/10, mean +20pp, median 0pp |
| Blinded judge | Phase 1 complete; Phase 2 in progress at 21/50 judged rooms |
| Lens baseline | 4/4 so far; gate needs n≥10 |
| External validation | Still needed: non-author operators on their own artifacts |

## Quick start

```bash
git clone https://github.com/Zhachory1/agent-fleet ~/code/agent-fleet
cd ~/code/agent-fleet
export AGENT_FLEET_HOME=$PWD
# Read the maturity disclaimer above before relying on output as decision-grade.
bash install.sh                # Claude Code (default; symlinks)
# OR: bash install.sh --tool cursor    # Cursor   (→ ./.cursor/rules/)
# OR: bash install.sh --tool opencode  # opencode (→ ./.agent-fleet/)
# OR: bash install.sh --tool codex     # Codex    (→ ./.agent-fleet/ + ~/.codex/skills/council)
# OR: bash install.sh --tool cave      # Cave     (→ ./.cave/{agents,skills,prompts})
# OR: bash install.sh --print | pbcopy  # any chat: paste the prompt
bash examples/first-council/run.sh         # see a real run end-to-end (isolated tmpdir)
```

## What you get

[`examples/first-council/`](examples/first-council/) is a complete, runnable council on a
fictional-but-realistic PRD (checkout feature-flag). Includes the input artifact, the operator's
solo decision, the per-persona POSITION blocks from a 2-round debate, the final synthesis with
verdict + ranked issues + named dissents, and a **net-new-vs-solo** table. On that example
council, the council surfaced 4 BLOCKERs/MAJORs the solo decision didn't name. Read it before
deciding whether to install.

## Not for you if…

- You want a managed product — this is a prompt structure + bash helpers, not a service.
- You don't already use an AI coding agent (Claude Code / Cursor / Cave / opencode / Codex / chat).
- You're not willing to write your decision *before* the council convenes — Step 0 is the
  whole point.
- You want a CI gate / merge-blocker. This is a thinking tool; the output requires judgment.
- You need pristine evidence the tool works. The validation arm is still open.

## How it works (30s)

```
your decision  ──▶  /council <task>
                      ├─ Step 0   — write your solo decision + risks you already see
                      ├─ Step 0.5 — same-lenses single-pass baseline (validation arm)
                      ├─ Step 2   — pick 3-6 personas by task (17 in catalog)
                      ├─ Step 3   — round 1: each persona reviews in isolation, blind
                      │             rounds 2..N (default 2, cap 4): each persona sees peers'
                      │             FULL prior positions and must REFUTE-FIRST before conceding
                      │             ↳ default-3 auto-included: red-team + mvp + occams-razor
                      │             ↳ deterministic convergence + capitulation detector
                      └─ Step 5   — synthesis: ranked issues, named dissents, false-consensus flag
                          Step 6  — journal the run (refuses unless transcript was captured)
```

Personas are stateless one-shot reviewers; the orchestrator (your AI coding agent) sequences
everything and holds the transcript. The reflection debate (each persona reads peers' full
prior positions, must refute before conceding) is what distinguishes a council from "ask 4 LLMs
the same question and average." Red-team carries a hardened concession rule. Full design
rationale: [`docs/PRD.md`](docs/PRD.md), [`docs/DD.md`](docs/DD.md).

## The personas (17 total — see [`agents/INDEX.md`](agents/INDEX.md))

**Core six** (n≥18 validation runs each):

| Persona | Lens | Catches |
|---|---|---|
| `ml-scientist` | skeptical ML researcher | calibration, train/serve skew, leakage, metric choice |
| `ab-critic` | experiment statistician | power/MDE, peeking, SUTVA, holdout hygiene |
| `reliability-sentinel` | SRE | blast radius, rollback, SLOs, fallback, hot-path risk |
| `software-architect` | boundaries-first | coupling, bounded contexts, evolvability, contracts |
| `generalist-swe` | pragmatic IC | simplicity, over-engineering, correctness, edge cases |
| `red-team` | adversary | strongest case against, hand-waved assumptions, what breaks first |

**Experimental eleven** (added 2026-06; not yet promoted to Core — promotion criterion is ≥3
logged real runs with `acted_on=true` per [`agents/INDEX.md`](agents/INDEX.md), which most
haven't hit yet; descriptions are `[experimental]`-prefixed in the YAML frontmatter so any
selection UI carries the warning):

| Persona | Group | Lens | Catches |
|---|---|---|---|
| `data-engineer` | domain | pipelines-first | idempotency, schema evolution, lineage, backfills, late-data |
| `perf-engineer` | domain | tail-latency-first | p99, allocation pressure, algorithmic complexity, caching, I/O patterns |
| `product-pm` | domain | user-value-first | problem clarity, scope, outcome-vs-output, adoption story, reversibility |
| `cost-finops` | domain | unit-economics-first | $/req, capacity, vendor lock, hidden costs, build-vs-buy TCO |
| `docs-dx` | domain | developer-experience-first | API ergonomics, error messages, onboarding friction, examples |
| `pre-mortem` | adversarial | reasons backward from imagined catastrophe | no-owner failure modes, slow-motion disasters, recovery story, one-way doors |
| `mvp` | adversarial | smallest-real-signal advocate | scope creep, polish creep, severity inflation across review rounds, two-way-door reversibility |
| `occams-razor` | adversarial | complexity-cutter | premature abstraction, speculative flexibility, indirection without payoff, framework-itis, rule-of-three violations |
| `cto` | executive | 3–5 year platform/tech arc | strategic fit, stack coherence, migration asymmetry, talent/hire, one-way doors |
| `ceo` | executive | strategy and narrative | why-this-why-now, opportunity cost, differentiation, brand, first-customer |
| `vp-eng` | executive | capacity and execution | who actually does this, sequencing, hiring-assumption risk, opportunity cost |

The **adversarial pair `red-team` + `pre-mortem`** are methodologically distinct (red-team
attacks the artifact as written; pre-mortem assumes it shipped + failed and reasons backward).
The **`mvp` persona is deliberately oppositional** to red-team + pre-mortem: they find more
risks, mvp cuts non-blocking scope. Picking mvp WITH either of them for any decision that's
been through 2+ review rounds gives the reflection debate a real argument to resolve.

Full catalog with overlap matrix + selection decision tree + persona-pairing recommendations:
[`agents/INDEX.md`](agents/INDEX.md). Frontmatter detail (the `model: sonnet` field is
Claude-Code-specific metadata; strip it from your local copy if your tool errors on unknown
frontmatter) is in [AGENTS.md](AGENTS.md).

## What you get depends on your tool

Personas + bash helpers are portable everywhere. What varies by tool is **round-1
isolation** — whether each persona's first POSITION is generated in a context that has not
seen the other personas' POSITIONs (true parallel via subagent primitive) or sequentially in
the same context ("single-context"). Reflection rounds (round 2+) work in both modes — each
persona still reads peers' prior-round POSITIONs and must REFUTE-FIRST before conceding.

| Tool | Round-1 isolation | How |
|---|---|---|
| **Claude Code** | parallel (Task tool) | `install.sh` → native agents + `/council` skill |
| **opencode** | parallel (subagents) | `AGENTS.md` + `--target` personas; orchestrate via subagents |
| **Codex CLI** | single-context | reads root `AGENTS.md`; run the orchestrator prompt |
| **Cursor** | single-context | drop personas into `.cursor/rules/`; paste orchestrator prompt |
| **Cave** | parallel when using subagents | `install.sh --tool cave` → `.cave/{agents,skills,prompts}` |
| **any AI chat** | single-context | `install.sh --print` → paste the prompt |

> **Honest disclosure on the difference:** parallel mode guarantees personas don't influence
> each other's round-1 POSITIONs; single-context mode has known round-1 contamination risk
> (persona 4 has seen personas 1–3's outputs in-context even if prompted to ignore them) and
> measured lower agreement in this dogfood sample. A 10-pair measurement on this repo found
> parallel self-vs-blinded-judge agreement
> at **10/10** vs single-context at **8/10** (mean paired delta **+20pp**, median **0pp**;
> 8/10 pairs tied, 2/10 favored parallel). Treat that as directional, not universal external
> evidence: single-context remains usable, but prefer true parallel subagents when your tool has
> them. See [`docs/measurement/parallel-vs-single-context.md`](docs/measurement/parallel-vs-single-context.md).

## Install (full per-tool snippets)

### Claude Code (recommended — full council)
```bash
git clone https://github.com/Zhachory1/agent-fleet ~/code/agent-fleet
cd ~/code/agent-fleet && export AGENT_FLEET_HOME=$PWD
bash install.sh                     # symlinks agents → ~/.claude/agents, skill → ~/.claude/skills/council
# in Claude Code:  /council review this diff …
bash install.sh --uninstall         # reversible
```

### Codex CLI / opencode
```bash
export AGENT_FLEET_HOME=~/code/agent-fleet
bash "$AGENT_FLEET_HOME/install.sh" --tool opencode  # → ./.agent-fleet/
bash "$AGENT_FLEET_HOME/install.sh" --tool codex     # → ./.agent-fleet/ + ~/.codex/skills/council
# then ask the agent: "act as the council orchestrator in ./.agent-fleet/council-orchestrator.md"
```

### Cave
```bash
export AGENT_FLEET_HOME=~/code/agent-fleet
bash "$AGENT_FLEET_HOME/install.sh" --tool cave      # → ./.cave/{agents,skills,prompts}
```

### Cursor
```bash
export AGENT_FLEET_HOME=~/code/agent-fleet
bash "$AGENT_FLEET_HOME/install.sh" --tool cursor    # → ./.cursor/rules/
```

### Any AI editor / chat
```bash
bash ~/code/agent-fleet/install.sh --print   # prints the orchestrator prompt — paste into chat
# then paste 3-6 relevant agents/*.md persona prompts when asked
```

## Lib helpers (all environments with `bash` + `jq`)

```bash
export AGENT_FLEET_HOME=~/code/agent-fleet

# Core (used by every run)
$AGENT_FLEET_HOME/lib/transcript.sh show [council-<slug>]   # full per-persona reasoning, boxed
$AGENT_FLEET_HOME/lib/transcript.sh rooms                   # past councils
$AGENT_FLEET_HOME/lib/journal.sh stats [N]                  # catch rate / false-alarm / gate verdict
$AGENT_FLEET_HOME/lib/journal.sh --help                     # see all flags
```

`journal.sh append` **refuses** unless the run's transcript was captured first — you cannot
record a council whose thinking was not persisted.

### Private overlay (extension)

If `agents/_overlay.md` exists, every persona loads it into its system prompt for your org's
domain specifics. **The overlay is loaded verbatim — treat it as code you are running.** Inspect
any overlay before trusting it:

```bash
$AGENT_FLEET_HOME/lib/overlay.sh show   # prints content + SHA256 + path
$AGENT_FLEET_HOME/lib/overlay.sh lint   # advisory: scans for suspicious patterns
```

The lint is heuristic and advisory — a clean lint does NOT prove an overlay is safe. Starter
presets for common org shapes live in [`agents/_overlay.example/`](agents/_overlay.example/):

| If your org is… | Start from… |
|---|---|
| SaaS (subscription) | [`saas.md`](agents/_overlay.example/saas.md) |
| ML platform / applied ML | [`ml-platform.md`](agents/_overlay.example/ml-platform.md) |
| Adtech / programmatic | [`adtech.md`](agents/_overlay.example/adtech.md) |
| Fintech / payments / risk | [`fintech.md`](agents/_overlay.example/fintech.md) |
| Two-sided marketplace | [`marketplace.md`](agents/_overlay.example/marketplace.md) |
| Devtools | [`devtools.md`](agents/_overlay.example/devtools.md) |
| Anything else | [`_overlay.md.example`](agents/_overlay.md.example) |

Each preset is edited heavily before installing. ml-scientist + ab-critic get noticeably sharper
with a domain-rich overlay — the cost of running them against the bare skeleton is real.

### Blinded judge (validation, infrastructure)

Every catch-rate number above is self-reported by the operator. The blinded-judge mechanism
narrows that bias channel: a fresh-context LLM (different account or different model family)
judges whether the council's synthesis surfaced a net-new issue the solo decision missed —
seeing only the artifact + solo + per-persona positions + operator synthesis + persona list, NOT
the operator's post-hoc note or identity. Returns one binary `NET_NEW_CATCH: true|false` with a
verbatim `EVIDENCE` quote.

> **This feature narrows the bias channel from author-judges-author to LLM-judges-LLM. It does
> not by itself upgrade the evidence tier to external human validation. That requires non-author
> operators and/or human judges running the workflow on their own artifacts.**

```bash
# Phase 1: first 5 dual-judged councils establish noise floor; --phase1 required
$AGENT_FLEET_HOME/lib/blind-judge.sh judge council-<slug> --phase1 judge-a

# Phase 2: single-judged (every 5th council); --phase1 forbidden after Phase 1 closes
$AGENT_FLEET_HOME/lib/blind-judge.sh judge council-<slug>

# Rescue legacy rooms that predate the durable-artifact change:
$AGENT_FLEET_HOME/lib/blind-judge.sh backfill-artifact council-<slug> --from <path>
```

The canonical rubric is [`lib/blind-judge-prompt.v2.txt`](lib/blind-judge-prompt.v2.txt)
(visible by design; changes bump the filename version and are git-history-visible). Full design
+ Phase 1/Phase 2 calibration in
[`docs/features/blinded-judge/PRD.md`](docs/features/blinded-judge/PRD.md). Current state:
**Phase 1 calibration is complete; Phase 2 is in progress at 21/50 judged rooms. [Issue #1](../../issues/1)
tracks the 50-run decision and README/stats update.**

## Tests

```bash
for t in test/test_*.sh; do bash "$t"; done
```

CI runs the same loop on every push and PR (see badge above). 18 shell test scripts pass locally and in CI.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The highest-leverage external contribution today is
running councils cold on your own work and writing down the friction, especially whether the
first-run install path and overlay presets match a non-author workflow.

## License

[MIT](LICENSE) — Copyright (c) 2026 Zhachory Volker.
