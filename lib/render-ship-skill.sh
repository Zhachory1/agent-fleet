#!/usr/bin/env bash
# Render the ship implementation workflow skill wrapper from the canonical portable prompt.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
cat <<'EOF'
---
name: ship
description: "Implement accepted specs/tasks with a small disciplined patch workflow. Use for /ship, ship it, implement this, make the change, bugfix, focused refactor, test pass, docs update, PR polish. Modes: --mode patch|test|docs|polish|bench. Runs scope-lock, implementation, spec-check/test-writer, doc-writer, occams-principles, focused validation. Not for deciding whether to build; use /council for high-stakes decisions."
---

<!-- GENERATED FROM prompts/ship-orchestrator.md; DO NOT EDIT BODY DIRECTLY. -->
<!-- To change the ship protocol, edit prompts/ship-orchestrator.md, then run: -->
<!--   bash lib/render-ship-skill.sh > skills/ship/SKILL.md -->

EOF
cat "$DIR/prompts/ship-orchestrator.md"
