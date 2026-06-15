#!/usr/bin/env bash
# Test: install.sh --tool cursor|opencode|codex place files into expected default dirs.
# Validates the tool-shortcut aliases added for issue #14 MAJOR ('install.sh --tool ...').
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

# How many persona .md files exist (excludes INDEX.md and _overlay.md.example).
expected_personas=$(find "$DIR/agents" -maxdepth 1 -name '*.md' \
  ! -name 'INDEX.md' ! -name '_overlay.md.example' | wc -l | tr -d ' ')
expected_files=$((expected_personas + 1))  # personas + council-orchestrator.md

for tool_spec in "cursor:./.cursor/rules" "opencode:./.agent-fleet" "codex:./.agent-fleet"; do
  tool="${tool_spec%%:*}"
  expected_dir="${tool_spec##*:}"
  tmp=$(mktemp -d)
  ( cd "$tmp" && bash "$DIR/install.sh" --tool "$tool" >/dev/null 2>&1 ) || {
    echo "FAIL: install.sh --tool $tool exited non-zero"; fail=1; rm -rf "$tmp"; continue
  }
  placed_dir="$tmp/${expected_dir#./}"
  if [ ! -d "$placed_dir" ]; then
    echo "FAIL: --tool $tool did not create $expected_dir"; fail=1; rm -rf "$tmp"; continue
  fi
  n=$(find "$placed_dir" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
  if [ "$n" != "$expected_files" ]; then
    echo "FAIL: --tool $tool placed $n files into $expected_dir; expected $expected_files"
    fail=1
  fi
  # orchestrator prompt must be present
  if [ ! -f "$placed_dir/council-orchestrator.md" ]; then
    echo "FAIL: --tool $tool did not place council-orchestrator.md"; fail=1
  fi
  # placed files must be copies (not symlinks) — Cursor sandbox + opencode discovery break symlinks
  sample=$(find "$placed_dir" -maxdepth 1 -name 'red-team.md' | head -1)
  if [ -L "$sample" ]; then
    echo "FAIL: --tool $tool placed symlinks; should be copies (sandboxes break symlinks)"
    fail=1
  fi
  rm -rf "$tmp"
done

[ "$fail" = "0" ] && echo "PASS test_install_tool_flags" || exit 1
