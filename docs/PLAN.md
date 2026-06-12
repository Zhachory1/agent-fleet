# Agent Fleet Council — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build personal multi-persona council: `/council <task>` orchestrator picks 2-4 specialist agents, runs bounded debate, synthesizes decision-grade answer with dissent.

**Architecture:** Orchestrator = slash-command skill driving main session; spawns stateless one-shot persona subagents over ≤2 rounds; holds all output in own context; writes JSONL transcript (agent-chat format, write-only, no plugin dep) + counterfactual journal. Implements DD `./DD.md`.

**Tech Stack:** Markdown agent defs (Claude Code native frontmatter: name/description/model/tools), bash + jq helpers, Claude Code Skill + Task tool.

---

## Conventions

- Repo root: `~/code/agent-fleet`. All paths relative to it unless absolute.
- Commit after each task. Conventional commits.
- Persona/agent loadable format = YAML frontmatter (`name`, `description`, `model`, `tools`) + body (verified against Rokt `code-reviewer` agent).
- Tests are bash scripts in `test/`, runnable standalone, exit non-zero on fail.

---

## File Structure (locks decomposition)

```
agents/        6 persona defs + _rokt-overlay.md.example   — one lens each
skills/council/SKILL.md                                    — orchestrator
lib/transcript.sh                                          — serial JSONL append
lib/journal.sh                                             — counterfactual log append
install.sh                                                 — symlink in/out of ~/.claude
test/*.sh                                                  — contract tests
.gitignore                                                 — _rokt-overlay.md, /tmp runs
```

---

## Chunk 1: Foundation (scaffold + lib helpers)

### Task 0: Scaffold + .gitignore

**Files:**
- Create: `.gitignore`
- Create: `agents/_rokt-overlay.md.example`

- [ ] **Step 1: Write `.gitignore`**

```
# private overlay — never commit Rokt-confidential
agents/_rokt-overlay.md
# run artifacts
/tmp-council-*
*.local
```

- [ ] **Step 2: Write `agents/_rokt-overlay.md.example`** (template; real one private)

```markdown
# Rokt Overlay (example — copy to _rokt-overlay.md and fill; that copy is gitignored)

When reviewing, apply these domain specifics:
- Ads metrics: APT, CoPI, VPT, YER, CVR, eCPM, value-based bidding.
- Experiment caveats: auction interference (SUTVA violation), pacing, holdout hygiene.
- Stack: KFP pipelines, Trino/Iceberg datalake, Datadog, K8s (blue=experiments, green=scheduled).
- Hot paths: bid path, selection/serving — latency + blast-radius sensitive.
- Current priorities: doppelganger / LAL / CoPI.
# NOTE: keep real overlay free of PII and confidential internals beyond what you need.
```

- [ ] **Step 3: Commit**

```bash
cd ~/code/agent-fleet
git add .gitignore agents/_rokt-overlay.md.example
git commit -m "chore: scaffold agent-fleet repo + gitignore + overlay template"
```

### Task 1: `lib/transcript.sh` (serial JSONL append)

**Files:**
- Create: `lib/transcript.sh`
- Test: `test/test_transcript.sh`

- [ ] **Step 1: Write failing test** `test/test_transcript.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export AGENT_CHAT_ROOT="$(mktemp -d)"
ROOM="test-room"
"$DIR/lib/transcript.sh" append "$ROOM" "ml-scientist" "verdict=BLOCK calibration off"
"$DIR/lib/transcript.sh" append "$ROOM" "red-team" "what about cold start"
LOG="$AGENT_CHAT_ROOT/rooms/$ROOM/log.jsonl"
[ -f "$LOG" ] || { echo "FAIL: log not created"; exit 1; }
[ "$(wc -l < "$LOG" | tr -d ' ')" = "2" ] || { echo "FAIL: expected 2 lines"; exit 1; }
jq -e . "$LOG" >/dev/null || { echo "FAIL: invalid JSONL"; exit 1; }
FROM=$(sed -n '1p' "$LOG" | jq -r .from)
[ "$FROM" = "ml-scientist" ] || { echo "FAIL: from mismatch"; exit 1; }
echo "PASS test_transcript"
```

