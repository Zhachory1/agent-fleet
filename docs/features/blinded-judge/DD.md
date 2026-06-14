# DD — Blinded-judge sample mechanism

**DD ID:** 20260614-blinded-judge
**Status:** In progress · **Rev 1** · implements PRD Rev 3 · issue #1
**DRI:** Zhach Volker

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

## Three-input + persona-list blinded brief

The judge sees exactly four blobs, assembled by the helper from artifacts the orchestrator
already wrote (or will write per FR9):

```
ARTIFACT              ← ~/.claude/agent-chat/rooms/council-<slug>/artifact.txt   (FR9, new)
SOLO_DECISION         ← extracted from the journal row's solo_decision field
COUNCIL_SYNTHESIS     ← extracted from the room's transcript (last @@from: synthesis block,
                         OR operator-supplied via --synthesis <path> if no synthesis was captured)
PERSONA_LIST          ← extracted from the journal row's personas field (comma-separated)
```

What the judge does NOT see: per-persona positions, the operator's post-hoc catch note, the
operator identity, any prior journal state, the prompt that produced the council, any chain of
thought, prior council output, or any earlier version of this rubric.

## Canonical rubric (`lib/blind-judge-prompt.v1.txt`)

Committed as a separate file so it is git-tracked and hash-able. Helper concatenates this rubric
with the four blobs and the sentinel-delimited response template. Stored verbatim so the
rubric-tuning attack from the external review is git-history-visible.

```
You are a blinded auditor of an AI-assisted decision review.

You see exactly four blobs and NOTHING ELSE:
  1. ARTIFACT         — the proposal under review
  2. SOLO_DECISION    — what the operator decided + risks they said they already saw
  3. COUNCIL_SYNTHESIS — the synthesis the council produced (verdict + ranked issues + dissents)
  4. PERSONA_LIST     — which review lenses ran (e.g. "ml-scientist, ab-critic, red-team")

You do NOT see: per-persona positions, the operator's post-hoc note, the operator's identity,
prior reviews, any chain of thought.

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

Return EXACTLY this format. No preamble, no scoring, no commentary outside the sentinels:

===JUDGE OUTPUT===
NET_NEW_CATCH: true|false
WHY: <one sentence. If true: name the specific net-new issue. If false: name the closest
      solo↔synthesis pair so the operator can see why you gave no credit.>
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

Materiality is operationally defined by the two-clause test above (not perfectly objective, but
not "I know it when I see it" either). Rubric changes require a PR with a one-paragraph
rationale; stats partitions agreement by `judge_prompt_version` (cross-version pooling
forbidden per PRD).

## `lib/blind-judge.sh` — surface

```
blind-judge.sh prepare <room> [--synthesis <path>]
   ↳ assemble the four blobs, render against blind-judge-prompt.v1.txt,
     print full prepared prompt to stdout AND copy to clipboard (pbcopy/xclip; stdout-only
     fallback with printed warning if neither available),
     print SHA256 of the full prepared prompt,
     print the context-switch banner (see below).

blind-judge.sh record <room> --catch true|false --why "..." \
                              --model-family <claude|gpt|gemini|local-llama|mistral|grok|deepseek|other> \
                              [--prompt-sha256 <hex>]
   ↳ validate inputs strictly (FR2 parser); write @@from: blind-judge line to room transcript;
     update journal row's judge_* fields per FR8 (or write judge-only row if no row exists).

blind-judge.sh judge <room>      # MVP convenience: prepare + read response from stdin + record
   ↳ runs prepare (prints + copies + banner), then waits on stdin for the operator's pasted-back
     response (heredoc or piped), parses it, and runs record. The "single command" UX from
     PRD FR3.
