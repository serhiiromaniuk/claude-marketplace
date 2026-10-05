# Changelog

All notable changes to the `toolkit` plugin. Versions follow
[Semantic Versioning](https://semver.org/); dates are YYYY-MM-DD.

## [1.0.0] - 2026-10-05

### Changed — agent-readiness (re-install the templates; layout and names changed)

- **One installed layout.** Every template now assumes repo-root `CLAUDE.md`, `RULES.md`,
  `AGENTS.md` and `WORKFLOW.md`, subagents in `.claude/agents/`, commands in
  `.claude/commands/`, the loop in `loop/` (no `ralph/` alternative) and tasks in
  `tasks/`. Every link resolves from where its file lands. Mode 2 copies from
  `${CLAUDE_PLUGIN_ROOT}/skills/agent-readiness/templates`, keeps the scripts executable
  and says to fill `<PROJECT>` and the golden rules.
- **`/status` is now `/where`.** `/status` is a Claude Code built-in and shadowed the
  template command. `/where` pre-approves only read-only git (`git tag --list`).
- **`loop.sh` exits with a distinct, documented code** for DONE, BLOCKED, GATE_FAILED,
  the iteration cap and a usage error. It bounds rate-limit waits, forwards signals to
  the child, keeps its lock in the real git dir (worktree-safe), validates
  `--max-iterations` and no longer silences stderr.
- **`step-done.sh` can be re-run after exit 3**: it restores LOG/PLAN and unstages on
  failure. Its secret scan no longer skips added lines that start with `+`, and gate
  evidence is stripped of colour codes on BSD sed too.
- **`merge-gate.sh`** merges with `--no-verify` and an inline identity, takes
  `MERGE_GATE_BASE` (default: `origin/HEAD`, else `main`) and no longer reports a hook
  refusal as a conflict.
- **`amendments-guard.sh`** parses an explicit disposition marker; every template that
  describes an amendments entry uses the same format, and PROMPT §1 runs `make amendments`
  at task close.
- **`where.sh`** skips fenced blocks when following `@`-imports and resolves them relative
  to the importing file; ledger links, step titles and `[parallel:X]` groups parse
  consistently.
- **Templates are domain-free**: leftovers from the project they were extracted from are
  gone. The test suite covers the new behaviour.

### Fixed — glab

- **`glab ci trace` is no longer pre-approved.** Without an ID it opens an interactive
  picker, and on a running job it streams until the job ends, so it could hang the call.
- **Helpers work with current glab (≥ 1.54, checked against 1.74).** JSON is filtered by
  piping to `jq` (`glab api` has no `--jq` flag), and a failed API call now returns an
  error instead of a false "No failed jobs found." Cancel uses `glab ci cancel pipeline`;
  `gl-wait` and `gl-pipeline-id` use `glab ci get --output json`.
- **`gl-cancel-all` only touches the current branch**, lists what it would cancel by
  default, and needs `--yes` to cancel anything. `gl-retry-watch` retries the whole
  pipeline through the API instead of the job-only `glab ci retry`.
- **Narrow pre-approval.** `allowed-tools` no longer grants all of Bash, only read-only
  glab and git commands (no token-revealing wildcards).
- **No hardcoded install path.** Claude sources the helpers from
  `${CLAUDE_PLUGIN_ROOT}` in the same Bash call; the skill no longer edits `~/.bashrc`.
  `setup.md` installs glab from gitlab-org/cli (not the archived 2022 fork) and states the
  minimum version.
- **Docs.** Pipeline variables via `--variables-env`, `DEBUG`/`GLAB_DEBUG_HTTP` instead of a
  nonexistent `--verbose`, `tag_list`, `skip_tls_verify`, `/toolkit:glab`, and triggers for
  self-hosted GitLab URLs and `.gitlab-ci.yml`.
- **Tests (160).** Mocks assert the corrected commands, add regressions for each fix, and,
  when glab is installed, check every glab subcommand and flag the helpers and docs use
  against `glab <cmd> --help`.

### Removed

- The skill template and the placeholder `/toolkit:example` command no longer ship to
  installers: every directory under `skills/` loads (a leading `_` does not hide it), so
  `toolkit:_skill-template` showed up in every session. The template moved to
  `templates/skill/SKILL.md` at the repo root, with a corrected `allowed-tools` note
  (it pre-approves tools; it does not restrict them).

### Added

- `LICENSE` (MIT), which both manifests already declared.

### Fixed — claude-in-chrome

- `allowed-tools` no longer pre-approves Bash or every browser tool: only page reading
  and tab housekeeping run without a prompt, so clicks, typing, form fills, JavaScript and
  uploads on untrusted pages still ask.
- Start-up no longer opens two tabs, and every workflow closes the tabs it created.
- Examples set `action_summary` on clicks, keys, typing and form fills; browser choice
  goes through `list_connected_browsers` → `select_browser`, with `switch_browser` only
  for picking inside Chrome. Adds `browser_batch`, `file_upload` and `read_page`'s
  `max_chars`.

### Fixed — assessment-report

- **A numeric footer stays a footer.** `render.mjs` reads a numeric third argument as
  the old `<port>` only when a fourth (the footer) follows, so a footer such as `2026`
  is no longer taken for a port.
- **Every bundled example is invented and says so.** The gap-risk example is rewritten
  from scratch for a fictional parcel-locker operator. The due-diligence and
  architecture-review examples use invented company names. Every cover is labelled as a fictional sample, and no example
  names a real author. The docs now say examples are written from scratch and must never
  be a real engagement, even with names replaced.
- **Numbers follow the rubric.** In due-diligence and in the post-incident action items,
  findings scored 12 were badged MEDIUM and findings scored 6 were badged LOW. They are
  re-badged per `scoring.md`, and every dependent count, bar, bubble, KPI and cover line
  is updated. The "N of M verified" counts in the
  security-review and cost-review examples are corrected.
- **`render.mjs` starts and cleans up its own headless Chrome.** It looks for `CHROME`
  first, then the usual Linux, macOS and Windows install paths. It uses a temporary
  profile and a random port, or reuses a running Chrome with `--port N`.
- **`render.mjs` fails loudly.** It requires Node ≥ 22. A missing file, a page that fails
  to load or a DevTools error exits non-zero instead of writing a PDF of Chrome's error
  page. Paths with spaces or `#` work, and the footer text is escaped.
- **PDF bookmarks list only h1–h3.** Every h4 label used to appear as well, 42–51 entries
  per report. The cover is 268 mm, so it now fills page 1 without spilling onto page 2.
- **`SKILL.md`** renders via `${CLAUDE_PLUGIN_ROOT}` (the old `~/.claude/skills/...` path
  does not exist for a plugin install). It says to copy the type's `example.html`.
  `confluence-publish.md` notes that `createConfluencePage` accepts a space key and needs
  `getContentFormatGuide` first.

### Fixed — cost-tracker (spend was overstated, about 2.9x on the author's history)

- **One API response is counted once.** Claude Code writes a response as several
  transcript lines (thinking, text, tool use), each carrying the full usage; every line
  was counted. Rows are now keyed by message id + request id, the last line's usage
  wins, and tool names are merged across lines.
- **Exact per-version pricing.** `hooks/cost-tracker/pricing.py` holds Anthropic's
  published rates per model version, with separate input, output, 5-minute cache-write,
  1-hour cache-write and cache-read rates (Fable 5.1, Opus 5.5, Sonnet 5.5 and older).
  1-hour cache writes are priced from `cache_creation.ephemeral_1h_input_tokens`. An
  unknown model is stored unpriced and listed as `UNPRICED` instead of inheriting an
  older model's price. `CLAUDE_COST_PRICING` now maps an exact model id to five rates;
  files in the old format are ignored with a warning.
- **The Stop hook stays out of the way.** It reads its own session from the hook payload
  and resumes from saved offsets (on the author's history about 0.2 s per turn instead
  of about 2 s rescanning everything), uses WAL and a busy timeout, never exits 2, prints nothing with
  `--quiet`, and records failures in `last-error.json` for `--status`. `hooks.json`
  sets a 30 s timeout. During the one-time rescan after a migration, a hook ingests
  its own session first and gives the rescan a 2 s slice, so no turn waits long.
- **Databases migrate in place without losing a row.** Schema v2 (`PRAGMA user_version`)
  backs up first, de-duplicates rows whose transcript still exists, keeps rows whose
  transcript is gone (with an estimate of their overstatement in `--status`), and
  reprices everything. `--reprice` recomputes all costs after a future price change.
- **CLI.** argparse with `--backfill`, `--status`, `--report`, `--csv FILE`, `--reprice`,
  `--self-test`; an unknown flag errors instead of running an ingest. 33 unit tests in
  `test_track.py`. The code is split into `track.py`, `pricing.py`, `store.py` and
  `report.py`.
- **`/toolkit:cost-report`** runs one self-contained `track.py` call per step (the Bash
  tool keeps no variables between calls, so later steps used to query an empty path), no
  longer needs the `sqlite3` CLI, and drops two false claims (cache reads are not always
  a tenth of input; Stop fires after every turn, not once per session).

## [0.19.1] - 2026-09-29

### Fixed (a foreign `§N` could hide the spec)

- **`templates/loop/where.sh` counts only `spec §<key>` as a spec citation.**
  0.17.0 treated every bare `§<key>` as one, skipping only `FILE.md §N`. A
  step reading "values per runtime-reference §5" then matched spec heading
  `## 5. …`. The session got the wrong section, and the whole spec left
  `.read`, which is the one failure the fallback exists to prevent. The same
  defect was found by an independent review of the source project's port.
  `spec` must now start a word (`runtime-spec §1` is not a citation), and
  whitespace is collapsed first, so a citation that wraps across lines
  resolves instead of falling back.
- `planner.md` now tells the planner to cite as `spec §<key>`. `plan-reviewer.md`
  flags a step that follows a spec section without citing it (MEDIUM).
  `tests/loop-scripts.test.sh` adds foreign-citation and wrapped-citation
  cases (40 run, 0 failed).

## [0.19.0] - 2026-09-29

### Added (faster task open: fan out, ask once, batch the trivial)

Research done one area after another dominated a run; owner questions surfaced
one stalled step at a time; and a long plan paid the per-step close-out cost once
per step.

- **Parallel plan groups.** The planner tags independent steps
  `- [ ] N. [parallel: A] …` (disjoint files, no shared state, ≤ 4 per group).
  `where.sh` strips the tag from the title and reports `.parallel_group` and
  `.parallel_steps`; `PROMPT.md` §1/§3 and `AGENTS.md` §8a run a group as ONE
  increment: one subagent per step launched together (worktrees for anything
  beyond new files), `merge-gate.sh` on the merged tree, ONE batched reviewer
  pass that sees the group as one change, one LOG entry per step, and
  `step-done.sh --steps "N M …"` to tick the group. Research-heavy tasks open
  with a discovery group, one area per subagent, each writing its own page,
  then the decision records side by side.
- **Owner questions up front.** `PLAN.md` gains `## Questions for the owner`
  (`- Q1 — … · blocks: 4 · answer: pending | asked <date> | <answer>`); the
  planner collects every unknown only a human can resolve and marks dependent
  steps `(needs Q1)`. `where.sh` reports `.open_questions`,
  `.unasked_questions` and `.waiting_on`; the session asks all unasked ones in
  ONE batch, and a step waiting on an open one blocks instead of guessing.
- **Batch steps.** Trivial mechanical items one check proves are one step. The
  plan-reviewer flags both directions: oversized (unrelated checks) and
  undersized (a run of trivial steps sharing one check, MEDIUM), plus missing
  owner questions (HIGH) and parallel tags on host/secret/shared-state steps
  (CRITICAL).
- **`AGENTS.md` §10 Throughput** (and a `SKILL.md` convention): wall time goes
  to round-trips, serial independent work and per-step ceremony — batch
  independent tool calls, fan out, ask once, script the ceremony, size models
  per role, `/fast` for the main session.
- **`merge-gate.sh` made generic:** `loop/` paths, the gate is
  `$MERGE_GATE_CMD` (default `make check`, was a project-specific target),
  project-specific wording removed.
- Tests: 9 more cases (group detection, title stripping, question states,
  `.waiting_on`, `--steps`, merge-gate green/conflict/main untouched) — 39 total.

## [0.18.0] - 2026-09-29

### Changed (review by risk, close by script)

Closing a step cost many model round-trips of ceremony, hours over a long plan.
Per-step reviews rarely found a CRITICAL and only a couple of HIGH each (mostly on
scripts, config and decision records), while every LOW became an amendment to
carry to the close.

- **New `templates/loop/step-done.sh`** (+ `make step-done MSG=… [PUSH=1]`)
  closes an increment in one command: runs the gate (red → exit 1, nothing
  changed), appends its tail to `LOG.md` between `gate:begin`/`gate:end`
  markers, ticks the first unchecked `PLAN.md` box, runs the prose budget and
  the staged-diff secret scan (`make staged-scan` when present, else a built-in
  scan for forbidden paths and key-shaped strings that never prints a value),
  commits with commit hooks running, and pushes only with `--push`. The gate
  evidence is now written by the script from the real exit code instead of
  retyped by the agent.
- **The verifier subagent is optional.** A deterministic gate needs no model;
  `verifier.md` is for checks that need judgment (a smoke run, thresholds).
- **Review is risk-tiered and pipelined** (`PROMPT.md` §4b, `AGENTS.md` §8,
  `RULES.md` Git). Risky steps — code with logic, scripts, infra config,
  host/env changes, decision records, anything near a golden rule — are
  reviewed before the commit. Low-risk steps are committed unpushed and
  reviewed in ONE batch over `@{u}..HEAD` when 3 wait, before a risky step, or
  at the wave/task end. Unpushed == unreviewed: `where.sh` reports the count as
  `.unreviewed` (-1 without an upstream → review every step). The reviewer
  starts in the background as soon as the gate is green, while the LOG entry is
  written; CRITICAL/HIGH are always fixed before the push.
- **Lean review ledger.** `reviewer.md` reports every CRITICAL/HIGH, at most 3
  MEDIUM and no LOW (a golden-rule finding is never LOW), answers INTENT per
  step in a batched pass, and judges the batch as one change.
- **`entry-size-guard.sh`** does not count the fixed-size gate block as prose.
- **`where.sh` and `step-done.sh` `--help`** work from any directory.
- Tests: `tests/loop-scripts.test.sh` gains 15 step-done cases (red gate leaves
  everything untouched, dry-run, staged files + LOG + PLAN in one commit, the
  gate block, the tick, `.unreviewed`, a key-shaped string and a staged `.env`
  refused, a refusing commit hook honoured, `--push`).

## [0.17.0] - 2026-09-29

### Changed (a lean resume read and a parallel gate)

In long interactive sessions rather than a loop, every resume read far more than
the step needed before any work began, and a sequential gate ran at least twice
per increment.

- **`templates/loop/where.sh` reads less.** Rules files that `CLAUDE.md`
  `@`-imports (directly or through another import) are reported in a new
  `.loaded` field and left out of `.read`; they were already in context and got
  read a second time. The active `LOG.md` leaves `.read` too. A new `--context`
  mode prints the step slice instead: the current step's full text (all its
  continuation lines), the newest two LOG entries (capped at 80 lines, headings
  in comments and code fences skipped), and only the governing-spec sections
  the step cites with `§<key>` (a heading's leading number or its text before
  ` — `; `§1` never matches `§10`; `FILE.md §6` cites another document and is
  ignored). The spec leaves `.read` only when every citation resolves, so a
  miss costs a bigger read, never a missing one. JSON gains `loaded`,
  `spec_sections` and `context_cmd`. The resume read shrinks to a fraction.
