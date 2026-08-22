# Changelog

## [0.13.1] - 2026-08-22

### Fixed
`commands/cost-report.md` wrote a dollar figure as `~$1/MTok`. In command markdown
`$1` is a positional-argument placeholder, so invoking the command substituted a
word from the user's arguments and the sanity-check rule rendered as "a blended
rate far above ~this/MTok" — the one number in that rule, gone. Now spelled
`~1 USD/MTok`. Worth remembering for any command doc: write "USD", or escape,
never a bare `$` followed by a digit.

## [0.13.0] - 2026-08-22

### Fixed (cost-tracker overstated every bill by ~4.3x)
`cost-report` on a real project produced $26,274 all-time and $9,604 for one repo.
Both were wrong by **4.30x** — the true figures are **$6,104** and **$2,755**. Two
independent bugs in `hooks/cost-tracker/track.py`, compounding:

1. **The Opus row carried retired Claude 3 Opus pricing** — `$15 in / $75 out` per
   MTok. Opus 5 / 4.8 / 4.7 / 4.6 are **$5 / $25**. A 3x error on the tier that
   serves the overwhelming majority of agentic work. Fable 5 was also mapped to
   the Opus row at $15/$75 instead of its own **$10 / $50**, and its comment
   claimed falling back to the Opus tier "keeps estimates conservative" — it did
   the opposite for a model priced *above* Opus.
2. **A phantom long-context premium.** The table doubled every rate once a single
   request's context passed 200K. No current model has such a premium: Opus
   5/4.8/4.7/4.6, Sonnet 5/4.6, Fable 5 and Mythos 5 are all single-price at a 1M
   window. On cache-heavy agentic sessions most requests cross 200K, so this
   silently doubled the bulk of the spend on top of bug 1.

Corrected table, with cache multipliers derived from the input rate (write 1.25x,
read 0.10x) rather than hand-typed:

    opus         5 / 25 / 6.25 / 0.50
    sonnet       3 / 15 / 3.75 / 0.30
    haiku        1 /  5 / 1.25 / 0.10
    fable       10 / 50 / 12.50 / 1.00
    mythos      10 / 50 / 12.50 / 1.00   (new row)
    default      3 / 15 / 3.75 / 0.30    (was: top tier)

`long` now equals `std` for every family. The tier machinery is kept — the
`CLAUDE_COST_PRICING` override uses it, and older 1M-context betas genuinely did
carry ~2x — with a comment forbidding its reintroduction without a published rate.

Deliberately NOT encoded: Sonnet 5's $2/$10 introductory rate, valid through
2026-08-31. A hardcoded intro price silently overstates the discount the day it
lapses, and an unattended collector has nobody watching. Sonnet is undercounted
by 1.5x until then; it was 1.5% of the observed spend.

The unknown-model fallback moved from the top tier to the Sonnet tier. A new,
unrecognised model id is far more often mid-tier than frontier, and guessing high
turns every unknown into a phantom bill.

### Added (regression guards)
`--self-test` gains four checks that would have caught both bugs: Opus prices at
5/25, Opus cache multipliers are 6.25/0.50, Fable prices at 10/50, and crossing
200K does **not** change the rate.

### Changed (`commands/cost-report.md`)
- A magnitude sanity-check before presenting anything: divide USD by tokens, and
  a blended rate far above ~$1/MTok on a cache-heavy workload means the rate table
  is wrong, not that the work was expensive.
- Says plainly that cache read is a tenth of input, so long agentic sessions are
  cheap per token and large in aggregate — and to name which of the two drives the
  number. On the project measured, fresh input was **$2** of $2,755; cache read
  was 52%, cache write 28%, output 20%, across 3.05 billion tokens.
- Warns that the Stop hook never fires for headless `claude -p` runs, so Ralph
  loops and subagents are missing until a backfill. On the project measured this
  hid **32,032 of 32,034 rows** — the repo showed $0.00 before backfill.

