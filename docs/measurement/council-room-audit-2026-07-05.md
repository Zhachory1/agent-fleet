# Council room audit — 2026-07-05

## Scope

Local audit after updating Me Write Code to `1.0.9`.

Data roots:

```bash
export AGENT_FLEET_HOME=/Users/zhach/code/agent-fleet
export AGENT_CHAT_ROOT=$HOME/.agent-fleet/agent-chat
export AGENT_FLEET_JOURNAL=$HOME/.agent-fleet/journal.jsonl
```

No artifact bodies were copied into this doc. This audit uses room metadata, journal fields, and helper output only.

## Commands

```bash
bash "$AGENT_FLEET_HOME/lib/journal.sh" stats
bash "$AGENT_FLEET_HOME/lib/blind-judge.sh" candidates --all
bash "$AGENT_FLEET_HOME/lib/transcript.sh" rooms
```

## Source-of-truth stats

After judging the six ready rooms and five recovered rooms, `journal.sh stats` reports:

```text
council journal — last 56 run(s)
net-new catch rate : 54/56 = 96%   [gate ≥40%: PASS]
acted-on (code+design): 35/49 = 71%
hypotheses pursued (investigations): 2/7 = 28%
false-alarm rate   : 45/569 issues dismissed = 7%   [gate <50%: PASS]
lens-baseline arm  : 26/28 council beat same-lenses single pass   [gate n≥10 & ≥40%: PASS]
blinded-judge sample : 27 of 56 runs judged = 48%
self-vs-blind        : 25/27 agree = 92%   [Phase 2: 26/50 rooms judged]
runs by kind       : code=25, design=24, investigation=7

verdict: KEEP — council earns its cost
```

Interpretation:

- Council remains useful in dogfood data: high acted-on rate, low dismissed-issue rate, lens-baseline gate passed.
- Phase 2 is not close-ready: strict distinct-room progress is `26/50`; the earlier paired-inclusive `21/50` snapshot has been surpassed by strict active-root rooms after judging the six ready candidates and five recovered candidates.
- Agreement sample is still small and author/operator-run. Do not upgrade beyond dogfood evidence.

## Room inventory

Active room root:

```text
~/.agent-fleet/agent-chat/rooms
```

Inventory:

| Bucket | Count | Notes |
|---|---:|---|
| Room dirs | 84 | Raw directories in active root. |
| Journal rows | 56 | Active journal rows counted by `journal.sh stats`. |
| Candidate-index rooms | 43 | Rooms joined by `blind-judge.sh candidates --all`. |
| Strict judged candidate rooms | 26 | Distinct rooms in the Phase 2 denominator. |
| Judged journal rows | 27 | One duplicate-room judged row explains row-vs-room mismatch. |
| Ready unjudged rooms | 0 | Five older rooms were repaired and judged after the first judged batch. |
| Ambiguous rooms | 3 | Multiple self-report rows; helper correctly refuses. |
| Missing-artifact rooms | 12 | Not recoverable unless original artifact source is found. |
| No-position rooms | 2 | Artifact/synthesis exists but no `#r<N>` persona positions captured. |
| Unindexed room dirs | 41 | Round fragments, artifact-only dirs, or rooms without active journal rows. |

## Phase 2 candidates judged on 2026-07-05

These rooms met helper readiness checks: durable artifact, journal row, captured persona positions, and synthesis.
All six were judged with a fresh `agy` judge context using `--model-family claude`.

| Room | Positions | Synthesis words | Task |
|---|---:|---:|---|
| `council-system-prompt-2026-06-29` | 12 | 479 | `system-prompt-review` |
| `council-m3-gbrain-context-20260701` | 12 | 330 | `m3-gbrain-context` |
| `council-m3-gbrain-context-allowall-20260701` | 12 | 344 | `m3-gbrain-context-allowall` |
| `council-m4-headroom-router-20260701` | 12 | 267 | `m4-headroom-router` |
| `council-mewrite-issue-49-offline-diagnostics` | 24 | 611 | `mewrite-issue-49-offline-diagnostics-docs` |
| `council-m3b-qmd-provider-20260702` | 12 | 230 | `m3b-qmd-provider` |

All six returned `NET_NEW_CATCH=true`, agreeing with operator self-report. Strict Phase 2 progress moved from `15/50` to `21/50`.

## Repaired and judged missing-artifact rooms

A follow-up recovery pass fixed five synthesis-split rooms by copying exact artifact versions from git history and merging the captured sibling round logs into the journal room. Each recovered room has `recovery-notes.txt` and keeps the original synthesis-only log at `log.jsonl.pre-recovery-20260705`. The DRI accepted the reconstruction and all five were judged with fresh `agy` judge context using `--model-family claude`.