- **`where.sh` step position** is now the ordinal of the first unchecked box,
  not "checked + 1", which went wrong once a later box was ticked out of order.
- **`templates/Makefile.sample` runs the gate in parallel.** `check` calls
  `$(MAKE) --jobs=$(CHECK_JOBS) --output-sync=target check-gates`, then prints
  the green line. Any failing gate still fails `check`; the output stays grouped
  per gate. Needs GNU make ≥ 4.0.
- **`entry-size-guard.sh` finds the active LOG from the task folder** (`where.sh
  --json`), no longer from `--read`, since `LOG.md` left the read list.
- **Resume ritual updated** to match: `PROMPT.md` §1, `AGENTS.md` §3a,
  `/loop-step`, `/status`, `loop/README.md`, `reference/ratchets.md`.
- **New `tests/loop-scripts.test.sh`** (outside `templates/`, so never
  installed): builds a throwaway fixture repo and checks the read contract,
  section resolution and `--context` output.

## [0.16.0] - 2026-09-29

### Changed (graders sized to their job)

Tuned from a real project's agent set, where every subagent call re-read about
24 KB of rules it already had.

- **`templates/agents/verifier.md` now runs on `haiku`** (was `sonnet`). The
  verifier only runs the gate and reports the exit code and output, so it makes
  no judgment call that needs a stronger model. A new rule keeps the cheaper
  model honest: `VERDICT` follows the exit code, so any non-zero `EXIT` is
  `FAIL`, and a threshold miss is `FAIL` even on `EXIT=0`. The judgment roles
  keep their models: `reviewer` and `planner` stay on `opus`, `plan-reviewer`
  and `adjudicator` stay on `fable`.
