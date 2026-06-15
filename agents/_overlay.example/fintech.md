# Overlay (fintech — example starter; copy to _overlay.md and customize)

# ⚠ THREAT MODEL — this file is loaded VERBATIM into every persona's system prompt.
# Read it end-to-end before installing. Run `lib/overlay.sh show|lint` to inspect.
# Treat any overlay as code you are running, not data.

# Starter preset for fintech / payments / lending / risk organizations. Especially relevant to
# reliability-sentinel, software-architect, red-team personas — fintech failure modes are
# typically operational and regulatory rather than algorithmic.

When reviewing, apply fintech domain specifics:

- **Headline KPIs / metrics**: payment success rate, auth-to-capture conversion, charge-back
  rate, fraud rate by segment, false-positive rate of risk models (legitimate-customer denials),
  approval rate by issuer / network, settlement timeliness, reconciliation match rate, treasury
  exposure, regulatory-reporting completeness.
- **Proxy-vs-real metrics**: approval rate is NOT customer happiness (a too-loose model approves
  fraud); fraud catch-rate is NOT net financial impact (the false-positive cost can dwarf the
  catch); 30-day delinquency is NOT lifetime loss.
- **Idempotency is non-negotiable**: every payment-side write operation has an idempotency key;
  retries are the default behavior of any network call in this stack; double-charges are the
  canonical "you definitely got this wrong" outcome; idempotency windows have to outlive the
  worst-case retry storm.
- **Latency budgets**: card-not-present authorization typically has a network budget of ~3s
  end-to-end; rejected payments at the issuer (vs declined at the platform) have different
  customer-facing UX implications; queued / asynchronous payment paths introduce reconciliation
  surface.
- **Dispute paths**: charge-back lifecycle (representment, second presentment, arbitration);
  evidence collection windows; the moment funds actually become irreversible at the
  acquirer/network level.
- **Stack**: payment processors and gateways (Stripe / Adyen / Braintree / direct issuer
  connections); ledger systems for the source-of-truth balance; reconciliation pipelines;
  KYC/AML providers; risk-scoring services (often in real-time); regulatory reporting pipelines.
- **Hot paths**: payment authorization; balance read for spend authorization; risk-scoring call
  during checkout; settlement file generation; reconciliation job that reads the day's batch.
- **Reversibility / one-way doors**: anything that touches the ledger; customer fund movements;
  KYC decisions (legal record); regulatory submissions; refund logic on the irreversible window.
- **Regulatory constraints**: PCI scope (cardholder data); KYC/AML record retention (often
  years); regional licensing (state-by-state in US; cross-border for EU/UK/APAC); audit trail
  requirements that affect what can be logged and what cannot.
- **Common review failures**: idempotency-key reuse across charge attempts; risk-model
  improvement claims without false-positive-cost quantification; ledger-as-cache antipattern;
  dispute logic that handles the happy path but not partial-state failure; latency improvement
  that adds reconciliation surface.
- **Current priorities / projects**: REPLACE THIS with your team's named initiatives.

# NOTE: this is a public starter. Your private _overlay.md MUST be free of customer / merchant
# identifiers, real account numbers, real transaction amounts, or any regulated PII.
