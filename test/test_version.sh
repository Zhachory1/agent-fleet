#!/usr/bin/env bash
# All bash helpers report the same version from the VERSION file.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"

[ -f "$DIR/VERSION" ] || { echo "FAIL: VERSION file missing"; exit 1; }
EXPECTED=$(cat "$DIR/VERSION" | tr -d '[:space:]')
[ -n "$EXPECTED" ] || { echo "FAIL: VERSION file is empty"; exit 1; }

fail=0
LEGACY_OVERLAY="$DIR/agents/_rokt-overlay.md"
LEGACY_OVERLAY_CREATED=0
if [ ! -e "$LEGACY_OVERLAY" ]; then
  printf 'test-only legacy private overlay\n' > "$LEGACY_OVERLAY"
  LEGACY_OVERLAY_CREATED=1
fi
cleanup() {
  if [ "$LEGACY_OVERLAY_CREATED" = "1" ]; then rm -f "$LEGACY_OVERLAY"; fi
}
trap cleanup EXIT

[ -f "$DIR/package.json" ] || { echo "FAIL: package.json missing"; exit 1; }
PACKAGE_VERSION=$(node -e 'process.stdout.write(require(process.argv[1]).version)' "$DIR/package.json")
if [ "$PACKAGE_VERSION" != "$EXPECTED" ]; then
  echo "FAIL: package.json version '$PACKAGE_VERSION' does not match VERSION '$EXPECTED'"
  fail=1
fi

PACK_JSON=$(cd "$DIR" && npm pack --dry-run --json)
if ! node -e 'const pack = JSON.parse(process.argv[1])[0]; const files = pack.files.map(f => f.path); for (const required of ["bin/agent-fleet.js", "install.sh", "agents/red-team.md", "ship-agents/ship-spec-checker.md", "skills/council/SKILL.md"]) { if (!files.includes(required)) { console.error(`missing ${required}`); process.exit(1); } } for (const privateFile of ["agents/_overlay.md", "agents/_rokt-overlay.md"]) { if (files.includes(privateFile)) { console.error(`${privateFile} included`); process.exit(1); } }' "$PACK_JSON"; then
  echo "FAIL: npm package contents missing required payload or include private overlay"
  fail=1
fi

if [ ! -x "$DIR/bin/agent-fleet.js" ]; then
  echo "FAIL: bin/agent-fleet.js missing or not executable"
  fail=1
fi

actual_cli=$(node "$DIR/bin/agent-fleet.js" --version 2>&1 | tr -d '[:space:]')
if [ "$actual_cli" != "$EXPECTED" ]; then
  echo "FAIL: agent-fleet --version returned '$actual_cli', expected '$EXPECTED'"
  fail=1
fi

CLI_RUNTIME_HOME=$(mktemp -d)
cli_home=$(AGENT_FLEET_NPM_HOME="$CLI_RUNTIME_HOME/runtime" node "$DIR/bin/agent-fleet.js" home 2>&1)
if [ "$cli_home" != "$CLI_RUNTIME_HOME/runtime" ]; then
  echo "FAIL: agent-fleet home returned '$cli_home', expected '$CLI_RUNTIME_HOME/runtime'"
  fail=1
fi
if [ ! -f "$CLI_RUNTIME_HOME/runtime/lib/transcript.sh" ] || [ -f "$CLI_RUNTIME_HOME/runtime/agents/_overlay.md" ] || [ -f "$CLI_RUNTIME_HOME/runtime/agents/_rokt-overlay.md" ]; then
  echo "FAIL: agent-fleet home did not sync runtime helpers safely"
  fail=1
fi
runtime_cli_home=$(AGENT_FLEET_NPM_HOME="$CLI_RUNTIME_HOME/runtime" node "$CLI_RUNTIME_HOME/runtime/bin/agent-fleet.js" home 2>&1)
if [ "$runtime_cli_home" != "$CLI_RUNTIME_HOME/runtime" ] || [ ! -f "$CLI_RUNTIME_HOME/runtime/agents/red-team.md" ]; then
  echo "FAIL: copied runtime agent-fleet CLI should not destructively self-sync"
  fail=1
fi
rm -rf "$CLI_RUNTIME_HOME"

cli_help=$(node "$DIR/bin/agent-fleet.js" --help 2>&1)
if ! grep -q 'agent-fleet install' <<<"$cli_help" || ! grep -q 'npx @zhachory1/agent-fleet install --tool claude' <<<"$cli_help"; then
  echo "FAIL: agent-fleet --help missing npx install guidance"
  fail=1
fi

install_help=$(AGENT_FLEET_NPM_HOME="$(mktemp -d)/runtime" node "$DIR/bin/agent-fleet.js" install --help 2>&1)
if ! grep -q 'agent-fleet installer v' <<<"$install_help" || ! grep -q 'npx @zhachory1/agent-fleet install --tool claude' <<<"$install_help"; then
  echo "FAIL: agent-fleet install --help did not delegate to installer help"
  fail=1
fi

set +e
out=$(node "$DIR/bin/agent-fleet.js" not-a-command 2>&1)
rc=$?
set -e
if [ "$rc" != "1" ] || ! grep -q "unknown command" <<<"$out"; then
  echo "FAIL: agent-fleet unknown command should exit 1 with unknown-command help"
  fail=1
fi

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

# install.sh fallback --help must include version + Options section
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
