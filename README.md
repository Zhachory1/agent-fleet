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
> publishing openly. The validation gate currently reads:
> `INSUFFICIENT BASELINE DATA — council cannot be judged until 1 more lens-baseline run(s)`.
> Net-new catch rate is high (31/32 = 96%) but **self-reported by the author**. A blinded-judge
> mechanism exists ([§Lib helpers](#lib-helpers--all-environments-with-bash--jq)) and is the
> answer to that bias; it is documented but not yet exercised on enough runs to produce a
> defensible number. Treat all metrics as Tier-3 evidence until [issue
> #1](../../issues/1) + [issue #20](../../issues/20) close.

## Quick start

```bash
git clone https://github.com/Zhachory1/agent-fleet ~/code/agent-fleet
cd ~/code/agent-fleet
export AGENT_FLEET_HOME=$PWD
# Read the maturity disclaimer above before relying on output as decision-grade.
bash install.sh                # Claude Code (default; symlinks)
# OR: bash install.sh --tool cursor    # Cursor   (→ ./.cursor/rules/)
# OR: bash install.sh --tool opencode  # opencode (→ ./.agent-fleet/)
# OR: bash install.sh --tool codex     # Codex    (→ ./.agent-fleet/)
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
- You don't already use an AI coding agent (Claude Code / Cursor / opencode / Codex / chat).
- You're not willing to write your decision *before* the council convenes — Step 0 is the
  whole point.
- You want a CI gate / merge-blocker. This is a thinking tool; the output requires judgment.
- You need pristine evidence the tool works. The validation arm is still open.

## How it works (30s)

```
your decision  ──▶  /council <task>
                      ├─ Step 0   — write your solo decision + risks you already see
                      ├─ Step 0.5 — same-lenses single-pass baseline (validation arm)
                      ├─ Step 2   — pick 3-6 personas by task (16 in catalog)
                      ├─ Step 3   — round 1: each persona reviews in isolation, blind
                      │             rounds 2..N (default 2, cap 4): each persona sees peers'
                      │             FULL prior positions and must REFUTE-FIRST before conceding
                      │             ↳ red-team auto-included when N>1 (standing dissenter)
                      │             ↳ deterministic convergence + capitulation detector
                      └─ Step 5   — synthesis: ranked issues, named dissents, false-consensus flag
                          Step 6  — journal the run (refuses unless transcript was captured)
```

Personas are stateless one-shot reviewers; the orchestrator (your AI coding agent) sequences
everything and holds the transcript. The reflection debate (each persona reads peers' full
prior positions, must refute before conceding) is what distinguishes a council from "ask 4 LLMs
the same question and average." Red-team carries a hardened concession rule. Full design
rationale: [`docs/PRD.md`](docs/PRD.md), [`docs/DD.md`](docs/DD.md).

## The personas (16 total — see [`agents/INDEX.md`](agents/INDEX.md))

**Core six** (n≥18 validation runs each):

| Persona | Lens | Catches |
|---|---|---|
| `ml-scientist` | skeptical ML researcher | calibration, train/serve skew, leakage, metric choice |
| `ab-critic` | experiment statistician | power/MDE, peeking, SUTVA, holdout hygiene |
| `reliability-sentinel` | SRE | blast radius, rollback, SLOs, fallback, hot-path risk |
| `software-architect` | boundaries-first | coupling, bounded contexts, evolvability, contracts |
| `generalist-swe` | pragmatic IC | simplicity, over-engineering, correctness, edge cases |
| `red-team` | adversary | strongest case against, hand-waved assumptions, what breaks first |

**Experimental ten** (added 2026-06; not yet promoted to Core — promotion criterion is ≥3
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
the same context ("solo-context"). Reflection rounds (round 2+) work in both modes — each
persona still reads peers' prior-round POSITIONs and must REFUTE-FIRST before conceding.

| Tool | Round-1 isolation | How |
|---|---|---|
| **Claude Code** | parallel (Task tool) | `install.sh` → native agents + `/council` skill |
| **opencode** | parallel (subagents) | `AGENTS.md` + `--target` personas; orchestrate via subagents |
| **Codex CLI** | single-context | reads root `AGENTS.md`; run the orchestrator prompt |
| **Cursor** | single-context | drop personas into `.cursor/rules/`; paste orchestrator prompt |
| **any AI chat** | single-context | `install.sh --print` → paste the prompt |

> **Honest disclosure on the difference:** parallel mode guarantees personas don't influence
> each other's round-1 POSITIONs; single-context mode has potential cross-persona contamination
> at round 1 (persona 4 has seen personas 1–3's outputs in-context even if prompted to ignore
> them). **The magnitude of that contamination is not measured** — the lens-baseline arm in
> `journal.sh stats` compares any council mode against same-lenses-single-pass; it does NOT
> compare the two council modes against each other. Until the dual-mode measurement lands
> (tracked as a follow-up issue), "parallel is better" is a theoretical claim with known sign
> and unknown magnitude. Plan accordingly.

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
bash "$AGENT_FLEET_HOME/install.sh" --tool opencode  # or --tool codex; both → ./.agent-fleet/
# then ask the agent: "act as the council orchestrator in ./.agent-fleet/council-orchestrator.md"
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
> not upgrade the evidence tier. The only upgrade is human-judges-human ([issue
> #13](../../issues/13)).**

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
**0 of 5 Phase 1 dual-judged runs complete; [issue #20](../../issues/20) is the close criterion
for [issue #1](../../issues/1).**

## Tests

```bash
for t in test/test_*.sh; do bash "$t"; done
```

CI runs the same loop on every push and PR (see badge above). 13 tests; all pass on Ubuntu.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The highest-leverage external contribution today is
running 3 councils cold on your own work and writing down the friction —
[issue #13](../../issues/13).

## License

[MIT](LICENSE) — Copyright (c) 2026 Zhachory Volker.
