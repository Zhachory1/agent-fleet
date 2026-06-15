# DD — Blinded-judge sample mechanism

**DD ID:** 20260614-blinded-judge
**Status:** In progress · **Rev 4** (post PR B /council + PR C correctness fixes) · implements PRD Rev 3 · issue #1

> **Rev 4 footnote** (post PR B /council + PR C MAJOR-absorption): documented `judge_phase1`
> as the 14th journal field (issue #23 MAJOR; used by `count_judge_b_rows` for the
> sequencing-exploit guard); clarified `synthesis_word_count` semantics (it captures the LATEST
> `@@from: synthesis` block's word count, not aggregate across rounds — matches the `| last` pick
> in `extract_operator_synthesis`); noted PR C correctness fixes to `enforce_phase1` (distinct
> rooms boundary, not total rows) and `judge` subcommand (per-room lock spanning prepare→record).
**DRI:** Zhach Volker

> **Rev 3 changelog** (rubric-file external review by Gemini, 1 BLOCKER + 4 MAJOR + 2 MINOR):
> rubric bumped to **v2** (filename `lib/blind-judge-prompt.v2.txt`) per its own version-bump
> rule. v1 was never shipped; v2 is the first impl-ready version. Findings absorbed: EVIDENCE
> must quote PERSONA POSITIONS (not operator synthesis) — prevents self-validating loop where
> operator's framing validates itself; rubric ships REASONING + DISSENT_DIFF scratchpad fields
> inside sentinels (zero-shot binary on multi-step task was crippling the LLM); materiality
> clause 2 reworded "would notice" → "would change a future decision or be cited in a postmortem"
> (anchors to outcome events, not subjective reactions); "closely implied" claims require the
> judge to quote the implying SOLO_DECISION line (parallel-shape defense to EVIDENCE); WHY
> contradiction with dissent-erasure resolved (two named cases); typo fixed.
>
> **Rev 2 changelog** (council gate #1: SPLIT 3xSHIP-WITH-CHANGES / 1xBLOCK; CONVERGED at r2;
> 4 BLOCKERs, 11 MAJORs, 6 MINORs absorbed):
> Materiality test EVIDENCE-field fix (docs-dx counter-fixed red-team; judge MUST emit verbatim
> synthesis quote when NET_NEW_CATCH=true; operator-rubric-tuning becomes visible via WHY+EVIDENCE
> drift) · external rubric-file review gate added before implementation PR · FR9 backfill helper
> for the 23 orphaned legacy rooms · council_mode DROPPED entirely (was scope drift past PRD) ·
> --phase1 forcing rule (REFUSES without flag for first 5 runs, REFUSES with flag after run 5) ·
> parser rewritten shellcheck-clean (NET_NEW_CATCH:true/True/whitespace handled) · multi-line WHY
> collapsed-then-checked, not rejected outright · flock added on journal+transcript · @diff:
> snapshot at council-time + refuse-on-rot (no manual replacement) · judge_prompt_sha256 split
> into template_sha256 (drift) + render_sha256 (audit) · rubric-file frontmatter carries attack
> warning in-place · agreement bands marked heuristic-pending-n=50 · dissent-erasure fix: full
> per-persona positions in synthesis blob (judge gets attribution; detection > blinding) ·
> synthesis_word_count added as symmetric confound · banner names model-family pattern · MINORs:
> warn-and-confirm overwrite, SSH no-clipboard auto-detect, blind-judge#judge-N transcript line,
> stats --judged subcommand.

---

# Problem & honest scope

The PRD's full motivation is in [PRD.md](./PRD.md). Recap: every catch-rate number on the
dashboard is self-reported by the author who built the tool. We add a fresh-context LLM judge
that sees only `(artifact, solo_decision, council_synthesis, persona_list)` and returns a binary
NET_NEW_CATCH answer. Stored alongside the self-report, NOT replacing it.

**v1's goal is narrower than "fix the bias"**: introduce a real blinding *boundary*, surface the
self-vs-blind disagreement on the dashboard, and run two calibration phases so the next person
to argue about the headline KPI has something honest to argue from. Operator-side attack surface
(picking a weak judge model, paraphrasing the prompt in-browser, iteratively tuning the rubric to
match intuition) is **acknowledged-not-solved** in v1 — disclosed in PRD NFR3, partially closed
in v1.1 via CLI shell-out. Full elimination is a non-goal here.

---

# Success Metrics

| Type | Measure | Bar |
|---|---|---|
| Primary | self-vs-blind agreement rate | publish with CI; act per PRD Decision Process; do NOT switch KPI before Phase 2 (n≥50) |
| Guard | parse rate of judge response | 100% — `record` refuses on parse failure (no silent garbage) |
| Cost | latency per judged run | ≤60s end-to-end; ≤2min operator overhead |
| Cadence | % runs judged | first 5 dual-judged (Phase 1); ≥20% single-judged thereafter |
| Honesty | calibration deliverable in repo | `docs/features/blinded-judge/calibration-phase1.md` paragraph after first 5 dual-judged runs |

