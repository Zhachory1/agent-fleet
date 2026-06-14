# Software Engineering PRD (SEPRD)

*⬆️ Agent Fleet — persona council with orchestrated selection and transcripted debate*

**SEPRD-ID**: SEPRD-20260612-agent-fleet-council
**Status**: Draft — Pending Team Ratification (self-ratified; personal tooling) · **Rev 2** (post-aggressive-review)
**Domain**: Personal developer tooling (global `~/.claude`, private overlay optional)
**Last updated**: 2026-06-12
**DRI**: Zhach Volker
**Related**: Reuses the *file format* (only) of an internal `agent-chat` JSONL room transcript

> **Rev 2 changelog** (from adversarial review): mode-B execution model corrected (orchestrator
> sequences rounds; personas are stateless one-shots) · agent-chat reuse downgraded to write-only
> transcript, no script dependency, `--as` extension dropped · KPI made counterfactual · consensus
> mush guardrail added · artifact-passing made a first-class FR · auto-suggest cut from v1 · roster
> reframed as a 12-persona library with a lean 6-persona v1 ship-set (added `software-architect` +
> `generalist-swe`, cut `staff-reviewer`).

---

# Context

## Problem Statement (The "Why")

As a Staff SWE + people leader at an ads platform, I make recurring **high-stakes,
multi-disciplinary judgment calls** — model changes, experiment readouts, design-doc reviews,
serving-path PRs, architecture choices, perf/cost tradeoffs. Today I evaluate these **solo, in a
single Claude context**. Gaps:

* **Single-perspective blind spots.** The errors that hurt most when wrong ("AUC up but
  calibration worse," "this A/B has interference so the readout is invalid," "this PR touches the
  hot path," "this design couples two bounded contexts") are exactly what a *specialist second
  opinion from a different lens* catches and a single generalist pass misses.
* **No structured adversarial check.** No cheap way to get N independent specialists to
  pressure-test a decision and *disagree* before I commit.
* **Existing skills are procedures, not judgment.** Repo skills (`code-reviewer`, `investigation`,
  `exec-summary`) encode *how* to do a task, not *opinionated persona judgment*.

The gap is a **standing library of specialist personas** an orchestrator can convene on demand,
that are made to **disagree**, and that **follow me across every repo**.

> **Honesty gate (from review):** It is NOT proven that multi-persona debate beats a single strong
> context prompted with the same lenses. The dominant risk is *consensus mush* — personas from one
> base model converging and laundering a confident wrong answer. v1 therefore ships with a
> built-in counterfactual (solo-first logging) so the fleet must *earn* its existence (see KPI).

## Context & Strategic Alignment

Personal-productivity tool; no org-OKR dependency. Indirectly serves engineering-quality goals
and is a pattern shareable to the team later. Reuses the `agent-chat` JSONL *format* (not its
runtime) so a future real-time peer-session mode could layer on.

## User Persona & Use Case

* **Persona:** Me — Staff SWE / ML lead. Secondary: a teammate who later installs it (must work
  with the private overlay **absent**, zero coupling).
* **Scenario:** High-stakes decision (review this model change / is this experiment valid / tear
  apart this DD / is this PR safe / build-vs-buy this). I run `/council <task>`. It selects 2–4
  relevant personas, runs a bounded debate, synthesizes one decision-grade answer with **named
  dissents preserved**.

---

# Success & Measurement

## Target Metric (Primary KPI) — counterfactual catch rate

**Net-new, decision-changing, hindsight-validated catches per run.** For the first ~20 real
decisions I log:

1. **Solo first** — write my decision + the risks I see, *before* convening the council.
2. **Council** — run `/council`.
3. **Log only**: material issues the council added that my solo pass **missed**, that I **acted
   on** (changed/strengthened the decision), and that **survived ~1-week hindsight** as actually
   correct.

North Star = the rate of runs producing ≥1 such net-new acted-on catch. Baseline = 0. **Kill
criterion:** if < ~10% of runs change my decision over the first 20, the fleet is an expensive
linter and gets cut to a single-context prompt.

## Guardrail Metrics (Constraints) — all numeric

| Metric | Baseline | Limit |
|---|---|---|
| **False-alarm rate** = council-raised issues I dismiss as noise/wrong on reflection | 0 (n/a) | **> 50% dismissed ⇒ fleet declared noise.** Logged per run alongside catches. |
| **False-consensus rate** = runs where council unanimously agreed and I later found them collectively wrong | 0 | Tracked + reported; any unanimous run is flagged in synthesis as a *warning*, not a green light. |
| **Input-token cost / run** (the real driver: artifact × personas × rounds) | 0 | Bounded by artifact-passing rules (FR9) + ≤4 personas + ≤2 rounds; no unbounded loop. |
| **Portability** (overlay absent) | n/a | MUST run on a machine with no private overlay, zero coupling errors and **zero dependency** on the agent-chat plugin. |

## Baselines & Targets

| Metric | Baseline | Target |
|---|---|---|
| **Net-new acted-on catch rate** | 0 | ≥1 such catch in ≥40% of first 20 runs (else iterate or kill) |
| **False-alarm rate** | n/a | < 50% dismissed |
| **Adoption (impact-weighted)** | 0 | ≥3 runs/week *that produced an acted-on catch* (usage without catches = abandonment signal, not success) |

---

# Scope & Requirements

## Functional Requirements

* **FR1 — Persona library (12) + lean v1 ship-set (6).** Ship agent definitions (generic core),
  each a distinct judgment lens, scoped tool allowlist, structured output.
  * **v1 ship-set (orthogonal, build now):** `ml-scientist`, `ab-critic`, `reliability-sentinel`,
    `software-architect`, `generalist-swe`, `red-team`.
  * **Library (defined, lower priority / fast-follow):** `cost-hawk`, `data-contract-guardian`,
    `dd-adversary` (may fold into `red-team`), `eng-manager-coach`, `director-strategy`,
    `staff-reviewer` (**cut** — overlaps the `code-reviewer` skill + `generalist-swe`; kept in
    library only if a gap appears).
  * **Orthogonality rule:** new personas must add a lens no existing persona covers, else they
    breed consensus mush. `software-architect` = boundaries/coupling/evolvability/build-vs-buy;
    `generalist-swe` = pragmatic implementation/simplicity/readability/over-engineering check.
* **FR2 — Orchestrator selection (2–4).** Given a task, select the 2–4 most relevant personas
  (never all), one-line justification each. Selection uses a **rules table for common task types**
  (testable) + LLM judgment for the rest (OQ#2).
* **FR3 — Orchestrator-driven bounded debate (corrected model).** Personas are **stateless
  single-shot subagents**. The **orchestrator** does all sequencing:
  * **Round 1:** spawn selected personas (parallel), each returns a position.
  * **Round 2 (optional, ≤1 extra):** re-spawn the same personas, injecting peers' round-1
    positions (orchestrator-summarized if large) into each prompt; each returns a revision.
  * Personas **do not** poll, block, or talk to each other live. The orchestrator holds all
    outputs in its own context. (No "synchronous inter-agent chat" — that was a mode-A concept and
    mode A is out of scope.)
* **FR4 — Transcript, not transport.** The orchestrator appends `{ts,from,text}` JSONL lines
  (the agent-chat room *format*) to `~/.claude/agent-chat/rooms/<room>/log.jsonl` **write-only,
  for observability + forward-compat**. It does **not** use the `chat` script, markers, cursors,
  the listen loop, or the Stop hook. No `--as` extension. **No runtime dependency** on the
  `agent-chat` plugin. Appends are done **serially by the orchestrator** (avoids the >PIPE_BUF
  concurrent-append race entirely).
* **FR5 — Synthesis with enforced dissent.** Output one decision-grade answer, issues **ranked by
  severity**, **named dissents preserved** (not averaged away). At least one persona (`red-team`
  if selected, else the most-skeptical selected) MUST file a strongest-counterargument every run.
  If the council reached unanimous agreement, synthesis MUST flag it as a *false-consensus risk*.
* **FR6 — Trigger: slash-command only (v1).** `/council <task>`. **Auto-suggest is OUT for v1**
  (own sub-project, own false-positive failure mode, zero core value over the slash command).
* **FR7 — Generic core + private overlay.** Persona bodies are pure generic. If sibling
  `_overlay.md` (your org's KPIs, stack, hot paths, current priorities) exists, persona loads it for
  domain sharpening; absent ⇒ runs generic, no error. Overlay is gitignored / private.
* **FR8 — Install/uninstall.** Reversible: symlink/copy `agents/` → `~/.claude/agents/`. No global
  state beyond `~/.claude/agents/` + the user-scoped room dir.
* **FR9 — Artifact passing (the cost-critical FR).** The orchestrator captures the artifact under
  review **once** (read file / `git diff` → temp path) and passes a **file path or bounded
  excerpt** in each persona's Task prompt — NOT the parent conversation (subagents inherit none of
  it). Round 2 injects a **summarized** peer brief, not raw concatenated outputs, to bound the
  quadratic growth. Total input tokens is a tracked guardrail.

## Non-Functional Requirements

* **NFR1 — Reversible & inspectable.** Symlink/copy install; clean uninstall.
* **NFR2 — Bounded cost.** Hard caps: ≤4 personas, ≤2 rounds, artifact-size rules. No
  loop-until-converged.
* **NFR3 — Zero org-coupling in core.** No org-confidential content in persona bodies
  (internal product internals, OKRs, customer/PII data) — all in the private
  overlay. (Ref: scrub-before-public-repo standard.)
* **NFR4 — Reuse the format, not the machinery.** Same `{ts,from,text}` JSONL lines; do **not**
  inherit markers/cursors/listen-loop/Stop-hook built for the opposite (peer-session) model.
* **NFR5 — Observable.** Each run leaves a transcript + a one-line counterfactual journal entry
  (solo decision, net-new catch Y/N, dismissed Y/N) so the KPI is measurable.
* **NFR6 — Testable.** (a) agents load without error; (b) the **rules-table** selection cases are
  deterministic and asserted ("model change" → ml-scientist + ab-critic + reliability); (c) the
  **orchestrator round contract** is tested: round-1 outputs reach round-2 prompts and synthesis
  preserves a dissent. (Not the mode-A `--as` round-trip — that machinery isn't shipped.)

## Out of Scope

* **Peer-session real-time mode (mode A)** — multi-terminal live agents. Deferred; format kept
  compatible so it *could* be added.
* **Auto-suggest trigger** — deferred to post-validation.
* **`--as` extension / forking the `agent-chat` script** — not built; transcript-only.
* **Runtime dependency on the agent-chat plugin** — explicitly avoided.
* **Team distribution / `ai-workflows` packaging** — later phase.
* **Reimplementing procedural skills** — fleet complements `code-reviewer`, `investigation`, etc.;
  personas may delegate to them.
* **Settings/config UI** — agents are markdown; edit the file.

---

# Validation Gate (new, from review)

Before investing further past v1: over the first ~20 real decisions, run the counterfactual
(solo-first → council). If net-new acted-on catch rate clears ~40% and false-alarm < 50%, keep
building (library expansion, mode A, auto-suggest). If not, collapse the council into a single
context prompted with the selected lenses and retire the orchestration apparatus.

---

# Stakeholders & Timeline

| Stakeholder | Role | Level |
|---|---|---|
| Zhach Volker | DRI / sole user | Approve |
| `agent-chat` (internal JSONL room format) | upstream format we borrow | Inform (no fork, no runtime dep) |

## Staged Timeline (honest)

* **PRD (Rev 2) + DD + plan:** this session.
* **v1 slice:** orchestrator (`/council`) + 6 ship-set personas + artifact-passing + transcript +
  counterfactual journal. Verified by tests (NFR6 a/b/c).
* **Gate:** ~20 real runs ⇒ keep/iterate/kill.
* **Fast-follow (gated):** library personas, overlay enrichment, mode A, auto-suggest.

---

# Open Questions / Discovery Tasks (resolve in DD)

| # | Question / Task | Owner | Due |
|---|---|---|---|
| 1 | Final v1 persona bodies (6) — lens, tool allowlist, output schema | DRI | DD |
| 2 | Selection mechanism: rules table coverage + LLM fallback boundary | DRI | DD |
| 3 | Orchestrator form: slash-command skill vs agent (decided: **skill** driving main session) | DRI | DD |
| 4 | Artifact capture + excerpting rules (size thresholds, path vs inline) | DRI | DD |
| 5 | Round-2 peer-brief summarization format | DRI | DD |
| 6 | Synthesis output format that keeps dissents skimmable < 2 min | DRI | DD |
| 7 | Counterfactual journal: schema + location | DRI | DD |

---

# Next Steps

1. **DD** — architecture for selection, round protocol, artifact passing, transcript, overlay,
   synthesis, with the corrected execution model. ≥2 options on selection mechanism (OQ#2).
2. **Plan** via `superpowers:writing-plans`.
3. **Implement with subagents**, then **verify everything**.
