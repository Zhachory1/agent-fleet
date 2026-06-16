# Phase 1 calibration — operator runbook

**Goal:** 5 dual-judged councils → close #48 → unblock #36.

**Time:** ~5-10 min per judge call × 7 remaining calls = **35-70 min total**, doable across one or two sittings.

**What you do:** for each row in the table below, open a fresh chat in the indicated account/family, paste the prompt content from the linked file, copy the chat's response, paste it back into the helper. The helper validates the format and writes the journal row.

---

## State of play

LLM already ran **3 of 10** judge calls (judge-a on 3 rooms) in the session that produced this runbook. **Caveat:** those 3 were same-session-as-orchestrator (meta-context contamination — see "Spot-check" at the bottom). All 3 returned `catch=true`.

| # | Room | judge-a | judge-b |
|---|---|---|---|
| 1 | `council-cache-prd` | ⏳ **you** (LLM was contaminated by smoke test) | ⏳ you |
| 2 | `council-permtier-prd` | ✅ done (LLM, catch=true) — see spot-check | ⏳ you |
| 3 | `council-prose-40pct` | ✅ done (LLM, catch=true) — see spot-check | ⏳ you |
| 4 | `council-prose-40pct-finding` | ✅ done (LLM, catch=true) — see spot-check | ⏳ you |
| 5 | `council-repo-state-v010` | ⏳ **you** | ⏳ you |

**7 calls left.** Recommended order: knock out **judge-b for #2–4 first** (you have an existing judge-a to compare against — useful disagreement signal). Then **#1 (both)** and **#5 (both)** to finish.

---

## Account / family plan

Per [DD §0.1](../DD.md) and the original [phase1-worksheet](../phase1-worksheet.md), Phase 1 wants ≥3 judge-b runs across the 5 rooms with **≥2 cross-family** (Claude/GPT/Gemini are different families). Since the LLM already used Claude (same-family-different-account-style) for the 3 judge-a slots, the recommended split for the 7 remaining is:

| Slot | Recommended family | Why |
|---|---|---|
| #1 `council-cache-prd` judge-a | **Claude (fresh chat)** | Original judge-a was contaminated; redo in a clean Claude chat |
| #1 `council-cache-prd` judge-b | **GPT or Gemini** | Cross-family |
| #2 `council-permtier-prd` judge-b | **Claude (fresh chat)** | Same-family pair for comparing same-family judges |
| #3 `council-prose-40pct` judge-b | **Claude (fresh chat)** | Same |
| #4 `council-prose-40pct-finding` judge-b | **GPT or Gemini** | Cross-family |
| #5 `council-repo-state-v010` judge-a | **Claude (fresh chat)** | Same-family |
| #5 `council-repo-state-v010` judge-b | **GPT or Gemini** | Cross-family |

That gives **3 cross-family judge-b** runs across the 5 rooms (cache, prose-40pct-finding, repo-state) — clears the worksheet's ≥2 cross-family target with margin.

**If you can't get a GPT or Gemini account this week:** do all 7 in Claude fresh chats. Document in the calibration writeup ("Phase 1 ran all-same-family due to operator account constraints; cross-family arm deferred"). The data still says something.

---

## The procedure (do this 7 times)

For each row below:

1. **Open the prompt file in Zed** (the linked `.txt`). It's already a fully-rendered judge prompt; nothing to edit.
2. **Open a fresh chat** in the indicated family/account. **Critical:** do not reuse a chat that has agent-fleet context. New conversation, no prior turns.
3. **Copy the ENTIRE contents of the .txt file** (cmd-A, cmd-C in Zed). Paste it into the fresh chat. Send.
4. **Wait for the response.** It will be formatted as:
   ```
   ===JUDGE OUTPUT===
   REASONING: ...
   DISSENT_DIFF: - ...
   NET_NEW_CATCH: true|false
   WHY: ...
   EVIDENCE: ... (if catch=true)
   IMPLIED_BY: ... (if catch=false and WHY claims implication)
   ===END===
   ```
