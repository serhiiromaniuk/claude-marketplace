# Plan

> Written before work starts. **Do not edit the steps once work begins** —
> append changes under `## Amendments`. One step = one loop increment.

## Steps
- [ ] 1. <first step — small, verifiable>
- [ ] 2. <next step>
- [ ] 3. <...>

## Risks / Dependencies
- <risk, dependency, or unknown — and how it's mitigated>
- <which steps are independent and could fan out to parallel subagents>

## Escape hatches
- If a step fails 3 times: stop, log the blocker, set status: blocked, emit `<<LOOP:BLOCKED>>`.
- If a destructive / secret-touching / irreversible external action is required: stop and hand to a human.
- (gate phases) if the gate fails: `<<LOOP:GATE_FAILED>>` — fix the work, never the threshold.

## Amendments
<!-- Append dated plan changes here during work. Never edit the steps above. -->
