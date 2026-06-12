# SEPRD — Iterative cross-reflection rounds

**SEPRD-ID**: SEPRD-20260612-council-iterative-reflection
**Status**: Draft — Pending Team Ratification · **Rev 2** (post council gate #1)
**Domain**: agent-fleet (personal tooling) · GitHub issue ROKT/agent-fleet#1
**DRI**: Zhach Volker
**Last updated**: 2026-06-12

> **Rev 2 changelog** (council gate #1, SPLIT, red-team BLOCK): mush guard made **structural**
> (critique-before-concede), not a prompt nudge — red-team's killer point that the feature is
> otherwise a sycophancy loop · convergence = **verdict-only** for v1 (semantic "new-issue"
> detection dropped — unimplementable cheaply/deterministically) · backward-compat reframed
> honestly (round-2 behavior *changes*) · `changed` **inferred orchestrator-side** (verdict diff),
> no persona-file schema change · SKILL.md is canonical, portable prompt kept in sync via a test ·
> KPI given a sample size + revert trigger.

---

# Context

## Problem Statement
The council orchestrator runs ≤2 rounds; Round 2 is conditional and injects only a *summarized*
peer brief. So personas mostly judge **blind** — they rarely react to each other. The user wants
genuine **iterative reflection**: each persona reads what the others said and revises its own
judgment over several rounds (concede what's persuasive, hold-and-defend what it still believes),
until positions converge. Blind one-shot positions miss the value of a real review *discussion* —
where one specialist's finding reframes another's verdict.

## Strategic Alignment
Direct enhancement of the council's core value (decision quality). No external dependency. Must not
regress the existing guardrails (bounded cost, anti-consensus-mush, transcript integrity).

## User & Use Case
Me, running `/council` on a high-stakes decision. After round 1, personas should explicitly
reflect on peers and either change or defend their position — and I should be able to *see the
evolution* in the transcript.

---

# Success & Measurement

## Primary KPI
**Reflection yield**: fraction of multi-iteration runs where ≥1 persona *changes its verdict after
reading peers* (observable, orchestrator-detected via verdict diff) AND I judge the change correct.
**Evaluation:** sampled manual review after **≥10 multi-iteration runs**. **Revert trigger:** if
yield < 30% after 10 runs, drop the default back to a single blind round — reflection is theater.

## Guardrails (numeric)
| Metric | Limit |
|---|---|
| Iterations per run | hard cap ≤4 (default 2); verdict-stable convergence-stop ends early |
| Personas per run | unchanged ≤4 |
| Token cost | bounded: convergence-stop + cap; round N injects peers' prior positions (capped count, not full history of all rounds) |
| False-consensus | **structural** anti-mush (FR4); if all personas flip to the majority verdict in one round, emit a WARNING and do NOT count it as convergence |

## Baseline / Target
| Metric | Baseline | Target |
|---|---|---|
| Reflection yield (verdict-change, acted-on) | 0 | ≥30% of multi-iter runs, evaluated after ≥10 runs |
| Convergence-stop efficacy | n/a | stops before the cap in a majority of runs (logged) |

---

# Scope & Requirements

## Functional
* **FR1 — N iterations.** `/council … --iterations N` (default 2, hard cap 4). Iteration 1 = blind
  positions (today's behavior). Iterations 2..N = reflection rounds.
* **FR2 — Cross-reflection (critique-before-concede).** In iterations ≥2, each persona receives
  **peers' prior-round positions** and MUST, *in order*: (a) for each peer point it disagrees with,
  state the strongest **refutation** first; (b) only then concede points it cannot refute;
  (c) emit a (possibly revised) verdict + issues + a short `reflection:` note. The refute-first
  ordering is the structural anti-sycophancy lever — a persona may not silently agree, it must
  earn agreement by failing to refute. Personas stay stateless; the orchestrator injects the peer
  positions into the prompt (no persona-file schema change — see FR for `changed`).
* **FR3 — Convergence stop (verdict-only, v1).** End early when an iteration produces **no verdict
  change** across all personas (orchestrator diffs round N-1 vs N verdicts — deterministic). Always
  stop at the cap. Semantic "no new issue" detection is **out of v1** (unimplementable cheaply;
  the ≤4 cap bounds cost regardless).
* **FR4 — Structural mush guard.** Anti-mush is the refute-first ordering (FR2), NOT a "hold your
  ground" nudge. Plus a detector: if all personas **flip to the majority verdict in a single
  round**, emit a `⚠ converged-this-round` WARNING and do **not** treat that round as a clean
  convergence-stop (it may be sycophancy). `red-team` is auto-included in any multi-iteration run
  as standing dissent.
* **FR5 — `changed` inferred orchestrator-side.** The orchestrator computes `changed: yes|no` per
  persona by **diffing its verdict** across rounds — deterministic, no new required field in the
  persona `.md` files. The persona's free-text `reflection:` note is for the transcript only.
* **FR6 — Transcript per iteration.** Each iteration's positions are captured **round-tagged**
  (`@@from: <persona>#r<N>`), so `transcript.sh show` renders the round-1 → round-2 → … evolution.
  Anti-skip journal guard still holds.
* **FR7 — Honest backward-compat + single source.** Default stays cap 2, but **round-2 behavior
  changes**: it becomes a real reflection round (was a summarized blind brief) — this is an
  improvement, declared, with tests updated. **SKILL.md is the canonical orchestrator**;
  `prompts/council-orchestrator.md` is kept in sync, enforced by a test asserting both agree on the
  iteration cap + flag.

## Non-Functional
* **NFR1** — Cost bounded; no unbounded loop; convergence-stop mandatory.
* **NFR2** — Personas stay stateless one-shots; orchestrator still sequences (no live chat).
* **NFR3** — Reflection must preserve dissent; the feature must not increase false-consensus rate.
* **NFR4** — Testable: convergence-stop and cap are deterministic and asserted.

## Out of Scope
* Live peer-session chat (Mode A) — still deferred.
* Persona definition changes.
* Auto-tuning iteration count.

---

# Open Questions (for DD)
| # | Q | Leaning (from council) |
|---|---|---|
| 1 | Round-N input: peers' full prior positions vs summarized? | Full prior positions, but only the immediately-prior round (not all rounds); cap persona count at 4 so it's bounded. Confirm token budget in DD. |
| 2 | Convergence detection | **RESOLVED:** verdict-only diff (deterministic). Semantic new-issue dropped from v1. |
| 3 | `changed` field | **RESOLVED:** inferred orchestrator-side via verdict diff; no persona-file change. |
| 4 | Default iteration count | Keep 2 (round-2 now a real reflection round). Revert to 1 if KPI < 30% after 10 runs. |
| 5 | Critique-before-concede: how to encode in the reflection prompt so it's actually followed, and can we test that round-≥2 output references peer points? | DD |

---

# Next Steps
DD (round loop, reflection prompt, convergence detection, transcript round-tags) → plan → implement
→ /code-review. `/council` review at each gate.
