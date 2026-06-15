# Operator self-test — first 3 councils as a "user"

> **Status**: 0/3 complete. Deadline: 2026-07-15.
> Per issue #13 (operator-as-candidate comment): the operator (also the author) runs 3 councils on real artifacts, records verbatim friction *as a user*, separately from their friction *as the author*. This does NOT satisfy the "non-author external user" milestone — that stays open.

## Why this file exists

Issue #13 named @Zhachory1 as the candidate external user 2026-06-14, unblocking the DD PR per PRD-Rev-3 procedural dependency. The honest caveat is in the issue: the operator-as-candidate is not the spirit of the issue. What this exercise DOES accomplish:

1. Forces the operator to record friction-as-a-user separately from friction-as-the-author.
2. Counts as a first verbatim writeup the issue can point to.
3. Confirms the install/onboarding path actually works for a session that didn't build the path.

What it does NOT accomplish: replacing a real external user.

## The 3 councils to run

Same selection discipline as the Phase 1 worksheet:
- Real work, not contrived test artifacts
- Mix of run-kinds (code, design, investigation)
- One must be on something the operator has NOT seen reviewed before by this tool (no anchoring)

| # | Council slug | Run-kind | Artifact source | Status |
|---|---|---|---|---|
| 1 | TBD | code | Real PR diff (not a self-review PR; ideally external repo) | [ ] |
| 2 | TBD | design | A real PRD/DD the operator is genuinely uncertain about | [ ] |
| 3 | TBD | investigation | A hypothesis-gen task (postmortem, anomaly readout) | [ ] |

## Per-council verbatim recording template

For each of the 3, fill this in **immediately after the council finishes**, not days later. Memory of friction decays in hours.

```
## Council N — <slug>

### Step-by-step where I got stuck

(Bullet list. Exact step, exact error, exact terminal output. No paraphrasing.
Example: "ran `journal.sh append` per docs. Got `journal: requires --transcript captured first`. Took 4 minutes to find that `transcript.sh capture` had to run first; the README doesn't link the two.")

### What I had to look up vs what the docs covered

(Count of times I opened a file outside the README/skill. Source of each lookup —
README, skill, AGENTS.md, INDEX.md, source code, git history.)

### Net-new catch test

Solo decision (before council): "..."
Council top-1 finding: "..."
Was this net-new vs what I'd have caught alone? yes/no/partial
Why: ...

### Time-to-data

Council started (timestamp):
Synthesis done (timestamp):
Total wall-clock:
Minutes of THINKING (not waiting on subagents):

### One thing I would NOT have figured out from the README alone

(One sentence. If "nothing" is honest, write "nothing".)
```

## Acceptance for this file

This file is "done" when:
- [ ] 3 council writeups committed below this line (one section per council, full verbatim template)
- [ ] At least one previously-filed adoption-tier issue (#4, #14) gets a comment with a concrete revision — could be "this issue should close as not-an-issue based on the self-test" OR "this issue's MINOR X should escalate to MAJOR based on the self-test."
- [ ] At least one NEW issue filed for a friction not in my pre-registered list.
- [ ] Comment on issue #13 with the link + the milestone status.

## What this file does NOT do

- Doesn't close issue #13 (a non-author user runs the same exercise is still required).
- Doesn't substitute for blinded-judge calibration (#20 / #1 are separate).
- Doesn't validate the "general-public ready" claim.

---

## Council 1 of 3 — TBD

*(Run when ready; fill template above.)*

## Council 2 of 3 — TBD

*(Run when ready; fill template above.)*

## Council 3 of 3 — TBD

*(Run when ready; fill template above.)*