### Note on re-pricing existing databases
Cost is computed at ingest, so an existing `usage.db` keeps the old numbers.
Deleting it and re-backfilling is **lossy** — rows whose `.jsonl` has since been
rotated away cannot be rebuilt (75 sessions, 17,189 rows in the case measured).
Re-price in place instead: read every row, recompute with `cost_usd`, `UPDATE`.

## [0.12.0] - 2026-08-22

### Added (cost tracking that survives a moved config dir)
`cost-tracker` — a `Stop` hook plus `/toolkit:cost-report`, reporting this
machine's own Claude Code token spend from the session transcripts Claude Code
already writes. No API calls, nothing leaves the machine.

The design comes from a tracker that had silently collected nothing for a month:
its transcript glob was hardcoded to `~/.claude/projects`, while the sessions had
moved to a `CLAUDE_CONFIG_DIR` elsewhere. The hook ran, found zero files, and
exited 0 every time. Three properties follow from that failure:

- `hooks/cost-tracker/track.py` — scans **every** known config dir
  (`CLAUDE_CONFIG_DIR` and the `~/.claude` default, de-duplicated by realpath),
  so relocating an install cannot quietly stop collection.
- `--status` writes and reads a `last-run.json` breadcrumb and **warns when the
  newest row is more than three days old**. A collector that stops is now
  discoverable instead of looking like a quiet week.
- **History is recoverable at any time.** Ingest is idempotent (keyed by
  assistant-message uuid) and reads the transcripts, so `backfill` recovers
  sessions that ran before the plugin was installed, or in another install's
  config dir. The only hard limit is transcript retention.

Other properties worth naming: pricing includes the long-context (>200K input)
premium and is overridable via `CLAUDE_COST_PRICING` rather than requiring an
edit; only **metadata** is stored (uuid, timestamp, project directory name, tool,
model, token counts, cost, session id — never prompt or response text); the
database is created `0600` inside a `0700` directory; transcripts are streamed
line-by-line so a tens-of-MB file never lands in memory during a hook; and the
hook exits 0 on any exception so a tracker bug can never break a session.

`--self-test` covers insertion, duplicate suppression, tool/project capture and
both pricing tiers on synthetic data in a temp dir. It earned its place
immediately by failing on a wrong hand-written expectation rather than on the code.

## [0.11.0] - 2026-07-27

### Added (a bounded control plane — the loop's own biggest slowdown)
`agent-readiness`'s loop templates gain a position oracle and a prose ratchet.
Both come from a measured failure on a real Ralph-loop project, not from theory:
iteration wall time went from **12-17 min to 47-211 min** across three objectives
with the same model, machine and discipline. The cause was neither the gate (28 s),
the model, nor review standards — it was that every iteration is a *fresh* agent
that re-reads an *append-only* control plane. The ledger reached 93,119 B of which
five rows were 88,900 B (one row was 41,717 B on a single line); the pointer file
reached 88,025 B of which 87,000 B was accumulated "you are here" paragraphs.
~350 KB read before any work began, growing quadratically, with the same summary
written three times (log entry, pointer paragraph, ledger row).

- `templates/loop/where.sh` — **position is computed, not narrated.** Derives
  phase · task · step N/M · step title · governing spec + stub flag · gate · tree
  state · `last_result` · and a `read[]` **contract** from the `PLAN.md`
  checkboxes, the `BRIEF.md` `Governing spec:` line, the `LOG.md` tail and
  `git status`. `--json` (loop) · `--human` / `make where` (person) · `--read`.
  Exit 2 with `.error` when the ledger has no in-progress task. The read contract
  is what keeps a closed task's log out of context *structurally* rather than by
  asking the agent nicely. The idea is spec-kit's `check-prerequisites --json`
  pattern; none of spec-kit itself is adopted.
- `templates/loop/entry-size-guard.sh` — the ratchet (`make loop-hygiene`): LOG
  entry ≤40 lines, `STATE.md` ≤40 lines, ledger row ≤200 B. **Warn-only and NOT a
  dependency of the correctness gate** — that gate must never fail on prose style
  — so `PROMPT.md` §5 calls it in the agent's own pre-commit sequence, which is
  what gives the warning a reader. `--strict` exits 1 for CI.

