# Plan: Council input integrity

- status: ready-for-implementation
- source: `PRD.md`, `DD.md`, council room `council-issue-78-design-rerun`
- branch: `fix/issue-78-council-input-integrity`
- mode: ship patch

## Scope lock

Do:

- fail missing kind or infrastructure reuse inventory before debate;
- strict-capture all required POSITION blocks by round;
- gate formal synthesis and complete journal rows on manifest state;
- terminalize incomplete rooms;
- test each #78 case.

Do not:

- add transport runner, dependency, or crypto attestation;
- rewrite old logs;
- modify persona prompts.

Stop. Return to DD if strict receipts cannot handle round 1 plus reflection rounds.

## Files

| Path | Work |
|---|---|
| `lib/council-guard.sh` | New artifact, manifest, state, POSITION checks |
| `lib/transcript.sh` | Strict round capture; managed-room generic gate |
| `lib/journal.sh` | Complete-state gate; incomplete events; stats filter |
| `prompts/council-orchestrator.md` | Required lifecycle |
| `skills/council/SKILL.md` | Generated prompt copy |
| `test/test_council_guard.sh` | New unit coverage |
| `test/test_transcript.sh` | Strict receipt and synthesis coverage |
| `test/test_journal.sh` | Complete/incomplete coverage |
| `test/test_orchestrator_sync.sh` | Prompt contracts |
| `.gitignore` | Ignore local workflow runs |

## Task graph

```mermaid
flowchart LR
  A[Guard + state tests] --> B[Strict transcript receipt]
  B --> C[Journal gates]
  C --> D[Prompt + generated skill]
  D --> E[Focused tests + npm test]
```

Guard owns state. Transcript records valid round evidence. Journal and prompt use same state.

## Tasks

### 1. Guard and manifest

Why: one source for structural checks.

- Add `artifact`, `begin`, `position`, `finish`, and incomplete-state commands.
- Store kind, artifact hash, inventory result, roster, mode, state, and round receipts.
- Lock manifest updates. Reject bad or terminal transitions.

Accept:

- Missing kind, invalid inventory, invalid POSITION, duplicate field, bad persona, and invalid state fail.
- Valid infrastructure inventory and POSITION pass.
- `begin` binds validated artifact; `finish` only accepts a captured running round.

Validate:

```bash
bash test/test_council_guard.sh
```

### 2. Transcript and journal gates

Why: invalid evidence must not become completed council evidence.

- Add strict managed-room `capture-positions`.
- One full named round only. No partial write or duplicate round.
- Block generic managed-room persona blocks. Block synthesis before `finish`.
- Require complete state for `journal append`.
- Add `journal incomplete`. It seals room first. Record typed v2 event. Exclude incomplete events from completed rates.

Accept:

- Empty/malformed/missing counterargument/missing persona output fail before strict capture.
- Generic capture cannot add persona evidence to a managed room.
- Incomplete room cannot capture, finish, synthesize, or append complete row.
- Stats show incomplete count, never count it as a complete council.

Validate:

```bash
bash test/test_transcript.sh
bash test/test_journal.sh
```

### 3. Protocol and generated skill

Why: every supported TUI needs same fail-closed steps.

- Gate artifact before persona debate.
- Require selected roster receipt, direct raw output, one retry, strict capture each round, and `finish` before synthesis.
- Ban reconstruction. Label preselected single-context work as simulation.
- On second failure: terminal incomplete record, nonzero `COUNCIL_INCOMPLETE`, no synthesis/verdict/judge.
- Regenerate skill from canonical prompt.

Accept:

- Prompt sync test asserts each new invariant.
- Rendered skill equals canonical prompt wrapper.

Validate:

```bash
bash test/test_orchestrator_sync.sh
```

### 4. Full validation and review

- Run focused tests first.
- Run `npm test`.
- Run spec check, docs check only if public workflow docs changed, then Occam check.

Accept:

- All commands pass.
- Diff contains no runtime transport or dependency.
- Every #78 acceptance item maps to code or test.

## Execution

| Wave | Tasks | Gate |
|---|---|---|
| 1 | 1 | Guard tests pass |
| 2 | 2 | Transcript and journal tests pass |
| 3 | 3 | Prompt sync passes |
| 4 | 4 | `npm test` passes |

## Rollback

Revert patch. No schema migration or durable data change.
