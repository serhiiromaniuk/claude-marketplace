---
description: Report where the project stands — active phase, task, next step, gate status, and what's blocking the next milestone.
allowed-tools: Read, Bash(git status*), Bash(git tag*), Bash(git log*), Grep, Glob
---

Report the current state of the `<PROJECT>` agentic workflow. Be concise — a
status readout, not an essay. Do not change anything.

1. Read `loop/STATE.md` — active phase, active task, next step, iteration, gate.
2. Read the active task's `BRIEF.md` (done-when) and the **tail** of its
   `LOG.md` (last thing that happened).
3. Read `tasks/INDEX.md` for the full ledger.
4. Run `git status` (clean?), `git tag` (which milestones are tagged), and
   `git log --oneline -5`.
5. Cross-check the gate: is the foundation phase complete? Which phase gate is
   the next blocker (see RULES.md phase table + AGENTS.md §6)?

Output:
- **Phase / task / next step** (one line each)
- **Gate status** — open/closed, and what must pass to lift the next gate
- **Done-when progress** — checked vs unchecked from the BRIEF
- **Repo** — clean/dirty, latest tag, last commit
- **Next action** — the single next step the loop (or a human) should take

If `$ARGUMENTS` names a phase, focus the report on that phase instead.
