# Contributing an overlay preset

Overlay presets are public starters that an operator copies to `agents/_overlay.md` and edits
privately. They should make the council sharper for a domain without embedding any confidential
company facts.

## Good preset shape

A useful preset names generic domain realities:

- headline KPIs / decision metrics
- common proxy-metric traps
- experiment caveats
- typical stack assumptions
- hot paths and blast-radius areas
- one-way doors / hard-to-reverse choices
- common review failures
- placeholders for private current priorities

Keep it short enough that every persona can actually use it. Target 40-80 lines.

## Safety rules

Do **not** include:

- customer names
- real internal KPI targets
- incident details that identify a company or person
- private URLs, Slack channels, dashboards, API keys, account IDs, dataset names, or hostnames
- instructions that override persona/orchestrator contracts
- tool-use instructions or prompt-injection-style text

Treat an overlay as code loaded into every persona prompt. Run:

```bash
bash lib/overlay.sh lint agents/_overlay.example/<your-preset>.md
```

A clean lint is not proof of safety; it is only a heuristic check.

## Filename

Use a broad, public domain name:

```text
agents/_overlay.example/<industry-or-org-shape>.md
```

Examples:

- `healthcare.md`
- `gaming.md`
- `education.md`
- `enterprise-infra.md`
- `consumer-social.md`

## Template

```markdown
# Overlay (<Domain> — example starter; copy to _overlay.md and customize)

# ⚠ THREAT MODEL — this file is loaded VERBATIM into every persona's system prompt.
# Read it end-to-end before installing. Run `lib/overlay.sh show|lint` to inspect.
# Treat any overlay as code you are running, not data.

When reviewing, apply <domain> specifics:

- **Headline KPIs / metrics**: ...
- **Proxy-vs-real metrics**: ...
- **Experiment caveats**: ...
- **Stack**: ...
- **Hot paths**: ...
- **Reversibility / one-way doors**: ...
- **Common review failures**: ...
- **Current priorities / projects**: REPLACE THIS with the 1-3 named initiatives your team is
  shipping right now.

# NOTE: this is a public starter. Keep your private _overlay.md free of PII, customer names,
# and confidential identifiers beyond what you need to make the personas useful.
```

## PR checklist

- [ ] Preset is generic and public-safe.
- [ ] No real company/customer identifiers.
- [ ] No private URLs, account IDs, hostnames, secrets, or dataset names.
- [ ] Contains the threat-model header.
- [ ] Includes placeholders where private priorities should be filled in after copy.
- [ ] `bash lib/overlay.sh lint agents/_overlay.example/<preset>.md` ran and findings are explained.
- [ ] README preset table updated if this preset represents a broad new org shape.
