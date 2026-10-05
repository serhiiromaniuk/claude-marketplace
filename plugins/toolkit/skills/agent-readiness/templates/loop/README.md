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
| `where.sh` | The **position oracle** — every iteration's first command. `--json` for the loop, `--human` (`make where`, `/where`) for a person, `--read` for just the file list, `--context` for the step slice (full step text, newest two LOG entries, the spec sections the step cites with `spec §<key>`). Computes phase · task · step N/M · step title · governing spec + stub flag · gate · tree state · the read contract, which leaves out rules `CLAUDE.md` already loads (`.loaded`) and the whole `LOG.md`. |
| `step-done.sh` | Closes an increment in **one** command (`make step-done MSG=…`): runs the gate (red → exit 1, nothing changed), appends its tail to `LOG.md` between `gate:begin`/`gate:end` markers, ticks the step's `PLAN.md` box, runs the prose budget and the staged-diff secret scan, commits (hooks run), and pushes only with `--push`. A scan or hook refusal (exit 3) puts `LOG.md`/`PLAN.md` back, so a re-run is safe. Replaces several model round-trips per step and the mandatory verifier subagent. |
| `entry-size-guard.sh` | The prose ratchet (`make loop-hygiene`): LOG entry ≤40 lines, `STATE.md` ≤40 lines, ledger row ≤200 bytes. Warn-only, called from `PROMPT.md` §5 — deliberately **not** a dependency of the correctness gate. |
| `amendments-guard.sh` | `make amendments` — prints how many deferred reviewer findings in the active `PLAN.md`'s `## Amendments` are still OPEN. One `- A<n> … · disposition: <word>` item per finding; `open`/`deferred`/no field is open (format in the script header and `tasks/_template/PLAN.md`). Run at every task close (PROMPT §1). `--all` walks closed tasks too. Warn-only. |
| `merge-gate.sh` | The prerequisite for parallel tasks: merges N branches into a throwaway worktree off the base branch (`MERGE_GATE_BASE`, default origin/HEAD → `main` → `master`) and runs the gate **once on the merged tree**. Two branches can be green alone and RED together — global LOC rows, one coverage/testcount ratchet, committed generated code. |
| `STATE.md` | Only what no script can derive: the gate verdict, decisions not to relitigate, and carry-forwards aimed at a task with no folder yet. Changes on those events, **not** every iteration. |
| `loop.sh` | The bounded harness. Runs `claude -p` with `PROMPT.md`, dispatches on the last completion marker, stops on a stop marker or `--max-iterations`, and exits with a code that says why (below). |
| `loop.sh --stop-on-phase` | Promotes `<<LOOP:PHASE_COMPLETE>>` to a hard terminal, so the run delivers exactly ONE milestone and hands back. Default is autonomous rollover — the agent tags the milestone and continues into the next phase. The stop lands **after** the tag, so nothing is half-done. |
| `env.sh` *(optional)* | If present, sourced **once** when `loop.sh` starts; its exports reach every iteration's agent — put your toolchain on `PATH` here (child `claude -p` shells are non-interactive and don't source `~/.profile`). A failing `env.sh` stops the loop before the first iteration. Not created by default. |

## Run it

```bash
loop/loop.sh                       # default cap (8 iterations), supervised
loop/loop.sh --max-iterations 20   # raise the cap
loop/loop.sh --dry-run             # print the prompt + settings, run nothing
```

`--max-iterations` is the **primary safety**. The loop is never unbounded: rate
limits are waited out at most `LIMIT_MAX` times in a row, and `--continuous`
retries stop after 5 consecutive failures. Alternatively, run one increment by
hand with the `/loop-step` slash command.

The exit code says why the loop stopped, so a wrapper (cron, CI, a tmux script)
can branch on it:

| Exit | Meaning |
|------|---------|
| 0 | `<<LOOP:DONE>>` — the project goal is reached |
| 1 | harness or agent failure: `claude` failed, no marker, a failure/limit cap, another loop holds the lock (stderr says which) |
| 2 | usage error (unknown flag, bad value) |
| 3 | `<<LOOP:BLOCKED>>` — a human is needed |
| 4 | `<<LOOP:GATE_FAILED>>` — a hard gate failed |
| 5 | `<<LOOP:PHASE_COMPLETE>>` under `--stop-on-phase` |
| 6 | `--max-iterations` reached |
| 128+n | interrupted by signal n (130 Ctrl-C, 143 `kill`) — the running agent is stopped too |

| Environment | Default | Effect |
|-------------|---------|--------|
| `LIMIT_WAIT` | `1800` | seconds to wait out a usage/rate limit before retrying the same iteration |
| `LIMIT_MAX` | `12` | consecutive limit waits before giving up (exit 1) |
| `FAIL_BACKOFF` | `15` | `--continuous`: seconds × consecutive failures between retries |

The single-instance lock lives in the git dir of the working tree (one per
linked worktree) and needs `flock`; where `flock` is missing (stock macOS) the
guard is skipped.

**Watching the loop from outside: never `pgrep -f` a pattern that appears in your
own command line.** A watcher written as
`while pgrep -f 'claude -p'; do sleep 20; done` matches *itself* — its `bash -c`
line contains that string — so the condition never goes false and the watcher spins
forever. The same shape makes `pkill -f 'loop.sh'` kill the shell that runs it.
Watch a PID instead (`while kill -0 "$pid"; do …`), or match on parentage with
`pgrep -P "$parent"`. Both failures were observed on a real run.

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
| `--stop-on-phase` | Halts at `PHASE_COMPLETE` instead of rolling on — one milestone per run, tagged and pushed before the stop. Use it when you want a human look at each milestone boundary. |

If the loop's child shells can't see your toolchain (verify fails with a spurious
`GATE_FAILED`), create `loop/env.sh` to export `PATH`.

## Completion markers (the harness dispatches on the last one the agent prints)

| Marker | Meaning | Loop |
|--------|---------|------|
| `<<LOOP:CONTINUE>>` | increment done, steps remain | re-invokes |
| `<<LOOP:PHASE_COMPLETE>>` | all steps done **and** gate passed — agent tags the milestone + opens the next phase | **re-invokes** (rolls into the next phase) — **stops** under `--stop-on-phase` |
| `<<LOOP:DONE>>` | the whole project goal is reached (all phases done, everything verified) | **stops** (always) |
| `<<LOOP:BLOCKED>>` | escape hatch tripped (3 failed tries) or a step needs a human | **stops** (always) |
| `<<LOOP:GATE_FAILED>>` | a hard gate failed (never weaken it) | **stops** (always — a failed gate needs a human decision, not a respin) |

The loop tags milestones and rolls phase→phase on its own, so a single run with
a high `--max-iterations` can carry the project a long way — pass
`--stop-on-phase` when you want it to deliver one milestone and hand back instead. Milestone tags are
applied **only when the phase's gate objectively passed** (the project's check
command, e.g. `make check`, is green; the phase's documented acceptance criteria
are met).

## Hard stops the loop will not cross autonomously

The **human-only boundary**: secrets, production deploys, destructive infra, and
irreversible external actions. These are permanently human. The loop tags
milestones and crosses code-phase gates autonomously, but stops with
`<<LOOP:BLOCKED>>` whenever a next step would cross that boundary, and with
`<<LOOP:DONE>>` when the project goal is reached. See [`../AGENTS.md`](../AGENTS.md)
§4 and §6.
