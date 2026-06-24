# Blinded-judge helper implementation review — 2026-06-23

**Issue:** #65 — external-context review of blinded-judge helper implementation
**Reviewer:** `agy -p`
**Model family:** claude
**Prompt used:** `/tmp/agent-fleet-helper-review-prompt.txt` during the run; reproduced below.
**Code reviewed:** current working tree on 2026-06-23, focused on:

- `lib/blind-judge.sh`
- `lib/journal.sh`
- `test/test_blind_judge.sh`
- `test/test_journal.sh`
- `test/test_migrate.sh`

## Prompt

```text
You are a fresh-context implementation reviewer for agent-fleet issue #65.

Review the blinded-judge helper implementation for correctness, audit integrity, concurrency, and data-loss risks. Focus files:
- lib/blind-judge.sh
- lib/journal.sh
- test/test_blind_judge.sh
- test/test_journal.sh
- test/test_migrate.sh

Do NOT suggest large redesigns. Return only actionable findings. For each finding include severity (BLOCKER/MAJOR/MINOR), file:line if possible, problem, and concrete fix. If no correctness bugs, say so and list residual risks.

Pay special attention to:
- prepare -> judge -> record audit field propagation
- judge_ts behavior
- Phase 1/Phase 2 boundary logic
- ambiguous legacy room handling
- journal migration defaults
- record concurrency and lock behavior
- evidence self-quote guards
- candidate status accuracy

Output format:
===HELPER REVIEW===
reviewer: agy -p
model_family: claude
commit_under_review: current working tree
prompt: /tmp/agent-fleet-helper-review-prompt.txt
findings:
- <severity> <file:line> <problem> fix: <fix>
residual_risks:
- <risk>
verdict: PASS | PASS-WITH-FIXES | BLOCK
===END===
```

## Review verdict

`PASS-WITH-FIXES`.

The review found real helper-layer correctness bugs. All BLOCKER/MAJOR findings were fixed in this follow-up except residual risks explicitly listed below.

## Findings and triage

| Severity | Finding | Triage |
|---|---|---|
| BLOCKER | `journal.sh migrate` used `//=` defaults, which clobbers explicit `false` values (for example `judge_blinded_catch:false`) because jq treats `false` as falsey. | **Fixed.** Migration now adds missing keys only via `ensure(key; default)` and preserves explicit `false`; regression test added. |
| BLOCKER | `journal.sh append` and `blind-judge.sh record` used different locks (`flock` vs mkdir lock), so append and record could race and lose rows. | **Fixed.** `journal.sh` now uses the same portable mkdir lock at `$JOURNAL.lockdir`; regression coverage still relies on existing concurrency tests. |
| MAJOR | Phase 1 dual-judging overwrote judge-a with judge-b instead of preserving both rows. | **Fixed.** `record` appends a second judged row when the existing row has a different Phase 1 judge label; same-label races remain idempotent. Regression test added. |
| MAJOR | Legacy positional `journal.sh append` with 8 positional args plus `--judge-*` flags parsed flags as optional positionals. | **Fixed.** Optional positionals are consumed only until first `--flag`; regression test added. |
| MAJOR | `candidates` could imply judgeability for rooms with no self-report journal row. | **Fixed.** Candidate status now includes `missing-journal`; runbook and regression test updated. |
| MAJOR | Evidence self-quote guard compared normalized evidence against raw synthesis/solo text, missing wrapped-line quotes. | **Fixed.** Guards normalize whitespace on both sides in `parse` and `record`; regression test added. |
| MINOR | `prepare` used `sha256sum` directly, which is not standard on macOS. | **Fixed.** Added `sha256_file` / `sha256_text` helpers with `shasum -a 256` fallback. |

## Residual risks

- `migrate` and `record` use `mv` for atomic replacement; this can replace a symlinked journal with a regular file. Current default journal path is a normal file, so this is noted but not fixed.
- `judge` stdin timeout uses `timeout`, `gtimeout`, then Perl alarm fallback. If a system lacks all three, timeout behavior may fail. macOS has Perl by default; noted but not fixed.

## Validation after fixes

Focused helper tests:

```bash
bash -n lib/journal.sh lib/blind-judge.sh
bash test/test_journal.sh
bash test/test_migrate.sh
bash test/test_blind_judge.sh
```

Full suite also passed:

```bash
for t in test/*.sh; do bash "$t" || exit 1; done
```
