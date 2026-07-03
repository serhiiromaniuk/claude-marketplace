---
name: create-checklist
description: Generate a structured, actionable checklist for a task, setup, or review. Use when the user asks for a checklist, a step-by-step setup guide, a pre-flight/verification list, or wants a repeatable procedure written down.
---

# Create Checklist

Produces a clear, actionable checklist from a described task or goal.

## When to use

- The user says "make a checklist", "setup steps", "pre-flight list", "onboarding steps".
- A repeatable procedure should be captured as tickable items.

## How to build it

1. **Clarify the goal** in one line — what "done" looks like.
2. **Group** items into logical phases (e.g. Prep → Execute → Verify) when there are more than ~6 items.
3. Write each item as an **imperative, independently verifiable** action — one action per line.
4. Mark items that are **optional** or **conditional** explicitly.
5. End with a short **verification** section: how to confirm the whole thing succeeded.

## Output format

```markdown
# <Task> Checklist

**Goal:** <one line>

## Prep
- [ ] <action>
- [ ] <action>

## Execute
- [ ] <action>

## Verify
- [ ] <how to confirm success>
```

Keep it tight — a checklist is a tool, not documentation. Cut anything that isn't a checkable action.
