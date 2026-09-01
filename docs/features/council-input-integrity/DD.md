# DD: Council input integrity

- status: revised after council
- owner: Zhach Volker
- source: `PRD.md`, issue #78
- council: minimal, round 1 blocked
- next gate: delta council review

## Context

`lib/transcript.sh capture` accepts any non-empty `@@from:` block. `lib/journal.sh append` needs only a non-empty room log. `prompts/council-orchestrator.md` lacks deterministic reuse and required-POSITION gates.

## Scope

In:

- explicit artifact kind and reuse inventory gate;
- one strict, atomic capture path plus completion manifest;
- completed journal and formal synthesis gated on that manifest;
- incomplete journal event;
- protocol, generated skill, and tests.

Out:

- transport adapter or cryptographic process attestation;
- retries past one;
- semantic grading of issue claims;
- migration of historical room logs.

## Exact Contracts

### Artifact metadata

Every new council artifact starts with exactly one line:

```text
council_artifact_kind: infrastructure | general
```

Missing or invalid kind returns `NEED-MORE-INFO`; it cannot default to `general`. An `infrastructure` artifact must contain this heading and all non-empty fields:

```markdown
## Capability Reuse Inventory
- plausible existing capabilities:
- owner/source of truth:
- current consumers:
- access contract:
- evidence for rejection:
```

`general` skips only this inventory. The orchestrator selects kind before personas run; the metadata makes the classification reviewable. The guard validates structure, not truth. Persona review checks evidence quality.

### POSITION grammar

A strict response must have one matching header and one of each required field:

```text
POSITION (persona: <name>)
- verdict: SHIP | SHIP-WITH-CHANGES | BLOCK | NEED-MORE-INFO
- top_issues:
- strongest_counterargument: <non-empty>
- confidence: low | med | high
- one_line: <non-empty>
```

`top_issues` may have no bullets. Duplicate required fields, an unknown verdict, a mismatched persona, or blank required value fails validation.

### Run state

`council-guard.sh begin <room> <artifact-path> <mode> <personas-csv>` validates artifact metadata itself, then creates one room manifest with artifact SHA-256, kind, inventory result, selected mode, normalized unique persona names, selection rationale, and `state: pending`. The prompt records selection before `begin`; the manifest is the immutable roster receipt for this trusted-runner protocol. `capture-positions` validates one final response for every manifest persona in one common round, then appends the receipt-listed rows and moves state to `running`. `finish <room> <round>` moves a running room to `complete` only after the orchestrator chooses its last valid round. The receipts are the only formal persona evidence.

A prompt runner can prove provenance only through its own transport. It must copy raw spawned output directly into validation, never author or relabel it. If it chose a single-context run before spawning, it records `execution_mode: lens-simulation`; that is not independent multi-agent review. This portable helper makes completion provenance auditable; it does not claim cryptographic attestation. Threat model: prevent accidental or protocol-level fabrication, not a malicious local operator who can rewrite the room files.

### Retry and terminal result

For each manifest persona: validate raw response, retry once if missing/invalid, then use only final valid response in strict capture. Invalid attempts do not enter `log.jsonl`. After a second failure, `journal.sh incomplete` atomically transitions manifest state from `pending` to `incomplete` before it writes the journal event, then runner returns nonzero with exactly:

```text
COUNCIL_INCOMPLETE
failed_personas: <csv>
transport_reason: <reason>
```

`capture-positions` requires `pending` or `running`; `finish`, formal synthesis, and completed journal append require `complete`; all reject `incomplete`. A retry after terminal failure needs a new room. Managed rooms reject generic persona-position blocks; only strict receipts may be used as formal persona evidence. No formal synthesis, convergence claim, blinded judge, or completed journal append is allowed after failure. If incomplete journal write fails, state remains `incomplete`; halt with no verdict and show room plus recovery command.

## Design

Add `lib/council-guard.sh`:

- `artifact <path>` validates metadata and, for infrastructure, reuse inventory.
- `begin <room> <artifact-path> <mode> <personas-csv>` validates artifact and normalized selection, then writes pending manifest.
- `position <persona>` reads stdin and enforces POSITION grammar.
- `finish <room> <round>` transitions running to complete only for a receipt-listed final round.
- `state <room> incomplete` performs the one terminal failure transition.

Add `transcript.sh capture-positions <room>`. It reads `@@from: <persona>#rN` blocks, loads pending/running manifest, rejects unknown, duplicate, missing, or mixed-round blocks, validates all response bodies before write, takes a room lock, appends positions, and records a round receipt. A stale partial log never becomes formal evidence because it lacks a receipt; duplicate capture cannot duplicate a round. `finish` is separate so reflection rounds can each use strict capture.