5. **Copy the entire response block** (from `===JUDGE OUTPUT===` to `===END===` inclusive).
6. **Dump it to a file** (avoids terminal paste-buffer limits that silently drop bytes on multi-KB pastes):
   ```bash
   pbpaste > /tmp/response.txt
   ```
7. **Run the judge command with `--response-file`** (the per-slot command below uses this). The helper reads from the file, writes the journal row, done.

> **Why not paste directly into stdin?** macOS Terminal / iTerm / Zed's embedded terminal use canonical mode for `cat`, which has a ~1-4KB paste buffer. Anything past that is silently dropped. The judge responses are typically 1-3KB but unpredictable; the file route is reliable.
>
> If you prefer to live dangerously and paste directly, omit `--response-file` and Ctrl-D when done — just watch for truncation.

---

## The 7 commands

Each command below assumes:

```bash
export AGENT_FLEET_HOME=/Users/zhach/code/agent-fleet
```

And that you've just done `pbpaste > /tmp/response.txt` after copying the judge's response.

### Slot 1: `council-cache-prd` judge-a (fresh Claude chat)

**Prompt file:** [`council-cache-prd__judge-a.txt`](./council-cache-prd__judge-a.txt)

```bash
bash $AGENT_FLEET_HOME/lib/blind-judge.sh judge council-cache-prd --phase1 judge-a --response-file /tmp/response.txt
```

### Slot 2: `council-cache-prd` judge-b (fresh GPT or Gemini chat)

**Prompt file:** [`council-cache-prd__judge-b.txt`](./council-cache-prd__judge-b.txt) (same content as judge-a; the `--phase1` flag differs only at journal-write time)

```bash
bash $AGENT_FLEET_HOME/lib/blind-judge.sh judge council-cache-prd --phase1 judge-b --response-file /tmp/response.txt
```

### Slot 3: `council-permtier-prd` judge-b (fresh Claude chat)

**Prompt file:** [`council-permtier-prd__judge-b.txt`](./council-permtier-prd__judge-b.txt)

```bash
bash $AGENT_FLEET_HOME/lib/blind-judge.sh judge council-permtier-prd --phase1 judge-b --response-file /tmp/response.txt
```

### Slot 4: `council-prose-40pct` judge-b (fresh Claude chat)

**Prompt file:** [`council-prose-40pct__judge-b.txt`](./council-prose-40pct__judge-b.txt)

```bash
bash $AGENT_FLEET_HOME/lib/blind-judge.sh judge council-prose-40pct --phase1 judge-b --response-file /tmp/response.txt
```

### Slot 5: `council-prose-40pct-finding` judge-b (fresh GPT or Gemini chat)

**Prompt file:** [`council-prose-40pct-finding__judge-b.txt`](./council-prose-40pct-finding__judge-b.txt)

```bash
bash $AGENT_FLEET_HOME/lib/blind-judge.sh judge council-prose-40pct-finding --phase1 judge-b --response-file /tmp/response.txt
```

### Slot 6: `council-repo-state-v010` judge-a (fresh Claude chat)

**Prompt file:** [`council-repo-state-v010__judge-a.txt`](./council-repo-state-v010__judge-a.txt)

⚠ **Note:** this is the council on agent-fleet itself (a self-review). The original phase1-worksheet excluded self-reviews — but it's the only synthesis-bearing room available as a 5th, and Phase 2 will have plenty of non-self-review rooms. Document in the calibration writeup as a known confound.

```bash
bash $AGENT_FLEET_HOME/lib/blind-judge.sh judge council-repo-state-v010 --phase1 judge-a --response-file /tmp/response.txt
```

### Slot 7: `council-repo-state-v010` judge-b (fresh GPT or Gemini chat)

**Prompt file:** [`council-repo-state-v010__judge-b.txt`](./council-repo-state-v010__judge-b.txt)