---

# Design

## File layout

```
agent-fleet/
├── lib/
│   ├── blind-judge.sh                       # the helper (NEW)
│   ├── blind-judge-prompt.v1.txt            # canonical rubric, versioned (NEW)
│   └── journal.sh                           # +6 fields, +stats arm (MODIFY)
├── docs/features/blinded-judge/
│   ├── PRD.md                               # Rev 3 (DONE)
│   ├── DD.md                                # this file
│   └── calibration-phase1.md                # written after first 5 dual-judged runs (DEFERRED)
├── skills/council/SKILL.md                  # FR9: write artifact to room (MODIFY)
├── prompts/council-orchestrator.md          # FR9: same (MODIFY)
└── test/
    ├── test_blind_judge.sh                  # NEW
    └── test_journal.sh                      # extend for new fields
```

## Five-blob blinded brief (Rev 3: split COUNCIL_SYNTHESIS into PERSONA_POSITIONS + OPERATOR_SYNTHESIS)

The judge sees exactly five blobs. **Rev 3 splits** what was a single COUNCIL_SYNTHESIS blob in
Rev 2 into PERSONA_POSITIONS and OPERATOR_SYNTHESIS, so the EVIDENCE-source check can prevent
the operator's framing from self-validating (Gemini's rubric-file review BLOCKER):

```
ARTIFACT              ← ~/.claude/agent-chat/rooms/council-<slug>/artifact.txt   (FR9)
SOLO_DECISION         ← extracted from the journal row's solo_decision field
PERSONA_POSITIONS     ← (Rev 3) the @@from: <persona>#r<N> blocks from the room transcript ONLY.
                         Each persona's POSITION block per round, unedited. These are what each
                         reviewer actually said.
OPERATOR_SYNTHESIS    ← (Rev 3) the @@from: synthesis block from the room transcript. This is
                         what the operator wrote AFTER reading the POSITIONS. The judge sees
                         this separately from the POSITIONS so the EVIDENCE field can be
                         constrained to PERSONA_POSITIONS only.
PERSONA_LIST          ← extracted from the journal row's personas field (comma-separated)
```

What the judge does NOT see: the operator's post-hoc catch note (`catch_note` in the journal),
the operator identity, any prior journal state, the prompt that produced the council, or any
earlier version of this rubric. **Note (Rev 2 origin, Rev 3 hardened):** the judge DOES see
per-persona positions (with attribution). Rev 2 traded blinding for the ability to catch
dissent-erasure. Rev 3 hardens the tradeoff by separating PERSONA_POSITIONS from
OPERATOR_SYNTHESIS so the operator's own framing cannot be quoted as evidence of itself.

## Canonical rubric (`lib/blind-judge-prompt.v1.txt`)

Committed as a separate file so it is git-tracked and hash-able. Helper concatenates this rubric
with the four blobs and the sentinel-delimited response template. Stored verbatim so the
rubric-tuning attack from the external review is git-history-visible. **Rev 2:** the rubric file
carries its own attack-warning frontmatter at the top, in-place where any would-be tuner would
edit it.

