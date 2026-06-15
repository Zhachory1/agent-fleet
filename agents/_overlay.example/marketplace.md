# Overlay (two-sided marketplace — example starter; copy to _overlay.md and customize)

# ⚠ THREAT MODEL — this file is loaded VERBATIM into every persona's system prompt.
# Read it end-to-end before installing. Run `lib/overlay.sh show|lint` to inspect.
# Treat any overlay as code you are running, not data.

# Starter preset for two-sided marketplaces (ride-share, food delivery, freelancer platforms,
# rental marketplaces, etc.). Especially relevant to ab-critic, product-pm, ml-scientist
# personas — marketplaces have unique experiment caveats and growth-loop dynamics.

When reviewing, apply marketplace domain specifics:

- **Headline KPIs / metrics**: gross merchandise value (GMV), take rate, liquidity (time-to-fill
  for the supply-constrained side / search-to-conversion for demand), supply utilization, demand
  conversion, repeat-rate by cohort, NPS / satisfaction by both sides separately. The two sides
  have different KPIs and frequently competing optimizations.
- **Proxy-vs-real metrics**: GMV growth that comes purely from price increases is NOT the same
  as transaction-volume growth; high liquidity does NOT mean balanced supply/demand (it can
  mean both sides are growing in lockstep, which masks shortage); search-to-conversion improves
  if you SHOW LESS CHOICE (filter aggressively); that's not a real product win.
- **Experiment caveats — the big one**: SUTVA violations via supply contention. If treatment-
  group demand consumes shared supply, control-group demand is affected. Geo-splits (different
  cities in different arms), time-splits (different days of the week / hour), supply-side splits
  (random subset of providers gets the treatment) each have their own biases. Long-tail supply
  with low transaction counts hides variance. Network effects make causal inference hard:
  treating one side changes the other side's behavior, which feeds back.
- **Growth-loop dynamics**: more supply attracts more demand; more demand attracts more supply;
  reviewers should ask which side of the loop is supply-constrained vs demand-constrained NOW
  (not the historical pattern). Subsidies on one side leak to the other through pricing.
- **Trust / safety**: rating systems with low base rates; review fraud (mutual high-ratings);
  bad-actor detection; the moment a marketplace loses trust on either side is hard to recover
  from.
- **Stack**: matching engines (often real-time on the demand side, batch on the supply side);
  pricing services; trust-and-safety pipelines; payment integration (often handled by a separate
  team — see fintech overlay); growth / referral pipelines.
- **Hot paths**: search / matching (latency + relevance); pricing under contention; checkout /
  booking; messaging between sides; review pipeline.
- **Reversibility / one-way doors**: take-rate changes (provider-side trust if increased,
  customer-side trust if decreased); rating-system reset; matching-algorithm changes during a
  high-traffic period (re-pricing in flight); brand-affecting trust-and-safety decisions.
- **Common review failures**: A/B comparison that doesn't account for supply contention; growth
  claims without separating new vs returning users; pricing experiments with no demand
  elasticity baseline; "user happiness" metrics that double-count when both sides rate each
  other.
- **Current priorities / projects**: REPLACE THIS with your team's named initiatives.

# NOTE: this is a public starter. Keep your private _overlay.md free of buyer / seller / provider
# identifiers, real pricing, or anything that would identify a specific actor on the platform.
