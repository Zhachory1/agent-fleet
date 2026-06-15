# Persona index

Each `agents/<name>.md` is a self-contained system prompt — one judgment lens. Pick **2–4** per
council; **cap 4**. When `iterations>1`, the orchestrator force-includes `red-team`.

> ⚠ **Overlap matters.** Personas in the same group often raise similar issues, which inflates
> false-consensus pressure. When the selection table suggests 4 personas, prefer ones from
> **different groups**. The `Tends to agree with` column flags pairs whose lenses partially
> overlap — picking both is fine if intentional, but you're not getting two independent reads.

## Core six (the original lens-fleet, n≥18 validation runs)

| Persona | Lens | Picks up | Tends to agree with |
|---|---|---|---|
| `ml-scientist` | Skeptical ML researcher | calibration, train/serve skew, leakage, metric choice, drift | `ab-critic` (both distrust offline wins) |
| `ab-critic` | Experiment statistician | power/MDE, peeking, SUTVA, holdout hygiene | `ml-scientist` |
| `reliability-sentinel` | SRE | blast radius, rollback, SLO/latency, fallback, hot-path risk | `perf-engineer` (both watch the serving path) |
| `software-architect` | Boundaries-first | coupling, bounded contexts, evolvability, contracts, build-vs-buy | `cto` (both judge tech selection; near-term vs long-term) |
| `generalist-swe` | Pragmatic IC | simplicity, over-engineering, correctness, edge cases, test gaps | — (broadly orthogonal) |
| `red-team` | Adversary, attacks the artifact | strongest case against, hand-waved assumptions, what breaks first | `pre-mortem` (both adversarial, **methods differ**) |

## Domain specialists (experimental — added 2026-06; ≥1 real run before promoting)

| Persona | Lens | Picks up | Tends to agree with |
|---|---|---|---|
| `data-engineer` *(experimental)* | Pipelines-first | idempotency, schema evolution, lineage, backfills, late data | `software-architect` on contracts |
| `perf-engineer` *(experimental)* | Tail-latency-first | p99, allocation pressure, algorithmic complexity, caching, I/O patterns | `reliability-sentinel` |
| `product-pm` *(experimental)* | User-value-first | problem clarity, scope, outcome-vs-output, adoption story, reversibility | `ceo` (both ask "should we build this") |
| `cost-finops` *(experimental)* | Unit-economics-first | $/req, capacity, vendor lock, hidden costs, build-vs-buy TCO | `cto` on platform bets |
| `docs-dx` *(experimental)* | Developer-experience-first | API ergonomics, error messages, onboarding friction, examples | — (broadly orthogonal) |

## Adversarial complement (experimental)

| Persona | Lens | Picks up | Tends to agree with | Deliberately opposes |
|---|---|---|---|---|
| `pre-mortem` *(experimental)* | Reasons backward from imagined catastrophe | no-owner failure modes, slow-motion disasters, recovery story, one-way doors | `red-team` (both adversarial, **methods differ**) | — |
| `mvp` *(experimental)* | Smallest-real-signal advocate; pushes for cuts | scope creep, polish-creep, severity inflation across review rounds, two-way-door reversibility | — | **`red-team`** and **`pre-mortem`** (oppositional by design — they find more, mvp cuts; pick both for high-stakes decisions where the reflection round is the point) |

> `red-team` vs `pre-mortem`: red-team attacks the artifact as written. Pre-mortem assumes it
> shipped and failed, then reasons backward. They are genuinely orthogonal methods — picking both
> is reasonable for high-stakes ships, but it doubles the adversarial weight in a 4-persona set.
>
> `mvp` vs `red-team`/`pre-mortem`: deliberately oppositional. red-team and pre-mortem expand
> scope by finding risks; mvp contracts scope by cutting non-blocking items. Picking mvp WITH
> either of them is recommended for any decision that's been through 2+ review rounds — the
> reflection debate between "add more rigor" and "cut for speed" is the point. mvp will not
> attack genuine BLOCKERs (it stays in its lane on severity-inflation and scope-bloat); it does
> attack ROUND-N-escalation where Rev 3's BLOCKER was Rev 2's MAJOR that drifted up.

## Executive (experimental — zero validation runs)

| Persona | Lens | Picks up | Tends to agree with |
|---|---|---|---|
| `cto` *(experimental)* | 3–5 year platform/tech arc | strategic fit, stack coherence, migration asymmetry, talent/hire, one-way doors | `software-architect` (same domain, near-vs-far horizon) |
| `ceo` *(experimental)* | Strategy and narrative | why-this-why-now, opportunity cost, differentiation, brand, first-customer | `product-pm` |
| `vp-eng` *(experimental)* | Capacity and execution | who actually does this, sequencing, hiring-assumption risk, opportunity cost | `product-pm` on scope |

## Decision tree

```
Reviewing CODE (diff, PR, serving path):
  default-fast change          → generalist-swe + reliability-sentinel
  latency / hot path           → perf-engineer + reliability-sentinel + generalist-swe
  refactor / code quality      → generalist-swe + software-architect
  SDK / public API / CLI       → docs-dx + software-architect + generalist-swe
  ETL / schema / pipeline      → data-engineer + reliability-sentinel + software-architect

Reviewing a MODEL or EXPERIMENT:
  model change / pipeline      → ml-scientist + ab-critic + reliability-sentinel
  A/B readout / holdout        → ab-critic + ml-scientist (+ red-team if launch-decision)

Reviewing a DESIGN or DECISION:
  design doc / architecture    → software-architect + red-team + generalist-swe
  build-vs-buy / vendor / cost → cost-finops + software-architect + cto
  platform bet / 3-5yr stack   → cto + software-architect + ceo
  PRD / scope / "should we"    → product-pm + ceo + red-team
  multi-team capacity / staffing → vp-eng + software-architect + product-pm
  high-stakes ship / one-way door → pre-mortem + red-team + reliability-sentinel

Investigations (hypothesis generation, postmortems, audits):
  pick 3-4 by signal; investigations are not gated on acted-on rate.
```

## Why "experimental"

The 10 personas tagged `(experimental)` were added together in one session in 2026-06. They have
zero validation runs at time of writing — we do not yet know whether their findings are net-new vs
the Core Six, or whether they cost more in noise than they earn in signal. Promote a persona to
`Core` after **≥3 real runs** logged in the journal with `acted_on=true` (or, for `pre-mortem`,
catches that an equivalent `red-team`-only run would have missed).

## Selection rules (`skills/council/SKILL.md` Step 2)

The orchestrator's selection table maps task signals → personas. This file is the *catalog*; the
selection table is the *routing*. When the table picks 4, eyeball the `Tends to agree with`
column — if 2 of the 4 are flagged as same-group, swap one for an orthogonal pick.
