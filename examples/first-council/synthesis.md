# Council synthesis — checkout.express_path PRD

**Personas:** reliability-sentinel, software-architect, generalist-swe, red-team (auto-included)
**Iterations:** 2 (default)
**Convergence:** CHANGED → ran to 2 rounds (default cap)
**Consensus flag:** SPLIT (2× BLOCK, 1× SHIP-WITH-CHANGES, 1× SHIP)

## Council verdict: **SPLIT** (lean BLOCK on the mutable-state race)

The split is structural, not noise: reliability-sentinel + red-team converged on BLOCK around a
shared failure mode (mutable customer state mid-checkout, made worse by unclear kill-switch
granularity). software-architect and generalist-swe hold SHIP-with-modifications because the
mitigation (audit-log + reconciliation) is doc-level work, not code-rewriting.

### Ranked issues

| # | Sev | Finding | Raised by | Fix |
|---|---|---|---|---|
| 1 | BLOCKER | "Returning customer" is a MUTABLE label. An admin can revert an account from returning to new (fraud reversal, GDPR deletion) DURING an in-flight checkout. The express path can bypass new-account validators on an account that is now classified as new. | red-team r1, reliability-sentinel r2 (compounded) | Audit-log the customer-state snapshot at pre-check + run a post-hoc reconciliation job that flags mismatches between snapshot and final state. Cost: one log line per checkout, one batch job. Doesn't destroy the latency win. |
| 2 | BLOCKER | Kill-switch granularity unspecified. Flag-read is per-request, per-connection, or per-process? Determines whether a flip interrupts in-flight express-path requests immediately or only new ones. The "<30s" target conflates flag-propagation time with express-path-drain time. | reliability-sentinel r1 | Spec the read granularity in the PRD. Recommend per-request read (~1µs overhead) so a flip interrupts every new validator-bypass decision. |
| 3 | MAJOR | "A/B comparison after rollout" is actually a before/after (longitudinal) comparison, not an A/B. The PRD doesn't specify per-customer vs per-request assignment. | software-architect r1 | Clarify in PRD: per-customer assignment for the headline metric (clean causal claim); per-request for the latency-of-bypass micro-benchmark. |
| 4 | MAJOR | Kill-switch is asserted to work but no test for it exists in the acceptance criteria. | red-team r1 | Add to acceptance: "kill-switch verified by manual flip in staging with 1 RPS of returning-customer traffic; assert express-path requests stop within N seconds." |
| 5 | MINOR | Validator-drift mitigation is process-only (code review + comment). | generalist-swe r1 | Add a unit test that asserts "every validator in the new-accounts-only group MUST be in this list" — adding a validator without updating the list fails CI. |
| 6 | MINOR | `checkout_express_path_ratio` is a ratio; customer-base shifts mask absolute volume changes. | generalist-swe r1 | Also emit a raw count of bypass operations per minute. |
| 7 | MINOR | Coupling: the bypass decision and the new-accounts-only validators live in the same module; future divergence is invisible. | software-architect r1 | Note in code; revisit if a third conditional validator lands. |

### Dissents (preserved, named)

- **red-team — BLOCK:** "The mutable-state race has no detection mechanism in the PRD as written. Audit-log + reconciliation moves it from BLOCK to SHIP-WITH-CHANGES. Without it, the failure mode is silent."
- **generalist-swe — SHIP:** "Probability-weighted, the admin-flips-customer-mid-checkout race fires ~0 times per year. The PRD is shippable as v1 with two low-cost hardening additions (structural-marker test, absolute-count metric)."

### Strongest counterargument to the verdict

The mutable-state race is a real failure mode but the affected window per checkout is tens of
milliseconds. The admin actions that mutate customer state (fraud reversal, GDPR deletion) are
themselves rare and slow. Probability-weighted, the race fires at a rate dominated by overall
checkout volume × admin-action rate × (race-window / checkout-duration), which is small. The
audit-log + reconciliation fix is correct but the urgency could be over-stated.

### One-line recommendation

**SHIP-WITH-CHANGES after audit-log + reconciliation (BLOCKER #1), per-request kill-switch read
(BLOCKER #2), and kill-switch verification test (MAJOR #4) land. Items #3, #5, #6, #7 can ship
in follow-up PRs.**

---

## Net-new vs the operator's solo decision

The operator's solo (`solo-decision.md`) listed 3 risks:
1. Validator drift over time (process-level mitigation noted)
2. Customer-record lookup latency (out-of-scope; deferred to caching proposal)
3. Metric drift (`checkout_express_path_ratio` going above 85%)

**Net-new from the council:**

| Council finding | In solo? | Severity gap |
|---|---|---|
| Mutable-customer-state race during in-flight checkout | NO | BLOCKER (the highest-stakes issue) |
| Kill-switch granularity (per-request vs per-connection vs per-process) | NO | BLOCKER |
| "A/B comparison" is actually before/after | NO | MAJOR |
| Kill-switch asserted but never tested | NO (operator noted kill-switch as a safety mitigation but did not require a verification test) | MAJOR |
| Structural-marker test for validator-drift | The operator named "code review discipline" — the council strengthened to a CI-enforced test | MINOR strengthening |
| Absolute-count metric for bypass operations | NO (solo had ratio only) | MINOR |

**4 BLOCKERs/MAJORs the operator missed entirely.** That is the value-prop of the council: not
just adding more bullet points but surfacing failure modes the solo decision didn't name.

This is the moment in the workflow where the operator goes back to the PRD with the council's
findings in hand and decides which to act on, which to push back on, and which to log as
"considered, declined." The journal entry below captures that.
