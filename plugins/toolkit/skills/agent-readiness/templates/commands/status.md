---
description: Report where the project stands — active phase, task, next step, gate status, and what's blocking the next milestone.
allowed-tools: Read, Bash(loop/where.sh*), Bash(git status*), Bash(git tag*), Bash(git log*), Grep, Glob
---

Report the current state of the `<PROJECT>` agentic workflow. Be concise — a
status readout, not an essay. Do not change anything.

1. Run `loop/where.sh --human` — phase, task, step N/M, governing spec (and
   whether it is still a stub), gate, tree state, last result. This replaces
   reading `loop/STATE.md` + `tasks/INDEX.md` for position.
2. Read the active task's `BRIEF.md` (done-when boxes) and the **tail** of its
   `LOG.md`. Closed tasks' folders are archive — do not open them.
3. Read `loop/STATE.md`'s carry-forward + decision sections only if the question
   needs them.
4. Run `git tag` (which milestones are tagged) and `git log --oneline -5`.
5. Cross-check the gate: which phase gate is the next blocker (see RULES.md phase
   table + AGENTS.md §6)?

Output:
- **Phase / task / next step** (one line each)
- **Gate status** — open/closed, and what must pass to lift the next gate
- **Done-when progress** — checked vs unchecked from the BRIEF
- **Repo** — clean/dirty, latest tag, last commit
- **Next action** — the single next step the loop (or a human) should take

If `$ARGUMENTS` names a phase, focus the report on that phase instead.
