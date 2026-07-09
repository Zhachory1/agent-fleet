#!/usr/bin/env bash
# Test: install.sh --tool cursor|opencode|codex|cave place files into expected default dirs.
# Validates tool-shortcut aliases added for issue #14 MAJOR plus cross-tool installs (#52/#53/#58).
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXTRA_PERSONA="$DIR/agents/cave-tool-map-fixture.md"
TEST_PARENT_TMP=$(mktemp -d)
trap 'rm -f "$EXTRA_PERSONA"; rm -rf "$TEST_PARENT_TMP"' EXIT
mktemp_d() { mktemp -d "$TEST_PARENT_TMP/d.XXXXXX"; }
fail=0

# How many installable agent .md files exist (council personas + ship implementation agents).
expected_personas=$(find "$DIR/agents" -maxdepth 1 -name '*.md' \
  ! -name 'INDEX.md' ! -name '_overlay.md' ! -name '_rokt-overlay.md' ! -name '_overlay.md.example' | wc -l | tr -d ' ')
expected_ship_agents=$(find "$DIR/ship-agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
expected_agents=$((expected_personas + expected_ship_agents))
expected_files=$((expected_agents + 2))  # agents + council-orchestrator.md + ship-orchestrator.md

# Payload iteration must survive repo paths with spaces.
tmp=$(mktemp_d)
space_repo="$tmp/agent fleet"
ln -s "$DIR" "$space_repo"
SPACE_HOME="$tmp/mewrite home"
( cd "$tmp" && HOME="$tmp/home" bash "$space_repo/install.sh" --dir "$SPACE_HOME" >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --dir failed when repo path contains spaces"; fail=1
}
if [ ! -f "$SPACE_HOME/agents/red-team.md" ] || [ ! -f "$SPACE_HOME/agents/ship-spec-checker.md" ]; then
  echo "FAIL: space-path install did not place expected agents"
  fail=1
fi
rm -rf "$tmp"

for tool_spec in "cursor:./.cursor/rules" "opencode:./.agent-fleet" "codex:./.agent-fleet"; do
  tool="${tool_spec%%:*}"
  expected_dir="${tool_spec##*:}"
  tmp=$(mktemp_d)
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
  if [ ! -f "$placed_dir/ship-orchestrator.md" ]; then
    echo "FAIL: --tool $tool did not place ship-orchestrator.md"; fail=1
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
    if [ ! -f "$tmp/home/.codex/skills/ship/SKILL.md" ]; then
      echo "FAIL: --tool codex did not install ship skill into ~/.codex/skills/ship"
      fail=1
    fi
    if [ ! -f "$tmp/home/.codex/agent-fleet/agents/red-team.md" ]; then
      echo "FAIL: --tool codex did not install persona payload into ~/.codex/agent-fleet/agents"
      fail=1
    fi
    if [ ! -f "$tmp/home/.codex/agent-fleet/prompts/council-orchestrator.md" ]; then
      echo "FAIL: --tool codex did not install prompt payload into ~/.codex/agent-fleet/prompts"
      fail=1
    fi
    if [ ! -f "$tmp/home/.codex/agent-fleet/prompts/ship-orchestrator.md" ]; then
      echo "FAIL: --tool codex did not install ship prompt payload into ~/.codex/agent-fleet/prompts"
      fail=1
    fi
    ( cd "$tmp" && HOME="$tmp/home" bash "$DIR/install.sh" --tool codex --uninstall >/dev/null 2>&1 ) || {
      echo "FAIL: install.sh --tool codex --uninstall exited non-zero"; fail=1
    }
    if [ -e "$tmp/home/.codex/skills/council" ]; then
      echo "FAIL: --tool codex --uninstall did not remove council skill"
      fail=1
    fi
    if [ -e "$tmp/home/.codex/agent-fleet" ]; then
      echo "FAIL: --tool codex --uninstall did not remove global payload"
      fail=1
    fi
  fi
  rm -rf "$tmp"
done

# Generic --dir installs into unknown TUI global resource homes, e.g. ~/.mewrite.
tmp=$(mktemp_d)
GENERIC_HOME="$tmp/mewrite-home"
( cd "$tmp" && HOME="$tmp/home" bash "$DIR/install.sh" --dir "$GENERIC_HOME" >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --dir exited non-zero"; fail=1
}
if [ ! -f "$GENERIC_HOME/agents/red-team.md" ]; then
  echo "FAIL: --dir did not install personas into DIR/agents"
  fail=1
fi
if [ ! -f "$GENERIC_HOME/skills/council/SKILL.md" ]; then
  echo "FAIL: --dir did not install council skill into DIR/skills/council"
  fail=1
fi
if [ ! -f "$GENERIC_HOME/skills/ship/SKILL.md" ]; then
  echo "FAIL: --dir did not install ship skill into DIR/skills/ship"
  fail=1
fi
if [ ! -f "$GENERIC_HOME/prompts/council-orchestrator.md" ]; then
  echo "FAIL: --dir did not install prompt into DIR/prompts"
  fail=1
fi
if [ ! -f "$GENERIC_HOME/prompts/ship-orchestrator.md" ]; then
  echo "FAIL: --dir did not install ship prompt into DIR/prompts"
  fail=1
fi
if [ -L "$GENERIC_HOME/agents/red-team.md" ]; then
  echo "FAIL: --dir installed symlinks; should be copies for unknown TUI dirs"
  fail=1
fi
if ! grep -q '^model: haiku$' "$GENERIC_HOME/agents/red-team.md"; then
  echo "FAIL: --dir did not keep cheaper default subagent model"
  fail=1
fi
( cd "$tmp" && HOME="$tmp/home" bash "$DIR/install.sh" --dir "$GENERIC_HOME" --uninstall >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --dir --uninstall exited non-zero"; fail=1
}
if [ -f "$GENERIC_HOME/agents/red-team.md" ] || [ -e "$GENERIC_HOME/skills/council" ] || [ -e "$GENERIC_HOME/skills/ship" ] || [ -f "$GENERIC_HOME/prompts/council-orchestrator.md" ] || [ -f "$GENERIC_HOME/prompts/ship-orchestrator.md" ]; then
  echo "FAIL: --dir --uninstall left installed files behind"
  fail=1
fi
rm -rf "$tmp"

# AGENT_FLEET_SUBAGENT_MODEL rewrites installed agent frontmatter only.
cat > "$EXTRA_PERSONA" <<'EOF'
---
name: cave-tool-map-fixture
description: test-only fixture for model frontmatter rewrite
model: haiku
tools: Read
---
model: body-line-should-not-change
EOF
tmp=$(mktemp_d)
MODEL_HOME="$tmp/mewrite-home"
( cd "$tmp" && HOME="$tmp/home" AGENT_FLEET_SUBAGENT_MODEL=sonnet bash "$DIR/install.sh" --dir "$MODEL_HOME" >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --dir with AGENT_FLEET_SUBAGENT_MODEL exited non-zero"; fail=1
}
if ! grep -q '^model: sonnet$' "$MODEL_HOME/agents/red-team.md"; then
  echo "FAIL: AGENT_FLEET_SUBAGENT_MODEL did not rewrite installed persona model"
  fail=1
fi
if ! grep -q '^model: sonnet$' "$MODEL_HOME/agents/ship-spec-checker.md"; then
  echo "FAIL: AGENT_FLEET_SUBAGENT_MODEL did not rewrite installed ship-agent model"
  fail=1
fi
if ! grep -q '^model: body-line-should-not-change$' "$MODEL_HOME/agents/cave-tool-map-fixture.md"; then
  echo "FAIL: AGENT_FLEET_SUBAGENT_MODEL rewrote a body model line"
  fail=1
fi
rm -rf "$tmp"
rm -f "$EXTRA_PERSONA"

tmp=$(mktemp_d)
TARGET_HOME="$tmp/flat-target"
( cd "$tmp" && HOME="$tmp/home" AGENT_FLEET_SUBAGENT_MODEL=sonnet bash "$DIR/install.sh" --target "$TARGET_HOME" --copy >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --target with AGENT_FLEET_SUBAGENT_MODEL exited non-zero"; fail=1
}
if ! grep -q '^model: sonnet$' "$TARGET_HOME/red-team.md"; then
  echo "FAIL: --target did not apply AGENT_FLEET_SUBAGENT_MODEL"
  fail=1
fi
rm -rf "$tmp"

tmp=$(mktemp_d)
( cd "$tmp" && HOME="$tmp/home" AGENT_FLEET_SUBAGENT_MODEL=sonnet bash "$DIR/install.sh" --tool codex >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --tool codex with AGENT_FLEET_SUBAGENT_MODEL exited non-zero"; fail=1
}
if ! grep -q '^model: sonnet$' "$tmp/.agent-fleet/red-team.md" || ! grep -q '^model: sonnet$' "$tmp/home/.codex/agent-fleet/agents/red-team.md"; then
  echo "FAIL: --tool codex did not apply AGENT_FLEET_SUBAGENT_MODEL to project and global payloads"
  fail=1
fi
rm -rf "$tmp"

tmp=$(mktemp_d)
( cd "$tmp" && HOME="$tmp/home" AGENT_FLEET_SUBAGENT_MODEL=sonnet bash "$DIR/install.sh" --tool claude >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --tool claude with AGENT_FLEET_SUBAGENT_MODEL exited non-zero"; fail=1
}
if ! grep -q '^model: sonnet$' "$tmp/home/.claude/agents/red-team.md"; then
  echo "FAIL: --tool claude did not apply AGENT_FLEET_SUBAGENT_MODEL"
  fail=1
fi
if [ -L "$tmp/home/.claude/agents/red-team.md" ]; then
  echo "FAIL: --tool claude model override should write copied agent files, not symlinks"
  fail=1
fi
rm -rf "$tmp"

# Cave uses distinct resource dirs and needs lowercase tool names in installed persona copies.
tmp=$(mktemp_d)
( cd "$tmp" && HOME="$tmp/home" bash "$DIR/install.sh" --tool cave >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --tool cave exited non-zero"; fail=1
}
if [ -d "$tmp/.cave/agents" ]; then
  n=$(find "$tmp/.cave/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
  if [ "$n" != "$expected_agents" ]; then
    echo "FAIL: --tool cave placed $n agent files; expected $expected_agents"
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
if [ ! -f "$tmp/.cave/skills/ship/SKILL.md" ]; then
  echo "FAIL: --tool cave did not install ship skill into .cave/skills/ship"
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
if ! grep -q '^model: haiku$' "$tmp/.cave/agents/red-team.md"; then
  echo "FAIL: --tool cave did not keep cheaper default subagent model"
  fail=1
fi
( cd "$tmp" && HOME="$tmp/home" bash "$DIR/install.sh" --tool cave --uninstall >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --tool cave --uninstall exited non-zero"; fail=1
}
if [ -f "$tmp/.cave/agents/red-team.md" ] || [ -e "$tmp/.cave/skills/council" ] || [ -e "$tmp/.cave/skills/ship" ] || [ -f "$tmp/.cave/prompts/council-orchestrator.md" ] || [ -f "$tmp/.cave/prompts/ship-orchestrator.md" ]; then
  echo "FAIL: --tool cave --uninstall left installed files behind"
  fail=1
fi
rm -rf "$tmp"

tmp=$(mktemp_d)
( cd "$tmp" && HOME="$tmp/home" AGENT_FLEET_SUBAGENT_MODEL=sonnet bash "$DIR/install.sh" --tool cave >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --tool cave with AGENT_FLEET_SUBAGENT_MODEL exited non-zero"; fail=1
}
if ! grep -q '^model: sonnet$' "$tmp/.cave/agents/red-team.md"; then
  echo "FAIL: --tool cave did not apply AGENT_FLEET_SUBAGENT_MODEL"
  fail=1
fi
if ! grep -q '^tools: read, find, grep, bash$' "$tmp/.cave/agents/red-team.md"; then
  echo "FAIL: --tool cave model override broke tool rewrite"
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
tmp=$(mktemp_d)
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
tmp=$(mktemp_d)
( cd "$tmp" && HOME="$tmp/home" CAVE_HOME="$tmp/cave-home" bash "$DIR/install.sh" --tool cave --user >/dev/null 2>&1 ) || {
  echo "FAIL: install.sh --tool cave --user exited non-zero"; fail=1
}
if [ ! -f "$tmp/cave-home/agent/agents/red-team.md" ]; then
  echo "FAIL: --tool cave --user did not install personas into CAVE_HOME/agent/agents"
  fail=1
fi
if [ ! -f "$tmp/cave-home/skills/council/SKILL.md" ]; then
  echo "FAIL: --tool cave --user did not install skill into CAVE_HOME/skills/council"
  fail=1
fi
if [ ! -f "$tmp/cave-home/skills/ship/SKILL.md" ]; then
  echo "FAIL: --tool cave --user did not install ship skill into CAVE_HOME/skills/ship"
  fail=1
fi
if [ ! -f "$tmp/cave-home/prompts/council-orchestrator.md" ]; then
  echo "FAIL: --tool cave --user did not install prompt into CAVE_HOME/prompts"
  fail=1
fi
rm -rf "$tmp"

# npm/npx CLI is the primary UX and delegates to the same installer behavior.
tmp=$(mktemp_d)
CLI_HOME="$tmp/mewrite-home"
( cd "$tmp" && HOME="$tmp/home" node "$DIR/bin/agent-fleet.js" install --dir "$CLI_HOME" >/dev/null 2>&1 ) || {
  echo "FAIL: agent-fleet install --dir exited non-zero"; fail=1
}
if [ ! -f "$CLI_HOME/agents/red-team.md" ] || [ ! -f "$CLI_HOME/skills/council/SKILL.md" ] || [ ! -f "$CLI_HOME/skills/ship/SKILL.md" ]; then
  echo "FAIL: agent-fleet install --dir did not place generic payload"
  fail=1
fi
if [ ! -f "$tmp/home/.agent-fleet/lib/transcript.sh" ] || [ -f "$tmp/home/.agent-fleet/agents/_overlay.md" ]; then
  echo "FAIL: agent-fleet CLI did not sync safe stable runtime home"
  fail=1
fi
rm -rf "$tmp"

tmp=$(mktemp_d)
mkdir -p "$tmp/stale/agents" "$tmp/stale/skills/council" "$tmp/home/.claude/agents" "$tmp/home/.claude/skills"
printf 'stale\n' > "$tmp/stale/agents/red-team.md"
printf 'stale\n' > "$tmp/stale/skills/council/SKILL.md"
ln -s "$tmp/stale/agents/red-team.md" "$tmp/home/.claude/agents/red-team.md"
ln -s "$tmp/stale/skills/council" "$tmp/home/.claude/skills/council"
( cd "$tmp" && HOME="$tmp/home" node "$DIR/bin/agent-fleet.js" install --tool claude >/dev/null 2>&1 ) || {
  echo "FAIL: agent-fleet install --tool claude exited non-zero"; fail=1
}
if [ ! -f "$tmp/home/.claude/agents/red-team.md" ] || [ ! -f "$tmp/home/.claude/skills/council/SKILL.md" ]; then
  echo "FAIL: agent-fleet install --tool claude did not place Claude payload"
  fail=1
fi
if [ -L "$tmp/home/.claude/agents/red-team.md" ] || [ -L "$tmp/home/.claude/skills/council" ]; then
  echo "FAIL: agent-fleet install --tool claude should replace stale symlinks with durable copies"
  fail=1
fi
if grep -q '^stale$' "$tmp/home/.claude/agents/red-team.md" || grep -q '^stale$' "$tmp/home/.claude/skills/council/SKILL.md"; then
  echo "FAIL: agent-fleet install --tool claude left stale symlink targets in place"
  fail=1
fi
( cd "$tmp" && HOME="$tmp/home" node "$DIR/bin/agent-fleet.js" install --tool claude --uninstall >/dev/null 2>&1 ) || {
  echo "FAIL: agent-fleet install --tool claude --uninstall exited non-zero after copy install"; fail=1
}
if [ -e "$tmp/home/.claude/agents/red-team.md" ] || [ -e "$tmp/home/.claude/skills/council" ]; then
  echo "FAIL: agent-fleet install --tool claude --uninstall left copied payload behind"
  fail=1
fi
rm -rf "$tmp"

tmp=$(mktemp_d)
( cd "$tmp" && HOME="$tmp/home" AGENT_FLEET_SUBAGENT_MODEL=sonnet node "$DIR/bin/agent-fleet.js" install --tool cave >/dev/null 2>&1 ) || {
  echo "FAIL: agent-fleet install --tool cave with model override exited non-zero"; fail=1
}
if ! grep -q '^model: sonnet$' "$tmp/.cave/agents/red-team.md"; then
  echo "FAIL: agent-fleet install did not pass AGENT_FLEET_SUBAGENT_MODEL through"
  fail=1
fi
rm -rf "$tmp"

set +e
OUT=$(HOME="$(mktemp_d)" bash "$DIR/install.sh" --tool codex --user 2>&1)
rc=$?
set -e
[ "$rc" != "0" ] && echo "$OUT" | grep -q -- '--user/--project only applies to --tool cave' \
  || { echo "FAIL: --tool codex --user should reject as Cave-only scope flag: rc=$rc out='$OUT'"; fail=1; }

HELP_OUT=$(bash "$DIR/install.sh" --help)
echo "$HELP_OUT" | grep -q -- '--agent-instructions' \
  || { echo "FAIL: --help missing --agent-instructions"; fail=1; }
echo "$HELP_OUT" | grep -q 'AGENT_FLEET_SUBAGENT_MODEL' \
  || { echo "FAIL: --help missing subagent model override"; fail=1; }
AGENT_OUT=$(bash "$DIR/install.sh" --agent-instructions)
echo "$AGENT_OUT" | grep -q 'do NOT vendor this repo' \
  || { echo "FAIL: --agent-instructions missing anti-vendor rule"; fail=1; }
echo "$AGENT_OUT" | grep -q 'npx @zhachory1/agent-fleet install --dir ~/.mewrite' \
  || { echo "FAIL: --agent-instructions missing primary unknown TUI npx example"; fail=1; }
echo "$AGENT_OUT" | grep -q 'bash install.sh --dir ~/.mewrite' \
  || { echo "FAIL: --agent-instructions missing fallback unknown TUI --dir example"; fail=1; }
echo "$AGENT_OUT" | grep -q 'AGENT_FLEET_SUBAGENT_MODEL' \
  || { echo "FAIL: --agent-instructions missing subagent model override"; fail=1; }
jq -e '.tools.unknown_global_tui.command == "npx @zhachory1/agent-fleet install --dir <TUI_CONFIG_DIR>" and .tools.unknown_global_tui.fallback == "bash install.sh --dir <TUI_CONFIG_DIR>" and .tools.claude.command == "npx @zhachory1/agent-fleet install --tool claude" and .tools.claude.fallback == "bash install.sh --tool claude"' \
  "$DIR/install.manifest.json" >/dev/null \
  || { echo "FAIL: install.manifest.json missing expected primary npx/fallback commands"; fail=1; }

[ "$fail" = "0" ] && echo "PASS test_install_tool_flags" || exit 1
