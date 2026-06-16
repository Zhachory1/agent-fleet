# Contributing to agent-fleet

Short version: read the README, run the worked example, then pick an open issue. Most needed
contributions are:

1. **Run a few councils on your own real work** and write up the friction (see [issue
   #13](../../issues/13)). This is the highest-leverage external contribution — the tool has
   never been used by anyone who isn't the author.
2. **Add or correct an overlay starter preset** under
   [`agents/_overlay.example/`](agents/_overlay.example/) for your industry (see [issue
   #4](../../issues/4)). Six are shipped; one acceptance criterion is **at least one preset
   contributed by someone who isn't the repo author** — that's the gap.
3. **Bugs + improvements** in the open issue list. Smaller is better; one issue per PR.

## Before opening a PR

1. **Run the full test suite.**
   ```bash
   for t in test/test_*.sh; do bash "$t"; done
   ```
   All tests should pass. CI runs the same loop on Ubuntu.

2. **Pass `bash -n` syntax check.**
   ```bash
   for f in install.sh lib/*.sh test/*.sh; do bash -n "$f" || echo "FAIL $f"; done
   ```

3. **If you're adding an overlay preset**, run the lint against it:
   ```bash
   bash lib/overlay.sh lint agents/_overlay.example/<your-preset>.md
   ```
   The lint is advisory — findings appear in CI logs but don't block. Read each finding
   manually before sending; some are false positives by design (the example file's own threat-
   model warning trips two patterns).

4. **Match the surrounding bash style.** All shell scripts use `set -euo pipefail` at the top.
   We use `bash`, not `sh` (the `[[ ]]` operator + `<<<` here-strings are fine). Indent with
   2 spaces.

5. **Don't invent new abstractions.** This repo is ~5 bash helpers + ~17 persona markdown files
   + tests. Bias toward extending the existing pattern rather than adding a layer.

## Persona contributions

If you want to add a new persona:

- Read [`agents/INDEX.md`](agents/INDEX.md) to understand the existing groups (Core / Domain /
  Adversarial / Executive) and the overlap matrix.
- Tag your persona `[experimental]` in its `description:` field per the existing experimental
  personas (test_agents_load.sh enforces this invariant — Core MUST NOT have the prefix;
  experimental MUST).
- Add it to `test/test_agents_load.sh`'s `EXPERIMENTAL` array.
- Add a row to `agents/INDEX.md` Domain or Adversarial table.
- Promotion to Core requires ≥3 logged real runs with `acted_on=true` per the INDEX rules.

## Conventions worth knowing

- **Commit messages**: `feat(...)`, `fix(...)`, `docs(...)`, `chore(...)`, `test(...)`. Body
  paragraph with rationale; close the relevant issue with `Closes #NN`.
- **PR descriptions**: include a one-paragraph "what + why", an acceptance checklist if the
  issue had one, and any deliberate scope cuts ("did NOT do X because Y").
- **Tests are the contract**. If your change passes the existing tests it's probably right; if
  it requires changing a test, explain the test change in the PR description.
- **Versions**: this repo uses [SemVer](https://semver.org/). `VERSION` is the single source
  of truth; all helpers respond to `--version`. Don't bump the version in a feature PR — the
  maintainer tags releases separately.

## Council / blinded-judge gates

For substantive PRs (PRDs, design docs, plans, large impl), the maintainer runs `/council`
review (see the `prompts/council-orchestrator.md`). You're not expected to run councils on
your own PRs, but the maintainer may post council findings on your PR as review comments.
Treat those as actionable signal, not bureaucratic ceremony.

For PRs that touch the canonical rubric (`lib/blind-judge-prompt.v*.txt`), the file's own
frontmatter requires:
1. A PR with a one-paragraph rationale.
2. Bumping the filename version (`v2.txt` → `v3.txt`).
3. Acknowledging that `journal.sh stats` does NOT pool agreement rates across rubric versions.

## Code of conduct

This project adopts the [Contributor Covenant 2.1](./CODE_OF_CONDUCT.md). Be respectful, be
specific, assume good faith. Ad-hominem against personas (human or LLM) is the one thing this
repo flags explicitly beyond the Covenant's standard expectations.

## Questions?

Open a [discussion](../../discussions) or file an [issue](../../issues/new) — there's no formal
maintainer rota, just the operator who built it.
