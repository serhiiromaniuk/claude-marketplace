# Log

> Append-only. Never edit a previous entry. Newest at bottom. Keep it factual —
> commands run, evidence, decisions. This is the loop's memory.
>
> **This is the ONE place per-step detail is written.** `loop/STATE.md` and
> `tasks/INDEX.md` are pointers and change only when the gate verdict changes, a
> decision is made, a carry-forward moves, or a task opens/closes. `loop/where.sh`
> computes step position from `PLAN.md` and the last result from this file's newest
> `## ` heading — so restating an entry in a pointer file is prose every later
> iteration pays to re-read.
>
> **Budget: ≤40 lines per entry** (`make loop-hygiene` warns). Bullets, not
> narrative. Cite a spec/doc section, never re-quote it. Record the decision and
> the evidence, not the reasoning that produced them. The shape below is the shape.

## YYYY-MM-DD HH:MM — Session start
Context loaded per `loop/where.sh --json`. Starting at step <N>.

<!-- Entry template — copy, fill, keep it under 40 lines:

## Step <N> <✓|blocked> YYYY-MM-DD — <the headline result, one line>

**Changed:** <file/module — what, one line each>

**Check:** <the check that proves this step> — failed first for <the intended
reason>, then passed. <or, when it is green-on-arrival: the mutation that proves
the assertion has teeth, in one line>

**Evidence:** `make check` EXIT=<n> — <lint result, type result, tests passed,
coverage %, the acceptance numbers>.
<the verbatim output tail — only the decisive lines>

**verifier:** PASS|FAIL — <one line>
**reviewer:** <n> CRITICAL / <n> HIGH / <n> MEDIUM / <n> LOW
- CRITICAL|HIGH <id>: <finding> → fixed in <where>.
- MEDIUM|LOW <id>: <finding> → deferred to PLAN `## Amendments` #<n>.

**Decision:** <a choice the next iteration must not relitigate · none>
**Carry-forward:** <raised/discharged in loop/STATE.md · none>
**Next:** step <N+1> — <title>.

Commit: <type>(<scope>): <subject>   ·   Marker: <<LOOP:CONTINUE>>
-->
