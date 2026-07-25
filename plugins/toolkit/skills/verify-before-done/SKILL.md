---
name: verify-before-done
description: Use before any claim that work is complete, fixed, passing, or ready — and before committing, pushing, opening a PR, moving to the next task, or trusting a subagent's success report. Requires running the proving command in the current message and reading its output first. Evidence before assertions, always.
---

# Verify Before Done

Claims about work state require fresh evidence from a command you just ran. No exceptions.

Violating the letter of this rule violates the spirit of it.

## When to use

- About to say done / fixed / passing / works / ready — or any paraphrase or implication of it
- About to commit, push, or open a PR
- About to mark a task complete or start the next one
- A subagent reported success
- Inside an unattended loop, before emitting a completion promise

## The iron law

**No completion claim without fresh verification evidence.**

If you have not run the verification command *in this message*, you cannot claim it passes.

## Gate function

Before stating any status:

1. **Identify** — what exact command proves this claim?
2. **Run** it — full command, fresh, not a subset
3. **Read** — full output, exit code, failure count
4. **Compare** — does the output actually confirm the claim?
   - No: state the real status, with the output
   - Yes: state the claim, with the output
5. Only then, speak

Skipping a step is lying, not verifying.

## What each claim requires

| Claim | Requires | Not sufficient |
|---|---|---|
| Tests pass | Test command output, 0 failures | Earlier run, "should pass" |
| Linter clean | Linter output, 0 errors | Partial check, extrapolation |
| Build succeeds | Build command, exit 0 | Linter passed, logs look fine |
| Bug fixed | Original symptom retested, passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passed once |
| Subagent finished | VCS diff shows the changes | Agent said "success" |
| Requirements met | Line-by-line checklist | Tests passing |
| Deploy healthy | Post-deploy probe / rollout status | Apply command exited 0 |

Regression test red-green: write it, run (pass), revert the fix, run (**must fail**), restore, run (pass). Without the red step you have not proven the test detects anything.

## Stop signals

You are about to violate this if you notice:

- "should", "probably", "seems to", "looks right"
- Satisfaction before evidence — "Great!", "Perfect!", "Done!"
- Committing or pushing without having run the check
- Taking a subagent's word for it
- Partial verification standing in for full
- "just this once" / "I'm confident" / tired and wanting it over
- Any wording that implies success where no command was run

## Rationalizations, answered

| Excuse | Reality |
|---|---|
| "Should work now" | Run the verification |
| "I'm confident" | Confidence is not evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter is not a compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion is not an excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words, so the rule doesn't apply" | Spirit over letter |

## Notes

- In unattended loops (Ralph-style, cron agents) this is the load-bearing rule: a false completion claim ends the loop early with nobody watching. Run the check, then emit the promise.
- Adapted from the `verification-before-completion` skill in
  [obra/superpowers](https://github.com/obra/superpowers) (MIT, Copyright (c) 2025 Jesse Vincent), commit `3dcbd5c`.