- [ ] **Step 2: Run, verify fail**

Run: `bash test/test_transcript.sh`
Expected: FAIL (transcript.sh not found / no such file)

- [ ] **Step 3: Implement `lib/transcript.sh`**

```bash
#!/usr/bin/env bash
# Serial JSONL transcript append — agent-chat room format, write-only.
# Usage: transcript.sh append <room> <from> <text>
set -euo pipefail
AGENT_CHAT_ROOT="${AGENT_CHAT_ROOT:-$HOME/.claude/agent-chat}"
ac_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ac_safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64; }

cmd="${1:-}"; shift || true
case "$cmd" in
  append)
    room="$(ac_safe "${1:?room}")"; from="${2:?from}"; text="${3:?text}"
    rd="$AGENT_CHAT_ROOT/rooms/$room"; mkdir -p "$rd"
    line="$(jq -cn --arg ts "$(ac_now)" --arg from "$from" --arg text "$text" \
      '{ts:$ts, from:$from, text:$text}')"
    printf '%s\n' "$line" >> "$rd/log.jsonl"
    ;;
  *) echo "usage: transcript.sh append <room> <from> <text>" >&2; exit 1;;
esac
```

- [ ] **Step 4: Run, verify pass**

Run: `chmod +x lib/transcript.sh && bash test/test_transcript.sh`
Expected: `PASS test_transcript`

- [ ] **Step 5: Commit**

```bash
git add lib/transcript.sh test/test_transcript.sh
git commit -m "feat: add serial JSONL transcript helper + test"
```

### Task 2: `lib/journal.sh` (counterfactual log)

**Files:**
- Create: `lib/journal.sh`
- Test: `test/test_journal.sh`

- [ ] **Step 1: Write failing test** `test/test_journal.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export AGENT_FLEET_JOURNAL="$(mktemp -d)/journal.jsonl"
"$DIR/lib/journal.sh" append "review-model-x" "ship as-is" "ml-scientist,ab-critic" true "missed skew" true 1
[ -f "$AGENT_FLEET_JOURNAL" ] || { echo "FAIL: no journal"; exit 1; }
jq -e '.net_new_catch==true and .acted_on==true and .dismissed_count==1' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: fields wrong"; exit 1; }
echo "PASS test_journal"
```

- [ ] **Step 2: Run, verify fail**

Run: `bash test/test_journal.sh` → FAIL (no journal.sh)

- [ ] **Step 3: Implement `lib/journal.sh`**

```bash
#!/usr/bin/env bash
# Counterfactual journal append — powers the catch-rate KPI.
# Usage: journal.sh append <task> <solo_decision> <personas_csv> <net_new_catch> <catch_note> <acted_on> <dismissed_count>
set -euo pipefail
JOURNAL="${AGENT_FLEET_JOURNAL:-$HOME/.claude/agent-fleet-journal.jsonl}"
ac_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
cmd="${1:-}"; shift || true
case "$cmd" in
  append)
    task="${1:?}"; solo="${2:?}"; personas="${3:?}"; catch="${4:?}"; note="${5:-}"; acted="${6:?}"; dis="${7:-0}"
    mkdir -p "$(dirname "$JOURNAL")"
    jq -cn --arg ts "$(ac_now)" --arg task "$task" --arg solo "$solo" \
      --arg personas "$personas" --argjson catch "$catch" --arg note "$note" \
      --argjson acted "$acted" --argjson dis "$dis" \
      '{ts:$ts, task:$task, solo_decision:$solo, personas:($personas|split(",")),
        net_new_catch:$catch, catch_note:$note, acted_on:$acted, dismissed_count:$dis}' \
      >> "$JOURNAL"
    ;;
  *) echo "usage: journal.sh append ..." >&2; exit 1;;
esac
```

- [ ] **Step 4: Run, verify pass**

Run: `chmod +x lib/journal.sh && bash test/test_journal.sh` → `PASS test_journal`

- [ ] **Step 5: Commit**

```bash
git add lib/journal.sh test/test_journal.sh
git commit -m "feat: add counterfactual journal helper + test"
```

---

## Chunk 2: Personas (6 orthogonal lenses)

### Task 3: Persona definitions

