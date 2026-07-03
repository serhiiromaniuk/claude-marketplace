#!/usr/bin/env bash
# loop/loop.sh — the bounded agent-loop harness.
#
# Re-feeds loop/PROMPT.md to a fresh `claude -p` agent each iteration. Progress
# lives on disk (tasks/ + loop/STATE.md) and in git, NOT in the context window.
# Stops on a completion marker or when it hits --max-iterations (the primary
# safety). See loop/README.md and rules/AGENTS.md §4.
#
# Usage:
#   loop/loop.sh                      # default cap (8)
#   loop/loop.sh --max-iterations 20
#   loop/loop.sh --dry-run            # show what would run, run nothing
#   loop/loop.sh --prompt loop/PROMPT.md
#
# Requires the `claude` CLI on PATH. Run from the repo root.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# If CLAUDE_CONFIG_DIR is already exported, respect it so every iteration uses
# the intended config (agents, settings, permissions) regardless of which
# terminal launched the loop. Otherwise leave it unset and let `claude` use its
# own default.
if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
  export CLAUDE_CONFIG_DIR
fi

MAX_ITERS=8
PROMPT_FILE="loop/PROMPT.md"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-iterations) MAX_ITERS="$2"; shift 2 ;;
    --prompt)         PROMPT_FILE="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=1; shift ;;
    -h|--help)        grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$PROMPT_FILE" ]] || { echo "prompt not found: $PROMPT_FILE" >&2; exit 1; }

# Completion markers the agent emits (rules/AGENTS.md §4).
#   CONTINUE_MARKERS => keep looping (more steps, or a phase finished+tagged and
#                       the agent rolls into the next phase autonomously).
#   STOP_MARKERS      => stop and hand back to a human: the project goal reached,
#                       a failed hard gate, or the escape hatch.
CONTINUE_MARKERS=("<<LOOP:CONTINUE>>" "<<LOOP:PHASE_COMPLETE>>")
STOP_MARKERS=("<<LOOP:DONE>>" "<<LOOP:BLOCKED>>" "<<LOOP:GATE_FAILED>>")

echo ">> loop | repo=$REPO_ROOT | prompt=$PROMPT_FILE | max-iterations=$MAX_ITERS"
echo ">> CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR:-<default>}"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ">> --dry-run: would run \`claude -p \"\$(cat $PROMPT_FILE)\"\` up to $MAX_ITERS times."
  echo "---- prompt ----"; cat "$PROMPT_FILE"; exit 0
fi
command -v claude >/dev/null || { echo "claude CLI not on PATH" >&2; exit 1; }

for ((i = 1; i <= MAX_ITERS; i++)); do
  echo ""; echo "==================== iteration $i / $MAX_ITERS ===================="

  # One fresh agent per iteration. Scope tools to what a step needs; widen only
  # if you trust the run. Auto mode keeps a classifier in the loop for safety.
  out="$(claude -p "$(cat "$PROMPT_FILE")" --permission-mode auto 2>&1)" || {
    echo ">> claude exited non-zero on iteration $i — stopping for review." >&2
    echo "$out"; exit 1
  }
  echo "$out"

  for m in "${STOP_MARKERS[@]}"; do
    if grep -qF "$m" <<<"$out"; then
      echo ""; echo ">> stop marker: $m  (iteration $i). Handing back to human."
      exit 0
    fi
  done

  matched=""
  for m in "${CONTINUE_MARKERS[@]}"; do
    if grep -qF "$m" <<<"$out"; then matched="$m"; break; fi
  done
  if [[ -z "$matched" ]]; then
    echo ""; echo ">> no completion marker found on iteration $i — stopping (treat as needs-attention)." >&2
    exit 1
  fi
  echo ">> $matched — continuing."
done

echo ""; echo ">> reached max-iterations ($MAX_ITERS) without a terminal marker. Stopping (safety cap)."
echo ">> review loop/STATE.md and the active task LOG.md, then re-run to continue."
