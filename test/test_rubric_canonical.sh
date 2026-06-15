#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
DD="$DIR/docs/features/blinded-judge/DD.md"
RUBRIC="$DIR/lib/blind-judge-prompt.v2.txt"
[ -f "$RUBRIC" ] || { echo "FAIL: rubric file missing"; exit 1; }
# Extract the first fenced code block under '## Canonical rubric' header.
EXTRACTED=$(awk '
  /^## Canonical rubric/ {in_section=1; next}
  in_section && /^```$/ && !in_code {in_code=1; next}
  in_section && in_code && /^```$/ {in_code=0; in_section=0; exit}
  in_section && in_code {print}
' "$DD")
# Compare with whitespace normalized (trailing whitespace + blank-line runs collapsed).
norm() { sed 's/[[:space:]]*$//' | cat -s; }
diff <(printf '%s\n' "$EXTRACTED" | norm) <(norm < "$RUBRIC") \
  || { echo "FAIL: rubric file drifts from DD canonical block (above diff)"; exit 1; }
echo "PASS test_rubric_canonical"
