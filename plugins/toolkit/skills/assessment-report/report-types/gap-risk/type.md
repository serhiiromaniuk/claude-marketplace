# Report type: gap-risk (general scored gap/risk assessment)

The general base type. Assesses a system / estate / project, organizes findings by **area** (e.g. infrastructure tenants, services, domains), scores each, and produces a costed remediation roadmap. The Acme Widgets infrastructure audit (`example.html`) is the canonical worked example.

## When to use
"gap/risk analysis", "audit X", "infrastructure/cloud review", "assess the state of Y", or any request that's *findings → scored → executive dashboard → PDF* and doesn't match a more specific type.

## Section order (page ≈ each)
1. **Cover** — title, scope chips, verdict box (composite grade + one-line so-what), meta.
2. **Contents** — clickable TOC.
3. **Executive Summary** — KPI strip, composite gauge + dimension bars, severity bars, **Impact×Effort matrix**, and three columns: *What we'd do / Impact if we don't / Effort & cost*.
4. **How to read** — scoring scale, grade band, confidence-flag legend, residual+stance explanation, radar axes. (Keep compact.)
5. **Architecture / context** — a diagram of the areas being assessed.
6. **Per-area sections** (one per tenant/area) — scorecard (grade + radar), inventory, strengths, effort, and a findings table (with confidence dots + L/I/score).
7. **(Optional) Cost & resilience** — real cost actuals + backup/DR (RPO/RTO) posture, when relevant.
8. **Consolidated Risk Register** — all findings ranked; `score → residual`; deferral stance.
9. **Impact & Business Case + Roadmap** — exposure→cost table (rates as variables) + Wave 1/2/3 plan.
10. **Appendix** — evidence samples, account/identifier reference, standards mapping (CIS/WAF/NIST), integrity statement.

## Scoring (see ../../reference/scoring.md)
- Per-finding: **Likelihood × Impact** (1–5 each) → 1–25 → severity band.
- Per-area: 0–100 across **Security 30 · Resilience 25 · IaC/Maintainability 20 · Observability 15 · Cost-fit 10** → letter grade. (Rename/reweight dimensions per domain; keep 5 for the radar.)
- Composite = areas weighted by criticality (e.g. Prod 50 · CI 35 · Non-prod 15).
- Each finding also gets: **confidence** (Verified/Inferred/Assumed), **residual** score after fix, and a **deferral stance** (Fix now / Schedule / Accept-interim).

## Data to gather (read-only; see ../../reference/discovery-playbook.md)
Inventory + posture of each area. For cloud: identity/keys, network exposure (open SGs/bastions), HA (multi-AZ, replicas, task counts), monitoring/alarms, backups (RPO/RTO), cost actuals, IaC state vs reality. For CI/hosts: tool versions/EOL, disk/RAM/swap, brute-force exposure, config drift. Capture evidence + confidence per finding.

## Framing rules
- Dual audience: dashboard first (stakeholders), detail later (engineers).
- Lead the register with the highest risk-reduction-per-hour items; call out 1–2 "do not wait" findings.
- Express impact as **asymmetry** (small effort + small run-cost vs. open-ended downside); leave money rates as variables.
- The **Accept (interim)** stance is legitimate when the system is live — list accepted items so the acceptance is *deliberate*, not accidental.
- Call out genuine **strengths** too — it builds trust and makes the criticism land.

## Reuse note
`example.html` is a synthetic sample report (fictional data) rendered with the canonical pipeline. Fastest path for a new gap-risk report: copy `example.html` (not the bare template) and replace content area-by-area — it already has the full section set wired up.