- **Graders stop re-reading loaded rules.** Subagents already get `CLAUDE.md`
  and every file it `@`-imports. `planner`, `reviewer` and `verifier` now skip
  rule files that `CLAUDE.md` already loads, and Mode 2 in `SKILL.md` now
  installs the rules with `CLAUDE.md` `@`-importing the rest. A probe on the
  source project confirmed it: a Haiku subagent quoted a `CLAUDE.md` golden
  rule and an `AGENTS.md` §6 bullet verbatim without reading either file.

## [0.15.0] - 2026-09-04

### Added (every grader reads what it grades)
Three orchestration gaps closed, all found by auditing a real loop rather than by
reading the templates.

- **`templates/agents/plan-reviewer.md`** (strongest reasoner) — audits a freshly
  written `PLAN.md` at a task's open, before step 1. The plan is immutable from the
  first checked box, and plan defects are the expensive kind because they are found
  by EXECUTING them: on the source project one plan was revised **16 -> 20 steps**
  mid-objective because a whole area was missing, and another grew a step into
  "part 1...part 8" because one step was really eight. Both cost several iterations;
  this pass costs part of one. `PROMPT.md` §1's `.needs_plan` branch dispatches it,
  and explicitly carves it out of §4b's both-graders rule — a plan has no diff and
  no gate, so one grader call is complete, not a violation.
