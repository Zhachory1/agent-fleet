# Overlay (ML platform — example starter; copy to _overlay.md and customize)

# ⚠ THREAT MODEL — this file is loaded VERBATIM into every persona's system prompt.
# Read it end-to-end before installing. Run `lib/overlay.sh show|lint` to inspect.
# Treat any overlay as code you are running, not data.

# Starter preset for ML platform / applied-ML organizations. Replace specifics with YOUR org's
# reality before installing as agents/_overlay.md. Especially relevant to ml-scientist,
# ab-critic, reliability-sentinel, data-engineer personas.

When reviewing, apply ML-platform domain specifics:

- **Headline KPIs / metrics**: prediction-quality metrics chosen for the actual business
  objective (calibration error / log-loss / NLL rather than only AUC when the business cares
  about probability); offline metric → online metric correlation (or lack thereof); feature
  freshness; serving latency p50/p95/p99; training-pipeline SLA; data quality drift; model-vs-
  baseline lift (NOT model-vs-previous-version; baseline is the honest comparison).
- **Proxy-vs-real metrics**: ranking metrics (AUC, NDCG) often miss calibration regressions;
  offline wins frequently fail online due to distribution shift; "best-in-eval-window" is the
  baseline to beat AND a known cherry-picking source.
- **Experiment caveats**: train/serve skew is the default failure mode; point-in-time correctness
  of features is the most common silent bug; labeling delay vs metric definition affects offline
  evaluation honesty; covariate shift between eval-window and serving traffic; SUTVA violations
  in ranked systems (one user's exposure changes another's distribution); peeking on long-running
  experiments.
- **Data quality**: schema evolution (nullable adds, drops, renames) breaks downstream silently;
  partition watermarks vs event-time vs processing-time confusion; backfill correctness under
  late-arriving data; idempotency of training jobs (replays must converge).
- **Stack**: training in Python (PyTorch / JAX / TensorFlow); orchestration in Airflow / KFP /
  Argo / Prefect / SageMaker; feature stores (Feast / Tecton / homegrown); model registry; online
  serving via Triton / TorchServe / a custom path; warehouses for offline metrics; metric stores.
- **Hot paths**: online inference (latency + blast radius); feature lookups (freshness +
  cardinality); fallback paths when the model service is down (default-to-previous, default-to-
  null, never default-to-error); shadow-mode evaluation BEFORE replacing the production model.
- **Reversibility / one-way doors**: training data acquisition (irreversible once labels stale);
  feature-set changes (cascade through retraining + downstream); model retraining frequency
  commitments; customer-facing prediction APIs.
- **Common review failures**: claiming offline win without naming the held-out vs validation
  split; ignoring calibration when the business uses probability for decisioning; ranking
  improvements with no business-metric tie-in; A/B with insufficient power because the model
  effect is small but real; "the model just learned the holiday" (drift the experiment didn't
  control for).
- **Current priorities / projects**: REPLACE THIS with your team's named ML projects right now
  — the personas use this to ask "is this consistent with where the team is going?"

# NOTE: this is a public starter. Keep your private _overlay.md free of customer identifiers,
# proprietary model architectures, and labeled training-data examples.
