#!/usr/bin/env bash
# loop/where.sh — the loop's position oracle.
#
# WHY THIS EXISTS (measured, not theoretical). A Ralph loop re-reads its control
# plane in every fresh iteration. Those files are append-only by nature, so they
# grow, and the growth is quadratic: each iteration re-reads everything every
# earlier iteration wrote. On one real project the pointer files reached 181 KB
# (a "you are here" section of 87,000 B; a ledger row of 41,717 B on ONE line)
# and iteration wall time went from 12-17 min to 47-211 min on the same model,
# same machine, same discipline. Compacting them is half the fix. The other half
# is this script: a *derived* answer cannot rot back into prose.
#
# Everything below is already machine-readable — no parsing of narrative:
#   the `in-progress` row of tasks/INDEX.md · the `- [ ]`/`- [x]` checkboxes of
#   the active PLAN.md · the `Governing spec:` line of its BRIEF.md · the newest
#   `## ` heading of its LOG.md · loop/STATE.md's gate row · git status.
#
# loop/PROMPT.md §1 consumes the JSON and reads ONLY the files listed in `.read`.
# That is what keeps a CLOSED task's LOG.md out of context structurally instead
# of by asking the agent nicely — closed folders are never named.
#
# Usage:
#   loop/where.sh            # JSON (default) — what the loop consumes
#   loop/where.sh --read     # just the file list, one path per line
#   loop/where.sh --human    # one-screen summary for a person (see /status)
#
# Exit 0 = position determined (read .needs_open / .needs_plan / .spec_stub to
# see what the iteration owes). Exit 2 = cannot determine; JSON still prints with
# .error set.
#
# ADAPTING IT: only the five paths below are project-specific. If your layout
# differs (no rules/ dir, specs elsewhere), change them here and nowhere else.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

INDEX="${LOOP_INDEX:-tasks/INDEX.md}"
STATE="${LOOP_STATE:-loop/STATE.md}"
TASKS_DIR="${LOOP_TASKS_DIR:-tasks}"
TEMPLATE_DIR="${LOOP_TEMPLATE_DIR:-tasks/_template}"
RULES=()
for f in rules/RULES.md rules/AGENTS.md; do [[ -f "$f" ]] && RULES+=("$f"); done

MODE=json
case "${1:-}" in
  ""|--json) MODE=json ;;
  --read)    MODE=read ;;
  --human)   MODE=human ;;
  -h|--help) grep '^#' "$0" | sed '1d; s/^# \{0,1\}//'; exit 0 ;;
  *) echo "unknown arg: $1 (try --help)" >&2; exit 2 ;;
esac

ERROR=""

# ── the ledger row ───────────────────────────────────────────────────────────
# The single row of tasks/INDEX.md whose status is in-progress. Its first
# markdown link is the task folder.
row="$(grep -m1 -E '\|[^|]*in-progress[^|]*\|' "$INDEX" 2>/dev/null || true)"
folder=""; task=""; phase=""
if [[ -n "$row" ]]; then
  rel="$(printf '%s' "$row" | grep -oE '\]\(\./[^)]+\)' | head -1 | sed -E 's#^\]\(\./##; s#\)$##; s#/$##')"
  [[ -n "$rel" ]] && folder="$TASKS_DIR/$rel"
  task="$(basename "${folder:-}")"
  phase="$(printf '%s' "$row" | awk -F'|' 'NF>3 {gsub(/^[ \t`]+|[ \t`]+$/,"",$3); print $3}')"
fi
if [[ -z "$row" ]]; then
  ERROR="no in-progress row in $INDEX — open the next todo task from $TEMPLATE_DIR"
fi
needs_open=false
[[ -n "$row" && ( -z "$folder" || ! -d "$folder" ) ]] && needs_open=true

BRIEF=""; PLAN=""; LOG=""
if [[ -n "$folder" && -d "$folder" ]]; then
  [[ -f "$folder/BRIEF.md" ]] && BRIEF="$folder/BRIEF.md"
  [[ -f "$folder/PLAN.md"  ]] && PLAN="$folder/PLAN.md"
  [[ -f "$folder/LOG.md"   ]] && LOG="$folder/LOG.md"
fi

# ── step position: the PLAN's checkboxes ARE the state machine ───────────────
steps=0; done_steps=0; step=0; step_title=""; all_done=false
if [[ -n "$PLAN" ]]; then
  steps="$(grep -cE '^- \[[ xX]\] ' "$PLAN" || true)"
  done_steps="$(grep -cE '^- \[[xX]\] ' "$PLAN" || true)"
fi
needs_plan=false
if [[ -z "$PLAN" || "$steps" -eq 0 ]]; then
  needs_plan=true
else
  if [[ "$done_steps" -ge "$steps" ]]; then
    step="$steps"; all_done=true
  else
    step=$((done_steps + 1))
    # A step title may wrap onto indented continuation lines and end at a bolded
    # `:**`. Join up to 4 lines, cut there, strip marker/number/emphasis.
    # NB: awk runs END on `exit`, so the fallback print is guarded by `p`.
    raw="$(awk '/^- \[ \] /{f=1}
                f{buf = buf " " $0; if (buf ~ /:\*\*/ || ++n >= 4) {print buf; p=1; exit}}
                END{if (!p && f && buf != "") print buf}' "$PLAN")"
    step_title="$(printf '%s' "$raw" \
      | sed -E 's/:\*\*.*$//; s/^ *- \[ \] *//; s/^[0-9]+[a-z]?\.? *//; s/\*\*//g;
                s/[[:space:]]+/ /g; s/^ +//; s/ +$//' | cut -c1-160)"
  fi
fi

