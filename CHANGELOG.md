# Changelog

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
