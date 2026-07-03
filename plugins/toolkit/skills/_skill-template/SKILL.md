---
name: <skill-name>
description: <one sentence — WHAT it does and WHEN to use it. This is how Claude decides to load the skill, so make it trigger-rich with concrete keywords.>
# allowed-tools: Bash, Read, Grep, Glob   # optional — restrict tools while active
---

# <Skill Title>

<One-paragraph summary of what this skill does.>

## When to use

- <trigger scenario>
- <trigger scenario>

## How it works

<Steps / rules Claude should follow.>

## Notes

- Bundle helpers in `scripts/` and reference them via `${CLAUDE_PLUGIN_ROOT}` (never hardcode paths).
- Put extra docs Claude should load on demand in `references/`.
- Copy this folder to `skills/<your-skill>/` and delete this template line.
