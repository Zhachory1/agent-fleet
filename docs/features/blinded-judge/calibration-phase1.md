# Blinded-judge Phase 1 calibration

> Qualitative shape-of-disagreement readout from the first 5 dual-judged councils. Closes #48. **Does NOT close #1**: per #20, #1 closes only after Phase 1 + Phase 2 (50 single-judged runs) + DRI decision + README/stats update. **NOT** the quantitative band decision — that's Phase 2 + DRI-decision-`<date>`.md.

**Phase 1 completed:** 2026-06-16
**Operator/DRI:** @Zhachory1

## Sample

5 distinct councils, dual-judged (10 judge calls total). **All five pairs are cross-family** (Claude judge-a vs Gemini judge-b).

| # | Room | judge-a family | judge-b family | Pair kind |
|---|---|---|---|---|
| 1 | `council-cache-prd` | claude (fresh) | gemini | cross-family |
| 2 | `council-permtier-prd` | claude (in-session, contaminated) | gemini | cross-family ⚠ |
| 3 | `council-prose-40pct` | claude (in-session, contaminated) | gemini | cross-family ⚠ |
| 4 | `council-prose-40pct-finding` | claude (in-session, contaminated) | gemini | cross-family ⚠ |
| 5 | `council-repo-state-v010` | claude (fresh) | gemini | cross-family |

**Departure from PRD-OQ8 target (3 same-family + 2 cross-family):** Phase 1 ran **all-cross-family** rather than the planned 3:2 mix. The same-family arm has n=0 in this sample, and a 3rd family (GPT) was not exercised at all. **Implication:** Phase 1 cannot distinguish "rubric is family-robust" from "rubric agrees within the specific Claude/Gemini pairing." Phase 2 must rebalance: deliberately schedule same-family pairs and a 3-family-cross-family arm to cover the gap Phase 1 left open.

**Contamination caveat (3 of 5 judge-a rows):** for councils 2, 3, and 4, the judge-a call (Claude side) was made by an LLM in the same session as the orchestrator that produced the council. The LLM had read the rubric, knew the project's vocabulary, and was the agent that built the council mechanism. This is the **maximally bad case** for "blinded" judging — context contamination is total on the Claude side of those 3 pairs. Both materiality clauses were still tested against the rubric, but the verdict cannot be treated as independent of the council's authoring. The Gemini judge-b on those same rooms was fully blinded (fresh chat, no project context), so the contamination is asymmetric across the pair, not symmetric.

**Empty-synthesis caveat (4 of 5 rooms):** rooms 1-4 have **no `@@from: synthesis`** block in their transcript — they predate the orchestrator's Step 5 mandate (filed as #57, resolved by the empty-synthesis-warning in `lib/blind-judge.sh`). Only room 5 (`council-repo-state-v010`) has a synthesis block. The rubric's dissent-erasure cross-check was therefore vacuous on 4 of 5 rooms — every persona claim trivially "missing from synthesis." Judge prompts handled this gracefully, but the dissent-erasure SIGNAL is muted on most of the Phase 1 sample.

**Self-review caveat (1 of 5 rooms):** room 5 (`council-repo-state-v010`) is a council on agent-fleet itself. The original phase1-worksheet explicitly excluded self-reviews. It was used here because it was the only synthesis-bearing room available as a 5th distinct council. **Implication:** judges 2 and 3's verdicts on this room are about a meta-recursive artifact (the operator running councils about whether to run more councils); calibration signal from this row should be weighted accordingly.

**Catch=false caveat (0 of 5 formal rooms):** every formal Phase 1 judgment returned `NET_NEW_CATCH=true`. That means Phase 1 did **not** exercise the rubric's specificity / false-positive arm. The sample can show whether judges agree on obvious material catches; it cannot show whether the rubric correctly says `false` when the council adds no genuinely net-new material issue. Phase 2 should include naturally negative or low-signal rooms before making any KPI decision.

## Disagreement count and shape

| # | Room | judge-a | judge-b | Agree? | One-line shape |
|---|---|---|---|---|---|
| 1 | `council-cache-prd` | catch=**true** | catch=**true** | ✅ | Both judges centered on the same finding (multi-breakpoint anchor likely a no-op) via different evidence quotes (judge-a: "tools breakpoint NO-OP cargo-cult"; judge-b: "92% ceiling-destroyer") |
| 2 | `council-permtier-prd` | catch=**true** | catch=**true** | ✅ | Both judges flagged software-architect's `beforeToolCall`-is-terminal seam-bug; judge-b additionally surfaced red-team's "false security" framing |
| 3 | `council-prose-40pct` | catch=**true** | catch=**true** | ✅ | Both flagged pre-registered-stopping-rule + per-prompt-floor concerns; judge-b additionally surfaced the qualifier-fidelity issue ("hedging IS substance") |
| 4 | `council-prose-40pct-finding` | catch=**true** | catch=**true** | ✅ | Both flagged the skipped-judge-calibration BLOCKER as the central catch (rubric §0.1 was pre-registered then skipped) |
| 5 | `council-repo-state-v010` | catch=**true** | catch=**true** | ✅ | Both centered on the stale-lockdir-threshold bug (5min < 10min judge hold) as the most concrete catch |

