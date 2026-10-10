---
name: agent-readiness
description: Audit how well a software repo is set up for autonomous, long-running agentic work (Claude Code, AGENTS.md / CLAUDE.md, subagents, unattended Ralph-style loops) — grade 7 pillars into a short scorecard plus a stateful .agent-readiness/score.json with a trend, then optionally plan or apply the fixes from bundled templates. Use when asked to "grade this repo for agents", "how agent-ready / automation-ready is this codebase", "is this ready for an unattended Claude loop", "audit our Claude Code / AGENTS.md setup", "make this repo work for a Ralph loop / long-running agent", "re-run the readiness check and show the trend", "bring this repo up to <reference> for automation", or "score and then fix our agentic tooling". Not a code-quality review.
---

# Agent readiness

Grade a repository on how well it's set up for **autonomous, long-running agentic work** —
then improve it. Modeled on the `assessment-report` skill (same scoring vocabulary, same
optional renderer); the *shape* here is fixed by `rubric/rubric.md` (7 pillars), and there's a
second mode the reporting skill doesn't have: **apply the fixes**.

## Two modes

- **Mode 1 — `audit`** (baseline): scan the repo read-only, score the 7 pillars, write a
  short scorecard + a diffable `.agent-readiness/score.json` into the repo.
- **Mode 2 — `uplift`** (plan & apply): turn the graded gaps into changes — applied on-the-fly
  now, or written to a task file to do later.

Default to `audit`. Only enter `uplift` when the user asks to fix/adapt, and confirm which
apply-mode (on-the-fly vs. postponed) before writing to their repo.

---

## Mode 1 — audit (baseline)

1. **Scan — read-only.** Follow `reference/scan-playbook.md`: orient, then probe each of the 7
   pillars across all common conventions (`CLAUDE.md`/`AGENTS.md`/`.cursor`, `tasks/`, `ralph/`
   or `loop/`, `Makefile`, `.claude/agents`, git config). **Never mutate or run** the repo's
   code; the only files Mode 1 writes are the two in step 3. Record concrete evidence paths +
   a confidence flag per pillar.
