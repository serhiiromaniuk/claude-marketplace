# loop/STATE.md — the non-derivable pointer

> **`loop/where.sh --json` for position; this file for judgement.** Active phase,
> task, step number, step title, governing spec, tree state and last result are
> **computed** from the `PLAN.md` checkboxes, the `LOG.md` tail and `git status`.
> Restating any of them here is a second copy that goes stale and that every future
> iteration re-reads — the pattern that took one project from 12 to 200 min per
> iteration. Keep only what no script can derive.
>
> **Budget ≤40 lines** (`make loop-hygiene`). Update on a gate change, a decision,
> or a carry-forward — **not** every iteration.

| Field | Value |
|-------|-------|
| **Gate status** | 🟡 `<what must go green to lift the current phase gate>` |
| **Blocked?** | no |

## Carry-forward — obligations that outlive the task that found them
> Only for work aimed at a phase whose task folder does not exist yet. **Read this
> when you OPEN a task**: discharge or re-target any entry naming it in that task's
> `BRIEF.md`, and strike the entry here in the same commit. ≤6 lines per entry.

- `<CF-1 → phase N: the fact. Recorded in: <doc §x>. Discharge: <what closes it>.>`

## Decisions — do not relitigate
- `<YYYY-MM-DD: the decision in one line, and the option it beat.>`

<!-- Does NOT belong here: step position / "next step" (where.sh computes it) ·
     last iteration's story (that task's LOG.md tail) · a task's outcome or lessons
     (its OUTCOME.md) · the phase table (rules/RULES.md) · iteration counters and
     the last marker (git log). Tempted to paste a paragraph? It goes in the LOG. -->
