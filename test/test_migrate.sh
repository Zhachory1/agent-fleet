#!/usr/bin/env bash
# Test: journal.sh migrate idempotently fills schema defaults.
#
# Issue #14 MAJOR — operator's local journal accreted 4 different schema shapes as the
# schema evolved (pre-run_kind, +lens_baseline/issues_raised, +run_kind, +judge_*).
# This subcommand backfills missing fields with the same defaults stats uses.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"

note() { printf '  %s\n' "$*"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Build a journal with the 4 schema-era shapes from a real operator's journal.
JNL="$WORK/journal.jsonl"
{
  # Schema era 0 (oldest): pre-run_kind, pre-lens_baseline, pre-judge_*
  echo '{"ts":"2026-01-01T00:00:00Z","room":"c-old0","task":"t","solo_decision":"s","personas":["a"],"net_new_catch":true,"catch_note":"","acted_on":true,"dismissed_count":0}'
  # Schema era 1: +lens_baseline_run, +council_beat_baseline, +issues_raised (still no run_kind)
  echo '{"ts":"2026-02-01T00:00:00Z","room":"c-old1","task":"t","solo_decision":"s","personas":["a"],"net_new_catch":true,"catch_note":"","acted_on":true,"dismissed_count":0,"lens_baseline_run":false,"council_beat_baseline":null,"issues_raised":1}'
  # Schema era 2: +run_kind (still no judge_*)
  echo '{"ts":"2026-03-01T00:00:00Z","room":"c-old2","task":"t","solo_decision":"s","personas":["a"],"net_new_catch":true,"catch_note":"","acted_on":true,"dismissed_count":0,"lens_baseline_run":false,"council_beat_baseline":null,"issues_raised":1,"run_kind":"design"}'
  # Schema era 3 (current): all fields
  echo '{"ts":"2026-04-01T00:00:00Z","room":"c-new","task":"t","solo_decision":"s","personas":["a"],"net_new_catch":true,"catch_note":"","acted_on":true,"dismissed_count":0,"lens_baseline_run":false,"council_beat_baseline":null,"issues_raised":1,"run_kind":"code","judge_blinded":false,"judge_blinded_catch":null,"judge_why":"","judge_evidence":"","judge_implied_by":"","judge_reasoning":"","judge_dissent_diff":"","judge_model_family_self_reported":"","judge_prompt_version":null,"judge_template_sha256":"","judge_render_sha256":"","judge_ts":null,"solo_decision_word_count":1,"synthesis_word_count":0}'
} > "$JNL"

export AGENT_FLEET_JOURNAL="$JNL"

# --- dry-run reports correct change count (3 of 4 rows are pre-current) ---
OUT=$(bash "$DIR/lib/journal.sh" migrate --dry-run)
echo "$OUT" | grep -q "3 / 4" \
  && note "PASS dry-run reports 3 of 4 rows would change" \
  || { note "FAIL dry-run: got '$OUT'"; exit 1; }
# Dry-run must not modify the file
[ ! -f "$JNL.bak" ] && note "PASS dry-run leaves no .bak" || { note "FAIL dry-run wrote .bak"; exit 1; }

# --- migrate: writes .bak + atomic replace ---
OUT=$(bash "$DIR/lib/journal.sh" migrate)
echo "$OUT" | grep -q "3 / 4" \
  && note "PASS migrate reports 3 / 4 updated" \
  || { note "FAIL migrate report: got '$OUT'"; exit 1; }
[ -f "$JNL.bak" ] && note "PASS migrate created .bak" || { note "FAIL migrate did not create .bak"; exit 1; }

# Every row now has the full schema (18 canonical fields backfilled)
miss=$(jq -r '. | [
  has("run_kind"), has("lens_baseline_run"), has("council_beat_baseline"),
  has("issues_raised"), has("judge_blinded"), has("judge_blinded_catch"),
  has("judge_why"), has("judge_evidence"), has("judge_implied_by"),
  has("judge_reasoning"), has("judge_dissent_diff"),
  has("judge_model_family_self_reported"), has("judge_prompt_version"),
  has("judge_template_sha256"), has("judge_render_sha256"), has("judge_ts"),
  has("solo_decision_word_count"), has("synthesis_word_count")
] | all' "$JNL" | sort -u)
[ "$miss" = "true" ] && note "PASS every row has all canonical fields" \
  || { note "FAIL some row still missing fields after migrate"; jq -c '.' "$JNL"; exit 1; }

# Defaults are correct: oldest row should now have run_kind="code", lens_baseline_run=false, etc.
oldest_kind=$(jq -r 'select(.room=="c-old0") | .run_kind' "$JNL")
[ "$oldest_kind" = "code" ] && note "PASS oldest row got run_kind=code default" \
  || { note "FAIL oldest run_kind: $oldest_kind"; exit 1; }
oldest_judge=$(jq -r 'select(.room=="c-old0") | .judge_blinded' "$JNL")
[ "$oldest_judge" = "false" ] && note "PASS oldest row got judge_blinded=false default" \
  || { note "FAIL oldest judge_blinded: $oldest_judge"; exit 1; }
oldest_baseline=$(jq -r 'select(.room=="c-old0") | .council_beat_baseline' "$JNL")
[ "$oldest_baseline" = "null" ] && note "PASS oldest row got council_beat_baseline=null default" \
  || { note "FAIL oldest council_beat_baseline: $oldest_baseline"; exit 1; }

# Current-schema row is byte-identical (no fields touched)
new_after=$(jq -c 'select(.room=="c-new")' "$JNL")
new_before=$(jq -c 'select(.room=="c-new")' "$JNL.bak")
[ "$new_after" = "$new_before" ] && note "PASS current-schema row unchanged by migrate" \
  || { note "FAIL current-schema row changed: \nbefore: $new_before\nafter:  $new_after"; exit 1; }

# --- idempotency: second migrate is a no-op ---
OUT=$(bash "$DIR/lib/journal.sh" migrate)
echo "$OUT" | grep -q "already up to date" \
  && note "PASS second migrate is no-op" \
  || { note "FAIL second migrate not idempotent: $OUT"; exit 1; }

# --- empty / missing journal ---
EMPTY="$WORK/empty.jsonl"
OUT=$(AGENT_FLEET_JOURNAL="$EMPTY" bash "$DIR/lib/journal.sh" migrate 2>&1)
echo "$OUT" | grep -q "no journal" \
  && note "PASS missing journal handled gracefully" \
  || { note "FAIL missing journal: $OUT"; exit 1; }

echo "PASS test_migrate"
