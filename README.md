# agent-fleet

[![tests](https://github.com/Zhachory1/agent-fleet/actions/workflows/test.yml/badge.svg)](https://github.com/Zhachory1/agent-fleet/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A portable **council of specialist review personas** for high-stakes engineering decisions.
You convene 2–4 orthogonal reviewers, they critique your artifact from independent angles, and an
orchestrator runs a bounded reflection debate (critique-before-concede, ≤4 rounds), then
synthesizes one decision-grade answer with **ranked issues, named dissents, and a false-consensus
flag**. It is built to *disagree with you* — to catch what a single review pass misses.

> ⚠ **Research-grade, not production-grade.** This is a tool I built for myself and am
> publishing openly. The validation gate currently reads:
> `INSUFFICIENT BASELINE DATA — council cannot be judged until 7 more lens-baseline run(s)`.
> Net-new catch rate is high (21/22 = 95%) but **self-reported by the author**; an external-judge
> mechanism is open as [issue #1](../../issues/1) and a first-external-user effort as
> [issue #13](../../issues/13). Treat the metrics as Tier-3 evidence until those close.

---

## What it actually does (concrete example)

I recently ran the council on this very repo asking *"can this be adopted by the general public?"*.
My **solo** answer was: "polish a few things and trust public visibility is enough."

The council's synthesis (4 reviewers, 4 rounds, converged at cap):

```
Council verdict: SPLIT-NO-MAJORITY (2× BLOCK / 2× SHIP-WITH-CHANGES)

Ranked issues
  1. [BLOCKER] No LICENSE file — public repo but legally unusable        — docs-dx
  2. [BLOCKER] Hardcoded ~/code/agent-fleet/ paths in 6+ places          — docs-dx, generalist-swe
  3. [BLOCKER] No CI — tests are unverifiable for any non-author         — generalist-swe
  4. [BLOCKER] Repo's own gate says INSUFFICIENT and README doesn't say so — red-team
  5. [MAJOR]   model: sonnet frontmatter breaks portability on non-Claude tools — red-team
  6. [MAJOR]   Overlay loads verbatim into every persona's system prompt;
               threat model needed                                       — red-team
  ...
Dissents (preserved, named)
  - red-team — BLOCK: "Every metric you publish is the same person who built the tool,
    scoring the tool. File 'find first external user' before any more polish work."
```

Issues #5 and #6 above are findings the council surfaced that I — and a same-lenses
single-pass baseline I ran first — had both missed. They became [issue #10](../../issues/10) and
[issue #12](../../issues/12) on this repo.

That is what running a council *gets* you: a structured second opinion you can argue with,
file as work, and link back to a durable transcript.

---

## When to use it

Convene a council when the cost of getting it wrong > the cost of 5 minutes of LLM calls:

- Model change / new training-pipeline feature → `ml-scientist + ab-critic + reliability-sentinel`
- Experiment readout / launch decision → `ab-critic + ml-scientist`
- Design doc / new service / build-vs-buy → `software-architect + red-team + generalist-swe`
- Serving-path PR / latency change → `reliability-sentinel + perf-engineer + generalist-swe`
- PRD / scope ("should we build this?") → `product-pm + ceo + red-team`
- Platform bet / 3–5yr tech direction → `cto + software-architect + ceo`

Full task → personas table in [`agents/INDEX.md`](agents/INDEX.md) (includes overlap flags).

## Not for you if…

- You want a managed product — this is a prompt structure + bash helpers, not a service.
- You don't already use an AI coding agent (Claude Code / Cursor / opencode / Codex / chat).
- You're not willing to run the orchestrator prompt yourself and write down your decision *before*
  the council convenes (Step 0 is the whole point — it's how we know whether the council surfaced
  something net-new).
- You need pristine evidence the tool works. The validation arm is still open.

---

## How it works (1-minute version)

```
your decision  ──▶  /council <task>
                      ├─ Step 0   — write your solo decision + risks you already see
                      ├─ Step 0.5 — same-lenses single-pass baseline (validation arm)
                      ├─ Step 2   — pick 2-4 personas by task (15 in catalog)
                      ├─ Step 3   — round 1: each persona reviews in isolation, blind
                      │             rounds 2..N (default 2, cap 4): each persona sees peers'
                      │             FULL prior positions and must REFUTE-FIRST before conceding
                      │             ↳ red-team auto-included when N>1 (standing dissenter)
                      │             ↳ deterministic convergence + capitulation detector
                      └─ Step 5   — synthesis: ranked issues, named dissents, false-consensus flag
                          Step 6  — journal the run (refuses unless transcript was captured)
```

Personas are **stateless one-shot reviewers**. The orchestrator (your AI coding agent) sequences
everything and holds the transcript. The reflection debate (each persona reads peers' full prior
positions, must refute before conceding) is what distinguishes a council from "ask 4 LLMs the same
question and average." Red-team carries a hardened rule: it cannot concede without citing a
factual error in its OWN prior position.

Full design rationale: [`docs/PRD.md`](docs/PRD.md) and [`docs/DD.md`](docs/DD.md).

## The personas (15 total — see [`agents/INDEX.md`](agents/INDEX.md))

**Core six** (n≥18 validation runs):

| Persona | Lens | Catches |
|---|---|---|
| `ml-scientist` | skeptical ML researcher | calibration, train/serve skew, leakage, metric choice |
| `ab-critic` | experiment statistician | power/MDE, peeking, SUTVA, holdout hygiene |
| `reliability-sentinel` | SRE | blast radius, rollback, SLOs, fallback, hot-path risk |
| `software-architect` | boundaries-first | coupling, bounded contexts, evolvability, contracts |
| `generalist-swe` | pragmatic IC | simplicity, over-engineering, correctness, edge cases |
| `red-team` | adversary | strongest case against, hand-waved assumptions, what breaks first |

**Experimental** (added together; promote per `agents/INDEX.md` after ≥3 logged runs):
`data-engineer`, `perf-engineer`, `product-pm`, `cost-finops`, `docs-dx`, `pre-mortem`, `cto`,
`ceo`, `vp-eng`, `mvp`.

> **Note on persona frontmatter:** each persona's YAML frontmatter carries a `model: sonnet`
> field. This is **Claude-Code-specific metadata** — Claude Code's agent loader uses it to pin
> a model. Other tools (Cursor / Codex / opencode / generic chat) ignore unknown frontmatter
> fields. If your tool errors on the field rather than ignoring it, strip the line from your
> local copy of the persona files (it's safe to remove) or file an issue. The `description:`
> field uses a `[experimental]` prefix to mark unvalidated personas — visible in any selection
> UI that reads frontmatter (issue #9).

---

## What you get depends on your tool

The personas + bash helpers are portable everywhere. The **parallel multi-agent debate** needs a
subagent primitive — without one, you fall back to "solo council" mode where one agent adopts each
persona's prompt in sequence within one context. **Solo mode is closer to the lens-baseline this
tool exists to beat than to a true multi-agent debate.** Plan accordingly.

| Tool | Council depth | How |
|---|---|---|
| **Claude Code** | full parallel (Task tool) | `install.sh` → native agents + `/council` skill |
| **opencode** | full parallel (subagents) | `AGENTS.md` + `--target` personas; orchestrate via subagents |
| **Codex CLI** | DEGRADED — solo (single context) | reads root `AGENTS.md`; run the orchestrator prompt |
| **Cursor** | DEGRADED — solo (single context) | drop personas into `.cursor/rules/`; paste orchestrator prompt |
| **any AI chat** | DEGRADED — solo (single context) | `install.sh --print` → paste the prompt |

"DEGRADED" means the run is closer to the same-lenses-single-pass baseline than to a true council.
Useful, often still finds things — but the validation gate scores it accordingly.

---

## Install

### Claude Code (recommended — full council)
```bash
git clone https://github.com/Zhachory1/agent-fleet ~/code/agent-fleet
cd ~/code/agent-fleet
export AGENT_FLEET_HOME=$PWD
bash install.sh                     # symlinks agents → ~/.claude/agents, skill → ~/.claude/skills/council
# then in Claude Code:  /council review this diff …
bash install.sh --uninstall         # reversible
```

### Codex CLI / opencode (AGENTS.md-aware, DEGRADED solo mode unless opencode subagents are wired)
```bash
export AGENT_FLEET_HOME=~/code/agent-fleet
bash "$AGENT_FLEET_HOME/install.sh" --target ./.agent-fleet --copy
# then ask the agent: "act as the council orchestrator in ./.agent-fleet/council-orchestrator.md"
```

### Cursor (DEGRADED solo mode)
```bash
export AGENT_FLEET_HOME=~/code/agent-fleet
bash "$AGENT_FLEET_HOME/install.sh" --target ./.cursor/rules --copy
# Cursor reads .cursor/rules; invoke with: "run the council (see council-orchestrator.md)"
```

### Any AI editor / chat (no install, DEGRADED solo mode)
```bash
bash ~/code/agent-fleet/install.sh --print   # prints the orchestrator prompt — paste into the chat
# then paste the 2-4 relevant agents/*.md persona prompts when asked
```

---

## Helpers (any environment with `bash` + `jq`)

```bash
export AGENT_FLEET_HOME=~/code/agent-fleet

$AGENT_FLEET_HOME/lib/transcript.sh show [council-<slug>]   # full per-persona reasoning, boxed
$AGENT_FLEET_HOME/lib/transcript.sh rooms                   # past councils
$AGENT_FLEET_HOME/lib/journal.sh stats [N]                  # catch rate / false-alarm / gate verdict
```

`journal.sh append` **refuses** unless the run's transcript was captured first — you cannot record
a council whose thinking was not persisted.

## Blinded judge (validation, optional)

Every catch-rate number in `journal.sh stats` is **self-reported by the operator** who ran the
council. The blinded judge mechanism narrows that bias channel: after a council runs, you (or a
fresh-context LLM in a different account / different model family) judges whether the council's
synthesis contains a net-new issue the solo decision missed — seeing only the artifact, the solo
decision, the per-persona positions + operator's synthesis, and the persona list. The judge
emits one binary line (`NET_NEW_CATCH: true|false`) plus a verbatim `EVIDENCE` quote (when
`true`) and `REASONING` + `DISSENT_DIFF` scratchpads. Both the operator's self-report and the
blinded judge's answer are stored side-by-side in the journal; `stats` reports agreement-rate
separately.

> ⚠ **This feature narrows the bias channel from author-judges-author to LLM-judges-LLM. It does
> not upgrade the evidence tier. The only upgrade is human-judges-human ([issue #13](../../issues/13)).**

```bash
# After a council, prepare the blinded brief (copies prompt to clipboard, prints banner):
$AGENT_FLEET_HOME/lib/blind-judge.sh judge council-<slug> --phase1 judge-a    # Phase 1 (first 5 rooms)
$AGENT_FLEET_HOME/lib/blind-judge.sh judge council-<slug>                      # Phase 2 (>=5 rooms)

# For legacy rooms that predate the FR9 durable-artifact change:
$AGENT_FLEET_HOME/lib/blind-judge.sh backfill-artifact council-<slug> --from <path>
```

The canonical rubric is `lib/blind-judge-prompt.v2.txt` (visible by design — any change to it
bumps the filename version and is git-history-visible). See
[`docs/features/blinded-judge/PRD.md`](docs/features/blinded-judge/PRD.md) for the full design,
including the two-phase calibration (qualitative n=5, then quantitative n≥50) and the explicit
operator-attack surface that v1 disclosed-but-did-not-solve.

## Private overlay

If `agents/_overlay.md` exists, every persona loads it into its system prompt for your org's
domain specifics (KPIs, stack, hot paths, current priorities). It is gitignored. **The overlay is
loaded verbatim** — treat it as code you are running, not as data. See [issue
#12](../../issues/12) for the threat-model and inspection-helper work. Start from
[`agents/_overlay.md.example`](agents/_overlay.md.example).

## Tests

```bash
for t in test/test_*.sh; do bash "$t"; done
```

CI runs the same loop on every push and PR (see badge above).

## Contributing

Open issues are tagged. The most useful contribution today is in
[issue #13](../../issues/13) — running 3 councils on your own real work and writing down what
broke. If you do that, file a PR adding your experience to `docs/external-users/`.

## License

[MIT](LICENSE) — Copyright (c) 2026 Zhachory Volker.
