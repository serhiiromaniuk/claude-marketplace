# Report types

A **report type** defines the *shape* of one kind of report — its section list, what data to gather, how to score it, and the audience framing. The engine (design system in `assets/`, scoring in `reference/`, the renderer) is shared across all types, so adding a new type is cheap: drop in a new folder, no engine changes.

## How a type is structured
```
report-types/<type>/
├── type.md       # spec: when to use, sections in order, scoring scheme, data to gather, example
└── example.html  # (optional but recommended) a full real report of this type, for reference
```

## How Claude picks a type
1. Match the user's request against the registry below.
2. Load that type's `type.md` and follow its section list.
3. If nothing fits, use **gap-risk** (the general base) and adapt — then consider promoting the adaptation into a new type.

## Registry

| Type | Status | Use when |
|---|---|---|
| **gap-risk** | ✅ available | General scored gap/risk assessment of a system, estate, or project. Tenants/areas → findings → grades → roadmap. (e.g. infra/cloud audit.) |
| **security-review** | ✅ available | OWASP/CIS/NIST-CSF threat-centric security posture review; findings by attack-surface domain (Identity, Network, Data, AppSec, Detection & Response). |
| **cost-review** | ✅ available | Cloud spend/FinOps: cost actuals, waste, commitment coverage, rightsizing. Opportunities scored Savings×Effort. |
| **due-diligence** | ✅ available | Tech/vendor due-diligence for acquisitions or partnerships. Overall RAG verdict; findings scored Likelihood×Deal-impact. |
| **architecture-review** | ✅ available | Well-Architected-style design review of a single system, across the 6 WAF pillars. |
| **post-incident** | ✅ available | Blameless post-mortem: SEV, timeline, root-cause chain, contributing factors, action items. |

To add a type: copy `gap-risk/type.md` as a starting point, adjust the section list and scoring, register it in the table above, and (ideally) drop a real `example.html` once you've produced one.
