# Software Engineering Design Document (SEDD)

*Technical blueprint for the Agent Fleet council. Implements PRD Rev 2 (`./PRD.md`).*

**SEDD ID:** 20260612-agent-fleet-council
**Status:** In progress
**Domain:** Personal developer tooling (`~/.claude`, global)
**Last updated:** 2026-06-12
**DRI:** Zhach Volker
**Related:** `./PRD.md` (Rev 2) · agent-chat JSONL format (`ROKT/ai-workflows`, format only)

---

# Problem Statement

## Need

Solo single-context decisions miss specialist angles. Want council of orthogonal personas,
orchestrator pick 2-4, bounded debate, synthesis with dissent. Full why in PRD. DD job: pin
architecture so build subagents have exact blueprint.

## Success Metrics

| Type | Measure | Bar |
|---|---|---|
| **Primary (product)** | net-new acted-on hindsight-validated catch rate | ≥1 catch in ≥40% of first 20 runs |
| **Guardrail** | false-alarm rate (issues dismissed) | < 50% |
| **Functional** | agents load clean; rules-table selection deterministic; round contract holds | 100% of NFR6 tests pass |
| **Cost** | input tokens/run | ≤4 personas × ≤2 rounds, artifact passed once |
| **Portability** | runs overlay-absent, no plugin dep | clean on non-Rokt machine |

---

# High-Level Design

## Conceptual Overview

`/council <task>` skill drive main session = **orchestrator**. Flow:

```
/council <task>
  │
  ├─ 1. CAPTURE   artifact once → temp file (diff / doc / metrics)
  ├─ 2. SELECT    pick 2-4 personas (rules table → LLM fallback)
  ├─ 3. ROUND 1   spawn selected personas in PARALLEL (Task tool)
  │                 each prompt = persona body + artifact path + task
  │                 each returns structured position
  ├─ 4. ROUND 2   (optional, ≤1) re-spawn same personas
  │                 inject orchestrator-SUMMARIZED peer brief
  │                 each returns revision
  ├─ 5. SYNTH     orchestrator (holds all outputs in own context)
  │                 → ranked issues, NAMED dissents, false-consensus flag
  ├─ 6. TRANSCRIPT serial-append {ts,from,text} JSONL → room log (write-only)
  └─ 7. JOURNAL   one-line counterfactual entry (solo vs council)
```

Key truth (from review): personas = **stateless one-shot subagents**. No live chat. Orchestrator
do all sequencing + hold all state. Room = transcript only, not coordination.

## Architectural Boundary

* **Orchestrator:** slash-command skill `/council`. Lives `~/.claude/skills/council/` (or in fleet
  repo, symlinked). Drive main session — has Task tool to spawn subagents.
* **Personas:** agent definitions `~/.claude/agents/<name>.md`. Generic core. Each = own context,
  own scoped tools. Hidden complexity: each persona's lens + judgment. Exposed interface: structured
  output schema (position).
* **Transcript:** `~/.claude/agent-chat/rooms/council-<slug>/log.jsonl`. Write-only. Same
  `{ts,from,text}` line format as agent-chat. **No** marker/cursor/listen/Stop-hook. No plugin dep.
* **Overlay:** `~/.claude/agents/_rokt-overlay.md` (gitignored, private). Optional.

No Rokt Brain boundary. No Transaction Moment. No SoR object. Paved road n/a (markdown + bash +
Claude Code agents). No new tech.

---

# Detailed Deep Dive

## Repo Layout (source of truth, versioned)

```
~/code/agent-fleet/
  docs/         PRD.md  DD.md  PLAN.md
  agents/       ml-scientist.md  ab-critic.md  reliability-sentinel.md
                software-architect.md  generalist-swe.md  red-team.md
                _rokt-overlay.md.example   (template; real one private+gitignored)
  skills/council/ SKILL.md   (orchestrator)
  lib/          transcript.sh   (serial JSONL append helper)
                journal.sh      (counterfactual log helper)
  install.sh    (symlink agents/ + skills/council → ~/.claude; reversible)
  test/         test_agents_load.sh  test_selection.sh  test_round_contract.sh
  .gitignore    (_rokt-overlay.md, run artifacts)
```

Install = symlink each `agents/*.md` → `~/.claude/agents/`, `skills/council` →
`~/.claude/skills/council`. Uninstall = remove symlinks. Reversible (NFR1).

## Persona Definition Contract

Each agent `.md`: YAML frontmatter (`name`, `description`, `tools`) + body. Body sections:

1. **Lens** — one-paragraph identity + what this persona distrusts by default.
2. **What you attack** — checklist of failure modes this lens owns.
3. **Output contract** — fixed structure (below).
4. **Overlay hook** — `If ~/.claude/agents/_rokt-overlay.md exists, read it for domain specifics`.
5. **Etiquette** — terse, evidence-based, severity-tagged, MUST surface ≥1 dissent/counterargument.

**Persona output schema** (returned to orchestrator):

