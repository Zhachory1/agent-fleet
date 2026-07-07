#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
A="$DIR/skills/ship/SKILL.md"
B="$DIR/prompts/ship-orchestrator.md"
EXPECTED="$(mktemp)"
trap 'rm -f "$EXPECTED"' EXIT
bash "$DIR/lib/render-ship-skill.sh" > "$EXPECTED"
if ! diff -u "$EXPECTED" "$A" >/dev/null; then
  echo "FAIL: skills/ship/SKILL.md is not generated from prompts/ship-orchestrator.md"
  echo "      Run: bash lib/render-ship-skill.sh > skills/ship/SKILL.md"
  diff -u "$EXPECTED" "$A" | head -80
  exit 1
fi
for tok in 'SHIP SCOPE' 'ACCEPTANCE CHECK' 'OCCAMS CHECK' '--mode patch' '--mode bench' '/council' '/tmp/ship-bench'; do
  grep -qF -- "$tok" "$B" || { echo "FAIL: ship prompt missing $tok"; exit 1; }
done
grep -qF 'Smallest patch wins' "$B" || { echo "FAIL: ship prompt missing minimality rule"; exit 1; }
grep -qF 'Do **not** use `/ship` to decide whether work should exist' "$B" || { echo "FAIL: ship prompt missing council boundary"; exit 1; }
echo "PASS test_ship_orchestrator_sync"
