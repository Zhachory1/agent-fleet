# Blinded-judge Phase 2 runbook

**Goal:** reach ≥50 single-judged Phase 2 rooms for issue #1, then write the DRI decision at
`docs/features/blinded-judge/decision-<date>.md`.

**Historical local snapshot (2026-06-19):** 21/50 distinct rooms judged, 19/21 self-vs-blind agreement. Run `bash lib/journal.sh stats` for current source-of-truth counts; journals are environment-specific.

## What counts

Count a room when all are true:

1. It is a real council run on a real artifact.
2. The room has a durable `artifact.txt` (or resolvable `@file:` / `@diff:` pointer).
3. The room has captured persona positions (`@@from: <persona>#r<N>` entries).
4. The judge was a fresh context that did not run the council.
5. The result was recorded by `lib/blind-judge.sh judge` or `record`.

## What does not count

- Duplicate original rooms whose anonymized clones were already judged for a paired-mode study.
- Synthetic test fixtures.
- Reruns of the same room unless explicitly investigating judge disagreement; do not add them to the Phase 2 denominator.
- Rooms with missing artifacts unless backfilled from the original source.

Rooms with no `@@from: synthesis` block may be judged, but note the caveat: dissent-erasure checking is muted. Prefer synthesis-bearing rooms for the remaining Phase 2 sample.

## Preferred judge CLI flow

Use a fresh CLI judge when available. The helper invokes CLI judges with prompt mode (`claude -p`, `agy -p`, `gemini -p`):

```bash
export AGENT_FLEET_HOME=/path/to/agent-fleet
export AGENT_CHAT_ROOT=${AGENT_CHAT_ROOT:-$HOME/.claude/agent-chat}
export AGENT_FLEET_JOURNAL=${AGENT_FLEET_JOURNAL:-$HOME/.local/share/agent-fleet/journal.jsonl}

bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-<slug> --judge-cli claude
# or
bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-<slug> --judge-cli agy --model-family claude
# or
bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-<slug> --judge-cli gemini
```

`--judge-cli` and `--response-file` are mutually exclusive. If the CLI output needs manual cleanup,
use the response-file path instead:

```bash
bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" prepare council-<slug> > /tmp/judge-prompt.txt
# paste the rendered prompt into a fresh chat, save response to /tmp/judge-response.txt
bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" judge council-<slug> --response-file /tmp/judge-response.txt
```

## Candidate selection loop

1. List unjudged rooms with artifacts and transcripts.
2. Exclude paired-mode duplicates and synthetic/test rooms.
3. Prefer rooms with synthesis blocks and naturally varied outcomes (including low-signal / likely `catch=false`).
4. Judge one room.
5. Run `bash lib/journal.sh stats` and record the new Phase 2 count in issue #1 if it moved.

Use the helper instead of hand-rolled `jq` when possible:

```bash
bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" candidates
```

Columns:

- `status`: `ready`, `ambiguous-room`, `no-synthesis`, `missing-artifact`, `missing-transcript`, `no-positions`, or `judged`.
  - `ambiguous-room` means the room has multiple journal self-report rows, so `prepare` cannot safely pair the right solo decision with the right persona positions. Use a unique room per council or split the legacy room before judging.
- `positions`: number of captured `#r<N>` persona position blocks.
- `synthesis_words`: word count across synthesis blocks; `0` means dissent-erasure checking is muted.
- `artifact`: whether `artifact.txt` exists.

By default, `candidates` excludes already judged rooms and `council-paired-*` rooms. Use:

```bash
bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" candidates --all
bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" candidates --include-paired
```

Only count paired rooms if they are the actual study target and their anonymized clones have not
already been judged.

## Phase 2 close criteria

Issue #1 closes only after:

1. Phase 2 reaches ≥50 judged rooms.
2. The DRI writes `decision-<date>.md` with the agreement band and KPI decision.
3. README and stats wording are updated to reflect the decision.
4. The issue is closed with links to the stats, decision doc, and final commit.
