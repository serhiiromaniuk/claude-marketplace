# Report type: due-diligence (technical / vendor due-diligence)

A deal-facing type. Assesses an acquisition or partnership **target's** technology, organized by **engineering domain**, scores each against the investment thesis, and produces a costed value-creation / remediation plan plus an overall **RAG investability verdict**. The Meridian Capital → Loomly Labs review (`example.html`) is the canonical worked example.

## When to use
"tech/vendor due-diligence", "diligence on a target we're acquiring", "review this company's engineering before we invest/partner", "is this codebase/team worth buying", or any request that's *target findings → scored against a deal thesis → investment recommendation → PDF*. If the request is a general internal audit with no deal context, use `gap-risk` instead.

## Section order (page ≈ each)
1. **Cover** — title, deal-scope chips (target · acquirer · scope), **RAG investability verdict** box (Red / Amber / Green + composite grade + one-line so-what), meta.
2. **Contents** — clickable TOC.
3. **Executive Summary** — deal-context KPIs (ARR, headcount, stage, margins), composite gauge + dimension bars, RAG summary, **top deal risks + upside**, and a **Risk × Deal-impact matrix**.
4. **How to read** — RAG scale, diligence-maturity posture bands, confidence-flag legend, residual+stance explanation, radar axes, and a **"materiality to the deal"** note.
5. **Company & technology overview** — a diagram of the target's architecture / stack, plus **team shape** (headcount by function, key-person concentration).
6. **Per-domain sections** (one per page, 6 domains) — scorecard (grade + radar), inventory, strengths, effort, and a findings table (confidence dots + L/Deal-impact/score). The six domains:
   1. **Architecture & Scalability**
   2. **Code Quality & Technical Debt**
   3. **Security & Compliance**
   4. **Data & IP**
   5. **Engineering Team & Process**
   6. **Operations, Reliability & Cost**
7. **Consolidated Risk Register** — all deal risks ranked; `score → residual`; **deal-impact stance** (deal-breaker / price-chip / post-close fix).
8. **Value-creation plan & remediation roadmap** — **Day-1 / First-100-days / Year-1** waves with the **cost of remediation** per wave, plus the recommended price adjustment.
9. **Appendix** — data-room / evidence references, standards mapping (SOC 2 / ISO 27001 / OSS-license), and the read-only + synthetic-data integrity statement.

## Scoring (see ../../reference/scoring.md)
- Per-finding: **Likelihood × Deal-impact** (1–5 each) → 1–25 → severity band. Deal-impact reads blast radius *to the deal*: value erosion, integration cost, closing risk — not just operational blast radius.
- Per-domain: 0–100 across **Scalability 25 · Maintainability 25 · Security/Compliance 20 · Team & Process 20 · Cost/Ops 10** → letter grade on a **diligence-maturity** scale (A Strong → F Critical; "C" = fair, needs work). Keep 5 dimensions for the radar (axes S / M / C / T / O).
- **Composite = domains weighted by materiality to the investment thesis** (e.g. Architecture 25 · Debt 20 · Security 15 · Data&IP 15 · Team 15 · Ops 10 — reweight to the thesis).
- **Overall RAG verdict** on the cover: **Green** (proceed) · **Amber** (proceed with conditions) · **Red** (do not proceed / renegotiate). Anchor it on the composite plus the count of deal-breakers.
- Each finding also gets: **confidence** (Verified/Inferred/Assumed), **residual** score after remediation, and a **deal-impact stance**:
  - **Deal-breaker** — must be resolved or contractually conditioned before close.
  - **Price-chip** — quantifiable value erosion; negotiate the price or a retention/escrow.
  - **Post-close fix** — real work, absorb into the value-creation plan after close.

## Data to gather (read-only; see ../../reference/discovery-playbook.md)
Diligence is **read-only against a data room + management interviews** — you do not touch the target's production. Gather: architecture & scaling limits (monolith vs. services, tenancy model, throughput ceilings); code health (test coverage, static analysis, dependency/EOL risk, legacy modules); security posture (SOC 2 / ISO status, secrets handling, pen-test recency, MFA/SSO); data & IP (OSS license exposure — GPL/AGPL/copyleft, contributor IP assignment, GDPR/DPA, PII handling); team (org shape, **bus-factor / key-person** concentration, process maturity, hiring pipeline); operations (regions, DR/BCP runbooks & tested restores, observability/SLOs, cloud cost trend & efficiency). Record evidence source (data-room doc, code sample, interview) + a confidence flag per finding.

## Framing rules
- Deal audience: dashboard + RAG verdict first (deal team / IC), domain detail next (integration engineers), bridged by the register and the value-creation plan.
- Lead with the **deal-breakers** and the **price-chips** — the findings that move the price or the terms — before the post-close backlog.
- Express remediation as **cost-of-fix vs. value-at-risk asymmetry**; leave money as **named variables with concrete synthetic estimates** (Day-1 / 100-day / Year-1 budgets, recommended price adjustment).
- Be explicit about **materiality to the thesis** — a scary-looking finding that doesn't threaten the deal thesis is not a deal-breaker; say so.
- Call out genuine **strengths** and upside too — diligence that only lists risk is not credible and gives the deal team nothing to underwrite.
- The **post-close fix** stance is legitimate — list absorbed items so the value-creation plan is deliberate, not a surprise after close.

## Reuse note
`example.html` is a synthetic sample report (fictional target, acquirer, findings and costs) rendered with the canonical pipeline. Fastest path for a new due-diligence report: copy `example.html` (not the bare template) and replace content domain-by-domain — it already has the full section set (RAG cover, 6 domain pages, deal-impact register, Day-1/100-day/Year-1 plan) wired up.