**Files (Create):** `agents/ml-scientist.md`, `agents/ab-critic.md`, `agents/reliability-sentinel.md`, `agents/software-architect.md`, `agents/generalist-swe.md`, `agents/red-team.md`
**Test:** `test/test_agents_load.sh`

**Shared body template** (every persona; fill `<...>` from the per-persona table in DD §"v1 Personas"):

```markdown
---
name: <persona-name>
description: <one-line lens + when orchestrator should pick this persona>
model: sonnet
tools: Read, Glob, Grep, Bash
---

You are **<Persona Title>** — <lens identity; what you distrust by default>.

You are dispatched by a council orchestrator to review ONE artifact from YOUR lens only.
Stay in your lane — other personas cover other lenses. Be terse, evidence-based, specific.

## What you attack
<bulleted failure modes this lens owns — from DD table>

## How to work
1. Read the artifact at the path given in your prompt (or the inline excerpt).
2. If `~/.claude/agents/_rokt-overlay.md` exists, read it and apply its domain specifics. If absent, proceed generic — no error.
3. If peer positions are included (round 2), engage them: agree, refute, or sharpen.

## Output contract (return EXACTLY this structure)
POSITION (persona: <persona-name>)
- verdict: SHIP | SHIP-WITH-CHANGES | BLOCK | NEED-MORE-INFO
- top_issues: list of {severity: BLOCKER|MAJOR|MINOR, claim, evidence, fix}
- strongest_counterargument: the best case AGAINST your own verdict   # MANDATORY — never skip
- confidence: low | med | high
- one_line: tl;dr

## Rules
- `strongest_counterargument` is mandatory every time — it prevents council consensus mush.
- Do not mutate anything. Read-only. You advise.
- If the artifact is outside your lens, say so and return NEED-MORE-INFO rather than inventing.
```

Per-persona fill (lens + attacks) — authoritative source is DD §"v1 Personas (6, orthogonal)":

- **ml-scientist** — skeptical ranking/ML researcher; distrusts offline wins. Attacks: calibration, train/serve skew, leakage, metric choice (NLL vs AUC), data drift, label quality.
- **ab-critic** — paranoid experiment statistician. Attacks: power/MDE, peeking, novelty effect, interference/SUTVA (auctions), holdout hygiene, segment cherry-picking, readout validity.
- **reliability-sentinel** — SRE worrier. Attacks: blast radius, rollback path, SLO impact, fallback/degradation, capacity, hot-path/serving risk, what-pages-oncall.
- **software-architect** — boundaries-first architect. Attacks: coupling, bounded-context violations, evolvability, build-vs-buy, contract/versioning, premature/ wrong tech selection.
- **generalist-swe** — pragmatic senior IC. Attacks: simplicity, readability, over-engineering/YAGNI, does-it-actually-work, edge cases, error handling, test gaps.
- **red-team** — hostile adversary; default refute. Attacks: strongest case against the whole proposal, hand-waved assumptions, security/abuse, "what breaks first."

- [ ] **Step 1: Write failing test** `test/test_agents_load.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXPECTED=(ml-scientist ab-critic reliability-sentinel software-architect generalist-swe red-team)
fail=0
for name in "${EXPECTED[@]}"; do
  f="$DIR/agents/$name.md"
  [ -f "$f" ] || { echo "FAIL: missing $name.md"; fail=1; continue; }
  head -1 "$f" | grep -q '^---$' || { echo "FAIL: $name no frontmatter"; fail=1; }
  grep -q "^name: $name$" "$f" || { echo "FAIL: $name name field wrong"; fail=1; }
  grep -q "^tools:" "$f" || { echo "FAIL: $name no tools"; fail=1; }
  grep -q "strongest_counterargument" "$f" || { echo "FAIL: $name missing mandatory dissent"; fail=1; }
  grep -q "_rokt-overlay.md" "$f" || { echo "FAIL: $name no overlay hook"; fail=1; }
done
[ "$fail" = "0" ] && echo "PASS test_agents_load" || exit 1
```

- [ ] **Step 2: Run, verify fail**

Run: `bash test/test_agents_load.sh` → FAIL (missing agent files)

- [ ] **Step 3: Write all 6 persona files** using the template + per-persona fill above.