### Changed (write detail once; one reviewer pass)
- `templates/loop/STATE.md` no longer restates anything derivable. It keeps the
  gate verdict, decisions not to relitigate, and a **carry-forward** section for
  obligations aimed at a phase whose task folder does not exist yet. It changes on
  those events, not every iteration. Ships at 31/40 lines so there is headroom.
- `templates/loop/PROMPT.md` §1 is "run the oracle, read only `.read`, dispatch on
  the flags" (`.error` > `.tree_clean` > `.needs_open` > `.needs_plan` >
  `.spec_stub` > `.all_steps_done` > do step N); §5 states the write-once rule and
  the budget; §4b is **one** reviewer pass — CRITICAL/HIGH fixed now, MEDIUM/LOW
  appended to `PLAN.md` `## Amendments` with `file:line`. Extra polish rounds are
  now named as a violation in their own right: 2-3 passes per step, each costing a
  re-verify plus a re-review, was the measured secondary cause.
- `templates/agents/{reviewer,verifier}.md` report in bullets with a findings cap
  and trimmed evidence — a subagent's report *is* main-context input, so an essay
  there costs what an essay in the log costs. `verifier` reports `INCONCLUSIVE`
  rather than a guessed PASS.
- `templates/tasks/_template/LOG.md` carries the entry *shape* (headline · changed
  · check + observed failure-first · verbatim evidence tail · verifier · reviewer
  dispositions · decision · carry-forward · next) instead of a two-line hint —
  filling a shaped template is cheaper to emit and to re-read than composing prose.
  `BRIEF.md` marks its `Governing spec:` line MACHINE-READ. `tasks/INDEX.md` states
  the ≤200 B row budget and the one-in-progress-row rule the oracle depends on.
- `templates/rules/{AGENTS,WORKFLOW}.md`, `templates/commands/{loop-step,status}.md`,
  `templates/loop/README.md` and `templates/Makefile.sample` (new `where` /
  `loop-hygiene` targets) all follow.
- `rubric/rubric.md` P3 now requires a bounded control plane and **caps P3 at 3**
  when it is append-only; `reference/scan-playbook.md` P3 detects the bloat
  directly (row lengths, pointer size, minutes-per-iteration from `git log`);
  `reference/ratchets.md` gains §"Control-plane prose" with the numbers, the
  four-step fix, and the rescue step that must precede any deletion — grep the
  pointer for live carry-forwards, because history is in git but an unmet
  obligation is not history.

All scripts were tested against a synthetic project through nine cases: normal
position, fleshed vs stub spec, no in-progress row (exit 2), missing task folder,
all-steps-done, a PLAN with no checkboxes, each guard warn path, `--strict`, and
bad-argument handling. Two bugs were found and fixed that way — a stub-detection
false positive from the word "STUB" appearing later in a finished spec, and a
duplicated step title because awk runs `END` on `exit`.

## [0.10.0] - 2026-07-25

### Added (evidence before completion claims)
New skill `verify-before-done`, adapted from `verification-before-completion` in
[obra/superpowers](https://github.com/obra/superpowers) (MIT, commit `3dcbd5c`)
— the only file worth lifting from that framework after auditing it against this
setup. Everything else there either couples to its own 279 KB skill tree,
duplicates native functionality (`using-git-worktrees` vs the `EnterWorktree`
tool), or defers to a different skill on the first line.

- `plugins/toolkit/skills/verify-before-done/SKILL.md` — gate function
  (identify → run → read → compare → claim), per-claim evidence table, stop
  signals, rationalization table. Adds two rows the upstream skill lacks:
  deploy health (probe, not `apply` exit 0) and the unattended-loop case.
- Matters most for `agent-readiness`'s loop templates: a false completion claim
  ends an unattended run early with nobody watching, so the marker protocol is
  only as trustworthy as the evidence behind it.


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
