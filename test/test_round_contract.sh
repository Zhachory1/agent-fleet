#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
# clear-majority split: 2 SHIP, 1 BLOCK → SPLIT + BLOCK surfaced as dissent
OUT="$(printf 'ml-scientist SHIP\ngeneralist-swe SHIP\nred-team BLOCK\n' | bash "$DIR/lib/synth.sh" flag)"
echo "$OUT" | grep -q "^SPLIT$" || { echo "FAIL: clear-majority split not detected"; exit 1; }
echo "$OUT" | grep -q "DISSENT:.*BLOCK" || { echo "FAIL: dissent not surfaced"; exit 1; }
# even split (no majority): 1 SHIP, 1 BLOCK → SPLIT-NO-MAJORITY, lists all verdicts, no arbitrary dissent
OUT2="$(printf 'ml-scientist SHIP\nred-team BLOCK\n' | bash "$DIR/lib/synth.sh" flag)"
echo "$OUT2" | grep -q "SPLIT-NO-MAJORITY" || { echo "FAIL: even split mislabeled"; exit 1; }
echo "$OUT2" | grep -q "VERDICT:" || { echo "FAIL: verdicts not listed on even split"; exit 1; }
echo "$OUT2" | grep -q "DISSENT:" && { echo "FAIL: arbitrary dissent on even split"; exit 1; } || true
# unanimous → false-consensus flag
OUT3="$(printf 'ml-scientist SHIP\nred-team SHIP\n' | bash "$DIR/lib/synth.sh" flag)"
echo "$OUT3" | grep -q "FALSE-CONSENSUS" || { echo "FAIL: false-consensus not flagged"; exit 1; }
# empty input → NO-INPUT (exit 1), must NOT be FALSE-CONSENSUS
OUT4="$(printf '' | bash "$DIR/lib/synth.sh" flag 2>/dev/null || true)"
echo "$OUT4" | grep -q "NO-INPUT" || { echo "FAIL: empty input not guarded (got: $OUT4)"; exit 1; }
echo "$OUT4" | grep -q "FALSE-CONSENSUS" && { echo "FAIL: empty input falsely reported consensus"; exit 1; } || true
echo "PASS test_round_contract"
