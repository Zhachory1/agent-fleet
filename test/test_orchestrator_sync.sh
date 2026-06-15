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
echo "PASS test_orchestrator_sync"
