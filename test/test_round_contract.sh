#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
# split case: one SHIP one BLOCK → SPLIT + dissent surfaced
OUT="$(printf 'ml-scientist SHIP\nred-team BLOCK\n' | bash "$DIR/lib/synth.sh" flag)"
echo "$OUT" | grep -q "SPLIT" || { echo "FAIL: split not detected"; exit 1; }
echo "$OUT" | grep -q "DISSENT:" || { echo "FAIL: dissent not surfaced"; exit 1; }
# unanimous case → false-consensus flag
OUT2="$(printf 'ml-scientist SHIP\nred-team SHIP\n' | bash "$DIR/lib/synth.sh" flag)"
echo "$OUT2" | grep -q "FALSE-CONSENSUS" || { echo "FAIL: false-consensus not flagged"; exit 1; }
echo "PASS test_round_contract"
