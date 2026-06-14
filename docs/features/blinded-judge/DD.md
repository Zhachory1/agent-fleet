# DD — Blinded-judge sample mechanism

**DD ID:** 20260614-blinded-judge
**Status:** In progress · **Rev 2** (post council gate #1) · implements PRD Rev 3 · issue #1
**DRI:** Zhach Volker

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

## Three-input + persona-list + per-persona-positions blinded brief

The judge sees exactly four blobs (Rev 2: COUNCIL_SYNTHESIS now includes full per-persona
positions, not just the operator's synthesis — fixes dissent-erasure invisibility):

```
ARTIFACT              ← ~/.claude/agent-chat/rooms/council-<slug>/artifact.txt   (FR9, new)
SOLO_DECISION         ← extracted from the journal row's solo_decision field
COUNCIL_SYNTHESIS     ← (Rev 2) FULL room transcript: all @@from: <persona>#r<N> blocks + the
                         operator's @@from: synthesis block. The judge sees both what each
                         persona actually said AND what the operator summarized — enables
                         dissent-erasure detection.
PERSONA_LIST          ← extracted from the journal row's personas field (comma-separated)
```

What the judge does NOT see: the operator's post-hoc catch note (`catch_note` in the journal),
the operator identity, any prior journal state, the prompt that produced the council, any chain
of thought, prior council output, or any earlier version of this rubric. **Note (Rev 2):** the
judge DOES now see per-persona positions (with attribution), trading some blinding for the
ability to catch the operator under-representing a dissenting persona in the synthesis. This
tradeoff was named in council gate #1 — detection of the actual sycophancy failure mode this
feature exists to address requires the judge see the source material, not just the summary.

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
# ============================================================================

You are a blinded auditor of an AI-assisted decision review.

You see exactly four blobs and NOTHING ELSE:
  1. ARTIFACT         — the proposal under review
  2. SOLO_DECISION    — what the operator decided + risks they said they already saw
  3. COUNCIL_SYNTHESIS — the full room transcript: each persona's POSITION block per round,
                          plus the operator's synthesis (verdict + ranked issues + dissents)
  4. PERSONA_LIST     — which review lenses ran (e.g. "ml-scientist, ab-critic, red-team")

You do NOT see: the operator's post-hoc note, the operator's identity, prior reviews,
any chain of thought, or any earlier version of this rubric.

Answer ONE binary question:

  Does COUNCIL_SYNTHESIS contain at least one issue, risk, or recommendation that:
    (a) is NOT already named or closely implied in SOLO_DECISION's "risks I already see", AND
    (b) is material to the decision?

Materiality test (apply BOTH):
  - Would a reasonable engineer change a non-trivial decision (verdict, design, sequencing,
    rollout plan) based on this issue?
  - Would omitting this issue from the synthesis make the synthesis worse in a way that
    someone other than the author would notice?

Use PERSONA_LIST to spot synthesis confabulation: if the synthesis attributes findings to
lenses that did not run, flag that — it counts as a parsing failure of the synthesis, not as
net-new content.

Use PER-PERSONA POSITIONS to spot dissent-erasure: if a persona's POSITION block contains a
claim that is not represented (or is materially under-represented) in the operator's @@from:
synthesis block, that under-represented dissent COUNTS as net-new content — the operator's
synthesis failed to surface it. The judge's WHY should call this out explicitly.

Return EXACTLY this format. No preamble, no scoring, no commentary outside the sentinels:

===JUDGE OUTPUT===
NET_NEW_CATCH: true|false
WHY: <one sentence. If true: name the specific net-new issue. If false: name the closest
      solo↔synthesis pair so the operator can see why you gave no credit.>
EVIDENCE: <required when NET_NEW_CATCH=true; a verbatim line copied from COUNCIL_SYNTHESIS that
           contains the net-new issue. Omit when NET_NEW_CATCH=false.>
===END===

==== ARTIFACT ====
{ARTIFACT}

==== SOLO_DECISION ====
{SOLO_DECISION}

==== COUNCIL_SYNTHESIS ====
{COUNCIL_SYNTHESIS}

==== PERSONA_LIST ====
{PERSONA_LIST}
```

**EVIDENCE field rationale (Rev 2, council BLOCKER #2 fix):** the materiality test's two clauses
are both operator-defined ("reasonable engineer" and "someone other than the author" are
operator-calibrated). docs-dx's fix: require the judge to QUOTE a verbatim synthesis line when
claiming net-new. This makes operator-side rubric-tuning *visible* in the journal as WHY+EVIDENCE
drift (e.g. if the rubric is iteratively tuned to match the operator's intuition, the EVIDENCE
field will start citing increasingly trivial lines). It preserves the judge's utility on design-doc
councils (where red-team's alternative third-clause fix — "quantitative metric / go-no-go /
rollback criterion" — would have killed the judge). The defense is process not technical, but
the EVIDENCE field makes the process VISIBLE.

## `lib/blind-judge.sh` — surface

```
blind-judge.sh prepare <room> [--synthesis <path>] [--phase1 judge-a|judge-b]
   ↳ assemble the four blobs, render against blind-judge-prompt.v<latest>.txt,
     print full prepared prompt to stdout AND copy to clipboard (pbcopy/xclip/SSH-fallback),
     print BOTH SHA256s: judge_template_sha256 (rubric+sentinels only) and
     judge_render_sha256 (full prepared prompt this call),
     print the context-switch banner.

blind-judge.sh record <room> --catch true|false --why "..." [--evidence "..."] \
                              --model-family <claude|gpt|gemini|local-llama|mistral|grok|deepseek|other> \
                              [--template-sha256 <hex>] [--render-sha256 <hex>] \
                              [--phase1 judge-a|judge-b] [--force]
   ↳ validate inputs strictly (FR2 parser, Rev 2 EVIDENCE required when catch=true);
     flock on journal+transcript; write @@from: blind-judge#judge-N to transcript;
     update existing row's judge_* fields OR write judge-only row per FR8;
     warn-and-confirm if row already has DIFFERENT judge answer (unless --force).

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

## Parser (FR2 strict; Rev 2: shellcheck-clean + EVIDENCE field)

Bash-grep, no jq for parsing the response (jq is for journal append/read). The response is
small and structured; jq for that is overkill.

```bash
# die: write a one-line error to stderr and exit 1. Used throughout the helper.
die() { printf 'blind-judge: %s\n' "$*" >&2; exit 1; }

parse_response() {
    local resp="$1"
    # 1. must contain ===JUDGE OUTPUT=== AND ===END=== sentinels
    grep -q '^===JUDGE OUTPUT===$' <<<"$resp" || die "missing ===JUDGE OUTPUT=== sentinel"
    grep -q '^===END===$' <<<"$resp"           || die "missing ===END=== sentinel"
    # 2. extract just the block between sentinels (defends against the synthesis containing
    #    a literal NET_NEW_CATCH: true substring)
    local block
    block=$(sed -n '/^===JUDGE OUTPUT===$/,/^===END===$/p' <<<"$resp" |
            sed '1d;$d')
    # 3. NET_NEW_CATCH line must exist and be true|false (Rev 2: tolerate whitespace + case)
    local catch
    catch=$(awk -F'[: \t]+' '/^NET_NEW_CATCH:/ {print tolower($2); exit}' <<<"$block" |
            tr -d '[:space:]')
    [[ "$catch" =~ ^(true|false)$ ]] || die "NET_NEW_CATCH must be 'true' or 'false', got: $catch"
    # 4. WHY must exist; collapse any wrap-newlines inside the WHY value into spaces
    #    (Rev 2: pbcopy/pbpaste wraps long lines; legitimate single-sentence WHY can arrive
    #     multi-line; we collapse rather than reject)
    local why_raw why
    why_raw=$(awk '/^WHY:/{flag=1; sub(/^WHY:[ \t]*/, ""); print; next}
                   /^(EVIDENCE|===END===):?/{flag=0}
                   flag{print}' <<<"$block")
    why=$(printf '%s' "$why_raw" | tr '\n' ' ' | tr -s '[:space:]' ' ' | sed 's/[[:space:]]*$//')
    [ -n "$why" ] || die "WHY line missing or empty"
    # 5. EVIDENCE required if catch=true; omitted if catch=false (Rev 2: BLOCKER #2 fix)
    local evidence_raw evidence
    evidence_raw=$(awk '/^EVIDENCE:/{flag=1; sub(/^EVIDENCE:[ \t]*/, ""); print; next}
                        /^===END===$/{flag=0}
                        flag{print}' <<<"$block")
    evidence=$(printf '%s' "$evidence_raw" | tr '\n' ' ' | tr -s '[:space:]' ' ' | sed 's/[[:space:]]*$//')
    if [ "$catch" = "true" ] && [ -z "$evidence" ]; then
        die "EVIDENCE required when NET_NEW_CATCH=true (must quote verbatim line from COUNCIL_SYNTHESIS)"
    fi
    if [ "$catch" = "false" ] && [ -n "$evidence" ]; then
        die "EVIDENCE must be empty when NET_NEW_CATCH=false (got: $evidence)"
    fi
    printf '%s\n%s\n%s\n' "$catch" "$why" "$evidence"
}
```

Test fixtures under `test/fixtures/blind-judge/` for the parser golden bad cases:
- `missing-sentinel.txt` — no `===JUDGE OUTPUT===`
- `missing-end.txt` — no `===END===`
- `no-space.txt` — `NET_NEW_CATCH:true` (no space after colon)
- `caps.txt` — `NET_NEW_CATCH: True`
- `trailing-ws.txt` — `NET_NEW_CATCH: true   ` (trailing whitespace)
- `bad-value.txt` — `NET_NEW_CATCH: yes`
- `multi-line-why-wrapped.txt` — legitimate single-sentence wrapped by pbcopy (must PASS)
- `multi-line-why-actual.txt` — two distinct sentences with explicit newlines (must FAIL,
  detected because EVIDENCE: or ===END=== appears mid-WHY block)
- `missing-evidence.txt` — `NET_NEW_CATCH: true` without EVIDENCE
- `evidence-on-false.txt` — `NET_NEW_CATCH: false` with EVIDENCE present
- `valid-true.txt` and `valid-false.txt` — golden good

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

Six PRD fields + two DD additions on each row. Default-when-missing makes legacy rows continue
to work. **Rev 2: dropped `council_mode`** (was scope drift past PRD's committed 6).

| Field | Type | Default-if-missing | Notes |
|---|---|---|---|
| `judge_blinded` | bool | `false` | was this run judged? |
| `judge_blinded_catch` | bool\|null | `null` | judge's NET_NEW_CATCH answer |
| `judge_why` | string | `""` | judge's WHY one-liner |
| `judge_evidence` | string | `""` | **Rev 2:** judge's EVIDENCE verbatim quote (when catch=true) |
| `judge_model_family_self_reported` | string | `""` | operator-supplied; name carries the warning |
| `judge_prompt_version` | string | `null` | e.g. `v1`; null = "before blinded-judge existed" |
| `judge_template_sha256` | string | `""` | **Rev 2:** SHA256 of rubric+sentinels ONLY — drift detection (constant across runs of same version) |
| `judge_render_sha256` | string | `""` | **Rev 2:** SHA256 of full prepared prompt this call — per-call audit |
| `solo_decision_word_count` | int | `0` | PRD-OQ3: confound recording |
| `synthesis_word_count` | int | `0` | **Rev 2:** symmetric to solo_decision_word_count |

(8 new fields, not 6. Rev 2 added `judge_evidence`, split `judge_prompt_sha256` into
`judge_template_sha256`+`judge_render_sha256`, added `synthesis_word_count`. The PRD's "6
fields" commitment is updated by this DD; if you read this and PRD FR6's number disagree, the
DD wins for v1 because PRD was written before the EVIDENCE field, hash-split, and symmetric
word-count were discovered in council gate #1.)

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

* `lib/blind-judge.sh prepare|record|judge|backfill-artifact` implemented; parser rejects all 11
  golden bad fixtures enumerated in the Parser section.
* `lib/blind-judge-prompt.v1.txt` committed verbatim, with the in-place attack-warning frontmatter.
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
