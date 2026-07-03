# claude-marketplace

Personal Claude Code plugin marketplace — my skills, slash commands, subagents, and setup guidelines, packaged as installable plugins.

This repo is **both** a marketplace (it lists plugins) and the home of those plugins.

## Install

```bash
# 1. Add this marketplace
/plugin marketplace add serhiiromaniuk/claude-marketplace

# 2. Install the toolkit plugin
/plugin install toolkit@serhii

# 3. (later) update
/plugin marketplace update serhii
```

## What's here

```
.claude-plugin/marketplace.json   # marketplace manifest — lists the plugins below
plugins/
  toolkit/                        # my general-purpose plugin
    .claude-plugin/plugin.json    # plugin manifest
    skills/                       # auto-discovered skills (one dir each, SKILL.md)
    commands/                     # slash commands (/toolkit:name)
    agents/                       # subagents
    hooks/hooks.json              # event automation
docs/                             # human-facing notes, NOT loaded into Claude's context
```

## Adding a new skill

1. `mkdir plugins/toolkit/skills/<skill-name>`
2. Create `SKILL.md` with frontmatter (`name`, `description`, optional `allowed-tools`).
3. Bundle helpers in `scripts/` and extra docs in `references/` if needed — reference bundled
   files via `${CLAUDE_PLUGIN_ROOT}`, never hardcoded paths.
4. Bump `version` in `plugins/toolkit/.claude-plugin/plugin.json`.

## Conventions

See [`docs/conventions.md`](docs/conventions.md) for the rule of thumb on skill vs. command
vs. agent vs. hook, and the personal-identity requirement for this repo.