```bash
bash $AGENT_FLEET_HOME/lib/blind-judge.sh judge council-repo-state-v010 --phase1 judge-b --response-file /tmp/response.txt
```

---

## What the LLM already recorded (judge-a for slots 2/3/4)

| Room | Catch | Why | Evidence (verbatim) |
|---|---|---|---|
| `council-permtier-prd` | **true** | async pause/resume + false-security framing not in solo | "beforeToolCall block is TERMINAL (agent-loop.ts:584 returns error outcome), not pause/resume; parallel tool execution races the prompt" |
| `council-prose-40pct` | **true** | pre-registered stopping rule + per-prompt floor not in solo | "No pre-registered MDE/stopping rule → sequential peeking; two thresholds (35/40) = stop when convenient." |
| `council-prose-40pct-finding` | **true** | calibration skipped, variance-gate paradox, EXCEPTIONS untested | "judge calibration was PRE-REGISTERED mandatory (DD §0.1 + PLAN Phase B step1: hand-score ~3, >10% disagree→fix+refreeze) and was SKIPPED — entire quantitative conclusion rests on uncalibrated judge." |

When you do judge-b on these, ignore the LLM's verdicts (they're not in the prompt). Form your own.

---

## Spot-check recommendation

If you want to validate the LLM's 3 judge-a calls (recommended — meta-context contamination is real), pick ONE of slots 2/3/4 and **re-judge it as judge-a with `--force`** in a clean Claude session. Disagreement is itself a calibration signal.

```bash
# Example: redo prose-40pct judge-a in a fresh chat, overriding the existing row
bash $AGENT_FLEET_HOME/lib/blind-judge.sh judge council-prose-40pct --phase1 judge-a --force
```

The `--force` flag exists for exactly this case (per `lib/blind-judge.sh` `record` subcommand).

---

## When all 10 rows are in

```bash
# Sanity check: should show 5 distinct rooms, 10 judged rows (or 9 if you skip the spot-check redo)
bash $AGENT_FLEET_HOME/lib/journal.sh stats --judged
bash $AGENT_FLEET_HOME/lib/journal.sh stats
```

The `[calibration phase — N/5 Phase 1]` line in `stats` should disappear once 5 distinct rooms are judged and Phase 1's dual-judge invariant is met (≥3 of 5 with a judge-b row).

Then:

1. Write `docs/features/blinded-judge/calibration-phase1.md` from the [template](../calibration-phase1.template.md).
2. Include a paragraph on:
   - judge-a vs judge-b agreement rate (across the 5 rooms — count agreements where both said catch=true OR both said catch=false)
   - same-family vs cross-family observations
   - LLM-judge-a vs human-judge-a disagreement (if you do the spot-check)
   - The empty-synthesis caveat (4 of 5 rooms had no `@@from: synthesis` block — see #57)
   - The self-review caveat (`council-repo-state-v010` is a self-review)
3. Post a comment on **#48** with the writeup link. That closes #48.
4. **#1 closes too**: per the worksheet, #1's true close criterion is "calibration writeup landed," not code merge.

---

## Bail conditions

- **A prompt is too long for the chat's context window**: unlikely (all 7 are 15-26KB), but if it happens, switch to a model with a longer context (Claude Sonnet, GPT-4o, Gemini 1.5 Pro all handle this easily).
- **A judge response doesn't fit the format**: the helper will reject with a clear error (`missing ===JUDGE OUTPUT=== sentinel`, etc.). Ask the chat to retry with the exact format the rubric demands.
- **The chat refuses to engage** (rare): say "this is a meta-evaluation task; please follow the rubric format exactly." If still refusing, switch to a different family.
- **You run out of time**: do as many slots as you can. The helper records each row immediately; you can resume tomorrow without state loss.

---

## Generated by

LLM agent on 2026-06-16 after running the #48 smoke test that found and fixed #57 (via PR #59). All 7 prompt files in this directory are gitignored (regenerable from `bash lib/blind-judge.sh prepare <room> --phase1 <judge-a|judge-b>`).
