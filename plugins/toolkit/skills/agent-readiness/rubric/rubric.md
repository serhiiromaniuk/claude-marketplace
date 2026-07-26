# Agent-readiness rubric (the scored shape)

This is to `agent-readiness` what a `report-types/<type>/type.md` is to `assessment-report`:
it defines the **areas**, the **scoring scheme**, and **what to gather**. The engine
(scoring vocabulary, the optional renderer) is reused from the `assessment-report` skill —
this file only defines the shape.

The subject is a **software repository**. The question is: *how well is this repo adopted
for autonomous / long-running agentic work (Claude Code, agents, unattended loops)?*

## The 7 pillars (the "areas")

Each pillar is scored on a **maturity level 0–4** and carries a **weight**. The pillars
are distilled from a reference implementation of an agent-operable repo (see `../templates/`,
which is also what Mode 2 installs).

| # | Pillar | Weight | What it measures |
|---|---|---|---|
| P1 | **Rules & context** | 15 | Machine-readable rules an agent loads before acting: never-violate invariants, architecture boundaries, a supremacy clause, a self-onboarding worked example. |
| P2 | **Filesystem-as-memory** | 20 | Progress lives on disk, not in the context window: a task ledger with a contract/plan/append-only-log/closure per unit of work, an index, a template. |
| P3 | **Long-running loop** | 20 | An invariant re-fed prompt, a bounded harness (iteration cap), a completion-marker protocol, a "you-are-here" state pointer, one-verified-increment discipline, and a **bounded** control plane (position computed, not narrated; a prose budget on what each iteration appends). |
| P4 | **Verification gates** | 18 | A single sanctioned entrypoint (e.g. `make check`); every step names a check; hard thresholds that must never be self-lowered; a gate-failed path; and a path for a *falsified* threshold, so a wrong gate escalates instead of deadlocking the loop. |
| P5 | **Role-specialized subagents** | 10 | Defined agent roles (planner / reviewer / verifier / researcher), tool- and model-scoped; separation of plan → implement → verify → adversarial review. |
| P6 | **Autonomy boundaries** | 10 | Human-only actions enumerated (secrets, prod deploys, destructive infra, irreversible external actions); the loop halts and hands back at them. |
| P7 | **Change hygiene** | 7 | Conventional commits + scope, staged-diff secret/forbidden-path scan, clean-tree discipline, milestone tagging tied to gates, artifact/secret `.gitignore`. |

Total weight = 100. **Reweight per context** (e.g. a library with no unattended loop can down-weight
P3/P6) — but keep all 7 so the radar always has 7 axes. If you reweight, say so in the report.

## Maturity levels (0–4) — generic anchors

| Level | Label | Meaning |
|---|---|---|
| 0 | **Absent** | No trace of this pillar. |
| 1 | **Ad-hoc** | Present only informally / implicitly (human-oriented, not agent-consumable). |
| 2 | **Partial** | Exists but thin or not wired into the workflow. |
| 3 | **Solid** | Deliberate, explicit, and used. |
| 4 | **Exemplary** | Solid **and** self-reinforcing — referenced by the loop/agents, crash-safe, hard to violate by accident. |

### Per-pillar level anchors

**P1 Rules & context** — 0 none · 1 human-only README, implicit conventions · 2 a `CLAUDE.md`/`AGENTS.md` exists but no explicit invariants or boundaries · 3 layered rules with explicit never-violate invariants + architecture boundaries · 4 + a supremacy/override clause and a worked self-onboarding example, and the loop/agents actually cite the rules.

**P2 Filesystem-as-memory** — 0 progress only in chat/context · 1 an ad-hoc `TODO.md` · 2 some on-disk task notes, no template/ledger/append-only discipline · 3 structured task folders (contract + plan + log) + an index · 4 + a `_template`, append-only log rule, immutable-plan discipline, closure records — survives a crash / `/clear`.