# ── the governing spec, and whether it is still a stub ───────────────────────
# BRIEF.md's `Governing spec:` line; the first backticked path on it. Optional —
# a project with no spec layer simply leaves the line out.
spec=""; spec_stub=false
if [[ -n "$BRIEF" ]]; then
  spec="$(grep -m1 -E '^[-*] *Governing spec:' "$BRIEF" \
    | grep -oE '`[A-Za-z0-9._/-]+\.md`' | head -1 | tr -d '`')"
fi
if [[ -n "$spec" && -f "$spec" ]]; then
  # Convention: an unwritten spec carries a STUB/TODO marker in its header block.
  # Scoped to the header on purpose — a finished spec may well mention the word
  # "STUB" further down, recording that it stopped being one.
  head -12 "$spec" | grep -qE '\*\*STUB|TODO\(spec\)' && spec_stub=true
elif [[ -n "$spec" ]]; then
  spec_stub=true   # named but absent — writing it IS the iteration
fi

# ── tree state (PROMPT §1's reconcile branch) ────────────────────────────────
tree_clean=true
[[ -n "$(git status --porcelain 2>/dev/null)" ]] && tree_clean=false
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"

# ── last result: the newest LOG.md entry heading ─────────────────────────────
# Deliberately NOT read from the pointer files. Deriving it here is what lets a
# normal increment write prose in ONE place (its LOG) instead of three.
last_result=""
if [[ -n "$LOG" ]]; then
  last_result="$(grep -E '^## ' "$LOG" | tail -n1 \
    | sed -E 's/^## *//; s/[[:space:]]+/ /g; s/ $//' | cut -c1-240)"
fi

# ── the non-derivable bits STATE.md still owns ───────────────────────────────
gate=""; blocked="unknown"
if [[ -f "$STATE" ]]; then
  gate="$(grep -m1 -E '\*\*Gate status\*\*' "$STATE" \
    | awk -F'|' '{gsub(/^[ 	]+|[ 	]+$/,"",$3); gsub(/`/,"",$3); print $3}' | cut -c1-200)"
  blocked="$(grep -m1 -E '\*\*Blocked\?\*\*' "$STATE" \
    | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$3); gsub(/`/,"",$3); print $3}' | cut -c1-80)"
fi

# ── what this iteration must read ────────────────────────────────────────────
READ=("${RULES[@]}")
[[ -f "$STATE" ]] && READ+=("$STATE")
if [[ "$needs_open" == true ]]; then
  READ+=("$TEMPLATE_DIR/BRIEF.md" "$TEMPLATE_DIR/PLAN.md")
else
  [[ -n "$BRIEF" ]] && READ+=("$BRIEF")
  [[ -n "$PLAN"  ]] && READ+=("$PLAN")
  [[ -n "$LOG"   ]] && READ+=("$LOG")
fi
[[ -n "$spec" ]] && READ+=("$spec")

# ── output ───────────────────────────────────────────────────────────────────
jesc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\000-\037'; }

case "$MODE" in
read)
  printf '%s\n' "${READ[@]}"
  ;;
human)
  echo "phase       : ${phase:-?}"
  echo "task        : ${task:-<none>}  [${folder:-no folder}]"
  if [[ "$needs_open" == true ]]; then
    echo "step        : NO FOLDER — open the task from $TEMPLATE_DIR; that IS this iteration"
  elif [[ "$needs_plan" == true ]]; then
    echo "step        : NO PLAN — the planner subagent decomposes BRIEF+spec; that IS this iteration"
  elif [[ "$all_done" == true ]]; then
    echo "step        : all $steps steps ✓ — close the task (OUTCOME.md), check the gate, advance"
  else
    echo "step        : $step of $steps — $step_title"
  fi
  [[ -n "$spec" ]] && echo "spec        : $spec$([[ "$spec_stub" == true ]] && echo '  [STUB — write it first]')"
  echo "gate        : ${gate:-<none recorded>}"
  echo "tree        : $([[ "$tree_clean" == true ]] && echo clean || echo 'DIRTY — reconcile before starting (PROMPT §1)') on $branch"
  echo "last result : ${last_result:-<none>}"
  echo "read        : ${READ[*]}"
  [[ -n "$ERROR" ]] && echo "error       : $ERROR"
  ;;
json)
  printf '{\n'
  printf '  "phase": "%s",\n'         "$(jesc "$phase")"
  printf '  "task": "%s",\n'          "$(jesc "$task")"
  printf '  "folder": "%s",\n'        "$(jesc "$folder")"
  printf '  "needs_open": %s,\n'      "$needs_open"
  printf '  "needs_plan": %s,\n'      "$needs_plan"
  printf '  "step": %s,\n'            "$step"
  printf '  "steps": %s,\n'           "$steps"
  printf '  "all_steps_done": %s,\n'  "$all_done"
  printf '  "step_title": "%s",\n'    "$(jesc "$step_title")"
  printf '  "spec": "%s",\n'          "$(jesc "$spec")"
  printf '  "spec_stub": %s,\n'       "$spec_stub"
  printf '  "gate": "%s",\n'          "$(jesc "$gate")"
  printf '  "blocked": "%s",\n'       "$(jesc "$blocked")"
  printf '  "tree_clean": %s,\n'      "$tree_clean"
  printf '  "branch": "%s",\n'        "$(jesc "$branch")"
  printf '  "last_result": "%s",\n'   "$(jesc "$last_result")"
  printf '  "read": ['
  for i in "${!READ[@]}"; do
    [[ "$i" -gt 0 ]] && printf ', '
    printf '"%s"' "$(jesc "${READ[$i]}")"
  done
  printf '],\n'
  printf '  "error": "%s"\n'          "$(jesc "$ERROR")"
  printf '}\n'
  ;;
esac

[[ -n "$ERROR" ]] && exit 2
exit 0