```
# ============================================================================
# WARNING TO ANY EDITOR OF THIS FILE
# ----------------------------------------------------------------------------
# Any change to this file requires:
#   (a) a PR with a one-paragraph rationale for the change
#   (b) bump the filename to lib/blind-judge-prompt.v<N+1>.txt (do NOT edit in place)
#   (c) acknowledge in the PR that journal.sh stats does NOT pool agreement
#       rates across rubric versions (cross-version pooling is forbidden by spec)
# This file is git-history-visible by design. Tuning the materiality threshold
# to match the author's intuition will be visible in the diff and in the
# version-partitioned agreement-rate breakdown.
# ----------------------------------------------------------------------------
# v2 changelog: EVIDENCE must quote PERSONA_POSITIONS (not operator synthesis) —
# prevents self-validating loop. REASONING + DISSENT_DIFF scratchpads added
# inside sentinels so the LLM can actually run multi-step analysis. Materiality
# clause 2 reworded to anchor on outcome events (future-decision-change or
# postmortem-cite) rather than subjective reactions. "Closely implied" claims
# now require quoting the implying SOLO_DECISION line.
# ============================================================================

You are a blinded auditor of an AI-assisted decision review.

You see FIVE blobs and NOTHING ELSE:
  1. ARTIFACT          — the proposal under review
  2. SOLO_DECISION     — what the operator decided + risks they said they already saw
  3. PERSONA_POSITIONS — the raw per-persona POSITION blocks from each round of the council
                          (these are what each reviewer actually said, unedited)
  4. OPERATOR_SYNTHESIS— what the operator wrote as the council's synthesis (verdict + ranked
                          issues + named dissents). The operator wrote this AFTER reading the
                          POSITIONS. It may under-represent dissent.
  5. PERSONA_LIST      — which review lenses ran (e.g. "ml-scientist, ab-critic, red-team")

You do NOT see: the operator's post-hoc note, the operator's identity, prior reviews, or
any earlier version of this rubric.

Answer ONE binary question:

  Does the council (PERSONA_POSITIONS + OPERATOR_SYNTHESIS taken together) contain at least
  one issue, risk, or recommendation that:
    (a) is NOT already named in SOLO_DECISION's "risks I already see" — OR is named there in a
        way so vague that a reasonable engineer would not act on the SOLO_DECISION line alone,
        AND
    (b) is material to the decision?

Materiality test (apply BOTH):
  - Would a reasonable engineer change a non-trivial decision (verdict, design, sequencing,
    rollout plan) based on this issue?
  - If this issue were omitted and the decision shipped, would it plausibly be the kind of
    issue that a future postmortem or follow-up review would cite as a missed risk?

Use PERSONA_LIST to spot synthesis confabulation: if OPERATOR_SYNTHESIS attributes findings
to lenses that did not run, flag that — it counts as a parsing failure of the synthesis, not
as net-new content.

Use PERSONA_POSITIONS to spot dissent-erasure: claims that appear in a POSITION block but are
missing or materially under-represented in OPERATOR_SYNTHESIS COUNT as net-new content (the
operator's synthesis failed to surface them). You will enumerate these in the DISSENT_DIFF
scratchpad below.

--- HOW TO WORK ---

You are required to produce REASONING and DISSENT_DIFF scratchpads inside the sentinel block
BEFORE emitting the binary decision. The scratchpads exist because the materiality test and
the dissent-diff are multi-step analyses the LLM cannot do well zero-shot.

Return EXACTLY this format. No preamble, no commentary outside the sentinels. The scratchpads
are REQUIRED — a missing REASONING or DISSENT_DIFF field is a parse failure.

===JUDGE OUTPUT===
REASONING: <2-5 sentences. Walk through the two-part materiality test against the strongest
            candidate issue. State which clause(s) hold and which do not. If the candidate
            issue is "closely implied" by SOLO_DECISION, this is where you weigh that.>

DISSENT_DIFF: <one bullet per claim in PERSONA_POSITIONS that is missing or under-represented
               in OPERATOR_SYNTHESIS. Format: "- <persona-name>: <claim summary>". Empty list
               is fine — write "- (none)". Missing field is a parse failure.>

NET_NEW_CATCH: true|false

WHY: <one sentence. Two cases:
      (a) If true due to a content finding: name the specific net-new issue.
      (b) If true due to dissent-erasure: name the persona whose dissent was erased AND the
          specific claim that was under-represented.
      If false: name the closest SOLO_DECISION line that already covers the strongest council
      finding.>

EVIDENCE: <required when NET_NEW_CATCH=true. A verbatim line copied from PERSONA_POSITIONS
           (NOT from OPERATOR_SYNTHESIS) that contains the net-new issue or the erased dissent.
           Quoting OPERATOR_SYNTHESIS here is a parse failure: the synthesis is the operator's
           framing and cannot self-validate. Omit when NET_NEW_CATCH=false.>

IMPLIED_BY: <required ONLY when you claim a council finding was "closely implied" by
             SOLO_DECISION (i.e., when NET_NEW_CATCH=false because the operator already named it).
             A verbatim line copied from SOLO_DECISION that does the implying. Omit otherwise.>

===END===

==== ARTIFACT ====
{ARTIFACT}

==== SOLO_DECISION ====
{SOLO_DECISION}

==== PERSONA_POSITIONS ====
{PERSONA_POSITIONS}

==== OPERATOR_SYNTHESIS ====
{OPERATOR_SYNTHESIS}

==== PERSONA_LIST ====
{PERSONA_LIST}
```

**EVIDENCE field rationale (Rev 2 origin, Rev 3 hardened):** the materiality test's clauses are
operator-defined. docs-dx's Rev 2 fix: require the judge to QUOTE a verbatim line when claiming
net-new — makes operator-side rubric-tuning visible as WHY+EVIDENCE drift. **Gemini's rubric-file
review found the Rev 2 EVIDENCE rule was self-validating**: because both POSITIONS and the
operator's synthesis lived in one COUNCIL_SYNTHESIS blob, the judge could satisfy the requirement
by quoting the operator's own synthesis line, validating the operator's framing with the
operator's framing. **Rev 3 fix:** split the blob into PERSONA_POSITIONS and OPERATOR_SYNTHESIS;
EVIDENCE MUST quote from PERSONA_POSITIONS only. Parser rejects an EVIDENCE line that matches any
line in OPERATOR_SYNTHESIS. The defense remains process-not-technical (PR + version + cross-
version-pooling-forbidden), but the EVIDENCE source restriction closes the self-validating loop.

