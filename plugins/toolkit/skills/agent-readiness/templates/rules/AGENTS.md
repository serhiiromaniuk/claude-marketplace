# AGENTS.md — operating manual for agentic work in `<PROJECT>`

How an AI agent (Claude Code, or any coding agent) must work in this repo.
[`RULES.md`](./RULES.md) is the *governance layer* (what is true about the
project: golden rules, architecture, conventions). **This file is the *operating
layer*** (how you actually execute work across long-running, multi-session,
phase-gated tasks). [`WORKFLOW.md`](./WORKFLOW.md) is the worked example.

Read order at the start of any session: **RULES.md → AGENTS.md → the active task
folder under [`../tasks/`](../tasks/) → [`../loop/STATE.md`](../loop/STATE.md).**

> Do not improvise, skip steps, or deviate from the workflow below. When the
> workflow and a clever shortcut disagree, the workflow wins.

---

## 0. The one rule that overrides this whole file

**The golden rules in [`RULES.md`](./RULES.md) are non-negotiable.** Nothing in
this operating manual permits you to violate them. In particular:

- The runtime invariants (RULES.md golden rules #1/#4/#5) constrain the *product
  you build*, not you the dev agent. The loop, subagents, and this manual are
  **dev-time tooling only** — they must leave **zero** forbidden runtime
  dependency in `src/`. If you find yourself about to introduce one, stop: that
  is the line.
- **Golden rule #6 gates everything.** No later-phase production logic until the
  foundation phase is complete and reviewed. The loop must refuse to write
  later-phase code while the foundation gate is open. See §6 (Gates).

---

## Quick reference — setup, commands & structure

> The build/test/run commands and the repo map in one place, so any agent (or
> tool) has them up front. Deeper conventions live in [`RULES.md`](./RULES.md);
> the *how-to-execute* workflow is §1+ below. Safety (§0 above) overrides all.

### Prerequisites
- `<language + pinned version>`, `<runtime/container tooling>`, and any required
  services. Config/secrets via environment (copy the example env file).

### Commands — the `Makefile` is the only sanctioned entrypoint

```bash
make install   # set up the isolated environment + install deps
make check     # lint + typecheck + tests — RUN BEFORE EVERY COMMIT
make test      # tests with coverage (≥80% target)
make lint | format | typecheck   # the individual gates
make lock      # freeze exact dep versions
make help      # full target list
```

`<Add project-specific run/validation targets here (e.g. make up, make
validate) with what each does and what it needs.>`

### Project structure

```
src/                  the main package / source tree
  <component>/          <one responsibility per module>
  <adapter>/            HARD boundary — vendor/external SDK lives ONLY here
  config.<ext>          every config value read + validated in ONE place
tests/                the test suite (≥80% coverage)
loop/                 agent loop: PROMPT.md (invariant prompt) · loop.sh · STATE.md
tasks/                per-phase BRIEF/PLAN/LOG/OUTCOME folders + INDEX.md ledger
agents/               specialist subagents (planner, reviewer, verifier)
commands/             slash-command shortcuts (/loop-step, /status)
RULES.md              governance: golden rules, architecture, conventions, git
AGENTS.md             this file — how an agent executes work here
WORKFLOW.md           worked example
Makefile              the single sanctioned dev entrypoint
```

---

## 1. Core philosophy

- **One session = one focused outcome.** A session advances exactly one task
  (one phase, or one slice of a phase). Resist scope creep; spin a new task.
- **Structure is memory, not the context window.** The task folder
  (`BRIEF / PLAN / LOG / OUTCOME`) plus git history *is* the agent's memory. A
  fresh agent with zero conversation history must be able to resume from the
  files alone. Progress lives on disk, not in tokens.
- **Iteration over perfection.** Small, verified increments beat big unverified
  leaps. Commit + push each one.
- **Failures are data.** A failed step is a `LOG.md` entry and a plan
  adjustment, not a silent retry. Document, adapt, continue.
- **Every claim needs evidence.** "Tests pass" means the `make check` output is
  in the log. No asserting success you didn't observe.
- **Simplicity first.** Reach for a subagent or a parallel fan-out only when a
  single straight-line pass genuinely can't do it. Don't add machinery you don't
  need.

---

## 2. The unit of work: phases and tasks

Work is organized by the **phase roadmap in [`RULES.md`](./RULES.md)**. Each
phase (or a meaningful slice of one) becomes a **task folder** under
[`../tasks/`](../tasks/):

```
tasks/
├── INDEX.md          # the ledger — every task, its phase, its status
├── _template/        # copy this to start a task
│   ├── BRIEF.md   PLAN.md   LOG.md   OUTCOME.md
└── phase-1_<short-kebab>/   # naming: phase-N_short-kebab  (or  YYYY-MM-DD_short-kebab for off-roadmap work)
    ├── BRIEF.md   PLAN.md   LOG.md   (OUTCOME.md added when done)
```

**Folder naming**
- On-roadmap: `phase-<N>_<short-kebab>`.
- Off-roadmap / ad-hoc: `YYYY-MM-DD_<short-kebab>`.

**The four documents** (one purpose each — never merge them):

| File | Lifecycle | Holds |
|------|-----------|-------|
| `BRIEF.md` | **Static** after first write | what, why, scope (in/out), **done-when** (verifiable), refs |
| `PLAN.md`  | Steps frozen once work starts; **append amendments** at bottom | numbered steps, risks/deps, **escape hatches** |
| `LOG.md`   | **Append-only**, newest at bottom, timestamped | what happened, commands run, decisions, findings |
| `OUTCOME.md` | Written at close (done **or** blocked) | summary, deliverables (commits/tags), follow-ups, lessons |

Discipline: never edit a past `LOG.md` entry; never rewrite `PLAN.md` steps
mid-flight (amend instead); never silently overwrite — append a dated note.

The ledger [`../tasks/INDEX.md`](../tasks/INDEX.md) gets one row per task with
status `todo | in-progress | blocked | done`.

---

## 3. Session rituals

### 3a. Startup (before touching anything)
1. Read [`RULES.md`](./RULES.md) (golden rules, architecture, git).
2. Read this file (`AGENTS.md`).
3. Read [`../loop/STATE.md`](../loop/STATE.md) — what phase/task is active, which
   step is next, gate status.
4. Open the active task folder; read `BRIEF.md`, `PLAN.md`, and the **tail** of
   `LOG.md`.
5. Confirm `git status` is clean and you're on the main branch (or, for parallel
   same-code work, the intended worktree — see §7).
