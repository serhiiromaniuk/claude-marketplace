# loop/ — the long-running loop engine

This directory is the **agent loop** for `<PROJECT>`. The technique (a "Ralph
loop": re-feed a fresh agent the same prompt every iteration) is simple:

> Re-feed a fresh agent **the same prompt** every iteration. Progress doesn't
> live in the context window — it lives on disk (the `tasks/` folder + this
> `STATE.md`) and in git history. Each iteration the agent reads where it left
> off, does **one** increment, verifies it, commits, and stops. The next
> iteration picks up from the files.

**The catch, and the counter-measure.** "Progress lives on disk" means every
iteration *re-reads* it, so append-only control-plane files make the loop
quadratically slower — measured at 12→200 min per iteration on one real project
before the fix. So position is **computed**, not narrated: `where.sh` derives phase
· task · step N/M · governing spec · tree state · the read list from the `PLAN.md`
checkboxes, the `LOG.md` tail and `git status`, and the loop reads only the files it
names. Detail is written **once**, in the task's `LOG.md`. `entry-size-guard.sh` is
the ratchet that keeps it that way. See `reference/ratchets.md` §"Control-plane
prose" in the `agent-readiness` skill for the numbers.

Why it fits this repo: the work is long, gated, and correctness-sensitive. A
fresh context per step avoids context rot, and the filesystem-as-memory model
means a crash, a `/clear`, or a new day never loses progress.

## Files

| File | Role |
|------|------|
| `PROMPT.md` | The **invariant** prompt. Re-fed verbatim every iteration. Don't change it per-step — change the task's `PLAN.md` instead. |
| `where.sh` | The **position oracle** — every iteration's first command. `--json` for the loop, `--human` (`make where`) for a person, `--read` for just the file list. Computes phase · task · step N/M · step title · governing spec + stub flag · gate · tree state · the read contract. |
| `entry-size-guard.sh` | The prose ratchet (`make loop-hygiene`): LOG entry ≤40 lines, `STATE.md` ≤40 lines, ledger row ≤200 B. Warn-only, called from `PROMPT.md` §5 — deliberately **not** a dependency of the correctness gate. |
| `STATE.md` | Only what no script can derive: the gate verdict, decisions not to relitigate, and carry-forwards aimed at a task with no folder yet. Changes on those events, **not** every iteration. |
| `loop.sh` | The bounded harness. Runs `claude -p` with `PROMPT.md`, greps stdout for completion markers, stops on a marker or `--max-iterations`. |
| `loop.sh --stop-on-phase` | Promotes `<<LOOP:PHASE_COMPLETE>>` to a hard terminal, so the run delivers exactly ONE milestone and hands back. Default is autonomous rollover — the agent tags the milestone and continues into the next phase. The stop lands **after** the tag, so nothing is half-done. |
| `env.sh` *(optional)* | If present, sourced before each iteration — put your toolchain on `PATH` here (child `claude -p` shells are non-interactive and don't source `~/.profile`). Not created by default. |

## Run it

```bash
loop/loop.sh                       # default cap (8 iterations), supervised
loop/loop.sh --max-iterations 20   # raise the cap
loop/loop.sh --dry-run             # print the prompt + settings, run nothing
```

`--max-iterations` is the **primary safety**. The loop is never unbounded.
Alternatively, run one increment by hand with the `/loop-step` slash command.

### Long unattended run

For a hands-off run that keeps going through hiccups, combine three flags and
detach it from the terminal:

```bash
tmux new -s loop
loop/loop.sh --continuous --model opus --skip-permissions --max-iterations 1000
#   detach: Ctrl-b then d   ·   reattach: tmux attach -t loop
```

| Flag | Effect |
|------|--------|
| `--continuous` | `DONE`/`BLOCKED`/`GATE_FAILED` still halt. A missing marker and transient `claude` errors are **retried** with linear backoff, bounded by a consecutive-failure cap (5) so a broken auth/API doesn't burn the whole budget. |
| `--skip-permissions` | Passes `--dangerously-skip-permissions` — no permission prompts. ⚠️ Then the human-only boundary in `AGENTS.md` + the `BLOCKED` marker are the *only* guardrail; run it only where you're happy letting an agent act freely. |
| `--model <m>` | Pins the driver model (e.g. `opus`) for deterministic runs instead of inheriting the config default. |

If the loop's child shells can't see your toolchain (verify fails with a spurious
`GATE_FAILED`), create `loop/env.sh` to export `PATH`.

## Completion markers (the harness greps stdout for these)

| Marker | Meaning | Loop |
|--------|---------|------|
| `<<LOOP:CONTINUE>>` | increment done, steps remain | re-invokes |
| `<<LOOP:PHASE_COMPLETE>>` | all steps done **and** gate passed — agent tags the milestone + opens the next phase | **re-invokes** (rolls into the next phase) |
| `<<LOOP:DONE>>` | the whole project goal is reached (all phases done, everything verified) | **stops** (always) |
| `<<LOOP:BLOCKED>>` | escape hatch tripped (3 failed tries) or a step needs a human | **stops** (always) |
| `<<LOOP:GATE_FAILED>>` | a hard gate failed (never weaken it) | **stops** (always — a failed gate needs a human decision, not a respin) |

The loop tags milestones and rolls phase→phase on its own, so a single run with
a high `--max-iterations` can carry the project a long way. Milestone tags are
applied **only when the phase's gate objectively passed** (the project's check
command, e.g. `make check`, is green; the phase's documented acceptance criteria
are met).

## Hard stops the loop will not cross autonomously

The **human-only boundary**: secrets, production deploys, destructive infra, and
irreversible external actions. These are permanently human. The loop tags
milestones and crosses code-phase gates autonomously, but stops with
`<<LOOP:BLOCKED>>` whenever a next step would cross that boundary, and with
`<<LOOP:DONE>>` when the project goal is reached. See [`../rules/AGENTS.md`](../rules/AGENTS.md)
§4 and §6.