- [ ] **Step 4: Run, verify pass**

Run: `bash test/test_agents_load.sh` → `PASS test_agents_load`

- [ ] **Step 5: Commit**

```bash
git add agents/*.md test/test_agents_load.sh
git commit -m "feat: add 6 orthogonal council personas + load test"
```

---

## Chunk 3: Orchestrator + selection

### Task 4: `/council` orchestrator skill

**Files:**
- Create: `skills/council/SKILL.md`
- Test: `test/test_selection.sh` (asserts the rules-table doc is present + parseable)

**`skills/council/SKILL.md`** — frontmatter + procedure the main session follows:

```markdown
---
name: council
description: Convene a council of 2-4 specialist personas to review a high-stakes decision (model change, experiment readout, design doc, serving-path PR, architecture/build-vs-buy). Picks personas, runs a bounded debate, synthesizes a decision-grade answer with named dissents. Triggers: /council, council review, get a second opinion, tear this apart, is this safe to ship, review this model/experiment/design.
---

# Council Orchestrator

You are the council orchestrator. Run this protocol. Personas are STATELESS one-shot subagents — YOU sequence everything and hold all outputs in YOUR context.

## Step 0 — Solo first (counterfactual, MANDATORY)
Before convening, ask the user (one line) for their current decision + the risks they already see. Record as `solo_decision`. This powers the catch-rate KPI. If they decline, set solo_decision="(skipped)".

## Step 1 — Capture artifact once
Identify the artifact under review (a diff, a doc path, a metrics table, pasted text).
- diff → `git diff [args] > /tmp/council-<slug>.txt`
- file/doc → use its path directly
- pasted text / table → write to `/tmp/council-<slug>.txt`
Hold the path. <2KB may be inlined; else pass the path.

## Step 2 — Select 2-4 personas (rules table → LLM fallback)
Match task to this table; if no row matches, use judgment to pick 2-4 + one-line justification each. Always cap at 4. Add `red-team` when stakes are high.

| Task signal | Personas |
|---|---|
| model change / new model input / training pipeline | ml-scientist, ab-critic, reliability-sentinel |
| experiment / A-B / readout / holdout | ab-critic, ml-scientist |
| design doc / architecture / new service / build-vs-buy | software-architect, red-team, generalist-swe |
| PR / serving-path / bid-path / latency change | reliability-sentinel, generalist-swe, software-architect |
| refactor / simplify / code quality | generalist-swe, software-architect |
| DEFAULT / unmatched | LLM picks 2-4 + justify |

State the selected personas + why (one line each) to the user before spawning.

## Step 3 — Round 1 (parallel)
Spawn each selected persona via the Task tool IN PARALLEL (one message, multiple Task calls). Each prompt = the persona name (subagent_type) + the artifact path/excerpt + the task statement. Collect each returned POSITION.

Append each position to the transcript serially:
`bash ~/code/agent-fleet/lib/transcript.sh append council-<slug> <persona> "<one_line + verdict>"`

## Step 4 — Round 2 (only if verdicts conflict OR user passed --deep)
Summarize round-1 positions into a short peer brief (you do this — do NOT concatenate raw). Re-spawn the SAME personas in parallel, prompt now includes the brief. Collect revisions, append to transcript.

## Step 5 — Synthesize (in YOUR context)
Produce:
```
## Council verdict: <consensus verdict OR "split">
⚠ false-consensus risk        # ONLY if all personas agreed — flag it, do not treat unanimity as safety
### Ranked issues
1. [BLOCKER] <claim> — raised by <personas> — fix: <...>
2. [MAJOR] ...
### Dissents (preserved, named)
- <persona>: <minority position>
### Strongest counterargument to the verdict
- <best refutation, from red-team or most-skeptical persona>
### One-line recommendation
```

## Step 6 — Journal
Ask the user: did the council surface a net-new issue you'd have missed (Y/N), did you act on it (Y/N), how many raised issues did you dismiss as noise? Then:
`bash ~/code/agent-fleet/lib/journal.sh append "<slug>" "<solo_decision>" "<personas_csv>" <true|false> "<note>" <true|false> <dismissed_count>`

## Hard limits
≤4 personas, ≤2 rounds. No loops. Personas are read-only advisors.
```

