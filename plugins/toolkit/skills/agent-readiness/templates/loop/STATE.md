# loop/STATE.md — live loop pointer

> The first thing every loop iteration reads. Keep it tiny and current. This is
> the agent's "you are here". Update it at the end of every iteration.

| Field | Value |
|-------|-------|
| **Active phase** | Phase 1 — `<short description>` |
| **Active task** | [`tasks/phase-1_<short-kebab>/`](../tasks/phase-1_<short-kebab>/) — `<one line on where it stands>` |
| **Next step** | ⏳ `<the single next unchecked PLAN.md step>` |
| **Iteration** | 0 |
| **Gate status** | 🟡 `<phase 1 gate not yet passed / what must go green>` |
| **Last marker** | `<<LOOP:CONTINUE>>` |
| **Blocked?** | no |

## Notes for the next iteration
- `<carry-forward note: a decision made, a follow-up to remember, a gotcha>`
- The loop tags milestones and rolls phase→phase itself, **only when the gate is
  observed-green** (the project's check command for code phases; the documented
  acceptance criteria otherwise). Stop at `<<LOOP:DONE>>` when the project goal
  is reached. See AGENTS.md §4/§6.
- Architecture holds: vendor SDKs behind their adapter only; all config in one
  place; no forbidden runtime dependencies.
- Parallelize independent work via subagents where it fits (AGENTS.md §8a).

## Decision log
- `<dated, one-line decisions the next iteration must not relitigate>`
