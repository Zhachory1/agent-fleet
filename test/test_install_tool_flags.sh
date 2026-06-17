#!/usr/bin/env bash
# Test: install.sh --tool cursor|opencode|codex|cave place files into expected default dirs.
# Validates tool-shortcut aliases added for issue #14 MAJOR plus cross-tool installs (#52/#53/#58).
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXTRA_PERSONA="$DIR/agents/cave-tool-map-fixture.md"
trap 'rm -f "$EXTRA_PERSONA"' EXIT
fail=0

# How many persona .md files exist (excludes catalog + private/example overlays).
expected_personas=$(find "$DIR/agents" -maxdepth 1 -name '*.md' \
  ! -name 'INDEX.md' ! -name '_overlay.md' ! -name '_overlay.md.example' | wc -l | tr -d ' ')
expected_files=$((expected_personas + 1))  # personas + council-orchestrator.md

for tool_spec in "cursor:./.cursor/rules" "opencode:./.agent-fleet" "codex:./.agent-fleet"; do
  tool="${tool_spec%%:*}"
  expected_dir="${tool_spec##*:}"
  tmp=$(mktemp -d)
  ( cd "$tmp" && HOME="$tmp/home" bash "$DIR/install.sh" --tool "$tool" >/dev/null 2>&1 ) || {
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
  if [ ! -f "$placed_dir/council-orchestrator.md" ]; then
    echo "FAIL: --tool $tool did not place council-orchestrator.md"; fail=1
  fi
  sample=$(find "$placed_dir" -maxdepth 1 -name 'red-team.md' | head -1)
  if [ -L "$sample" ]; then
    echo "FAIL: --tool $tool placed symlinks; should be copies (sandboxes break symlinks)"
    fail=1
  fi
  if [ "$tool" = "codex" ]; then
    if [ ! -f "$tmp/home/.codex/skills/council/SKILL.md" ]; then
      echo "FAIL: --tool codex did not install council skill into ~/.codex/skills/council"
      fail=1
    fi
    ( cd "$tmp" && HOME="$tmp/home" bash "$DIR/install.sh" --tool codex --uninstall >/dev/null 2>&1 ) || {
      echo "FAIL: install.sh --tool codex --uninstall exited non-zero"; fail=1
    }
    if [ -e "$tmp/home/.codex/skills/council" ]; then
      echo "FAIL: --tool codex --uninstall did not remove council skill"
      fail=1
    fi
  fi
  rm -rf "$tmp"
done

# Cave uses distinct resource dirs and needs lowercase tool names in installed persona copies.
tmp=$(mktemp -d)
( cd "$tmp" && HOME="$tmp/home" bash "$DIR/install.sh" --tool cave >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --tool cave exited non-zero"; fail=1
}
if [ -d "$tmp/.cave/agents" ]; then
  n=$(find "$tmp/.cave/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
  if [ "$n" != "$expected_personas" ]; then
    echo "FAIL: --tool cave placed $n persona files; expected $expected_personas"
    fail=1
  fi
else
  echo "FAIL: --tool cave did not create ./.cave/agents"
  fail=1
fi
if [ -f "$tmp/.cave/agents/council-orchestrator.md" ]; then
  echo "FAIL: --tool cave put orchestrator prompt in .cave/agents"
  fail=1
fi
if [ ! -f "$tmp/.cave/prompts/council-orchestrator.md" ]; then
  echo "FAIL: --tool cave did not install orchestrator prompt into .cave/prompts"
  fail=1
fi
if [ ! -f "$tmp/.cave/skills/council/SKILL.md" ]; then
  echo "FAIL: --tool cave did not install council skill into .cave/skills/council"
  fail=1
fi
if ! grep -q '^tools: read, find, grep, bash$' "$tmp/.cave/agents/red-team.md"; then
  echo "FAIL: --tool cave did not rewrite persona tools to Cave lowercase names"
  fail=1
fi
if grep -q '^tools: Read, Glob, Grep, Bash$' "$tmp/.cave/agents/red-team.md"; then
  echo "FAIL: --tool cave left Claude-Code-cased tool names in installed Cave persona"
  fail=1
fi
( cd "$tmp" && HOME="$tmp/home" bash "$DIR/install.sh" --tool cave --uninstall >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --tool cave --uninstall exited non-zero"; fail=1
}
if [ -f "$tmp/.cave/agents/red-team.md" ] || [ -e "$tmp/.cave/skills/council" ] || [ -f "$tmp/.cave/prompts/council-orchestrator.md" ]; then
  echo "FAIL: --tool cave --uninstall left installed files behind"
  fail=1
fi
rm -rf "$tmp"

# Cave tool mapping is per declared tool, not a hardcoded tools line.
cat > "$EXTRA_PERSONA" <<'EOF'
---
name: cave-tool-map-fixture
description: test-only fixture for Cave tool mapping
tools: Read, Write, Glob, Grep, Bash, NotReal
---
body
EOF
tmp=$(mktemp -d)
set +e
OUT=$(cd "$tmp" && HOME="$tmp/home" bash "$DIR/install.sh" --tool cave 2>&1)
rc=$?
set -e
if [ "$rc" != "0" ]; then
  echo "FAIL: --tool cave with mapping fixture exited $rc: $OUT"; fail=1
fi
if ! grep -q '^tools: read, write, find, grep, bash, NotReal$' "$tmp/.cave/agents/cave-tool-map-fixture.md"; then
  echo "FAIL: --tool cave did not map declared tools per token"
  fail=1
fi
echo "$OUT" | grep -q 'WARN Cave tool has no mapping: NotReal' \
  || { echo "FAIL: --tool cave did not warn on unmapped tool: $OUT"; fail=1; }
rm -rf "$tmp"
rm -f "$EXTRA_PERSONA"

# Cave user-scope layout uses Cave's user resource dirs.
tmp=$(mktemp -d)
( cd "$tmp" && HOME="$tmp/home" bash "$DIR/install.sh" --tool cave --user >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --tool cave --user exited non-zero"; fail=1
}
if [ ! -f "$tmp/home/.cave/agent/agents/red-team.md" ]; then
  echo "FAIL: --tool cave --user did not install personas into ~/.cave/agent/agents"
  fail=1
fi
if [ ! -f "$tmp/home/.cave/skills/council/SKILL.md" ]; then
  echo "FAIL: --tool cave --user did not install skill into ~/.cave/skills/council"
  fail=1
fi
if [ ! -f "$tmp/home/.cave/prompts/council-orchestrator.md" ]; then
  echo "FAIL: --tool cave --user did not install prompt into ~/.cave/prompts"
  fail=1
fi
rm -rf "$tmp"

set +e
OUT=$(HOME="$(mktemp -d)" bash "$DIR/install.sh" --tool codex --user 2>&1)
rc=$?
set -e
[ "$rc" != "0" ] && echo "$OUT" | grep -q -- '--user/--project only applies to --tool cave' \
  || { echo "FAIL: --tool codex --user should reject as Cave-only scope flag: rc=$rc out='$OUT'"; fail=1; }

[ "$fail" = "0" ] && echo "PASS test_install_tool_flags" || exit 1