- **`templates/agents/adjudicator.md`** (strongest reasoner, read-only) — rules
  whether a FAILING hard gate is itself wrong: `fits` / `re-scope` /
  `raise-with-basis` / `blocked`. It is the only role with no stake in the increment
  continuing, which the driver has and the reviewer does not audit: the reviewer
  reads the diff, never the motive. `PROMPT.md`'s GATE_FAILED path now enumerates an
  action per ruling, because a ruling with no action path is a trap — `fits` means
  the gate really passes, so telling the driver to emit GATE_FAILED anyway would
  halt the loop on a green gate. `raise-with-basis` is actionable ONLY once its
  measured arithmetic is in a committed decision record in the same commit: a
  threshold never moves on a subagent's word, and this is not a route around
  "never weaken a check to go green".
- **`templates/loop/amendments-guard.sh`** + a `make amendments` target — counts how
  many deferred reviewer findings in a plan's `## Amendments` are still OPEN.
  `--all` walks closed tasks. Measured on the source project the first time the
  count existed: **m1-06 74 entries / 50 open · m1-07 46/26 · m1-08 44/34 ·
  m1-10 81/39 · m1-11 138/69 · m1-12 40/8**. Nobody had been dishonest; the
  mechanism simply had no reader, and its carry-forward file maintained the open
  list by hand.
