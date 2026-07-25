# Changelog

## [0.9.1] - 2026-07-25

### Fixed (harness false-stop on its own narration)
Found by running the loop: an iteration whose real last-line marker was
`<<LOOP:CONTINUE>>` was halted as `<<LOOP:GATE_FAILED>>` because its §1
dirty-tree reconcile recap *mentioned* the prior iteration's stop marker in
prose, and `loop.sh` grepped the **entire** output for markers. The v0.8.0
reconcile guidance makes such narration routine, so any recovered-from-stop run
could false-stop on the very next iteration.

- `templates/loop/loop.sh` — dispatch on the **last** `<<LOOP:`-bearing line
  only (PROMPT.md §7 makes the last line authoritative). If that one line
  carries both a stop and a continue marker (protocol violation), stop wins —
  fail toward the human, never past one. No-marker handling unchanged.
  Verified with an 8-case dispatch table: the observed failure shape, its
  inverse (prose `CONTINUE`, final `BLOCKED`), all five markers, trailing blank
  lines, no marker, both-on-one-line.
- `templates/loop/README.md` — doc drift from v0.5.0 corrected: `GATE_FAILED`
  **always** stops (the code's `STOP_ALWAYS` since 0.5.0); the README still
  claimed it was retried under `--continuous`.


## [0.9.0] - 2026-07-25

### Added (gate design — a wrong gate must not deadlock the loop)
Found by running the loop: the templates said "never weaken a gate" in eight
places but never said what to do when the **threshold itself** is the wrong
metric. On a gate no correct work could pass, the loop's only moves were grind or
violate — so it stopped and burned a human interrupt to discover something two
earlier decision records had already implied.

- `templates/rules/AGENTS.md` §6 — the **falsified-metric path**, with three
  objective tests so it can't be used as a shortcut: the overage shape must be on
  record at **≥3 independent checkpoints**, the threshold must be shown (by
  arithmetic, not assertion) to be unreachable alongside the project's other
  *mandated* requirements, and the fix must **re-scope what is counted while
  keeping a hard gate on the portion moved out** — never stop measuring it. The
  increment then becomes the **decision record** (numbers, ≥2 options, a
  recommendation); a human edits the constant.
- `templates/loop/PROMPT.md` §7 — same clause on the `GATE_FAILED` bullet, so the
  loop hands back a *decision* instead of a discovery.
- `templates/rules/RULES.md` — acceptance criteria now carry the arithmetic behind
  each number, and point at AGENTS.md §6 for re-scoping.
- `reference/ratchets.md` (new) — designing floors/ceilings that stay honest:
  floor-vs-ceiling separation, the **scoping rule** (a ceiling counts only the
  quantity it discourages — never bill rule-mandated artifacts to a budget
  written for something else), four pre-install threshold sanity checks
  (project to completion, name the axis, check against the other rules, prove
  both arms fire), and the near-misses that are really weakened checks.
- `rubric/rubric.md` + `reference/scan-playbook.md` — P4 level 4 now requires the
  falsified-metric path, and **caps P4 at 3** when one threshold has been
  individually excused ≥2 times blaming the same mandated artifact: that is a
  mis-scoped gate, not repeated bad luck.


## [0.8.0] - 2026-07-24

### Added (antipattern guards)
- **Single-instance lock** in `templates/loop/loop.sh` (flock) — refuses to start
  if another loop is already running on the repo (two loops clobber each other).
- `templates/loop/PROMPT.md`:
  - §1: reconcile a **dirty tree first** — a non-clean tree means a prior
    iteration was interrupted; verify+commit or restore before new work; never
    leave orphan files.
  - §5: **finish synchronously** — never background the check or defer the commit
    ("commit follows"); expected ratchet/generated diffs are not gate failures.
  - §7: **every turn MUST end with exactly one marker** — a markerless turn is a
    failure; if you can't finish, emit BLOCKED/GATE_FAILED, never end silently.


## [0.7.0] - 2026-07-24

### Added
- `agent-readiness` loop template (`templates/loop/loop.sh`): rides out
  session/usage/rate limits instead of dying. On a FAILED run matching a limit
  signal (usage/rate limit, 429, overloaded, quota, "please try again"), it waits
  `LIMIT_WAIT` (env, default 1800s) and retries the SAME iteration — no failure
  count, no iteration consumed. Gated on non-zero exit so a successful iteration
  whose output discusses rate-limiting never false-trips. Real errors keep the
  5-strike backoff; DONE/BLOCKED/GATE_FAILED unchanged.


## [0.6.0] - 2026-07-23

### Added
- `agent-readiness` loop template: anti-greeting preamble at the top of
  `templates/loop/PROMPT.md` — blunt "EXECUTE THIS TURN, not a chat, act now;
  terse style is not permission to skip work." Fixes an intermittent headless
  misfire where the agent greets ("no task given, what you want?") instead of
  executing (seen under terse/greeting plugins).
- `templates/rules/AGENTS.md`: "harmless local setup is NOT the human-only
  boundary" clause — a missing local tool is not a BLOCKED reason; install it or
  run it via Docker. Boundary = harm/irreversibility/external reach, not "binary
  absent." Stops agents over-blocking on trivial setup.


## [0.5.0] - 2026-07-23

### Fixed
- `agent-readiness` loop template (`templates/loop/loop.sh`): in `--continuous`
  mode `<<LOOP:GATE_FAILED>>` now **stops** (was retried, which spun on a real
  gate block instead of handing back). GATE_FAILED joins DONE/BLOCKED as an
  always-stop terminal.

### Added
- Config-hygiene note in `loop.sh`: run headless under a CLEAN `CLAUDE_CONFIG_DIR`
  with no interactive/greeting plugins (they make `claude -p` answer
  conversationally with no marker).
- Timestamp on each iteration banner.

## [0.4.0] - 2026-07-23

### Changed
- `agent-readiness` skill: the loop template now **mandates** independent review
  per increment (P5). `templates/loop/PROMPT.md` gains a `§4b` step — before every
  commit, spawn the `verifier` (re-run the check, PASS/FAIL with evidence) then the
  `reviewer` (audit the diff) in fresh contexts; skipping either is a loop
  violation. `templates/rules/AGENTS.md` §8 reinforced to match (was framed as
  optional delegation). Ensures repos scaffolded from the skill never skip the
  evaluator-optimizer gate — the writer is never its own grader.

## [0.3.0] - 2026-07-23

### Changed
- `agent-readiness` skill: the `templates/loop/loop.sh` harness now supports
  long **unattended** runs — `--continuous` (only `DONE`/`BLOCKED` halt;
  `GATE_FAILED`/missing-marker/transient errors retry with linear backoff,
  bounded by a consecutive-failure cap), `--model` (pin the driver model), and
  `--skip-permissions`. Supervised default behaviour is unchanged. Added an
  optional `loop/env.sh` hook (sourced each iteration) so a project can put its
  toolchain on `PATH` for the non-interactive child agents, and documented all
  of it in `templates/loop/README.md`.

## [Unreleased]

### Added
- Initial marketplace scaffold with one placeholder plugin.
- `_skill-template/` — copy-to-start template for new skills.
- Placeholder command template, empty agents/ and hooks/ dirs ready for content.
- `glab` skill — GitLab CLI DevOps workflows.
- `claude-in-chrome` skill — Chrome browser automation via the claude-in-chrome MCP.
- `agent-readiness` skill — audits how well a repo is adopted for autonomous/long-running
  agentic work (7-pillar rubric → A–F grade + diffable `.agent-readiness/score.json`), then
  plans & applies the fixes. Reuses the assessment-report scoring/renderer; ships a domain-free
  reference implementation (loop, tasks, rules, subagents) under `templates/`.
- `assessment-report` skill — scored gap/risk assessment reports as branded PDFs. Ships
  with a fully synthetic (fictional data) worked example under `report-types/gap-risk/`.
- `assessment-report` — five new report types, each a `type.md` spec + a full synthetic,
  rendered-and-verified `example.html` on the shared blueprint design system:
  `security-review` (OWASP/CIS/NIST threat-centric posture), `cost-review` (FinOps,
  Savings×Effort), `due-diligence` (tech DD with a RAG verdict, Likelihood×Deal-impact),
  `architecture-review` (Well-Architected 6-pillar), and `post-incident` (blameless
  post-mortem: SEV, timeline, root-cause chain, action items).
