# Blinded-judge Phase 1 calibration

> Template. Copy to `calibration-phase1.md` when ready, fill in, link from issue #20.
> Per PRD-Rev-3 + DD §--phase1: this is the qualitative shape-of-disagreement readout from the first 5 dual-judged councils. NOT the quantitative band decision — that's Phase 2 + DRI-decision-`<date>`.md.

## Sample

5 distinct councils, dual-judged (10 judge calls total).

| # | Room | judge-a family | judge-b family | Pair |
|---|---|---|---|---|
| 1 | `council-...` | | | same/cross |
| 2 | `council-...` | | | same/cross |
| 3 | `council-...` | | | same/cross |
| 4 | `council-...` | | | same/cross |
| 5 | `council-...` | | | same/cross |

Per PRD-OQ8 target: 3 same-family + 2 cross-family.

## Disagreement count and shape

| # | Room | judge-a verdict | judge-b verdict | Agree? | Disagreement summary (one line) |
|---|---|---|---|---|---|
| 1 | | catch=t/f | catch=t/f | y/n | "A flagged evidence quote X; B said synthesis was too thin to judge" |
| ... | | | | | |

Disagreements: `N/5`. Same-family agreement: `M/3`. Cross-family agreement: `K/2`.

## Concentration analysis

Where do disagreements cluster?

- [ ] By artifact length (long synthesis vs short)
- [ ] By synthesis quality (empty `OPERATOR_SYNTHESIS` field; the rubric is rubric-robust but disagreement may spike when the operator under-documents)
- [ ] By specific persona being quoted (red-team findings hard to score vs ml-scientist findings)
- [ ] By issue severity (BLOCKER findings agree more than MINOR)
- [ ] By run-kind (code vs design vs investigation — investigations may genuinely have no "net-new catch" answer)

Write one paragraph naming the dominant pattern. If "no pattern detected at n=5," write that — under-powered is honest.

## Same-family vs cross-family observation

Did same-family judges agree more than cross-family? By how much?

- Same-family agreement rate: `M/3 = ...%`
- Cross-family agreement rate: `K/2 = ...%`
- Difference: ... percentage points

**Honest caveat**: n=3 vs n=2 is not statistical evidence. This is qualitative observation only. The Phase 2 quantitative bands sit on n≥50, not n=5.

## Implications for Phase 2

One paragraph naming:

1. The expected band the agreement rate likely falls into (90%+ / 70-90% / <70%).
2. Any rubric-version-bump candidates above that should ship before Phase 2 starts.
3. Whether Phase 2 should front-load same-family or cross-family runs to characterize the band faster.

## What this writeup does NOT do

- Doesn't switch the canonical KPI from self-report to blinded. That's the DRI's Phase-2 decision.
- Doesn't close issue #1. Phase 2 + DRI-decision-`<date>`.md closes #1.
- Doesn't claim statistical confidence at n=5. This is shape-of-disagreement, not band measurement.

## Sign-off

Operator (DRI): @Zhachory1
Date Phase 1 completed:
Phase 2 start commit:
