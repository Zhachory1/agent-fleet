#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export AGENT_CHAT_ROOT="$(mktemp -d)"
export AGENT_FLEET_JOURNAL="$(mktemp -d)/journal.jsonl"
ROOM="council-review-model-x"

# GUARD: append must REFUSE (exit 2) when the room has no transcript
set +e
"$DIR/lib/journal.sh" append "$ROOM" "review-model-x" "ship as-is" "ml-scientist,ab-critic" true "missed skew" true 1 2>/dev/null
rc=$?; set -e
[ "$rc" = "2" ] || { echo "FAIL: journal should refuse (exit 2) without transcript, got $rc"; exit 1; }
[ ! -s "$AGENT_FLEET_JOURNAL" ] || { echo "FAIL: journal wrote a line despite no transcript"; exit 1; }

# capture a transcript -> now append succeeds
printf '@@from: ml-scientist\nverdict: BLOCK\n- [BLOCKER] skew\n' | "$DIR/lib/transcript.sh" capture "$ROOM"
"$DIR/lib/journal.sh" append "$ROOM" "review-model-x" "ship as-is" "ml-scientist,ab-critic" true "missed skew" true 1
[ -s "$AGENT_FLEET_JOURNAL" ] || { echo "FAIL: journal not written after capture"; exit 1; }
jq -e '.room=="'"$ROOM"'" and .net_new_catch==true and .acted_on==true and .dismissed_count==1' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: fields wrong"; exit 1; }
# backward-compat defaults for the new optional fields
jq -e '.lens_baseline_run==false and .council_beat_baseline==null and .issues_raised==0 and .run_kind=="code"' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: new-field defaults wrong"; exit 1; }

# full call with baseline + issues_raised + run_kind (same room, already has transcript)
"$DIR/lib/journal.sh" append "$ROOM" "t2" "solo" "red-team" true "n" true 2 true true 5 investigation
jq -se '.[1] | .lens_baseline_run==true and .council_beat_baseline==true and .issues_raised==5 and .run_kind=="investigation"' "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: full-arg fields wrong"; exit 1; }

# run_kind validation: reject bogus value
set +e
"$DIR/lib/journal.sh" append "$ROOM" "t-bad" "solo" "red-team" true "n" true 0 false null 0 garbage 2>/dev/null
rc=$?; set -e
[ "$rc" = "1" ] || { echo "FAIL: bad run_kind should reject (exit 1), got $rc"; exit 1; }

# test override lets append through with no transcript (for harnesses/tests)
export AGENT_FLEET_REQUIRE_TRANSCRIPT=0
"$DIR/lib/journal.sh" append "council-no-room" "t3" "solo" "ml-scientist" false "n" false 0 \
  || { echo "FAIL: override should allow append without transcript"; exit 1; }
unset AGENT_FLEET_REQUIRE_TRANSCRIPT

# stats: 3 runs, 2 catches -> 66% PASS; false-alarm (1+2+0)/(0+5+0)=3/5
# Split: row1 = code (default), row2 = investigation, row3 = code (default)
# code/design acted-on = 2/2 (row1 + row3 both acted=true/false? row1 acted=true row3 acted=false)
#   actually row3 was the override row with acted=false -> 1/2 = 50%
# investigations acted-on = 1/1 = 100%
OUT="$("$DIR/lib/journal.sh" stats)"
echo "$OUT" | grep -q "net-new catch rate : 2/3" || { echo "FAIL: stats catch count wrong: $OUT"; exit 1; }
echo "$OUT" | grep -q "gate ≥40%: PASS" || { echo "FAIL: stats gate not PASS"; exit 1; }
echo "$OUT" | grep -q "false-alarm rate   : 3/5" || { echo "FAIL: stats false-alarm denom wrong: $OUT"; exit 1; }
echo "$OUT" | grep -q "acted-on (code+design): 1/2" || { echo "FAIL: stats code/design acted-on wrong: $OUT"; exit 1; }
echo "$OUT" | grep -q "hypotheses pursued (investigations): 1/1" || { echo "FAIL: stats investigations wrong: $OUT"; exit 1; }
echo "$OUT" | grep -q "runs by kind       : code=2, design=0, investigation=1" || { echo "FAIL: stats run-kind breakdown wrong: $OUT"; exit 1; }

