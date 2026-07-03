# Task ledger

Every task, its phase, and its status. One row per task folder. Update on
create, on status change, and on close. Status: `todo · in-progress · blocked · done`.

See [`../rules/AGENTS.md`](../rules/AGENTS.md) for how tasks work and
[`../loop/STATE.md`](../loop/STATE.md) for the currently-active pointer.

| Started | Phase | Task | Folder | Status | Milestone tag |
|---------|-------|------|--------|--------|---------------|
| YYYY-MM-DD | 1 | `<short title>` | [`phase-1_<short-kebab>/`](./phase-1_<short-kebab>/) | in-progress | `v0.1-<name>` |
| YYYY-MM-DD | 2 | `<short title>` | [`phase-2_<short-kebab>/`](./phase-2_<short-kebab>/) | todo | `v0.2-<name>` |

<!--
Roadmap (RULES.md phase table) — open a task per phase as you reach it:
  1  <deliverable>  → v0.1-<name>
  2  <deliverable>  → v0.2-<name>
  3  <deliverable>  → v1.0-<name>
-->