**P3 Long-running loop** — 0 none · 1 informal "keep going" prompting · 2 a reusable prompt but no bounded harness or marker protocol · 3 invariant prompt + bounded harness (iteration cap) + completion markers · 4 + one-verified-increment discipline, autonomous phase-rollover within bounds, **and a bounded control plane**: position is *computed* by a script the iteration runs first (not narrated in files it must read), the read set is an explicit contract that excludes closed tasks, per-step detail is written in exactly one place, and a prose budget is enforced on it. **Cap P3 at 3 when the control plane is append-only** — a ledger row over ~200 B, a "you-are-here" section longer than a screen, or the same paragraph in three files is the quadratic-slowdown pattern in `reference/ratchets.md` §"Control-plane prose", worth 4-8x iteration wall time.

**P4 Verification gates** — 0 no automated checks · 1 tests exist but run ad-hoc, not wired to the workflow · 2 a check command exists but steps don't require it, no hard gates · 3 single sanctioned entrypoint + every step names its check · 4 + hard thresholds that can't be self-lowered, evidence-in-log discipline, an explicit gate-failed protocol, **and** a falsified-metric path (replication + shown arithmetic + re-scope-never-delete → decision record + human sign-off) so a threshold no correct work can pass escalates once instead of blocking every iteration. Cap at 3 if a threshold has been individually excused ≥2 times by decision records that each blame the same mandated artifact — that is a mis-scoped gate, not repeated bad luck (see `../reference/ratchets.md`).

**P5 Role-specialized subagents** — 0 none · 1 single agent does everything · 2 one custom agent or ad-hoc delegation · 3 several defined roles with tool scoping · 4 + an adversarial review role, model-per-role, and the loop actually invokes them.

**P6 Autonomy boundaries** — 0 undefined (unbounded, or nothing is automated) · 1 implicit "be careful" only · 2 boundaries mentioned but not enforced by the loop · 3 explicit human-only list + the loop halts and hands back · 4 + permission scoping and blocked/handback markers; the autonomy envelope is documented.

**P7 Change hygiene** — 0 no conventions; risk of committing secrets/artifacts · 1 freeform commits, basic `.gitignore` · 2 commit-style guidance but no secret-scan/tagging · 3 conventional commits + staged-diff secret/forbidden-path scan + clean-tree rule · 4 + milestone tagging tied to gates, and the discipline is encoded in the prompt/loop.

## Scoring (reuses `assessment-report`'s vocabulary)

- **Per-pillar percent** = `level / 4 × 100`.
- **Composite** = Σ(pillar percent × weight) / Σweights → map to the **same A–F band table**
  as `assessment-report/reference/scoring.md`:

  | Band | Grade | Adoption level |
  |---|---|---|
  | 85–100 | **A** | Exemplary |
  | 70–84 | **B** | Solid |
  | 55–69 | **C** | Partial |
  | 40–54 | **D** | Ad-hoc |
  | <40 | **F** | Absent |

- **Confidence flag per pillar** (reused verbatim): 🟢 Verified (signal file read directly) · 🟡 Inferred (present but not confirmed to be wired in) · ⚪ Assumed (couldn't inspect — say so).
- **Each gap** (a missing/weak signal) gets a **severity** (how much it hurts autonomous operation: CRITICAL/HIGH/MEDIUM/LOW) and a **remediation stance** — this is what drives Mode 2:
  - **Fix now** → Mode 2 applies it on-the-fly from `../templates/`.
  - **Schedule** → Mode 2 writes it into a `tasks/agent-readiness-uplift/` PLAN in the target repo.
  - **Accept (interim)** → noted in the report, not actioned.
- **Prioritize** uplift actions on **Impact × Effort** (reuse the matrix): high-impact / low-effort pillars first (usually P2/P3/P4).

## Framing rules (mirror the example)
- Dashboard first: composite grade + adoption level + a 7-row pillar table + a 7-axis radar. Detail (per-pillar gaps + evidence) after.
- Call out genuine **strengths**, not only gaps — it makes the criticism land.
- Say plainly that this is an **adoption-maturity** scale, not a code-quality score, so a "C" isn't misread.
- Lead remediation with the highest maturity-gain-per-hour pillar; name 1–2 "do first" items.
