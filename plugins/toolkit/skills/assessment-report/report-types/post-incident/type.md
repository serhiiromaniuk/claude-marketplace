# Report type: post-incident (blameless post-incident review / post-mortem)

A blameless post-incident review of a single production incident. Reconstructs **what happened** on a timeline, separates the **trigger** from the **root cause**, scores **contributing factors** and **prevention action items**, and produces an owned action-item roadmap. The Cartwright "Checkout API outage — Aurora failover storm" (`example.html`) is the canonical worked example. Emphasis is **timeline + causes + actions**, not per-area letter grades — and the wording is **strictly blameless** throughout: describe systems, signals, and decisions-with-context, never individuals at fault.

## When to use
"post-incident review", "post-mortem", "write up the outage / the SEV1", "root-cause analysis", "what happened and how do we stop it happening again", or any request shaped as *incident → timeline → root cause → contributing factors → action items → PDF*. If the request is a forward-looking gap/risk audit rather than a retrospective on a specific event, use `gap-risk` instead.

## Section order (page ≈ each)
1. **Cover** — incident title, **SEV level** in the verdict box (not a grade) + one-line impact, key durations as statstrip (detection time · MTTM · total duration · % customers affected), meta.
2. **Contents** — clickable TOC.
3. **Executive Summary** — incident-KPI strip (detection time / time-to-mitigate / total duration / customers affected / error-budget burn); a one-paragraph *what happened & so-what*; **contributing-factor severity as bars**; **Impact×Effort matrix of action items** (which prevention work to do first); optional response-readiness gauge.
4. **How to read** — SEV scale (SEV1 critical … SEV4 minor), a **blameless-principles** note, contributing-factor severity scale, action-item priority = **Likelihood(recurrence) × Impact**, confidence legend, response-readiness radar axes.
5. **Incident Timeline** — a vertical, time-ordered table (time · event · actor/system) walking detection → escalation → mitigation → recovery; call out **MTTA / MTTM / MTTR** explicitly.
6. **Impact Analysis** — customer / SLA / financial / reputation impact + a small **blast-radius diagram** (what degraded, what held).
7. **Root Cause Analysis** — a **causal chain / 5-whys** diagram (inline SVG, boxes + arrows) plus narrative that separates **trigger** from **root cause**.
8. **Contributing Factors** — grouped **technical / process / organizational**, each scored with a severity band.
9. **What Went Well / What Went Poorly** — two columns; keep the "well" honest and specific (it builds trust and is blameless-positive).
10. **Action Items & Prevention Roadmap** — a table (ID · owner *(role)* · priority · due-window · status), grouped **Now / Next / Later**.
11. **Appendix** — evidence (log / metric / alert samples), comms/timeline log, and the **integrity + synthetic-data + blameless statement**.

## Scoring (see ../../reference/scoring.md)
- **SEV classification** on the cover (severity of the *incident itself*): SEV1 critical (major customer-facing outage / data loss) · SEV2 high · SEV3 moderate · SEV4 minor. This replaces the composite letter grade — a post-mortem grades the *event and the response*, not per-area posture.
- Per-action-item **Likelihood(recurrence) × Impact** (1–5 each → 1–25 → severity band) to prioritise prevention work. Same 5×5 matrix as `scoring.md`; here Likelihood = "how likely is a recurrence if we do nothing," Impact = "how bad if it recurs."
- Per-contributing-factor a **severity band** (Critical/High/Medium/Low) — how much it amplified or prolonged the incident.
- Optional **response-readiness scorecard** — 5 dimensions **Detection · Response · Mitigation · Communication · Prevention**, each 0–100 → composite → grade band, shown on the **radar**. This grades *how well the response went*, not the systems' posture. Use it, and only it, for any 0–100/grade number; do **not** attach per-area letter grades elsewhere.
- Each action item / finding still carries a **confidence** flag (Verified / Inferred / Assumed) on its ID.

## Data to gather (read-only; see ../../reference/discovery-playbook.md)
Reconstruct the incident from artefacts, never by assigning blame: the **alert/monitoring timeline** (when the first signal fired vs. when a human engaged — MTTA), **deploy/change log** (what changed just before), **metrics** (error rate, latency, saturation, connection-pool/thread counts, DB failover events), **logs** (error signatures, retry storms), the **incident channel / comms log** (decisions and their timing), the **runbook** actually used (and whether it was current), and **SLO/error-budget** state. Capture each fact with evidence + a confidence flag. Compute the durations: **MTTA** (detect→ack), **MTTM** (detect→mitigate), **MTTR** (detect→full recovery). Read-only: don't mutate systems while reconstructing.

## Framing rules
- **Blameless, always.** Attribute events to systems, signals, defaults, and decisions-made-with-the-information-available — never to a named person or "human error." Use **roles** (e.g. "Payments on-call lead", "SRE", "DB team"), not names. A missing circuit breaker or a stale runbook is a *system* gap, not a person's fault.
- **Trigger ≠ root cause.** State the triggering event plainly, then trace to the underlying systemic cause. The fix targets the root cause and the amplifiers, not the trigger.
- Dual audience: incident KPIs + response-readiness + action matrix first (leadership); timeline, RCA, and contributing factors next (engineers); action roadmap bridges them.
- Lead the action roadmap with the highest recurrence-risk-reduction items; call out 1–2 "do not wait" preventions.
- Keep **What Went Well** genuine and specific — a blameless review celebrates the parts of the response that worked as designed.
- Express prevention value as **asymmetry** (a small guardrail — circuit breaker, alert tuning, runbook refresh — vs. the open-ended cost of a repeat outage).

## Reuse note
`example.html` is a synthetic sample report (fictional company, fictional incident, roles not names) rendered with the canonical pipeline. Fastest path for a new post-incident report: copy `gap-risk/example.html` (it has the full design-system chrome wired up) and replace content section-by-section per the order above — the risk-register table becomes the **action-items table**, add a **timeline table** (reuse the table classes) and a **causal-chain** inline-SVG diagram, and repoint the radar to the response-readiness scorecard. Keep every visual component and all styling unchanged.