```
POSITION (persona: <name>)
- verdict: <SHIP | SHIP-WITH-CHANGES | BLOCK | NEED-MORE-INFO>
- top_issues: [ {severity: BLOCKER|MAJOR|MINOR, claim: ..., evidence: ..., fix: ...} ]
- strongest_counterargument: <the best case AGAINST my own verdict>   # mandatory, anti-consensus
- confidence: <low|med|high>
- one_line: <tl;dr>
```

`strongest_counterargument` mandatory = the anti-consensus-mush lever (PRD FR5).

## v1 Personas (6, orthogonal)

| Persona | Lens | Owns (attacks) | Tools |
|---|---|---|---|
| **ml-scientist** | skeptical ranking/ML researcher; distrusts offline wins | calibration, train/serve skew, leakage, metric choice (NLL vs AUC), data drift | Read, Grep, Glob, Bash(ro) |
| **ab-critic** | paranoid experiment statistician | power/MDE, peeking, novelty, interference/SUTVA (auctions!), holdout hygiene, readout validity | Read, Grep, Glob, Bash(ro) |
| **reliability-sentinel** | SRE worrier | blast radius, rollback, SLO impact, fallback, capacity, hot-path/serving risk, oncall-at-3am | Read, Grep, Glob, Bash(ro) |
| **software-architect** | boundaries-first architect (Liam lens) | coupling, bounded contexts, evolvability, build-vs-buy, contract/versioning, tech selection | Read, Grep, Glob, Bash(ro) |
| **generalist-swe** | pragmatic senior IC | simplicity, readability, over-engineering, does-it-actually-work, edge cases, YAGNI | Read, Grep, Glob, Bash(ro) |
| **red-team** | hostile adversary; default = refute | strongest attack on the whole proposal, what breaks, what's hand-waved, security/abuse | Read, Grep, Glob, Bash(ro) |

All read-only tools (personas advise, never mutate). Library personas (`cost-hawk`,
`data-contract-guardian`, `eng-manager-coach`, `director-strategy`, `dd-adversary`) defined later,
gated on validation.

## Selection — Design Options