**Aggregate disagreement: 0/5.** Judge-a/judge-b verdict agreement = 100%. Clean-pair agreement is **2/2** for the two fresh-Claude/Gemini rooms; the remaining **3/3** agreement rows include contaminated Claude-side judge-a calls, so judge-a independence is not established for those rows.

### Key finding: contamination-vs-fresh-chat verdict flip

There's a **separate** disagreement embedded in the cache-prd row that is the calibration's most useful signal but doesn't appear in the 5-pair table above. The LLM also ran two earlier in-session judge calls on `council-cache-prd` during the helper smoke test (the "judge-1" and "judge-2" entries in the room's transcript, distinct from the fresh-chat judge-a/judge-b that appear in this writeup's row 1). Those in-session calls returned `NET_NEW_CATCH: false` — they argued the council's content was "closely implied by SOLO_DECISION's 'measurement-first' framing." The fresh-chat judges returned `NET_NEW_CATCH: true`. **Same room, same artifact, opposite verdicts.** This is the contamination-vs-fresh-judge signal that the formal table can't capture because both formal rows came from the same fresh-chat family. Whether the 3 contaminated formal rows would also change under fresh-chat judging is untested.

## Concentration analysis

Where do disagreements cluster?

- ❌ **By artifact length** — no pattern, sample agrees across artifacts from 37 to 90 source lines.
- ⚠️ **By synthesis quality** — synthesis was empty on 4 of 5 rooms; both judges handled empty synthesis the same way (treating all persona claims as fully erased). No disagreement observed on this axis, but the axis itself is **muted** because dissent-erasure was vacuous on those 4 rooms.
- ❌ **By persona being quoted** — judges quoted different personas as primary evidence in 4 of 5 rooms (red-team, software-architect, ml-scientist, ab-critic all appeared as the "EVIDENCE" source across the sample), but both judges still concluded catch=true. The persona-source disagreement was *within* the same verdict, not across verdicts.
- ❌ **By issue severity** — all catches in the sample were on findings the judges classified as material (BLOCKER-level or close). MINOR findings did not surface as the primary catch in any judgment.
- ❌ **By run-kind** — sample includes 3 design, 1 investigation, 1 investigation-shaped-as-design. All five judged catch=true. Not enough variation to test.

**Dominant pattern, observed but with low power (n=5):** judges agree on verdict but cite different evidence quotes for the same underlying council finding. Two judges scoring the same room frequently quote different persona BLOCKER lines, but both quotes point to the same material issue. This suggests the rubric's catch-detection is **persona-agnostic** within a council — what gets flagged is the *strongest material gap relative to SOLO_DECISION*, not "which persona had the most cogent point." This is the intended behavior per DD §0.1.

**Honest under-power statement:** at n=5 with 5/5 agreement, we cannot distinguish "the rubric is robust" from "Phase 1 sample was easy." Phase 2 (n≥50) is the band-measurement; this report is shape only.

## Cross-family vs same-family observation

- **Cross-family agreement rate (Claude / Gemini)**: 5/5 = 100%.
- **Same-family agreement rate**: undefined (no same-family pairs ran in Phase 1).
- **3rd-family check (GPT)**: not run.

**Honest caveat**: 5/5 cross-family agreement on a Claude/Gemini-only sample is consistent with "rubric is family-robust across these two families" AND equally consistent with "these two specific families happen to share a view-of-the-rubric." Phase 1 did not test Claude/GPT, Gemini/GPT, or Claude-fresh/Claude-different-account pairings at all — no evidence either way on those axes. The Phase 2 quantitative bands sit on n≥50, not n=5.

**Same-family arm is the Phase 2 gap to fill first.** Without any same-family Phase 1 data, there's a real risk that family-specific quirks (e.g. Claude and Gemini both happen to defer to the materiality framing more aggressively than GPT would) are baked into the 100% number. Phase 2 should schedule the first ~10 runs deliberately toward same-family-different-account and 3-family pairings to characterize the bands Phase 1's cross-family-only sample left blank.

**Side note on Gemini specifically:** the operator reports Gemini kept the strict `===JUDGE OUTPUT===` format under load without drift across all 5 judge-b calls. Same-format-discipline observation, not a calibration claim — but worth noting because format breakage was a real concern the rubric design accounted for. Both families followed the contract; format-discipline is not calibration-blocking at this sample size.

## Implications for Phase 2