- **`templates/loop/merge-gate.sh`** — merges N branches into a throwaway worktree
  off `main` and runs the gate ONCE on the merged tree. The prerequisite for
  parallel tasks, which the templates have always sanctioned and no project had
  used: two branches can be green alone and RED together, because LOC rows are
  global, coverage/testcount is one ratchet, and generated code is committed. Per
  branch verification proves nothing about the union.

### Changed
- **`templates/agents/reviewer.md`** now receives the active step's own acceptance
  text and answers `INTENT: satisfied | shortfall | creep` as the FIRST line of its
  report, and the output template carries that line (a literal reader omitted it
  otherwise). Without the step text the only judge of "did this increment do what
  step N said" is the agent that wrote it — the one place "the writer is never its
  own grader" stayed broken, and invisible, because a flawless diff against the
  wrong step returns green from both graders.
- **`rubric/rubric.md`** P5 gains the requirement and a cap: **P5 is capped at 3**
  when the reviewer gets the diff but not the step's acceptance criteria, when a
  plan is written by an agent and reviewed by nobody, or when a failing gate can be
  re-scoped by the same agent that wants to continue with no independent
  adjudication and no committed decision record.
- **`reference/ratchets.md`** gains §"Deferred findings — the ratchet that is
  usually a promise", including how NOT to detect discharge. The guard's first
  version grepped ids from the whole plan and matched them against 400 commit
  messages; its one field result, "16 of 16 discharged", was false at BOTH ends —
  the ids were cross-references to other objectives' amendments and the evidence
  was bare numbers inside unrelated strings (`.29.`, `=202`, `/35/`). Disposition is
  read from the amendment's own text instead, scoped to the section, across the
  three entry formats real projects use.
