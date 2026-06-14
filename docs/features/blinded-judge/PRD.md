# PRD — Blinded-judge sample mechanism

**ID**: PRD-20260614-blinded-judge
**Status**: Draft — Pending council review
**Domain**: agent-fleet
**DRI**: Zhach Volker
**Last updated**: 2026-06-14
**Closes**: GitHub issue #1

---

# Context

## Problem Statement
Every catch-rate / acted-on / false-alarm number on `journal.sh stats` is **self-reported by the
same person who built the tool**. The same operator selects personas, runs them, decides
post-hoc whether the council surfaced something "net-new" the solo decision missed, and writes
the journal entry. There is no blinded judge.

The council's own self-review (council-agent-fleet-self-review, 2026-06-14) flagged this twice as
a BLOCKER — once by `red-team`, corroborated by `product-pm`. Until at least *some* judgment calls
are made by a context that hasn't seen the implementation session, the published metrics are the
lowest-grade evidence form possible: the author of a tool, looking at the tool's output, generally
feeling it was useful.

This makes every metric the dashboard publishes Tier-3 evidence. It also makes the validation
gate's headline number (currently 95% net-new catch rate) impossible to defend to an external
reader.

## Strategic Alignment
Builders-first: the metric exists *for the builder*, to know whether the tool earns its cost. If
the metric is structurally self-flattering, the builder is misled.
Speed: the cheapest mechanism that introduces a real blinding boundary, even an imperfect one,
is better than waiting for a perfect one (e.g. an external user, issue #13 — slower, harder).

## User & Use Case
Me, running `/council` on a real decision. After capturing the council's synthesis and writing my
own answer to "did this catch something net-new", I (or a hook) ALSO send the synthesis +
artifact + my solo decision to a *fresh* LLM context that has no knowledge of the council, my
personas, my post-hoc note, or who I am. That fresh context returns its own binary judgment. Both
answers go on the dashboard. Disagreement is itself signal.

---

# Success & Measurement

## Primary KPI
**Self-vs-blind agreement rate**: fraction of judged runs where the operator's `net_new_catch`
answer matches the blinded judge's `judge_blinded_catch` answer.

**Interpretation:**
- > 80% agreement → self-report is roughly trustworthy at the population level; keep using it but
  publish the blinded-judge rate as the headline.
- 50-80% → significant disclosure gap; the published catch rate over-reports. The blinded number
  becomes the canonical KPI, the self-report becomes a diagnostic.
- < 50% → catch-rate is unreliable; the tool's value is unproven at the metric level even if it
  still feels useful.

**Evaluation:** sampled manually after **≥10 judged runs**.

## Guardrails (numeric)
| Metric | Limit |
|---|---|
| Latency per judge call | ≤ 60s end-to-end (paste prompt + read response) |
| Operator cognitive overhead per judged run | ≤ 2 minutes |
| % of runs judged | ≥ 20% (first 10 unconditionally, then every 5th) |
| Self-vs-blind agreement rate | report it; no hard gate — it IS the metric |

## Baseline / Target
| Metric | Baseline | Target |
|---|---|---|
| Judged runs in journal | 0 | first 10 unconditionally, then ≥20% |
| Self-vs-blind agreement rate | unknown | publish it; act on it per the bands above |
| Operator friction | n/a | low enough that the judge mechanism survives past run 10 |

---

# Scope & Requirements

## Functional

* **FR1 — Three-input bounded brief.** The blinded judge receives EXACTLY three blobs and nothing
  else:
  1. ARTIFACT (the diff/doc/proposal the council reviewed)
  2. SOLO_DECISION (the operator's pre-council decision + risks-they-already-saw, captured in
     Step 0 of the orchestrator)
  3. COUNCIL_SYNTHESIS (the synthesized verdict + ranked issues + named dissents)

  The judge does NOT see: per-persona positions, persona selection, the operator's post-hoc note,
  the operator's identity, prior journal state, the prompt that produced the council, any chain of
  thought, or any prior council output.

* **FR2 — Single binary output with a forced format.** The judge returns EXACTLY:
  ```
  NET_NEW_CATCH: true|false
  WHY: <one sentence>
  ```
  No preamble, no commentary, no scoring. Two-clause rubric for `true`: an issue in
  COUNCIL_SYNTHESIS that is (a) NOT already named or closely implied in SOLO_DECISION's
  risks-already-seen, AND (b) material to the decision. If `true`, the `WHY` names the specific
  net-new issue; if `false`, the `WHY` names the closest solo↔synthesis pair so the operator can
  inspect why the judge gave no credit.

* **FR3 — Paste-and-record workflow (MVP).** No CLI shell-out, no API key handling. A helper
  (`lib/blind-judge.sh prepare <room>`) prints a self-contained prompt to stdout, ready to paste
  into any fresh LLM chat. The operator pastes, copies the structured response, runs
  `lib/blind-judge.sh record <room> ...` to file it. Paste-and-record makes the blinding
  *visible* — the operator has to actually switch contexts — and supports the "paste into a
  different model family" pattern without code change.

* **FR4 — Cadence: first 10 + every Nth.** The first 10 multi-iteration councils after this lands
  are judged unconditionally (calibration phase). After that, every 5th run is judged. The
  cadence is documented in SKILL.md; the helper does not enforce it (the operator owns it).
  Front-loading buys answer-speed on whether to keep doing this at all.

* **FR5 — Shadow, not replace.** The blinded judge's answer is stored ALONGSIDE the operator's
  self-report. The dashboard reports both. We do not switch the canonical KPI to the blinded
  number until ≥10 judged runs have settled which band (>80% / 50-80% / <50%) we are in.

* **FR6 — Journal schema additions.** Four new fields on the journal row:
  - `judge_blinded`: bool — was this run judged?
  - `judge_blinded_catch`: bool|null — the judge's NET_NEW_CATCH answer (null if not judged)
  - `judge_why`: string — the judge's WHY one-liner
  - `judge_model_family`: string — `claude` | `gpt` | `gemini` | `local-llama` | `other`,
    operator-supplied so cross-family agreement can be analyzed separately

* **FR7 — Stats arm.** `journal.sh stats` reports a new line:
  `blinded-judge agreement: X/Y self/judge agree = Z%   (Y of N runs judged)` plus the blinded
  catch rate itself. Disagreement > 30% prints a `⚠` annotation (does not change the verdict —
  the verdict is reported per the existing gate; the annotation is the disclosure).

* **FR8 — Transcript guard parity.** The judge record is itself a sibling write to the run's
  transcript room (a `@@from: blind-judge` line), enforced the same way `journal.sh append`
  enforces transcript-first: `blind-judge.sh record` REFUSES if the room has no captured
  transcript. Preserves the existing structural anti-skip guard.

## Non-Functional

* **NFR1 — Zero new runtime dependency.** Bash + jq only (matches the rest of the toolchain). No
  curl, no Python, no API keys. Paste-and-record is the contract.

* **NFR2 — Bounded operator friction.** ≤2 min per judged run; if it costs more than that, the
  operator will silently drop it (this is the failure mode we already saw with the
  lens-baseline arm — 2/22 runs).

* **NFR3 — Honest blinding.** The prompt explicitly states what the judge does NOT have access to,
  so a future reader can audit whether blinding was real. The operator MUST switch contexts (new
  chat, ideally different model family); the helper records `judge_model_family` so same-family
  vs cross-family agreement can be separated.

* **NFR4 — Tier-3 disclosure.** This mechanism narrows the bias channel; it does NOT eliminate it.
  README + SKILL.md must continue to say so, and direct readers to issue #13 (first external
  user) as the next-level validation.

