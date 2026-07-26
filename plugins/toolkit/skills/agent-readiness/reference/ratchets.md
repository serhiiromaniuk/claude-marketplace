# Designing ratchets & gates that can't deadlock the loop

Read this when auditing **P4 (verification gates)** or installing gates in Mode 2.
A gate an autonomous loop cannot legally pass is worse than no gate: it converts
every remaining iteration into a hand-back. This file is about designing gates
whose *thresholds stay honest under measurement* — and what to do when one turns
out not to be.

## Two kinds of ratchet — keep them separate

| Kind | Direction | Guards against | Example |
|---|---|---|---|
| **Floor** | may only rise | coverage/assertions being deleted to go green | committed assertion count, coverage % |
| **Ceiling** | may only fall | bloat, scope creep, design smell | LOC budget, bundle size, dependency count |

They are complementary, not redundant — a floor stops tests being removed, a
ceiling stops volume growing without thought. Wire both, and never let one
quantity be governed by a single number that tries to be both.

## The scoping rule (where budgets go wrong)

**A ceiling must count only the quantity whose growth it is meant to discourage.**
The common failure: one budget over *production + test* code together. It reads
as thrifty, but the two are governed by different rules — the same workflow that
caps volume usually also *mandates* a test per feature, per failure mode, per
race. So the mandated axis eats the shared budget, and eventually correct work
cannot fit. The gate then fires on the thing you asked for.

Symptom to look for in an audit: a budget breach whose entire overage is
accounted for by artifacts some other rule requires. That is a scoping bug in the
gate, not bloat in the repo.

Fix shape — **split the axes, gate both**:

```
                 measured   budget   status
TOTAL prod          <p>      <P>      ok    <- design-size signal, hard gate
TOTAL test          <t>      <T>      ok    <- volume ceiling, hard gate, own number
```

Report both per unit (package / module / service) too, so the *shape* of a breach
is visible before it becomes a build failure.

Both hard. Nothing stopped being measured — that is what separates this from
"exclude the tests from the counter", which is a weakened check.

Per-milestone ceilings beat one project-wide number for the mandated axis: state
the arithmetic for the next milestone, rebase at its close via a decision record.
A ceiling nobody can explain gets raised on reflex; one derived from stated
arithmetic gets *checked*.

## Sanity-check a threshold before you install it

1. **Project it to completion.** Sum what the remaining work will add at the
   observed ratio. If the endpoint is 2× the threshold, the threshold is
   decorative — it will be raised serially, which is gate-weakening by
   installments.
2. **Name the axis.** One number, one quantity. If you can't say what growing
   quantity it discourages, it isn't a gate.
3. **Check it against the other rules.** Any workflow rule that *mandates*
   artifacts must not bill them to a ceiling written for a different purpose.
4. **Prove both arms fire.** Temporarily lower each constant, observe non-zero
   exit, revert. An unfired gate is an assumption.

## When a threshold is already wrong — the falsified-metric path

Authoritative rule: `../templates/rules/AGENTS.md` §6. Summary — the loop may
propose a re-scope only when all three hold:

- **Replicated:** the same overage shape is on record at **≥3 independent
  checkpoints**. One is a slow step; three is a wrong metric.
- **Arithmetically unreachable:** shown by computation, alongside the project's
  other mandated requirements — not asserted.
- **Re-scope, never delete:** what is counted is split, and the portion moved out
  keeps a **hard gate of its own**.

Then the increment is the **decision record** — measured numbers, ≥2 options, a
recommendation — and the loop emits `<<LOOP:GATE_FAILED>>` naming the decision.
A human edits the constant. The work stays exactly as verified.

**Watch for the near-miss that is actually a weakened check:** "stop counting X"
with no replacement gate, "raise it to a number nothing will reach", or "trim the
artifacts until it fits". The first two blind a real signal; the third deletes
work the rules required. All three are the failure this path exists to avoid, and
a plausible rationale does not convert one into a re-scope.

## Audit heuristics (P4)

- Repeated decision records that each say "overage is entirely <mandated
  artifact>, the rest is lean" → the gate's scope is wrong. Score P4 down for a
  gate that has been individually excused ≥2 times.
- "Never lower the threshold" with **no** falsified-metric path → the loop's only
  moves on a wrong gate are grind or violate. Level 3 at best.
- Thresholds with no recorded arithmetic → can't be defended, will be raised on
  reflex.
- A floor and a ceiling on the same number → they fight; one of them is unenforced.

## Control-plane prose — the ratchet everyone forgets

Every ratchet above guards the *product*. This one guards the *loop itself*, and it
is the one most likely to be missing: nothing in a Ralph loop bounds how much prose
the loop writes about itself.

**The failure, measured on a real project.** Iteration wall time (minutes between
consecutive loop commits) went from **12–17 min** to **47–211 min** over three
objectives — same model, same machine, same discipline, no growth in task
difficulty. The cause was not the gate (the full verify was 28 s), the model, or
review standards. It was that each iteration is a *fresh* agent that re-reads the
control plane, and the control plane is append-only:

| File | Grew to | Of which |
|---|---|---|
| the ledger (`tasks/INDEX.md`) | 93,119 B / 57 lines | **five rows = 88,900 B (95%)**; one row was 41,717 B on a single line |
| the pointer (`ROADMAP.md`) | 88,025 B / 789 lines | **lines 1–774 = 87,000 B (98.8%)** were accumulated "you are here" paragraphs; one line was 22,485 B |
| a CLOSED task's `LOG.md` | 215,317 B | never needed again, still reachable |

~350 KB / ~90k tokens read *before any work began*, and each iteration appended
20–30 KB that every later iteration re-read: **quadratic**. Worse, the same summary
was written **three times** — LOG entry, pointer paragraph, ledger row — so the
agent paid output-token time to emit it and input-token time forever after.

**The fix, in the order that pays.**

1. **Compact once.** Pointer files back to pointers (≤4 lines), ledger back to one
   line per task. 181 KB → 6.5 KB. Before deleting, grep the pointer for
   `carry-forward|follow-up|owes|amendment|deferred` and relocate anything still
   *live* — history is in git, but an unmet obligation is not history. On the real
   project exactly one entry lived nowhere else, and a spec pointed at it by name.
2. **Compute position instead of narrating it** (`loop/where.sh`). The 181 KB read
   existed to answer one question: *where am I?* A script answers it from the PLAN
   checkboxes, the LOG tail and `git status`, and the loop reads only the files it
   names. This also makes "don't read closed tasks" structural rather than polite.
3. **Write detail once.** With position computed, pointer files carry no per-step
   state, so they change only on gate / decision / carry-forward / task-boundary
   events. The triple-write disappears.
4. **Ratchet it** (`loop/entry-size-guard.sh`): LOG entry ≤40 lines, `STATE.md`
   ≤40 lines, ledger row ≤200 B. **Warn-only, and NOT a dependency of the
   correctness gate** — that gate must never fail on prose style. Call it from the
   agent's own pre-commit sequence instead; a warning nobody reads is worthless.
5. **Cap the subagent reports too.** A reviewer's or verifier's output *is*
   main-context input. Bullets with `file:line`, a findings cap, evidence trimmed
   to the decisive lines.

**Audit heuristics.** A ledger row over ~200 B, a "you are here" section longer
than a screen, a closed task's log still named in the read path, or the same
paragraph appearing in three files → score the loop pillar down and install
steps 1–4. And note the anti-pattern this whole section is about: growing one of
these budgets to silence its warning is the same move as weakening a test to go
green (see the falsified-metric path above — it applies to prose budgets too).
