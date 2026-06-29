#!/usr/bin/env bash
# Test: npm CLI wrapper delegates to install.sh and uses copy-by-default installs.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail=0

VERSION_OUT=$(node "$DIR/bin/agent-fleet.js" --version)
EXPECTED_VERSION=$(cat "$DIR/VERSION")
[ "$VERSION_OUT" = "$EXPECTED_VERSION" ] \
  || { echo "FAIL: npm CLI --version got '$VERSION_OUT', expected '$EXPECTED_VERSION'"; fail=1; }

HOME_OUT=$(node "$DIR/bin/agent-fleet.js" home)
[ "$HOME_OUT" = "$DIR" ] \
  || { echo "FAIL: npm CLI home got '$HOME_OUT', expected '$DIR'"; fail=1; }

HELP_OUT=$(node "$DIR/bin/agent-fleet.js")
echo "$HELP_OUT" | grep -q 'agent-fleet installer' \
  || { echo "FAIL: npm CLI without args should print installer help"; fail=1; }

PRINT_OUT=$(node "$DIR/bin/agent-fleet.js" --print)
echo "$PRINT_OUT" | grep -q 'Council Orchestrator' \
  || { echo "FAIL: npm CLI --print did not print orchestrator prompt"; fail=1; }

GENERIC_HOME="$TMP/mewrite-home"
HOME="$TMP/home" node "$DIR/bin/agent-fleet.js" install --dir "$GENERIC_HOME" >/dev/null 2>&1 \
  || { echo "FAIL: npm CLI install --dir exited non-zero"; fail=1; }
[ -f "$GENERIC_HOME/agents/red-team.md" ] \
  || { echo "FAIL: npm CLI install --dir did not install persona"; fail=1; }
[ ! -L "$GENERIC_HOME/agents/red-team.md" ] \
  || { echo "FAIL: npm CLI install --dir installed a symlink"; fail=1; }

CLAUDE_HOME="$TMP/claude-home"
HOME="$CLAUDE_HOME" node "$DIR/bin/agent-fleet.js" install --tool claude >/dev/null 2>&1 \
  || { echo "FAIL: npm CLI install --tool claude exited non-zero"; fail=1; }
[ -f "$CLAUDE_HOME/.claude/agents/red-team.md" ] \
  || { echo "FAIL: npm CLI install --tool claude did not install persona"; fail=1; }
[ ! -L "$CLAUDE_HOME/.claude/agents/red-team.md" ] \
  || { echo "FAIL: npm CLI install --tool claude should copy personas, not symlink into npm cache"; fail=1; }
[ -f "$CLAUDE_HOME/.claude/skills/council/SKILL.md" ] \
  || { echo "FAIL: npm CLI install --tool claude did not install copied skill"; fail=1; }
HOME="$CLAUDE_HOME" node "$DIR/bin/agent-fleet.js" uninstall --tool claude >/dev/null 2>&1 \
  || { echo "FAIL: npm CLI uninstall --tool claude exited non-zero"; fail=1; }
[ ! -e "$CLAUDE_HOME/.claude/agents/red-team.md" ] \
  || { echo "FAIL: npm CLI uninstall --tool claude left persona behind"; fail=1; }
[ ! -e "$CLAUDE_HOME/.claude/skills/council" ] \
  || { echo "FAIL: npm CLI uninstall --tool claude left skill behind"; fail=1; }

[ "$fail" = "0" ] && echo "PASS test_npm_cli" || exit 1
