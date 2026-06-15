# Overlay (adtech — example starter; copy to _overlay.md and customize)

# ⚠ THREAT MODEL — this file is loaded VERBATIM into every persona's system prompt.
# Read it end-to-end before installing. Run `lib/overlay.sh show|lint` to inspect.
# Treat any overlay as code you are running, not data.

# Starter preset for auction-style / programmatic advertising platforms. Especially relevant to
# ml-scientist, ab-critic, reliability-sentinel personas — adtech experiments are infamous for
# SUTVA violations and pacing artifacts.

When reviewing, apply adtech domain specifics:

- **Headline KPIs / metrics**: value-based bidding metrics (advertiser value per impression,
  cost-per-action, return-on-ad-spend, marginal cost-per-incremental-conversion); supply-side
  metrics (impression yield, fill rate, viewability); platform-level metrics (revenue per
  thousand impressions, advertiser ROI, end-user engagement).
- **Proxy-vs-real metrics**: CTR is NOT conversion; conversion-rate is NOT incremental lift;
  last-click attribution is NOT true causal contribution; views-through-conversion is famously
  game-able. Reviewers should challenge any claim that conflates click → conversion → lift.
- **Experiment caveats — the big one**: AUCTION INTERFERENCE / SUTVA VIOLATIONS are the default
  pathology. Traditional A/B (per-user random assignment) is biased whenever the treatment
  changes the auction (which it almost always does). Geo-splits, time-splits, advertiser-splits,
  or paired-budget tests are the typical fixes — each with its own caveats. Holdout hygiene
  (excluding the holdout's signals from training data) is non-trivial in real-time bidding.
  Pacing-budget interactions can make experiments non-stationary day-over-day. Long-tail
  advertisers with low impression counts hide huge variance.
- **Stack**: real-time bidding pipelines (sub-100ms budget); offline training pipelines that
  often run nightly or hourly; feature stores for bidder context; observability that has to
  handle millions of QPS at the request layer; bid-loss reasons emitted as structured logs.
- **Hot paths**: bid request → bid response (latency budget often <100ms end-to-end including
  network); attribution pipelines (correctness + privacy); pacing/budget enforcement; pixel /
  postback handlers; segment join under load.
- **Reversibility / one-way doors**: changes to attribution windows; bidder logic during a
  significant traffic shift; SDK contracts on publisher side; revenue-share with advertiser
  partners.
- **Common review failures**: "we saw a CTR lift offline" without an incrementality test;
  pacing-related artifacts misread as model improvement (the new model pacing differently
  changes WHICH impressions it gets, which biases everything downstream); claims of advertiser
  ROI improvement without disentangling spend shifts from value-per-spend; A/B comparisons that
  don't account for the spillover via shared advertiser budgets.
- **Privacy / regulation**: PII handling in cookie-less / signal-loss environments; ad-fraud
  detection vs ad-quality vs ad-incrementality (three different problems); regional compliance.
- **Current priorities / projects**: REPLACE THIS with your team's named initiatives — value-
  based bidding work, look-alike modeling, attribution improvements, etc.

# NOTE: this is a public starter. Keep your private _overlay.md free of advertiser names,
# publisher names, real bid prices, or any data that would identify a specific buyer/seller.
