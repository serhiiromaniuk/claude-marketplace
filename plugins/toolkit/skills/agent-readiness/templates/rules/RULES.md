# RULES.md — `<PROJECT>`

Working agreement for this repo. Read before changing anything. This file is the
durable governance layer (structure, conventions, safety, git). The full spec /
charter lives in `<link to spec doc>`.

---

## Agentic workflow (how work gets executed)

This file is governance (*what is true*). [`AGENTS.md`](./AGENTS.md) is the
operating manual (*how to execute*), [`WORKFLOW.md`](./WORKFLOW.md) is the worked
example, and [`../loop/`](../loop/) is the long-running **agent loop** (re-feed
one fixed prompt; progress lives on disk, not in context). Work is tracked as
per-phase task folders under [`../tasks/`](../tasks/) (`BRIEF/PLAN/LOG/OUTCOME`);
specialist subagents live in [`../agents/`](../agents/).

**At the start of any agentic session, read: RULES.md → AGENTS.md → the active
task → `loop/STATE.md`.** The loop is dev-time tooling only, and it HARD-STOPS at
every phase gate and every human-only boundary (see AGENTS.md §6).

---

## What this is

`<One-paragraph description of the project: what it does, who runs it, its
runtime shape (service / library / CLI / batch job), and its top constraint.>`

### Golden rules (never violate)

1. `<Golden rule #1 — the single most important invariant. e.g. a category of
   dependency that must never enter the runtime.>`
2. `<Golden rule #2 — a mode/flag that gates a dangerous capability; safe
   default; never default to the dangerous value.>`
3. **Secrets only via environment / a secrets manager.** Never hardcode
   keys/tokens; never commit env files, key files, or anything under data/output
   directories.
4. `<Golden rule #4 — a scope limit for the current milestone (what is out of
   scope for now).>`
5. `<Golden rule #5 — a safety invariant about irreversible/external actions
   (e.g. a guard must be in place before/around the risky operation; safety
   limits override normal logic).>`
6. **Phase 1's foundational gate gates everything.** No later-phase production
   logic until the foundation (research / design / scaffolding, as your phase
   table defines) is complete and reviewed.

---

## Phase workflow

Build strictly in order; commit + tag at each milestone (see Git). An agent (the
loop) **may tag a milestone and roll into the next phase autonomously, but only
once that phase's gate has objectively passed** (the project's check command,
e.g. `make check`, is green for code phases; the documented acceptance criteria
are met otherwise). The one boundary it never crosses on its own is the
**human-only boundary** — see "Before crossing a human-only boundary" below.

| Phase | Deliverable | Milestone tag |
|-------|-------------|---------------|
| 1 | `<foundation: research / design / scaffold complete & reviewed>` | `v0.1-<name>` |
| 2 | `<core component built + first end-to-end path working>` | `v0.2-<name>` |
| 3 | `<main feature + its acceptance check>` | `v0.3-<name>` |
| 4 | `<hardening: observability, safety limits, ops>` | `v0.4-<name>` |
| 5 | `<all checks pass, validated end-to-end, ready to ship>` | `v1.0-<name>` |

**Acceptance gate** (define the objective, measurable criteria for your key
milestone here — e.g. all of: `<metric A ≥ threshold>`, `<metric B within
bound>`, `<coverage ≥ 80%>`, `<N validation runs>`). Never weaken these; fix the
work, not the threshold.

---

## Architecture rules

- **Vendor / external SDKs sit behind one adapter.** Core logic depends only on
  your own interface (e.g. `src/<component>/client.py`), never directly on a
  third-party SDK. Keep the vendor import in the adapter module only.
- **All config flows through one module.** Validate at startup, fail fast on
  missing/invalid config. No scattered environment reads across modules.
- **State survives restart** where correctness depends on it. Persist critical
  state so a restart never loses it or resumes work incorrectly.
- **Many small files** (≤ ~400 lines, 800 hard max). One responsibility each.

---

## Conventions

- `<language + version pin, one place, read by both local env and any
  container>`. Type hints / docstrings on public surfaces.
- **Structured logging**, no ad-hoc `print`/stdout debugging left in.
- **Every external / network call** wrapped with error handling + retry/backoff.
  Never silently swallow errors.
- Validate all external data (API responses, inputs, config) at the boundary.
- Format/lint and type-check with the project's configured tools.

## Local development (isolated + reproducible)

- **Never install into system-wide tooling.** Use an isolated environment. The
  `Makefile` is the only sanctioned entry point — every dev target runs the
  isolated environment's own binaries.
  - `make install` → set up the environment + install deps · `make check` →
    lint + typecheck + test · `make lock` → freeze exact versions.
- **Reproducibility is a priority.** Pin dependency versions; commit the lockfile.

## Decision process

Any choice without a strict roadmap is **resolved in the design/research
document before implementation**, not decided ad hoc in code. Golden rule #6
gates this.

---

## Testing

- Coverage target **≥ 80%** (adjust to the project). TDD where practical
  (red → green → refactor).
- Must-test: the core correctness-critical logic, boundary/edge cases, and any
  safety-limit triggers.
- Run via the isolated environment: `make test`. Never invoke the test runner
  against system-wide tooling.

---

## Git

**Commit message** — Conventional Commits:

```
<type>(<scope>): <subject>
```

- types: `feat fix refactor docs test chore perf ci build`
- scopes: `<the project's component names>`

**Branching & parallel work**
- The main branch is the working branch by default: atomic, separate commits
  directly to it. No feature branches / PRs unless the project needs them.
- **Git worktrees** are the exception, used only when two efforts work on the
  **same functionality in parallel** — give each its own worktree so edits don't
  collide, then merge back. For independent parallel work, separate commits are
  enough.

**Cadence & milestones**
- **Commit + push after every completed change, scope, or task** — do not batch
  unrelated work or leave the remote behind.
- Tag milestones per the phase table (`git tag v0.1-<name>` then `git push
  --tags`). The agent applies these tags itself once the phase gate is
  observed-green (a tag asserts the gate passed — never tag to "make progress").

**Never commit:** env files / secrets / keys, anything under data/output/log
directories, generated artifacts. Enforced by `.gitignore` — if `git status`
ever shows one of these, stop and fix it.

---

## Before crossing a human-only boundary

This checklist is **human-only — never an agent/loop action.** The loop stops at
the boundary (`<<LOOP:BLOCKED>>`, or `<<LOOP:DONE>>` at the final milestone) and
hands over here. Human-only actions: handling secrets / production credentials,
production deploys, destructive infrastructure changes, and irreversible
external actions. Do the documented pre-flight checklist, then a human performs
the action (golden rules #2/#3/#5).