**REASONING + DISSENT_DIFF rationale (Rev 3):** the v1 rubric banned all reasoning outside the
sentinels, then asked the LLM to apply a two-part materiality test AND a cross-reference dissent
diff zero-shot. Gemini correctly identified this as crippling — the LLM cannot do multi-step
analysis without a scratchpad. Rev 3 adds REASONING (free-form walk-through of the materiality
test) and DISSENT_DIFF (enumerated list of claims-in-POSITIONS-missing-from-SYNTHESIS) inside
the sentinels, before NET_NEW_CATCH. Both are REQUIRED — missing field is a parse failure. The
content is stored in the journal as `judge_reasoning` and `judge_dissent_diff` for audit but
does not affect the binary KPI.

**IMPLIED_BY field (Rev 3, parallel-shape defense):** "closely implied" claims in clause (a)
of the main question are subjective the same way "material" is. Gemini's finding: operator can
argue vague solo-risks cover specific council findings. Fix: when judge claims NET_NEW_CATCH=false
BECAUSE a council finding was already implied in SOLO_DECISION, the judge MUST quote the implying
SOLO_DECISION line in IMPLIED_BY. Same defense shape as EVIDENCE; same visibility property.

## `lib/blind-judge.sh` — surface

```
blind-judge.sh prepare <room> [--synthesis <path>] [--phase1 judge-a|judge-b]
   ↳ assemble the FIVE blobs (Rev 3: PERSONA_POSITIONS extracted from @@from:<persona>#r<N>
     blocks, OPERATOR_SYNTHESIS extracted from @@from:synthesis block), render against
     blind-judge-prompt.v<latest>.txt (currently v2),
     print full prepared prompt to stdout AND copy to clipboard (pbcopy/xclip/SSH-fallback),
     print BOTH SHA256s: judge_template_sha256 (rubric+sentinels only) and
     judge_render_sha256 (full prepared prompt this call),
     print the context-switch banner.

blind-judge.sh record <room> --catch true|false --why "..." [--evidence "..."] \
                              [--implied-by "..."] [--reasoning "..."] [--dissent-diff "..."] \
                              --model-family <claude|gpt|gemini|local-llama|mistral|grok|deepseek|other> \
                              [--template-sha256 <hex>] [--render-sha256 <hex>] \
                              [--phase1 judge-a|judge-b] [--force]
   ↳ validate inputs strictly (FR2 parser, Rev 3 fields: REASONING + DISSENT_DIFF required,
     EVIDENCE required when catch=true AND must not match any line in OPERATOR_SYNTHESIS);
     flock on journal+transcript; write @@from: blind-judge#judge-N to transcript;
     update existing row's judge_* fields OR write judge-only row per FR8;
     warn-and-confirm if row already has DIFFERENT judge answer (unless --force).
   ↳ When invoked via `judge`, the parser does the work; `record` direct invocation accepts
     the parsed fields as flags (for testing + future CLI-shell-out automation).

blind-judge.sh judge <room> [--phase1 judge-a|judge-b]   # PRD FR3 single-command UX
   ↳ prepare + 10min stdin wait (5min reminder offers [r]ecopy/[w]ait/[c]ancel) + parse + record.

blind-judge.sh backfill-artifact <room> --from <path>     # Rev 2: rescue orphaned legacy rooms
   ↳ write <path> contents to ~/.claude/agent-chat/rooms/<room>/artifact.txt; idempotent.
     For rooms created before FR9 landed. Will not recover all 23 legacy rooms
     but recovers any whose source artifact still exists in git or filesystem.
```

`judge` is the path the PRD's FR3 commits to. `prepare` + `record` are kept as separate
subcommands for: testing, automation (a v1.1 CLI shell-out can use them), and the case where
the operator wants the prepared prompt as a file for inspection before pasting.

### --phase1 forcing rule (Rev 2)

The helper detects "current Phase 1 judged-run count" by counting journal rows where
`judge_blinded=true`. Forcing rule:

- **runs 1–5 (Phase 1):** helper REFUSES without `--phase1 judge-a` or `--phase1 judge-b`.
  Operator must explicitly designate. Per-run, helper expects judge-a first; on a re-run for the
  same room, expects judge-b.
- **runs ≥6 (Phase 2):** helper REFUSES with `--phase1` flag present. Phase 1 is over;
  attempting to claim Phase 1 status retroactively is rejected.

