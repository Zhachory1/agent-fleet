# Blinded-judge — Implementation Plan

> **For agentic workers:** REQUIRED: TDD per chunk — failing test FIRST, then minimum code to pass, then refactor. Steps use checkbox (`- [ ]`) syntax. Where this PLAN spec text conflicts with DD Rev 3, DD wins; if you find such a conflict, flag it in the implementation PR.

**Goal:** Ship the v1 blinded-judge mechanism per PRD Rev 3 + DD Rev 3. Implements issue #1.

**Architecture:** New `lib/blind-judge.sh` helper (prepare/record/judge/backfill-artifact subcommands) + canonical rubric `lib/blind-judge-prompt.v2.txt` + journal schema +13 fields + `stats` two-phase arm. Orchestrator edits (SKILL.md + portable prompt) for FR9 artifact persistence. 14 parser golden-bad fixtures + concurrency stress test.

**Tech Stack:** bash + jq + flock. No new runtime dependency. Paste-and-record UX (no CLI shell-out in v1 per PRD).

---

## File map

```
lib/blind-judge.sh                          CREATE  prepare|record|judge|backfill-artifact subcommands + parser
lib/blind-judge-prompt.v2.txt               CREATE  canonical rubric with attack-warning frontmatter (v1 never shipped)
lib/journal.sh                              MODIFY  +13 fields, --judged subcommand, two-phase stats arm
lib/transcript.sh                           MODIFY  render @@from: blind-judge#judge-N with distinct visual
skills/council/SKILL.md                     MODIFY  Step 1: durable artifact write to room/artifact.txt (FR9)
prompts/council-orchestrator.md             MODIFY  mirror Step 1 change
test/test_blind_judge.sh                    CREATE  parser fixtures + chain semantics + concurrency
test/fixtures/blind-judge/                  CREATE  14 golden-good + golden-bad response fixtures
test/test_journal.sh                        MODIFY  +13 fields default + roundtrip + judge-only-row exclusion
test/test_transcript.sh                     MODIFY  blind-judge#judge-N rendering
```

---

## Chunk 0: canonical rubric (no code; ship file first)

The rubric file is the contract everything else implements against. Land it first so subsequent chunks reference a real file.

### Task 0.1: write `lib/blind-judge-prompt.v2.txt`

**Files:** Create `lib/blind-judge-prompt.v2.txt`

