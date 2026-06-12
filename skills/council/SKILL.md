---
name: council
description: Convene a council of 2-4 specialist personas to review a high-stakes decision (model change, experiment readout, design doc, serving-path PR, architecture/build-vs-buy). Picks personas, runs a bounded debate, synthesizes a decision-grade answer with named dissents. Triggers: /council, council review, get a second opinion, tear this apart, is this safe to ship, review this model/experiment/design.
---

# Council Orchestrator

You are the council orchestrator. Run this protocol. Personas are STATELESS one-shot subagents — YOU sequence everything and hold all outputs in YOUR context.

## Step 0 — Solo first (counterfactual, MANDATORY)
Before convening, ask the user (one line) for their current decision + the risks they already see. Record as `solo_decision`. This powers the catch-rate KPI. If they decline, set solo_decision="(skipped)".

## Step 1 — Capture artifact once
Identify the artifact under review (a diff, a doc path, a metrics table, pasted text).
- diff → `git diff [args] > /tmp/council-<slug>.txt`
- file/doc → use its path directly
- pasted text / table → write to `/tmp/council-<slug>.txt`
Hold the path. <2KB may be inlined; else pass the path.

## Step 2 — Select 2-4 personas (rules table → LLM fallback)
Match task to this table; if no row matches, use judgment to pick 2-4 + one-line justification each. Always cap at 4. Add `red-team` when stakes are high.

| Task signal | Personas |
|---|---|
| model change / new model input / training pipeline | ml-scientist, ab-critic, reliability-sentinel |
| experiment / A-B / readout / holdout | ab-critic, ml-scientist |
| design doc / architecture / new service / build-vs-buy | software-architect, red-team, generalist-swe |
| PR / serving-path / bid-path / latency change | reliability-sentinel, generalist-swe, software-architect |
| refactor / simplify / code quality | generalist-swe, software-architect |
| DEFAULT / unmatched | LLM picks 2-4 + justify |

State the selected personas + why (one line each) to the user before spawning.

## Step 3 — Round 1 (parallel)
Spawn each selected persona via the Task tool IN PARALLEL (one message, multiple Task calls). Each prompt = the persona name (subagent_type) + the artifact path/excerpt + the task statement. Collect each returned POSITION.

Append each position to the transcript serially:
`bash ~/code/agent-fleet/lib/transcript.sh append council-<slug> <persona> "<one_line + verdict>"`

## Step 4 — Round 2 (only if verdicts conflict OR user passed --deep)
Summarize round-1 positions into a short peer brief (you do this — do NOT concatenate raw). Re-spawn the SAME personas in parallel, prompt now includes the brief. Collect revisions, append to transcript.

## Step 5 — Synthesize (in YOUR context)
Compute the consensus/dissent flag deterministically: pipe '<persona> <verdict>' lines into `bash ~/code/agent-fleet/lib/synth.sh flag`.
Produce:
```
## Council verdict: <consensus verdict OR "split">
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
Ask the user: did the council surface a net-new issue you'd have missed (Y/N), did you act on it (Y/N), how many raised issues did you dismiss as noise? Then:
`bash ~/code/agent-fleet/lib/journal.sh append "<slug>" "<solo_decision>" "<personas_csv>" <true|false> "<note>" <true|false> <dismissed_count>`

## Hard limits
≤4 personas, ≤2 rounds. No loops. Personas are read-only advisors.
