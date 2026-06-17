# Parallel-subagent vs single-context council runs — measurement protocol

**Status:** protocol + helper landed. No real paired runs yet.
**Tracks:** issue #36.
**Depends on:** #48 (Phase 1 calibration complete as of 2026-06-16).

---

## Why this exists

README + AGENTS.md previously described single-context councils as "DEGRADED." Commit `5546493`
softened that to "single-context (round-1 contamination)" with an explicit honesty paragraph:

> The magnitude of that contamination is not measured — the lens-baseline arm in
> `journal.sh stats` compares any council mode against same-lenses-single-pass; it does NOT
> compare the two council modes against each other. Until the dual-mode measurement lands,
> "parallel is better" is a theoretical claim with known sign and unknown magnitude.

This doc IS the measurement. It defines the protocol so when the runs happen, they answer one
question: **is single-context-mode meaningfully worse than parallel-subagent-mode on the
catch-rate KPI, after blinded-judge scoring?**

## Hypothesis

`H0` (null): blinded-judge catch agreement is equivalent in the two modes (within noise).
`H1`: parallel-subagent mode has materially higher catch agreement with blinded-judge than
       single-context mode does, on the same artifacts.

We are NOT testing "operator says it caught more" — we are testing whether the blinded judge
(reading only the artifact + persona positions + operator synthesis) endorses the catch
**equally** in both modes. The blinded judge cannot tell which mode produced the transcript
(rooms are renamed before judging — see §"Blinding the judge" below).

## Design (paired-artifact, per generalist-swe BLOCKER)

**10 artifacts × 2 modes = 20 council runs.** Paired, not split.

Pairing kills artifact-variance. If we ran 10 different artifacts split 5-and-5, we'd be
measuring "are the 5 mode-A artifacts harder than the 5 mode-B artifacts?" not "does the mode
matter?" Paired gives us a per-artifact delta whose mean is the mode effect with artifact
variance removed.

