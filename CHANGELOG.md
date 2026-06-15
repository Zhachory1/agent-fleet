# Changelog

All notable changes to agent-fleet are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project adheres to semantic versioning.

## [Unreleased]

### Added
- `install.sh --tool cursor` / `--tool opencode` / `--tool codex` shortcuts that copy personas + orchestrator prompt into sensible default directories (`.cursor/rules/` and `.agent-fleet/` respectively). Closes the second MAJOR from issue #14.
- `agents/occams-razor.md` — aggressive complexity-cutter persona (experimental). Default verdict skews BLOCK on premature abstraction, indirection without payoff, framework-itis. Paired with `mvp` produces a double-edge bloat attack on scope + complexity.
- `docs/features/blinded-judge/phase1-worksheet.md` — concrete 5-council to-do for issue #20 with the exact judge commands.
- `docs/external-users/operator-self-test.md` — issue #13 second-checkbox tracker.
- `test/test_install_tool_flags.sh` — exercises the new `--tool` shortcuts.
- Selection-table parity check in `test/test_orchestrator_sync.sh` — every persona in `agents/` must be referenced in BOTH `prompts/council-orchestrator.md` AND `skills/council/SKILL.md` (or neither). Mutation-tested.

### Changed
- `agents/mvp.md` — sharpened to default BLOCK or SHIP-WITH-CHANGES, never SHIP unless minimum-scope is provable. Added quantitative-evidence rule.
- Persona cap raised from 2-4 to 3-6 in orchestrator + skill + INDEX. Mandatory overlap check at >4 personas.
- shellcheck CI gate flipped from advisory to **hard gate** at `--severity=warning`. 14 real warnings fixed (SC2069 stderr-redirect order, SC2155 masked exit codes, SC2088 unexpanded-tilde false positives now disabled with rationale).
- `docs/features/blinded-judge/calibration-phase1.template.md` fleshed out from 5-line stub to actionable template.

### Honest disclosure
- Issue #1 (catch-rate self-report integrity) remains **open** despite code shipping. Closure requires Phase 1 + DRI decision per issue #20, not code merge. `journal.sh stats` self-report rates are Tier-3 evidence until that lands.

## [0.1.0] — 2026-06

Initial public-readiness baseline.

### Added
- Core six personas + 10 experimental specialists (domain, adversarial complement, executive).
- Bounded N-iteration reflection debate with critique-before-concede and a `warned` state machine for SUSPICIOUS-FLIP capitulation detection.
- `lib/transcript.sh` — durable per-room reasoning capture.
- `lib/journal.sh` — counterfactual catch-rate log with gate dashboard.
- `lib/blind-judge.sh` — blinded-judge sample mechanism (code shipped; Phase 1 calibration pending per #20).
- `lib/synth.sh` — deterministic consensus/dissent flag.
- `lib/overlay.sh` — private overlay inspector + lint.
- `install.sh` with `--tool claude` native install + `--target DIR --copy` generic install.
- Council skill at `skills/council/SKILL.md` (Claude Code) + portable orchestrator prompt at `prompts/council-orchestrator.md` (any tool).
