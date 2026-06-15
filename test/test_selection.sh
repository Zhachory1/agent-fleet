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
grep -qiE 'red-team.*(auto|force).*(includ|multi-iter|iterations)|force-include red-team' "$DIR/skills/council/SKILL.md" \
  || { echo "FAIL: red-team auto-include rule missing"; exit 1; }

# Persona cap (Rev 3): minimum 3, maximum 6. Both SKILL.md and the portable prompt MUST agree.
for f in "$DIR/skills/council/SKILL.md" "$DIR/prompts/council-orchestrator.md"; do
  grep -q '3-6 personas\|Select 3-6\|pick 3-6\|3-6 by task' "$f" \
    || { echo "FAIL: $(basename "$f") missing the 3-6 persona-cap text"; exit 1; }
  # Stale 2-4 references would be a regression (excluding 'was 2-4' historical notes).
  if grep -E '(pick|Select|select|cap) (at )?2-4|2-4 personas' "$f" >/dev/null; then
    if grep -E '(pick|Select|select|cap) (at )?2-4|2-4 personas' "$f" | grep -v 'was 2-4' | grep -q .; then
      echo "FAIL: $(basename "$f") still has stale 2-4 persona-cap references"; exit 1
    fi
  fi
done

# Verify ALL 16 personas appear in the selection table — both Core Six and the 10 experimentals.
for name in ml-scientist ab-critic reliability-sentinel software-architect generalist-swe red-team \
            data-engineer perf-engineer product-pm cost-finops docs-dx pre-mortem cto ceo vp-eng mvp; do
  # The selection table is between '## Step 2' and 'State the selected personas'
  awk '/^## Step 2/,/State the selected personas/' "$DIR/skills/council/SKILL.md" | grep -q "\\b$name\\b" \
    || { echo "FAIL: persona '$name' missing from SKILL.md selection table"; exit 1; }
done

echo "PASS test_selection"
