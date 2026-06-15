# First-council worked example

A complete, runnable council on a realistic PRD. Closes [issue #11](../../../issues/11).

## What's here

| File | What |
|---|---|
| [`artifact.md`](artifact.md) | The input PRD — a feature flag for a checkout API's express path. ~2 pages, generic enough to be public. |
| [`solo-decision.md`](solo-decision.md) | The operator's pre-council answer + the three risks they already saw. The counterfactual baseline. |
| [`run.sh`](run.sh) | Reproducible: captures the per-persona POSITION blocks into an isolated room, journals the run, and prints the transcript + stats. Does NOT call an LLM — `transcript.txt` is pre-canned. |
| [`transcript.txt`](transcript.txt) | The per-persona POSITION blocks from a 2-round council, rendered as they'd appear in `transcript.sh show`. |
| [`synthesis.md`](synthesis.md) | The final synthesis: verdict, ranked issues, dissents, **net-new-vs-solo table**. |

## The 30-second version

The operator wrote a PRD for a feature-flag-gated express checkout path. Their solo decision was
SHIP-WITH-CHANGES with three named risks (validator drift, customer-record lookup latency, metric
drift).

The council ran with **4 Core Six personas** (reliability-sentinel, software-architect,
generalist-swe, red-team — last one auto-included for multi-iteration runs). 2 rounds, SPLIT verdict
(2× BLOCK, 1× SHIP-WITH-CHANGES, 1× SHIP).

The council surfaced **4 BLOCKERs/MAJORs the solo decision missed entirely**:

1. **BLOCKER:** "Returning customer" is a MUTABLE label — admin actions (fraud reversal, GDPR
   deletion) can flip a customer's classification mid-checkout. The express path can bypass
   new-account validators on an account that's now classified as new. (red-team)
2. **BLOCKER:** Kill-switch granularity is unspecified — per-request vs per-connection vs
   per-process flag-read determines whether a flip interrupts in-flight requests or only new ones.
   (reliability-sentinel)
3. **MAJOR:** "A/B comparison after rollout" is actually a before/after (longitudinal) comparison,
   not an A/B. (software-architect)
4. **MAJOR:** Kill-switch asserted to work but never tested. (red-team)

The full synthesis is in [`synthesis.md`](synthesis.md). The net-new-vs-solo table at the bottom is
the value-prop: this isn't more bullet points, it's failure modes the operator's solo pass didn't
name.

## Running it

```bash
cd $AGENT_FLEET_HOME    # or the path to your clone of agent-fleet
bash examples/first-council/run.sh
```

The script creates an isolated `$AGENT_CHAT_ROOT` and `$AGENT_FLEET_JOURNAL` under `mktemp -d`, so
your real journal at `~/.claude/agent-fleet-journal.jsonl` is **untouched**. The temp dir is
cleaned up on exit.

## What the example shows (and doesn't)

**Shows:**
- What an input artifact looks like
- What a pre-council solo decision looks like (the counterfactual)
- What 4 personas produce as per-persona POSITION blocks across 2 rounds with REFUTE-FIRST reflection
- How `lib/transcript.sh capture` ingests round-tagged blocks
- How `lib/journal.sh append` records the run
- How `lib/transcript.sh show` renders the round-by-round transcript
- How the synthesis identifies net-new findings vs the solo decision

**Doesn't show:**
- A live LLM call — the per-persona POSITIONs are pre-canned. In a real run, you'd dispatch to
  your AI tool's subagent primitive (Claude Code's Task tool, opencode subagents, Codex CLI, etc.)
  per the orchestrator prompt at [`prompts/council-orchestrator.md`](../../prompts/council-orchestrator.md).
- The **blinded-judge** mechanism (issue #1). After the synthesis lands, the operator can run
  `lib/blind-judge.sh judge $ROOM --phase1 judge-a` to record a blinded second-opinion judgment.
  Omitted here to keep this example focused on the council itself.

## Why this example uses only the Core Six

The Core Six personas have ≥18 logged validation runs each. The 10 experimental personas
(`data-engineer`, `perf-engineer`, `product-pm`, `cost-finops`, `docs-dx`, `pre-mortem`, `cto`,
`ceo`, `vp-eng`, `mvp`) are tagged `[experimental]` in their descriptions and in
[`agents/INDEX.md`](../../agents/INDEX.md). They have ≥3 logged runs each but haven't been promoted.
Leading with experimental personas in a public example would oversell what's validated.

## When to NOT use this example

This example uses fictional content. The artifact is a fake PRD, the operator's solo decision is
fictional, the council's responses are pre-canned (mine, illustrative). If you want to see real
council runs, look at the journal entries at `~/.claude/agent-fleet-journal.jsonl` after a real
run — they're the durable record.
