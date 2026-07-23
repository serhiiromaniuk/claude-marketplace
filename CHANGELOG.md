# Changelog

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
