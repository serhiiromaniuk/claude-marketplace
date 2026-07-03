# Scoring methodology

A blended, recognised approach: a 5×5 risk matrix (ISO 31000 style) for findings, a weighted posture grade per area (Well-Architected-style), plus residual risk and an explicit deferral stance. For dollarized risk, escalate to a FAIR model (see end).

## 1. Per-finding risk score
`Risk = Likelihood × Impact`, each 1–5 → **1–25**.
- Likelihood (1 rare → 5 near-certain): exploitability, exposure, frequency.
- Impact (1 trivial → 5 catastrophic): blast radius, recoverability, $ / reputation.

| Score | Severity |
|---|---|
| 20–25 | CRITICAL |
| 12–19 | HIGH |
| 6–11 | MEDIUM |
| 1–5 | LOW |

(Note: a Critical *can* sit at score 15 if Impact=5 even when Likelihood is moderate — severity is a judgement anchored by, not strictly derived from, the score. Keep it honest.)

## 2. Confidence flag (per finding)
- 🟢 **Verified** — observed live (API/SSH/console).
- 🟡 **Inferred** — from config/Terraform/docs, not live-confirmed.
- ⚪ **Assumed** — reasonable assumption, needs confirmation.
Show as a dot on the finding ID. Be honest — mixed confidence is more credible than false certainty.

## 3. Residual risk (per finding)
Estimate the score **after** the proposed fix and show `now → residual` (e.g. `16 →2`). Makes the value of the work explicit and is more persuasive than the current score alone.

## 4. Deferral stance (per finding)
Because assessed systems are usually live, give each finding an honest interim call:
- **Fix now** — security and/or cheap & high-value; don't wait.
- **Schedule** — real work, plan into a cycle.
- **Accept (interim)** — tolerable for now, *with eyes open*. List accepted items so acceptance is deliberate.

## 5. Per-area posture grade (0–100 → letter)
Score 5 dimensions, weight, sum. Default weights (rename/reweight per domain, keep 5 for the radar):

| Dimension | Weight |
|---|---|
| Security | 30% |
| Resilience / Availability | 25% |
| IaC / Maintainability | 20% |
| Observability | 15% |
| Cost-fit | 10% |

Composite across areas = weight by criticality (e.g. Prod 50% · CI 35% · Non-prod 15%).

| Band | Grade | Meaning |
|---|---|---|
| 85–100 | A | Strong |
| 70–84 | B | Good |
| 55–69 | C | Fair — needs work |
| 40–54 | D | Weak — at risk |
| <40 | F | Critical |

This is a **security-posture** scale, not academic — say so in the report so "C" isn't misread.

## 6. Prioritization
Plot findings on **Impact × Effort**. Top-left (high impact / low effort) = quick wins, do first. Use the same IDs in the matrix, the register, and the per-area tables so readers can cross-reference.

## When stakeholders want hard numbers
Swap the "illustrative annual cost" framing for a **FAIR** model: Loss Event Frequency × Loss Magnitude, with min/likely/max ranges. Keep rates as named variables the finance owner fills in. CVSS is for CVEs specifically; this 5×5 is for architectural/operational risk.
