# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **personal Claude Code plugin marketplace**. It is *both* the marketplace (a
manifest listing installable plugins) and the home of those plugins. There is no
application to build or run — the "code" is authored primarily as markdown skills
plus a few helper scripts. Contributions are prose-and-config, not a compiled program.

## Architecture

```
.claude-plugin/marketplace.json   # marketplace manifest — declares name "serhii" and lists plugins
plugins/toolkit/                  # the single (currently) plugin, installed as toolkit@serhii
  .claude-plugin/plugin.json      # plugin manifest — bump "version" here when adding a skill
  skills/<name>/SKILL.md          # auto-discovered skills; each also invocable as /toolkit:<name>
  commands/<name>.md              # explicit slash commands
  agents/<name>.md                # subagents (own context / restricted tools)
  hooks/hooks.json                # event automation (currently empty: {"hooks": {}})
docs/                             # human-facing notes — NOT loaded into Claude's context
```

Two-level manifest chain: `marketplace.json` points at `./plugins/toolkit`, whose
`plugin.json` names the plugin. Skills are auto-discovered from `skills/*/SKILL.md`;
they do not need to be registered anywhere.

### Skill anatomy

```
skills/<name>/
  SKILL.md      # required. YAML frontmatter: name, description, [allowed-tools]
  references/   # optional. docs pulled in on demand
  scripts/      # optional. helpers
  assets/       # optional. templates, html, renderers
```

- The `description` frontmatter is the trigger — make it keyword-rich, because that
  is how Claude decides to auto-load the skill.
- Bundled files (scripts, templates, references) MUST be referenced via
  `${CLAUDE_PLUGIN_ROOT}` — never hardcode absolute paths, since the plugin is
  installed into an arbitrary location on the user's machine.

## Choosing a primitive (skill vs command vs agent vs hook)

- **model-decides when → skill** (`skills/<name>/SKILL.md`)
- **I-invoke explicitly → command** (`commands/<name>.md`, called `/toolkit:<name>`)
- **needs own context / restricted tools → subagent** (`agents/<name>.md`)
- **runs on an event → hook** (`hooks/hooks.json`)

## Conventions

- **One commit per skill/functionality** so history stays granular and each addition
  is independently revertable.
- After adding or changing a skill, bump `version` in `plugins/toolkit/.claude-plugin/plugin.json`.
- **Scope**: this is a *public* personal marketplace. Keep everything general-purpose
  and free of work-specific or private material (nothing `*@stepico.com`-internal) —
  anything internal belongs in a separate, private marketplace. Existing skills that
  derive from work tooling (e.g. `assessment-report`) ship only synthetic/fictional
  example data for this reason.
- Record notable additions in `CHANGELOG.md` under `[Unreleased]`.

## Testing / validating changes

No repo-wide build or test harness. Validation is per-skill and ad hoc:

- Shell helpers ship their own tests — e.g. run `plugins/toolkit/skills/glab/scripts/glab-helpers.test.sh`.
- Renderers are standalone Node scripts — e.g. `plugins/toolkit/skills/assessment-report/assets/render.mjs`.
- After editing manifests, sanity-check JSON validity (they are small hand-edited files).
