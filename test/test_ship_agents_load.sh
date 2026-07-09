#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
EXPECTED=(ship-implementation-lead ship-spec-checker ship-test-writer ship-doc-writer ship-occams-principles)
for name in "${EXPECTED[@]}"; do
  f="$DIR/ship-agents/$name.md"
  [ -f "$f" ] || { echo "FAIL: missing $name.md"; fail=1; continue; }
  head -1 "$f" | grep -q '^---$' || { echo "FAIL: $name no frontmatter"; fail=1; }
  grep -q "^name: $name$" "$f" || { echo "FAIL: $name name field wrong"; fail=1; }
  grep -q '^description:' "$f" || { echo "FAIL: $name no description"; fail=1; }
  grep -q '^tools:' "$f" || { echo "FAIL: $name no tools"; fail=1; }
  grep -q '^model: haiku$' "$f" || { echo "FAIL: $name should default spawned subagent model to haiku"; fail=1; }
  grep -q 'Context requirements' "$f" || { echo "FAIL: $name missing context requirements"; fail=1; }
  grep -q 'strongest_counterargument' "$f" || { echo "FAIL: $name missing strongest_counterargument"; fail=1; }
  grep -q 'Output format' "$f" || { echo "FAIL: $name missing output format"; fail=1; }
done
[ "$fail" = 0 ] && echo "PASS test_ship_agents_load" || exit 1