```

`judge` is the path the PRD's FR3 commits to. `prepare` + `record` are kept as separate
subcommands for: testing, automation (a v1.1 CLI shell-out can use them), and the case where
the operator wants the prepared prompt as a file for inspection before pasting.

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

## Parser (FR2 strict)

Bash-grep, no jq for parsing the response (jq is for journal append/read). The response is
small and structured; jq for that is overkill.

```bash
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
    # 3. NET_NEW_CATCH line must exist and be true|false
    local catch
    catch=$(grep -m1 '^NET_NEW_CATCH:' <<<"$block" | awk '{print $2}')
    [[ "$catch" =~ ^(true|false)$ ]] || die "NET_NEW_CATCH must be 'true' or 'false', got: $catch"
    # 4. WHY must exist; collapse trailing whitespace; ban embedded newlines
    local why
    why=$(grep -m1 '^WHY:' <<<"$block" | sed 's/^WHY: //')
    [ -n "$why" ] || die "WHY line missing or empty"
    # 5. WHY must be a single line (multi-line WHY rejected; OQ#1 leaning)
    [ "$(grep -c '^WHY:' <<<"$block")" = "1" ] || die "WHY must be single-line"
    printf '%s\n%s\n' "$catch" "$why"
}
```

`die()` writes the failing line to stderr and `exit 1`. No row mutation, no silent garbage. PRD
guard rate: 100%.

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
* **Row exists** → in-place update of `judge_*` fields only. Idempotent (re-running with the
  same room overwrites the judge_* fields; self-report stays untouched).

No orphaned state: a judged row always has both (a) `judge_blinded=true` AND (b) the
`@@from: blind-judge` transcript line — either both or neither.

## Journal schema changes (PRD FR6, run_kind-style backward compat)

Six new fields on each row. Default-when-missing makes legacy rows continue to work:

| Field | Type | Default-if-missing | Notes |
|---|---|---|---|
| `judge_blinded` | bool | `false` | was this run judged? |
| `judge_blinded_catch` | bool\|null | `null` | judge's NET_NEW_CATCH answer |
| `judge_why` | string | `""` | judge's WHY one-liner |
| `judge_model_family_self_reported` | string | `""` | operator-supplied; name carries the warning |
| `judge_prompt_version` | string | `null` | e.g. `v1`; null = "before blinded-judge existed" |
| `judge_prompt_sha256` | string | `""` | SHA256 of helper-emitted prompt; rubric-drift detection only |

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

* If `judged_runs < 5` → print `[calibration phase — N/5 Phase 1, dual-judging recommended]`,
  do NOT print agreement %.
* If `5 ≤ judged_runs < 50` → print `[Phase 2: N/50 judged]`, print agreement % but no band
  interpretation.
* If `judged_runs ≥ 50` → print agreement % with band (90+/70-90/<70) per PRD Phase 2.
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
| PRD-OQ1 | reply format whitespace / multi-line WHY | reject multi-line WHY (parser, step 5); document. |
| PRD-OQ2 | (RESOLVED in PRD as FR9) | FR9 implementation above. |
| PRD-OQ3 | solo-decision-quality confound | record `solo_decision_word_count` as a 7th new journal field (cheap; deferred analysis). |
| PRD-OQ4 | cadence enforced vs documented | documented in v1 (SKILL.md). Forcing gate deferred to v1.1 per PRD. |
| PRD-OQ5 | hash scope | per PRD Rev 3: helper-output only; rubric-drift detection only; not tamper-detection. |
| PRD-OQ6 | calibration-phase stats text | two-phase per `stats` arm above. |
| PRD-OQ7 | (RESOLVED — persona list IN) | implemented in FR1, parser uses it for confabulation detection. |
| PRD-OQ8 | dual-judge family split for Phase 1 | 3 same-family / 2 cross-family for the first 5 dual-judged runs. Recorded as `judge_a_model_family_self_reported` + `judge_b_model_family_self_reported` for those 5 only; collapses to single `judge_model_family_self_reported` from run 6 onward. |
| PRD-OQ9 | judge_prompt_version operations | rubric file is `lib/blind-judge-prompt.v<N>.txt`; helper reads filename to derive version; PR to bump = `git mv` to next N + commit. |

# New Open Questions (for PLAN)

| # | Q | Leaning |
|---|---|---|
| DD-OQ1 | Should `blind-judge.sh judge` time-out on stdin if operator never pastes back? | 10 minutes hard, print remaining-time at 5min mark. Operator is the user; they own it. |
| DD-OQ2 | Where does Phase 1's dual-judging live in the helper? `judge --dual`? Two separate `judge` calls? | Two separate `judge` calls per council; helper detects "this room already has a judge_blinded_catch" and prompts "this is Phase 1; recording as judge_B." |
| DD-OQ3 | Test fixtures for parser — golden bad responses (wrong sentinel, missing line, multi-line WHY, NET_NEW_CATCH=yes instead of true) — checked into repo? | Yes; under `test/fixtures/blind-judge/`. PLAN sequences this. |
| DD-OQ4 | What does the helper do on macOS-without-`pbcopy` or linux-without-`xclip`? | Fall back to stdout-only with a visible "no clipboard tool found — copy manually" banner. Do not fail. |
| DD-OQ5 | If the operator runs `judge` on a council that ran in DEGRADED solo mode, do we mark the judge row differently? | Yes — add a `council_mode: parallel\|degraded-solo` field to the journal that captures whether the council was a true multi-agent run or a solo-context simulation. Useful for separating judge agreement rates between the two regimes. (This is technically a 7th new journal field; flagging it for PLAN.) |

# Acceptance

* `lib/blind-judge.sh prepare|record|judge` implemented; parser rejects all 4+ golden bad fixtures.
* `lib/blind-judge-prompt.v1.txt` committed verbatim.
* `lib/journal.sh` schema extended (6 + 1 new fields); backward-compat preserved; `stats` prints
  the two-phase arm; `judge-only rows` surfaced when present.
* `skills/council/SKILL.md` + `prompts/council-orchestrator.md` Step 1 require artifact persistence
  in the room.
* `test/test_blind_judge.sh` covers: prepare-without-room-errors, parser-rejects-bad-fixtures,
  record-updates-existing-row, record-writes-judge-only-row-when-no-row-exists, dual-judging-
  Phase-1 flow, idempotent re-record.
* `test/test_journal.sh` extended: legacy rows parse with all new fields defaulted, fully-populated
  rows round-trip, judge-only rows excluded from agreement calculations.
* CI green on the PR.

# Tech Debt / Deferred (named)

* **CLI shell-out judge** (v1.1) — auto-call `claude` / `llm` / `openai` CLI to remove the paste
  step. Closes the paste-time-tampering gap PRD Rev 3 documented as unsolvable in v1.
* **Forcing gate on cadence** (v1.1) — block `journal.sh append` until judge call completes for
  the first N runs, if v1 cadence-compliance drops below 70%.
* **Schema migration tool** (issue #14 roll-up) — `journal.sh migrate` for any future schema
  change; touched here but deferred.
* **Multi-judge consensus beyond Phase 1** — running every council past 3 judges and majority-
  voting. Defer until n=1 judge proves its keep at Phase 2.
* **Solo-decision-quality analysis** — `solo_decision_word_count` is recorded in v1, analysis is
  v1.1.
