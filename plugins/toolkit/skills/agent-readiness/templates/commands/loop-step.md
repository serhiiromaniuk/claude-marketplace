---
description: Perform exactly ONE loop increment interactively (do one step → verify → log → commit → emit a marker), following loop/PROMPT.md.
---

Execute **one** iteration of the agent loop by hand, exactly as
[`loop/PROMPT.md`](../loop/PROMPT.md) specifies. This is the interactive
equivalent of one `loop/loop.sh` cycle — use it to step through carefully or to
test the loop before running it unattended.

Do this now:
1. Run `loop/where.sh --json` FIRST, then read exactly the files it lists in
   `.read` — nothing else. Never open a closed task's `LOG.md`. Dispatch on its
   flags per PROMPT §1: `.error` / `.tree_clean` / `.needs_open` / `.needs_plan` /
   `.spec_stub` / `.all_steps_done`, first true one wins.
2. Respect the gates (AGENTS.md §6) — especially: if the foundation phase is
   open, do not write later-phase `src/` code. Never cross a human-only boundary
   (secrets, production deploys, destructive infra, irreversible external
   actions) autonomously.
3. Do step `.step` of `.steps`, titled `.step_title` — the single next unchecked
   `PLAN.md` step. Just one.
4. Verify it (AGENTS.md §5), run the mandatory `verifier` + `reviewer` subagents
   (PROMPT §4b — ONE reviewer pass; MEDIUM/LOW go to `## Amendments`), and record
   the evidence in `LOG.md` in the template's shape, ≤40 lines.
5. Check the box in `PLAN.md`. Touch `loop/STATE.md` / `tasks/INDEX.md` **only** if
   the gate verdict changed, a decision was made, a carry-forward moved, or the
   task opened/closed — never to record a step. Then `make loop-hygiene`.
6. Commit (Conventional Commits + scope) and push.
7. End with exactly one marker on the last line: `<<LOOP:CONTINUE>>`,
   `<<LOOP:PHASE_COMPLETE>>`, `<<LOOP:DONE>>`, `<<LOOP:GATE_FAILED>>`, or
   `<<LOOP:BLOCKED>>`.

Then STOP. Do not start the next step — that's the next iteration.

If `$ARGUMENTS` is given, treat it as a focus/override for which step to do, but
still do only one.
