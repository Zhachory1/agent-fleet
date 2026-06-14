# PRD — Blinded-judge sample mechanism

**ID**: PRD-20260614-blinded-judge
**Status**: Draft — **Rev 3** (post NFR6 external-context review)
**Domain**: agent-fleet
**DRI**: Zhach Volker
**Last updated**: 2026-06-14
**Addresses**: GitHub issue #1 (close after metrics-gate per Next Steps; shipping the helper is
NOT closing the issue)

> **Rev 3 changelog** (NFR6 external-context review by Gemini in fresh context, 1 BLOCKER + 5
> MAJOR): n=5 dual-judge calibration **rescoped from quantitative to qualitative** — statistical
> power on n=5 is so low any disagreement falls inside the CI, structurally defaulting to
> retaining self-report. **Replacement threshold raised to n≥50 with named CI**; until then BOTH
> metrics are diagnostics, neither is canonical · FR8 step-3-when-step-2-failed case made explicit
> (judge-only row vs in-place update) · header changed: "Addresses #1", not "Closes #1" ·
> `judge_model_family` renamed `judge_model_family_self_reported` everywhere — the field name
> carries the warning that the operator's incentive to inflate noise floor is unprevented ·
> `judge_prompt_sha256` rescoped — documents helper output for rubric-drift only; paste-time
> tampering is an unsolvable-in-paste-and-record gap, deferred to v1.1 CLI shell-out ·
> "materiality" rubric-tuning defense is **process not technical**: rubric changes require a PR
> with rationale + version bump + version-partitioned agreement reporting; the attack is made
> visible in git history, not prevented.
>
> **Rev 2 changelog** (council gate #1, SPLIT, red-team BLOCK, product-pm NEED-MORE-INFO):
> agreement bands DERIVED-not-asserted via DD calibration · KPI-replacement decision process named ·
> meta-recursion gate added: PRD requires external-context review before DD merges · #13 named-
> candidate dependency added to DD merge · OQ#7 flipped (judge SEES persona list) · Tier-3 honesty
> sentence inserted verbatim · Strategic Alignment rewritten (epistemic honesty, not builders-
> first/speed) · canonical prompt template added with `===JUDGE OUTPUT===` sentinel + parser-
> failure spec · FR3 contradiction resolved (single command + visible context-switch) ·
> backward-compat strategy for FR6 explicit · FR8 chain ordering specified · OQ#2 promoted to
> FR9 (artifact persistence in room) · `judge_prompt_version` field added · "Replacing self-
> report" moved to Sequenced-for-v1.1 · hash covers full prepared prompt · `judge_model_family`
> canonical list documented · FR4 reworded "calibration sample" not "validation threshold".

---

# Context

## Problem Statement
Every catch-rate / acted-on / false-alarm number on `journal.sh stats` is **self-reported by the
same person who built the tool**. The same operator selects personas, runs them, decides
post-hoc whether the council surfaced something "net-new" the solo decision missed, and writes
the journal entry. There is no blinded judge.

The council's own self-review (council-agent-fleet-self-review, 2026-06-14) flagged this twice as
a BLOCKER. Until at least *some* judgment calls are made by a context that hasn't seen the
implementation session, the published metrics are the lowest-grade evidence form possible: the
author of a tool, looking at the tool's output, generally feeling it was useful.

## Strategic Alignment

**This feature exists for epistemic honesty about the tool's published metrics**, not for builder
speed or to make catch-rate "go up". The currently-published 95% net-new catch rate is a
credibility risk; an external reader cannot defend it. The mechanism below narrows the bias
channel from author-judges-author to LLM-judges-LLM. **It does not upgrade the evidence tier.
The only upgrade is human-judges-human (issue #13).** That sentence is canonical. Repeat it in
docs.

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

### Calibration is qualitative, not quantitative (Rev 3 — BLOCKER from external review)
The PRD does NOT assert numeric bands AND does NOT use n=5 to derive any. Gemini's external review
correctly observed that n=5 binary outcomes yield ~±44pp CIs at 95%; any disagreement falls
inside the band, structurally defaulting to "retain self-report". Asserting a quantitative
calibration on that sample size IS a self-flattering shortcut.

**Calibration is now two phases:**

**Phase 1 — qualitative shape (n=5 dual-judged councils):**
1. First 5 judged councils run with TWO independent fresh-context judges each (`judge_A` and
   `judge_B`, recorded as separate fields).
2. Analysis is **descriptive only**: *where* do disagreements concentrate? Long synthesis vs
   short? Specific personas? Specific issue severities? Same model family vs cross-family?
3. The output is a paragraph in `docs/features/blinded-judge/calibration-phase1.md` — not a
   number, not a band. No KPI replacement decision is made here.

**Phase 2 — quantitative bands (n≥50 single-judged councils):**
1. After Phase 1, run ≥50 more judged councils (single judge each, cadence per FR4).
2. At n=50 the 95% CI on a binary agreement rate narrows to ~±14pp — enough to distinguish 70%
   from 90% but NOT 80% from 85%. Threshold for KPI replacement is therefore set wide: bands
   are 90%+ / 70-90% / <70% (DD finalizes exact cuts).
3. The Phase 2 sample is what triggers the Decision Process below.

**Honest disclosure:** even at n=50 we cannot detect small biases; the mechanism distinguishes
gross over-reporting from honest noise, not fine differences.

### Decision Process for KPI replacement
Per FR5 the blinded number is shadow-only until BOTH (a) Phase 2 sample lands AND (b) the DRI
has executed the process below:

- **When:** after ≥50 judged runs in Phase 2 (not 10 — corrected Rev 3) AND Phase 1 has produced
  the descriptive paragraph.
- **Who:** the DRI on a written one-pager committed to `docs/features/blinded-judge/decision-<date>.md`.
- **What replaces what:** the README's headline catch rate switches from self-report to the
  blinded number IF Phase 2 agreement falls in the <70% band. The self-report stays in the
  journal and stats output as a diagnostic. **In the 70-90% band BOTH metrics remain diagnostics;
  neither is canonical** — README publishes both with their CIs.
- **Reversal:** if a later batch of ≥25 runs shifts the agreement rate by ≥10pp, the DRI
  revisits.

## Guardrails (numeric)
| Metric | Limit |
|---|---|
| Latency per judge call | ≤ 60s end-to-end (paste prompt + read response) |
| Operator cognitive overhead per judged run | ≤ 2 minutes (single command, two visible context switches) |
| % of runs judged | ≥ 20% (first 5 dual-judged for Phase 1, then every 5th — dual-judging may slow Phase 1 if cadence allows it; otherwise sequential) |
| Self-vs-blind agreement rate | report it; no hard gate — it IS the metric |
| Parse rate of judge response | 100% — record refuses on parse failure (no silent garbage) |

## Baseline / Target
| Metric | Baseline | Target |
|---|---|---|
| Judged runs in journal | 0 | first 5 dual-judged (Phase 1), then ≥20% single-judged toward n≥50 (Phase 2) |
| Self-vs-blind agreement rate | unknown | publish with CI; act per Decision Process; do NOT switch KPI before n=50 |
| Judge-vs-judge agreement rate | unknown | descriptive paragraph from Phase 1 n=5; NO numeric calibration claimed |
| Operator friction | n/a | low enough that the mechanism survives past Phase 1 |

---

# Scope & Requirements

## Functional

* **FR1 — Three-input bounded brief, PLUS persona list.** The blinded judge receives EXACTLY
  these blobs and nothing else:
  1. ARTIFACT (the diff/doc/proposal the council reviewed)
  2. SOLO_DECISION (operator's pre-council decision + risks-they-already-saw)
  3. COUNCIL_SYNTHESIS (synthesized verdict + ranked issues + named dissents)
  4. PERSONA_LIST (the names of the personas that ran — e.g. `ml-scientist, ab-critic, red-team`)

  **Why PERSONA_LIST is in (changed from Rev 1, council gate #1):** without it the judge cannot
  detect synthesis confabulation — e.g. a synthesis listing perf-engineer-shaped issues when no
  perf-engineer was in the council. Hiding the list reduces the judge's ability to catch failure
  modes we have not anticipated.

  The judge does NOT see: per-persona positions, the operator's post-hoc note, the operator's
  identity, prior journal state, the prompt that produced the council, any chain of thought, the
  rubric in earlier versions, or any prior council output.

* **FR2 — Canonical prompt template with sentinel-delimited output.** The exact prompt is
  versioned and ships in the repo as `lib/blind-judge-prompt.v1.txt`. The judge MUST return:

  ```
  ===JUDGE OUTPUT===
  NET_NEW_CATCH: true|false
  WHY: <one sentence>
  ===END===
  ```

  Two-clause rubric for `true`: an issue in COUNCIL_SYNTHESIS that is (a) NOT already named or
  closely implied in SOLO_DECISION's risks-already-seen, AND (b) material to the decision. If
  `true`, the `WHY` names the specific net-new issue; if `false`, the `WHY` names the closest
  solo↔synthesis pair so the operator can inspect why the judge gave no credit. **Record refuses
  on parse failure** (`===JUDGE OUTPUT===` sentinel missing OR `NET_NEW_CATCH:` line missing OR
  value not `true|false`): prints the offending line, exits 1, never silently records garbage.

* **FR3 — Single-command paste-and-record (resolves Rev 1 contradiction).** Rev 1 framed
  operator-friction as a feature (blinding is visible) AND worried that the operator would drop
  the cadence (lens-baseline arm precedent). That is contradictory. Rev 2 picks one: **smooth the
  workflow, make the blinding visible via a context-switch indicator, not via the number of
  commands.** Concretely:
  ```
  lib/blind-judge.sh judge <room>
  ```
  - Prints the prepared prompt to stdout AND copies it to clipboard (`pbcopy` on mac,
    `xclip -selection clipboard` on linux, fallback to stdout-only with a printed instruction
    `"copy the above into a fresh chat"`).
  - Prints a visible banner: `"⚠ SWITCH CONTEXTS NOW — open a NEW chat (different account or
    different model family if available), paste the prompt, then return here."`
  - Waits on stdin for the structured response (heredoc or piped).
  - Validates strictly (FR2). Refuses on parse failure.
  - Records: appends to journal row + writes `@@from: blind-judge` line to the room.

  Two visible context switches (terminal → fresh chat → back) instead of four commands. The
  blinding remains visible; the friction is in the right place.

* **FR4 — Cadence: first 10 calibration sample + every Nth.** The first 10 multi-iteration
  councils after this lands are judged unconditionally. **This is a calibration SAMPLE, not a
  validation THRESHOLD.** Statistical power for a binary outcome at 70-90% expected agreement
  needs n~50-100 for ±10pp confidence; n=10 only tells us the *shape* of the disagreement
  (where it concentrates, what kinds of catches the judge calls vs disputes). After 10, every
  5th run is judged. The cadence is documented in SKILL.md; the helper does not enforce it (the
  operator owns it). Forcing mechanism (gate journal-append on judge-completion) is deferred to
  v1.1 if first-10 compliance drops below 70%.

* **FR5 — Shadow, not replace (v1).** The blinded judge's answer is stored ALONGSIDE the
  operator's self-report. The dashboard reports both. Replacement triggers per the **Decision
  Process** above; not before ≥10 judged runs.

* **FR6 — Journal schema additions (run_kind-style backward compat).** Six new fields on the
  journal row:
  - `judge_blinded`: bool — was this run judged? Default `false` if missing.
  - `judge_blinded_catch`: bool|null — judge's NET_NEW_CATCH answer (null if not judged).
  - `judge_why`: string — judge's WHY one-liner.
  - `judge_model_family_self_reported`: string — `claude` | `gpt` | `gemini` | `local-llama` |
    `mistral` | `grok` | `deepseek` | `other`. **Operator-supplied. The field name carries the
    warning** (Rev 3): the operator could pick a deliberately weak model to inflate the noise
    floor; the helper cannot prevent this. Free-string accepted; canonical list above is what
    stats groups; anything unrecognized rolls into `other`. Stats output prefixes the metric
    with `[self-reported]` so the reader sees the gap.
  - `judge_prompt_version`: string (e.g. `v1`) — pins which rubric was used. **Rubric changes
    require a PR with a one-paragraph rationale + version bump**; this makes any "tune the
    materiality threshold until LLM agrees with me" attack visible in git history. Stats
    partitions agreement rates by version (cross-version pooling is forbidden).
  - `judge_prompt_sha256`: string — SHA256 of the *helper-produced prepared prompt* (rubric +
    sentinels + artifact + synthesis + persona_list as the helper emits them). **Detects
    rubric drift in the HELPER ONLY** (Rev 3 — corrected from Rev 2's overscoped claim). Does
    NOT detect operator paraphrasing in the browser between copy and paste; that is an
    unsolvable-in-paste-and-record gap, partial mitigation only via CLI shell-out (v1.1).

  **Backward compat:** rows without these fields are treated as `judge_blinded=false`. Stats
  arm reports `n/a` when no judged runs exist. Test_journal.sh asserts both legacy and
  fully-populated row shapes parse correctly. **Schema migration script is OUT of v1**; legacy
  rows continue to work as-is, same pattern as `run_kind` rolled in.

* **FR7 — Stats arm.** `journal.sh stats` reports two new lines:
  ```
  blinded-judge sample : Y of N runs judged = Z%  (judged_blinded=true)
  self-vs-blind        : X of Y agree = W%        [calibration phase: N<10]
  ```
  If <10 judged runs: print `[calibration phase — N/10]` instead of a band interpretation.
  If ≥10: print agreement % + a `⚠ disagreement > 30%` annotation if relevant (cosmetic; does
  not affect verdict). Verdict line unchanged — the gate is per the lens-baseline + catch-rate
  arms as today.

* **FR8 — Chain ordering and failure semantics.** Explicit ordering for any judged council:
  1. `transcript.sh capture` writes the per-persona positions to the room.
  2. `journal.sh append` records the self-report (transcript-guard ensures step 1 happened).
  3. **(judged runs only)** `blind-judge.sh judge` prepares + records — writes a
     `@@from: blind-judge` line to the room (transcript-guard ensures step 1 happened) AND
     updates the existing journal row's `judge_*` fields (idempotent: re-running with the same
     room overwrites, but only the `judge_*` fields).

  Failure semantics (Rev 3 — step-3-when-step-2-failed case made explicit):
  - If 1 fails → 2 refuses (existing guard).
  - If 2 fails → 3 still possible. Two sub-cases:
      (a) **No journal row exists for this room.** Step 3 writes a NEW row with all
          self-report fields set to `null` and only the `judge_*` fields populated. This is
          a "judge-only" row; it counts in `judged_runs` but is excluded from
          self-vs-blind-agreement calculations (no self-report to compare against). Stats
          surfaces these as a separate count: `judge-only rows: N` so the operator sees the
          journal-append failures piling up.
      (b) **Journal row exists from a previous successful step 2.** Step 3 updates the
          `judge_*` fields in place.
    The helper detects which sub-case applies by checking for the room in the journal.
  - If 3 fails parse → no row mutation OR write; error exit 1; user re-runs after fixing.
  - No orphaned state: a judged row always has `judge_blinded=true` AND the transcript
    `@@from: blind-judge` line; either both or neither.

* **FR9 — Artifact persistence in the room (orchestrator requirement).** The orchestrator MUST
  write the artifact under review to `~/.claude/agent-chat/rooms/council-<slug>/artifact.txt`
  alongside the transcript. `blind-judge.sh prepare` reads it from there; `/tmp/council-<slug>.txt`
  is no longer authoritative (it may be cleared between the council and the judge call). The
  orchestrator skill must enforce this in Step 1 of SKILL.md. This is a cross-component
  requirement; it is in this PRD because the helper depends on it.

## Non-Functional

* **NFR1 — Zero new runtime dependency.** Bash + jq only. No curl, no Python, no API keys.
  Paste-and-record is the contract.

* **NFR2 — Bounded operator friction.** ≤2 min per judged run. If that bound is consistently
  exceeded the cadence will drop; revisit FR3 or add a forcing gate per FR4.

* **NFR3 — Honest blinding, with unprevented operator-attack surface (Rev 3).** The canonical
  prompt explicitly states what the judge does NOT have access to so a future reader can audit
  blinding integrity. The operator MUST switch contexts (new chat, ideally different model
  family). **Unprevented attacks** (operator self-interest to inflate noise floor / drop the
  cadence / paraphrase the prompt in-browser / iteratively tune the rubric to match their
  intuition) are documented HERE, not silently glossed:
    - `judge_model_family_self_reported` is exactly what the name says — unverifiable.
    - `judge_prompt_sha256` does not catch paste-time edits.
    - Rubric-tuning is countered by git-history-visibility (versioned + PR-required), not
      technical prevention.
  These gaps are partially closed in v1.1 via CLI shell-out; in v1 they are disclosed.

* **NFR4 — Tier-3 disclosure (canonical sentence, repeat verbatim).** "This feature narrows the
  bias channel from author-judges-author to LLM-judges-LLM. It does not upgrade the evidence
  tier. The only upgrade is human-judges-human (issue #13)." README, SKILL.md, and stats output
  MUST carry that sentence or a direct paraphrase. Issue #13 must be linked from each.

* **NFR5 — Backward compatibility (FR6).** Existing journal rows are treated as
  `judge_blinded=false`. Stats degrade gracefully when no judged runs exist.

* **NFR6 — External-context PRD review gate (resolves council BLOCKER #1).** Before DD merges,
  this PRD must be reviewed by a context that has not seen its authorship session. Concretely:
  paste this PRD into a fresh chat with no prior memory, request one round of critique against
  these criteria — (a) is the framing internally consistent, (b) is the KPI honest, (c) does
  any acceptance criterion smuggle in a self-flattering shortcut — and attach the critique as a
  comment on PR #16. DD work does not start until this gate closes.

## Out of Scope (v1)
* CLI shell-out to `claude` / `llm` / `openai` for automated judging. Paste-and-record only.
* HTTP API integration / key handling.
* Multi-judge consensus (3+ judges and voting). Dual-judge is in scope ONLY for the first 5
  calibration runs (per the calibration strategy above), not as ongoing operating procedure.
* Auto-detecting solo-decision quality. Record `solo_decision_word_count` going forward;
  correlation analysis is deferred.
* Forcing gate that blocks `journal.sh append` until judge completion. Decision deferred to v1.1
  based on first-10 compliance data.

## Sequenced for v1.1 (not OoS — explicit later phase)
* Switch canonical KPI from self-report to blinded number (FR5 explicitly defers this; the
  Decision Process names trigger + decision-maker).
* Forcing gate per FR4 if cadence compliance < 70% in v1.
* CLI shell-out judge as an OPTIONAL alternative to paste-and-record.

---

# Open Questions (for DD)

| # | Q | Leaning |
|---|---|---|
| 1 | Format of the judge's reply: bash-grep-parseable text with sentinels (FR2) — what about whitespace handling, unicode in WHY, multi-line WHY accidentally pasted? | Strict single-line WHY; reject multi-line; document. DD finalize. |
| 2 | (RESOLVED — promoted to FR9.) | — |
| 3 | Solo-decision-quality confound: how to surface it without making the metric noise? | Record `solo_decision_word_count` on every row going forward; offline analysis only; no FR. DD confirm. |
| 4 | Does cadence ("every 5th") need to be enforced or just documented? | Documented in v1 (FR4); enforce in v1.1 only if first-10 compliance drops below 70%. |
| 5 | Hash-of-paste: SHA256 of the full prepared prompt (rubric + sentinels + blobs + persona_list). Recorded in `judge_prompt_sha256`. | Resolved in FR6. DD confirms test fixtures match. |
| 6 | What does `journal.sh stats` print during calibration phase (judged_runs < 10)? | `[calibration phase — N/10 runs judged]`. DD confirm cutoff. |
| 7 | (RESOLVED — judge SEES persona list per FR1; council gate #1 flipped Rev 1's "omit" leaning.) | — |
| 8 | Dual-judge calibration (first 5 runs) — same-family or force-cross-family for the second judge? | Same-family for B in 3 of 5, cross-family in 2 of 5 — gives us both noise-floor estimate AND family-bias signal in n=5. DD finalize. |
| 9 | What does `judge_prompt_version` bump look like operationally? Branch / commit / tag? | DD: tag `judge-prompt-v2` in git when the prompt template changes; helper reads the version string from the committed prompt file. |

---

# Next Steps
1. **External-context PRD review gate (NFR6).** Required before DD work. Comment on PR #16.
2. **#13 named-candidate gate.** DD merge requires issue #13 to have a named candidate external
   user (not shipped). Tracked on #13.
3. `/council` on DD (target personas: data-engineer for the schema, generalist-swe for chain
   semantics, red-team for the recursion meta-objection, docs-dx for the prompt template).
4. PLAN absorbs DD feedback → `/council` on PLAN.
5. Implementation in a fresh subagent → `/code-review` → `/council` on the implementation PR.
6. Close issue #1 only after ≥10 judged runs land and the agreement band is named in stats AND
   the Decision Process has been executed (i.e. either the KPI has switched or the DRI has
   documented why it has not).