- [ ] **Step 1: extract verbatim from DD Rev 3 §Canonical rubric.** The DD ships the rubric text as a fenced code block. Copy it verbatim into `lib/blind-judge-prompt.v2.txt` (the fenced ` ``` ` boundaries are NOT part of the file). Include the `# ============` attack-warning frontmatter.

- [ ] **Step 2: sanity-check the file has all required tokens.** Run:

```bash
for tok in 'WARNING TO ANY EDITOR' 'v2 changelog' 'PERSONA_POSITIONS' 'OPERATOR_SYNTHESIS' \
           'PERSONA_LIST' 'REASONING' 'DISSENT_DIFF' 'NET_NEW_CATCH' 'WHY' 'EVIDENCE' \
           'IMPLIED_BY' '===JUDGE OUTPUT===' '===END===' '{ARTIFACT}' '{SOLO_DECISION}'; do
  grep -qF "$tok" lib/blind-judge-prompt.v2.txt || { echo "FAIL: missing $tok"; exit 1; }
done
echo "rubric tokens OK"
```

- [ ] **Step 3: commit** `chore(blinded-judge): canonical rubric v2.txt (post external review)`

---

## Chunk 1: journal schema (additive, backward-compat)

13 new fields per DD Rev 3. Run_kind-style backward compat — missing field → default. Tests assert legacy rows unchanged.

### Task 1.1: extend `journal.sh append`

**Files:** Modify `lib/journal.sh`; Modify `test/test_journal.sh`

- [ ] **Step 1: failing test.** Append to `test/test_journal.sh`:

```bash
# Rev 3 schema: 13 new blinded-judge fields default to legacy-compat values when missing.
# Existing rows (before this commit) MUST continue to parse with all defaults populated.
LEGACY='{"ts":"2026-06-01T00:00:00Z","room":"c-legacy","task":"old","solo_decision":"s",
         "personas":["x"],"net_new_catch":true,"catch_note":"","acted_on":true,
         "dismissed_count":0,"lens_baseline_run":false,"council_beat_baseline":null,
         "issues_raised":0,"run_kind":"code"}'
echo "$LEGACY" > /tmp/journal-legacy.jsonl
# stats must report 'blinded-judge sample : 0 of 1 runs judged' for legacy-only data
OUT=$(AGENT_FLEET_JOURNAL=/tmp/journal-legacy.jsonl bash "$DIR/lib/journal.sh" stats)
echo "$OUT" | grep -q 'blinded-judge sample : 0 of 1' || { echo "FAIL: stats new-arm legacy: $OUT"; exit 1; }
echo "$OUT" | grep -qi 'calibration phase' || { echo "FAIL: stats calibration-phase label missing: $OUT"; exit 1; }

# new fields write through append
ROOM_J=council-judged-row
"$DIR/lib/transcript.sh" capture "$ROOM_J" <<<"@@from: a
verdict: BLOCK"
"$DIR/lib/journal.sh" append "$ROOM_J" "j" "solo" "a" true "n" true 1 false null 3 code \
  --judge-blinded true --judge-catch true --judge-why "found leakage" \
  --judge-evidence "ml-scientist: train/serve skew detected" \
  --judge-model-family claude --judge-prompt-version v2 \
  --judge-template-sha256 deadbeef --judge-render-sha256 cafef00d \
  --judge-reasoning "two-clause materiality holds" --judge-dissent-diff "- (none)" \
  --solo-decision-word-count 1 --synthesis-word-count 5
jq -e '.[-1] | .judge_blinded==true and .judge_blinded_catch==true and .judge_evidence!="" and
       .judge_prompt_version=="v2" and .judge_reasoning!="" and .judge_dissent_diff!="" and
       .synthesis_word_count==5' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: new judge_* fields not written through append"; exit 1; }

# judge-only row (no preceding self-report append): write a fresh row with self-report null
ROOM_K=council-judge-only
"$DIR/lib/transcript.sh" capture "$ROOM_K" <<<"@@from: a
verdict: SHIP"
"$DIR/lib/journal.sh" append-judge-only "$ROOM_K" "k" \
  --judge-blinded true --judge-catch false --judge-why "covered by solo" \
  --judge-model-family gpt --judge-prompt-version v2 \
  --judge-template-sha256 deadbeef --judge-render-sha256 baadf00d \
  --judge-reasoning "solo already named the issue" --judge-dissent-diff "- (none)"
jq -e '.[-1] | .judge_blinded==true and .net_new_catch==null and .acted_on==null and .room=="'"$ROOM_K"'"' \
  "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: judge-only row should have judge_blinded=true and self-report fields=null"; exit 1; }
```

- [ ] **Step 2: implement.** Two surface changes to `lib/journal.sh`:

  - `append`: accept new `--judge-*` flags AFTER the existing 12 positional args (per #3 the positional contract stays, but new fields are kw-args). Default missing flags to legacy values (judge_blinded=false, etc.). Compute `solo_decision_word_count` from `$3` if not supplied; require `synthesis_word_count` flag (operator MUST report — synthesis size is the operator's input, not the appender's).
  - New subcommand `append-judge-only <room> <task> --judge-* ...`: writes a fresh row with all self-report fields NULL and judge_* fields populated. Used by step 3 of the chain when step 2 failed (per DD FR8).

  Both wrap their write in `flock -x "$AGENT_FLEET_JOURNAL.lock"` (Chunk 4 adds the lock).

- [ ] **Step 3: run, all tests pass.** Existing 10 tests must not regress.

### Task 1.2: `stats` two-phase arm + `--judged` subcommand

**Files:** Modify `lib/journal.sh`; extend `test/test_journal.sh`

- [ ] **Step 1: failing test.** Add to `test/test_journal.sh`:

```bash
# stats shows phase label by judged-runs count
for n in 0 4 5 49 50; do
  # ... (helper to populate $n judged rows; assert label is phase 1 / phase 2 / band)
done

# stats --judged prints last 5 (timestamp, self_catch, judge_catch, why, evidence)
OUT=$(bash "$DIR/lib/journal.sh" stats --judged)
echo "$OUT" | grep -q 'self_catch' || { echo "FAIL: --judged header missing"; exit 1; }
```

- [ ] **Step 2: implement.** Extend `stats` with:
  - `blinded-judge sample : Y of N runs judged = Z%`
  - `self-vs-blind : X of Y agree = W%` (only if Y>=5; else `[calibration phase — N/5 Phase 1, dual-judging required via --phase1 judge-a|judge-b]`)
  - `judge-vs-judge : X/5` (Phase 1 dual-judged rows only)
  - `[Phase 2: N/50 judged]` when 5≤N<50; band annotation `[bands: heuristic-pending-recalibration]` when N≥50
  - `judge-only rows: N` line when any judge-only rows exist
  - `--judged` subcommand: print last 5 judged rows as a table (timestamp | self | judge | why | evidence)

- [ ] **Step 3: run tests.**

- [ ] **Step 4: commit** `feat(journal): blinded-judge schema (13 fields) + two-phase stats arm`

---

## Chunk 2: helper — `lib/blind-judge.sh prepare`

The simplest subcommand. Reads the room, assembles the 5 blobs, renders against the rubric, prints + clipboards + emits banner. No state mutation.

### Task 2.1: prepare assembles 5 blobs

**Files:** Create `lib/blind-judge.sh`; Create `test/test_blind_judge.sh`

- [ ] **Step 1: failing test.** `test/test_blind_judge.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export AGENT_CHAT_ROOT="$(mktemp -d)"
export AGENT_FLEET_JOURNAL="$(mktemp -d)/j.jsonl"
ROOM=council-prepare-test
ARTIFACT_PATH="$AGENT_CHAT_ROOT/rooms/$ROOM/artifact.txt"
mkdir -p "$(dirname "$ARTIFACT_PATH")"
echo "diff text here" > "$ARTIFACT_PATH"
"$DIR/lib/transcript.sh" capture "$ROOM" <<EOF
@@from: ml-scientist#r1
verdict: BLOCK
- [BLOCKER] train/serve skew
@@from: synthesis
Council verdict: BLOCK
1. [BLOCKER] train/serve skew
EOF
"$DIR/lib/journal.sh" append "$ROOM" "prepare-test" "ship as-is" "ml-scientist" true "" true 0 false null 1 design --synthesis-word-count 8

OUT=$("$DIR/lib/blind-judge.sh" prepare "$ROOM" --phase1 judge-a)
# Five sentinels present
for sec in '==== ARTIFACT ====' '==== SOLO_DECISION ====' '==== PERSONA_POSITIONS ====' \
           '==== OPERATOR_SYNTHESIS ====' '==== PERSONA_LIST ===='; do
  grep -qF "$sec" <<<"$OUT" || { echo "FAIL: missing section $sec"; exit 1; }
done
# artifact content rendered
grep -q "diff text here" <<<"$OUT" || { echo "FAIL: artifact not rendered"; exit 1; }
# operator synthesis is SEPARATE from persona positions in output
ps_block=$(awk '/==== PERSONA_POSITIONS ====/,/==== OPERATOR_SYNTHESIS ====/' <<<"$OUT")
os_block=$(awk '/==== OPERATOR_SYNTHESIS ====/,/==== PERSONA_LIST ====/' <<<"$OUT")
grep -q "ml-scientist#r1" <<<"$ps_block" || { echo "FAIL: persona position not in PERSONA_POSITIONS"; exit 1; }
grep -q "Council verdict" <<<"$os_block" || { echo "FAIL: synthesis not in OPERATOR_SYNTHESIS"; exit 1; }
grep -qE "Council verdict|^1\." <<<"$ps_block" && { echo "FAIL: synthesis leaked into PERSONA_POSITIONS"; exit 1; }
# template + render SHA256 printed
grep -qE 'judge_template_sha256: [0-9a-f]{64}' <<<"$OUT" || { echo "FAIL: template SHA256 missing"; exit 1; }
grep -qE 'judge_render_sha256: [0-9a-f]{64}' <<<"$OUT" || { echo "FAIL: render SHA256 missing"; exit 1; }
# context-switch banner mentions different-family + different-account
grep -qiF "SWITCH CONTEXTS NOW" <<<"$OUT" || { echo "FAIL: banner missing"; exit 1; }
grep -qiF "different model family" <<<"$OUT" || { echo "FAIL: banner doesn't name family pattern"; exit 1; }
echo "PASS prepare-test"
```

- [ ] **Step 2: implement `prepare`.** Subcommand dispatch + flag parsing. Key bits:
  - Read `~/.claude/agent-chat/rooms/$ROOM/artifact.txt`. If file is `@file: <path>`, resolve. If `@diff: <ref>`, `git show <ref>`. If unresolvable, die with the message from DD §FR9.
  - Read room `log.jsonl`, extract `@@from: <persona>#r<N>` blocks → `PERSONA_POSITIONS`; extract `@@from: synthesis` block → `OPERATOR_SYNTHESIS`. The two MUST be disjoint (no overlap).
  - Read journal row's `solo_decision` and `personas`.
  - Load `lib/blind-judge-prompt.v2.txt` as the template; substitute `{ARTIFACT}`, `{SOLO_DECISION}`, `{PERSONA_POSITIONS}`, `{OPERATOR_SYNTHESIS}`, `{PERSONA_LIST}`.
  - Compute `judge_template_sha256` = sha256 of rubric file (rubric+sentinels, constant per version). Compute `judge_render_sha256` = sha256 of the substituted full prompt.
  - `pbcopy` (mac) / `xclip -selection clipboard` (linux) / stdout-only (otherwise OR if `$SSH_CONNECTION` set). Print the banner from DD §"The context-switch banner (FR3)".
  - Print both SHA256s before the banner so the operator can paste them into `record` later.

- [ ] **Step 3: run, prepare-test passes.**

### Task 2.2: `--phase1` forcing rule

**Files:** Modify `lib/blind-judge.sh`; extend `test/test_blind_judge.sh`

- [ ] **Step 1: failing tests.**
  - prepare with 0 judged rows + no `--phase1` → exit 1 with "REFUSES: --phase1 judge-a|judge-b required during Phase 1 (judged_count=0/5)"
  - prepare with 4 judged rows + `--phase1 judge-b` → succeeds (Phase 1, expecting judge B since A would be 1st append for that room)
  - prepare with 6 judged rows + `--phase1 judge-a` → exit 1 with "REFUSES: --phase1 may not be used after Phase 1 (judged_count=6, max 5)"
  - prepare with 6 judged rows + no flag → succeeds

- [ ] **Step 2: implement.** Count judged rows from journal (`jq '[.[]|select(.judge_blinded==true)]|length'`). Per DD §"--phase1 forcing rule (Rev 2)".

- [ ] **Step 3: commit** `feat(blind-judge): prepare subcommand + --phase1 forcing rule`

---

## Chunk 3: parser

The load-bearing piece. 14 golden-bad fixtures must reject; 3 golden-good must pass.

### Task 3.1: parser implementation

**Files:** Extend `lib/blind-judge.sh`; Create `test/fixtures/blind-judge/`; extend `test/test_blind_judge.sh`

- [ ] **Step 1: write 14 golden fixtures.** Each is a complete response that the operator might paste back. Per DD §Parser test-fixtures list. Naming and content matches DD verbatim:
  - `missing-sentinel.txt`, `missing-end.txt`, `missing-reasoning.txt`, `missing-dissent-diff.txt`
  - `no-space.txt`, `caps.txt`, `trailing-ws.txt`, `bad-value.txt`
  - `multi-line-why-wrapped.txt` (must PASS), `multi-line-why-actual.txt` (must FAIL)
  - `missing-evidence.txt`, `evidence-on-false.txt`
  - `evidence-quotes-synthesis.txt` (must FAIL with "EVIDENCE quotes OPERATOR_SYNTHESIS verbatim")
  - `implied-without-implied-by.txt`
  - `valid-true.txt`, `valid-false.txt`, `valid-erasure.txt` (must PASS)

- [ ] **Step 2: failing test.** Drive the parser against all 17 fixtures. Each `*-pass.txt` exit 0 + correct output fields; each `*-fail.txt` exit 1 + error message contains expected substring.

- [ ] **Step 3: implement.** Per DD §Parser code block. Two subtleties:
  - The parser is called with TWO args: `response_text` and `operator_synthesis`. The second is needed for the EVIDENCE self-quote check (`grep -qFx -- "$evidence" <<<"$operator_synthesis"`).
  - `extract_field()` helper handles all multi-line scratchpad sections uniformly.

- [ ] **Step 4: run, all parser tests pass.**

- [ ] **Step 5: commit** `feat(blind-judge): parser + 14 golden fixtures (self-quote check is the BLOCKER fix)`

---

## Chunk 4: record + judge + concurrency (flock)

The mutation path. `record` writes the row; `judge` is `prepare` + stdin read + `record`. Both wrap journal+transcript writes in `flock`.

### Task 4.1: `record` with EVIDENCE source-check + warn-and-confirm

**Files:** Extend `lib/blind-judge.sh`; extend `test/test_blind_judge.sh`

- [ ] **Step 1: failing tests.**
  - `record` on a room that has a journal row → updates `judge_*` fields in place.
  - `record` on a room with NO journal row → writes a judge-only row (uses `journal.sh append-judge-only`).
  - `record` with `--catch true --evidence "X"` where X appears in OPERATOR_SYNTHESIS → exit 1 with self-quote error.
  - `record` second call with DIFFERENT `--catch` value → exit 1 unless `--force` is passed, message "this room already has judge_blinded_catch=true; rerunning with judge_blinded_catch=false — pass --force to override".
  - `record` second call with SAME `--catch` value → exit 0 silently (idempotent).

- [ ] **Step 2: implement.** Subcommand `record` accepts all `--judge-*` flags. Steps:
  1. Validate room has a transcript (`transcript.sh capture` guard exists; reuse).
  2. Read OPERATOR_SYNTHESIS from room's `log.jsonl`.
  3. If `--catch true` AND `--evidence` is set: assert evidence does NOT appear verbatim in OPERATOR_SYNTHESIS.
  4. Acquire `flock -x` on journal file.
  5. Check journal for existing row by room. If exists with same `judge_blinded_catch` → exit 0. If different and no `--force` → exit 1. If different and `--force` → overwrite.
  6. Write `@@from: blind-judge#judge-N` line to transcript (N = count of existing blind-judge lines in this room + 1).
  7. Either `journal.sh append` with `--judge-*` flags (if row exists) OR `journal.sh append-judge-only` (if row missing).
  8. Release lock.

- [ ] **Step 3: run, all tests pass.**

### Task 4.2: `judge` (prepare + read stdin + record)

**Files:** Extend `lib/blind-judge.sh`; extend `test/test_blind_judge.sh`

- [ ] **Step 1: failing test.** Feed a valid response on stdin; assert helper records it and the journal row gets `judge_blinded=true`.

- [ ] **Step 2: implement.** Subcommand `judge <room>` runs `prepare`, then waits on stdin for the response (10 min hard timeout, 5 min reminder with `[r]ecopy/[w]ait/[c]ancel`), parses it, runs `record` with the parsed fields.

- [ ] **Step 3: run.**

### Task 4.3: concurrency stress test

**Files:** Extend `test/test_blind_judge.sh`

- [ ] **Step 1: failing test.** Spawn two `record` invocations on the same room in parallel via `&`; wait both. Assert: journal has exactly one row update (not two), transcript has exactly one `@@from: blind-judge` line, the second invocation either failed with "already recorded" OR succeeded with the same answer (idempotent).

- [ ] **Step 2: implement.** Already done in Task 4.1 step 4 (flock on journal); verify lock granularity is right. If transcript needs its own lock, add `flock` on the room directory.

- [ ] **Step 3: commit** `feat(blind-judge): record + judge + concurrency (flock on journal + room dir)`

---

## Chunk 5: backfill-artifact (rescue legacy rooms)

For the 23 orphaned rooms predating FR9. Idempotent: write `room/artifact.txt` from a supplied path.

### Task 5.1: backfill-artifact

**Files:** Extend `lib/blind-judge.sh`; extend `test/test_blind_judge.sh`

- [ ] **Step 1: failing test.**
  - backfill-artifact on a fresh room → creates `artifact.txt`, content matches `--from`.
  - rerun with same args → no error, content unchanged.
  - rerun with different `--from` → overwrites and prints a one-line `note: artifact replaced` warning.
  - prepare on the backfilled room → succeeds.

- [ ] **Step 2: implement.** Trivial: `cp $from $room/artifact.txt`; print a note if the existing differs from the new.

- [ ] **Step 3: commit** `feat(blind-judge): backfill-artifact for legacy room rescue`

---

## Chunk 6: orchestrator changes — FR9 artifact persistence

The cross-component requirement: orchestrator MUST write the artifact to the room.

### Task 6.1: SKILL.md + portable prompt Step 1

**Files:** Modify `skills/council/SKILL.md`; Modify `prompts/council-orchestrator.md`; Modify `test/test_orchestrator_sync.sh`

- [ ] **Step 1: failing test.** Add to `test/test_orchestrator_sync.sh`:

```bash
# FR9: Step 1 must instruct the orchestrator to write the durable copy to room/artifact.txt
for f in "$A" "$B"; do
  grep -qF 'rooms/council-<slug>/artifact.txt' "$f" || { echo "FAIL: $(basename "$f") missing FR9 durable artifact path"; exit 1; }
done
```

- [ ] **Step 2: implement.** Replace Step 1 in both files with the dual-write spec from DD §FR9 (working `/tmp` copy + durable room copy; `@file:` / `@diff:` pointers allowed for already-durable artifacts).

- [ ] **Step 3: commit** `docs(orchestrator): FR9 — write artifact to room/artifact.txt durable copy`

---

## Chunk 7: rendering — distinct judge line in `transcript.sh show`

### Task 7.1: judge-N rendering

**Files:** Modify `lib/transcript.sh`; Modify `test/test_transcript.sh`

- [ ] **Step 1: failing test.** Capture a transcript with one `@@from: blind-judge#judge-1` line; assert `show` renders it with a distinguishable marker (e.g. prefixed `[JUDGE]` instead of the normal persona name).

- [ ] **Step 2: implement.** In `show`'s awk renderer, detect lines whose `from` field matches `^blind-judge#judge-`; render with a distinct visual prefix.

- [ ] **Step 3: commit** `feat(transcript): distinct rendering for blind-judge#judge-N entries`

---

## Chunk 8: README + integration

### Task 8.1: README update

**Files:** Modify `README.md`

- [ ] **Step 1:** Add a section under "What it actually does" naming the blinded-judge mechanism, linking to issue #1, calling out NFR4 (Tier-3 disclosure) verbatim, and noting the rubric file is at `lib/blind-judge-prompt.v2.txt` (in case readers want to inspect what the judge sees).

- [ ] **Step 2: commit** `docs(README): document blinded-judge mechanism + Tier-3 disclosure`

### Task 8.2: end-to-end smoke

**Files:** Add to `test/test_blind_judge.sh`

- [ ] **Step 1: smoke test.** Set up a room with transcript + journal row + artifact, run `judge` with a piped valid response, assert journal row has all judge_* fields populated correctly AND transcript has the `@@from: blind-judge#judge-1` line.

- [ ] **Step 2: commit** `test(blind-judge): end-to-end smoke`

---

## Chunk 9: Phase 1 operations (post-merge, manual, no code)

These are the operator-procedural steps after the implementation lands. Listed here so they don't get lost.

- [ ] Run the first 5 judged councils with `--phase1 judge-a` then `--phase1 judge-b` (3 same-family, 2 cross-family per PRD-OQ8). Document each.
- [ ] After 5 dual-judged runs land: write `docs/features/blinded-judge/calibration-phase1.md` with the qualitative shape-of-disagreement paragraph (PRD Rev 3 Phase 1).
- [ ] Switch helper to single-judge mode for runs 6+.
- [ ] After 50 single-judged runs: DRI writes `docs/features/blinded-judge/decision-<date>.md` per PRD Decision Process (KPI replacement triggered if agreement <70%).

---

## Acceptance summary (cross-references DD §Acceptance)

- [ ] All 10 existing tests still pass.
- [ ] `test/test_blind_judge.sh` covers: prepare (5 blobs disjoint), 14 golden parser fixtures, --phase1 forcing, record (in-place update + judge-only row + self-quote check + warn-confirm + idempotent), judge (end-to-end), backfill-artifact (idempotent), concurrency (two-terminal race serializes).
- [ ] `test/test_journal.sh` extended for 13 new fields default + roundtrip + judge-only row exclusion.
- [ ] `test/test_transcript.sh` covers distinct rendering of `blind-judge#judge-N`.
- [ ] `test/test_orchestrator_sync.sh` covers FR9 durable artifact path in both SKILL.md and portable prompt.
- [ ] CI green on the implementation PR.
- [ ] `lib/blind-judge-prompt.v2.txt` matches the DD §Canonical rubric verbatim (no drift).
- [ ] Pre-implementation gate (rubric external review) was satisfied by DD Rev 3; reference the comment in the impl PR body.

## Sequenced for v1.1 (per DD Tech Debt)

- CLI shell-out judge (`--auto-claude` / `--auto-gpt` etc.)
- Forcing gate on cadence (if first-10 compliance < 70%)
- Schema migration tool (issue #14 roll-up)
- Multi-judge consensus beyond Phase 1
- Solo + synthesis word-count analysis
- `council_mode` field (if post-hoc analysis ever needs it)
