# Iterative Reflection — Implementation Plan

> **Status:** Historical implementation plan. Iterative reflection shipped in v0.1.0; current validation work lives in [`../../ROADMAP.md`](../../ROADMAP.md). Checkboxes below stay as build history, not active backlog.

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add N-iteration cross-reflection to the council: personas read peers' prior positions and revise via critique-before-concede, with verdict+issue-count convergence/mush detection, round-tagged transcript, bounded cost.

**Architecture:** Orchestrator-sequenced rounds (no live chat). New deterministic bash helper `synth.sh converged`; `transcript.sh show` parses round tags; SKILL.md (canonical) + portable prompt carry the loop + reflection prompt + sentinels. Implements DD Rev 2.

**Tech Stack:** bash + jq; markdown orchestrator prompts; grep-level tests for prose rules, behavioral tests for bash.

> **Rev 2** (council gate #3, SPLIT 2×BLOCK): fixed a real bug — `show`'s `jq -r` decodes `\n` to
> real newlines and breaks the awk tab-record parse → `gsub` fix + multi-line test · guarded the
> `changed` flag against a persona missing from the prior round · stable sort · pinned the exact
> sentinel string (HTML-comment form; DD reconciled) · require the full `warned` state machine as
> explicit SKILL.md prose · tombstone the old Step-4 "summarize brief" → full-position injection ·
> specify `issue_count` derivation (else the substance guard is dead) · synthesis must surface a
> *persisted* SUSPICIOUS-FLIP · reframed grep tests honestly as drift/lint (the falsifiable
> anti-mush test is `test_converged`; "did the council resist" is an eval, not a unit test).

---

## File map
```
lib/synth.sh                       MODIFY  add `converged` subcommand
lib/transcript.sh                  MODIFY  `show` parses #rN, groups by round (store raw — no capture change)
skills/council/SKILL.md            MODIFY  canonical: N-iter loop, reflection prompt, sentinels, red-team auto-include
prompts/council-orchestrator.md    MODIFY  mirror loop + sentinels + REFUTE FIRST
test/test_converged.sh             CREATE
test/test_orchestrator_sync.sh     CREATE
test/test_reflect_prompt.sh        CREATE
test/test_transcript.sh            MODIFY  round-tag round-trip + negative (#tag not #rN)
test/test_selection.sh             MODIFY  red-team auto-included when iterations>1
```

---

## Chunk 1: deterministic helpers (synth.sh + transcript show)

### Task 1: `synth.sh converged` (verdict + issue-count mush detector)

**Files:** Modify `lib/synth.sh`; Create `test/test_converged.sh`

- [ ] **Step 1: failing test** `test/test_converged.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
S="$DIR/lib/synth.sh"
# clean convergence: all verdicts identical prev->curr, no flip
OUT=$(printf 'a SHIP 1\nb SHIP 2\n---\na SHIP 1\nb SHIP 2\n' | bash "$S" converged); echo "$OUT" | grep -qx CONVERGED || { echo "FAIL converged: $OUT"; exit 1; }
# a real change (no suspicious flip): one verdict differs, not toward a majority capitulation
OUT=$(printf 'a SHIP 2\nb BLOCK 2\n---\na SHIP 2\nb NEED-MORE-INFO 2\n' | bash "$S" converged); echo "$OUT" | grep -qx CHANGED || { echo "FAIL changed: $OUT"; exit 1; }
# synchronized capitulation: >=2 flip to curr majority
OUT=$(printf 'a BLOCK 3\nb SHIP 2\nc BLOCK 4\n---\na SHIP 1\nb SHIP 2\nc SHIP 0\n' | bash "$S" converged); echo "$OUT" | grep -qx SUSPICIOUS-FLIP || { echo "FAIL sync-flip: $OUT"; exit 1; }
# substance degradation: single flip toward majority with dropped issue count
OUT=$(printf 'a SHIP 2\nb SHIP 2\nc BLOCK 4\n---\na SHIP 2\nb SHIP 2\nc SHIP 0\n' | bash "$S" converged); echo "$OUT" | grep -qx SUSPICIOUS-FLIP || { echo "FAIL substance: $OUT"; exit 1; }
# boundary: flip toward majority with EQUAL issue count is just CHANGED, not suspicious
OUT=$(printf 'a SHIP 2\nb SHIP 2\nc BLOCK 2\n---\na SHIP 2\nb SHIP 2\nc SHIP 2\n' | bash "$S" converged); echo "$OUT" | grep -qx CHANGED || { echo "FAIL equal-count-boundary: $OUT"; exit 1; }
# empty -> NO-INPUT exit 1
set +e; OUT=$(printf '' | bash "$S" converged 2>/dev/null); rc=$?; set -e
[ "$rc" = 1 ] && echo "$OUT" | grep -qx NO-INPUT || { echo "FAIL no-input: rc=$rc $OUT"; exit 1; }
echo "PASS test_converged"
```

- [ ] **Step 2: run, expect FAIL** (`converged` unknown subcommand)

- [ ] **Step 3: implement** — add this case to `lib/synth.sh` before the `*)` default:

```bash
  converged)
    # stdin: prev block, a line "---", curr block. Lines: "<persona> <verdict> <issue_count>".
    raw="$(cat)"; [ -n "$(printf '%s' "$raw" | tr -d '[:space:]')" ] || { echo NO-INPUT; exit 1; }
    prev="$(printf '%s\n' "$raw" | sed -n '1,/^---$/p' | sed '/^---$/d' | sed '/^[[:space:]]*$/d')"
    curr="$(printf '%s\n' "$raw" | sed -n '/^---$/,$p' | sed '/^---$/d' | sed '/^[[:space:]]*$/d')"
    [ -n "$prev" ] && [ -n "$curr" ] || { echo NO-INPUT; exit 1; }
    # curr majority verdict (plurality)
    maj="$(printf '%s\n' "$curr" | awk '{print $2}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')"
    pv() { printf '%s\n' "$prev" | awk -v p="$1" '$1==p{print $2; exit}'; }
    pc() { printf '%s\n' "$prev" | awk -v p="$1" '$1==p{print $3; exit}'; }
    flips=0; degraded=0; changed=0
    while read -r p v c; do
      [ -n "$p" ] || continue
      ov="$(pv "$p")"; oc="$(pc "$p")"
      [ -n "$ov" ] && [ "$ov" != "$v" ] && changed=1                              # guard: missing prev != change
      if [ -n "$ov" ] && [ "$ov" != "$maj" ] && [ "$v" = "$maj" ]; then          # moved TO majority
        flips=$((flips+1))
        if [ -n "$oc" ] && [ "${c:-0}" -lt "$oc" ]; then degraded=1; fi          # ...while dropping issues
      fi
    done <<< "$curr"
    if [ "$flips" -ge 2 ] || [ "$degraded" = 1 ]; then echo SUSPICIOUS-FLIP
    elif [ "$changed" = 1 ]; then echo CHANGED
    else echo CONVERGED
    fi
    ;;
```

- [ ] **Step 4: run, expect PASS** → `bash test/test_converged.sh` → `PASS test_converged`
- [ ] **Step 5: commit** `feat: add synth.sh converged (verdict+issue-count mush detector)`

### Task 2: `transcript.sh show` round grouping

**Files:** Modify `lib/transcript.sh` (`show` case only); Modify `test/test_transcript.sh`

- [ ] **Step 1: extend test** — append to `test/test_transcript.sh` before its final `echo PASS`:

```bash
# round-tagged capture stored RAW; show groups by round
RR=round-room
printf '@@from: red-team#r1\nverdict: BLOCK\n@@from: red-team#r2\nverdict: SHIP\n' | "$DIR/lib/transcript.sh" capture "$RR"
grep -q '"from":"red-team#r2"' "$AGENT_CHAT_ROOT/rooms/$RR/log.jsonl" || { echo "FAIL: #rN not stored raw"; exit 1; }
SHOW="$("$DIR/lib/transcript.sh" show "$RR")"
echo "$SHOW" | grep -q '── round 1 ──' || { echo "FAIL: no round1 header"; exit 1; }
echo "$SHOW" | grep -q '── round 2 ──' || { echo "FAIL: no round2 header"; exit 1; }
# MULTI-LINE block must render intact (catches the jq-real-newline vs awk-tab bug)
ML=ml-room
printf '@@from: red-team#r1\nverdict: BLOCK\ntop_issues:\n- [BLOCKER] x\n' | "$DIR/lib/transcript.sh" capture "$ML"
MOUT="$("$DIR/lib/transcript.sh" show "$ML")"
echo "$MOUT" | grep -q '│ top_issues:' || { echo "FAIL: multiline body not rendered (jq/awk newline bug)"; exit 1; }
echo "$MOUT" | grep -cq '── round' && [ "$(echo "$MOUT" | grep -c '── round')" = 1 ] || { echo "FAIL: multiline split into spurious rounds"; exit 1; }
# negative: a '#' that is NOT a round suffix must not be grouped as a round
NR=neg-room
printf '@@from: persona#hashtag\nverdict: SHIP\n' | "$DIR/lib/transcript.sh" capture "$NR"
"$DIR/lib/transcript.sh" show "$NR" | grep -qE '── round [0-9]+ ──' && { echo "FAIL: #hashtag misread as round"; exit 1; } || true
```

- [ ] **Step 2: run, expect FAIL** (no round headers)
- [ ] **Step 3: implement** — replace the `show)` case body's `jq` render line with round-aware grouping:

```bash
  show)
    room="${1:-}"
    if [ -z "$room" ]; then room="$(ls -1t "$ROOMS" 2>/dev/null | head -1)"; fi
    [ -n "$room" ] || { echo "(no rooms yet)"; exit 0; }
    room="$(ac_safe "$room")"; log="$ROOMS/$room/log.jsonl"
    [ -f "$log" ] || { echo "no transcript for room '$room'"; exit 1; }
    printf '═══ council transcript: %s ═══\n\n' "$room"
    # emit "round<TAB>from<TAB>ts<TAB>text"; round = trailing #r<digits> on from (else 0).
    # gsub("\n";"\\n"): jq -r decodes \n to REAL newlines, which would break the tab-record parse —
    # re-escape so each log entry stays ONE awk record; awk re-splits on the literal \n.
    # sort -s + -k2,2 = stable, deterministic persona order within a round.
    jq -r '. as $e | ($e.from | capture("#r(?<n>[0-9]+)$").n // "0") as $r
           | "\($r)\t\($e.from)\t\($e.ts)\t\($e.text | gsub("\n";"\\n"))"' "$log" \
    | sort -s -n -k1,1 -k2,2 -t$'\t' \
    | awk -F'\t' '
        { r=$1; from=$2; gsub(/#r[0-9]+$/,"",from); ts=$3; text=$4
          if (r!=prev) { if (r=="0") printf "── round — ──\n"; else printf "── round %s ──\n", r; prev=r }
          printf "┌─ [%s]  %s\n", from, ts
          n=split(text, L, /\\n/); for(i=1;i<=n;i++) printf "│ %s\n", L[i]
          printf "└─\n" }'
    ;;
```

> Note: `text` newlines are stored as literal `\n` inside the JSON string by jq's `-r` only if the
> value had them; transcript text is single-line per `capture` block join — if multi-line is needed,
> the awk `split(text,L,/\\n/)` handles escaped `\n`. Keep capture's join as-is.

- [ ] **Step 4: run, expect PASS** → `bash test/test_transcript.sh`
- [ ] **Step 5: commit** `feat: transcript show groups by round tag (#rN), stored raw`

---

## Chunk 2: orchestrator (SKILL.md canonical + portable mirror + prose tests)

### Task 3: SKILL.md — N-iteration loop + reflection prompt + sentinels

**Files:** Modify `skills/council/SKILL.md` (canonical). Pinned details below are REQUIRED literal text.

- [ ] **Step 1 — sentinels (exact strings).** Add these two lines verbatim near the top of the body
  (HTML-comment form — file is Markdown; `test_orchestrator_sync.sh` greps the exact strings):
  ```
  <!-- ITER_CAP=4 -->
  <!-- ITER_DEFAULT=2 -->
  ```
- [ ] **Step 2 — tombstone the old Step 4.** DELETE the current Step 4 text ("Summarize round-1
  positions into a short peer brief … do NOT concatenate raw"). It mandates Option B; the DD binds
  Option A. Replace per Step 3.
- [ ] **Step 3 — loop + reflection (replace Steps 3/4 and the "≤2 rounds" hard limit).** The
  replacement MUST include, as explicit numbered prose the orchestrator follows:
  - `--iterations N`, default 2, **clamp 1..4** (cap absolute).
  - Iteration 1 = blind positions (today's behavior).
  - Iterations ≥2 reflection prompt, containing the literal marker **`REFUTE FIRST`** and the
    ordered steps: (1) REFUTE FIRST each peer point you disagree with; (2) CONCEDE only what you
    could not refute; (3) HOLD and defend the rest; (4) emit revised POSITION + a `reflection:` note.
    Inject **each peer's full prior-round POSITION verbatim** (NOT summarized).
  - **red-team auto-included** when iterations>1, with the harder rule: red-team may not CONCEDE
    without citing a specific factual error in its OWN prior position.
  - **`issue_count` derivation (REQUIRED, else the substance guard is dead):** before calling
    `synth.sh converged`, for each persona count its emitted `top_issues` (e.g.
    `grep -cE '^\s*-\s*\[(BLOCKER|MAJOR|MINOR)\]'` over that persona's POSITION text). Pass
    `"<persona> <verdict> <issue_count>"` lines for prev and curr rounds.
  - **`warned`-flag state machine (REQUIRED literal logic in the prose):**
    > After each reflection round, pipe prev/curr `<persona> <verdict> <issue_count>` (separated by a
    > `---` line) into `synth.sh converged`. Then: **CONVERGED** → stop. **SUSPICIOUS-FLIP** and not
    > yet warned → emit `⚠ converged-this-round (possible capitulation)`, set warned, run exactly ONE
    > more round. **SUSPICIOUS-FLIP** again after warned, or **CHANGED** → keep iterating to the cap.
  - Capture each round round-tagged: `transcript.sh capture council-<slug>` with `@@from: <persona>#r<N>`.
- [ ] **Step 4 — synthesis surfaces persisted capitulation.** In Step 5 (synthesis), add: if a
  SUSPICIOUS-FLIP persisted to the cap (warned and still flipping), the synthesis MUST headline
  `⚠ council capitulated under reflection — treat consensus as suspect`, NOT present clean consensus.
- [ ] **Step 5 — hard limits.** Replace "≤2 rounds. No loops." with
  "≤4 personas, ≤4 iterations (default 2), cap absolute, no unbounded loop."
- [ ] **Step 6: commit** `feat: SKILL.md N-iteration reflection loop, warned state machine, sentinels`

### Task 4: portable prompt mirror

**Files:** Modify `prompts/council-orchestrator.md`

- [ ] **Step 1:** Mirror Task 3: same sentinels `<!-- ITER_CAP=4 --> <!-- ITER_DEFAULT=2 -->`, the
  `REFUTE FIRST` reflection block, the iteration loop, red-team rule. Keep the subagent-vs-single-context branch.
- [ ] **Step 2: commit** `feat: mirror iteration loop into portable orchestrator prompt`

### Task 5: prose-rule tests (sync, reflect prompt, selection)

**Files:** Create `test/test_orchestrator_sync.sh`, `test/test_reflect_prompt.sh`; Modify `test/test_selection.sh`

> **Honesty (gate #3, red-team):** these are **drift/lint** tests — they verify required text EXISTS,
> not that reflection RESISTS sycophancy. The falsifiable anti-mush test is `test_converged.sh`
> (capitulation → SUSPICIOUS-FLIP). Whether the council *actually resisted* on a real run is an
> **eval**, not a unit test — checked manually in Task 6 Step 3, not claimed as automated.

- [ ] **Step 1: `test/test_orchestrator_sync.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
A="$DIR/skills/council/SKILL.md"; B="$DIR/prompts/council-orchestrator.md"
for tok in '<!-- ITER_CAP=4 -->' '<!-- ITER_DEFAULT=2 -->'; do
  grep -qF "$tok" "$A" || { echo "FAIL: SKILL.md missing exact sentinel $tok"; exit 1; }
  grep -qF "$tok" "$B" || { echo "FAIL: portable prompt missing exact sentinel $tok"; exit 1; }
done
grep -q 'REFUTE FIRST' "$A" || { echo "FAIL: SKILL.md missing REFUTE FIRST"; exit 1; }
grep -q 'REFUTE FIRST' "$B" || { echo "FAIL: portable prompt missing REFUTE FIRST"; exit 1; }
echo "PASS test_orchestrator_sync"
```

- [ ] **Step 2: `test/test_reflect_prompt.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
A="$DIR/skills/council/SKILL.md"
grep -q 'REFUTE FIRST' "$A" || { echo "FAIL: no refute-first ordering"; exit 1; }
grep -qiE 'peer.*prior position|prior position.*peer|inject.*peer' "$A" || { echo "FAIL: no peer-position injection"; exit 1; }
grep -qiE 'red-team.*(factual error|own prior)|concede.*factual error' "$A" || { echo "FAIL: no hardened red-team concession rule"; exit 1; }
echo "PASS test_reflect_prompt"
```

- [ ] **Step 3: extend `test/test_selection.sh`** — append before its final PASS:

```bash
grep -qiE 'red-team.*(auto|force).*(includ|multi-iter|iterations)|force-include red-team' "$DIR/skills/council/SKILL.md" \
  || { echo "FAIL: red-team auto-include rule missing"; exit 1; }
```

- [ ] **Step 4: run all new/changed tests, expect PASS**
- [ ] **Step 5: commit** `test: orchestrator sync + reflect-prompt + selection rules`

---

## Chunk 3: verify + dogfood

### Task 6: full suite + E2E

- [ ] **Step 1:** `for t in test/*.sh; do bash "$t" || exit 1; done` → all PASS.
- [ ] **Step 2:** reinstall `bash install.sh` (symlinks already point at repo; no-op confirm).
- [ ] **Step 3 (E2E, manual):** `/council --iterations 3` on this plan; confirm round-2 positions
  reference peer points, `transcript.sh show` renders `── round N ──` evolution, and a SUSPICIOUS-FLIP
  warning appears if personas capitulate.
- [ ] **Step 4: commit** any fixups.

## Verification checklist (maps to DD testing)

> **Archived:** CI now owns these checks; see root [`README.md`](../../../README.md) and [`docs/ROADMAP.md`](../../ROADMAP.md) for current status.

- [ ] `test_converged.sh`: CONVERGED / CHANGED / SUSPICIOUS-FLIP (sync + substance) / NO-INPUT.
- [ ] `test_transcript.sh`: #rN stored raw, show groups by round, `#hashtag` not misread.
- [ ] `test_orchestrator_sync.sh`: sentinels + REFUTE FIRST in both files.
- [ ] `test_reflect_prompt.sh`: refute-first + peer injection + hardened red-team rule present.
- [ ] `test_selection.sh`: red-team auto-include rule present.
- [ ] Cap absolute (≤4); SUSPICIOUS-FLIP costs exactly one retry; default 2.
