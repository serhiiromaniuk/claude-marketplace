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
