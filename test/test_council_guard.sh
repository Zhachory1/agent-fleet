#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AGENT_CHAT_ROOT="$TMP/chat"

invalid_artifact() {
  set +e
  "$DIR/lib/council-guard.sh" artifact "$1" >/dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: invalid artifact accepted"; exit 1; }
}
printf 'artifact without metadata\n' > "$TMP/missing.txt"
invalid_artifact "$TMP/missing.txt"
printf 'council_artifact_kind: other\n' > "$TMP/invalid.txt"
invalid_artifact "$TMP/invalid.txt"
cat > "$TMP/incomplete.txt" <<'EOF'
council_artifact_kind: infrastructure
## Capability Reuse Inventory
- plausible existing capabilities: helper
- owner/source of truth:
- current consumers: tests
- access contract: shell
- evidence for rejection: mismatch
EOF
invalid_artifact "$TMP/incomplete.txt"
cat > "$TMP/valid.txt" <<'EOF'
council_artifact_kind: infrastructure
## Capability Reuse Inventory
- plausible existing capabilities: helper
- owner/source of truth: repository
- current consumers: tests
- access contract: shell interface
- evidence for rejection: mismatch
EOF
"$DIR/lib/council-guard.sh" artifact "$TMP/valid.txt" | jq -e '.kind=="infrastructure" and .inventory_valid==true and (.artifact_sha256|length==64)' >/dev/null
export COUNCIL_EXECUTION_MODE=spawned
set +e
"$DIR/lib/council-guard.sh" begin guard-room "$TMP/valid.txt" ship 'red-team, mvp, occams-razor' >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: begin accepted missing selection rationale"; exit 1; }
export COUNCIL_SELECTION_RATIONALE="adversarial coverage"
unset COUNCIL_EXECUTION_MODE
set +e
"$DIR/lib/council-guard.sh" begin guard-room "$TMP/valid.txt" ship 'red-team, mvp, occams-razor' >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: begin accepted missing execution mode"; exit 1; }
export COUNCIL_EXECUTION_MODE=invalid
set +e
"$DIR/lib/council-guard.sh" begin guard-room "$TMP/valid.txt" ship 'red-team, mvp, occams-razor' >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: begin accepted invalid execution mode"; exit 1; }
export COUNCIL_EXECUTION_MODE=lens-simulation
"$DIR/lib/council-guard.sh" begin guard-room "$TMP/valid.txt" ship 'red-team, mvp, occams-razor' >/dev/null
MANIFEST="$AGENT_CHAT_ROOT/rooms/guard-room/manifest.json"
jq -e '.state=="pending" and .artifact_path=="'"$TMP"'/valid.txt" and .selection_rationale=="adversarial coverage" and .artifact_kind=="infrastructure" and .mode=="ship" and .execution_mode=="lens-simulation" and (.personas|length==3)' "$MANIFEST" >/dev/null \
  || { echo "FAIL: begin did not create required manifest"; exit 1; }

valid_position() {
  cat <<'EOF'
POSITION (persona: red-team)
- verdict: BLOCK
- top_issues:
- strongest_counterargument: transport may be sufficient
- confidence: high
- one_line: block until evidence is complete
EOF
}
valid_position | "$DIR/lib/council-guard.sh" position red-team
for bad in empty duplicate missing-counterargument mismatch; do
  case "$bad" in
    empty) input='';;
    duplicate) input="$(valid_position; echo '- verdict: SHIP')";;
    missing-counterargument) input="$(valid_position | grep -v strongest_counterargument)";;
    mismatch) input="$(valid_position | sed 's/persona: red-team/persona: mvp/')";;
  esac
  set +e
  printf '%s\n' "$input" | "$DIR/lib/council-guard.sh" position red-team >/dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: $bad POSITION accepted"; exit 1; }
done
set +e
"$DIR/lib/council-guard.sh" finish guard-room 1 >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: finish accepted uncaptured round"; exit 1; }
echo "PASS test_council_guard"