Keep generic `capture` for legacy rooms and typed non-persona entries. For a managed room, reject generic persona-position blocks and reject `@@from: synthesis` unless state is `complete`. Update `journal.sh append` to require that state for all new completed council records. Add `event_type: council_completed` and `schema_version: 2`; legacy rows remain completed by default. `journal.sh incomplete` transitions pending/running state to incomplete and records `event_type: council_incomplete`, `schema_version: 2`, `verdict: null`, failed personas, and transport reason. `stats` excludes incomplete events from every completed-council denominator and reports their count separately.

## Control Flow

```mermaid
sequenceDiagram
  participant O as Orchestrator
  participant G as council-guard.sh
  participant P as Spawned persona
  participant T as transcript.sh
  participant J as journal.sh

  O->>G: artifact artifact.txt
  alt bad or missing kind/inventory
    G-->>O: NEED-MORE-INFO
  else valid artifact
    O->>G: begin room, mode, roster manifest
    loop each council round; one initial response and one retry maximum per persona
      O->>P: request raw POSITION
      P-->>O: raw response
      O->>G: position named persona
      O->>T: capture-positions one exact round batch
    end
    alt any persona invalid twice
      O->>J: incomplete failed names + reason
      J-->>O: COUNCIL_INCOMPLETE
    else last valid round chosen
      O->>G: finish room, final round
      O->>T: capture synthesis
      O->>J: append completed run
    end
  end
```

Completion needs a validated manifest. Generic capture cannot unlock synthesis or a completed journal row.

## Files

| Path | Change | Responsibility |
|---|---|---|
| `lib/council-guard.sh` | create | metadata, manifest, POSITION checks |
| `lib/transcript.sh` | modify | strict batch and formal-synthesis gate |
| `lib/journal.sh` | modify | manifest-gated complete and incomplete event/stats |
| `prompts/council-orchestrator.md` | modify | new lifecycle and no-reconstruction rule |
| `skills/council/SKILL.md` | generated | installed protocol copy |
| `test/test_council_guard.sh` | create | guard and manifest cases |
| `test/test_transcript.sh` | modify | strict capture and synthesis gate |
| `test/test_journal.sh` | modify | completion and incomplete-stat semantics |
| `test/test_orchestrator_sync.sh` | modify | protocol sentinels |

## Alternatives

| Option | Why rejected |
|---|---|
| Prompt rules only | Invalid text still becomes persisted evidence. |
| Strict all generic capture | Breaks judges and old callers; completion receipt is narrower. |
| Keyword-detect infrastructure | False negatives silently bypass reuse gate. |
| Transport-specific runner | Stronger attestation, but breaks portable CLI design and exceeds #78. |

## Risks

- Existing manual completed councils lack a manifest. Mitigation: completion gate applies to new protocol; existing logs remain readable.
- Caller can lie about a spawn. Mitigation: documented trusted-runner boundary, direct raw capture rule, and simulation label. Native adapters may attest later.
- Crash after position rows but before receipt leaves orphan rows. Mitigation: no receipt or complete state means no synthesis or complete journal; use a new room.
- Concurrent capture can double-write. Mitigation: room lock and one receipt per round.
- Unvalidated generic position can contaminate a managed room. Mitigation: generic persona-position blocks are rejected; synthesis must use receipt-listed evidence.
- Incomplete events can skew metrics. Mitigation: event type/schema version, filter from every completed rate, and test count separately.

## Testing

- Guard: missing/invalid metadata; absent/incomplete/valid inventory; `begin` stores artifact receipt; empty, malformed, duplicate-field, missing-counterargument, mismatch, and valid POSITION.
- Transcript: invalid required set writes no rows; valid set atomically creates a round receipt; duplicate round capture fails; generic persona-position and synthesis before finish fail; synthesis after finish succeeds; incomplete state blocks later capture and synthesis.
- Journal: append rejects non-complete state; incomplete transition and row have no verdict; completed and incomplete event types are distinct; stats count incomplete separately and exclude it from all completion rates.
- Protocol: `begin` validates artifact and records mode/roster before debate; each round uses strict capture; one retry; raw output/no reconstruction; nonzero terminal incomplete contract; no synthesis/verdict/judge after failure.

## Rollout

No deploy. Regenerate skill from canonical prompt. `npm test` gates merge. Roll back by revert; no data migration.

## Open Question

Native adapters can add immutable invocation receipts later. It does not block portable #78 guardrails.
