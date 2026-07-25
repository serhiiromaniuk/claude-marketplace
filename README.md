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

## Skills

Installed with the `toolkit` plugin. Most auto-trigger by description; each is also invocable as `/toolkit:<name>`.

| Skill | What it does |
|---|---|
| **agent-readiness** | Audits how well a repo is adopted for autonomous / long-running agentic work — a 7-pillar maturity rubric → A–F grade + a diffable `.agent-readiness/score.json`, then plans & applies the improvements. |
| **assessment-report** | Turns findings into a scored, branded gap/risk assessment (executive dashboard + detail) rendered to PDF. |
| **claude-in-chrome** | Reference for browser automation via the claude-in-chrome MCP (navigate, DOM, screenshots, console/network debugging, GIF recording). |
| **glab** | GitLab CLI (`glab`) DevOps workflows — pipelines, merge requests, releases, CI/CD debugging. |
| **verify-before-done** | Blocks "done / fixed / passing" claims that aren't backed by a command run in the current message — gate function, per-claim evidence table, rationalization guards. |
| **_skill-template** | Copy-to-start template for authoring a new skill. |

## What's here

```
.claude-plugin/marketplace.json   # marketplace manifest — lists the plugins below
plugins/
  toolkit/                        # the general-purpose plugin
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
vs. agent vs. hook, skill anatomy, and the scope of this marketplace.

Changes land one commit per skill/functionality, so history stays granular and each addition is independently revertable.
