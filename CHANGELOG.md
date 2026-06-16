# Changelog

All notable changes to agent-fleet are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project adheres to semantic versioning.

## [Unreleased]

_(nothing yet — next changes land here)_

## [0.1.0] — 2026-06-16

Initial public-readiness baseline.

### Added
- Core six personas + 10 experimental specialists (domain, adversarial complement, executive).
- Bounded N-iteration reflection debate with critique-before-concede and a `warned` state machine for SUSPICIOUS-FLIP capitulation detection.
- `lib/transcript.sh` — durable per-room reasoning capture.
- `lib/journal.sh` — counterfactual catch-rate log with gate dashboard. Includes:
  - `append` (positional + kw-args), `append-judge-only`, `stats`, `migrate` subcommands.
  - `migrate` idempotently fills schema defaults on rows from prior schema eras (closes the schema-evolution paper-cut from #14).
  - Data-quality invariants enforced on `judge_*` field combinations (closes #44 item #3).
  - Write-permission precheck on the journal dir with actionable error (closes #23 reliability item).
- `lib/blind-judge.sh` — blinded-judge sample mechanism. Includes:
  - `prepare`, `record`, `judge`, `backfill-artifact` subcommands.
  - Phase 1 boundary by **distinct rooms judged** (not total rows) — closes #44 item #1.
  - Per-room lockdir spanning `prepare`→`record` (closes the subprocess race, #44 item #2).
  - Stale-lockdir recovery (5 min default) + retry jitter for concurrent waiters (closes #23 reliability items).
  - Portable `stat` (GNU vs BSD) for lockdir mtime checks.
  - Multi-synthesis-block selection via `| last` (closes #44 item #4).
- `lib/synth.sh` — deterministic consensus/dissent flag (`CONVERGED` / `CHANGED` / `SUSPICIOUS-FLIP` / `FALSE-CONSENSUS`).
- `lib/overlay.sh` — private overlay inspector + lint.
- `install.sh` with native Claude Code install + `--tool cursor` / `--tool opencode` / `--tool codex` shortcuts (closes #14 MAJOR) + `--target DIR --copy` generic install + `--print` portable orchestrator + `--version` / `--help`.
- Council skill at `skills/council/SKILL.md` (Claude Code) + portable orchestrator prompt at `prompts/council-orchestrator.md` (any tool).
- `agents/occams-razor.md` — aggressive complexity-cutter persona (experimental). Default verdict skews BLOCK on premature abstraction, indirection without payoff, framework-itis. Paired with `mvp` produces a double-edge bloat attack on scope + complexity.
- `docs/features/blinded-judge/phase1-worksheet.md` — concrete 5-council to-do for #20/#48 with exact judge commands.
- `docs/external-users/operator-self-test.md` — issue #13 second-checkbox tracker.
- `docs/measurement/parallel-vs-single-context.md` — paired-artifact A/B protocol for #36.
- `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1).
- `.github/ISSUE_TEMPLATE/` — bug + persona-proposal templates.
- shellcheck CI gate at `--severity=warning` (hard gate).
- Selection-table parity check in tests — every persona must be referenced in BOTH `prompts/council-orchestrator.md` AND `skills/council/SKILL.md` (or neither). Mutation-tested.

### Changed
- `agents/mvp.md` — sharpened to default BLOCK or SHIP-WITH-CHANGES, never SHIP unless minimum-scope is provable. Added quantitative-evidence rule.
- Persona cap raised from 2-4 to 3-6 in orchestrator + skill + INDEX. Mandatory overlap check at >4 personas.
- 14 real shellcheck warnings fixed (SC2069 stderr-redirect order, SC2155 masked exit codes, SC2088 unexpanded-tilde false positives disabled with rationale).
- README + AGENTS.md: reworded "DEGRADED" framing for single-context councils to "single-context (round-1 contamination)" with explicit honesty paragraph. The magnitude difference is unmeasured — tracked as #36.
- DD updated to document the full Rev 3 journal schema, `synthesis_word_count` (LATEST block, not aggregate), and `judge_phase1` (internal field).

### Honest disclosure
- Issue #1 (catch-rate self-report integrity) remains **open** despite code shipping. Closure requires Phase 1 + DRI decision per #20/#48, not code merge. `journal.sh stats` self-report rates are Tier-3 evidence until that lands.
- Issue #36 (parallel-vs-single-context measurement) has a protocol scaffold but no runs. "Parallel mode is better" is a theoretical claim with known sign and unknown magnitude until 10 paired runs land.
