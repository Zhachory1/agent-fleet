# Phase 1 worksheet — first 5 dual-judged councils

> **Status**: 0/5 complete. This is the concrete to-do that closes issue #1 (via #20).
> Every checkbox below = a 5-10min copy-paste sequence. Total time-to-Phase-1: ~1-2 hrs of judge time spread over a week.

## Why this file exists

Issue #20's checklist is buried inside a merged doc. PRs that closed code don't close validation. This file surfaces the 5 specific councils to judge, in order, with the exact commands. Tick boxes here, not in the issue body.

## Pre-flight (one-time, ~5 min)

- [ ] `export AGENT_FLEET_HOME="$HOME/code/agent-fleet"`
- [ ] `bash $AGENT_FLEET_HOME/lib/journal.sh stats` — should show `blinded-judge sample : 0 of N runs judged = 0%`
- [ ] Have two LLM accounts ready: a fresh Claude chat (judge-a, same-family) AND one cross-family option (GPT, Gemini, or Codex). **Rule**: don't reuse the agent that ran the original council — different account at minimum, different family is stronger.

## The 5 candidate rooms

Filtered to: artifact resolvable + transcript present + journal row exists. Generated 2026-06-15 from `ls ~/.claude/agent-chat/rooms/` cross-referenced with the journal.

| # | Room | Artifact | Personas (r1) | Issues raised | Notes |
|---|---|---|---|---|---|
| 1 | `council-cache-prd` | cavecode cache-optimization PRD | ab-critic, software-architect, red-team | 11 | design-kind; 92%-headroom critique was the catch |
| 2 | `council-permtier-prd` | cavecode opt-in-permission-tier PRD | red-team, software-architect | — | design-kind; smaller council |
| 3 | `council-prose-40pct` | cavecode prose-40pct DD | ab-critic, ml-scientist, red-team | — | design-kind; ML-heavy artifact |
| 4 | `council-prose-40pct-finding` | cavecode prose-40pct REPORT | ab-critic, ml-scientist, red-team | — | investigation-kind; readout artifact |
| 5 | **TBD** | next real council you run this week | — | — | Phase 1 needs 5 distinct rooms; this is the 5th |

**Selection rationale (gen-swe + occams):** picked rooms that are (a) fully resolvable today without backfill, (b) representative of the 3 run-kinds the gate cares about (design, design, design, investigation, + 1 future code), (c) not the agent-fleet self-review councils — judging your own tool's self-review is double-recursion that confounds the calibration signal.

## Same-family vs cross-family mix

Per PRD-OQ8: 3 same-family + 2 cross-family. Assignment below — change if you don't have the cross-family account handy this week; record the actual family used in the calibration writeup.

| # | Room | judge-a (family) | judge-b (family) | Pair kind |
|---|---|---|---|---|
| 1 | `council-cache-prd` | claude (fresh) | claude (different account) | same-family |
| 2 | `council-permtier-prd` | claude (fresh) | claude (different account) | same-family |
| 3 | `council-prose-40pct` | claude (fresh) | claude (different account) | same-family |
| 4 | `council-prose-40pct-finding` | claude (fresh) | gpt OR gemini | **cross-family** |
| 5 | TBD (5th distinct council) | claude (fresh) | gpt OR gemini | **cross-family** |

## The 10 commands (5 councils × 2 judges)

Each judge call is ~5 min of human time: run `prepare`, paste rendered prompt into the fresh chat, paste back the response, helper records.

### Council 1 of 5 — `council-cache-prd`

- [ ] judge-a (claude, fresh account):
  ```bash
  bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-cache-prd --phase1 judge-a
  ```
- [ ] judge-b (claude, different account):
  ```bash
  bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-cache-prd --phase1 judge-b
  ```

### Council 2 of 5 — `council-permtier-prd`

- [ ] judge-a:
  ```bash
  bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-permtier-prd --phase1 judge-a
  ```
- [ ] judge-b:
  ```bash
  bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-permtier-prd --phase1 judge-b
  ```

### Council 3 of 5 — `council-prose-40pct`

- [ ] judge-a:
  ```bash
  bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-prose-40pct --phase1 judge-a
  ```
- [ ] judge-b:
  ```bash
  bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-prose-40pct --phase1 judge-b
  ```

### Council 4 of 5 — `council-prose-40pct-finding` (cross-family)

- [ ] judge-a (claude, fresh):
  ```bash
  bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-prose-40pct-finding --phase1 judge-a
  ```
- [ ] judge-b (gpt or gemini):
  ```bash
  bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-prose-40pct-finding --phase1 judge-b
  ```

### Council 5 of 5 — TBD (cross-family)

- [ ] Run a real council on real work this week. **Pre-requirement**: orchestrator writes `artifact.txt` to the room (FR9). Then both judges as above.

## Per-judge runbook (5-10 min)

1. Run the `prepare` command for the judge slot. It renders the rubric + your council's artifact + persona positions, copies to clipboard, prints `judge_render_sha256:` for audit.
2. Open the fresh chat. Verify it's the right account/family for this slot.
3. Paste the rendered prompt.
4. Wait for the judge's response. It will be JSON-shaped per the rubric (verdict, evidence, reasoning, dissent_diff, materiality).
5. Copy the entire response, paste back into the terminal where the `judge` command is waiting (it has a 10-min stdin timeout).
6. Helper parses, validates, writes the journal row + transcript line. Done.

If stdin times out, re-run the same command; idempotent on `judge_render_sha256` collision per the DD.

## After all 10 judge calls land

- [ ] `bash "$AGENT_FLEET_HOME/lib/journal.sh" stats --judged` — confirm 5 distinct rooms judged, 10 rows.
- [ ] Write `docs/features/blinded-judge/calibration-phase1.md` from the template — qualitative shape-of-disagreement paragraph + same-family vs cross-family observation.
- [ ] **Issue #20** comment with the calibration writeup link. That's what closes #1, not the code merge.

## Bail conditions

- If 3+ of the 4 existing rooms refuse `resolve_artifact` because `@file:` is unresolvable (work moved/deleted), run the backfill helper: `bash lib/blind-judge.sh backfill-artifact <room> --from <new-path>` (see #23 for the deferred MAJOR list).
- If you can't get a non-claude account this week, do all 5 same-family for Phase 1 and document the deviation in the calibration writeup — that's honest, the data still says something.

## Out of scope

- Phase 2 (n≥50 single-judged) is a separate file when Phase 1 lands.
- DRI decision is the third milestone in issue #20; written when Phase 2 results stabilize.
- This file does NOT close issue #1. The calibration writeup at `calibration-phase1.md` does (via #20).