2. **Score.** Apply `rubric/rubric.md`: per-pillar maturity 0–4 → percent, weighted → composite
   → A–F band + adoption level (reuses `assessment-report`'s band table). Each gap gets a
   severity **and a remediation stance** (Fix now / Schedule / Accept) — the stance routes Mode 2.
3. **Write the stateful artifact.** Per `reference/score-schema.md`: get a real timestamp
   (`date -u +%FT%TZ` — never invent one), read any existing `.agent-readiness/score.json` to
   fill `previous` + compute `delta`, then write `.agent-readiness/score.json` and the short
   `report.md`. Show the trend (`▲/▼/─`) if there's a prior run; say "baseline" if not.
4. **Present.** Show the short scorecard: composite grade + adoption level + the 7-row pillar
   table + strengths + the 1–2 "do first" items. Keep it to ~one screen. Note plainly that this
   is an **adoption-maturity** scale, not a code-quality score.

### Optional branded render (only if asked)
Reuse the sibling skill's engine — don't rebuild it. The 7 pillars are the radar axes, the
composite is the gauge. The engine lives at
`${CLAUDE_PLUGIN_ROOT}/skills/assessment-report`: build `.agent-readiness/report.html` from its
`assets/template.html` following its `assets/STYLE.md`, then render it to
`.agent-readiness/report.pdf` and verify a couple of pages **exactly as the `assessment-report`
SKILL.md's render step describes** — follow that file, not a copy of its command here, so the
two never drift.

---

## Mode 2 — uplift (plan & apply)

Input is the graded gaps from Mode 1 (read `.agent-readiness/score.json`). Prioritize on
**Impact × Effort** — usually P2 (memory) / P3 (loop) / P4 (gates) give the most maturity per hour.
The reference implementation to install from is bundled with this skill (domain-free, drop-in)
at `${CLAUDE_PLUGIN_ROOT}/skills/agent-readiness/templates` — copy from there; a bare
`templates/` path would resolve against the target repo, not this skill. Every
`templates/...` path below is relative to `${CLAUDE_PLUGIN_ROOT}/skills/agent-readiness/`.

**Ask which apply-mode**, then:

- **On-the-fly (apply now):** for each `Fix now` gap, install or repair the pillar from
  the templates into the target repo. Every template is written for ONE installed layout —
  its paths and links assume it, so install exactly this:

  | Template | Installs to |
  |---|---|
  | `templates/rules/RULES.md`, `AGENTS.md`, `WORKFLOW.md` | repo root: `RULES.md`, `AGENTS.md`, `WORKFLOW.md` |
  | — | repo root `CLAUDE.md` that `@`-imports `@RULES.md` and `@AGENTS.md`, so every subagent starts with the rules loaded and the graders skip re-reading them |
  | `templates/loop/` | `loop/` (the scripts locate each other and the repo from there). Copy with `cp -p` or run `chmod +x loop/*.sh` after: a script written with Write/Edit loses `+x`, the Makefile targets then fail and the guards skip their checks |
  | `templates/tasks/` | `tasks/` (`INDEX.md` + `_template/`) |
  | `templates/agents/*.md` | `.claude/agents/` |
  | `templates/commands/*.md` | `.claude/commands/` (`/loop-step`, `/where`) |
  | `templates/Makefile.sample` | merged into the repo's `Makefile` |

  Then **fill the placeholders**: `<PROJECT>` everywhere (`grep -rnF '<PROJECT>'`), and in
  `RULES.md` the golden rules, the phase table and the acceptance gate — with the owner, since
  only they know them. The `reviewer` audits every diff against those golden rules, so an
  unfilled one is an unaudited one. From the Makefile, merge a `check` target (its gates run in
  parallel — with `--output-sync=target` on GNU make ≥ 4.0, interleaved output on older make) plus the
  `where` / `loop-hygiene` / `step-done` / `amendments` targets. Install the graders
  together — `templates/agents/{planner,reviewer,plan-reviewer,close-reviewer,adjudicator}.md`, plus
  `scout.md` for read-only discovery steps, and `verifier.md` when a step's check needs judgment (it is optional: the deterministic
  gate is run by `step-done.sh`) — since PROMPT §1/§4b/§7 dispatch them, and
  `templates/loop/step-done.sh`, `amendments-guard.sh` + `merge-gate.sh` alongside the
  other two scripts. **Install `templates/loop/where.sh` +
  `entry-size-guard.sh` whenever you install the loop** — a loop without them regrows the
  control-plane bloat described in `reference/ratchets.md`, which is the single largest
  measured cause of iteration slowdown.
  **Never overwrite** an existing file silently — show a diff and confirm, or write alongside.
  The same goes for a name: a project `.claude/agents/<name>.md` hides a user-level
  `~/.claude/agents/<name>.md` of that name, so check for `planner`, `reviewer`, … there and
  tell the owner which of their own agents would stop loading in this repo. Keep each
  template's `model:` / `effort:` lines (`templates/rules/AGENTS.md` §10 says why each role
  is sized as it is).
  Then re-run Mode 1 to confirm the grade moved, and commit per the repo's own hygiene rules.

- **Postponed (write to file):** dogfood the methodology — write the plan *in the format it
  installs*. Create `tasks/YYYY-MM-DD_agent-readiness-uplift/` (off-roadmap naming, today's
  date) from `templates/tasks/_template/` with a `BRIEF.md` (the goal: reach grade X) and a
  `PLAN.md` whose steps are the `Fix now`/`Schedule` gaps in priority order, each naming its
  check ("re-run agent-readiness; P3 ≥ level 3"), and add its `todo` row to `tasks/INDEX.md`
  (create the ledger from `templates/tasks/INDEX.md` if the repo has none). Now the uplift is
  itself a loop-friendly task the repo's own (or a fresh) agent can execute later.

`Accept (interim)` gaps are recorded in the report, not actioned — so the acceptance is deliberate.

---

