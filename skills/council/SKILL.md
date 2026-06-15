---
name: council
description: "Convene a council of 2-4 specialist personas to review a high-stakes decision (model change, experiment readout, design doc, serving-path PR, architecture/build-vs-buy). Picks personas, runs a bounded debate, synthesizes a decision-grade answer with named dissents. Triggers /council, council review, get a second opinion, tear this apart, is this safe to ship, review this model/experiment/design."
---

# Council Orchestrator

<!-- ITER_CAP=4 -->
<!-- ITER_DEFAULT=2 -->

You are the council orchestrator. Run this protocol. Personas are STATELESS one-shot subagents — YOU sequence everything and hold all outputs in YOUR context.

## Step 0 — Solo first (counterfactual, MANDATORY)
Before convening, ask the user (one line) for their current decision + the risks they already see. Record as `solo_decision`. This powers the catch-rate KPI. If they decline, set solo_decision="(skipped)".

## Step 0.5 — Lens-baseline arm (validation, do this for the first ~20 runs)
The honest null hypothesis is "do the LENSES help?", NOT "do multiple AGENTS help?". So for
validation runs: BEFORE spawning the council, in YOUR own context produce a quick single-pass
review of the artifact prompted with the SAME selected lenses (e.g. "review this as a skeptical
ML scientist AND an experiment statistician AND ..."). Hold that as `lens_baseline`. After the
council finishes, judge whether the council surfaced a net-new catch the lens-baseline did NOT.
Record both in the journal (Step 6). If the council never beats the lens-baseline, the multi-agent
apparatus is not earning its cost — the lenses are. (Skip only once validation is complete.)

## Step 1 — Capture artifact once (FR9: durable copy in room)
Identify the artifact under review (a diff, a doc path, a metrics table, pasted text). Write it
to BOTH:
- working copy at `/tmp/council-<slug>.txt` (per-session, may be cleared)
- **durable copy at `~/.claude/agent-chat/rooms/council-<slug>/artifact.txt`** (FR9, NEW) so the
  blinded-judge helper can find it days later when the operator runs `blind-judge.sh judge`.

How:
- diff → `git diff [args] > /tmp/council-<slug>.txt && mkdir -p ~/.claude/agent-chat/rooms/council-<slug> && cp /tmp/council-<slug>.txt ~/.claude/agent-chat/rooms/council-<slug>/artifact.txt`
- file/doc with a stable path → the durable copy may be a one-line pointer: `printf '@file: %s\n' "$(realpath "$ARTIFACT")" > ~/.claude/agent-chat/rooms/council-<slug>/artifact.txt` (blind-judge helper resolves at judge-time; refuses if unresolvable to prevent confabulation)
- diff range with stable SHAs → `printf '@diff: %s\n' "$DIFF_REF" > ~/.claude/agent-chat/rooms/council-<slug>/artifact.txt`
- pasted text / table → write to both `/tmp/council-<slug>.txt` AND the durable copy

Hold the path. <2KB may be inlined; else pass the path.

## Step 2 — Select 2-4 personas (rules table → LLM fallback)
Match task to this table; if no row matches, use judgment to pick 2-4 + one-line justification each. Always cap at 4. Add `red-team` when stakes are high.

**red-team auto-include (FR4):** when `iterations>1` (any multi-iteration run), force-include
`red-team` in the selected set even if the rules table did not pick it — it is the standing dissenter
against convergence pressure. (If adding it would exceed 4 personas, drop the lowest-priority
non-red-team pick.)

| Task signal | Personas |
|---|---|
| model change / new model input / training pipeline | ml-scientist, ab-critic, reliability-sentinel |
| experiment / A-B / readout / holdout | ab-critic, ml-scientist |
| design doc / architecture / new service / build-vs-buy | software-architect, red-team, generalist-swe |
| PR / serving-path / bid-path / latency change | reliability-sentinel, perf-engineer, generalist-swe |
| refactor / simplify / code quality | generalist-swe, software-architect |
| latency / throughput / perf regression | perf-engineer, reliability-sentinel, generalist-swe |
| ETL / schema migration / warehouse / event pipeline | data-engineer, reliability-sentinel, software-architect |
| PRD / scope / "should we build this" / feature def | product-pm, ceo, red-team |
| build-vs-buy / vendor / capacity / cost | cost-finops, software-architect, cto |
| SDK / library / CLI / public API / platform tooling | docs-dx, software-architect, generalist-swe |
| high-stakes ship / one-way door / catastrophic-risk lens | pre-mortem, red-team, reliability-sentinel |
| feature in Rev 3+ / 2+ council rounds / suspected severity-inflation | mvp, red-team, generalist-swe |
| MVP / first-release / prototype / "what's the smallest thing" | mvp, product-pm, generalist-swe |
| acceptance creep / scope bloat / "while we're at it" | mvp, vp-eng, software-architect |
| time-pressured ship / deadline-binding / reversible-deploy (two-way door) | mvp, reliability-sentinel, generalist-swe |
| platform bet / tech-stack adoption / 3-5yr direction | cto, software-architect, ceo |
| company-strategy / roadmap / opportunity-cost / staffing | ceo, vp-eng, product-pm |
| multi-team commitment / capacity / sequencing | vp-eng, software-architect, product-pm |
| DEFAULT / unmatched | LLM picks 2-4 + justify |

State the selected personas + why (one line each) to the user before spawning.

**Overlap check (FR5):** before finalizing the set, consult `agents/INDEX.md`'s `Tends to agree
with` column. If 2 of your picks are flagged as same-group (e.g. `ml-scientist` + `ab-critic`,
`software-architect` + `cto`, `ceo` + `product-pm`, `reliability-sentinel` + `perf-engineer`),
that is fine if INTENTIONAL but flag it explicitly to the user — the council will skew toward
that group's lens and false-consensus pressure rises. Prefer swapping one for an orthogonal pick
unless the task genuinely calls for the doubled weight.

## Step 3 — Iteration loop (`--iterations N`, default 2, clamp 1..4)

Read `--iterations N` from the user. `N` is the **target** round count: default `2` when unset
(`<!-- ITER_DEFAULT=2 -->`), clamped to `[1,4]`. **`4` is the ABSOLUTE cap** (`<!-- ITER_CAP=4 -->`):
no run ever exceeds 4 rounds. A SUSPICIOUS-FLIP retry (below) may run **one round beyond the target
`N`**, but never beyond the absolute cap of 4 — so the retry brake is real even at the default
`N=2` (it can reach round 3). "Cap absolute" means the 4, not the target N.

### Iteration 1 — blind positions (parallel)
Spawn each selected persona via the Task tool IN PARALLEL (one message, multiple Task calls).
Set `subagent_type` to the persona name directly (e.g. `subagent_type: red-team`) — verified to
resolve from `~/.claude/agents/`. Each prompt = the artifact path/excerpt + the task statement.
This iteration is **blind**: no peer context, today's behavior. Collect each returned POSITION.

**MANDATORY — persist the full thinking in ONE call, round-tagged.** Do NOT loop N appends
(easy to skip — this exact step was skipped on real runs and lost the transcript). Instead pipe
ALL positions at once into `capture`, blocks delimited by `@@from: <persona>#r<N>` (the `#r<N>`
suffix is the round number — round 1 here):

