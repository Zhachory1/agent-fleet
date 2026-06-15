# Overlay (devtools / developer-facing products — example starter)

# ⚠ THREAT MODEL — this file is loaded VERBATIM into every persona's system prompt.
# Read it end-to-end before installing. Run `lib/overlay.sh show|lint` to inspect.
# Treat any overlay as code you are running, not data.

# Starter preset for companies whose product is developer-facing: SDKs, CLIs, APIs, IDE
# extensions, dev infrastructure platforms. Especially relevant to docs-dx, software-architect,
# product-pm personas — devtools live or die on API ergonomics and onboarding friction.

When reviewing, apply devtools domain specifics:

- **Headline KPIs / metrics**: API adoption (workspaces with N+ API calls / month);
  time-to-first-success for new accounts; SDK install / first-API-call funnel; weekly active
  developers; expansion within an account (workspaces / projects / repos using the product);
  support-ticket-per-MAU as an inverse signal of DX quality.
- **Proxy-vs-real metrics**: GitHub stars are NOT adoption; documentation page views are NOT
  understanding; "completed onboarding" is NOT first real success; SDK download count is NOT
  active usage. Reviewers should challenge any claim that conflates surface-level metrics with
  real outcomes.
- **API design failure modes**: breaking changes ship even when they shouldn't (header renames,
  endpoint path drift, response-field semantics that subtly change); deprecation cycles that
  don't actually deprecate (the old endpoint stays "available" for years); SDK versions that
  ship dependencies the customer's project also ships at a different version.
- **Versioning is a real product**: the version-bump policy (semver vs date-based vs explicit),
  the deprecation cycle length, the deprecation-warning surface, dual-running periods, codemods
  for migrations — all of these are part of the product, not an afterthought.
- **Documentation as integration test**: code examples in docs SHOULD pass CI; a doc-example
  that no longer runs is a regression as much as a failing unit test; the time from "API
  changes" to "doc example is updated" is a measurable quality signal.
- **Error-message surface is product surface**: the moment a developer hits an unexpected error,
  the error message is doing the job of the docs, the support team, and the product manager all
  at once. Reviewers should treat error-message quality as a first-class concern.
- **Stack**: public-facing API gateways with rate limiting; SDKs published to per-language package
  managers (npm / PyPI / crates.io / Maven Central / RubyGems); documentation as code (often via
  Docusaurus / mkdocs / Astro); developer dashboards for usage / billing / API keys.
- **Hot paths**: authentication flow (key generation + revocation); main API endpoints under
  load (latency budget set by the customer's own latency budget); webhook delivery (retry,
  signature validation, idempotency); SDK exception → root-cause-traceable error.
- **Reversibility / one-way doors**: API contracts (especially after SDKs ship them); pricing
  models (developer trust is fragile); deprecation timelines that have been committed publicly;
  open-source library APIs once they have non-trivial adoption.
- **Common review failures**: API designs that optimize for the implementer ("makes our backend
  simpler") at the cost of the integrator ("3 round-trips and 2 retries to do the obvious
  thing"); SDK changes shipped without considering the customer's existing version pinning;
  documentation that explains the well-named path but skips the gotchas; rate-limit policies
  that don't surface a clear retry-with-backoff-N-seconds hint.
- **Current priorities / projects**: REPLACE THIS with your team's named initiatives.

# NOTE: this is a public starter. Your private _overlay.md is the place for internal version
# numbers, planned-but-unannounced deprecations, and customer-specific integration patterns.
