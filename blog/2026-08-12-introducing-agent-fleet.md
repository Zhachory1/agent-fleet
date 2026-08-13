# agent-fleet: a council that disagrees with you

A single AI review pass has a blind spot: it tends to agree with the framing you
handed it. Ask the same model the same question four times and average the
answers, and you mostly get the same blind spot, four times.

agent-fleet is built to break that.

> ⚠ **Research-grade, not production-grade.** This is a tool I built for myself
> and am publishing openly. The validation arm is still open — treat the numbers
> below as directional dogfood evidence, not proof.

## What it is

A portable **council of specialist review personas** for high-stakes engineering
decisions. You convene 3–6 orthogonal reviewers, each critiques your artifact
from an independent angle, and an orchestrator runs a bounded reflection debate,
then synthesizes one decision-grade answer with **ranked issues, named dissents,
and a false-consensus flag**.

The point isn't to get a rubber stamp. It's to catch what a single pass misses.

## Why a debate beats "ask 4 LLMs"

The mechanism that distinguishes a council from an ensemble is the **reflection
debate**:

```
your decision  ──▶  /council <task>
   Step 0    write your solo decision + the risks you already see
   Step 0.5  same-lenses single-pass baseline (validation arm)
   Step 2    pick 3-6 personas by task (17 in the catalog)
   Step 3    round 1: each persona reviews in isolation, blind
             rounds 2..N: each persona sees peers' FULL prior positions
             and must REFUTE-FIRST before conceding
   Step 5    synthesis: ranked issues, named dissents, false-consensus flag
   Step 6    journal the run
```

Personas are stateless one-shot reviewers; your AI coding agent orchestrates and
holds the transcript. Because each persona must read peers' full positions and
**refute before conceding**, the council resists the collapse-to-agreement that
averaging can't. A hardened red-team persona carries an even stricter concession
rule, and the default three — red-team, mvp, occams-razor — are auto-included.

**Step 0 is the whole point:** you write your own decision *before* the council
convenes, so the output is measured as net-new value over what you already had.

## Where it stands

From the current dogfood journal (author/operator-run, still being validated):

- **17 personas** — 6 core + 10 promoted + 1 experimental.
- **Net-new catch rate:** 54/56 (96%) in the dogfood snapshot.
- **Parallel vs single-context:** a 10-pair run had parallel at 10/10,
  single-context at 8/10 (mean +20pp).
- **Lens baseline:** 26/28 councils beat a same-lens single pass — current gate
  passed.
- **Blinded judge:** Phase 1 complete; strict Phase 2 in progress.

The honest gap: **external validation** — non-author operators running it on
their own artifacts — is still needed.

## Who it's for (and not)

Install it into Claude Code, Cursor, Cave, opencode, Codex, or paste it into any
chat agent:

```bash
npx @zhachory1/agent-fleet install --tool claude
```

It's **not** for you if you want a managed product, a CI merge-blocker, or
pristine proof it works. It's a thinking tool — a prompt structure plus bash
helpers — and the output requires judgment. If you're not willing to write your
decision before the council convenes, it isn't for you either.

Start with [`examples/first-council/`](../examples/first-council/): a complete,
runnable council on a realistic PRD, including the per-persona debate and a
net-new-vs-solo table. Read it before deciding whether to install.
