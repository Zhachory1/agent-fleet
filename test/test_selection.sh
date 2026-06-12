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