6. If there is no active task for the current phase, **create one** from
   `_template/` before doing any work (§2).

### 3b. Shutdown (end of session / loop iteration)
1. Append a final `LOG.md` entry (what you did, what's next).
2. Update [`../loop/STATE.md`](../loop/STATE.md) (next step, iteration count, gate).
3. Update [`../tasks/INDEX.md`](../tasks/INDEX.md) status if it changed.
4. Commit + push the increment (§7). The remote must not lag the work.
5. If the task is finished or blocked, write `OUTCOME.md`.

---

## 4. The agent loop (long-running tasks)

The technique: **re-feed the same prompt to a fresh agent over and over; the
filesystem and git history carry progress between iterations.** The invariant
prompt is [`../loop/PROMPT.md`](../loop/PROMPT.md); the harness is
[`../loop/loop.sh`](../loop/loop.sh); the live pointer is
[`../loop/STATE.md`](../loop/STATE.md). See [`../loop/README.md`](../loop/README.md).

**One iteration does exactly this:**
1. Load context (§3a) — STATE.md first.
2. Pick **the next single unchecked step** in the active `PLAN.md`. One step.
3. Do it.
4. **Verify** it (run the relevant check — §5). Record the evidence in `LOG.md`.
5. Check the box in `PLAN.md`; update `STATE.md`.
6. Commit + push.
7. Emit a **completion marker** (below) and stop. The loop re-invokes a fresh
   agent for the next step.

**Completion markers** (exact strings — the harness greps for them):
- `<<LOOP:CONTINUE>>` — increment done, more steps remain in this phase.
- `<<LOOP:PHASE_COMPLETE>>` — every step done **and** the phase gate passed (§6).
  The agent writes `OUTCOME.md`, **tags the milestone** (`git tag … && git push
  --tags`), opens the next phase's task, and the loop **re-invokes** to roll into
  it. Tag only when the gate objectively passed — never weaken a threshold to tag.
- `<<LOOP:DONE>>` — the whole project goal is reached: all phases done, final
  milestone tagged, everything verified. The loop **stops**.
- `<<LOOP:BLOCKED>>` — stuck (escape hatch tripped) or a step needs a human (e.g.
  a human-only boundary). The loop stops; `LOG.md`/`OUTCOME.md` explain why.
- `<<LOOP:GATE_FAILED>>` — a hard gate (acceptance criteria, coverage, golden
  rule) failed. The loop stops; **never** lower the threshold to get past it.

**Safety (mandatory):**
- `--max-iterations` is the **primary** safety mechanism. The loop is always
  bounded; an unbounded loop is forbidden. With autonomous tagging, a single
  bounded run can carry the project across several phases — the iteration cap is
  what keeps it reviewable.
- **Escape hatch:** if a single step fails **3 times**, stop, write the blocker
  to `LOG.md`, set the task `blocked`, emit `<<LOOP:BLOCKED>>`. Do not thrash.
- **What the loop MAY do autonomously:** tag a milestone and roll into the next
  phase — but **only after that phase's gate has objectively passed** (§5/§6).
- **The human-only boundary the loop must NEVER cross autonomously:** secrets /
  production credentials, production deploys, destructive infrastructure, and
  irreversible external actions. At these, stop (`<<LOOP:DONE>>` at the final
  milestone, else `<<LOOP:BLOCKED>>`) and hand back to a human.

---

## 5. Verification — give yourself a check that returns pass/fail

A step isn't done until a check confirms it. Pick the cheapest check that
actually proves the step.

| What changed | Check (record output in LOG.md) |
|--------------|---------------------------------|
| Any code in `src/` or `tests/` | `make check` (lint + typecheck + tests) |
| New/changed logic | a **failing test first**, then green (TDD) |
| Correctness-critical logic | unit test with hand-computed expected values |
| Measured results (a gate) | the acceptance criteria vs thresholds (RULES.md) |
| Runtime/packaging change | a build / config-validation command |
| Research / design | the relevant doc section filled with a stated **recommendation** |

Coverage target **≥ 80%** (adjust to the project). If you cannot verify a
change, you cannot call it done — say so in the log and leave the box unchecked.

---

## 6. Gates — where the loop must stop

Gates are **hard**. You may not cross one autonomously, and you may **never**
weaken one to pass it ("fix the work, never lower the thresholds").

- **Foundation gate (golden rule #6):** the design/research/scaffold phase must
  be complete + reviewed before *any* later-phase production code. While it's
  open, the loop works only inside that phase's scope.
- **Acceptance gate:** the authoritative criteria live in [`RULES.md`](./RULES.md)
  — do not restate the numbers here (avoids drift). The agent evaluates
  objectively against RULES.md: **all pass → tag the milestone and continue; any
  miss → `<<LOOP:GATE_FAILED>>`** (fix the work, never lower a threshold).
- **Milestone gate (autonomous):** at the end of a phase, once the gate has
  **objectively passed** (`make check` green for code phases; the documented
  acceptance criteria otherwise), the agent itself tags the milestone and rolls
  into the next phase. A tag asserts the gate passed — so it is applied **only**
  on observed-green evidence, never to "make progress".
- **When the gate is the wrong metric — the falsified-metric path.** Rare, and
  never a shortcut. "Fix the work, never lower the threshold" assumes the
  threshold measures what it claims to. Occasionally it does not, and then
  *neither* legal move exists: the work is correct, and the number still cannot
  be met. Do **not** grind the step, and do **not** touch the constant. All
  three tests must hold before you may even propose a change:
  1. **Replicated** — the same overage *shape* is already on record at **≥3
     independent checkpoints** (prior `LOG.md` / decision entries), not just
     today's step. One data point is a slow increment; three is a metric
     measuring the wrong thing.
  2. **Arithmetically unreachable** — show the sum. The threshold cannot be met
     while also satisfying the project's *other* mandated requirements (classic
     case: a volume cap that binds against per-feature tests the rules
     themselves require). Compute it; asserting it does not count.
  3. **Re-scope, never delete** — the proposal splits *what is counted* and
     keeps a **hard gate on the portion moved out**. Any proposal whose net
     effect is "this quantity is no longer measured" is a weakened check —
     forbidden however it is framed.
  Then **the increment is the decision record, not the edit**: write it up (an
  ADR under `decisions/` if the repo has one, else a dated `LOG.md` entry) with
  the measured numbers, **≥2 options**, and a recommendation; leave the gate and
  the work exactly as verified; emit `<<LOOP:GATE_FAILED>>` naming the decision
  needed. **A human edits the constant.** Why this exists: a gate no correct
  work can pass stops the loop *every* iteration, and the third time you write
  "the overage is entirely mandated test volume, the production code is lean" is
  the loop telling you the metric is wrong — record that instead of re-deriving
  it a fourth time.
- **Human-only gate — permanent:** secrets / production credentials, production
  deploys, destructive infra, and irreversible external actions are **never**
  agent actions (golden rules #2/#3/#5). The agent reaches the boundary and
  **stops** (`<<LOOP:DONE>>` or `<<LOOP:BLOCKED>>`).
- **Harmless local setup is NOT that boundary — don't over-block.** Full
  permission means you MAY act without prompting. A **missing local tool** is not
  a `<<LOOP:BLOCKED>>` reason: install it (via the project's sanctioned tool
  setup) or run it via its **official Docker image** (`docker run …`) instead.
  The gate is about **harm / irreversibility / external reach** — not "a binary
  is absent" or "spinning a local container." Rule of thumb: **local + reversible
  + harmless → just do it**; global / irreversible / external / secret → stop.

---

## 7. Execution rules

- **Read before you write.** Open the file (and its neighbours) before editing.
- **Respect the hard boundaries** from RULES.md: vendor SDK only inside its
  adapter; all config through the one config module; state persists where
  correctness needs it; files small (≤ ~400 lines).
- **Atomic commits straight to the main branch.** One logical change per commit,
  Conventional Commits with a repo scope — `feat(<component>): …`,
  `test(<component>): …`, `docs(<component>): …`. No feature branches or PRs by
  default. Commit **and push** after every completed increment. Task-folder docs
  may ride along with the code change they describe, or be their own `docs(...)`
  commit.
- **Parallel on the same code → git worktree.** The only reason to leave a single
  working copy: when two efforts touch the **same functionality at once**. Give
  each its own worktree so edits don't collide, then merge back. Independent
  parallel work just makes separate commits.
- **Secrets hygiene.** Never write a key/token/secret into any file or commit.
  Secrets live only in the environment (gitignored). Before committing, scan the
  staged diff for anything secret-like.
- **Never commit** env files, keys, anything under data/output/log directories,
  or generated artifacts. `.gitignore` enforces it; if `git status` shows one,
  stop and fix it.

---

## 8. Subagents & delegation

Use a subagent when a side task would flood the main context with file dumps or
search output you won't reuse, or when you want an **independent** opinion. They
live in [`../agents/`](../agents/):

| Subagent | Use it to… | Phase |
|----------|------------|-------|
| `planner` | turn a `BRIEF.md` into a numbered `PLAN.md` (steps, risks, escape hatches) without touching code | any |
| `reviewer` | audit a diff in a **fresh context** against the golden rules + correctness, report gaps only | any |
| `verifier` | run `make check` / the acceptance check and report pass/fail **with evidence**, no edits | any |

Patterns: **parallelize independent reads**; **evaluator-optimizer** =
`reviewer`/`verifier` checking the builder's output in a fresh context so the
writer isn't its own grader. Keep the toolset small — more agents ≠ better.

**Mandatory per increment (PROMPT.md §4b):** before **every** commit, spawn the
`verifier` (re-run the check, report PASS/FAIL with evidence) then the `reviewer`
(audit the diff vs the golden rules + correctness) in fresh contexts. Skipping
either is a loop violation. `planner` runs earlier — at an objective's start — to
write `PLAN.md`; it is not part of the per-commit gate.

### 8a. Parallelize independent work (the default — with guardrails)

When a unit of work decomposes into **genuinely independent** sub-tasks — ones
that don't consume each other's output and don't write the same files — run them
**concurrently as parallel subagents**, not serially. Good fits: independent
research/reads across subsystems, several review lenses over one diff at once,
independent file edits **via separate git worktrees** (§7) so concurrent writes
can't collide.

This does **not** override §1's simplicity rule: map the dependencies first and
only fan out work that is actually independent and non-trivial. If task B needs
task A's result, they are a **wave boundary** (sequential), not parallel. When
unsure, sequence it.

**Hard guardrails — parallelism never bends the safety model:**
- It speeds up *gathering and analysis within a step*. It does **not** let the
  loop abandon the one-verified-step-at-a-time discipline (§4) or cross a phase
  gate (§6) concurrently. Each parallel result is still independently
  **verified** (§5) before it's accepted.
- **Never run secret-touching, production-affecting, or shared-state mutations
  in parallel** — these stay strictly sequential and gated (golden rules
  #2/#3/#5). Concurrency must not create a race on state that decides whether an
  irreversible action happens.

The reviewer will always find *something*; act only on gaps that affect
correctness or a stated requirement, not on style or speculative hardening.

---

## 9. Multi-perspective review (before any significant or risky change)

Run the change past four lenses and note conclusions in `LOG.md`:

| Lens | Ask |
|------|-----|
| **Engineer** | Correct? Simplest approach? Inside the architecture boundaries? Rollback path? |
| **Risk** | Could this cause harm beyond intended limits? Are the safety guards still in place? Does the safety mode/flag still gate the dangerous path? Do safety limits still override normal logic? |
| **Security** | Any secret exposed/logged? Inputs validated at the boundary? Errors not leaking sensitive data? |
| **Future** | What does this make harder later? New tech debt? Does it bend a golden rule "just this once"? |

---

## 10. Anti-patterns (don't)

- Holding progress only in the conversation — if context were lost, work would
  vanish. Write it to the task folder.
- Editing past `LOG.md` entries or rewriting `PLAN.md` steps mid-task.
- Marking a step done without recorded verification evidence.
- Lowering a gate threshold, or skipping the foundation phase, to "make progress".
- Running an unbounded loop, or thrashing on a failing step past the 3-try hatch.
- Batching unrelated changes into one commit, or letting the remote lag.
- Importing a vendor SDK outside its adapter, or reading config outside the one
  config module.
- Introducing a forbidden runtime dependency (golden rule #1).
- Crossing a human-only boundary (secrets, production deploys, destructive infra,
  irreversible external actions) autonomously. (Milestone tagging and code-phase
  gates ARE autonomous once the gate objectively passes — §4/§6.)