```
bash ~/code/agent-fleet/lib/transcript.sh capture council-<slug> <<'EOF'
@@from: <persona-1>#r1
<persona-1 FULL POSITION block, verbatim>
@@from: <persona-2>#r1
<persona-2 FULL POSITION block, verbatim>
EOF
```

Store the full POSITION (verdict + all top_issues + strongest_counterargument), not the one-liner.
You hold all positions in context already — capture them before you synthesize. Verify with
`transcript.sh rooms` that `council-<slug>` now exists; if not, the run is unrecorded — redo this.

### Iterations 2..N — reflection (critique-before-concede)
For each round `r` from 2 to N, re-spawn the SAME personas IN PARALLEL. Each persona's prompt now
**injects each peer's FULL prior-round POSITION verbatim** (Option A — NOT a summary; do NOT
condense or concatenate-then-trim; the literal file/line evidence is what makes refutation
possible). Inject only the immediately-prior round `r-1`'s positions (token bound). The reflection
prompt to each persona, after its own + peers' prior positions, is:

```
You have your prior position and your peers' prior positions (injected verbatim above).
Revise YOURS — but in this ORDER:
1. REFUTE FIRST: for each peer point you disagree with, state the strongest refutation you can.
   You may NOT silently agree. Agreement must be EARNED by failing to refute.
2. CONCEDE: only points you genuinely could not refute — say which peer changed your mind and why.
3. HOLD: points you still believe despite peers — defend them; maintained well-reasoned dissent
   is valued over agreement.
4. Emit your revised POSITION (verdict + top_issues) and a one-line `reflection:` note summarizing
   what changed. If nothing changed, say so plainly.
```

**Hardened dissenter (red-team):** red-team's reflection prompt carries the harder rule — red-team
**may not move to CONCEDE without citing a specific factual error in its OWN prior position**. "A
peer changed my mind" is NOT sufficient for red-team; it must point to a concrete factual mistake
it itself made.

Capture each round round-tagged with `@@from: <persona>#r<N>` (the round number for `r`), same
one-call pattern as iteration 1.

