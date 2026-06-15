#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
A="$DIR/skills/council/SKILL.md"; B="$DIR/prompts/council-orchestrator.md"
for tok in '<!-- ITER_CAP=4 -->' '<!-- ITER_DEFAULT=2 -->'; do
  grep -qF "$tok" "$A" || { echo "FAIL: SKILL.md missing exact sentinel $tok"; exit 1; }
  grep -qF "$tok" "$B" || { echo "FAIL: portable prompt missing exact sentinel $tok"; exit 1; }
done
grep -q 'REFUTE FIRST' "$A" || { echo "FAIL: SKILL.md missing REFUTE FIRST"; exit 1; }
grep -q 'REFUTE FIRST' "$B" || { echo "FAIL: portable prompt missing REFUTE FIRST"; exit 1; }
# hardened red-team concession rule must be in BOTH files (red-team gate #4 finding)
for f in "$A" "$B"; do
  grep -qiE 'red-team.*(factual error|own prior)|concede.*factual error' "$f" || { echo "FAIL: $(basename "$f") missing hardened red-team concession rule"; exit 1; }
done
# capitulation headline must be in BOTH files' synthesis output template
for f in "$A" "$B"; do
  grep -qF 'council capitulated under reflection' "$f" || { echo "FAIL: $(basename "$f") missing capitulation headline"; exit 1; }
done
# FR9: Step 1 must instruct durable artifact write to room/artifact.txt (blind-judge helper depends on it)
for f in "$A" "$B"; do
  grep -qF 'rooms/council-<slug>/artifact.txt' "$f" || { echo "FAIL: $(basename "$f") missing FR9 durable artifact path"; exit 1; }
done
# Selection-table parity: every persona file in agents/ should be referenced in BOTH orchestrator
# files OR in NEITHER (asymmetric mention = a persona was added/renamed in one file but not the
# other). Catches the class of drift that occurred when occams-razor was added to the portable
# prompt's selection table but not to SKILL.md's. Uses whole-word match to avoid 'mvp' substring
# hits inside 'mvp-something' should that ever exist.
fail=0
for pf in "$DIR"/agents/*.md; do
  name=$(basename "$pf" .md)
  case "$name" in INDEX|_overlay.md.example) continue ;; esac
  in_a=0; in_b=0
  grep -qE "(^|[^a-zA-Z0-9_-])${name}([^a-zA-Z0-9_-]|$)" "$A" && in_a=1
  grep -qE "(^|[^a-zA-Z0-9_-])${name}([^a-zA-Z0-9_-]|$)" "$B" && in_b=1
  if [ "$in_a" != "$in_b" ]; then
    echo "FAIL: persona '$name' referenced in $([ "$in_a" = 1 ] && echo SKILL.md || echo portable-prompt) but NOT in $([ "$in_a" = 1 ] && echo portable-prompt || echo SKILL.md)"
    echo "       This is selection-table drift — the two orchestrators must agree on which personas exist."
    fail=1
  fi
done
[ "$fail" = 0 ] || exit 1
echo "PASS test_orchestrator_sync"