- **`templates/loop/README.md`** documents a watcher failure worth never repeating:
  **never `pgrep -f` a pattern that appears in your own command line.** A watcher
  written `while pgrep -f 'claude -p'; do sleep 20; done` matches itself, so the
  condition never goes false; the same shape makes `pkill -f 'loop.sh'` kill the
  shell running it. Watch a PID with `kill -0`, or match parentage with `pgrep -P`.
  Both were observed on a real run — the second one killed its own shell.

## [0.14.0] - 2026-08-22

### Added (`--stop-on-phase`)
`templates/loop/loop.sh` gains a flag that promotes `<<LOOP:PHASE_COMPLETE>>` from a
continue-marker to a hard terminal.

The default is unchanged and deliberate: PHASE_COMPLETE *continues*. The agent tags
the milestone, pushes the tag, advances the pointer and rolls into the next phase on
its own — that autonomous rollover is the point of the design (rules/AGENTS.md §4).
But "run until milestone N is done, then let me look" had no expression at all: the
only ways to get it were counting iterations and hoping the cap landed in the right
place, or watching for the tag from outside and killing the harness.

`--stop-on-phase` makes it one flag. The stop lands **after** the tag — the agent
tags, pushes and advances the pointer before emitting the marker, so the milestone is
complete and recorded, not half-done. The banner reports `stop-on-phase=0|1` so an
unattended run's log states which behaviour was in force.

Verified both dispatch paths in isolation: with the flag off, PHASE_COMPLETE
continues and DONE stops; with it on, both stop and CONTINUE still continues.

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

## [0.2.0] - 2026-07-04

### Added
- `assessment-report` — five new report types, each a `type.md` spec + a full synthetic,
  rendered-and-verified `example.html` on the shared blueprint design system:
  `security-review` (OWASP/CIS/NIST threat-centric posture), `cost-review` (FinOps,
  Savings×Effort), `due-diligence` (tech DD with a RAG verdict, Likelihood×Deal-impact),
  `architecture-review` (Well-Architected 6-pillar), and `post-incident` (blameless
  post-mortem: SEV, timeline, root-cause chain, action items).
- `CLAUDE.md` with repository guidance.

## [0.1.0] - 2026-07-03

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
- `assessment-report` skill — scored gap/risk assessment reports as branded PDFs, with a
  worked example under `report-types/gap-risk/` (rewritten from scratch in 1.0.0).
