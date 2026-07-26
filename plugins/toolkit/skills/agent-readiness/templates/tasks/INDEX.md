# Task ledger

Every task, its phase, and its status. **One line per task — a ledger row, not a
history.** Update on create, on status change, and on close; **never** to record a
step. Status: `todo · in-progress · blocked · done`.

> **Budget: ≤200 B per row** (`make loop-hygiene` warns). Detail belongs in that
> task's `OUTCOME.md` — link it, don't inline it. Exactly one row carries
> `in-progress`: that is what `loop/where.sh` reads to find the active task, and its
> first markdown link must be the task folder.

See [`../rules/AGENTS.md`](../rules/AGENTS.md) for how tasks work,
`loop/where.sh --human` for the live position, and
[`../loop/STATE.md`](../loop/STATE.md) for the gate + carry-forwards.

| Started | Phase | Task | Folder | Status | Milestone tag |
|---------|-------|------|--------|--------|---------------|
| YYYY-MM-DD | 1 | `<short title>` | [`phase-1_<short-kebab>/`](./phase-1_<short-kebab>/) | in-progress | `v0.1-<name>` |
| YYYY-MM-DD | 2 | `<short title>` | [`phase-2_<short-kebab>/`](./phase-2_<short-kebab>/) | todo | `v0.2-<name>` |
| YYYY-MM-DD | 0 | `<a closed one>` | [OUTCOME](./phase-0_<short-kebab>/OUTCOME.md) | done | `v0.0-<name>` |

<!--
Roadmap (RULES.md phase table) — open a task per phase as you reach it:
  1  <deliverable>  → v0.1-<name>
  2  <deliverable>  → v0.2-<name>
  3  <deliverable>  → v1.0-<name>
-->
