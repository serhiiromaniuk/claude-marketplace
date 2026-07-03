# The stateful artifact: `.agent-readiness/`

Mode 1 writes its result **into the target repo** so a re-run can diff against the last one.
This is the "stateful" requirement: you see the grade **trend**, not just a snapshot.

## Layout (written into the target repo)
```
.agent-readiness/
├── score.json     # machine-readable state — the source of truth, diffable across runs
├── report.md      # the short-and-beautiful human scorecard
└── report.html    # optional, only when a branded render was requested
```
Add `.agent-readiness/report.html` to the target's `.gitignore` if it shouldn't be committed;
`score.json` and `report.md` are meant to be committed so the trend lives in git history.

## `score.json` schema
```json
{
  "schemaVersion": 1,
  "generatedAt": "<ISO-8601, passed in — never invented>",
  "tool": "agent-readiness",
  "repo": { "path": "<abs path>", "commit": "<short sha>", "branch": "<name>" },
  "overall": { "score": 0, "grade": "F|D|C|B|A", "adoptionLevel": "Absent|Ad-hoc|Partial|Solid|Exemplary" },
  "weightsProfile": "default",
  "pillars": [
    {
      "id": "P2",
      "name": "Filesystem-as-memory",
      "weight": 20,
      "level": 3,
      "percent": 75,
      "confidence": "Verified|Inferred|Assumed",
      "signalsFound": ["tasks/INDEX.md", "tasks/_template/"],
      "gaps": [
        { "summary": "no append-only LOG discipline stated", "severity": "MEDIUM",
          "stance": "Fix now|Schedule|Accept", "confidence": "Verified" }
      ]
    }
    // …one object per pillar P1..P7
  ],
  "previous": { "generatedAt": "…", "overall": { "score": 0, "grade": "F" } },
  "delta": { "overallScore": 0, "byPillar": { "P2": 0 } }
}
```

### Field rules
- **`generatedAt`** — the runtime has no clock; get the timestamp from a `date -u +%FT%TZ` call and pass it in. Never fabricate one.
- **`level`** ∈ 0..4 (from `../rubric/rubric.md`); **`percent`** = `level/4*100`; **`overall.score`** = weighted mean of pillar percents.
- **`signalsFound`** — the concrete evidence paths (mirror the scan playbook output).
- **`gaps[].stance`** — the routing key for Mode 2 (Fix now → apply; Schedule → task file; Accept → report only).

## The diff / trend model
On every run, **before** writing the new file:
1. Read the existing `.agent-readiness/score.json` if present.
2. Copy its `generatedAt` + `overall` into the new file's **`previous`**.
3. Compute **`delta.overallScore`** and **`delta.byPillar`** (new − previous).
4. In `report.md`, show the delta next to the grade: e.g. `Grade: B (72, ▲ +14 since 2026-06-01)` and per-pillar `▲ ▼ ─` arrows.

First run (no prior file): `previous` and `delta` are `null`; report says "baseline — no prior run".

## `report.md` shape (short and beautiful)
Keep it to roughly one screen:
```markdown
# Agent-readiness — <repo name>
**Grade: B — Solid (72 / 100)**  ·  ▲ +14 since <prev date>  ·  <commit> · <date>

> One-line so-what: <the headline judgement>.

| Pillar | Level | Grade | Δ | Top gap |
|---|---|---|---|---|
| Filesystem-as-memory | ●●●○ (3) | B | ▲ | append-only LOG rule not stated |
| … | | | | |

**Strengths:** …    **Do first:** <1–2 highest gain-per-hour pillars>.

<optional: a 7-axis radar if the branded HTML was rendered>

_Scan was read-only. No file created, modified, or run; no secrets read._
```
For the branded HTML/PDF, reuse the `assessment-report` engine (see the skill's SKILL.md,
"Optional branded render") — the 7 pillars are the radar axes, the composite is the gauge.
