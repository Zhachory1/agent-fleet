#!/usr/bin/env bash
# All bash helpers report the same version from the VERSION file.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"

[ -f "$DIR/VERSION" ] || { echo "FAIL: VERSION file missing"; exit 1; }
EXPECTED=$(cat "$DIR/VERSION" | tr -d '[:space:]')
[ -n "$EXPECTED" ] || { echo "FAIL: VERSION file is empty"; exit 1; }

fail=0
for helper in "$DIR/install.sh" "$DIR/lib/journal.sh" "$DIR/lib/transcript.sh" \
              "$DIR/lib/synth.sh" "$DIR/lib/blind-judge.sh" "$DIR/lib/overlay.sh"; do
  actual=$(bash "$helper" --version 2>&1 | tr -d '[:space:]')
  if [ "$actual" != "$EXPECTED" ]; then
    echo "FAIL: $(basename "$helper") --version returned '$actual', expected '$EXPECTED'"
    fail=1
  fi
  # Also verify -V short form
  actual_short=$(bash "$helper" -V 2>&1 | tr -d '[:space:]')
  if [ "$actual_short" != "$EXPECTED" ]; then
    echo "FAIL: $(basename "$helper") -V returned '$actual_short', expected '$EXPECTED'"
    fail=1
  fi
done

# install.sh --help must include version + Options section
help=$(bash "$DIR/install.sh" --help 2>&1)
if ! grep -q "agent-fleet installer v" <<<"$help"; then
  echo "FAIL: install.sh --help missing version banner"
  fail=1
fi
if ! grep -q "^Options:" <<<"$help"; then
  echo "FAIL: install.sh --help missing Options: section"
  fail=1
fi

# install.sh unknown arg must exit 1 with 'try --help'
set +e
out=$(bash "$DIR/install.sh" --not-a-flag 2>&1)
rc=$?
set -e
if [ "$rc" != "1" ]; then
  echo "FAIL: install.sh unknown arg should exit 1, got $rc"
  fail=1
fi
if ! grep -q "try --help" <<<"$out"; then
  echo "FAIL: install.sh unknown arg should mention --help"
  fail=1
fi

[ "$fail" = "0" ] && echo "PASS test_version" || exit 1
