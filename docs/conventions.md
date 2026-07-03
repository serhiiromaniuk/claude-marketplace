# Conventions

Human-facing notes. Files in `docs/` are **not** auto-loaded into Claude's context.

## Which primitive do I reach for?

| I want…                                             | Use a…   | Lives in…            |
|-----------------------------------------------------|----------|----------------------|
| Claude to decide *when* to apply it, by description | skill    | `skills/<name>/SKILL.md` |
| To invoke it explicitly by name (`/toolkit:foo`)    | command  | `commands/foo.md`    |
| Its own context window and/or restricted tool set   | subagent | `agents/foo.md`      |
| Something to run automatically on an event          | hook     | `hooks/hooks.json`   |
| To bundle an external tool                          | MCP      | `.mcp.json`          |

Rule of thumb: *model-decides → skill; I-invoke → command; needs-own-context/tools → agent;
runs-on-an-event → hook.*

## Skill anatomy

```
skills/<name>/
  SKILL.md        # required. frontmatter: name, description, [allowed-tools]
  references/     # optional. docs the skill pulls in on demand
  scripts/        # optional. helpers; reference via ${CLAUDE_PLUGIN_ROOT}
  assets/         # optional. templates, images, etc.
```

Keep `description` trigger-rich — it's how Claude decides to load the skill.

## Scope

This is a personal marketplace. Keep plugins here general-purpose and free of
work-specific or private material — anything internal belongs in a separate, private
marketplace.
