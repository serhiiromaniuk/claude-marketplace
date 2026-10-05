#!/usr/bin/env bash
# loop-scripts.test.sh — tests for the loop scripts in ../templates/loop/.
#
# Each case builds a throwaway fixture repo (git init + a task folder) under a
# temp dir, copies the template scripts into its loop/, and asserts on their
# output. Nothing outside the temp dir is touched: HOME points into it, so git
# reads only the fixture config, and loop.sh drives a fake `claude` from it.
#
# Run: bash plugins/toolkit/skills/agent-readiness/tests/loop-scripts.test.sh
# Needs: bash >= 3.2, git, jq, make. Portable sed/grep/awk only (no `sed -i`,
# no `grep -z`), so it also runs on macOS and busybox.

# shellcheck disable=SC2016 # reason: fixtures write literal `$VAR`, `$(…)` and backticks on purpose
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
BGPIDS=""
# shellcheck disable=SC2317,SC2086 # reason: invoked by the EXIT trap; pids split on purpose
cleanup() {
  [[ -n "$BGPIDS" ]] && kill $BGPIDS 2>/dev/null
  rm -rf "$ROOT"
}
trap cleanup EXIT

# A hermetic git: identity, default branch, no user hooks or config.
export HOME="$ROOT/home"
mkdir -p "$HOME"
printf '[user]\n\tname = t\n\temail = t@t\n[init]\n\tdefaultBranch = main\n' >"$HOME/.gitconfig"
export GIT_CONFIG_NOSYSTEM=1
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

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
eq() { # eq <name> <actual> <expected>
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1" "got: $2 | want: $3"; fi
}
has() { grep -qF -- "$2" <<<"$1"; }    # has <text> <fixed string>
lacks() { ! grep -qE -- "$2" <<<"$1"; } # lacks <text> <ERE>
flat() { tr '\n' ' ' <"$1"; }           # a file on one line, for multi-line matches
subst() {                               # subst <file> <sed script> — portable in-place edit
  sed -e "$2" "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

# fixture <dir> — a minimal repo the loop scripts can run in (the installed layout:
# rules at the root, loop/, tasks/).
fixture() {
  local d="$1"
  mkdir -p "$d/loop" "$d/tasks/phase-1_demo" "$d/docs"
  cp "$TPL"/loop/*.sh "$d/loop/"
  chmod +x "$d"/loop/*.sh
  printf 'Do one step.\n' >"$d/loop/PROMPT.md"
  printf '# CLAUDE.md\n\n@RULES.md\n' >"$d/CLAUDE.md"
  printf '# RULES\n\nSee @AGENTS.md for how to work.\n' >"$d/RULES.md"
  printf '# AGENTS\n' >"$d/AGENTS.md"
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
- [ ] 2. **Edge proxy:** spec §Wave 1 file table and spec §2 rules; values
  per runtime-reference §1 and runtime-spec §10; see `AGENTS.md` §6 — check:
  make check.
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
  (cd "$d" && git init -q && git add -A && git commit -qm init)
}

# ════════════════════════════════════════════════════════════════════════════
echo "where.sh"
W="$ROOT/w"
fixture "$W"
WPLAN="$W/tasks/phase-1_demo/PLAN.md"
wj() { (cd "$W" && loop/where.sh --json); }
J="$(wj)"
C="$(cd "$W" && loop/where.sh --context)"

eq "rules imported by CLAUDE.md (transitively) are .loaded, not .read" \
  "$(jq -c '.loaded' <<<"$J")" '["CLAUDE.md","RULES.md","AGENTS.md"]'
eq "LOG.md is never in .read" "$(jq '[.read[] | select(endswith("LOG.md"))] | length' <<<"$J")" 0
eq "every cited § resolves → spec leaves .read" "$(jq '[.read[] | select(. == "docs/spec.md")] | length' <<<"$J")" 0
eq "spec_sections names §Wave 1 and §2, not foreign §1 or §10" \
  "$(jq -c '.spec_sections' <<<"$J")" '["2. More rules (L6-8)","Wave 1 — edge (L12-21)"]'
eq "context_cmd is set" "$(jq -r '.context_cmd' <<<"$J")" "loop/where.sh --context"
eq "step_title is cut at the bold colon" "$(jq -r '.step_title' <<<"$J")" "Edge proxy"
eq "last_result is the newest real LOG heading" "$(jq -r '.last_result' <<<"$J")" "Step 1 ✓ — newest entry"
check "--context prints the step's full text" has "$C" 'second continuation line'
check "--context prints a cited section, nested heading included" has "$C" 'nested check'
check "--context leaves out uncited sections" lacks "$C" 'tenth body|wave two body|rule one'
check "--context prints the newest two LOG entries" grep -qE 'middle body.*newest body' <<<"$(tr '\n' ' ' <<<"$C")"
check "--context prints the newest two LOG entries only" lacks "$C" 'old body|template heading'
eq "--read prints exactly .read" "$(cd "$W" && loop/where.sh --read | tr '\n' ' ')" "$(jq -r '.read[]' <<<"$J" | tr '\n' ' ')"
H="$(cd "$W" && loop/where.sh --human)"
check "--human names the step and the last result" \
  grep -qE 'step +: 2 of 3 — Edge proxy.*last result : Step 1 ✓ — newest entry' <<<"$(tr '\n' ' ' <<<"$H")"

cat >"$WPLAN" <<'EOF'
# Plan

## Steps

- [x] 1. **Done already:** nothing — check: none.
- [ ] 2. **Edge proxy:** spec §Wave
  1 file table and spec §2 rules — check: make check.
- [ ] 3. **Later:** spec §Wave 2 — check: make check.
EOF
eq "a citation wrapped across lines still resolves" \
  "$(wj | jq -c '.spec_sections')" '["2. More rules (L6-8)","Wave 1 — edge (L12-21)"]'

subst "$WPLAN" 's/§2 rules/§9 rules/'
J2="$(wj)"
eq "an unresolved § keeps the whole spec in .read" "$(jq '[.read[] | select(. == "docs/spec.md")] | length' <<<"$J2")" 1
eq "…and reports no sections" "$(jq '.spec_sections | length' <<<"$J2")" 0

subst "$WPLAN" 's/^- \[ \] 3\./- [x] 3./'
eq "step is the first unchecked box, not checked+1" "$(wj | jq '.step')" 2
subst "$WPLAN" 's/^- \[ \] 2\./- [x] 2./'
eq "every box ticked → all_steps_done" "$(wj | jq -c '[.all_steps_done, .step, .steps]')" '[true,3,3]'

cat >"$WPLAN" <<'EOF'
# Plan

## Steps
- [ ] 1. Section A discovery → own page + recommendation
- [ ] 2. Section B discovery → own page
- [ ] 3. Write the parser — check: make test
EOF
eq "an unbolded title stops at the next checkbox" "$(wj | jq -r '.step_title')" "Section A discovery → own page + recommendation"
subst "$WPLAN" 's/^- \[ \] 1\./- [x] 1./; s/^- \[ \] 2\./- [x] 2./'
eq "an unbolded title is cut at ' — check:'" "$(wj | jq -r '.step_title')" "Write the parser"

cat >"$WPLAN" <<'EOF'
# Plan

## Steps
- [ ] 1. [parallel:A] **Area A:** x — check: page.
- [ ] 2. [parallel: A] **Area B:** y — check: page.
- [ ] 3. [parallel: B] **Area C:** z — check: page.
EOF
eq "[parallel:A] and [parallel: A] are one group" "$(wj | jq -c '[.parallel_group, .parallel_steps, .step_title]')" '["A",[1,2],"Area A"]'

check "entry-size-guard still finds the active LOG.md" \
  has "$(cd "$W" && loop/entry-size-guard.sh)" 'phase-1_demo/LOG.md newest entry'

cp "$TPL/tasks/_template/LOG.md" "$W/tasks/phase-1_demo/LOG.md"
J3="$(wj)"
eq "a fresh LOG: last_result skips the template's commented heading" \
  "$(jq -r '.last_result' <<<"$J3")" "YYYY-MM-DD HH:MM — Session start"
check "a fresh LOG: the guard measures the real entry, not the comment" \
  grep -qE 'newest entry [0-3]/40' <<<"$(cd "$W" && loop/entry-size-guard.sh)"

subst "$W/tasks/INDEX.md" 's#(\./phase-1_demo/)#(phase-1_demo/)#'
eq "a ledger link without ./ still names the folder" "$(wj | jq -c '[.needs_open, .folder]')" '[false,"tasks/phase-1_demo"]'
subst "$W/tasks/INDEX.md" 's#(phase-1_demo/)#(./phase-2_missing/)#'
J4="$(wj)"
eq "a ledger row whose folder is missing → needs_open" "$(jq '.needs_open' <<<"$J4")" true
eq "…and the read list names the template" "$(jq -c '[.read[] | select(startswith("tasks/_template"))]' <<<"$J4")" \
  '["tasks/_template/BRIEF.md","tasks/_template/PLAN.md"]'
subst "$W/tasks/INDEX.md" 's#(\./phase-2_missing/)#(./phase-1_demo/)#'
mv "$WPLAN" "$WPLAN.bak"
eq "a task folder with no PLAN.md → needs_plan" "$(wj | jq '.needs_plan')" true
mv "$WPLAN.bak" "$WPLAN"
printf '# Spec\n\n> **STUB** — to be written.\n' >"$W/docs/spec.md"
J5="$(wj)"
eq "a STUB marker in the spec header → spec_stub, spec in .read" \
  "$(jq -c '[.spec_stub, ([.read[] | select(. == "docs/spec.md")] | length)]' <<<"$J5")" '[true,1]'

echo "where.sh — imports, parsed the way Claude Code parses them"
printf '# CLAUDE.md\n\n```text\n@RULES.md\n```\nUse `@AGENTS.md` like this.\n' >"$W/CLAUDE.md"
eq "an @import in a fenced block or a code span is not an import" \
  "$(wj | jq -c '[.loaded, .read[0:2]]')" '[["CLAUDE.md"],["RULES.md","AGENTS.md"]]'
printf '# CLAUDE.md\n@./RULES.md\n' >"$W/CLAUDE.md"
eq "@./RULES.md is an import" "$(wj | jq -c '.loaded')" '["CLAUDE.md","RULES.md","AGENTS.md"]'
mkdir -p "$W/rules"
printf '# CLAUDE.md\n@rules/RULES.md\n' >"$W/CLAUDE.md"
printf '# RULES\n@AGENTS.md\n' >"$W/rules/RULES.md"
printf '# AGENTS\n' >"$W/rules/AGENTS.md"
eq "an import resolves relative to the importing file (rules/RULES.md → @AGENTS.md)" \
  "$(cd "$W" && LOOP_RULES="rules/RULES.md rules/AGENTS.md" loop/where.sh --json | jq -c '.loaded')" \
  '["CLAUDE.md","rules/RULES.md","rules/AGENTS.md"]'
printf '# RULES\nSee @rules/AGENTS.md\n' >"$W/rules/RULES.md"
eq "…so @rules/AGENTS.md inside rules/RULES.md is rules/rules/AGENTS.md: still read" \
  "$(cd "$W" && LOOP_RULES="rules/RULES.md rules/AGENTS.md" loop/where.sh --json | jq -c '[.loaded, .read[0]]')" \
  '[["CLAUDE.md","rules/RULES.md"],"rules/AGENTS.md"]'
rm "$W/CLAUDE.md"
eq "without CLAUDE.md the rules files are read" "$(wj | jq -c '.read[0:2]')" '["RULES.md","AGENTS.md"]'

E="$ROOT/empty"
mkdir -p "$E/loop"
cp "$TPL/loop/where.sh" "$E/loop/"
(cd "$E" && git init -q)
EJ="$(cd "$E" && loop/where.sh --json)"
erc=$?
check "a bare repo: valid JSON with .error set, exit 2" \
  test "$erc" -eq 2 -a "$(jq -c '[.read, (.error | length > 0)]' <<<"$EJ" 2>/dev/null)" = '[[],true]'

# ════════════════════════════════════════════════════════════════════════════
echo "entry-size-guard.sh"
G="$ROOT/g"
fixture "$G"
check "everything within budget → hygiene OK" has "$(cd "$G" && loop/entry-size-guard.sh)" 'loop hygiene OK'
for i in $(seq 1 41); do echo "| x | $i |"; done >>"$G/loop/STATE.md"
GO="$(cd "$G" && loop/entry-size-guard.sh)"
check "STATE.md over 40 lines → WARN" grep -qE 'WARN +loop/STATE.md is [0-9]+ lines' <<<"$GO"
(cd "$G" && loop/entry-size-guard.sh --strict >/dev/null)
check "--strict turns a warning into exit 1" test $? -eq 1
row="| 2026-01-02 | 2 | $(printf 'é%.0s' $(seq 1 90)) | x | todo | - |"
echo "$row" >>"$G/tasks/INDEX.md"
check "a ledger row is measured in bytes (90 é = 180 B + frame > 200 B)" \
  grep -qE 'INDEX.md rows over 200B: 4\(' <<<"$(cd "$G" && loop/entry-size-guard.sh)"
check "--help works from a subdirectory" has "$(cd "$G/tasks" && ../loop/entry-size-guard.sh --help)" 'Usage:'

# ════════════════════════════════════════════════════════════════════════════
echo "step-done.sh"
# sfixture <dir> — the where.sh fixture plus a gate, a bare remote and an upstream.
sfixture() {
  local d="$1"
  fixture "$d"
  printf 'check:\n\t@echo "lint ok"; echo "tests: 3 passed"; test ! -f FAIL\n' >"$d/Makefile"
  git init -q --bare "$d.remote.git"
  (cd "$d" && git add -A && git commit -qm gate \
    && git remote add origin "$d.remote.git" && git push -qu origin HEAD 2>/dev/null)
}
sd() { (cd "$S" && git "$@"); }
S="$ROOT/s"
sfixture "$S"
head0="$(sd rev-parse HEAD)"
PLAN="$S/tasks/phase-1_demo/PLAN.md"
LOGF="$S/tasks/phase-1_demo/LOG.md"
gate_blocks() { grep -c 'gate:begin' "$LOGF"; }

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
(cd "$S" && loop/step-done.sh --commit "docs: step 2" >/dev/null 2>&1)
eq "green gate → committed" "$(sd log -1 --format=%s)" "docs: step 2"
eq "…with the staged step files, LOG and PLAN" \
  "$(sd show --name-only --format= HEAD | sort | tr '\n' ' ')" "docs/new.md tasks/phase-1_demo/LOG.md tasks/phase-1_demo/PLAN.md "
check "LOG gets the machine-written gate block" grep -qE 'gate:begin.*EXIT=0.*tests: 3 passed.*gate:end' <<<"$(flat "$LOGF")"
check "PLAN step 2 is ticked, step 3 is not" grep -qE -- '- \[x\] 2\..*- \[ \] 3\.' <<<"$(flat "$PLAN")"
eq "where.sh moves to step 3" "$(cd "$S" && loop/where.sh --json | jq .step)" 3
eq "one unpushed commit = one unreviewed" "$(cd "$S" && loop/where.sh --json | jq .unreviewed)" 1
check "the gate block is not counted as LOG prose (36 + block ≤ 40)" \
  grep -qE 'newest entry 3[0-9]/40' <<<"$(cd "$S" && loop/entry-size-guard.sh)"

cp "$LOGF" "$ROOT/log.before"
cp "$PLAN" "$ROOT/plan.before"
head1="$(sd rev-parse HEAD)"
printf 'aws_key = "%s%s"\n' "AKIA" "IOSFODNN7EXAMPLE" >"$S/docs/leak.md"
sd add docs/leak.md
(cd "$S" && loop/step-done.sh --commit "leak" >/dev/null 2>&1)
check "a key-shaped string in the staged diff → exit 3, no commit" \
  test $? -eq 3 -a "$(sd rev-parse HEAD)" = "$head1"
check "…and LOG is restored" cmp -s "$LOGF" "$ROOT/log.before"
check "…and PLAN is restored (no step ticked)" cmp -s "$PLAN" "$ROOT/plan.before"
eq "…and neither is left staged" "$(sd diff --cached --name-only -- tasks)" ""
sd reset -q docs/leak.md && rm "$S/docs/leak.md"

printf 'X=1\n' >"$S/.env"
sd add -f .env
(cd "$S" && loop/step-done.sh --commit "env" >/dev/null 2>&1)
check "a staged .env → exit 3, no commit" test $? -eq 3 -a "$(sd rev-parse HEAD)" = "$head1"
sd reset -q .env && rm "$S/.env"

cp "$S/Makefile" "$ROOT/Makefile.before"
printf 'staged-scan:\n\t@echo "project scan refuses"; exit 1\n' >>"$S/Makefile"
(cd "$S" && STEP_DONE_GATE=true loop/step-done.sh --commit "scanned" >/dev/null 2>&1)
check "a Makefile staged-scan target is used instead of the built-in scan (refusal → exit 3)" \
  test $? -eq 3 -a "$(sd rev-parse HEAD)" = "$head1"
cp "$ROOT/Makefile.before" "$S/Makefile"

printf '#!/bin/sh\ntouch "$(git rev-parse --git-dir)/hook-ran"\nexit 1\n' >"$S/.git/hooks/pre-commit"
chmod +x "$S/.git/hooks/pre-commit"
(cd "$S" && loop/step-done.sh --commit "hooked" >/dev/null 2>&1)
check "commit hooks run (no --no-verify): a refusing hook → exit 3" \
  test $? -eq 3 -a "$(sd rev-parse HEAD)" = "$head1" -a -f "$S/.git/hook-ran"
check "…and leaves LOG/PLAN exactly as before the call" \
  cmp -s "$LOGF" "$ROOT/log.before"
rm "$S/.git/hooks/pre-commit"
blocks0="$(gate_blocks)"
(cd "$S" && loop/step-done.sh --commit "docs: step 3" >/dev/null 2>&1)
check "re-run after exit 3 is idempotent: committed, step 3 ticked, one more gate block" \
  test $? -eq 0 -a "$(sd log -1 --format=%s)" = "docs: step 3" -a "$(gate_blocks)" -eq $((blocks0 + 1))
eq "…and no other step was ticked on the way" "$(grep -cE '^- \[x\] ' "$PLAN")" 3

(cd "$S" && loop/step-done.sh --commit "docs: nothing left" >/dev/null 2>&1)
check "every step ticked → a tick is refused (exit 3) before anything is edited" \
  test $? -eq 3 -a -z "$(sd status --porcelain -- tasks)"
echo "- [ ] 4. **More:** x — check: make check." >>"$PLAN"
sd add "$PLAN" && sd commit -qm "plan: step 4"
cp "$PLAN" "$ROOT/plan.before"
(cd "$S" && loop/step-done.sh --commit "docs: no tick" --no-tick >/dev/null 2>&1)
check "--no-tick commits the LOG evidence and leaves PLAN alone" \
  test $? -eq 0 -a "$(sd log -1 --format=%s)" = "docs: no tick"
cmp -s "$PLAN" "$ROOT/plan.before"
check "…PLAN unchanged" test $? -eq 0

echo "untracked" >"$S/docs/untracked.md"
(cd "$S" && loop/step-done.sh --commit "docs: all" --all >/dev/null 2>&1)
check "--all stages untracked step files too" has "$(sd show --name-only --format= HEAD)" 'docs/untracked.md'

(cd "$S" && loop/step-done.sh --commit "docs: step 5" --no-tick --push >/dev/null 2>&1)
eq "--push publishes: nothing unreviewed afterwards" "$(cd "$S" && loop/where.sh --json | jq .unreviewed)" 0

sd remote set-url origin "$ROOT/no-such-remote.git"
headp="$(sd rev-parse HEAD)"
pout="$(cd "$S" && loop/step-done.sh --commit "docs: unpushable" --no-tick --push 2>&1)"
prc=$?
check "a push failure → exit 3, but the commit stays" \
  test "$prc" -eq 3 -a "$(sd rev-parse HEAD)" != "$headp" -a "$(sd log -1 --format=%s)" = "docs: unpushable"
check "…and says so" has "$pout" 'push failed'
check "--help works from a subdirectory" has "$(cd "$S/docs" && ../loop/step-done.sh --help)" 'Usage:'

# ════════════════════════════════════════════════════════════════════════════
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
(cd "$P" && git add -A && git commit -qm plan)
J6="$(cd "$P" && loop/where.sh --json)"
eq "the [parallel: A] tag is stripped from the title" "$(jq -r .step_title <<<"$J6")" "Area A"
eq "parallel_group and every unchecked step of it" "$(jq -c '[.parallel_group, .parallel_steps]' <<<"$J6")" '["A",[2,3,5]]'
eq "open_questions counts pending + asked, unasked only pending" "$(jq -c '[.open_questions, .unasked_questions]' <<<"$J6")" '[2,1]'
(cd "$P" && loop/step-done.sh --steps "2 3 5" --commit "docs: group A" >/dev/null 2>&1)
eq "step-done --steps ticks exactly the group" "$(grep -cE '^- \[x\] (2|3|5)\.' "$P/tasks/phase-1_demo/PLAN.md")" 3
eq "the next step waits on its open question only (Q1, not the answered Q3)" \
  "$(cd "$P" && loop/where.sh --json | jq -c '[.step, .waiting_on, .parallel_steps]')" '[4,["Q1"],[]]'
(cd "$P" && loop/step-done.sh --steps "2" --commit "x" >/dev/null 2>&1)
check "step-done --steps refuses an already-ticked step (exit 3)" test $? -eq 3

pg() { (cd "$P" && git "$@") >/dev/null 2>&1; }
pg checkout -qb a && echo a >"$P/docs/a.md" && pg add -A && pg commit -qm a
pg checkout -q main
pg checkout -qb b && echo b >"$P/docs/b.md" && pg add -A && pg commit -qm b
pg checkout -qb c main && echo c >"$P/docs/a.md" && pg add -A && pg commit -qm c
pg checkout -q main
mg() { (cd "$P" && loop/merge-gate.sh "$@") >"$ROOT/mg.out" 2>&1; }
mg a b
check "merge-gate: disjoint branches are green together" test $? -eq 0
mg a c
check "merge-gate: conflicting branches fail" test $? -eq 1
check "…reported as a conflict" has "$(cat "$ROOT/mg.out")" 'does not merge cleanly'
check "merge-gate leaves main untouched" test ! -f "$P/docs/a.md"
mg a nope
check "merge-gate: a typo'd branch is not a conflict" has "$(cat "$ROOT/mg.out")" 'no such branch/commit: nope'

printf '#!/bin/sh\nexit 1\n' >"$P/.git/hooks/commit-msg"
cp "$P/.git/hooks/commit-msg" "$P/.git/hooks/pre-merge-commit"
chmod +x "$P/.git/hooks/commit-msg" "$P/.git/hooks/pre-merge-commit"
mg a b
check "merge-gate: a refusing commit hook does not fail the throwaway merge" test $? -eq 0
rm "$P/.git/hooks/commit-msg" "$P/.git/hooks/pre-merge-commit"

(cd "$P" && HOME="$ROOT/noid" GIT_CONFIG_NOSYSTEM=1 sh -c \
  'mkdir -p "$HOME" && printf "[user]\n\tuseConfigOnly = true\n" >"$HOME/.gitconfig" && loop/merge-gate.sh a b' \
  >"$ROOT/mg.out" 2>&1)
check "merge-gate: works with no git identity configured" test $? -eq 0

n0="$(cd "$P" && git ls-tree --name-only main docs/ | wc -l | tr -d ' ')"
(cd "$P" && MERGE_GATE_CMD="test \$(ls docs | wc -l) -le $((n0 + 1))" loop/merge-gate.sh a >/dev/null 2>&1)
check "merge-gate: a budget gate is green for one branch" test $? -eq 0
(cd "$P" && MERGE_GATE_CMD="test \$(ls docs | wc -l) -le $((n0 + 1))" loop/merge-gate.sh a b >"$ROOT/mg.out" 2>&1)
check "merge-gate: …and RED on the merged tree" test $? -eq 1
check "…reported as a merged-tree failure" has "$(cat "$ROOT/mg.out")" 'RED on the merged tree'

(cd "$P" && MERGE_GATE_BASE=nope loop/merge-gate.sh a >"$ROOT/mg.out" 2>&1)
check "merge-gate: MERGE_GATE_BASE must exist" test $? -eq 1
pg branch -m main master
mg a b
check "merge-gate: falls back to master when there is no main" test $? -eq 0
check "…and says which base it used" has "$(cat "$ROOT/mg.out")" 'worktree off master'
pg branch -m master main

# ════════════════════════════════════════════════════════════════════════════
echo "amendments-guard.sh"
A="$ROOT/a"
fixture "$A"
APLAN="$A/tasks/phase-1_demo/PLAN.md"
cat >>"$APLAN" <<'EOF'
<!-- - A9 · template example, inside a comment · disposition: open -->
- 2026-01-02 — plan: step 3 split into 3a/3b (a plan note, not a finding)
- A1 · 2026-01-02 · MEDIUM `src/a.py:1` — never closed the handle · disposition: open
- A2 · 2026-01-02 · MEDIUM `src/b.py:2` — unresolved path; see #101 · disposition: fixed in abc1234
- A3 · 2026-01-02 · MEDIUM `src/c.py:3` — prefixed ids collide
  a continuation line, and no disposition field at all
- **A4** · 2026-01-03 · MEDIUM `src/d.py:4` — see #101 too · disposition: deferred
- A5 · 2026-01-03 · MEDIUM `src/e.py:5` — retry missing · disposition: open
  → later: disposition: declined — upstream already retries
- A6 · 2026-01-03 · MEDIUM `src/f.py:6` — sounds done, is not · disposition: open

## After the amendments
- A7 · outside the section · disposition: open
EOF
AO="$(cd "$A" && loop/amendments-guard.sh)"
arc=$?
check "counts entries, reads only the LAST disposition word" has "$AO" '6 finding(s), 4 OPEN: A1 A3 A4 A6'
check "warn-only by default (exit 0)" test "$arc" -eq 0
(cd "$A" && loop/amendments-guard.sh --strict >/dev/null)
check "--strict exits 1 on an open finding" test $? -eq 1
cp "$TPL/tasks/_template/PLAN.md" "$APLAN"
echo "- 2026-01-04 — plan: step 2 split in two" >>"$APLAN"
check "no findings but other items → says to look" has "$(cd "$A" && loop/amendments-guard.sh)" '0 findings in `- A<n>` form (1 other item(s)'
mkdir -p "$A/tasks/_template"
cp "$TPL/tasks/_template/PLAN.md" "$A/tasks/_template/PLAN.md"
check "--all skips tasks/_template" lacks "$(cd "$A" && loop/amendments-guard.sh --all)" '_template'
check "--help works from a subdirectory" has "$(cd "$A/tasks" && ../loop/amendments-guard.sh --help)" 'Usage:'

# ════════════════════════════════════════════════════════════════════════════
echo "loop.sh (fake claude)"
L="$ROOT/l"
fixture "$L"
FD="$ROOT/fake"
mkdir -p "$ROOT/bin" "$FD"
cat >"$ROOT/bin/claude" <<'EOF'
#!/usr/bin/env bash
# fake claude: one action per invocation, line N of $FAKE_DIR/seq
d="$FAKE_DIR"
n=$(($(cat "$d/n" 2>/dev/null || echo 0) + 1))
echo "$n" >"$d/n"
printf '%s\n' "$*" >>"$d/args"
act="$(sed -n "${n}p" "$d/seq")"
[ -n "$act" ] || act=DONE
case "$act" in
  CONTINUE | DONE | BLOCKED | GATE_FAILED | PHASE_COMPLETE) echo "did a step" && echo "<<LOOP:$act>>" ;;
  NARRATE) echo "the last iteration stopped with <<LOOP:BLOCKED>>; reconciled" && echo "<<LOOP:CONTINUE>>" ;;
  NOMARK) echo "Ready. What do you need?" ;;
  LIMIT) echo "Claude usage limit reached. Your limit resets at 5pm" && exit 1 ;;
  SHA429) echo "error: commit a4291bc rejected by a hook" && exit 1 ;;
  FAIL) echo "boom" && exit 1 ;;
  HOLD) echo $$ >"$d/pid" && sleep 3 && touch "$d/survived" && echo "<<LOOP:DONE>>" ;;
  BG) sleep 20 >/dev/null 2>&1 & echo $! >"$d/bgpid" && echo "<<LOOP:DONE>>" ;;
esac
EOF
chmod +x "$ROOT/bin/claude"
seqs() { # seqs <action>... — reset the fake's script
  rm -f "$FD/n" "$FD/args" "$FD/pid" "$FD/survived"
  printf '%s\n' "$@" >"$FD/seq"
}
calls() { cat "$FD/n" 2>/dev/null || echo 0; }
lp() { # lp <loop.sh args> — run the loop on the fixture; rc in $?, output in $LO/$LE
  (cd "$L" && FAKE_DIR="$FD" PATH="$ROOT/bin:$PATH" LIMIT_WAIT=0 FAIL_BACKOFF=0 loop/loop.sh "$@") \
    >"$ROOT/lp.out" 2>"$ROOT/lp.err"
  local rc=$?
  LO="$(cat "$ROOT/lp.out")"
  LE="$(cat "$ROOT/lp.err")"
  return "$rc"
}

seqs CONTINUE DONE
lp
eq "CONTINUE then DONE → exit 0 after 2 iterations" "$? $(calls)" "0 2"
seqs BLOCKED
lp
eq "BLOCKED → exit 3" "$? $(calls)" "3 1"
seqs GATE_FAILED
lp
eq "GATE_FAILED → exit 4" "$? $(calls)" "4 1"
seqs PHASE_COMPLETE DONE
lp
eq "PHASE_COMPLETE rolls on by default" "$? $(calls)" "0 2"
seqs PHASE_COMPLETE DONE
lp --stop-on-phase
eq "…and stops under --stop-on-phase (exit 5)" "$? $(calls)" "5 1"
seqs NARRATE DONE
lp
eq "a marker quoted in narration does not stop the loop — the last one decides" "$? $(calls)" "0 2"
seqs CONTINUE CONTINUE CONTINUE
lp --max-iterations 2
eq "the iteration cap → exit 6" "$? $(calls)" "6 2"
seqs NOMARK
lp
eq "no marker (supervised) → exit 1" "$? $(calls)" "1 1"
check "…and says why on stderr" has "$LE" 'no completion marker'
seqs NOMARK DONE
lp --continuous
eq "no marker under --continuous → retried" "$? $(calls)" "0 2"
seqs FAIL
lp
eq "claude failing (supervised) → exit 1" "$? $(calls)" "1 1"
check "…with the reason on stderr (stderr is not silenced)" has "$LE" 'exited non-zero'
seqs SHA429
lp
eq "'429' inside a commit sha is not a rate limit" "$? $(calls)" "1 1"
seqs LIMIT DONE
lp --max-iterations 1
eq "a rate limit is waited out and the iteration is not consumed" "$? $(calls)" "0 2"
seqs LIMIT LIMIT LIMIT LIMIT LIMIT LIMIT
export LIMIT_MAX=3
lp
lrc=$?
unset LIMIT_MAX
eq "consecutive rate limits are bounded by LIMIT_MAX" "$lrc $(calls)" "1 4"
check "…and the stop says so" has "$LE" 'LIMIT_MAX=3'

lp --bogus
eq "an unknown flag → exit 2" "$?" 2
check "…with the message on stderr" has "$LE" 'unknown arg: --bogus'
lp --max-iterations 2x
eq "--max-iterations 2x → exit 2" "$?" 2
lp --max-iterations
eq "--max-iterations with no value → exit 2" "$?" 2

seqs DONE
lp --model opus
check "--model is passed through" has "$(cat "$FD/args")" '--model opus'
seqs DONE
lp
check "no --model → no empty argument (bash 3.2 empty-array path)" lacks "$(cat "$FD/args")" '--model'
seqs DONE
lp --dry-run
eq "--dry-run runs nothing" "$? $(calls)" "0 0"
check "…and prints the prompt" has "$LO" '---- prompt ----'
check "--help works from a subdirectory, without the shebang" \
  grep -qE '^loop/loop.sh — the bounded' <<<"$(cd "$L/tasks" && ../loop/loop.sh --help | head -1)"

printf 'export X="$UNSET_IN_ENV_SH"\n' >"$L/loop/env.sh"
seqs DONE
lp
check "a broken loop/env.sh stops the loop, visibly" test $? -ne 0 -a "$(calls)" = 0
check "…naming the problem" has "$LE" 'UNSET_IN_ENV_SH'
rm "$L/loop/env.sh"

LOCKF="$(git -C "$L" rev-parse --absolute-git-dir)/.agent-loop.lock"
if command -v flock >/dev/null 2>&1; then
  (flock -n 9 && sleep 3) 9>"$LOCKF" &
  holder=$!
  sleep 0.5
  seqs DONE
  lp
  eq "a second loop on the same tree is refused" "$? $(calls)" "1 0"
  check "…with the reason on stderr" has "$LE" 'already running'
  wait "$holder"

  seqs BG
  lp
  BGPIDS="$BGPIDS $(cat "$FD/bgpid" 2>/dev/null)"
  seqs DONE
  lp
  eq "a process the agent left running does not hold the lock" "$? $(calls)" "0 1"
  # shellcheck disable=SC2086 # reason: pids split on purpose
  kill $BGPIDS 2>/dev/null
  BGPIDS=""
else
  echo "  skip lock tests: flock not installed"
fi

(cd "$L" && git worktree add -q "$ROOT/l-wt" 2>/dev/null)
seqs DONE
(cd "$ROOT/l-wt" && FAKE_DIR="$FD" PATH="$ROOT/bin:$PATH" loop/loop.sh >/dev/null 2>&1)
check "in a linked worktree the lock lives in that worktree's git dir" \
  test -f "$(git -C "$ROOT/l-wt" rev-parse --absolute-git-dir)/.agent-loop.lock"

seqs HOLD
(cd "$L" && export FAKE_DIR="$FD" PATH="$ROOT/bin:$PATH" && exec loop/loop.sh) >"$ROOT/lp.out" 2>"$ROOT/lp.err" &
lpid=$!
for _ in $(seq 1 50); do
  [[ -f "$FD/pid" ]] && break
  sleep 0.1
done
kill -TERM "$lpid"
wait "$lpid"
src=$?
sleep 4
check "SIGTERM to the loop → exit 143" test "$src" -eq 143
check "…and the running agent is stopped with it" test ! -f "$FD/survived"
check "…and says so" has "$(cat "$ROOT/lp.err")" 'interrupted by SIGTERM'

echo
echo "$RUN run, $FAILED failed"
[[ "$FAILED" -eq 0 ]]
