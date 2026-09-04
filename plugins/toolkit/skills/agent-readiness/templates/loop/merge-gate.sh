#!/usr/bin/env bash
# hack/merge-gate.sh — the prerequisite for parallel objectives.
#
# AGENTS §6 already sanctions worktrees ("parallel work on the same code -> a git
# worktree; independent work -> separate commits") and the repo has never used one
# (`git worktree list` = 1). M2 has twelve objectives and several touch no shared
# code — chaos experiments, k6 scenarios, the ha overlay, dashboards — so fan-out is
# the largest available speed-up on ~160 serial iterations.
#
# WHY THIS SCRIPT MUST EXIST FIRST. Two branches that are each green can be RED
# together: the LOC rows are global, `.testcount` is a single ratchet, and generated
# code (`db/gen`, `proto/gen`) is committed. Verifying per branch proves nothing
# about the merge. The single-instance lock in loop/loop.sh exists for exactly this
# class of collision; fan-out is only safe with a gate on the MERGED tree.
#
# Usage:  hack/merge-gate.sh <branch> [<branch> ...]
#
# It merges each branch into a throwaway worktree off main, in order, and runs the
# full gate ONCE on the result. Nothing is pushed and main is never touched: the
# caller merges for real only after this exits 0.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$REPO_ROOT"
[ "$#" -ge 1 ] || { echo "usage: hack/merge-gate.sh <branch> [<branch> ...]" >&2; exit 2; }

fail() { echo "!! $*" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || fail "working tree is dirty — the gate needs a clean base"

WT="$(mktemp -d -t ticketing-mergegate-XXXXXX)"
# `rm -rf` after a failed `worktree remove` would leave a stale registration in
# .git/worktrees, so prune unconditionally.
cleanup() {
  git worktree remove --force "$WT" >/dev/null 2>&1 || true
  rm -rf "$WT"
  git worktree prune >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo ">> throwaway worktree off main: $WT"
git worktree add --detach "$WT" main >/dev/null || fail "could not create the worktree"

# Resolve every ref BEFORE merging anything: a typo'd branch name must not be
# reported as a merge conflict.
for b in "$@"; do
  git rev-parse --verify --quiet "$b^{commit}" >/dev/null \
    || fail "no such branch/commit: $b"
done

for b in "$@"; do
  echo ">> merging $b"
  if ! out="$(git -C "$WT" merge --no-ff --no-edit "$b" 2>&1)"; then
    echo "$out" | sed 's/^/   /' >&2
    fail "$b does not merge cleanly onto main + the branches before it (conflicting
   paths above). Resolve on the BRANCH, never inside this throwaway worktree —
   its whole purpose is that the result is discarded."
  fi
done

echo ">> the gate, on the MERGED tree (this is the only run that proves anything)"
if ( cd "$WT" && make verify ); then
  echo ">> MERGE GATE OK — these branches are green TOGETHER: $*"
  echo ">> now merge them for real, in this order, and push."
  exit 0
fi
fail "make verify is RED on the merged tree though each branch may be green alone.
   Usual causes: a global LOC row crossed only in the union, a .testcount ratchet
   both branches raised, or committed generated code regenerated on both sides.
   Fix on the branches, never on the merge."