No phase detection by journal-state-inspection (per council MAJOR #6 — the previous "helper
figures it out" design was a UX trap).

### The context-switch banner (FR3)

```
⚠ SWITCH CONTEXTS NOW
   Open a NEW chat in a DIFFERENT account, or a DIFFERENT model family
   (Claude/GPT/Gemini/Llama/Mistral/...) — the further from your current
   session, the cleaner the blinding.

   Prompt has been copied to your clipboard (pbcopy/xclip).
   Paste it. Then come back and paste the response below.

   Format expected:
       ===JUDGE OUTPUT===
       NET_NEW_CATCH: true|false
       WHY: ...
       ===END===
```

Visible-but-cheap. Two context switches, not four commands. The blinding is in the operator's
action (switching), not in the helper's UX friction.

## Parser (FR2 strict; Rev 3: REASONING + DISSENT_DIFF + IMPLIED_BY fields, EVIDENCE-source check)

Bash-grep, no jq for parsing the response (jq is for journal append/read). The response is
structured but larger than Rev 2 — still small enough that jq is overkill, but the parser
is now multi-section.

```bash
# die: write a one-line error to stderr and exit 1. Used throughout the helper.
die() { printf 'blind-judge: %s\n' "$*" >&2; exit 1; }

# extract_field BLOCK FIELD STOP_REGEX  -> captures the BLOCK lines between "FIELD:" and the
# first line matching STOP_REGEX (or ===END===). Collapses internal newlines into single spaces.
extract_field() {
    local block="$1" field="$2" stop_re="$3"
    local raw
    raw=$(awk -v F="^${field}:" -v S="^(${stop_re}|===END===):?" '
        $0 ~ F {flag=1; sub(F"[ \t]*", ""); print; next}
        $0 ~ S {flag=0}
        flag {print}' <<<"$block")
    printf '%s' "$raw" | tr '\n' ' ' | tr -s '[:space:]' ' ' | sed 's/[[:space:]]*$//'
}

parse_response() {
    local resp="$1" operator_synthesis="$2"  # Rev 3: operator_synthesis passed for self-quote check
    # 1. sentinels
    grep -q '^===JUDGE OUTPUT===$' <<<"$resp" || die "missing ===JUDGE OUTPUT=== sentinel"
    grep -q '^===END===$' <<<"$resp"           || die "missing ===END=== sentinel"
    local block
    block=$(sed -n '/^===JUDGE OUTPUT===$/,/^===END===$/p' <<<"$resp" | sed '1d;$d')

    # 2. REASONING required (Rev 3)
    local reasoning
    reasoning=$(extract_field "$block" REASONING 'DISSENT_DIFF|NET_NEW_CATCH|WHY|EVIDENCE|IMPLIED_BY')
    [ -n "$reasoning" ] || die "REASONING field required (multi-step materiality test cannot be zero-shot)"

    # 3. DISSENT_DIFF required (may be "- (none)")
    local dissent_diff
    dissent_diff=$(extract_field "$block" DISSENT_DIFF 'NET_NEW_CATCH|WHY|EVIDENCE|IMPLIED_BY')
    [ -n "$dissent_diff" ] || die "DISSENT_DIFF field required (use '- (none)' if no erasures found)"

    # 4. NET_NEW_CATCH true|false (whitespace + case tolerant)
    local catch
    catch=$(awk -F'[: \t]+' '/^NET_NEW_CATCH:/ {print tolower($2); exit}' <<<"$block" |
            tr -d '[:space:]')
    [[ "$catch" =~ ^(true|false)$ ]] || die "NET_NEW_CATCH must be 'true' or 'false', got: $catch"

    # 5. WHY required
    local why
    why=$(extract_field "$block" WHY 'EVIDENCE|IMPLIED_BY')
    [ -n "$why" ] || die "WHY field required"

    # 6. EVIDENCE required iff catch=true; MUST quote from PERSONA_POSITIONS, NOT OPERATOR_SYNTHESIS
    local evidence
    evidence=$(extract_field "$block" EVIDENCE 'IMPLIED_BY')
    if [ "$catch" = "true" ] && [ -z "$evidence" ]; then
        die "EVIDENCE required when NET_NEW_CATCH=true (must quote verbatim line from PERSONA_POSITIONS)"
    fi
    if [ "$catch" = "false" ] && [ -n "$evidence" ]; then
        die "EVIDENCE must be empty when NET_NEW_CATCH=false (got: $evidence)"
    fi
    # Rev 3 self-validation guard: EVIDENCE must NOT appear verbatim in OPERATOR_SYNTHESIS.
    # Quoting the operator's own synthesis to validate the operator's framing is the
    # Rev 2 self-validating-loop failure mode Gemini caught.
    if [ -n "$evidence" ] && grep -qFx -- "$evidence" <<<"$operator_synthesis"; then
        die "EVIDENCE quotes OPERATOR_SYNTHESIS verbatim ('$evidence'); must quote PERSONA_POSITIONS only"
    fi

    # 7. IMPLIED_BY required when catch=false AND WHY references implication; optional otherwise.
    # Heuristic check: if WHY contains the substring 'implied' or 'already' and catch=false,
    # IMPLIED_BY must be present and non-empty. This is a soft check; operator can override
    # by phrasing WHY differently, but the rubric instructs the judge to use IMPLIED_BY when
    # claiming implication so the heuristic catches the common case.
    local implied_by
    implied_by=$(extract_field "$block" IMPLIED_BY '')
    if [ "$catch" = "false" ] && [[ "$why" =~ (implied|already.named|already.covered) ]]; then
        [ -n "$implied_by" ] || die "IMPLIED_BY required when WHY claims SOLO_DECISION already covered the finding"
    fi

    printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$catch" "$why" "$evidence" "$implied_by" "$reasoning" "$dissent_diff"
}
```

Test fixtures under `test/fixtures/blind-judge/` for the parser golden bad cases (Rev 3 list):
- `missing-sentinel.txt` — no `===JUDGE OUTPUT===`
- `missing-end.txt` — no `===END===`
- `missing-reasoning.txt` — **Rev 3:** no REASONING field
- `missing-dissent-diff.txt` — **Rev 3:** no DISSENT_DIFF field
- `no-space.txt` — `NET_NEW_CATCH:true` (no space)
- `caps.txt` — `NET_NEW_CATCH: True`
- `trailing-ws.txt` — `NET_NEW_CATCH: true   `
- `bad-value.txt` — `NET_NEW_CATCH: yes`
- `multi-line-why-wrapped.txt` — legitimate single-sentence wrapped (must PASS)
- `multi-line-why-actual.txt` — two distinct sentences (must FAIL)
- `missing-evidence.txt` — `NET_NEW_CATCH: true` without EVIDENCE
- `evidence-on-false.txt` — `NET_NEW_CATCH: false` with EVIDENCE
- `evidence-quotes-synthesis.txt` — **Rev 3:** EVIDENCE line appears verbatim in
  OPERATOR_SYNTHESIS (must FAIL with self-validation error)
- `implied-without-implied-by.txt` — **Rev 3:** WHY says "already implied" but no IMPLIED_BY
- `valid-true.txt` and `valid-false.txt` and `valid-erasure.txt` (Rev 3: dissent-erasure WHY+EVIDENCE pattern) — golden good

No row mutation, no silent garbage. PRD guard rate: 100%.

## Chain ordering and failure semantics (PRD FR8)

```
council finishes
   │
   ▼
transcript.sh capture       ← step 1: per-persona positions + synthesis to room
   │
   ▼
journal.sh append           ← step 2: self-report row (transcript-guard fires if step 1 missing)
   │
   ▼ (for runs in the judged sample only)
blind-judge.sh judge        ← step 3:
   │                           a. prepare (assemble + paste + banner)
   │                           b. read response from stdin
   │                           c. parse (FR2 strict; reject on failure)
   │                           d. update existing journal row's judge_* fields IF row exists,
   │                              else write a judge-only row (no self-report fields populated)
   │                           e. write @@from: blind-judge line to room transcript
   ▼
done
```

Sub-cases for step 3 when step 2 has failed:

* **Row missing** → write a judge-only row. `judge_blinded=true`, all judge_* fields populated,
  `net_new_catch=null`, `acted_on=null`, etc. Stats counts these separately as "judge-only
  rows: N" so the operator sees journal-append failures piling up.
* **Row exists** → in-place update of `judge_*` fields only. Idempotent for SAME answer;
  warn-and-confirm if a DIFFERENT judge answer is being recorded (operator may have fat-fingered
  the wrong room). `--force` overrides the warning.

No orphaned state: a judged row always has both (a) `judge_blinded=true` AND (b) the
`@@from: blind-judge#judge-N` transcript line — either both or neither.

**Concurrency (Rev 2):** `journal.sh append` and `transcript.sh capture` are wrapped in
`flock` (file-lock on the journal and the room directory respectively). Two terminals running
`judge` on the same room serialize; the second sees the first's write and applies the warn-
and-confirm path. Stress test under `test/test_blind_judge.sh::concurrency`.

## Journal schema changes (PRD FR6, run_kind-style backward compat)

Six PRD fields + six DD additions on each row. Default-when-missing makes legacy rows continue
to work. **Rev 3: added `judge_reasoning`, `judge_dissent_diff`, `judge_implied_by`** (the
rubric's new scratchpad + IMPLIED_BY outputs). **Rev 2 dropped `council_mode`** (was scope
drift past PRD's committed 6).

| Field | Type | Default-if-missing | Notes |
|---|---|---|---|
| `judge_blinded` | bool | `false` | was this run judged? |
| `judge_blinded_catch` | bool\|null | `null` | judge's NET_NEW_CATCH answer |
| `judge_why` | string | `""` | judge's WHY one-liner |
| `judge_evidence` | string | `""` | **Rev 2:** verbatim quote from PERSONA_POSITIONS (Rev 3: source restricted) |
| `judge_implied_by` | string | `""` | **Rev 3:** verbatim quote from SOLO_DECISION when claiming "closely implied" |
| `judge_reasoning` | string | `""` | **Rev 3:** scratchpad walking through materiality test; audit-only, no KPI impact |
| `judge_dissent_diff` | string | `""` | **Rev 3:** enumerated claims-in-POSITIONS-missing-from-SYNTHESIS; audit-only |
| `judge_model_family_self_reported` | string | `""` | operator-supplied; name carries the warning |
| `judge_prompt_version` | string | `null` | e.g. `v2`; null = "before blinded-judge existed" |
| `judge_template_sha256` | string | `""` | **Rev 2:** SHA256 of rubric+sentinels ONLY — drift detection |
| `judge_render_sha256` | string | `""` | **Rev 2:** SHA256 of full prepared prompt this call — per-call audit |
| `solo_decision_word_count` | int | `0` | PRD-OQ3: confound recording |
| `synthesis_word_count` | int | `0` | **Rev 2:** symmetric to solo_decision_word_count. **Rev 4 clarification**: captures the LATEST `@@from: synthesis` block's word count (matches `| last` pick), not aggregate across rounds. Document accordingly; rename deferred to v1.1 if it bites. |
| `judge_phase1` | string | `""` | **Rev 4 (post PR B /council):** operator-supplied flag (`judge-a` / `judge-b`) for Phase 1 dual-judging; written by `record` and read by `count_judge_b_rows` for the >=3 judge-b-of-5 sequencing-exploit guard. Empty/missing for Phase 2 runs. |

(14 new fields total, not 6. PRD FR6's "6 fields" commitment is updated by this DD across
revisions. If PRD FR6 and this table disagree, the DD wins for v1 — PRD predates the
EVIDENCE field, hash-split, symmetric word-count [Rev 2], reasoning, dissent_diff, and
implied_by [Rev 3] discovered through council + external review; `judge_phase1` [Rev 4]
emerged from PR B impl as required for the council-mandated uniqueness exploit guard.)

Schema migration script remains OUT-of-v1 per PRD. Tests assert both legacy rows and
fully-populated rows parse correctly.

## `journal.sh stats` — new arm

Two new lines, plus calibration-phase guard:

```
blinded-judge sample : Y of N runs judged = Z%
self-vs-blind        : X of Y agree = W%   [self-reported model: ...]
                       [calibration phase — N/5 in Phase 1] / [Phase 2: N/50 judged]
```

Calibration-phase logic:

* If `judged_runs < 5` → print `[calibration phase — N/5 Phase 1, dual-judging required via --phase1 judge-a|judge-b]`,
  do NOT print agreement %.
* If `5 ≤ judged_runs < 50` → print `[Phase 2: N/50 judged]`, print agreement % but no band
  interpretation.
* If `judged_runs ≥ 50` → print agreement % with band (90+/70-90/<70) per PRD Phase 2.
  **Rev 2:** the bands themselves are HEURISTIC — round numbers picked before n=50 data exists.
  After the first 50 land, the DRI's one-pager (PRD Decision Process) revisits whether the
  90/70 cuts are still appropriate or should be derived from the Phase 1 noise floor + Nσ.
  This is named in stats output as `bands: heuristic-pending-recalibration`.
* Dual-judged rows (the first 5) contribute to a separate `judge-vs-judge: X/5` line.

Verdict line unchanged — gate is per the existing lens-baseline + catch-rate arms.

If `judge-only rows > 0` (step-2-failed sub-case) print `judge-only rows: N` line so the
operator notices.

## FR9 — Artifact persistence in the room (orchestrator requirement)

The orchestrator's Step 1 currently writes the artifact to `/tmp/council-<slug>.txt`. That is
not durable past a reboot or `/tmp` GC. The judge call may happen days after the council, so
the artifact must live in the room.

**Change to `skills/council/SKILL.md` and `prompts/council-orchestrator.md` Step 1:**

> Identify the artifact under review. Write it to BOTH:
>   * `/tmp/council-<slug>.txt` (working copy, unchanged)
>   * `~/.claude/agent-chat/rooms/council-<slug>/artifact.txt` (durable copy, NEW)
>
> If the artifact is a file path that already exists durably (a committed doc, a git diff
> hash), the durable copy can be a one-line pointer (`@file: <abs-path>` or
> `@diff: <sha-range>`); the helper resolves these at judge-time.

`blind-judge.sh prepare` reads `room/artifact.txt` first. If the file is a `@file:` pointer it
resolves; if a `@diff:` pointer it `git show`s. If `room/artifact.txt` is missing the helper
errors with: "no artifact in room; orchestrator did not persist it. Re-run the council OR
supply `--artifact <path>` to prepare."

Backward compat: old rooms without `artifact.txt` cannot be judged retroactively. Honest
limitation; documented.

---

# Open Questions (resolved in DD)

| # | Q from PRD | Resolution |
|---|---|---|
| PRD-OQ1 | reply format whitespace / multi-line WHY | **Rev 2:** collapse internal newlines into spaces, do NOT reject multi-line outright (pbcopy wrap is legitimate). Multi-distinct-line WHY caught when EVIDENCE: or ===END=== appears mid-block. |
| PRD-OQ2 | (RESOLVED in PRD as FR9) | FR9 implementation above. |
| PRD-OQ3 | solo-decision-quality confound | record `solo_decision_word_count` + (Rev 2) `synthesis_word_count` symmetric confound. |
| PRD-OQ4 | cadence enforced vs documented | documented in v1 (SKILL.md). Forcing gate deferred to v1.1 per PRD. |
| PRD-OQ5 | hash scope | **Rev 2:** split into `judge_template_sha256` (rubric+sentinels, constant per version, drift detection) + `judge_render_sha256` (full prepared prompt, per-call audit). |
| PRD-OQ6 | calibration-phase stats text | two-phase per `stats` arm above, bands marked heuristic-pending-recalibration. |
| PRD-OQ7 | (RESOLVED — persona list IN; **Rev 2:** full per-persona positions also IN, for dissent-erasure detection) | implemented in FR1, parser/rubric use both. |
| PRD-OQ8 | dual-judge family split for Phase 1 | 3 same-family / 2 cross-family for the first 5 dual-judged runs. Recorded as `judge_a_model_family_self_reported` + `judge_b_model_family_self_reported` for those 5 only; collapses to single `judge_model_family_self_reported` from run 6 onward. |
| PRD-OQ9 | judge_prompt_version operations | rubric file is `lib/blind-judge-prompt.v<N>.txt`; helper reads filename to derive version; PR to bump = `git mv` to next N + commit. |

# Open Questions (resolved in Rev 2 via council)

| # | Original DD-OQ | Resolution |
|---|---|---|
| DD-OQ1 | stdin timeout on `judge` | 10min hard, 5min reminder offers `[r]ecopy / [w]ait / [c]ancel`. |
| DD-OQ2 | Phase 1 dual-judging detection | **Resolved Rev 2:** explicit `--phase1 judge-a\|judge-b` flag; helper REFUSES without it for first 5 runs, REFUSES with it after run 5. No state-inspection (was a UX trap). |
| DD-OQ3 | Parser test fixtures location | `test/fixtures/blind-judge/`. 11 fixtures enumerated in Parser section above. |
| DD-OQ4 | No-clipboard fallback | stdout-only with visible banner; auto-detect SSH via `$SSH_CONNECTION` and skip clipboard attempt entirely. |
| DD-OQ5 | `council_mode` field | **Resolved Rev 2:** DROPPED entirely. Was scope drift past PRD's committed schema. Can be inferred from `personas` length + iteration count post-hoc if it ever matters. |

# Acceptance

* `lib/blind-judge.sh prepare|record|judge|backfill-artifact` implemented; parser rejects all
  golden bad fixtures enumerated in the Parser section (14 fixtures per Rev 3).
* `lib/blind-judge-prompt.v2.txt` committed verbatim, with the in-place attack-warning frontmatter
  (v1 was never shipped; v2 is the first impl-ready rubric per Rev 3 external review).
* `lib/journal.sh` schema extended (8 new fields per Rev 2); backward-compat preserved; `stats`
  prints the two-phase arm; `judge-only rows` surfaced when present; `stats --judged` lists
  last 5 judged rows.
* `skills/council/SKILL.md` + `prompts/council-orchestrator.md` Step 1 require artifact persistence
  in the room (FR9).
* `test/test_blind_judge.sh` covers: prepare-without-room-errors, parser-rejects-bad-fixtures,
  record-updates-existing-row, record-writes-judge-only-row-when-no-row-exists, dual-judging
  Phase-1 flow with `--phase1 judge-a|judge-b`, --phase1 forcing rule (refuses without flag for
  first 5; refuses with flag after run 5), warn-and-confirm on different-answer, `--force`
  override, concurrency stress test (two-terminal race serializes via flock), backfill-artifact
  idempotency.
* `test/test_journal.sh` extended: legacy rows parse with all 8 new fields defaulted, fully-
  populated rows round-trip, judge-only rows excluded from agreement calculations.
* CI green on the PR.

**Pre-implementation gate (Rev 2):** the rubric file `lib/blind-judge-prompt.v1.txt` must pass
an external-context review (paste the rubric file alone into a fresh chat in a different model
family; ask for one round of critique against materiality + EVIDENCE-field shortcut surface;
attach result as a comment on the implementation PR). Per council gate #1 BLOCKER #1, scoped
down from a whole-DD review per gen-swe's downscope. Rubric file is the highest-leverage, lowest-
cost external review surface.

# Tech Debt / Deferred (named)

* **CLI shell-out judge** (v1.1) — auto-call `claude` / `llm` / `openai` CLI to remove the paste
  step. Closes the paste-time-tampering gap PRD Rev 3 documented as unsolvable in v1.
* **Forcing gate on cadence** (v1.1) — block `journal.sh append` until judge call completes for
  the first N runs, if v1 cadence-compliance drops below 70%.
* **Schema migration tool** (issue #14 roll-up) — `journal.sh migrate` for any future schema
  change; touched here but deferred.
* **Multi-judge consensus beyond Phase 1** — running every council past 3 judges and majority-
  voting. Defer until n=1 judge proves its keep at Phase 2.
* **Solo + synthesis word-count analysis** — fields recorded in v1; analysis (correlation with
  judge-net-new rate, identify confounds) is v1.1.
* **`council_mode` field** (v1.1+ or never) — dropped from v1 (was scope drift). If post-hoc
  analysis ever wants to separate true-parallel-council judge rates from degraded-solo rates,
  this is the place to add it. Can be inferred from existing fields in the meantime.
