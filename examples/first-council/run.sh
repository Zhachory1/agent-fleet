#!/usr/bin/env bash
# Worked example: a council on a checkout feature-flag PRD.
#
# This script REPRODUCES the mechanics of capturing, journaling, and viewing a council run.
# It does NOT call an LLM — the per-persona POSITION blocks in transcript.txt are pre-canned
# (this is documentation, not a benchmark). To run an actual council, you'd dispatch to your
# AI tool (Claude Code's Task tool, opencode subagents, etc.) per the orchestrator prompt.
#
# Prerequisites:
#   - bash + jq + a working AGENT_FLEET_HOME pointing at this repo
#
# What this script does:
#   1. Creates an isolated journal + transcript root (so it doesn't pollute your real journal).
#   2. Writes the artifact into the orchestrator's durable room location (FR9).
#   3. Captures the per-persona POSITION blocks from transcript.txt into the room transcript.
#   4. Journals the run with a real solo_decision and the council's findings.
#   5. Prints the captured transcript via lib/transcript.sh show.
#   6. Prints the journal stats so you can see the row landed.
set -euo pipefail

# Resolve AGENT_FLEET_HOME from the script's location (../..).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_FLEET_HOME="${AGENT_FLEET_HOME:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
if [ ! -d "$AGENT_FLEET_HOME/lib" ]; then
  echo "ERROR: cannot resolve AGENT_FLEET_HOME (looked at $AGENT_FLEET_HOME). Set the env var manually." >&2
  exit 1
fi
echo "AGENT_FLEET_HOME=$AGENT_FLEET_HOME"

# Isolated env so we don't touch the operator's real journal/rooms
TMPROOT=$(mktemp -d)
export AGENT_CHAT_ROOT="$TMPROOT/agent-chat"
export AGENT_FLEET_JOURNAL="$TMPROOT/journal.jsonl"
trap 'echo "(cleaning up $TMPROOT)"; rm -rf "$TMPROOT"' EXIT

ROOM=council-checkout-express-path
mkdir -p "$AGENT_CHAT_ROOT/rooms/$ROOM"

# Step 1 (FR9): write the artifact to the room's durable location
cp "$SCRIPT_DIR/artifact.md" "$AGENT_CHAT_ROOT/rooms/$ROOM/artifact.txt"
echo "(artifact written to room/artifact.txt)"

# Step 3 capture: the per-persona POSITION blocks (in real use, these come back from the
# Task-tool / subagent calls). For this example, transcript.txt holds the canned output
# from a pre-recorded council run. We use a Python helper inline to extract the @@from blocks.

# Pre-canned transcript: extract @@from blocks from transcript.txt and pipe to capture.
python3 - "$SCRIPT_DIR/transcript.txt" <<'PYEOF' | bash "$AGENT_FLEET_HOME/lib/transcript.sh" capture "$ROOM"
import sys, re
text = open(sys.argv[1]).read()
# transcript.txt is the PRETTY-PRINTED form (boxed output from transcript.sh show).
# To re-capture into the room, emit synthetic @@from blocks: one per persona x round.
# Parse [persona] markers + round headers; emit @@from: <persona>#r<N> + the body lines.
round_n = 0
persona = None
buf = []
def flush():
    if persona and buf:
        print(f"@@from: {persona}#r{round_n}")
        for L in buf:
            print(L)
for line in text.splitlines():
    rm = re.match(r"── round (\d+) ──", line)
    if rm:
        flush()
        buf = []
        persona = None
        round_n = int(rm.group(1))
        continue
    pm = re.match(r"┌─ \[([^\]]+)\]", line)
    if pm:
        flush()
        buf = []
        persona = pm.group(1)
        continue
    if line.startswith("└─"):
        flush()
        buf = []
        persona = None
        continue
    if line.startswith("│ "):
        buf.append(line[2:])
        continue
    if line.startswith("│"):
        buf.append(line[1:])
        continue
flush()
PYEOF
echo "(transcript captured)"

# Step 6: journal the run. We claim net_new_catch=true (per the synthesis), acted_on=true
# (audit-log + per-request read are landed in the PRD's next revision), 4 issues raised, 0
# dismissed, this is a `design` run with `lens_baseline_run=false` (no baseline for this
# example). issues_raised matches the BLOCKER+MAJOR count from the synthesis.
bash "$AGENT_FLEET_HOME/lib/journal.sh" append \
  "$ROOM" \
  "checkout-express-path" \
  "ship-with-changes; kill-switch + segmentation already address the obvious risks" \
  "reliability-sentinel,software-architect,generalist-swe,red-team" \
  true \
  "council surfaced mutable-customer-state race + kill-switch granularity (both BLOCKERs); A/B-vs-before/after + kill-switch-verification-test (MAJORs); solo had named neither failure mode" \
  true \
  0 \
  false null 7 design \
  --synthesis-word-count 800
echo "(journal row written)"

echo ""
echo "═══ captured transcript ═══"
bash "$AGENT_FLEET_HOME/lib/transcript.sh" show "$ROOM"

echo ""
echo "═══ journal stats (isolated to this example) ═══"
bash "$AGENT_FLEET_HOME/lib/journal.sh" stats

echo ""
echo "This run was isolated to $TMPROOT — your real journal at \$HOME/.claude/ is untouched."
echo "The synthesis (verdict, ranked issues, dissents, net-new-vs-solo table) is in synthesis.md."
