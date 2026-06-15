# Solo decision (before the council)

**Operator's pre-council answer:** SHIP-WITH-CHANGES.

**My reasoning:** The PRD is mostly good. The express path skips validators only for the safe
segment (returning customers with prior orders). The kill-switch gives us a 30s out if anything
goes wrong. Latency win is real (120ms × 85% of requests).

## Risks I already see

1. **Validator drift over time.** Six months from now, someone adds a new fraud check to the
   "new accounts only" group thinking it only affects new accounts. If that new check ALSO
   matters for returning customers, the express path silently skips it. Mitigation: code review
   discipline + a comment at the bypass site naming what's skipped.

2. **Customer-record lookup latency.** The pre-check itself reads the customer record. If that
   read is slow, we trade 120ms of validator work for ~50ms of database round-trip. Mitigation:
   the next proposal (out of scope here) caches customer lookups; until then, accept the modest
   overhead.

3. **Metric drift.** `checkout_express_path_ratio` is the only new metric. If it climbs above
   the expected ~85%, that's a signal something changed in the customer base.

## What I want from the council

Push on the rollout plan and the failure modes I might be missing. Particularly: is the kill-switch
actually a kill-switch (does it instantly revert in-flight requests, or only new ones?), and what
does the A/B comparison actually compare (per-customer? per-request? am I controlling for
customer mix?).
