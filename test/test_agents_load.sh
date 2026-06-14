#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXPECTED=(ml-scientist ab-critic reliability-sentinel software-architect generalist-swe red-team \
  data-engineer perf-engineer product-pm cost-finops docs-dx pre-mortem cto ceo vp-eng)
fail=0
for name in "${EXPECTED[@]}"; do
  f="$DIR/agents/$name.md"
  [ -f "$f" ] || { echo "FAIL: missing $name.md"; fail=1; continue; }
  head -1 "$f" | grep -q '^---$' || { echo "FAIL: $name no frontmatter"; fail=1; }
  grep -q "^name: $name$" "$f" || { echo "FAIL: $name name field wrong"; fail=1; }
  grep -q "^tools:" "$f" || { echo "FAIL: $name no tools"; fail=1; }
  grep -q "strongest_counterargument" "$f" || { echo "FAIL: $name missing mandatory dissent"; fail=1; }
  grep -q "_overlay.md" "$f" || { echo "FAIL: $name no overlay hook"; fail=1; }
  # reflection alignment: no stale soft round-2 line (contradicts REFUTE-FIRST); must carry REFUTE FIRST
  grep -qi 'agree, refute, or sharpen' "$f" && { echo "FAIL: $name has stale soft round-2 line"; fail=1; }
  grep -q "REFUTE FIRST" "$f" || { echo "FAIL: $name missing REFUTE FIRST reflection alignment"; fail=1; }
done
[ "$fail" = "0" ] && echo "PASS test_agents_load" || exit 1