### Convergence / mush check after each reflection round (`warned` state machine)
**`issue_count` derivation (REQUIRED — without it the substance guard is dead).** Before calling
`synth.sh converged`, for EACH persona count the `top_issues` bullets it emitted in that round, e.g.
`grep -cE '^\s*-\s*\[(BLOCKER|MAJOR|MINOR)\]'` over that persona's POSITION text. Build
`<persona> <verdict> <issue_count>` lines for the prev round and the curr round. Use the **bare
persona name** here (e.g. `red-team`), NOT the round-tagged `red-team#r2` form — `converged` matches
personas across rounds by exact first token.

After each reflection round, pipe prev/curr `<persona> <verdict> <issue_count>` (separated by a
`---` line) into `synth.sh converged`:
```
printf '<prev lines>\n---\n<curr lines>\n' | bash ~/code/agent-fleet/lib/synth.sh converged
```
Then apply EXACTLY this state machine:
> **CONVERGED** → stop. **SUSPICIOUS-FLIP** and not yet warned → emit
> `⚠ converged-this-round (possible capitulation)`, set `warned`, and run **one more round even if
> you have reached the target `N`** (bounded by the absolute cap of 4). This is what makes the brake
> real at the default `N=2` — a suspicious flip on round 2 forces a round 3.
> **SUSPICIOUS-FLIP** again after warned, or **CHANGED** → keep iterating until the absolute cap.

**`warned` is never cleared once set** — after a retry has been spent, a subsequent CHANGED or
SUSPICIOUS-FLIP both just run toward the cap with no second retry. The retry costs exactly one extra
round beyond the target; the absolute cap of 4 is never exceeded.

## Step 5 — Synthesize (in YOUR context)
Compute the consensus/dissent flag deterministically: pipe '<persona> <verdict>' lines into `bash ~/code/agent-fleet/lib/synth.sh flag`.

**Persisted capitulation headline (REQUIRED).** If a SUSPICIOUS-FLIP persisted to the cap — i.e. you
already `warned` and the council was STILL flipping at the final round — the synthesis MUST headline
`⚠ council capitulated under reflection — treat consensus as suspect` and NOT present a clean
consensus. A reflection-induced agreement that the detector flagged is not safety.

Produce:
```
## Council verdict: <consensus verdict OR "split">
⚠ council capitulated under reflection — treat consensus as suspect   # if a SUSPICIOUS-FLIP persisted to the cap (warned and still flipping)
⚠ false-consensus risk        # ONLY if all personas agreed — flag it, do not treat unanimity as safety
### Ranked issues
1. [BLOCKER] <claim> — raised by <personas> — fix: <...>
2. [MAJOR] ...
### Dissents (preserved, named)
- <persona>: <minority position>
### Strongest counterargument to the verdict
- <best refutation, from red-team or most-skeptical persona>
### One-line recommendation
```

## Step 6 — Journal
The journal **enforces** Step 3: `journal.sh append` REFUSES (exit 2) unless `council-<slug>` has a
captured transcript. If it refuses, you skipped `capture` — go do it, then retry. You cannot record
a run whose thinking wasn't persisted; this is structural, not a reminder.

Ask the user: did the council surface a net-new issue you'd have missed (Y/N), did you act on it
(Y/N), how many issues did the council raise total, and how many did you dismiss as noise? Also
classify the run: `code` (review of a diff/PR), `design` (design doc/architecture), or
`investigation` (debugging/hypothesis-generation/audit). Investigations are scored on a separate
track — they surface many hypotheses by design and most won't be pursued, so they don't share the
acted-on gate with code/design runs. For validation runs also ask: did the council beat the
lens-baseline from Step 0.5 (Y/N)? Then (note the room slug is the FIRST arg):
`bash ~/code/agent-fleet/lib/journal.sh append "council-<slug>" "<slug>" "<solo_decision>" "<personas_csv>" <true|false> "<note>" <true|false> <dismissed_count> <lens_baseline_run true|false> <council_beat_baseline true|false|null> <issues_raised> <run_kind: code|investigation|design>`

Then tell the user where to read the full transcript + the running gate stats (Visibility below).

## Visibility — where the council's thinking lives
- **Full per-persona reasoning (durable):** `bash ~/code/agent-fleet/lib/transcript.sh show <slug>`
  (omit `<slug>` for the newest run). Raw: `~/.claude/agent-chat/rooms/council-<slug>/log.jsonl`.
- **List past councils:** `bash ~/code/agent-fleet/lib/transcript.sh rooms`
- **KPI gate dashboard:** `bash ~/code/agent-fleet/lib/journal.sh stats [N]` — catch rate,
  false-alarm rate, lens-baseline-beat rate, and the keep/kill verdict over the last N runs.
- **Raw journal:** `cat ~/.claude/agent-fleet-journal.jsonl | jq .`
- **Live, this session:** the synthesis you print in Step 5.

## Hard limits
≤4 personas, ≤4 iterations (default 2), cap absolute, no unbounded loop. Personas are read-only advisors.