**Decision needed (OQ#2):** how orchestrator pick 2-4.

### Option A — Pure LLM judgment
Orchestrator read task, reason about which lenses fit, pick.
* **Pro:** flexible, handles novel tasks, no maintenance.
* **Con:** non-deterministic → can't unit-test (NFR6 fails); may over/under-select; opaque.

### Option B — Pure rules table
Map task keywords/type → fixed persona set.
* **Pro:** deterministic, testable, fast, predictable cost.
* **Con:** brittle, misses novel tasks, keyword-gaming, maintenance.

### Option C — Rules table + LLM fallback (RECOMMENDED)
Rules table cover common task types (testable, deterministic for those). Unmatched → LLM judgment
picks, constrained to 2-4 + one-line justification each.
* **Pro:** common cases testable + predictable; long tail still handled; NFR6-c testable on table cases.
* **Con:** two code paths. Acceptable.

**Recommend C.** Rules table v1:

```
model change / new model input / training pipeline   → ml-scientist, ab-critic, reliability-sentinel
experiment / A-B / readout / holdout                 → ab-critic, ml-scientist
design doc / architecture / new service / build-vs-buy→ software-architect, red-team, generalist-swe
PR / serving-path / bid-path / latency change         → reliability-sentinel, generalist-swe, software-architect
refactor / simplify / code quality                    → generalist-swe, software-architect
cost / spend / efficiency                             → (library) cost-hawk, reliability-sentinel
DEFAULT / unmatched                                    → LLM picks 2-4 + justify
```

Always cap 4. red-team addable to any set when stakes high.

## Round Protocol (the corrected core)

```
selected = select(task)                       # 2-4 personas
artifact_path = capture(task)                  # FR9, once

# ROUND 1 — parallel, independent
r1 = parallel( spawn(p, prompt=body(p)+artifact_path+task) for p in selected )

transcript_append_serial(r1)                   # orchestrator writes, no race

if rounds==2:
   brief = summarize(r1)                        # orchestrator condenses peer positions
   r2 = parallel( spawn(p, prompt=body(p)+artifact_path+task+brief) for p in selected )
   transcript_append_serial(r2)
   final_positions = r2
else:
   final_positions = r1

synthesis = synthesize(final_positions)         # in orchestrator context
```

* **Stateless personas:** each spawn fresh, no memory across rounds — peer context injected via
  `brief`. (Matches Task subagent reality.)
* **Parallel spawn** for latency; **serial append** by orchestrator avoids >PIPE_BUF interleave
  race (review MAJOR 4). Personas never write the log themselves.
* **Round 2 default OFF** unless stakes high or round-1 verdicts conflict. Bounds cost.

## Artifact Passing (FR9 — cost-critical)

Orchestrator capture artifact ONCE → temp path (e.g. `/tmp/council-<slug>.txt`):
* diff → `git diff` to file
* design doc / file → already a path, pass path
* metrics table / pasted text → write to temp file

Pass **path** in each persona prompt (subagent reads what it needs — cheaper than inlining full).
For small artifacts (<~2KB) inline directly. Round 2 inject **summarized** brief, never raw concat
(bounds quadratic growth). Track total input tokens.

## Transcript Schema

`~/.claude/agent-chat/rooms/council-<slug>/log.jsonl`, one JSON/line:

```json
{"ts":"2026-06-12T22:05:01Z","from":"ml-scientist","text":"verdict=BLOCK; calibration..."}
```

`lib/transcript.sh append <room> <from> <text>` = jq-build line + single `printf >> log`. Called
serially by orchestrator. Read-only-format-compatible with agent-chat (mode A future). No cursor.

## Counterfactual Journal (NFR5 / KPI)

`~/.claude/agent-fleet-journal.jsonl`, one/run:

```json
{"ts":"...","task":"<slug>","solo_decision":"<my call before council>",
 "personas":["ml-scientist","ab-critic"],"net_new_catch":true,
 "catch_note":"missed train/serve skew on feature X","acted_on":true,"dismissed_count":1}
```

`lib/journal.sh` append. Orchestrator prompt me for `solo_decision` BEFORE convening (enforces
solo-first counterfactual). Powers the kill-criterion.

## Synthesis Format (skimmable < 2 min)

```
## Council verdict: <consensus verdict OR "split">
⚠ false-consensus risk          # only if unanimous
### Ranked issues
1. [BLOCKER] <claim> — raised by <personas> — fix: <...>
2. [MAJOR]  ...
### Dissents (preserved)
- <persona>: <position against the majority>
### Strongest counterargument to the verdict
- <best refutation, from red-team or most-skeptical>
### One-line recommendation
```

## Overlay Loading

Persona body ends: `If file ~/.claude/agents/_rokt-overlay.md exists, read it and apply its
domain specifics (ads metrics, KFP/Trino/Datadog/dopp/LAL). If absent, proceed generic.` Subagent
has Read tool → conditional read. Absent = no error (portability NFR3).

---

# Reliability, Scaling, Operations

* **Scaling:** n/a (personal, single-user, on-demand). Concurrency only within one run (≤4 parallel
  subagents) — capped.
* **Degradation:** persona spawn fails → orchestrator drops it (`.filter(Boolean)` semantics),
  proceed with survivors, note in synthesis. Never block whole run on one dead persona.
* **Observability:** transcript log + journal. No Datadog (local tool).

---

# Implementation & Launch Plan

## Phased Rollout

* **Phase 1 (build):** lib helpers, 6 personas, `/council` orchestrator, install, tests.
* **Phase 2 (validate):** 20 real runs, solo-first, fill journal. Compute catch + false-alarm.
* **Phase 3 (gate):** ≥40% catch & <50% false-alarm → expand (library, overlay enrich, mode A,
  auto-suggest). Else collapse to single-context-with-lenses prompt + retire orchestration.

## Testing Requirements

* **Unit/contract (NFR6):**
  * `test_agents_load.sh` — every `agents/*.md` has valid frontmatter, loads.
  * `test_selection.sh` — rules-table cases deterministic (assert "model change" → expected set).
  * `test_round_contract.sh` — mock personas; assert round-1 outputs reach round-2 prompt + synth
    preserves a dissent + flags false-consensus on unanimous input.
  * `test_transcript.sh` — append round-trips; serial append no interleave; format = valid JSONL.
  * `test_overlay_absent.sh` — persona prompt resolves clean with overlay missing.
* **E2E:** one real `/council` run on a sample diff, manual eyeball synthesis quality.
* **Rollback:** `install.sh --uninstall` removes symlinks. No prod, no canary.

---

# Technical Debt / Future Refactoring

* Mode A (peer sessions) intentionally deferred — transcript format kept compatible = the only
  forward-compat investment now.
* Selection rules table will rot as personas grow — revisit at library expansion.
* Round-2 summarization is naive (orchestrator condenses) — may need a dedicated summarizer if
  positions get large.
* Journal catch/false-alarm self-judged — accepted measurement debt (no ground truth available).

---

# Open Questions / Dependencies

| # | Question | Resolution |
|---|---|---|
| 1 | Orchestrator: skill vs agent? | **Skill** (`/council`) — needs Task tool + main-session control. Resolved. |
| 2 | Selection mechanism | **Option C** (rules table + LLM fallback). Resolved. |
| 3 | Round-2 trigger condition | Default OFF; ON if verdicts conflict or I pass `--deep`. Confirm in plan. |
| 4 | Artifact excerpt thresholds | <2KB inline, else path. Tune empirically. |
| 5 | Where orchestrator skill lives | fleet repo `skills/council`, symlinked. Resolved. |
| 6 | Does Claude Code load agents from `~/.claude/agents/`? | **Verify in plan phase** before building (hard dependency). |

> Coaching: OQ#6 is the one real external dependency — confirm the agent-loading path + frontmatter
> format Claude Code expects BEFORE writing 6 personas, else rework. Plan phase must spike it first.
