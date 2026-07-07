# Persona index

Each `agents/<name>.md` is a self-contained system prompt — one judgment lens. Pick **3–6** per
council (Rev 3: was 2–4; raised); **cap 6**. **Default-3 auto-include (Rev 5):** in `--mode ship`
and in the no-flag default, the orchestrator auto-includes `red-team`, `mvp`, and `occams-razor`
unless the operator explicitly opts out. In `--mode research`, `--mode domain`, `--mode exec`, and
`--mode minimal`, default-3 is not automatic; choose by task and coverage.

> ⚠ **Overlap matters more at higher persona counts.** Personas in the same group often raise
> similar issues, which inflates false-consensus pressure. The `Tends to agree with` column
> flags pairs whose lenses partially overlap — picking both is fine if intentional, but you're not
> getting two independent reads. **At 5–6 personas, the overlap check is MANDATORY**: with 6
> picks from a 17-persona catalog, the probability that 2+ picks are flagged-overlap pairs is
> high. Either swap orthogonal OR explicitly justify the doubled weight.

## Promotion policy

The original Core Six remain the highest-confidence baseline. Personas added in 2026-06 start as
`experimental`; promote after **≥3 real journaled runs with `acted_on=true`**. Promotion means the
frontmatter description no longer carries `[experimental]` and selection UIs may treat the persona
as a normal routing option. It does **not** mean external validation: most evidence is still
operator-run dogfood unless a non-author operator used the persona on their own artifact.

## Core six (original lens-fleet, n≥18 validation runs)

| Persona | Lens | Picks up | Tends to agree with |
|---|---|---|---|
| `ml-scientist` | Skeptical ML researcher | calibration, train/serve skew, leakage, metric choice, drift | `ab-critic` (both distrust offline wins) |
| `ab-critic` | Experiment statistician | power/MDE, peeking, SUTVA, holdout hygiene | `ml-scientist` |
| `reliability-sentinel` | SRE | blast radius, rollback, SLO/latency, fallback, hot-path risk | `perf-engineer` (both watch the serving path) |
| `software-architect` | Boundaries-first | coupling, bounded contexts, evolvability, contracts, build-vs-buy | `cto` (both judge tech selection; near-term vs long-term) |
| `generalist-swe` | Pragmatic IC | simplicity, over-engineering, correctness, edge cases, test gaps | — (broadly orthogonal) |
| `red-team` | Adversary, attacks the artifact | strongest case against, hand-waved assumptions, what breaks first | `pre-mortem` (both adversarial, **methods differ**) |

## Promoted dogfood-validated personas (≥3 acted-on real runs)

| Persona | Group | Lens | Picks up | Tends to agree with |
|---|---|---|---|---|
| `data-engineer` | domain | Pipelines-first | idempotency, schema evolution, lineage, backfills, late data | `software-architect` on contracts |
| `perf-engineer` | domain | Tail-latency-first | p99, allocation pressure, algorithmic complexity, caching, I/O patterns | `reliability-sentinel` |
| `product-pm` | domain | User-value-first | problem clarity, scope, outcome-vs-output, adoption story, reversibility | `ceo` (both ask "should we build this") |
| `cost-finops` | domain | Unit-economics-first | $/req, capacity, vendor lock, hidden costs, build-vs-buy TCO | `cto` on platform bets |
| `docs-dx` | domain | Developer-experience-first | API ergonomics, error messages, onboarding friction, examples | — (broadly orthogonal) |
| `mvp` | adversarial complement | **Aggressive** smallest-real-signal advocate; cuts SCOPE | scope creep, polish-creep, severity inflation across review rounds, two-way-door reversibility, acceptance bloat | `occams-razor` (same direction, different axis — see note below) |
| `occams-razor` | adversarial complement | **Aggressive** complexity-cutter; cuts COMPLEXITY | premature abstraction, speculative flexibility, indirection without payoff, layering for its own sake, "while we're here" refactors, framework-itis, rule-of-three violations | `mvp`; `generalist-swe` (overlapping — occams is over-engineering-FIRST) |
| `cto` | executive | 3–5 year platform/tech arc | strategic fit, stack coherence, migration asymmetry, talent/hire, one-way doors | `software-architect` (same domain, near-vs-far horizon) |
| `ceo` | executive | Strategy and narrative | why-this-why-now, opportunity cost, differentiation, brand, first-customer | `product-pm` |
| `vp-eng` | executive | Capacity and execution | who actually does this, sequencing, hiring-assumption risk, opportunity cost | `product-pm` on scope |

Promotion evidence from official local journal audits:

| Persona | Total runs | `acted_on=true` runs | Note |
|---|---:|---:|---|
| `mvp` | 21 | 13 | Strong dogfood signal, but many uses came from default-3 auto-include. |
| `occams-razor` | 21 | 13 | Strong dogfood signal, but many uses came from default-3 auto-include. |
| `docs-dx` | 18 | 10 | Strongest promoted domain signal. |
| `product-pm` | 9 | 6 | Enough acted-on product/scope catches to drop experimental warning. |
| `data-engineer` | 3 | 3 | Barely met threshold; keep watching noise rate. |
| `perf-engineer` | 6 | 4 | Earned promotion through serving-path and high-scale research councils. |
| `cost-finops` | 3 | 3 | Earned promotion through C-suite/FinOps stress-test councils; keep gathering non-research runs. |
| `cto` | 3 | 3 | Earned promotion through platform-bet stress-test councils; keep gathering non-research runs. |
| `ceo` | 3 | 3 | Earned promotion through strategy/market-entry stress-test councils; keep gathering non-research runs. |
| `vp-eng` | 3 | 3 | Earned promotion through execution/capacity stress-test councils; keep gathering non-research runs. |

## Still experimental

| Persona | Group | Lens | Picks up | Tends to agree with |
|---|---|---|---|---|
| `pre-mortem` *(experimental)* | adversarial complement | Reasons backward from imagined catastrophe | no-owner failure modes, slow-motion disasters, recovery story, one-way doors | `red-team` (both adversarial, **methods differ**) |

## Pairing notes

`red-team` vs `pre-mortem`: red-team attacks the artifact as written. Pre-mortem assumes it
shipped and failed, then reasons backward. They are genuinely orthogonal methods — picking both
is reasonable for high-stakes ships, but it doubles the adversarial weight in a 4-persona set.

`mvp` vs `red-team`/`pre-mortem`: deliberately oppositional. red-team and pre-mortem expand
scope by finding risks; mvp contracts scope by cutting non-blocking items. Picking mvp WITH
either of them is recommended for any decision that's been through 2+ review rounds — the
reflection debate between "add more rigor" and "cut for speed" is the point. mvp will not
attack genuine BLOCKERs (it stays in its lane on severity-inflation and scope-bloat); it does
attack ROUND-N-escalation where Rev 3's BLOCKER was Rev 2's MAJOR that drifted up.

`occams-razor` vs `software-architect`: deliberately oppositional. software-architect adds
boundaries, interfaces, and contracts for evolvability; occams-razor demands the third caller
exist before any abstraction lands (rule of three). Picking both is recommended whenever a
design doc or PR introduces new abstractions — the reflection debate between "this seam buys
us X" and "inline it until X actually exists" is the point. occams-razor will not attack
abstractions that already have ≥3 callers (rule already fired) and will not deny real failure
modes that complexity exists to prevent — it demands the simplest fix that still prevents them.

`mvp` + `occams-razor` together: the **double-edge bloat attack**. mvp cuts SCOPE (acceptance
items, requirements, what to build); occams cuts COMPLEXITY (layers, abstractions, how it's
built). They are NOT redundant — a tight-scope MVP can still be over-engineered, and a
simply-built solution can still have scope creep. Pick both whenever a recent PR / design /
proposal feels "gigantic for no reason." Both have aggressive defaults (skew BLOCK), so
picking both alongside `red-team` or `pre-mortem` produces a real fight in reflection rounds:
two cut-it voices vs. two find-more-risk voices, with `software-architect` or `generalist-swe`
often holding the middle.

## Decision tree

```
Reviewing CODE (diff, PR, serving path):
  default-fast change          → generalist-swe + reliability-sentinel
  latency / hot path           → perf-engineer + reliability-sentinel + generalist-swe
  refactor / code quality      → generalist-swe + software-architect
  SDK / public API / CLI       → docs-dx + software-architect + generalist-swe
  ETL / schema / pipeline      → data-engineer + reliability-sentinel + software-architect
  new abstraction / new layer / new framework / diff-bigger-than-the-change → occams-razor + software-architect + generalist-swe
  "this feels gigantic for the change" / bloated PR / over-engineered  → mvp + occams-razor + generalist-swe

Reviewing a MODEL or EXPERIMENT:
  model change / pipeline      → ml-scientist + ab-critic + reliability-sentinel
  A/B readout / holdout        → ab-critic + ml-scientist  (consider --mode domain or --no-default-3 if purely statistical)

Reviewing a DESIGN or DECISION:
  design doc / architecture    → software-architect + red-team + generalist-swe
  build-vs-buy / vendor / cost → cost-finops + software-architect + cto
  platform bet / 3-5yr stack   → cto + software-architect + ceo
  PRD / scope / "should we"    → product-pm + ceo + red-team
  multi-team capacity / staffing → vp-eng + software-architect + product-pm
  high-stakes ship / one-way door → pre-mortem + red-team + reliability-sentinel

Investigations (hypothesis generation, postmortems, audits):
  use --mode research; pick 3-4 by signal and prefer underused relevant lenses.
```

## Selection rules (`skills/council/SKILL.md` Step 2)

The orchestrator's selection table maps task signals → personas. This file is the *catalog*; the
selection table is the *routing*. When the table picks 4, eyeball the `Tends to agree with`
column — if 2 of the 4 are flagged as same-group, swap one for an orthogonal pick.
