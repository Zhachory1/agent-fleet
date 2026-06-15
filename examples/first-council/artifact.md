# PRD: Feature flag for `checkout.express_path`

**Status:** Draft
**Owner:** Hypothetical Operator
**Last updated:** 2026-06-15

## Context

Our checkout API has one code path: `checkout()` runs all validators, computes tax, applies
promotions, and writes the order. The path is well-tested but accumulates ~180ms of latency on
the median request. Profiling shows ~120ms is in two validators that only fire for new accounts
(< 24h old). For ~85% of requests (returning customers), those validators are dead-weight.

We want to short-circuit the validators for returning customers. We'll call this the "express
path." A returning customer is one with `account_age_days >= 1` AND at least one prior successful
order.

## Proposal

Add a feature flag `checkout.express_path` (default: off). When on:
- A pre-check at the top of `checkout()` looks at the customer record.
- Returning customers (per the definition above) skip the two new-account validators.
- New customers continue through the full path.

Flag is per-environment (staging, prod-canary, prod-full) and per-customer-segment
(rollout via internal segmentation tool). Kill-switch flips the flag off globally in <30s.

## Why

- Latency improvement: 120ms shaved from ~85% of requests → measurable p50/p95 win.
- New-account fraud check still fires for the population that needs it.
- The two validators are NOT removed — just bypassed for the safe segment.

## Acceptance

- Flag wired into the codebase.
- Metric: `checkout_express_path_ratio` (fraction of requests taking the express path).
- Rollback plan: flip the flag off via internal admin tool.
- A/B comparison after rollout: latency p50/p95 on returning customers, before vs after.
- New-customer error rate must not change (they go through the full path either way).

## Out of scope

- Removing the two validators entirely.
- Changing the definition of "returning customer."
- Caching customer record lookups (separate proposal).
