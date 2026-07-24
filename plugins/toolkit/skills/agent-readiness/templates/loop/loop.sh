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
#   loop/loop.sh --continuous                      # DONE/BLOCKED/GATE_FAILED stop; retry transients
#   loop/loop.sh --dry-run                         # show what would run, run nothing
#   loop/loop.sh --prompt loop/PROMPT.md
#
# Long unattended run (survives terminal/SSH close via tmux):
#   tmux new -s loop
#   loop/loop.sh --continuous --model opus --skip-permissions --max-iterations 1000
#   # detach: Ctrl-b then d   ·   reattach: tmux attach -t loop
#
# CONFIG HYGIENE: run headless under a CLEAN CLAUDE_CONFIG_DIR with NO
# interactive/greeting plugins. Such plugins inject prompts/hooks that make the
# headless `claude -p` agent answer conversationally instead of executing
# PROMPT.md (a "…Ready. What do you need?" reply with no marker). The repo's own
# .claude/agents load regardless of config dir.
#
# Requires the `claude` CLI on PATH. Run from the repo root.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Single-instance guard — two loops racing the same tree clobber each other's
# commits. Refuse to start if one is already running on this repo. (flock is
# best-effort; skipped where unavailable.)
LOCK_DIR="$REPO_ROOT/.git"; [[ -d "$LOCK_DIR" ]] || LOCK_DIR="${TMPDIR:-/tmp}"
exec 9>"$LOCK_DIR/.agent-loop.lock" 2>/dev/null || true
if command -v flock >/dev/null 2>&1 && ! flock -n 9; then
  echo ">> another loop is already running on this repo (lock: $LOCK_DIR/.agent-loop.lock). Refusing to start." >&2
  exit 1
fi

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
LIMIT_WAIT=${LIMIT_WAIT:-1800}       # seconds to wait out a usage/rate limit (default 30m)
# Signals meaning "session/usage/rate limit" — expected, NOT a failure. Checked
# ONLY on a failed run, so a successful iteration whose output happens to mention
# rate-limiting/429 never false-trips. When seen: wait LIMIT_WAIT, retry the SAME
# iteration (no failure count, no iteration consumed) — rides out multi-hour limits.
LIMIT_RE='usage limit|rate limit|rate.?limited|429|Too Many Requests|quota|resets? at|Please try again|overloaded|capacity'

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
#   STOP_ALWAYS => halt even in --continuous mode. All three need a human: DONE
#                  (goal reached), BLOCKED (stuck / boundary), and GATE_FAILED (a
#                  hard gate failed — often a real block the agent can't self-fix
#                  in scope; do NOT spin on it, hand back). Never suppress these.
#   CONTINUE    => keep looping (a step done, or a phase finished+tagged and the
#                  agent rolls into the next phase autonomously).
STOP_ALWAYS=("<<LOOP:DONE>>" "<<LOOP:BLOCKED>>" "<<LOOP:GATE_FAILED>>")
CONTINUE_MARKERS=("<<LOOP:CONTINUE>>" "<<LOOP:PHASE_COMPLETE>>")

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
  echo ""; echo "╭─────────── iteration $i/$MAX_ITERS · $(date '+%Y-%m-%d %H:%M:%S %Z') ───────────╮"

  # One fresh agent per iteration. Scope tools to what a step needs; widen only
  # if you trust the run. `auto` keeps a classifier in the loop for safety;
  # --skip-permissions removes it (unattended) — then the human-only boundary in
  # AGENTS.md + the BLOCKED marker are the only guardrail.
  if ! out="$(claude -p "$(cat "$PROMPT_FILE")" "${MODEL_FLAG[@]}" "${PERM_FLAG[@]}" 2>&1)"; then
    echo "$out"
    # Session/usage/rate limit — checked ONLY on a failed run, so a successful
    # iteration mentioning rate-limiting/429 never trips it. Wait it out, retry
    # the SAME iteration (no failure count, no iteration consumed).
    if grep -qiE "$LIMIT_RE" <<<"$out"; then
      echo ">> [$(date '+%Y-%m-%d %H:%M:%S %Z')] usage/rate limit detected — waiting ${LIMIT_WAIT}s, then retrying this iteration (not counted as a failure)."
      sleep "$LIMIT_WAIT"; i=$((i - 1)); continue
    fi
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

  # Hard terminals — always honoured (DONE / BLOCKED / GATE_FAILED).
  stop=""
  for m in "${STOP_ALWAYS[@]}"; do grep -qF "$m" <<<"$out" && stop="$m"; done
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
