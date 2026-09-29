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

echo
echo "$RUN run, $FAILED failed"
[[ "$FAILED" -eq 0 ]]