* **NFR5 — Backward compatibility.** Existing journal rows lack the new fields and are treated as
  `judge_blinded=false`. Stats degrade gracefully (the new arm reports `n/a` when no judged runs
  exist).

## Out of Scope (deferred to follow-up issues)

* CLI shell-out to `claude` / `llm` / `openai` for automated judging (issue TBD after MVP earns
  its keep). Paste-and-record only for v1.
* HTTP API integration / key handling.
* Multi-judge consensus (running the same artifact past 3 judges and voting). Defer until we know
  whether n=1 judge is even useful.
* Auto-detecting solo-decision quality (short solos trivially produce "everything is net-new" —
  see Open Question 3).
* Replacing the self-report. Shadow-only until ≥10 judged runs.

---

# Open Questions (for DD)

| # | Q | Leaning |
|---|---|---|
| 1 | Format of the judge's reply — strict `NET_NEW_CATCH: true|false` text grep, or JSON? | Strict text. Bash + grep parseable, no jq, no fragility on stray newlines. DD decide. |
| 2 | Where does ARTIFACT come from for `prepare`? The run may not have written `/tmp/council-<slug>.txt`. | DD: either inline if <2KB (read from transcript), or require operator to supply `--artifact <path>`. |
| 3 | How do we surface solo-decision-quality as a confound? | DD: record `solo_decision_word_count` on every row going forward; later check correlation between short solos and judge-net-new-true. Out of scope for FR; data only. |
| 4 | Does cadence ("every 5th") need to be enforced, or just documented? | Leaning: documented, not enforced. The operator owns it. If they skip every judge call we will see it in stats and the gate will not let them off the hook. |
| 5 | Does the helper record a hash of the artifact + synthesis so we can verify the operator pasted them faithfully? | Leaning: yes, lightweight `sha256sum` written to the journal — defense against "judge said no, operator pasted a sanitized version". DD confirm. |
| 6 | What does `journal.sh stats` print when judged runs < 10? | "(calibration phase — N/10 runs judged)" instead of a percentage. DD confirm threshold. |
| 7 | Should the judge be force-blind to the persona set, or is the persona list fair to include? | Leaning: omit it. Knowing which lenses ran biases the judge toward thinking those lenses' issues are "expected". DD confirm. |

---

# Next Steps
1. `/council` on this PRD (target personas: docs-dx, product-pm, generalist-swe, red-team auto).
2. DD absorbs council feedback → `/council` on DD.
3. PLAN absorbs DD feedback → `/council` on PLAN.
4. Implementation in a fresh subagent → `/code-review` → `/council` on the implementation PR.
5. Close issue #1 only after ≥10 judged runs land and the agreement band is named in stats.
