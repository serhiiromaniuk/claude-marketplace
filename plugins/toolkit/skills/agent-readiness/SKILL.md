---
name: agent-readiness
description: Audit how well a software repo is adopted for autonomous / long-running agentic work (Claude Code, agents, unattended loops), grade it against a 7-pillar rubric into a short scorecard + a stateful .agent-readiness/score.json, then optionally plan and apply the improvements. Use when asked to "grade this repo for agents", "how agent-ready / automation-ready is this codebase", "audit the Claude Code setup", "make this repo work for a Ralph loop / long-running agent", or "score and then fix our agentic tooling".
---

# Agent readiness

Grade a repository on how well it's set up for **autonomous, long-running agentic work** —
then improve it. Modeled on the `assessment-report` skill (same scoring vocabulary, same
optional renderer); the *shape* here is fixed by `rubric/rubric.md` (7 pillars), and there's a
second mode the reporting skill doesn't have: **apply the fixes**.

## Two modes

- **Mode 1 — `audit`** (baseline): scan the repo read-only, score the 7 pillars, write a
  short scorecard + a diffable `.agent-readiness/score.json` into the repo. *(Your requirement #1.)*
- **Mode 2 — `uplift`** (plan & apply): turn the graded gaps into changes — applied on-the-fly
  now, or written to a task file to do later. *(Your requirement #2.)*

Default to `audit`. Only enter `uplift` when the user asks to fix/adapt, and confirm which
apply-mode (on-the-fly vs. postponed) before writing to their repo.

## When to use
"grade / score this repo for agents", "how agent-ready is this codebase", "is this ready for a
long-running / unattended Claude loop", "audit our Claude Code / AGENTS.md setup", "bring this
repo up to <reference> for automation", "re-run the readiness check and show the trend".

---

## Mode 1 — audit (baseline)

1. **Scan — read-only.** Follow `reference/scan-playbook.md`: orient, then probe each of the 7
   pillars across all common conventions (`CLAUDE.md`/`AGENTS.md`/`.cursor`, `tasks/`, `ralph/`
   or `loop/`, `Makefile`, `.claude/agents`, git config). **Never mutate or run** the repo.
   Record concrete evidence paths + a confidence flag per pillar.
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
composite is the gauge:
```bash
AR=${CLAUDE_PLUGIN_ROOT:-~/.claude/plugins/toolkit}/skills/assessment-report
PORT=9333
google-chrome --headless=new --disable-gpu --no-sandbox \
  --remote-debugging-port=$PORT --remote-allow-origins=* about:blank >/tmp/chrome.log 2>&1 &
CHROME_PID=$!; for i in $(seq 1 30); do curl -s http://127.0.0.1:$PORT/json/version >/dev/null 2>&1 && break; sleep 0.3; done
node "$AR/assets/render.mjs" "/abs/path/report.html" "$PWD/.agent-readiness/report.html.pdf" $PORT "Agent Readiness · <repo>"
kill $CHROME_PID 2>/dev/null
```
Build the HTML from `$AR/assets/template.html` following `$AR/assets/STYLE.md`, then verify a
couple of pages with `pdftoppm` exactly as the `assessment-report` SKILL.md describes.

---

## Mode 2 — uplift (plan & apply)

Input is the graded gaps from Mode 1 (read `.agent-readiness/score.json`). Prioritize on
**Impact × Effort** — usually P2 (memory) / P3 (loop) / P4 (gates) give the most maturity per hour.
The reference implementation to install from is bundled at `templates/` (domain-free, drop-in).

**Ask which apply-mode**, then:

- **On-the-fly (apply now):** for each `Fix now` gap, install or repair the pillar from
  `templates/` into the target repo, mapping template dirs to the repo's convention:
  `templates/loop/` → `ralph/` (or `loop/`); `templates/tasks/` → `tasks/`; `templates/rules/`
  → `CLAUDE.md`/`AGENTS.md`/`WORKFLOW.md`; `templates/agents/` + `templates/commands/` →
  `.claude/agents/` + `.claude/commands/`; `templates/Makefile.sample` → merge a `check` target
  plus the `where` / `loop-hygiene` targets. **Install `templates/loop/where.sh` +
  `entry-size-guard.sh` whenever you install the loop** — a loop without them regrows the
  control-plane bloat described in `reference/ratchets.md`, which is the single largest
  measured cause of iteration slowdown.
  **Never overwrite** an existing file silently — show a diff and confirm, or write alongside.
  Then re-run Mode 1 to confirm the grade moved, and commit per the repo's own hygiene rules.

- **Postponed (write to file):** dogfood the methodology — write the plan *in the format it
  installs*. Create `tasks/agent-readiness-uplift/` from `templates/tasks/_template/` with a
  `BRIEF.md` (the goal: reach grade X) and a `PLAN.md` whose steps are the `Fix now`/`Schedule`
  gaps in priority order, each naming its check ("re-run agent-readiness; P3 ≥ level 3"). Now the
  uplift is itself a loop-friendly task the repo's own (or a fresh) agent can execute later.

`Accept (interim)` gaps are recorded in the report, not actioned — so the acceptance is deliberate.

---

## Key conventions (don't relearn these)
- **Read-only in Mode 1.** Scanning never writes or runs the target. Only Mode 2 mutates, only after confirmation.
- **One engine, reused.** Scoring vocabulary and the PDF renderer come from `assessment-report` — this skill adds the rubric, the state layer, the scan playbook, and the uplift step. Don't fork the renderer.
- **The artifact is stateful.** Always read the prior `score.json` and emit `previous`+`delta` so re-runs show a trend, not just a snapshot.
- **Templates are the single source of "good".** `templates/` is both what the rubric describes and what Mode 2 installs — keep them in sync.
- **Position is computed, never narrated.** `templates/loop/where.sh` derives phase · task · step N/M · governing spec · tree state · the read list from the `PLAN.md` checkboxes, the `LOG.md` tail and `git status`. The loop reads ONLY the files it names, which is what keeps closed tasks' logs out of context structurally. Detail is written **once**, in the LOG; pointer files (`STATE.md`, `INDEX.md`) change only on gate/decision/carry-forward/task-boundary events. `entry-size-guard.sh` is the ratchet. See `reference/ratchets.md` §"Control-plane prose".
- **Never invent a timestamp or a score.** Timestamps come from `date`; levels come from observed evidence. Verified-absent (you looked, it's not there) beats a guessed level.

## Files
- `rubric/rubric.md` — the 7 pillars, maturity anchors, weights, scoring → grade (the "shape").
- `reference/scan-playbook.md` — read-only per-pillar detection recipes + integrity statement.
- `reference/score-schema.md` — the `.agent-readiness/score.json` schema, diff/trend model, `report.md` shape.
- `reference/ratchets.md` — designing floors/ceilings that can't deadlock the loop: the scoping rule, threshold sanity checks, and the falsified-metric path. Read for P4 audits and before installing any gate.
- `templates/` — a domain-free reference implementation of an agent-operable repo (loop, tasks, rules, subagents, commands, Makefile). Both the rubric's benchmark and Mode 2's install source.
