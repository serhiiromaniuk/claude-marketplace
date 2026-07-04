# Report type: architecture-review (Well-Architected-style design review)

A structured design review of a **single system or workload** against the six
**AWS Well-Architected Framework (WAF) pillars**. Findings are the WAF
High/Medium/Low **Risk Items (HRIs)**; each pillar is scored 0–100 → letter
grade; the six pillars roll up to a composite posture. The Beacon IoT telemetry
platform review (`example.html`) is the canonical worked example.

## When to use
"Well-Architected review", "architecture review of X", "design review", "is this
system well-architected", "review our AWS workload against the pillars", or any
request shaped as *one system → assessed pillar-by-pillar → scored → executive
dashboard → PDF*. For a multi-tenant estate audit organised by area rather than
by pillar, use **gap-risk** instead.

## Section order (page ≈ each)
1. **Cover** — title, scope chips, verdict box (composite grade + one-line design verdict), meta.
2. **Contents** — clickable TOC.
3. **Executive Summary** — KPI strip, composite gauge + **six per-pillar bars**, **HRI severity bars**, **Impact×Effort matrix**, and three columns: *What we'd do / Impact if we don't / Effort & cost*.
4. **How to read** — risk-item scoring scale, grade bands, confidence-flag legend, residual+stance explanation, pillar radar axes. (Keep compact.)
5. **System context & architecture** — a real diagram of the system under review: components, data flow, trust/account boundaries.
6. **Operational Excellence** — pillar scorecard (grade + radar of 5 sub-questions), current-state notes, strengths, and an HRI table (confidence dot + L/I/score + residual + stance).
7. **Security** — same shape.
8. **Reliability** — same shape.
9. **Performance Efficiency** — same shape.
10. **Cost Optimization** — same shape.
11. **Sustainability** — same shape.
12. **Consolidated Risk Register** — all HRIs ranked; `score → residual`; deferral stance.
13. **Improvement Roadmap & Business Case** — exposure→cost table (rates as variables) + Wave 1/2/3 plan mapped to pillars.
14. **Appendix** — evidence samples, WAF pillar/question mapping, read-only + synthetic-data integrity statement.

## Scoring (see ../../reference/scoring.md)
- Per-finding (HRI): **Likelihood × Impact** (1–5 each) → 1–25 → severity band. WAF labels these **High / Medium / Low Risk Items** — map directly onto the band (Critical/High → HRI, Medium → MRI, Low → LRI; keep the same colour scale).
- Per-pillar: 0–100 across **5 sub-dimensions you choose per pillar** (keep 5 for the radar) → letter grade. Suggested sub-dimensions per pillar (rename to the workload):
  - **Operational Excellence** — Runbooks · IaC coverage · Observability · Deployment · Incident response.
  - **Security** — Identity/IAM · Detection · Infra protection · Data protection · Incident response.
  - **Reliability** — Foundations/limits · Fault isolation · Recovery/backup · Change mgmt · Scaling.
  - **Performance Efficiency** — Compute · Data/storage · Caching · Monitoring · Tradeoffs.
  - **Cost Optimization** — Pricing/commitment · Rightsizing · Usage awareness · Data cost · Decommission.
  - **Sustainability** — Compute efficiency · Data patterns · Non-prod scheduling · Region choice · Rightsizing.
- Composite = the **6 pillars, default equal weight (≈16.7% each)**. Note in the report that pillars can be **reweighted to the workload's priorities** (e.g. a regulated system may lift Security & Reliability, a batch pipeline may lift Cost).
- Each finding also gets: **confidence** (Verified/Inferred/Assumed), **residual** score after fix, and a **deferral stance** (Fix now / Schedule / Accept-interim).

## Data to gather (read-only; see ../../reference/discovery-playbook.md)
Inventory + posture of the one workload, organised by pillar. Per pillar, probe:
- **OpsEx** — runbooks/on-call, IaC coverage vs. click-ops, deploy pipeline, tracing/metrics/logs, incident process.
- **Security** — IAM roles/policies (wildcards, least-priv), WAF/edge protection, encryption at rest/in transit, auth (MFA, token scope), detection (GuardDuty/CloudTrail/alarms).
- **Reliability** — multi-AZ/multi-region, service quotas & throttling/backpressure, backups (RPO/RTO), failure/chaos testing, auto-scaling.
- **Performance** — cold-starts/provisioned concurrency, DB capacity mode & throttles, caching/CDN, right-sized compute, load characteristics.
- **Cost** — Savings Plans/RI coverage, rightsizing (utilisation vs. provisioned), cost allocation tags, data lifecycle, idle/decommission.
- **Sustainability** — non-prod scheduling, data retention/tiering, region carbon, managed-service efficiency.
Capture evidence + a confidence flag per finding.

## Framing rules
- Dual audience: dashboard first (stakeholders), pillar detail later (architects/engineers).
- Lead the register with the highest risk-reduction-per-hour HRIs; call out 1–2 "do not wait" items.
- Express impact as **asymmetry** (small effort + small run-cost vs. open-ended downside); leave money rates as variables. Where a pillar is Cost, real savings can be named as a range.
- The **Accept (interim)** stance is legitimate when the system is live — list accepted items so acceptance is *deliberate*, not accidental.
- Call out genuine **strengths** per pillar too — a Well-Architected review is a balance sheet, not a defect list; strengths make the criticism land.
- State the grade is a **posture** scale ("C" = fair), not academic, and that pillar weighting is a business choice.

## Reuse note
`example.html` is a synthetic sample report (fictional workload "Beacon") rendered
with the canonical pipeline. Fastest path for a new architecture-review: copy
`example.html` (not the bare template) and replace content pillar-by-pillar — it
already has the full section set (cover, exec dashboard, 6 pillar pages, register,
roadmap, appendix) wired up, including the six-bar composite and per-pillar radars.