1. **Expected band**: Phase 1 is consistent with a high agreement rate, but it is not a calibrated prior. Phase 2 is the measurement. Its sample will:
   - Have synthesis blocks (Phase 1's muted dissent-erasure check goes live)
   - Have less LLM contamination on the Claude side (Phase 1's 3-of-5 contaminated Claude judge-a rows skewed those rows toward "deferential to solo")
   - Mix code/design/investigation more broadly
   - Include same-family pairs Phase 1 didn't run
   - Include a 3rd family (GPT) Phase 1 didn't test

   With those changes, the Phase 1 number should be treated as an upper bound on Claude/Gemini cross-family agreement for easy positive examples, not as a prior for the full Phase 2 space.

2. **Rubric-version bump candidates before Phase 2 starts**: none from this Phase 1 readout. The rubric handled empty synthesis gracefully; the materiality test correctly distinguished closely-implied-by-solo from genuinely-net-new; both judges respected the format and the self-quote guards. No drift detected against the v2 rubric.

   *However*, the Phase 1 disagreement-within-cache-prd (LLM in-session judges said false; fresh Claude judges said true) is real and worth flagging as a **judge-context-sensitivity** observation, not a rubric flaw. The fix is at the operator level: don't run judges in the same session as the orchestrator. The fresh-chat rule was always the protocol; this run accidentally tested what happens when you violate it.

3. **Phase 2 front-loading recommendation**: Phase 1's all-cross-family weighting was an artifact of operator family-availability and Gemini's format-discipline advantage. Phase 2 should deliberately rebalance: front-load **same-family-different-account** (e.g. two Claude accounts, two Gemini accounts) in the first ~10 rooms to fill the Phase 1 gap, then introduce GPT by row ~20. After that, even mix. The goal of front-loading is to characterize the same-family band before Phase 2's pooled agreement-rate gets dominated by cross-family data.

4. **Stop pursuing contamination-free Phase 1 retroactively**: the 3 contaminated judge-a rows are useful as a calibration-of-the-calibration data point. They demonstrate the contamination-sensitivity directly (cache-prd's in-session-vs-fresh-chat verdict flip). Don't re-run them; cite the contamination explicitly in any Phase 2 report that pools Phase 1 data, and exclude the contaminated rows from any pooled agreement-rate calculation.

## What this writeup does NOT do

- ❌ Does not switch the canonical KPI from self-report to blinded. That's the DRI's Phase-2 decision.
- ❌ Does not close issue #1. Per #20, #1 closes only when **all** close criteria are met: Phase 1 complete, Phase 2 complete (50 single-judged runs), DRI decision committed to `decision-<date>.md`, and README + stats output updated to reflect the decision.
- ❌ Does not calibrate the catch=false / false-positive arm. All 5 formal Phase 1 judgments returned `NET_NEW_CATCH=true`.
- ❌ Does not claim statistical confidence at n=5. This is shape-of-disagreement, not band measurement.
- ❌ Does not certify the Phase 1 rows as a clean baseline. 4 of 5 rows have known calibration limitations (contamination, empty synthesis, self-review). Phase 2 should not pool naively against these rows.

## Honest summary of Phase 1's quality

> Phase 1 ran with four structural caveats: (a) 3 of 5 Claude judge-a calls were contaminated by in-session context, (b) 4 of 5 rooms had no synthesis block, muting the rubric's dissent-erasure arm, (c) Phase 1 was all-cross-family (Claude judge-a vs Gemini judge-b) with zero same-family and zero 3rd-family data, and (d) all 5 formal judgments returned `NET_NEW_CATCH=true`, so the catch=false / false-positive arm is uncalibrated. The 5/5 agreement rate is therefore an **upper bound on Claude/Gemini cross-family agreement for positive examples**, not a calibrated prior for the full Phase 2 space. The most informative single observation is the disagreement between LLM in-session Claude judges and fresh-chat Claude judges on `council-cache-prd` (verdicts flipped from false to true) — directly demonstrating that judge-context matters and supporting the fresh-chat protocol. Phase 2 should front-load same-family, 3rd-family, and naturally low-signal/negative rooms before pooling. — @Zhachory1, 2026-06-16

## Sign-off

- **Operator (DRI):** @Zhachory1
- **Date Phase 1 completed:** 2026-06-16
- **Phase 2 start commit:** TBD (when Phase 2 begins, link the first Phase 2 judge call's commit here)
- **Closes:** #48
- **Does not close:** #1 (per #20 close criteria: Phase 1 + Phase 2 + DRI decision + README/stats update)
- **Related issues filed during Phase 1:** #57 (empty-synthesis warning, closed by #59), #60 (`stats` Phase 1 counter uses row count instead of distinct rooms; not blocking), #54/#55/#56 (concurrent /council outputs, separate work)
