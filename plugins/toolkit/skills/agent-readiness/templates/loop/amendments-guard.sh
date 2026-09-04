#!/usr/bin/env bash
# hack/amendments-guard.sh — make deferred findings arrive as a NUMBER.
#
# PROMPT §4b defers every MEDIUM/LOW reviewer finding to the active PLAN's
# `## Amendments`. The mechanism works; what never existed is a count of how many
# are still OPEN. loop/STATE.md maintains its open list by hand, and CF-6
# admits its reservations' "only check is re-measure at the M1 close".
#
# HOW IT DECIDES, and why not the obvious way. The first version of this script
# grepped ids out of the whole PLAN and matched them against 400 commit subjects.
# Its one field result — "16 of 16 discharged" on m1-12 — was false at both ends:
# the ids it found were cross-references to OTHER objectives' amendments, and the
# "evidence" was bare numbers inside unrelated strings ('.29.', '=202', '/35/').
# So the commit grep is gone. An amendment's disposition is written in the
# amendment, by the increment that dealt with it, which is both local and exact.
#
# Two entry formats are in use and both are supported, scoped to `## Amendments`:
#   `- **#162 (M1)** …`   m1-07 .. m1-10   (global #NNN sequence)
#   `12. **2026-08-23 — …` m1-11, m1-12    (per-objective numbered list)
#
# An entry counts as DISPOSED when its own text carries a disposition verb:
# discharged, fixed, folded, resolved, closed, actioned, taken, superseded,
# declined, re-targeted, withdrawn, satisfied, done. Anything else is OPEN.
#
# WARN-ONLY, like entry-size-guard: an amendment may legitimately stay open for a
# whole objective. The point is that the number is visible at every close.
#
# Usage:  make amendments                  # the active objective
#         hack/amendments-guard.sh --all   # every tasks/*/PLAN.md, closed included
#         hack/amendments-guard.sh --strict
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$REPO_ROOT"

STRICT=0; ALL=0
for a in "$@"; do
  case "$a" in
    --strict) STRICT=1 ;;
    --all)    ALL=1 ;;
    -h|--help) grep '^#' "$0" | sed '1d; s/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $a (try --help)" >&2; exit 2 ;;
  esac
done

# Disposition verbs, written by the increment that dealt with the amendment.
DISPOSED='discharg|fixed|folded|resolv|closed|actioned|taken|supersed|declin|re-target|retarget|withdraw|satisfi|done|obsolete|moot'

# THREE entry formats are in use. All three are matched; a fourth will silently
# count zero, so the "0 entries" line is a signal to look, not a clean bill.
#   `- **#162 (M1)** …`      m1-07, m1-08, m1-10
#   `**#151 · 2026-08-05 …`  m1-09
#   `12. **2026-08-23 — …`   m1-11, m1-12
plans=()
if [ "$ALL" -eq 1 ]; then
  for f in tasks/*/PLAN.md; do [ -f "$f" ] && plans+=("$f"); done
else
  p="$(loop/where.sh --read 2>/dev/null | grep -E '/PLAN\.md$' | head -1)"
  [ -n "$p" ] && [ -f "$p" ] && plans+=("$p")
fi
[ "${#plans[@]}" -gt 0 ] || { echo ">> no PLAN.md to check"; exit 0; }

warnings=0
for plan in "${plans[@]}"; do
  # One record per amendment: id, disposed flag, and the entry folded to one line so
  # a verb on a continuation line still counts. awk owns the id extraction — the sed
  # version leaked whole entry bodies into the id list on nested `**`.
  read -r total open_n open_list <<<"$(awk -v disp="$DISPOSED" '
    function flush() {
      if (buf == "") return
      total++
      id = ""
      if (match(buf, /#[0-9]+/))      id = substr(buf, RSTART, RLENGTH)
      else if (match(buf, /^[0-9]+/)) id = "#" substr(buf, RSTART, RLENGTH)
      if (tolower(buf) !~ disp) { if (!(id in seen)) { seen[id]=1; open[++o]=id } }
      buf = ""
    }
    /^## Amendments/ { f=1; next }
    !f { next }
    /^- \*\*#[0-9]+/ || /^\*\*#[0-9]+/ || /^[0-9]+\. / { flush(); buf = $0; next }
    /^### / { next }
    { if (buf != "") buf = buf " " $0 }
    END {
      flush()
      list = ""
      for (i = 1; i <= o && i <= 14; i++) list = list open[i] " "
      if (o > 14) list = list "(+" (o - 14) " more)"
      if (list == "") list = "-"
      print total+0, o+0, list
    }' "$plan")"

  if [ "${open_n:-0}" -gt 0 ]; then
    printf '>> WARN  %-42s %s entries, %s OPEN: %s\n' "$plan" "$total" "$open_n" "$open_list"
    warnings=$((warnings+1))
  else
    printf '>> ok    %-42s %s entries, all disposed\n' "$plan" "$total"
  fi
done

if [ "$warnings" -gt 0 ]; then
  printf '>> %d plan(s) with open amendments. Each is a deferred reviewer finding: at the\n' "$warnings"
  printf '   objective close every one owes a disposition in OUTCOME.md — done, re-targeted\n'
  printf '   to a carry-forward, or declined WITH a reason. Never dropped (AGENTS §2).\n'
  [ "$STRICT" -eq 1 ] && exit 1
fi
exit 0