- [ ] **Step 1: Write failing test** `test/test_selection.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
S="$DIR/skills/council/SKILL.md"
[ -f "$S" ] || { echo "FAIL: no SKILL.md"; exit 1; }
# rules-table determinism: model change row must list the 3 expected personas
grep -q "model change.*ml-scientist, ab-critic, reliability-sentinel" "$S" \
  || { echo "FAIL: model-change selection rule missing/incorrect"; exit 1; }
grep -q "design doc / architecture / new service / build-vs-buy | software-architect, red-team, generalist-swe" "$S" \
  || { echo "FAIL: design-doc selection rule missing"; exit 1; }
grep -q "false-consensus risk" "$S" || { echo "FAIL: no false-consensus guard"; exit 1; }
grep -q "Solo first" "$S" || { echo "FAIL: no counterfactual step"; exit 1; }
grep -qi "parallel" "$S" || { echo "FAIL: round-1 not parallel"; exit 1; }
echo "PASS test_selection"
```

- [ ] **Step 2: Run, verify fail** → `bash test/test_selection.sh` FAIL (no SKILL.md)

- [ ] **Step 3: Write `skills/council/SKILL.md`** (content above).

- [ ] **Step 4: Run, verify pass** → `PASS test_selection`

- [ ] **Step 5: Commit**

```bash
git add skills/council/SKILL.md test/test_selection.sh
git commit -m "feat: add /council orchestrator skill + selection test"
```

---

## Chunk 4: Install + verification

### Task 5: `install.sh`

**Files:** Create `install.sh`; Test `test/test_overlay_absent.sh`

- [ ] **Step 1: Write `install.sh`**

```bash
#!/usr/bin/env bash
# Symlink agent-fleet into ~/.claude (reversible). Usage: install.sh [--uninstall]
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
AGENTS_DST="$HOME/.claude/agents"
SKILL_DST="$HOME/.claude/skills/council"
if [ "${1:-}" = "--uninstall" ]; then
  for f in "$SRC"/agents/*.md; do
    [ "$(basename "$f")" = "_rokt-overlay.md.example" ] && continue
    rm -f "$AGENTS_DST/$(basename "$f")"
  done
  rm -f "$SKILL_DST"
  echo "agent-fleet: uninstalled symlinks."
  exit 0
fi
mkdir -p "$AGENTS_DST" "$HOME/.claude/skills"
for f in "$SRC"/agents/*.md; do
  [ "$(basename "$f")" = "_rokt-overlay.md.example" ] && continue
  ln -sf "$f" "$AGENTS_DST/$(basename "$f")"
done
ln -sfn "$SRC/skills/council" "$SKILL_DST"
echo "agent-fleet: installed. Agents → $AGENTS_DST ; skill → $SKILL_DST"
echo "Optional: cp agents/_rokt-overlay.md.example agents/_rokt-overlay.md and edit (stays private)."
```

- [ ] **Step 2: Write `test/test_overlay_absent.sh`** (portability NFR3 — persona body resolves clean with no overlay)

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
# overlay hook must be conditional ("if exists") so absence is not an error
for f in "$DIR"/agents/ml-scientist.md "$DIR"/agents/red-team.md; do
  grep -qi "if .*_rokt-overlay.md exists" "$f" || grep -qi "If \`~/.claude/agents/_rokt-overlay.md\` exists" "$f" \
    || { echo "FAIL: $(basename $f) overlay hook not conditional"; exit 1; }