## Key conventions (don't relearn these)
- **Read-only scan in Mode 1.** Scanning never edits or runs the target; Mode 1 writes only `.agent-readiness/score.json` and `report.md` (plus `report.html`/`report.pdf` when a render was asked for). Only Mode 2 changes the repo itself, only after confirmation.
- **One engine, reused.** Scoring vocabulary and the PDF renderer come from `assessment-report` — this skill adds the rubric, the state layer, the scan playbook, and the uplift step. Don't fork the renderer.
- **The artifact is stateful.** Always read the prior `score.json` and emit `previous`+`delta` so re-runs show a trend, not just a snapshot.
- **Templates are the single source of "good".** `templates/` is both what the rubric describes and what Mode 2 installs — keep them in sync.
- **Every grader reads what it is grading.** `reviewer` gets the step's own acceptance text and answers `INTENT: satisfied | shortfall | creep` first — without it the only judge of "did this increment do what the step said" is the agent that wrote it, and a flawless diff against the wrong step returns green from both graders. `plan-reviewer` audits a freshly written `PLAN.md` before step 1, because plan defects are found by *executing* them (two real cases: a plan revised 16→20 steps mid-objective; a step that became "part 1…part 8"). `close-reviewer` checks a task close before any done-when box is ticked — it re-runs the checks, exercises the deliverable and hunts stubs, because steps can each pass while the BRIEF stays unmet. `adjudicator` rules on whether a *failing gate* is itself wrong, and is the only role with no stake in the increment continuing — a `raise-with-basis` ruling is actionable only once its arithmetic is in a committed decision record.
- **Review by risk, close by script.** Risky steps (code with logic, scripts, infra config, host/env changes, decision records, anything near a golden rule) get the `reviewer` before the commit; low-risk steps (doc prose, mechanical edits) are committed unpushed and reviewed in one batch before the push — unpushed == unreviewed, and `where.sh` reports the count as `.unreviewed`. The reviewer runs in the background while the LOG is written, reports every CRITICAL/HIGH, at most 3 MEDIUM and no LOW. `loop/step-done.sh` closes the step in one command (gate → LOG evidence → tick → hygiene → scan → commit), so a deterministic gate needs no verifier subagent.
- **Position is computed, never narrated.** `templates/loop/where.sh` derives phase · task · step N/M · governing spec · tree state · the read list from the `PLAN.md` checkboxes, the `LOG.md` tail and `git status`. The loop reads ONLY the files it names, which is what keeps closed tasks' logs out of context structurally. The read list is lean on purpose: rules `CLAUDE.md` already `@`-imports are reported as `.loaded` and not re-read, the active `LOG.md` is replaced by `where.sh --context` (newest two entries), and the governing spec shrinks to the sections the step cites with `spec §<key>`, which cuts the resume read to a fraction. Detail is written **once**, in the LOG; pointer files (`STATE.md`, `INDEX.md`) change only on gate/decision/carry-forward/task-boundary events. `entry-size-guard.sh` is the ratchet. See `reference/ratchets.md` §"Control-plane prose".
- **Speed comes from round-trips, not from cutting gates.** Measured on real projects, wall time goes to tool-call round-trips, serial work that was independent, and per-step ceremony. So the templates batch independent calls, fan out `[parallel: X]` plan groups (research areas, independent decision records — merged through `merge-gate.sh`, reviewed in one pass), collect owner questions into the PLAN and ask them in one batch, allow batch steps for trivial items one check proves, script the ceremony (`where.sh --context`, `step-done.sh`, a parallel `make check`), and size a model and an effort per role. `/fast` speeds up the main session's output on the same model. `templates/rules/AGENTS.md` §10.
- **Never invent a timestamp or a score.** Timestamps come from `date`; levels come from observed evidence. Verified-absent (you looked, it's not there) beats a guessed level.

## Files
- `rubric/rubric.md` — the 7 pillars, maturity anchors, weights, scoring → grade (the "shape").
- `reference/scan-playbook.md` — read-only per-pillar detection recipes + integrity statement.
- `reference/score-schema.md` — the `.agent-readiness/score.json` schema, diff/trend model, `report.md` shape.
- `reference/ratchets.md` — designing floors/ceilings that can't deadlock the loop: the scoping rule, threshold sanity checks, and the falsified-metric path. Read for P4 audits and before installing any gate.
- `templates/` — a domain-free reference implementation of an agent-operable repo (loop, tasks, rules, subagents, commands, Makefile). Both the rubric's benchmark and Mode 2's install source.
- `tests/loop-scripts.test.sh` — tests for the `templates/loop/*.sh` scripts (fixture repos in a temp dir, a fake `claude`; bash ≥ 3.2, git, jq, make). Run it after changing any loop script.
