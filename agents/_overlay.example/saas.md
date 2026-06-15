# Overlay (SaaS — example starter; copy to _overlay.md and customize)

# ⚠ THREAT MODEL — this file is loaded VERBATIM into every persona's system prompt.
# Read it end-to-end before installing. Run `lib/overlay.sh show|lint` to inspect.
# Treat any overlay as code you are running, not data.

# This is a starter preset for SaaS organizations. Replace specifics with YOUR org's reality
# before installing as agents/_overlay.md.

When reviewing, apply SaaS domain specifics:

- **Headline KPIs / metrics**: MAU, WAU, NPS, retention by cohort (D1/D7/D30), gross-revenue
  retention (GRR), net-revenue retention (NRR), monthly recurring revenue (MRR), churn (logo +
  revenue), expansion vs new vs churn breakdown, activation rate, time-to-value.
- **Proxy-vs-real metrics**: feature adoption is NOT engagement; engagement is NOT retention;
  retention is NOT revenue. Reviewers should challenge any claim that conflates them.
- **Experiment caveats**: small-N customer cohorts; pricing experiments need long readouts; B2B
  vs B2C have different significance bars; spillover via customer-to-customer comparisons (in
  shared workspaces) violates SUTVA; admin-impersonation traffic should be filtered from any
  user-level metric.
- **Stack**: typically PostgreSQL (OLTP) + a column store for analytics (Snowflake / BigQuery /
  Redshift); Redis or Memcached for cache; a queue (SQS / RabbitMQ / Sidekiq) for async work;
  observability via Datadog / New Relic / Grafana + Sentry / Bugsnag for errors.
- **Hot paths**: signup / login flow (latency + conversion); billing webhooks (idempotency +
  retry); core CRUD on the primary entity; export/import endpoints under load; multi-tenant
  isolation enforcement.
- **Reversibility / one-way doors**: pricing changes, schema migrations on the primary tenant
  table, customer-facing API contracts (especially when SDKs ship), brand-touching UX changes.
- **Common review failures**: A/B comparison without controlling for customer cohort age;
  signup-flow changes measured only on the post-signup funnel (ignoring the conversion drop);
  webhook reliability assumed without retry-budget specs; feature flags without sunset plans.
- **Current priorities / projects**: REPLACE THIS with the 1-3 named initiatives your team is
  shipping right now — helps the personas calibrate "is this consistent with where the team is
  going?"

# NOTE: this is a public starter. Keep your private _overlay.md free of PII, customer names,
# and confidential identifiers beyond what you need to make the personas useful.
