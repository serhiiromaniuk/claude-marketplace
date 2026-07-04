# Report type: cost-review (cloud spend / FinOps optimization review)

A FinOps-flavoured cost review of a cloud estate. Takes cost actuals (Cost Explorer / CUR), organizes savings by **optimization lever** (commitments, rightsizing, waste, storage & data-transfer, tagging/allocation), scores each lever's cost-maturity, ranks every opportunity by **savings vs. effort**, and produces a phased savings roadmap and business case. The Fjord Analytics AWS review (`example.html`) is the canonical worked example.

## When to use
"cost review", "FinOps assessment", "cloud spend audit", "where is our AWS/GCP/Azure bill going", "how do we cut cloud cost", "Savings Plan / RI coverage review", "rightsizing / waste analysis", or any request that's *cost actuals → savings opportunities → scored → executive dashboard → PDF*. If the ask is a broad posture audit (security, resilience, cost together), use **gap-risk** instead; use this type when **money is the primary lens**.

## Section order (page ≈ each)
1. **Cover** — title, scope chips (provider · run-rate · levers), verdict box (cost-maturity grade + one-line so-what: $/yr recoverable), meta.
2. **Contents** — clickable TOC.
3. **Executive Summary** — spend KPIs (current run-rate, identified annual savings, % waste), **savings gauge** (composite cost-maturity 0–100 + 5 FinOps dimension bars), a savings-by-lever bar, the **Savings × Effort matrix** (the showpiece), and three columns: *What we'd capture / Cost if we don't / Effort & risk*.
4. **How to read** — savings-opportunity scale (Savings × Effort), effort-ease legend, confidence flag, cost-maturity grade band, radar axes. (Keep compact.)
5. **Spend landscape** — where the money goes: breakdown **by service** and **by account/environment**, with a bar/stacked SVG; call out the concentration and the untagged share.
6. **Per-lever sections** (one page each), each with a cost-maturity scorecard (grade + radar), what's driving spend, what's already good, effort, and an opportunity table (confidence dots + Savings/Effort/score + monthly $):
   - **Commitment coverage** — Savings Plans / Reserved Instances vs. on-demand baseline.
   - **Rightsizing** — over-provisioned compute (EC2/ECS) and databases (RDS/analytics).
   - **Waste elimination** — idle/orphaned/unattached resources; off-hours scheduling.
   - **Storage & data-transfer** — gp2→gp3, S3 lifecycle, cross-AZ traffic, NAT egress.
   - **Tagging & cost allocation / accountability** — untagged spend, showback/chargeback, budgets & anomaly detection.
7. **Consolidated Savings Register** — all opportunities ranked by savings-per-effort; monthly **→** annualized savings; implementation-risk stance.
8. **Savings Roadmap & business case** — exposure→cost table (rates as variables) + Wave 1 quick wins / Wave 2 / Wave 3.
9. **Appendix** — Cost Explorer / CUR evidence samples, account reference, **FinOps Framework capability mapping**, and the read-only + synthetic-data integrity statement.

## Scoring (see ../../reference/scoring.md)
- Per-opportunity: **Savings impact × Effort** (1–5 each) → 1–25. Savings 1 (trivial $) → 5 (major $). **Effort is scored as ease**: 1 (major project) → 5 (few hours, in-place). So **high savings + low effort ⇒ top score ⇒ do first** — the top-left of the matrix. Relabel the matrix axes **Savings** (vertical) × **Effort** (horizontal, low→high); bubble size/colour = savings tier (MAJOR / LARGE / MED / SMALL), not risk severity.
- Per-lever: 0–100 across 5 FinOps dimensions → **cost-maturity** letter grade: **Commitment coverage 25 · Rightsizing 25 · Waste 20 · Allocation/Tagging 15 · Architecture cost-fit 15**. Radar axes: C (Commitment) · R (Rightsizing) · W (Waste) · A (Allocation) · X (Architecture cost-fit).
- Composite = levers weighted by the **spend share each governs**.
- Grade bands are reused (unchanged colours) but **relabelled as cost-maturity, not academic**: A Optimized · B Proactive · C Developing · D Reactive · F Ad-hoc. Say so, so "C" isn't misread.
- Each opportunity also gets: **confidence** (Verified from CUR/Cost Explorer / Inferred from utilization / Assumed), monthly **→** annualized $ savings, and an **implementation-risk stance** (Capture now / Schedule / Validate first).

## Data to gather (read-only; see ../../reference/discovery-playbook.md)
Cost actuals first: `ce get-cost-and-usage` grouped by SERVICE, LINKED_ACCOUNT, and tag keys; `ce get-savings-plans-utilization` / `-coverage`; `ce get-reservation-coverage`. Utilization for rightsizing: CloudWatch CPU/memory/connections/IOPS over 14–30 days, `compute-optimizer get-*-recommendations`. Waste: unattached EBS (`describe-volumes` state=available), old/orphaned snapshots, idle ELBs, unassociated EIPs, stopped-but-billed resources, dev/staging running 24/7. Storage: gp2 volumes, S3 storage-class distribution & lifecycle rules, cross-AZ data-transfer and NAT egress lines. Allocation: % of spend without a cost-allocation tag, presence of budgets/anomaly detection, showback. Capture the CUR/Cost-Explorer evidence + a confidence flag per opportunity. **Never mutate** anything during discovery — cost review is read-only.

## Framing rules
- Dual audience: dashboard first (finance / budget-holders), lever detail later (engineers / platform).
- Lead the register with the highest **savings-per-effort** items; call out 1–2 "capture this week" quick wins (commitments + off-hours scheduling are usually the biggest, safest).
- Express savings as **monthly and annualized** and as a **% of run-rate** — annualizing makes small monthly lines land. Keep unit rates / blended discounts as named variables where a real number is needed.
- Distinguish **commitment savings** (a purchase — reversible-ish, low technical risk) from **rightsizing/architecture savings** (needs testing, a change window, real risk). Say which is which; a cheap headline that breaks prod is not a win.
- **Tagging is an enabler, not a line item** — most of its value is unlocking accountability and future savings, so score it but don't over-claim direct $.
- Call out genuine **maturity strengths** too (existing commitments, gp3 adoption, encryption) — it builds trust and makes the criticism land.

## Reuse note
`example.html` is a synthetic sample report (fictional company "Fjord Analytics", fictional bill and figures) rendered with the canonical pipeline. Fastest path for a new cost-review: copy `example.html` (not the bare template) and replace content lever-by-lever — it already has the full section set, the Savings × Effort matrix, the per-lever radars, and the savings register wired up.
