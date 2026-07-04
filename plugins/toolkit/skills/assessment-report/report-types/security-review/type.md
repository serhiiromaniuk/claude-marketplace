# Report type: security-review (threat-centric security posture review)

A threat-centric security posture review driven by **OWASP Top 10 · CIS Benchmarks · NIST CSF**. Organizes findings by **security domain** (Identity, Network, Data, AppSec, Detection & Response), scores each, plots them on a **Likelihood × Impact** matrix, and produces a costed remediation roadmap that leads with the exposures an attacker reaches first. The Northwind Retail review (`example.html`) is the canonical worked example.

## When to use
"security review", "security posture assessment", "OWASP/CIS review", "threat model this system", "are we exposed?", "pen-test-adjacent posture check", or any request that's *threats → scored by severity → executive risk dashboard → PDF* and is framed around attackers, controls, and exposure rather than general engineering gaps. If the request is a broad system/estate audit that isn't specifically threat-centric, use `gap-risk` instead.

## Section order (page ≈ each)
1. **Cover** — title, scope chips (attack surface in scope), verdict box (composite posture grade + one-line so-what), meta.
2. **Contents** — clickable TOC.
3. **Executive Summary** — posture verdict, KPI strip, composite gauge + dimension bars, **severity bars**, and the **Likelihood × Impact matrix** (the showpiece), plus three columns: *What we'd do / Impact if we don't / Effort & cost*.
4. **How to read** — L×I risk scale + severity bands, posture grade band, a **CVSS-vs-L×I note** (CVSS scores CVEs; the 5×5 scores posture risk), confidence-flag legend, residual+stance explanation, radar axes. (Keep compact.)
5. **Threat model & attack surface** — a diagram of **trust boundaries and entry points** (internet edge → app/API → identity plane → data plane → internal), annotated with where each domain's findings sit.
6. **Per-domain sections** (one per page) — scorecard (grade + radar), what was observed, strengths, effort, and a findings table (confidence dots + L/I/score). Five domains, in attacker-reach order:
   - **Identity & Access** (IAM, MFA, break-glass, key rotation, least privilege)
   - **Network & Perimeter** (edge exposure, WAF, security groups, egress filtering, segmentation)
   - **Data Protection & Secrets** (encryption, S3/bucket posture, secret storage, key management)
   - **Application Security (OWASP)** (OWASP Top 10 — injection, auth/session, access control, vulnerable dependencies/CVEs)
   - **Detection & Response** (logging/SIEM, alerting, IR readiness, log retention/integrity)
7. **Consolidated Risk Register** — all threats ranked by current risk; `score → residual` after fix; deferral stance. Threat-centric wording (each row is an attacker capability, not just a config gap).
8. **Remediation Roadmap & business case** — exposure→cost table (rates as variables) + Wave 1/2/3 plan, front-loaded with the exposures reachable from the internet edge.
9. **Appendix** — evidence samples, **OWASP Top 10 / CIS Benchmark / NIST CSF control mapping**, and a read-only + synthetic-data integrity statement.

## Scoring (see ../../reference/scoring.md)
- Per-finding: **Likelihood × Impact** (1–5 each) → 1–25 → severity band (20–25 Crit · 12–19 High · 6–11 Med · 1–5 Low). Likelihood weighs exploitability/exposure/attacker reach; Impact weighs blast radius/data sensitivity/recoverability. **CVSS is for CVEs specifically** — where a finding is a known CVE, cite the CVSS score in the finding text, but the register/matrix position uses this 5×5 posture risk so CVEs and misconfigurations rank on one scale.
- Per-domain: 0–100 across five security dimensions → letter grade. Weights: **Prevention 30 · Detection 20 · Identity 20 · Data Protection 20 · Response 10**. (Keep 5 axes for the radar: **P / D / I / T / R** — Prevention · Detection · Identity · daTa protection · Response.)
- Composite = domains weighted by **exposure** (attack-surface criticality), e.g. Internet-facing app/API 45 · Identity plane 30 · Internal/data plane 25.
- Each finding also gets: **confidence** (Verified/Inferred/Assumed), **residual** score after the proposed control, and a **deferral stance** (Fix now / Schedule / Accept-interim).

## Data to gather (read-only; see ../../reference/discovery-playbook.md)
Posture of each domain, mapped to threats. Identity: static keys/age, MFA coverage, break-glass accounts, over-broad policies (`*:*`), federation. Network: internet-open security groups (22/3389/DB ports), WAF presence + rules (rate-limiting), public IPs, egress filtering, segmentation. Data: S3/bucket public-access-block + encryption + versioning, secrets in env vars vs a secret manager, KMS usage, TLS posture. AppSec: OWASP Top 10 checks — injection, broken auth/session handling, broken access control, security misconfig, **vulnerable & outdated dependencies (with CVE IDs + CVSS)**. Detection & Response: centralized logging/SIEM, CloudTrail/flow logs, alert coverage, log retention & tamper-resistance, IR runbook/on-call. Capture evidence + a confidence flag per finding; **never read or print secrets/keys**.

## Framing rules
- Dual audience: executive risk dashboard first (budget-holders), domain detail later (security engineers).
- **Order by attacker reach.** Lead the register and roadmap with what an unauthenticated attacker touches first (internet edge, identity), then lateral movement, then blast radius. Call out 1–2 "do not wait" exposures where a single leaked credential or open port reaches production.
- Express impact as **asymmetry** (small effort + small run-cost vs. an open-ended breach/incident cost); leave money rates as variables — or escalate to a FAIR loss-event model if stakeholders want dollars.
- The **Accept (interim)** stance is legitimate for lower-severity items when the system is live — list accepted items so acceptance is *deliberate*, with a compensating control noted where one exists.
- Call out genuine **strengths** (WAF present, RDS encrypted, buckets locked down) — it builds trust and makes the criticism land, and it stops readers over-rotating on a single alarming finding.
- Keep the **"security-posture scale, not academic"** note visible so "C" isn't misread as a school grade.

## Reuse note
`example.html` is a synthetic sample report (fully fictional data — no real company, IP, key, or CVE-in-context) rendered with the canonical pipeline. Fastest path for a new security-review: copy `example.html` (not the bare template) and replace content domain-by-domain — it already has the full section set, the L×I matrix, five domain scorecards, and the OWASP/CIS/NIST mapping wired up.
