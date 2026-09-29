#!/usr/bin/env bash
# loop-scripts.test.sh — tests for the loop scripts in ../templates/loop/.
#
# Each case builds a throwaway fixture repo (git init + a task folder) under a
# temp dir, copies the template scripts into its loop/, and asserts on their
# output. Nothing outside the temp dir is touched.
#
# Run: bash plugins/toolkit/skills/agent-readiness/tests/loop-scripts.test.sh
# Needs: bash ≥4, git, jq, make.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$HERE/../templates"
for c in git jq make; do
  command -v "$c" >/dev/null || {
    echo "SKIP: $c not installed"
    exit 0
  }
done

RUN=0
FAILED=0
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

ok() {
  RUN=$((RUN + 1))
  echo "  ok   $1"
}
bad() {
  RUN=$((RUN + 1))
  FAILED=$((FAILED + 1))
  echo "  FAIL $1"
  [[ -n "${2:-}" ]] && printf '       %s\n' "$2"
}
check() { # check <name> <command...> — passes when the command exits 0
  local name="$1"
  shift
  if "$@"; then ok "$name"; else bad "$name"; fi
}

# fixture <dir> — a minimal repo the loop scripts can run in.
fixture() {
  local d="$1"
  mkdir -p "$d/loop" "$d/rules" "$d/tasks/phase-1_demo" "$d/docs"
  cp "$TPL"/loop/*.sh "$d/loop/"
  chmod +x "$d"/loop/*.sh
  printf '# CLAUDE.md\n\n@rules/RULES.md\n' >"$d/CLAUDE.md"
  printf '# RULES\n\nSee @rules/AGENTS.md for how to work.\n' >"$d/rules/RULES.md"
  printf '# AGENTS\n' >"$d/rules/AGENTS.md"
  cat >"$d/loop/STATE.md" <<'EOF'
| Field | Value |
|-------|-------|
| **Gate status** | open |
| **Blocked?** | no |
EOF
  cat >"$d/tasks/INDEX.md" <<'EOF'
| Started | Phase | Task | Folder | Status | Tag |
|---------|-------|------|--------|--------|-----|
| 2026-01-01 | 1 | Demo | [`phase-1_demo/`](./phase-1_demo/) | in-progress | `v0.1` |
EOF
  cat >"$d/tasks/phase-1_demo/BRIEF.md" <<'EOF'
# Demo
- Governing spec: `docs/spec.md`
EOF
  cat >"$d/tasks/phase-1_demo/PLAN.md" <<'EOF'
# Plan

## Steps

- [x] 1. **Done already:** nothing — check: none.
- [ ] 2. **Edge proxy:** spec §Wave 1 file table and §2 rules; see
  `AGENTS.md` §6 for gates — check: make check.
  second continuation line.
- [ ] 3. **Later:** spec §Wave 2 — check: make check.

## Amendments
EOF
  cat >"$d/tasks/phase-1_demo/LOG.md" <<'EOF'
# Log

<!-- Entry template:

## Step <N> ✓ YYYY-MM-DD — template heading, not an entry

-->

## Step 0 ✓ — oldest entry
old body
## Step 1a ✓ — middle entry
middle body
## Step 1 ✓ — newest entry
newest body
EOF
  cat >"$d/docs/spec.md" <<'EOF'
# Spec

## 1. Ground rules
rule one

## 2. More rules
rule two

## 10. Tenth
tenth body

## Wave 1 — edge
wave one body

```text
## not a heading, fenced
```

### Wave 1 checks
nested check

## Wave 2 — data
wave two body
EOF
  (cd "$d" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init)
}

echo "where.sh"
W="$ROOT/w"
fixture "$W"
J="$("$W/loop/where.sh" --json)"
C="$("$W/loop/where.sh" --context)"

check "rules imported by CLAUDE.md (transitively) are .loaded, not .read" \
  test "$(jq -c '.loaded' <<<"$J")" = '["CLAUDE.md","rules/RULES.md","rules/AGENTS.md"]'
check "LOG.md is never in .read" \
  test "$(jq '[.read[] | select(endswith("LOG.md"))] | length' <<<"$J")" = 0
check "every cited § resolves → spec leaves .read" \
  test "$(jq '[.read[] | select(. == "docs/spec.md")] | length' <<<"$J")" = 0
check "spec_sections names §Wave 1 and §2, not §1 or §10" \
  test "$(jq -c '.spec_sections' <<<"$J")" = '["2. More rules (L6-8)","Wave 1 — edge (L12-21)"]'
check "context_cmd is set" test "$(jq -r '.context_cmd' <<<"$J")" = "loop/where.sh --context"
check "--context prints the step's full text" grep -q 'second continuation line' <<<"$C"
check "--context prints a cited section, nested heading included" grep -q 'nested check' <<<"$C"
lacks() { ! grep -qE "$1" <<<"$C"; }
check "--context leaves out uncited sections" lacks 'tenth body|wave two body|rule one'
check "--context prints the newest two LOG entries" grep -qzE 'middle body.*newest body' <<<"$C"
check "--context prints the newest two LOG entries only" lacks 'old body|template heading'

sed -i 's/§2 rules/§9 rules/' "$W/tasks/phase-1_demo/PLAN.md"
J2="$("$W/loop/where.sh" --json)"
check "an unresolved § keeps the whole spec in .read" \
  test "$(jq '[.read[] | select(. == "docs/spec.md")] | length' <<<"$J2")" = 1
check "…and reports no sections" test "$(jq '.spec_sections | length' <<<"$J2")" = 0

sed -i 's/^- \[ \] 3\./- [x] 3./' "$W/tasks/phase-1_demo/PLAN.md"
check "step is the first unchecked box, not checked+1" \
  test "$("$W/loop/where.sh" --json | jq '.step')" = 2

check "entry-size-guard still finds the active LOG.md" \
  grep -q 'phase-1_demo/LOG.md newest entry' <<<"$("$W/loop/entry-size-guard.sh")"

rm "$W/CLAUDE.md"
check "without CLAUDE.md the rules files are read" \
  test "$("$W/loop/where.sh" --json | jq -c '.read[0:2]')" = '["rules/RULES.md","rules/AGENTS.md"]'

echo "step-done.sh"
# sfixture <dir> — the where.sh fixture plus a gate, a bare remote and an upstream.
sfixture() {
  local d="$1"
  fixture "$d"
  printf 'check:\n\t@echo "lint ok"; echo "tests: 3 passed"; test ! -f FAIL\n' >"$d/Makefile"
  git init -q --bare "$d.remote.git"
  (cd "$d" && git add -A && git -c user.name=t -c user.email=t@t commit -qm gate \
    && git remote add origin "$d.remote.git" && git push -qu origin HEAD 2>/dev/null)
}
sd() { (cd "$S" && git -c user.name=t -c user.email=t@t "$@"); }
S="$ROOT/s"
sfixture "$S"
head0="$(sd rev-parse HEAD)"
PLAN="$S/tasks/phase-1_demo/PLAN.md"
LOGF="$S/tasks/phase-1_demo/LOG.md"

(cd "$S" && loop/step-done.sh >/dev/null 2>&1)
check "no --commit and no --dry-run → exit 2" test $? -eq 2

touch "$S/FAIL"
(cd "$S" && loop/step-done.sh --commit "x" >/dev/null 2>&1)
rc=$?
check "red gate → exit 1" test "$rc" -eq 1
check "red gate → LOG, PLAN and HEAD untouched" \
  test -z "$(sd status --porcelain -- tasks)" -a "$(sd rev-parse HEAD)" = "$head0"
rm "$S/FAIL"

(cd "$S" && loop/step-done.sh --dry-run >/dev/null 2>&1)
check "--dry-run is green and changes nothing" test $? -eq 0 -a -z "$(sd status --porcelain)"

for i in $(seq 1 34); do echo "- prose line $i"; done >>"$LOGF" # entry ≈36 prose lines
echo "new file" >"$S/docs/new.md"
sd add docs/new.md
(cd "$S" && GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
  loop/step-done.sh --commit "docs: step 2" >/dev/null 2>&1)
check "green gate → committed" test "$(sd log -1 --format=%s)" = "docs: step 2"
check "…with the staged step files, LOG and PLAN" \
  test "$(sd show --name-only --format= HEAD | sort | tr '\n' ' ')" = "docs/new.md tasks/phase-1_demo/LOG.md tasks/phase-1_demo/PLAN.md "
check "LOG gets the machine-written gate block" \
  grep -qzE 'gate:begin.*EXIT=0.*tests: 3 passed.*gate:end' "$LOGF"
check "PLAN step 2 is ticked, step 3 is not" \
  grep -qzE -- '- \[x\] 2\..*- \[ \] 3\.' "$PLAN"
check "where.sh moves to step 3" test "$(cd "$S" && loop/where.sh --json | jq .step)" = 3
check "one unpushed commit = one unreviewed" \
  test "$(cd "$S" && loop/where.sh --json | jq .unreviewed)" = 1
check "the gate block is not counted as LOG prose (36 + block ≤ 40)" \
  grep -qE 'newest entry 3[0-9]/40' <<<"$(cd "$S" && loop/entry-size-guard.sh)"

printf 'aws_key = "%s%s"\n' "AKIA" "IOSFODNN7EXAMPLE" >"$S/docs/leak.md"
sd add docs/leak.md
head1="$(sd rev-parse HEAD)"
(cd "$S" && loop/step-done.sh --commit "leak" >/dev/null 2>&1)
check "a key-shaped string in the staged diff → exit 3, no commit" \
  test $? -eq 3 -a "$(sd rev-parse HEAD)" = "$head1"
sd reset -q docs/leak.md && rm "$S/docs/leak.md"
sd checkout -q -- tasks

printf 'X=1\n' >"$S/.env"
sd add -f .env
(cd "$S" && loop/step-done.sh --commit "env" >/dev/null 2>&1)
check "a staged .env → exit 3, no commit" test $? -eq 3 -a "$(sd rev-parse HEAD)" = "$head1"
sd reset -q .env && rm "$S/.env"
sd checkout -q -- tasks

printf '#!/bin/sh\nexit 1\n' >"$S/.git/hooks/pre-commit" && chmod +x "$S/.git/hooks/pre-commit"
(cd "$S" && loop/step-done.sh --commit "hooked" >/dev/null 2>&1)
check "commit hooks run (no --no-verify): a refusing hook → exit 3" \
  test $? -eq 3 -a "$(sd rev-parse HEAD)" = "$head1"
rm "$S/.git/hooks/pre-commit"
sd reset -q && sd checkout -q -- tasks

(cd "$S" && GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
  loop/step-done.sh --commit "docs: step 3" --push >/dev/null 2>&1)
check "--push publishes: nothing unreviewed afterwards" \
  test "$(cd "$S" && loop/where.sh --json | jq .unreviewed)" = 0

echo "parallel groups, owner questions, merge-gate.sh"
P="$ROOT/p"
sfixture "$P"
cat >"$P/tasks/phase-1_demo/PLAN.md" <<'EOF2'
# Plan

## Questions for the owner

- Q1 — Which region? · blocks: 4 · answer: pending
- Q2 — Budget cap? · blocks: none · answer: asked 2026-01-02
- Q3 — Owner? · answer: Alice, 2026-01-03

## Steps

- [x] 1. **Done:** x — check: none.
- [ ] 2. [parallel: A] **Area A:** discovery — check: page exists.
- [ ] 3. [parallel: A] **Area B:** discovery — check: page exists.
- [ ] 4. **Decide:** region (needs Q1, Q3) — check: record.
- [ ] 5. [parallel: A] **Area C:** discovery — check: page exists.
EOF2
(cd "$P" && git add -A && git -c user.name=t -c user.email=t@t commit -qm plan)
J3="$(cd "$P" && loop/where.sh --json)"
check "the [parallel: A] tag is stripped from the title" test "$(jq -r .step_title <<<"$J3")" = "Area A"
check "parallel_group and every unchecked step of it" \
  test "$(jq -c '[.parallel_group, .parallel_steps]' <<<"$J3")" = '["A",[2,3,5]]'
check "open_questions counts pending + asked, unasked only pending" \
  test "$(jq -c '[.open_questions, .unasked_questions]' <<<"$J3")" = '[2,1]'
(cd "$P" && GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
  loop/step-done.sh --steps "2 3 5" --commit "docs: group A" >/dev/null 2>&1)
check "step-done --steps ticks exactly the group" \
  test "$(grep -cE '^- \[x\] (2|3|5)\.' "$P/tasks/phase-1_demo/PLAN.md")" = 3
J4="$(cd "$P" && loop/where.sh --json)"
check "the next step waits on its open question only (Q1, not the answered Q3)" \
  test "$(jq -c '[.step, .waiting_on, .parallel_steps]' <<<"$J4")" = '[4,["Q1"],[]]'
(cd "$P" && loop/step-done.sh --steps "2" --commit "x" >/dev/null 2>&1)
check "step-done --steps refuses an already-ticked step (exit 3)" test $? -eq 3

pg() { (cd "$P" && git -c user.name=t -c user.email=t@t "$@") >/dev/null 2>&1; }
pg checkout -qb a && echo a >"$P/docs/a.md" && pg add -A && pg commit -qm a
pg checkout -q main 2>/dev/null || pg checkout -q master
base="$(cd "$P" && git symbolic-ref --short HEAD)"
pg checkout -qb b && echo b >"$P/docs/b.md" && pg add -A && pg commit -qm b
pg checkout -qb c "$base" && echo c >"$P/docs/a.md" && pg add -A && pg commit -qm c
pg checkout -q "$base"
if [[ "$base" != main ]]; then pg branch -m "$base" main; fi
(cd "$P" && loop/merge-gate.sh a b >/dev/null 2>&1)
check "merge-gate: disjoint branches are green together" test $? -eq 0
(cd "$P" && loop/merge-gate.sh a c >/dev/null 2>&1)
check "merge-gate: conflicting branches fail" test $? -ne 0
check "merge-gate leaves main untouched" test ! -f "$P/docs/a.md"

echo
echo "$RUN run, $FAILED failed"
[[ "$FAILED" -eq 0 ]]