| Choice | Decision | Why |
|---|---|---|
| # of artifacts | 10 | Enough to see a 20pp catch-rate delta at p<0.05 with paired analysis; <30 keeps operator time bounded |
| Both modes per artifact | YES | Eliminates artifact-as-confound |
| Random order per artifact | YES — alternate which mode runs first per artifact | Mitigates operator-fatigue bias |
| Same personas both modes | YES | Mode is the only variable that should differ |
| Same N iterations both modes | YES — `--iterations 2`, the default | Iteration count is a different variable |
| Same `--phase1` flag? | N/A in Phase 2 (post-#48) | Phase 1 forcing is calibration-era |

### Pre-conditions
- [ ] #48 (Phase 1 calibration) is complete — `journal.sh stats` reports Phase 2.
- [ ] At least 2 different AI tools available to the operator (e.g. Claude Code for parallel,
      Codex CLI or Cursor for single-context).
- [ ] 10 artifacts collected — see §"Artifact selection" below.

### Artifact selection
Eligible artifacts:
- A diff (≤500 lines preferred — keeps council time bounded)
- A design doc / PRD / DD
- A model-quality readout / experiment readout

Distribution target across the 10:
- ~4 code diffs
- ~3 design docs
- ~3 experiment readouts

Excluded:
- Artifacts the operator already has a strong prior on (would bias both modes the same
  direction; not useful)
- Trivial artifacts (no council would catch anything; floor effect)
- Adversarial artifacts (intentionally broken; ceiling effect)

### Run protocol

For each artifact `i ∈ 1..10`:

1. Capture artifact once at `~/.claude/agent-chat/rooms/council-paired-<i>-parallel/artifact.txt`
   and `~/.claude/agent-chat/rooms/council-paired-<i>-single/artifact.txt` (same content;
   the room names distinguish modes).
2. Determine mode order: `flip_a_coin()` — first mode runs first; second mode runs second.
   Record the order.
3. Run the council in mode 1 with the SAME persona set + same N iterations.
4. Capture full transcript + journal.append (solo decision, net-new catch self-report).
5. Wait ≥1 hour before mode 2 to reduce carryover (the operator has just seen mode 1's output).
6. Run mode 2 with same personas, same N.
7. Capture + journal.append for mode 2.

### Blinding the judge

The blinded judge (`blind-judge.sh judge <room>`) reads from the room directory and the journal
row for that room. For the A-vs-B measurement, use the helper rather than hand-copying rooms:

```bash
bash lib/parallel-vs-single.sh anonymize \
  --pair-id 01 \
  --parallel-room council-paired-01-parallel \
  --single-room council-paired-01-single
```

What this does:
1. Copies each source room to a mode-hidden name: `council-paired-<id>-anon-<8hex>/`.
2. Appends cloned journal rows for those anonymized rooms with all `judge_*` fields reset.
3. Writes the unblinding map to `docs/measurement/parallel-vs-single-data/mapping.jsonl`
   (gitignored).
4. Warns if the copied transcript contains obvious mode-revealing strings (`parallel-subagent`,
   `single-context`, `Task tool`, `Codex`, `Cursor`, `Claude Code`). Inspect and fix those before
   judging if the warning fires.

Then run:

```bash
bash lib/blind-judge.sh judge <anon-room>
```

AFTER all judgments are recorded, unblind/analyze with:

```bash
bash lib/parallel-vs-single.sh analyze
```

The helper removes the most error-prone manual steps (renaming rooms, cloning journal rows, and
handling `false` judge results correctly), but it does not make the study complete: the operator
still must run 10 real paired artifacts and obtain fresh blinded judge responses for all 20
anonymized rooms.

## Metrics

Per artifact `i`, we record:

| Metric | Mode A (parallel) | Mode B (single-context) |
|---|---|---|
| Operator self-report catch (Y/N) | `self_a[i]` | `self_b[i]` |
| Blinded-judge catch (Y/N) | `judge_a[i]` | `judge_b[i]` |
| Self-vs-judge agreement | `self_a[i] == judge_a[i]` | `self_b[i] == judge_b[i]` |

Reported metrics:
- **Agreement rate by mode**: `mean(self_a == judge_a)` vs `mean(self_b == judge_b)` across i=1..10.
- **Paired delta**: `mean(agreement_a[i] - agreement_b[i])` with paired-bootstrap 95% CI.
- **Net-new catches per mode**: catches in A that judge confirmed but B did not even raise (and vice versa).
- **SUSPICIOUS-FLIP firing rate by mode**: did one mode trigger the convergence detector more often?

## Possible outcomes (pre-registered)

| Result | Implication for README claim |
|---|---|
| Paired delta within 10pp, CI crosses zero | Modes are equivalent on the practical KPI; the "DEGRADED" framing was wrong. Update README to say so. |
| Mode A agrees with judge ≥20pp more than mode B | "DEGRADED" framing was right; we have data. Restore (with citation). |
| Modes differ by run kind (e.g. design docs equivalent, code diffs different) | Conditional claim. Update README to say which mode helps which run kind. |
| Modes differ but in the OPPOSITE direction (B beats A) | Unexpected; investigate before claiming anything. Common cause: mode-A's parallel personas miss something the in-context contamination accidentally surfaced. |

## What this doc is NOT

- It is not a generic A/B framework for the council. The same machinery (paired artifacts,
  blinded judge) generalises to other comparisons (e.g. N=2 iterations vs N=3), but each
  specific question needs its own protocol doc.
- It is not a hypothesis about WHICH personas matter — that's a separate experiment.
- It is not a claim about LLM model families. Both modes should use the SAME model where
  possible to avoid confounding "mode" with "model."

## Open questions (resolve before runs begin)

- **OQ1**: Same model for both modes, or use the tool's native model? Tradeoff: same-model
  is cleaner science, native-model is more representative of real usage.
  *Recommendation*: same-model where the operator can configure both tools to the same
  family (Claude for both Claude Code and Cursor's underlying model, e.g.). Document the
  choice per-artifact if it varies.
- **OQ2**: Counter-balance for personas? Some personas (e.g. `red-team`) skew BLOCK; if the
  same persona set runs both modes, the systematic bias is constant. Skip.
- **OQ3**: What if the operator's solo decision changes between mode-1 and mode-2 because of
  what mode-1 surfaced? *Recommendation*: lock the solo decision before either mode runs;
  record it once; both modes use the same `--solo` text.

## Origin

`/council` on the issue queue (`council-issue-priorities`, 2026-06-16). `generalist-swe`
flagged this BLOCKER: "10-runs-in-both-modes design needs paired artifacts upfront — 5 per
mode means variance dominates; 10 artifacts twice each = 20 runs but variance controlled."
This doc reflects that finding.
