---
description: Perform exactly ONE loop increment interactively (do one step → verify → log → commit → emit a marker), following loop/PROMPT.md.
---

Execute **one** iteration of the agent loop by hand, exactly as
[`loop/PROMPT.md`](../loop/PROMPT.md) specifies. This is the interactive
equivalent of one `loop/loop.sh` cycle — use it to step through carefully or to
test the loop before running it unattended.

Do this now:
1. Load context in order: `rules/RULES.md` → `rules/AGENTS.md` → `loop/STATE.md`
   → the active task folder (`BRIEF`, `PLAN`, tail of `LOG`). Confirm
   `git status` is clean.
2. Respect the gates (AGENTS.md §6) — especially: if the foundation phase is
   open, do not write later-phase `src/` code. Never cross a human-only boundary
   (secrets, production deploys, destructive infra, irreversible external
   actions) autonomously.
3. Do the **single next unchecked step** in the active `PLAN.md`. Just one.
4. Verify it (AGENTS.md §5) and record the evidence in `LOG.md`.
5. Check the box in `PLAN.md`; update `loop/STATE.md` (next step, iteration +1,
   gate); update `tasks/INDEX.md` if status changed.
6. Commit (Conventional Commits + scope) and push.
7. End with exactly one marker on the last line: `<<LOOP:CONTINUE>>`,
   `<<LOOP:PHASE_COMPLETE>>`, `<<LOOP:DONE>>`, `<<LOOP:GATE_FAILED>>`, or
   `<<LOOP:BLOCKED>>`.

Then STOP. Do not start the next step — that's the next iteration.

If `$ARGUMENTS` is given, treat it as a focus/override for which step to do, but
still do only one.