| Room | Artifact source | Positions | Synthesis words | Judge result |
|---|---|---:|---:|---|
| `council-blinded-judge-prd-synthesis` | `git show ff6daf633b1b87d4fad82b87bcb036ea58889368:docs/features/blinded-judge/PRD.md` | 8 | 75 | `NET_NEW_CATCH=true` |
| `council-blinded-judge-dd-synthesis` | `git show cc7f75ada3bf17c17ec420d99f23b741632b2034:docs/features/blinded-judge/DD.md` | 8 | 90 | `NET_NEW_CATCH=true` |
| `council-blinded-judge-plan-synthesis` | `git show 570994e2b592f1b535000a166f48ed858ecc554c:docs/features/blinded-judge/PLAN.md` | 8 | 105 | `NET_NEW_CATCH=true` |
| `council-readme-rewrite-synthesis` | `git show 13129bb2b3de178beca40e597cd3b7ac231a0aad:README.md` | 12 | 133 | `NET_NEW_CATCH=true` |
| `council-degraded-claim-synthesis` | `git show 5843cf391d6da56f20c4399538344ae0a9c33533:README.md` | 12 | 93 | `NET_NEW_CATCH=true` |

Also copied the legacy inline artifact for `council-dg-removal-max-poll-pr224` from `~/.claude/agent-chat`, but that room remains `no-positions` because its transcript uses old `#r-final` tags rather than `#r<N>` tags.

Post-judge candidate scan:

| Status | Count |
|---|---:|
| judged | 26 |
| missing-artifact | 12 |
| ambiguous-room | 3 |
| no-positions | 2 |

## Not countable without repair

| Bucket | Rooms | Why blocked |
|---|---|---|
| Ambiguous self-report | `council-first-run-onboarding`, `council-honest-bench-accounting`, `council-subagent-write-reliability` | Multiple journal rows per room; helper cannot pair one solo decision to one transcript safely. |
| No positions | `council-news-scraper-issues-2026-06-29`, `council-dg-removal-max-poll-pr224` | Artifact exists, but no captured `#r<N>` persona positions. |
| Artifact-only recent dirs | `council-m4b-headroom-local-20260702`, `council-m5-context-setup-20260703`, `council-m6a-provider-fanout-20260703`, `council-m7-m9-context-completion-20260703` | Artifact exists, but no active journal row or `log.jsonl`. |
| Missing artifacts | 12 candidate rows | Do not judge unless original artifacts are recovered from durable sources. |
| Unindexed fragments | 41 dirs | Mostly round-specific logs, synthesis fragments, or rooms absent from active journal. Useful history, not strict Phase 2 data. |

## Research update

Evidence level after this audit:

1. **Dogfood usefulness: KEEP.** 35/49 acted-on code/design runs and 7% dismissed issue rate beat the repo's current utility gates.
2. **Lens value: passed current gate.** Same-lens baseline arm is 26/28, above both n≥10 and ≥40% thresholds.
3. **Blinded-judge calibration: still underpowered.** Strict Phase 2 denominator is 26/50 distinct rooms.
4. **Persistence improvements are working for newer councils.** The six newly judged rooms all had artifacts, positions, and synthesis. That is materially better than older no-synthesis or missing-artifact rooms.
5. **Some old rooms are repairable if the original source is durable.** Git-history artifacts plus sibling round logs recovered and judged five more rooms without inventing artifact text.
6. **No external-human validation yet.** These rooms do not satisfy the non-author operator milestone.

## Issue implications

- **#1:** updated progress to strict active-source state three times: pre-judge (`15/50`, 6 ready candidates), post-first-batch (`21/50`, 0 ready candidates), recovery (`5` more ready candidates), and post-recovery-judge (`26/50`, 0 ready candidates). Do not close. Issue comments: https://github.com/Zhachory1/agent-fleet/issues/1#issuecomment-4884897089, https://github.com/Zhachory1/agent-fleet/issues/1#issuecomment-4884926165, https://github.com/Zhachory1/agent-fleet/issues/1#issuecomment-4884953114, and https://github.com/Zhachory1/agent-fleet/issues/1#issuecomment-4884974507
- **#72:** no status change. Audit adds no non-author overlay contribution.
- **External/operator self-test tracker:** do not backfill from these rooms. It requires immediate verbatim friction notes; this audit only reviewed persisted council metadata.

## Next actions

1. Generate at least 24 more real council rooms with artifact, positions, synthesis, journal row, and fresh blinded judge.
2. Prioritize low-signal / likely `catch=false` artifacts so the sample is not all positive.
3. Re-run `journal.sh stats` and `blind-judge.sh candidates --all` after each judged batch.
4. Keep capturing `artifact.txt`, `log.jsonl`, `@@from: synthesis`, and journal rows for every new council.
