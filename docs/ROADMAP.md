# Roadmap

**Status:** active work list. Historical build plans stay in `docs/PLAN.md` and feature `PLAN.md` files.

## Now

1. Finish blinded-judge Phase 2.
   - Goal: ≥50 distinct judged rooms for issue #1.
   - Source of truth: `bash lib/journal.sh stats`, not static docs.
   - Use `bash lib/blind-judge.sh candidates`.
   - Prefer synthesis-bearing rooms, varied outcomes, low-signal / likely `catch=false`, same-family / GPT coverage.
   - Close with `docs/features/blinded-judge/decision-<date>.md`.

2. Grow lens-baseline arm.
   - Source of truth: `bash lib/journal.sh stats`.
   - Gate: n≥10 before stronger README claim.
   - Keep same-lens single-pass baseline separate from council result.

3. Run operator self-test.
   - Tracker: `docs/external-users/operator-self-test.md`.
   - Need 3 real councils: code, design, investigation.
   - Outcome: onboarding friction + artifact quality notes.

## Next

4. Recruit non-author operator.
   - Same self-test, their own artifact.
   - Do not count as broad external validation; count as first non-author signal.

5. Publish Phase 2 decision.
   - Needs ≥50 rooms first.
   - Include agreement band, KPI call, caveats, and links to stats.
   - Update README metrics after decision doc lands.

## Later

6. Clean low-priority CI debt.
   - Shellcheck warning gate already enforced.
   - Info-level cleanup only when touching nearby code.

7. Refresh archived design docs only when misleading.
   - Keep historical PRD/DD/PLAN intent intact.
   - Add status notes instead of rewriting old implementation history.
