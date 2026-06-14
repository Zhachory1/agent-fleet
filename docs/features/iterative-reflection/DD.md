# SEDD — Iterative cross-reflection rounds

**SEDD ID:** 20260612-council-iterative-reflection
**Status:** In progress · **Rev 2** (post council gate #2) · implements PRD Rev 2 · issue #1
**DRI:** Zhach Volker

> **Rev 2 changelog** (gate #2, SPLIT, red-team BLOCK): goal reframed honestly — v1 makes
> sycophancy **observable + bounded, not eliminated** (you cannot fully defeat it in one LLM call;
> red-team's own steelman) · detector strengthened with **issue-count-shrinkage** (deterministic
> substance-degradation proxy, not just verdict flips) · **red-team concession hardened** (must
> cite a specific factual error in its own prior position) · `synth.sh converged` stdin contract
> pinned with a worked example · `#rN` stored raw in JSONL, parsed only in `show` (+ negative test)
> · sync test uses **sentinel tokens** · cap is **absolute** (one-retry via `warned` flag) ·
> SKILL.md update is an explicit task · anti-mush E2E **automated** as a fixture · the stronger
> separate-spawn refute/concede split is named as v2.

---

# Problem & honest scope

Council personas judge blind. Want N reflection rounds where each reads peers + revises. The
hazard (red-team, both gates): reflection creates convergence pressure = sycophancy. **You cannot
eliminate that in a single-context LLM call.** So v1's goal is narrower and honest: make reflection
**happen, be observable, and be bounded** — surface every round in the transcript, detect the
obvious capitulation patterns, harden the dissenter, cap cost. Elimination of sycophancy is a
**non-goal**; the guard metric is *relative* ("no worse false-consensus than 1-round"), and the
KPI is a human-judged sampled review. The truly structural fix (refute and concede in separate
spawns) is **v2** (named in Tech Debt) — too heavy for v1.

# Success Metrics

| Type | Measure | Bar |
|---|---|---|
| Primary | reflection yield (verdict-change, acted-on) | ≥30% of multi-iter runs after ≥10 runs |
| Guard | false-consensus | structural (refute-first) + all-flip WARNING; no increase vs 1-round |
| Functional | convergence-stop + cap deterministic + asserted | NFR4 tests pass |
| Cost | iterations ≤4, personas ≤4, inject prior-round positions only | bounded, no loop |

---

# Design

## Round loop (orchestrator-driven, personas stateless)

```
selected = select(task)                 # + force-include red-team if multi-iter (FR4)
N = clamp(iterations, 1, 4)              # default 2
positions[1] = parallel( spawn(p, blind_prompt) for p in selected )   # iteration 1 = blind
capture(room, positions[1], round=1)

for r in 2..N:
    brief_r = positions[r-1]             # ONLY the immediately-prior round (token bound)
    positions[r] = parallel( spawn(p, reflect_prompt(p, peers=brief_r\p)) for p in selected )
    capture(room, positions[r], round=r)
    # convergence: verdict-only diff vs prior round
    if verdicts(positions[r]) == verdicts(positions[r-1]):
        if all_flipped_to_majority(positions[r-1], positions[r]):
            warn("⚠ converged-this-round — possible sycophancy, NOT treated as clean stop")
            continue                     # do not early-stop on a suspicious flip
        break                            # clean verdict-stable convergence
synthesize(positions[last])
```

* **Stateless:** each spawn fresh; peer context injected via prompt. No live chat (unchanged).
* **Token bound:** round r sees ONLY round r-1's positions (not all prior rounds). ≤4 personas ×
  ≤3 peers × ≤4 rounds — bounded, and convergence-stop usually ends sooner.
* **red-team auto-included** in any multi-iteration run (standing dissent vs convergence pressure).

## Reflection prompt — critique-before-concede (the structural anti-mush lever)

Iteration ≥2 prompt to each persona, AFTER its own prior position + peers' prior positions:

```
You have your prior position and your peers' prior positions. Revise YOURS — but in this ORDER:
1. REFUTE FIRST: for each peer point you disagree with, state the strongest refutation you can.
   You may NOT silently agree. Agreement must be EARNED by failing to refute.
2. CONCEDE: only points you genuinely could not refute — say which peer changed your mind and why.
3. HOLD: points you still believe despite peers — defend them; maintained well-reasoned dissent is
   valued over agreement.
4. Emit your revised POSITION (verdict + top_issues) and a one-line `reflection:` note summarizing
   what changed. If nothing changed, say so plainly.
```

Refute-first ordering forces engagement-then-judgment. **Honest limitation** (red-team gate #2):
it is still one LLM call with no external validator — a model *can* perform a token refutation then
concede. v1 accepts this and makes it observable (every refutation is in the transcript; a human
sees "refuted in r2, conceded in r3"). The separate-spawn split that would make it structural is v2.

**Hardened dissenter** (red-team auto-included in multi-iter runs): `red-team` may **not** move to
CONCEDE unless it cites a *specific factual error in its own prior position*. "A peer changed my
mind" is not sufficient for red-team. This raises its concession bar above cosmetic inclusion.

## `changed` — inferred orchestrator-side (no persona-file change)

Orchestrator computes `changed[p] = verdict(positions[r][p]) != verdict(positions[r-1][p])`.
Deterministic. Persona `.md` files unchanged — they already emit `verdict:`. The free-text
`reflection:` note is transcript-only, not parsed.

## Convergence + mush detector — `synth.sh converged` (pinned contract)

Verdict-stability drives the stop; an issue-count delta drives the substance-degradation guard.
Both are deterministic (counts + string compare, no semantics).

**`lib/synth.sh converged`** — stdin = prev round, a `---` line, curr round. Each line:
`<persona> <verdict> <issue_count>` (issue_count = number of top_issues that persona emitted).
Majority = plurality of verdicts in the curr round.

```
ml-scientist BLOCK 3
ab-critic SHIP-WITH-CHANGES 2
red-team BLOCK 4
---
ml-scientist SHIP-WITH-CHANGES 1
ab-critic SHIP-WITH-CHANGES 2
red-team SHIP-WITH-CHANGES 0
```
Output (first that applies):
* `NO-INPUT` (exit 1) — empty/malformed.
* `CHANGED` — ≥1 persona's verdict differs prev→curr AND it's not a suspicious flip → keep iterating.
* `SUSPICIOUS-FLIP` — ≥2 personas moved their verdict TO the curr majority this round (synchronized
  capitulation), OR any persona moved toward the majority verdict while its issue_count **dropped**
  (substance-degradation: kept arguing less to agree more). → WARNING; do NOT treat as a clean stop.
* `CONVERGED` — all verdicts identical prev→curr AND no `SUSPICIOUS-FLIP`. → clean early stop.

The example above → `SUSPICIOUS-FLIP` (red-team flipped BLOCK→SHIP-WITH-CHANGES and its issue_count
fell 4→0 — textbook capitulation; caught even though it's a single persona, addressing the staggered
+ substance-degradation cases verdict-only would miss).

## Loop interaction with the detector (cap is absolute)

```
if converged == CONVERGED: break
if converged == SUSPICIOUS-FLIP and not warned:
    warn(...); warned=true
    run one more round EVEN IF target N reached (bounded by absolute cap 4)   # makes the brake real at N=2
# else (CHANGED, or SUSPICIOUS again after warned) keep iterating until the absolute cap
```
`N` is the **target**; the absolute cap is **4**. A single suspicious flip may extend the run by one
round beyond the target (so default `N=2` can reach round 3 — the brake is real, not dead). `warned`
is **never cleared**, so the retry costs exactly one extra round; nothing ever exceeds 4 rounds.

## Transcript round-tagging (storage decision pinned)

Extend `transcript.sh`:
* `capture <room>` blocks accept `@@from: <persona>#r<N>` (round suffix optional; absent ⇒ untagged).
* **Storage:** the `from` field is stored **raw, verbatim** in the JSONL (e.g. `red-team#r2`) — no
  parsing in `capture`. The `#rN` suffix is parsed **only in `show`** for grouping. So a `#` that is
  NOT a round suffix (`persona#hashtag`) is never misclassified at write time.
* `show` parses a trailing `#r<digits>` off `from`, groups under `── round N ──` headers; entries
  with no `#rN` suffix render under a single "round —" group (backward-compatible with old logs).

## Single source of truth (sentinel-anchored)

`skills/council/SKILL.md` is canonical; `prompts/council-orchestrator.md` mirrors the iteration
rules. Both carry machine-checkable **sentinel comments** (HTML-comment form — both files are
Markdown): `<!-- ITER_CAP=4 -->` and `<!-- ITER_DEFAULT=2 -->`. `test_orchestrator_sync.sh` does a
fixed-string (`grep -F`) match for both sentinels in both files + both contain the refute-first
marker (`REFUTE FIRST`) — anchored, no false-pass on stray `4`/`2` in prose.
**SKILL.md currently says "≤2 rounds. No loops." — updating it to the loop semantics is an explicit
implementation task (it is the canonical source; fix it first, not the mirror).**

---

# Design Options (round-N peer input)

**A — full prior-round positions (RECOMMENDED).** Inject each peer's full prior POSITION.
* Pro: highest fidelity reflection; the file/line evidence personas need to refute is present.
* Con: more tokens. Bounded by "prior round only" + ≤4 personas. Acceptable.

**B — orchestrator-summarized brief.** Condense prior round to a brief.
* Pro: cheaper.
* Con: launders the specific evidence that makes refutation possible (red-team's gate-#1 point); it
  is exactly what made today's round-2 weak. Rejected for reflection rounds.

Recommend **A** — fidelity is the whole point of reflection; cost is bounded by round-scoping + cap.

---

# Reliability / Operations
* Persona spawn fails mid-round → drop survivor, note in synthesis (unchanged).
* Cap is a hard `clamp(...,1,4)` — no unbounded loop even if convergence never triggers.
* Observability: per-round transcript + journal (unchanged guard: no transcript ⇒ no journal).

---

# Testing
* `test_converged.sh` — `synth.sh converged`: identical verdicts → CONVERGED; a verdict differs →
  CHANGED; ≥2 flips-to-curr-majority → SUSPICIOUS-FLIP; single flip-toward-majority with dropped
  issue_count → SUSPICIOUS-FLIP (substance degradation); empty/malformed → NO-INPUT (exit 1).
* `test_transcript.sh` (extend) — `#r2` capture stored raw + round-trips; `show` renders
  `── round N ──` grouping; untagged logs still render; **negative test**: `from` = `persona#tag`
  (not `#r<digit>`) is NOT grouped as a round.
* `test_orchestrator_sync.sh` — SKILL.md and council-orchestrator.md carry identical
  `# ITER_CAP=` / `# ITER_DEFAULT=` sentinels + both contain `REFUTE FIRST`.
* `test_selection.sh` (extend) — red-team auto-included when iterations>1.
* **`test_reflect_prompt.sh`** (anti-mush, automated — replaces eyeball) — assert the reflection
  prompt text emitted for iterations ≥2 contains the `REFUTE FIRST` ordering AND that a peer-position
  block is injected; assert red-team's prompt contains the harder concession rule.
* E2E (manual, supplementary): dogfood `/council --iterations 3` on this feature's own plan; confirm
  round-2 positions reference peer points and `show` renders the evolution.

# Tech Debt / v2
* **Separate-spawn refute/concede** (the structural sycophancy fix red-team wants): spawn-1 produces
  refutations only; spawn-2 sees them and independently decides concessions. Doubles spawns —
  deferred to v2; v1 ships refute-first-in-one-call + observability.
* Semantic "new-issue" convergence (beyond verdict + issue-count) — deferred.
* Auto-tuning N from observed convergence rates — deferred.
* Single-source via sentinel-grep, not true generation — acceptable at this scale.

# Open Questions
| # | Q | Resolution |
|---|---|---|
| 1 | Peer input full vs summarized | **A (full, prior-round-only)**. Resolved. |
| 2 | Does default change behavior? | Yes — round-2 becomes real reflection; declared, tests updated. |
| 3 | Where does the all-flip detector live? | `synth.sh converged` returns the flag; orchestrator acts on it. Resolved. |
