#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
CORE=(ml-scientist ab-critic reliability-sentinel software-architect generalist-swe red-team)
EXPERIMENTAL=(data-engineer perf-engineer product-pm cost-finops docs-dx pre-mortem cto ceo vp-eng mvp occams-razor)
EXPECTED=("${CORE[@]}" "${EXPERIMENTAL[@]}")
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

# Issue #9: surface (experimental) tag on persona descriptions so selection UIs that read
# frontmatter (not INDEX.md) carry the warning. Invariant:
#   Core Six persona description MUST NOT start with '[experimental]'
#   Experimental persona description MUST start with '[experimental]'
for name in "${CORE[@]}"; do
  f="$DIR/agents/$name.md"
  if grep -q '^description:.*\[experimental\]' "$f"; then
    echo "FAIL: $name is Core but description starts with [experimental]"; fail=1
  fi
done
for name in "${EXPERIMENTAL[@]}"; do
  f="$DIR/agents/$name.md"
  if ! grep -q '^description:[^\n]*\[experimental\]' "$f"; then
    echo "FAIL: $name is experimental but description does not carry [experimental] tag"; fail=1
  fi
  # YAML frontmatter validity: an UNQUOTED '[experimental]' at the start of a value is
  # interpreted by YAML as a flow-sequence start — the parser blows up on the closing ']'.
  # All experimental personas MUST quote their description (either single or double quotes).
  # Detects the specific regression that shipped in PR #26 + survived until manually flagged.
  desc_line=$(grep -m1 '^description:' "$f" || true)
  case "$desc_line" in
    'description: "['*|"description: '["*) : ;;  # OK: quoted value starting with [
    'description: ['*)
      echo "FAIL: $name has unquoted '[experimental]' in description — breaks YAML frontmatter"
      echo "       line: $desc_line"
      echo "       fix:  wrap the description value in single quotes (escape any ' as '')"
      fail=1
      ;;
  esac
done

[ "$fail" = "0" ] && echo "PASS test_agents_load" || exit 1
