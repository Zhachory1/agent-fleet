# Blinded-judge — Implementation Plan

> **For agentic workers:** REQUIRED: TDD per chunk — failing test FIRST, then minimum code to pass, then refactor. Steps use checkbox (`- [ ]`) syntax. Where this PLAN spec text conflicts with DD Rev 3, DD wins; if you find such a conflict, **open a `plan-dd-conflict` tagged issue AND comment on the implementation PR** (not just "flag it" — a tracked surface).

**Status:** **Rev 2** (post council gate on PLAN PR #19, SPLIT, red-team BLOCK; 22 findings absorbed). Implements issue #1; **merging the impl PR does NOT close #1** (issue #20 tracks Phase 1 operations + DRI decision; #1 closes only when both land).

**Goal:** Ship the v1 blinded-judge mechanism per PRD Rev 3 + DD Rev 3.

**Architecture:** New `lib/blind-judge.sh` helper (prepare/record/judge/backfill-artifact subcommands) + canonical rubric `lib/blind-judge-prompt.v2.txt` + journal schema +13 fields + `stats` two-phase arm. Orchestrator edits (SKILL.md + portable prompt) for FR9 artifact persistence ship in a **SEPARATE PR sequenced BEFORE the impl PR** (council BLOCKER: every-future-council behavior change deserves its own blast radius). 14+ parser golden fixtures + concurrency stress test.

**Tech Stack:** bash + jq + flock. No new runtime dependency. Paste-and-record UX (no CLI shell-out in v1 per PRD).

> **Rev 2 changelog** (council gate, 3 BLOCKERs + 10 MAJORs + 9 MINORs absorbed):
> Chunk 9 moved to tracking **issue #20** (impl-PR merge no longer closes #1) · Chunk 6
> (orchestrator FR9 edit) becomes its **own PR sequenced BEFORE impl** (every-future-council
> behavior change) · Chunk 1 narrowed to `--judge-*` kw-args only (avoids scope conflict with
> issue #3) · backfill-artifact requires git-tracked source OR `--i-confirm` (closes the
> confabulation surface that reopened pointer-rot) · --phase1 sequencing exploit closed (need
> ≥5 distinct rooms + ≥3 judge-b) · Chunk 0 CI lint: `diff` rubric vs DD canonical block ·
> fixture content sketches added · word-counts both auto-computed (no operator flag) ·
> 3-sources-of-truth in prepare: spec'd authoritative source + warn on disagreement ·
> `calibration-phase1.template.md` ships in Chunk 0 · data-quality invariants tested ·
> PR packaging strategy named explicitly · abstraction-boundary comment in journal.sh ·
> rollback note + per-journal-file scope note · schema-count narrative corrected · README
> step split.

---

## File map

```
lib/blind-judge.sh                          CREATE  prepare|record|judge|backfill-artifact subcommands + parser
lib/blind-judge-prompt.v2.txt               CREATE  canonical rubric (matches DD canonical block byte-for-byte modulo whitespace)
lib/journal.sh                              MODIFY  +13 fields, --judged subcommand, two-phase stats arm, --judge-* kw-args ONLY (no scope-grab vs #3)
lib/transcript.sh                           MODIFY  render @@from: blind-judge#judge-N with distinct visual
skills/council/SKILL.md                     MODIFY  Step 1: durable artifact write to room/artifact.txt (FR9) — SEPARATE PR
prompts/council-orchestrator.md             MODIFY  mirror Step 1 change — SEPARATE PR
docs/features/blinded-judge/
  calibration-phase1.template.md            CREATE  template with required headings for Phase 1 paragraph
test/test_blind_judge.sh                    CREATE  parser fixtures + chain semantics + concurrency + invariants
test/fixtures/blind-judge/                  CREATE  17 fixtures (14 bad + 3 good, content per Chunk 3)
test/test_journal.sh                        MODIFY  +13 fields default + roundtrip + judge-only-row exclusion + invariants
test/test_transcript.sh                     MODIFY  blind-judge#judge-N rendering
test/test_rubric_canonical.sh               CREATE  CI lint: rubric file diff-matches DD canonical code block
```

## PR packaging strategy (Rev 2)

Council BLOCKER: spec the packaging up front, do not punt it.

1. **PR A — orchestrator FR9** (Chunk 6 only): SKILL.md + portable prompt Step 1 edits to write the durable room artifact. ≤5 lines diff in 2 files. Merges FIRST so subsequent impl can read `room/artifact.txt`.
2. **PR B — impl critical path** (Chunks 0–4 + Chunk 7): rubric file, journal schema, prepare, parser, record/judge/concurrency, transcript rendering. The MVP-shaped slice that lands the actual mechanism.
3. **PR C — follow-up** (Chunks 5, 8): backfill-artifact + README + end-to-end smoke. Lower-risk, sequence after PR B passes CI on a real judged run.
4. **Issue #20 — Phase 1 operations + DRI decision** (Chunk 9): tracking issue, NOT code. Impl-PR merge does NOT close #1.

---

## Chunk 0: canonical rubric + Phase 1 template + CI lint (no code; ship contracts first)

The rubric file is the contract everything else implements against. Land it first so subsequent chunks reference a real file. Plus the Phase 1 template (issue #20 needs it ready) and a CI lint asserting the rubric stays in sync with DD's canonical code block.

### Task 0.1: write `lib/blind-judge-prompt.v2.txt`

**Files:** Create `lib/blind-judge-prompt.v2.txt`

- [ ] **Step 1: extract verbatim from DD Rev 3 §Canonical rubric.** The DD ships the rubric text as a fenced code block. Copy it verbatim into `lib/blind-judge-prompt.v2.txt` (the fenced ` ``` ` boundaries are NOT part of the file). Include the `# ============` attack-warning frontmatter.

- [ ] **Step 2: sanity-check the file has all required tokens** (kept as a dev-time check; the canonical lint is Task 0.3):

```bash
for tok in 'WARNING TO ANY EDITOR' 'v2 changelog' 'PERSONA_POSITIONS' 'OPERATOR_SYNTHESIS' \
           'PERSONA_LIST' 'REASONING' 'DISSENT_DIFF' 'NET_NEW_CATCH' 'WHY' 'EVIDENCE' \
           'IMPLIED_BY' '===JUDGE OUTPUT===' '===END===' '{ARTIFACT}' '{SOLO_DECISION}'; do
  grep -qF "$tok" lib/blind-judge-prompt.v2.txt || { echo "FAIL: missing $tok"; exit 1; }
done
echo "rubric tokens OK"
```

- [ ] **Step 3: commit** `chore(blinded-judge): canonical rubric v2.txt (post external review)`

### Task 0.2: write `docs/features/blinded-judge/calibration-phase1.template.md`

**Files:** Create `docs/features/blinded-judge/calibration-phase1.template.md`

Council MAJOR finding: future-operator amnesia. Without a template, the calibration paragraph defaults to "agreement looked OK." Required headings + 1-line description per heading.

- [ ] **Step 1: write the template** with these sections (each: heading + 1-line description of what goes here):
  - `## Sample` — list the 5 council slugs and which family pair each used (claude/claude, claude/gpt, etc.)
  - `## Disagreement count and shape` — N pairs where judge-a and judge-b disagreed; describe each one ("council X: A said true, B said false because...")
  - `## Concentration analysis` — do disagreements concentrate in: long synthesis, short synthesis, specific personas, specific issue severities?
  - `## Same-family vs cross-family` — did the 3 same-family pairs agree more than the 2 cross-family pairs? If so, by how much?
  - `## Implications for Phase 2` — one paragraph naming the band the agreement rate likely falls into AND any rubric-version-bump candidates the qualitative analysis surfaced.

- [ ] **Step 2: commit** `chore(blinded-judge): calibration-phase1.template.md (issue #20)`

### Task 0.3: CI lint — rubric file matches DD canonical block

**Files:** Create `test/test_rubric_canonical.sh`

Council MAJOR finding (red-team, downgraded from BLOCKER): token-grep is loose. A future implementer paraphrasing the rubric would pass `grep` but not `diff`. The right defense is a CI lint.

- [ ] **Step 1: failing test.** `test/test_rubric_canonical.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
DD="$DIR/docs/features/blinded-judge/DD.md"
RUBRIC="$DIR/lib/blind-judge-prompt.v2.txt"
[ -f "$RUBRIC" ] || { echo "FAIL: rubric file missing"; exit 1; }
# Extract the first fenced code block under '## Canonical rubric' header.
EXTRACTED=$(awk '
  /^## Canonical rubric/ {in_section=1; next}
  in_section && /^```$/ && !in_code {in_code=1; next}
  in_section && in_code && /^```$/ {in_code=0; in_section=0; exit}
  in_section && in_code {print}
' "$DD")
# Compare with whitespace normalized (trailing whitespace + blank-line runs collapsed).
norm() { sed 's/[[:space:]]*$//' | cat -s; }
diff <(printf '%s\n' "$EXTRACTED" | norm) <(norm < "$RUBRIC") \
  || { echo "FAIL: rubric file drifts from DD canonical block (above diff)"; exit 1; }
echo "PASS test_rubric_canonical"
```

- [ ] **Step 2: ensure the rubric file passes the lint.** (After Task 0.1, the file should match DD's code block; the lint is the assertion.)

- [ ] **Step 3: commit** `test(blinded-judge): CI lint asserting rubric file matches DD canonical block`

---

## Chunk 1: journal schema (additive, backward-compat) — narrow `--judge-*` kw-args only

13 new fields per DD Rev 3. Run_kind-style backward compat — missing field → default. Tests assert legacy rows unchanged.

**Council BLOCKER #3 (gen-swe):** original PLAN extended `journal.sh append` outside the scope of issue #3 (which exists to design exactly that kw-arg refactor). Rev 2: this chunk introduces `--judge-*` flags ONLY — a narrow, scoped kw-arg parser — and explicitly leaves general-purpose kw-args (everything other than `--judge-*`) for issue #3 to handle later. The positional contract for the first 12 args stays unchanged.

**Council MAJOR (data-engineer):** both word counts auto-computed; operator does not pass `--synthesis-word-count`. `solo_decision_word_count` from `$3` (the existing positional); `synthesis_word_count` from the room's @@from: synthesis block at append time.

**Council MINOR (software-architect):** add a one-paragraph comment at the top of `journal.sh` naming the contract: `blind-judge.sh` reads `judge_*` fields from this file's row format; field-name changes are breaking changes.

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

  - `append`: accept new `--judge-*` flags AFTER the existing 12 positional args (**Rev 2: narrow to `--judge-*` ONLY** — no other kw-args; issue #3 handles general case). Default missing flags to legacy values (judge_blinded=false, etc.). **Both word counts auto-computed** (per council MAJOR): `solo_decision_word_count` from `$3`; `synthesis_word_count` from the @@from: synthesis block of the room's `log.jsonl`.
  - New subcommand `append-judge-only <room> <task> --judge-* ...`: writes a fresh row with all self-report fields NULL and judge_* fields populated. Used by step 3 of the chain when step 2 failed (per DD FR8).

  Both wrap their write in `flock -x "$AGENT_FLEET_JOURNAL.lock"`. **Rev 2:** flock added in Chunk 1, not deferred to Chunk 4 (council MAJOR: tests in Chunk 1 would race without it).

  **Data-quality invariants** (council MAJOR, data-engineer): asserted at write time.
  - `judge_blinded=false` ⇒ all other `judge_*` fields empty/null.
  - `judge_blinded_catch=true` ⇒ `judge_evidence` non-empty.
  - `judge_blinded_catch=false` ⇒ `judge_evidence` empty.
  Append refuses with a one-line error if invariants violated.

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

- [ ] **Step 2b: source-of-truth contract** (council MAJOR, software-architect + data-engineer compounded):
  - **Room is authoritative.** `room/artifact.txt` + `room/log.jsonl` are the canonical state.
  - `/tmp/council-<slug>.txt` is a working-copy advisory — if present AND it differs from `room/artifact.txt`, print a one-line warning but proceed using the room copy.
  - Journal row's `solo_decision` is REQUIRED. If missing OR the row is missing entirely, `prepare` refuses with `"no solo_decision in journal for room <slug>; run journal.sh append first OR pass --solo-decision explicitly"`.

- [ ] **Step 3: run, prepare-test passes.**

### Task 2.2: `--phase1` forcing rule

**Files:** Modify `lib/blind-judge.sh`; extend `test/test_blind_judge.sh`

- [ ] **Step 1: failing tests.**
  - prepare with 0 judged rows + no `--phase1` → exit 1 with "REFUSES: --phase1 judge-a|judge-b required during Phase 1 (judged_count=0/5)"
  - prepare with 4 judged rows + `--phase1 judge-b` → succeeds (Phase 1, expecting judge B since A would be 1st append for that room)
  - prepare with 6 judged rows + `--phase1 judge-a` → exit 1 with "REFUSES: --phase1 may not be used after Phase 1 (judged_count=6, max 5)"
  - prepare with 6 judged rows + no flag → succeeds

- [ ] **Step 2: implement.** Count judged rows from journal (`jq '[.[]|select(.judge_blinded==true)]|length'`). Per DD §"--phase1 forcing rule (Rev 2)".

  **Rev 2 hardening (council MAJOR, red-team + data-engineer):** the count is insufficient. Also enforce:
  - The 5 judged rows must come from **≥5 distinct rooms** (no using the same council twice to fake Phase 1 progress).
  - **≥3 of the 5 judged rows must have `--phase1 judge-b`** (so the operator can't fake Phase 1 by running judge-a five times).

  Closes the "5 calls all judge-a" sequencing exploit.

  **Rev 2 scope note** (council MINOR, software-architect): the phase count is per-`AGENT_FLEET_JOURNAL` file. Switching journals (different env var) resets the phase counter. Document this in the helper's `--help`.

- [ ] **Step 3: commit** `feat(blind-judge): prepare subcommand + --phase1 forcing rule`

---

## Chunk 3: parser

The load-bearing piece. 14 golden-bad fixtures must reject; 3 golden-good must pass.

### Task 3.1: parser implementation

**Files:** Extend `lib/blind-judge.sh`; Create `test/fixtures/blind-judge/`; extend `test/test_blind_judge.sh`

- [ ] **Step 1: write 17 golden fixtures.** Each is a complete response that the operator might paste back. Per DD §Parser test-fixtures list. Naming, content sketch, and expected behavior:

  **Bad fixtures (14, must FAIL):**
  - `missing-sentinel.txt` — valid response with the opening `===JUDGE OUTPUT===` line removed; expect "missing ===JUDGE OUTPUT=== sentinel"
  - `missing-end.txt` — valid response with closing `===END===` removed; expect "missing ===END=== sentinel"
  - `missing-reasoning.txt` — valid response with the REASONING section omitted; expect "REASONING field required"
  - `missing-dissent-diff.txt` — valid response with DISSENT_DIFF omitted; expect "DISSENT_DIFF field required"
  - `no-space.txt` — `NET_NEW_CATCH:true` (no space after colon); expect parse-pass (the parser is whitespace-tolerant); content also includes proof the catch is correctly extracted as `true`
  - `caps.txt` — `NET_NEW_CATCH: True` (capitalized); expect parse-pass via `tolower()` and value-check passes
  - `trailing-ws.txt` — `NET_NEW_CATCH: true   ` (3 trailing spaces); expect parse-pass
  - `bad-value.txt` — `NET_NEW_CATCH: yes`; expect "NET_NEW_CATCH must be 'true' or 'false', got: yes"
  - `multi-line-why-wrapped.txt` — legitimate single-sentence WHY that pbcopy wrapped across 2 lines (no EVIDENCE/END mid-block); **must PASS** — the parser collapses newlines into spaces
  - `multi-line-why-actual.txt` — two distinct sentences in WHY (with EVIDENCE field appearing after the wrap); **must FAIL** since EVIDENCE: appears mid-WHY block
  - `missing-evidence.txt` — `NET_NEW_CATCH: true` without an EVIDENCE field; expect "EVIDENCE required when NET_NEW_CATCH=true"
  - `evidence-on-false.txt` — `NET_NEW_CATCH: false` with a non-empty EVIDENCE field; expect "EVIDENCE must be empty when NET_NEW_CATCH=false"
  - `evidence-quotes-synthesis.txt` — `NET_NEW_CATCH: true` and EVIDENCE line that appears verbatim in the OPERATOR_SYNTHESIS argument passed to `parse_response`; expect "EVIDENCE quotes OPERATOR_SYNTHESIS verbatim" (this is the Gemini BLOCKER fix)
  - `implied-without-implied-by.txt` — `NET_NEW_CATCH: false` and WHY contains "already implied" but IMPLIED_BY field is missing; expect "IMPLIED_BY required when WHY claims SOLO_DECISION already covered"

  **Good fixtures (3, must PASS):**
  - `valid-true.txt` — catch=true, EVIDENCE from PERSONA_POSITIONS, REASONING + DISSENT_DIFF populated. Parser returns (true, why, evidence, "", reasoning, dissent_diff).
  - `valid-false.txt` — catch=false, no EVIDENCE, REASONING explains why solo covered, DISSENT_DIFF says "- (none)".
  - `valid-erasure.txt` — catch=true due to dissent-erasure; WHY names the persona + claim; EVIDENCE from that persona's POSITION block; DISSENT_DIFF lists the claim.

**Council MAJOR (red-team):** parser fixtures cover PARSER failures, not JUDGE-semantic failures (catch=false + WHY-claims-true; EVIDENCE paraphrased-from-synthesis-but-found-in-positions). **Explicitly deferred to v1.1** as "semantic-incoherence fixture category" — too expensive to fully cover in v1; flagged in tech debt.

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

**Council MAJOR (data-engineer):** backfill is a confabulation surface. Operator could backfill with `/tmp/random-notes.txt` and the judge would treat fabricated content as the original artifact. Same shape as the @diff: pointer-rot risk DD Rev 2 closed for orchestrator-time — reopens here unless constrained.

### Task 5.1: backfill-artifact with confabulation guard

**Files:** Extend `lib/blind-judge.sh`; extend `test/test_blind_judge.sh`

- [ ] **Step 1: failing test.**
  - backfill-artifact on a fresh room with `--from <git-tracked-path>` → creates `artifact.txt`, content matches.
  - backfill-artifact with `--from <not-git-tracked>` AND no `--i-confirm-this-is-the-original` → exit 1 with message instructing the operator to use one of the two paths.
  - backfill-artifact with `--from <not-git-tracked>` AND `--i-confirm-this-is-the-original` → succeeds; the journal-row's `judge_*` rows for this room will carry an additional flag `backfill_confirmed_by_operator=true` (parseable from the transcript line).
  - rerun with same args (same content) → no error, content unchanged.
  - rerun with different `--from` content → overwrites and prints a one-line `note: artifact replaced` warning.
  - prepare on the backfilled room → succeeds.

- [ ] **Step 2: implement.** Constraint: `--from` must be either (a) `git cat-file -e <ref>` passes (it's a tracked commit/blob), OR (b) operator passes `--i-confirm-this-is-the-original`. Default refuses arbitrary paths with `"refuse: --from must be git-tracked OR pass --i-confirm-this-is-the-original (paste-time confabulation surface)"`.

- [ ] **Step 3: commit** `feat(blind-judge): backfill-artifact with confabulation guard (git-tracked or --i-confirm)`

---

## Chunk 6: orchestrator changes — FR9 artifact persistence (SHIPS AS PR A, BEFORE PR B)

The cross-component requirement: orchestrator MUST write the artifact to the room.

**Council BLOCKER #2 (software-architect):** this chunk changes every-future-council behavior. It must be its own PR sequenced BEFORE the impl PR. Implementation depends on the orchestrator writing `room/artifact.txt`; that dependency makes the sequencing self-enforcing.

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

## Chunk 9: Phase 1 operations — MOVED TO TRACKING ISSUE #20

**Council BLOCKER #1 (red-team):** burying the actual feature work as checkboxes in a merged PLAN doc would never get checked. Phase 1 operations + the DRI decision land at **issue #20**, not here.

This PLAN ships **code**. Issue #20 tracks the **operations**. Issue #1 closes only when BOTH:
  - code merge (impl PR for Chunks 0-4 + 7; follow-up PR for Chunks 5, 8)
  - operations close (5 Phase 1 dual-judged councils + calibration-phase1.md + 50 Phase 2 single-judged councils + DRI decision-<date>.md)

**Rollback note** (council MINOR, red-team): if the Phase 2 agreement rate falls in the `<70%` band per PRD Decision Process, the DRI's decision is to **switch the canonical KPI from self-report to blinded**, NOT to remove the feature. There is no automatic rollback; the DRI is the decision-maker. This note exists so the question "do we kill it?" has a documented answer.

---

## Acceptance summary (cross-references DD §Acceptance)

- [ ] All 10 existing tests still pass.
- [ ] `test/test_blind_judge.sh` covers: prepare (5 blobs disjoint + source-of-truth disagreement warning), 17 golden parser fixtures (14 bad + 3 good), --phase1 forcing + uniqueness exploit guard, record (in-place update + judge-only row + self-quote check + warn-confirm + idempotent + invariant checks), judge (end-to-end), backfill-artifact (git-tracked OR --i-confirm), concurrency (two-terminal race serializes via flock).
- [ ] `test/test_journal.sh` extended for 13 new fields default + roundtrip + judge-only row exclusion + data-quality invariants.
- [ ] `test/test_transcript.sh` covers distinct rendering of `blind-judge#judge-N`.
- [ ] `test/test_orchestrator_sync.sh` covers FR9 durable artifact path in both SKILL.md and portable prompt (PR A only).
- [ ] `test/test_rubric_canonical.sh` asserts `diff` between rubric file and DD canonical code block is empty modulo whitespace.
- [ ] CI green on all three PRs (A: orchestrator FR9, B: impl critical path, C: follow-up).
- [ ] `lib/blind-judge-prompt.v2.txt` matches the DD §Canonical rubric verbatim (CI lint enforces).
- [ ] Pre-implementation gate (rubric external review) was satisfied by DD Rev 3; reference the comment in PR B's body.
- [ ] Issue #20 (Phase 1 operations + DRI decision) is **explicitly NOT in the impl PR's close-list**. Impl PR merge does not close #1; only issue #20 closing closes #1.

## Sequenced for v1.1 (per DD Tech Debt + council Rev 2)

- CLI shell-out judge (`--auto-claude` / `--auto-gpt` etc.)
- Forcing gate on cadence (if first-10 compliance < 70%)
- Schema migration tool (issue #14 roll-up)
- Multi-judge consensus beyond Phase 1
- Solo + synthesis word-count analysis
- `council_mode` field (if post-hoc analysis ever needs it)
- **Semantic-incoherence fixture category** (council MAJOR, red-team): fixtures for judge-side semantic failures (catch=false + WHY-claims-true; EVIDENCE paraphrased-from-synthesis-but-found-in-positions). Not parser-rejectable; would be flagged in stats. Out of v1; named here so it doesn't drift back as a surprise.
