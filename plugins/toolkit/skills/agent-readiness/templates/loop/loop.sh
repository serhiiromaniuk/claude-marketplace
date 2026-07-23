#!/usr/bin/env bash
# loop/loop.sh — the bounded agent-loop harness.
#
# Re-feeds loop/PROMPT.md to a fresh `claude -p` agent each iteration. Progress
# lives on disk (tasks/ + loop/STATE.md) and in git, NOT in the context window.
# The loop reads where it left off, does ONE verified increment, commits, and
# emits a marker. See loop/README.md and rules/AGENTS.md §4.
#
# Usage:
#   loop/loop.sh                                   # default cap (8), supervised
#   loop/loop.sh --max-iterations 20
#   loop/loop.sh --model opus                      # pin the driver model
#   loop/loop.sh --skip-permissions               # no permission prompts (unattended)
#   loop/loop.sh --continuous                      # only DONE/BLOCKED stop; retry the rest
#   loop/loop.sh --dry-run                         # show what would run, run nothing
#   loop/loop.sh --prompt loop/PROMPT.md
#
# Long unattended run (survives terminal/SSH close via tmux):
#   tmux new -s loop
#   loop/loop.sh --continuous --model opus --skip-permissions --max-iterations 1000
#   # detach: Ctrl-b then d   ·   reattach: tmux attach -t loop
#
# Requires the `claude` CLI on PATH. Run from the repo root.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Optional: a project drops loop/env.sh to put its own toolchain on PATH (or set
# any env) for every child agent. `claude -p` spawns NON-interactive shells that
# don't source ~/.profile, so a user-space toolchain would otherwise be invisible
# and the verify step would fail spuriously. Keep it domain-specific and local.
[[ -f "loop/env.sh" ]] && source "loop/env.sh"

# If CLAUDE_CONFIG_DIR is already exported, respect it so every iteration uses
# the intended config (agents, settings, permissions) regardless of which
# terminal launched the loop.
if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then export CLAUDE_CONFIG_DIR; fi

MAX_ITERS=8
PROMPT_FILE="loop/PROMPT.md"
MODEL=""
DRY_RUN=0
CONTINUOUS=0
PERM_FLAG=(--permission-mode auto)   # default: supervised (classifier in the loop)
MAX_CONSEC=5                         # stop after this many consecutive hard failures

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-iterations)   MAX_ITERS="$2"; shift 2 ;;
    --prompt)           PROMPT_FILE="$2"; shift 2 ;;
    --model)            MODEL="$2"; shift 2 ;;
    --skip-permissions) PERM_FLAG=(--dangerously-skip-permissions); shift ;;
    --continuous)       CONTINUOUS=1; shift ;;
    --dry-run)          DRY_RUN=1; shift ;;
    -h|--help)          grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$PROMPT_FILE" ]] || { echo "prompt not found: $PROMPT_FILE" >&2; exit 1; }

MODEL_FLAG=(); [[ -n "$MODEL" ]] && MODEL_FLAG=(--model "$MODEL")

# Completion markers the agent emits (rules/AGENTS.md §4).
#   STOP_ALWAYS     => halt even in --continuous mode: the project goal is
#                      reached (DONE) or a human is genuinely required (BLOCKED).
#                      Never suppress these.
#   STOP_SUPERVISED => also halt in the default (supervised) mode: a failed hard
#                      gate. In --continuous mode this is retried so the loop can
#                      fix the work next iteration (bounded by the 3-try escape
#                      hatch -> BLOCKED).
#   CONTINUE        => keep looping (a step done, or a phase finished+tagged and
#                      the agent rolls into the next phase autonomously).
STOP_ALWAYS=("<<LOOP:DONE>>" "<<LOOP:BLOCKED>>")
STOP_SUPERVISED=("<<LOOP:GATE_FAILED>>")
CONTINUE_MARKERS=("<<LOOP:CONTINUE>>" "<<LOOP:PHASE_COMPLETE>>" "<<LOOP:GATE_FAILED>>")

echo ">> loop | repo=$REPO_ROOT | prompt=$PROMPT_FILE | max-iterations=$MAX_ITERS"
echo ">> model=${MODEL:-<config default>} | perms=${PERM_FLAG[*]} | continuous=$CONTINUOUS"
echo ">> CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR:-<default>}"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ">> --dry-run: would run up to $MAX_ITERS times:"
  echo "   claude -p \"\$(cat $PROMPT_FILE)\" ${MODEL_FLAG[*]} ${PERM_FLAG[*]}"
  echo "---- prompt ----"; cat "$PROMPT_FILE"; exit 0
fi
command -v claude >/dev/null || { echo "claude CLI not on PATH" >&2; exit 1; }

consec_fail=0
for ((i = 1; i <= MAX_ITERS; i++)); do
  echo ""; echo "==================== iteration $i / $MAX_ITERS ===================="

  # One fresh agent per iteration. Scope tools to what a step needs; widen only
  # if you trust the run. `auto` keeps a classifier in the loop for safety;
  # --skip-permissions removes it (unattended) — then the human-only boundary in
  # AGENTS.md + the BLOCKED marker are the only guardrail.
  if ! out="$(claude -p "$(cat "$PROMPT_FILE")" "${MODEL_FLAG[@]}" "${PERM_FLAG[@]}" 2>&1)"; then
    echo "$out"
    if [[ "$CONTINUOUS" -eq 1 ]]; then
      consec_fail=$((consec_fail + 1))
      echo ">> claude exited non-zero (consecutive failures: $consec_fail/$MAX_CONSEC)."
      if [[ $consec_fail -ge $MAX_CONSEC ]]; then
        echo ">> $MAX_CONSEC consecutive failures — stopping (likely auth/API/network)." >&2; exit 1
      fi
      sleep $((15 * consec_fail)); continue    # linear backoff
    fi
    echo ">> claude exited non-zero on iteration $i — stopping for review." >&2; exit 1
  fi
  echo "$out"

  # Hard terminals — always honoured; GATE_FAILED also stops in supervised mode.
  stop=""
  for m in "${STOP_ALWAYS[@]}"; do grep -qF "$m" <<<"$out" && stop="$m"; done
  if [[ "$CONTINUOUS" -eq 0 ]]; then
    for m in "${STOP_SUPERVISED[@]}"; do grep -qF "$m" <<<"$out" && stop="$m"; done
  fi
  if [[ -n "$stop" ]]; then
    echo ""; echo ">> stop marker: $stop  (iteration $i). Handing back to a human."; exit 0
  fi

  # A recognized continue marker resets the failure counter.
  matched=""
  for m in "${CONTINUE_MARKERS[@]}"; do grep -qF "$m" <<<"$out" && { matched="$m"; break; }; done
  if [[ -n "$matched" ]]; then
    consec_fail=0; echo ">> $matched — continuing."; continue
  fi

  # No marker at all: a protocol miss.
  if [[ "$CONTINUOUS" -eq 1 ]]; then
    consec_fail=$((consec_fail + 1))
    echo ">> no completion marker (consecutive failures: $consec_fail/$MAX_CONSEC) — retrying."
    if [[ $consec_fail -ge $MAX_CONSEC ]]; then
      echo ">> $MAX_CONSEC consecutive protocol misses — stopping for review." >&2; exit 1
    fi
    sleep $((15 * consec_fail)); continue
  fi
  echo ">> no completion marker on iteration $i — stopping (needs attention)." >&2; exit 1
done

echo ""; echo ">> reached max-iterations ($MAX_ITERS). Stopping (safety cap)."
echo ">> review loop/STATE.md and the active task LOG.md, then re-run to continue."