done
[ ! -e "$DIR/agents/_rokt-overlay.md" ] || echo "(note: real overlay present locally — fine)"
echo "PASS test_overlay_absent"
```

- [ ] **Step 3: Run tests** → `chmod +x install.sh && bash test/test_overlay_absent.sh` → PASS

- [ ] **Step 4: Commit**

```bash
git add install.sh test/test_overlay_absent.sh
git commit -m "feat: add reversible install script + overlay-absent test"
```

### Task 6: Round-contract test (mock personas)

**Files:** Test `test/test_round_contract.sh`

> This validates the orchestrator's documented contract WITHOUT live LLM calls: a shell harness mocks two persona "positions" (one SHIP, one BLOCK) and asserts that a synthesis built from them (a) preserves the BLOCK dissent and (b) when both agree, emits the false-consensus flag. Implemented as a small pure-bash synth function so it is deterministic.

- [ ] **Step 1: Write `lib/synth.sh`** (extract the deterministic synth bits the orchestrator can call/test)

```bash
#!/usr/bin/env bash
# Deterministic synthesis check: reads persona verdicts (one per line: "<persona> <verdict>")
# from stdin, prints "FALSE-CONSENSUS" if all identical, else "SPLIT", and lists dissenters.
set -euo pipefail
cmd="${1:-}"; shift || true
case "$cmd" in
  flag)
    verdicts="$(cat)"
    uniq_v="$(printf '%s\n' "$verdicts" | awk '{print $2}' | sort -u | wc -l | tr -d ' ')"
    if [ "$uniq_v" = "1" ]; then echo "FALSE-CONSENSUS"; else
      echo "SPLIT"
      # dissenters = verdicts != majority
      maj="$(printf '%s\n' "$verdicts" | awk '{print $2}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')"
      printf '%s\n' "$verdicts" | awk -v m="$maj" '$2!=m {print "DISSENT: "$0}'
    fi
    ;;
  *) echo "usage: synth.sh flag  (stdin: '<persona> <verdict>' lines)" >&2; exit 1;;
esac
```

- [ ] **Step 2: Write `test/test_round_contract.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
# split case: one SHIP one BLOCK → SPLIT + dissent surfaced
OUT="$(printf 'ml-scientist SHIP\nred-team BLOCK\n' | bash "$DIR/lib/synth.sh" flag)"
echo "$OUT" | grep -q "SPLIT" || { echo "FAIL: split not detected"; exit 1; }
echo "$OUT" | grep -q "DISSENT:" || { echo "FAIL: dissent not surfaced"; exit 1; }
# unanimous case → false-consensus flag
OUT2="$(printf 'ml-scientist SHIP\nred-team SHIP\n' | bash "$DIR/lib/synth.sh" flag)"
echo "$OUT2" | grep -q "FALSE-CONSENSUS" || { echo "FAIL: false-consensus not flagged"; exit 1; }
echo "PASS test_round_contract"
```

- [ ] **Step 3: Run** → `chmod +x lib/synth.sh && bash test/test_round_contract.sh` → PASS
- [ ] **Step 4: Wire `lib/synth.sh flag` into SKILL.md Step 5** (orchestrator calls it on collected verdicts to drive the false-consensus flag). Edit SKILL.md to reference it.
- [ ] **Step 5: Commit**

```bash
git add lib/synth.sh test/test_round_contract.sh skills/council/SKILL.md
git commit -m "feat: add deterministic synth flag (false-consensus/dissent) + contract test"
```

### Task 7: Install, run all tests, E2E smoke

- [ ] **Step 1: Run full suite**

```bash
cd ~/code/agent-fleet && for t in test/*.sh; do bash "$t" || exit 1; done
```
Expected: all PASS.

- [ ] **Step 2: Install**

```bash
bash install.sh
ls -l ~/.claude/agents/ | grep -E 'ml-scientist|red-team'
ls -l ~/.claude/skills/council
```
Expected: symlinks present.

- [ ] **Step 3: E2E smoke (manual, real)** — in a fresh Claude Code session: `/council review this diff: <small sample>`. Eyeball: selects 2-4, personas return POSITION with strongest_counterargument, synthesis ranks issues + preserves dissent + journal prompt fires.

- [ ] **Step 4: Final commit + push (only if user confirms)**

```bash
git add -A && git commit -m "docs: PRD/DD/PLAN for agent-fleet council" || true
```

---

## Verification checklist (maps to NFR6 + KPI)

- [ ] All `test/*.sh` PASS.
- [ ] `install.sh` + `--uninstall` round-trip clean.
- [ ] Overlay-absent: persona prompts resolve with no error.
- [ ] E2E: `/council` selects, debates ≤2 rounds, synthesizes with dissent + false-consensus flag.
- [ ] Counterfactual journal writes a valid line.
- [ ] Zero dependency on the agent-chat plugin (only its JSONL format reused).
