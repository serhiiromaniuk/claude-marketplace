---
name: <skill-name>
description: <one sentence — WHAT it does and WHEN to use it. This is how Claude decides to load the skill, so make it trigger-rich with concrete keywords.>
# allowed-tools: Read, Grep, Bash(git status *)   # optional — PRE-APPROVES these tools while the skill is active; it does not restrict others. Keep it to read-only tools.
# disable-model-invocation: true                   # optional — only the user can invoke it (/toolkit:<skill-name>)
---

# <Skill Title>

<One-paragraph summary of what this skill does.>

## When to use

- <trigger scenario>
- <trigger scenario>

## How it works

<Steps / rules Claude should follow.>

## Notes

- Bundle helpers in `scripts/` and reference them as `${CLAUDE_PLUGIN_ROOT}/skills/<skill-name>/scripts/...` (never hardcode paths).
- Put extra docs Claude should load on demand in `reference/`.
