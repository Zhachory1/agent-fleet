#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
A="$DIR/skills/council/SKILL.md"
grep -q 'REFUTE FIRST' "$A" || { echo "FAIL: no refute-first ordering"; exit 1; }
# anchored: require the specific full-prior-position injection instruction (not incidental prose)
grep -qiE "peer'?s? (full )?prior-round position|full prior-round position" "$A" || { echo "FAIL: no full-prior-position injection instruction"; exit 1; }
grep -qiE 'red-team.*(factual error|own prior)|concede.*factual error' "$A" || { echo "FAIL: no hardened red-team concession rule"; exit 1; }
echo "PASS test_reflect_prompt"