# empty journal -> graceful
export AGENT_FLEET_JOURNAL="$(mktemp -d)/empty.jsonl"; touch "$AGENT_FLEET_JOURNAL"
"$DIR/lib/journal.sh" stats | grep -q "no runs logged yet" || { echo "FAIL: empty-journal stats not graceful"; exit 1; }
echo "PASS test_journal"

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
jq -se '.[-1] | .judge_blinded==true and .judge_blinded_catch==true and .judge_evidence!="" and
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
jq -se '.[-1] | .judge_blinded==true and .net_new_catch==null and .acted_on==null and .room=="'"$ROOM_K"'"' \
  "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: judge-only row should have judge_blinded=true and self-report fields=null"; exit 1; }

# Issue #3: kw-args form (PREFERRED entry path).
ROOM_KW=council-kwargs-row
"$DIR/lib/transcript.sh" capture "$ROOM_KW" <<<"@@from: a
verdict: SHIP"
"$DIR/lib/journal.sh" append \
  --room "$ROOM_KW" \
  --task "kwargs-test" \
  --solo "ship as-is" \
  --personas "ml-scientist,red-team" \
  --net-new-catch true \
  --note "a finding" \
  --acted-on true \
  --dismissed-count 2 \
  --lens-baseline true \
  --council-beat-baseline true \
  --issues-raised 4 \
  --run-kind design
jq -se --arg r "$ROOM_KW" '.[-1] | .room==$r and .task=="kwargs-test" and .net_new_catch==true and .acted_on==true and .dismissed_count==2 and .lens_baseline_run==true and .council_beat_baseline==true and .issues_raised==4 and .run_kind=="design"' \
  "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: kw-args write didn't populate all fields correctly"; exit 1; }

# kw-args: missing required field MUST error
set +e
"$DIR/lib/journal.sh" append --room "$ROOM_KW" --task t --personas p --net-new-catch true --acted-on true 2>/dev/null
rc=$?; set -e
[ "$rc" = "1" ] || { echo "FAIL: kw-args without --solo should reject (exit 1), got $rc"; exit 1; }

# kw-args: unknown flag MUST error
set +e
"$DIR/lib/journal.sh" append --room x --task t --solo s --personas p --net-new-catch true --acted-on true --not-a-real-flag yes 2>/dev/null
rc=$?; set -e
[ "$rc" = "1" ] || { echo "FAIL: kw-args with unknown flag should reject (exit 1), got $rc"; exit 1; }

# --help works at top level and prints kw-args usage
"$DIR/lib/journal.sh" --help | grep -q -- "--net-new-catch" || { echo "FAIL: --help missing kw-args usage"; exit 1; }

# Mixed-style: positional + judge-* trailing kw-args still works (back-compat)
ROOM_MIXED=council-mixed-row
"$DIR/lib/transcript.sh" capture "$ROOM_MIXED" <<<"@@from: a
verdict: SHIP"
"$DIR/lib/journal.sh" append "$ROOM_MIXED" mixed s a true "" true 0 false null 1 code \
  --judge-blinded true --judge-catch false --judge-why "covered" \
  --judge-reasoning "r" --judge-dissent-diff "- (none)" \
  --judge-model-family claude --judge-prompt-version v2
jq -se --arg r "$ROOM_MIXED" '.[-1] | .room==$r and .judge_blinded==true and .judge_blinded_catch==false' \
  "$AGENT_FLEET_JOURNAL" >/dev/null \
  || { echo "FAIL: mixed positional + judge-* kw-args broke"; exit 1; }
