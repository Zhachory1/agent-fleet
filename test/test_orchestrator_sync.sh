#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
A="$DIR/skills/council/SKILL.md"
B="$DIR/prompts/council-orchestrator.md"

# prompts/council-orchestrator.md is the canonical protocol. The skill file is a
# generated wrapper with frontmatter. Exact generated equality prevents silent
# drift between tool installs (#56), not just selection-table drift.
EXPECTED="$(mktemp)"
trap 'rm -f "$EXPECTED"' EXIT
bash "$DIR/lib/render-council-skill.sh" > "$EXPECTED"
if ! diff -u "$EXPECTED" "$A" >/dev/null; then
  echo "FAIL: skills/council/SKILL.md is not generated from prompts/council-orchestrator.md"
  echo "      Run: bash lib/render-council-skill.sh > skills/council/SKILL.md"
  diff -u "$EXPECTED" "$A" | head -80
  exit 1
fi

for tok in '<!-- ITER_CAP=4 -->' '<!-- ITER_DEFAULT=2 -->'; do
  grep -qF "$tok" "$B" || { echo "FAIL: portable prompt missing exact sentinel $tok"; exit 1; }
done
grep -q 'REFUTE FIRST' "$B" || { echo "FAIL: portable prompt missing REFUTE FIRST"; exit 1; }
grep -qiE 'red-team.*(factual error|own prior)|concede.*factual error' "$B" || { echo "FAIL: portable prompt missing hardened red-team concession rule"; exit 1; }
grep -qF 'council capitulated under reflection' "$B" || { echo "FAIL: portable prompt missing capitulation headline"; exit 1; }
grep -qF 'agent-fleet home' "$B" || { echo "FAIL: portable prompt missing agent-fleet home fallback"; exit 1; }
grep -qF 'AGENT_CHAT_ROOT' "$B" || { echo "FAIL: portable prompt missing explicit AGENT_CHAT_ROOT"; exit 1; }
grep -qF 'AGENT_FLEET_JOURNAL' "$B" || { echo "FAIL: portable prompt missing explicit AGENT_FLEET_JOURNAL"; exit 1; }
grep -qF '$AGENT_CHAT_ROOT/rooms/$ROOM/artifact.txt' "$B" || { echo "FAIL: portable prompt missing FR9 durable artifact path"; exit 1; }
grep -qF '@@from: synthesis' "$B" || { echo "FAIL: portable prompt missing synthesis capture"; exit 1; }
grep -qF 'blind-judge.sh" candidates --all' "$B" || { echo "FAIL: portable prompt missing candidate verification"; exit 1; }
grep -qF 'Task output paths are not a' "$B" || { echo "FAIL: portable prompt missing task-output-not-transcript warning"; exit 1; }
grep -qF 'council not complete — formal room/journal capture missing' "$B" || { echo "FAIL: portable prompt missing formal capture hard stop"; exit 1; }
grep -qF 'TRUNCATION_GUARD' "$B" || { echo "FAIL: portable prompt missing task-output truncation guard"; exit 1; }
grep -qF 'at most 5 `top_issues`' "$B" || { echo "FAIL: portable prompt missing bounded top_issues cap"; exit 1; }
grep -qF -- '--mode ship' "$B" || { echo "FAIL: portable prompt missing ship mode"; exit 1; }
grep -qF -- '--mode research' "$B" || { echo "FAIL: portable prompt missing research mode"; exit 1; }
grep -qF -- '--mode domain' "$B" || { echo "FAIL: portable prompt missing domain mode"; exit 1; }
grep -qF -- '--mode exec' "$B" || { echo "FAIL: portable prompt missing exec mode"; exit 1; }
grep -qF -- '--mode minimal' "$B" || { echo "FAIL: portable prompt missing minimal mode"; exit 1; }
grep -qF -- '--personas a,b,c' "$B" || { echo "FAIL: portable prompt missing forced persona roster"; exit 1; }
for tok in 'council_artifact_kind: infrastructure' 'Capability Reuse Inventory' 'council-guard.sh" artifact' 'council-guard.sh" begin' 'COUNCIL_EXECUTION_MODE' 'capture-positions "$ROOM"' 'council-guard.sh" finish' 'journal.sh" incomplete' 'COUNCIL_INCOMPLETE' 'never author, summarize, reconstruct, or relabel' 'Execution mode: <spawned|lens-simulation>'; do
  grep -qF "$tok" "$B" || { echo "FAIL: portable prompt missing input-integrity sentinel $tok"; exit 1; }
done

# Selection-table coverage: every persona file in agents/ must be referenced by
# the canonical prompt. Generated skill equality above gives skill parity for free.
fail=0
for pf in "$DIR"/agents/*.md; do
  name=$(basename "$pf" .md)
  case "$name" in INDEX|_overlay|_rokt-overlay|_overlay.md.example) continue ;; esac
  if ! grep -qE "(^|[^a-zA-Z0-9_-])${name}([^a-zA-Z0-9_-]|$)" "$B"; then
    echo "FAIL: persona '$name' is not referenced in canonical orchestrator prompt"
    fail=1
  fi
done
[ "$fail" = 0 ] || exit 1
echo "PASS test_orchestrator_sync"
