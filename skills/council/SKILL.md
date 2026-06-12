---
name: council
description: Convene a council of 2-4 specialist personas to review a high-stakes decision (model change, experiment readout, design doc, serving-path PR, architecture/build-vs-buy). Picks personas, runs a bounded debate, synthesizes a decision-grade answer with named dissents. Triggers: /council, council review, get a second opinion, tear this apart, is this safe to ship, review this model/experiment/design.
---

# Council Orchestrator

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
Spawn each selected persona via the Task tool IN PARALLEL (one message, multiple Task calls).
Set `subagent_type` to the persona name directly (e.g. `subagent_type: red-team`) — verified to
resolve from `~/.claude/agents/`. Each prompt = the artifact path/excerpt + the task statement.
Collect each returned POSITION.

**MANDATORY before synthesis — persist the full thinking in ONE call.** Do NOT loop N appends
(easy to skip — this exact step was skipped on real runs and lost the transcript). Instead pipe
ALL positions at once into `capture`, blocks delimited by `@@from: <persona>`:

```
bash ~/code/agent-fleet/lib/transcript.sh capture council-<slug> <<'EOF'
@@from: <persona-1>
<persona-1 FULL POSITION block, verbatim>
@@from: <persona-2>
<persona-2 FULL POSITION block, verbatim>
EOF
```

Store the full POSITION (verdict + all top_issues + strongest_counterargument), not the one-liner.
You hold all positions in context already — capture them before you synthesize. Verify with
`transcript.sh rooms` that `council-<slug>` now exists; if not, the run is unrecorded — redo this.

## Step 4 — Round 2 (only if verdicts conflict OR user passed --deep)
Summarize round-1 positions into a short peer brief (you do this — do NOT concatenate raw). Re-spawn the SAME personas in parallel, prompt now includes the brief. Collect revisions, append full positions to transcript.

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
**Precondition:** confirm `bash ~/code/agent-fleet/lib/transcript.sh rooms` lists `council-<slug>`.
If it does not, you skipped Step 3's `capture` — go back and persist the positions FIRST. Never
journal a run whose thinking wasn't recorded.

Ask the user: did the council surface a net-new issue you'd have missed (Y/N), did you act on it
(Y/N), how many issues did the council raise total, and how many did you dismiss as noise? For
validation runs also ask: did the council beat the lens-baseline from Step 0.5 (Y/N)? Then:
`bash ~/code/agent-fleet/lib/journal.sh append "<slug>" "<solo_decision>" "<personas_csv>" <true|false> "<note>" <true|false> <dismissed_count> <lens_baseline_run true|false> <council_beat_baseline true|false|null> <issues_raised>`

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
≤4 personas, ≤2 rounds. No loops. Personas are read-only advisors.
