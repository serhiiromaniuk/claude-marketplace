# WORKFLOW.md — a worked example, start to finish

This is the concrete companion to [`AGENTS.md`](./AGENTS.md). It walks one task
through the whole loop so the abstract rules have a shape. The example is a
generic **Phase 1 — Foundation** task, then a sketch of a later coding phase so
you see the pattern repeat.

Quick map of the moving parts:

| Layer | File(s) | Role |
|-------|---------|------|
| Governance | [`RULES.md`](./RULES.md) | golden rules, architecture, git |
| Operating manual | [`AGENTS.md`](./AGENTS.md) | how to execute |
| This walkthrough | `WORKFLOW.md` | the example |
| Loop engine | [`../loop/`](../loop/) | `PROMPT.md`, `loop.sh`, `STATE.md` |
| Memory | [`../tasks/`](../tasks/) | `BRIEF/PLAN/LOG/OUTCOME` per task + `INDEX.md` |
| Specialists | [`../agents/`](../agents/) | planner, reviewer, verifier |
| Shortcuts | [`../commands/`](../commands/) | `/status`, `/loop-step` |

---

## Phase A — Triage (human + agent, a few minutes)

A task starts from a human prompt. Three flavours:

- **Clear:** *"Do Phase 1 — design the `<component>` interface and record the
  decision."*
- **Vague:** *"start the foundation work."* → the agent asks 3–5 scoping
  questions first (which parts? any option already preferred? deadline?).
- **Exploratory:** *"is `<approach>` even feasible here?"* → the first plan step
  is literally "investigate", with a time-boxed escape hatch.

Output of triage: agreement on **what one task** this session advances and its
**done-when** condition.

---

## Phase B — Create the task structure (agent)

Copy the template:

```bash
cp -r tasks/_template tasks/phase-1_<short-kebab>
```

Then fill the three live docs (OUTCOME comes later):

**BRIEF.md** — frozen once written:
```markdown
# Phase 1 — Foundation

## What
Complete the foundation document: the key decisions (approach, components,
constraints, dependencies) this project rests on.

## Why
Golden rule #6 — no later-phase production code may start until this is done and
reviewed. Every later decision must trace to a conclusion here.

## Scope
**In:** the foundation document's sections + a feasibility note.
**Out:** any production code in src/ (forbidden until this task closes + review).

## Done when
- [ ] Every section has findings AND an explicit recommendation
- [ ] Key parameters recorded with rationale/sources
- [ ] Dependency list ready to pin
- [ ] Human review complete → milestone tag v0.1-<name>

## References
- RULES.md (golden rules, phase table) · <spec doc §...>
```

**PLAN.md** — steps frozen once work begins; amend at the bottom:
```markdown
# Plan
> Written before work. Do not edit steps once work starts — append amendments.

## Steps
- [ ] 1. Section A research → recommendation
- [ ] 2. Section B → recommendation
- [ ] 3. Section C → decision
- [ ] 4. Parameters table → filled with sourced values
- [ ] 5. Dependency list → pinned versions
- [ ] 6. Feasibility note; flag if a constraint is at risk
- [ ] 7. Self-review (multi-lens) + request human review

## Risks / Dependencies
- <external constraint that may rule out an option — verify early>.
- Steps 1–5 are largely independent → can fan out parallel `researcher`/planner subagents.

## Escape hatches
- If a section has no defensible recommendation after 3 attempts: log the blocker,
  set status: blocked, emit <<LOOP:BLOCKED>>.
- No access to a needed source: record what's missing, continue other steps.

## Amendments
<!-- append plan changes here, dated -->
```

**LOG.md** — first entry:
```markdown
# Log
> Append-only. Newest at bottom.

## YYYY-MM-DD HH:MM — Session start
Context loaded: RULES.md, AGENTS.md, BRIEF, PLAN. Starting at step 1.
```

Then update [`../tasks/INDEX.md`](../tasks/INDEX.md) and
[`../loop/STATE.md`](../loop/STATE.md) to point at this task, step 1.

---

## Phase C — Execute the loop (agent, possibly unattended)

Each iteration = **one step → verify → log → check box → commit/push → marker**
(AGENTS.md §4). Independent steps can fan out in parallel:

```text
Use several subagents in parallel, one each for the independent foundation
sections. Each returns findings + a recommendation; I consolidate into the
foundation doc and log per section.
```

Good `LOG.md` entries are factual and carry evidence:
```markdown
## YYYY-MM-DD HH:MM — Step 1 done: <component> choice
Compared options A / B / C on <criteria>. Recommendation: <choice> — <one-line
justification>. Written to the foundation doc, Section A.
Verify: Section A now ends with a stated recommendation. ✅
Commit: docs(<component>): foundation Section A recommendation
<<LOOP:CONTINUE>>
```

To run it unattended, a human starts the harness from a terminal:
```bash
loop/loop.sh --max-iterations 8        # bounded; stops on a marker or the cap
```
Or do one increment interactively with the `/loop-step` command, and check
position any time with `/status`.

The loop **stops itself** when it emits `<<LOOP:DONE>>`, `<<LOOP:BLOCKED>>`, or
`<<LOOP:GATE_FAILED>>` — or when it hits the iteration cap. It rolls
phase→phase autonomously via `<<LOOP:PHASE_COMPLETE>>` only once a gate is
observed-green.

---

## Phase D — Close (agent writes, human gates the boundary)

When every step is checked and the gate is satisfied, write **OUTCOME.md**:
```markdown
# Outcome
## Summary
Foundation doc complete: <approach>, <components>, parameters table, pinned
deps. <feasibility verdict>.

## Deliverables
- Commits: <hashes> (docs(<component>): foundation …)
- Foundation doc, all sections + feasibility note
- Pinned dependency list ready for the next phase

## Pending / Follow-up
- [ ] Human review of the foundation doc
- [ ] On approval: tag v0.1-<name>; open Phase 2 task

## Lessons / Notes
- <anything worth remembering>
```

Then: set `tasks/INDEX.md` → `done`, emit `<<LOOP:PHASE_COMPLETE>>` (or, for a
human-only boundary, hand over). Once the gate is green the milestone is tagged
(`git tag v0.1-<name> && git push --tags`) and the next-phase task opens — the
gate has lifted.

---

## The pattern repeats (later coding phase sketch)

A coding phase is the same loop with code-shaped steps and checks:

```text
tasks/phase-2_<component>/
  BRIEF  done-when: <component> behaves correctly on known inputs,
                    ≥80% coverage on src/<component>/, make check green
  PLAN   1. failing test: known input → expected output  (TDD red)
         2. implement src/<component>/base.<ext> interface
         3. implement src/<component>/<impl>.<ext>  (green)
         4. edge cases + tests
         5. reviewer subagent: audit vs golden rules (adapter boundary,
            no forbidden deps, no side effects) + correctness
         6. verifier subagent: make check, paste output
  each step → verify (make check) → log evidence → commit → <<LOOP:CONTINUE>>
```

Same discipline, same markers, same gates. The only thing that changes between
phases is the content of the steps and which check proves them.

---

## Edge cases

- **Blocked mid-step:** 3 failed attempts → log blocker, `status: blocked`,
  write OUTCOME, `<<LOOP:BLOCKED>>`. Don't thrash.
- **Task too big:** split into `phase-N_part-a`, `phase-N_part-b`; each gets its
  own folder, plan, and commits.
- **Plan was wrong:** never edit the original steps — append an `## Amendments`
  note explaining the change, then proceed.
- **Gate fails:** `<<LOOP:GATE_FAILED>>`, fix the *work*, re-run. Never edit the
  thresholds.
