#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
S="$DIR/lib/synth.sh"
# clean convergence: all verdicts identical prev->curr, no flip
OUT=$(printf 'a SHIP 1\nb SHIP 2\n---\na SHIP 1\nb SHIP 2\n' | bash "$S" converged); echo "$OUT" | grep -qx CONVERGED || { echo "FAIL converged: $OUT"; exit 1; }
# a real change (no suspicious flip): one verdict differs, not toward a majority capitulation
OUT=$(printf 'a SHIP 2\nb BLOCK 2\n---\na SHIP 2\nb NEED-MORE-INFO 2\n' | bash "$S" converged); echo "$OUT" | grep -qx CHANGED || { echo "FAIL changed: $OUT"; exit 1; }
# synchronized capitulation: >=2 flip to curr majority
OUT=$(printf 'a BLOCK 3\nb SHIP 2\nc BLOCK 4\n---\na SHIP 1\nb SHIP 2\nc SHIP 0\n' | bash "$S" converged); echo "$OUT" | grep -qx SUSPICIOUS-FLIP || { echo "FAIL sync-flip: $OUT"; exit 1; }
# substance degradation: single flip toward majority with dropped issue count
OUT=$(printf 'a SHIP 2\nb SHIP 2\nc BLOCK 4\n---\na SHIP 2\nb SHIP 2\nc SHIP 0\n' | bash "$S" converged); echo "$OUT" | grep -qx SUSPICIOUS-FLIP || { echo "FAIL substance: $OUT"; exit 1; }
# boundary: flip toward majority with EQUAL issue count is just CHANGED, not suspicious
OUT=$(printf 'a SHIP 2\nb SHIP 2\nc BLOCK 2\n---\na SHIP 2\nb SHIP 2\nc SHIP 2\n' | bash "$S" converged); echo "$OUT" | grep -qx CHANGED || { echo "FAIL equal-count-boundary: $OUT"; exit 1; }
# missing issue_count on a flipping curr line must NOT be treated as 0 (no false degradation) -> CHANGED
OUT=$(printf 'a BLOCK 2\nb SHIP 2\n---\na SHIP\nb SHIP 2\n' | bash "$S" converged); echo "$OUT" | grep -qx CHANGED || { echo "FAIL missing-count: $OUT"; exit 1; }
# persona in curr absent from prev must not crash and must not be a false change -> CONVERGED
OUT=$(printf 'a SHIP 1\n---\na SHIP 1\nb SHIP 2\n' | bash "$S" converged); echo "$OUT" | grep -qx CONVERGED || { echo "FAIL missing-prev-persona: $OUT"; exit 1; }
# flip-beats-changed priority: 2 flip to majority (issues drop) AND changed=1 -> SUSPICIOUS-FLIP, not CHANGED
OUT=$(printf 'a BLOCK 2\nb BLOCK 2\nc SHIP 2\n---\na SHIP 1\nb SHIP 1\nc SHIP 2\n' | bash "$S" converged); echo "$OUT" | grep -qx SUSPICIOUS-FLIP || { echo "FAIL flip-beats-changed: $OUT"; exit 1; }
# malformed: separator first (empty prev block) -> NO-INPUT exit 1
set +e; OUT=$(printf '%s\n' '---' 'a SHIP 1' | bash "$S" converged 2>/dev/null); rc=$?; set -e
[ "$rc" = 1 ] && echo "$OUT" | grep -qx NO-INPUT || { echo "FAIL sep-first: rc=$rc $OUT"; exit 1; }
# malformed: curr lines lacking a verdict field (empty majority) -> NO-INPUT, not spurious SUSPICIOUS-FLIP
set +e; OUT=$(printf 'a\nb\n---\na\nb\n' | bash "$S" converged 2>/dev/null); rc=$?; set -e
[ "$rc" = 1 ] && echo "$OUT" | grep -qx NO-INPUT || { echo "FAIL empty-verdict: rc=$rc $OUT"; exit 1; }
# malformed: two separators -> NO-INPUT exit 1
set +e; OUT=$(printf 'a SHIP 1\n---\nb SHIP 1\n---\na SHIP 1\n' | bash "$S" converged 2>/dev/null); rc=$?; set -e
[ "$rc" = 1 ] && echo "$OUT" | grep -qx NO-INPUT || { echo "FAIL double-sep: rc=$rc $OUT"; exit 1; }
# empty -> NO-INPUT exit 1
set +e; OUT=$(printf '' | bash "$S" converged 2>/dev/null); rc=$?; set -e
[ "$rc" = 1 ] && echo "$OUT" | grep -qx NO-INPUT || { echo "FAIL no-input: rc=$rc $OUT"; exit 1; }
echo "PASS test_converged"
