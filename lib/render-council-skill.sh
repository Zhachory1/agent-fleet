#!/usr/bin/env bash
# Render the Claude/Codex/Cave council skill wrapper from the canonical portable prompt.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
cat <<'EOF'
---
name: council
description: "Convene a council of 3-6 specialist personas to review a high-stakes decision (model change, experiment readout, design doc, serving-path PR, architecture/build-vs-buy). Picks personas, runs a bounded debate, synthesizes a decision-grade answer with named dissents. Triggers /council, council review, get a second opinion, tear this apart, is this safe to ship, review this model/experiment/design."
---

<!-- GENERATED FROM prompts/council-orchestrator.md; DO NOT EDIT BODY DIRECTLY. -->
<!-- To change the council protocol, edit prompts/council-orchestrator.md, then run: -->
<!--   bash lib/render-council-skill.sh > skills/council/SKILL.md -->

EOF
cat "$DIR/prompts/council-orchestrator.md"
