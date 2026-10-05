#!/usr/bin/env bash
# Claude Code status line (Tokyo Night palette, truecolor, no Nerd Font needed).
# Two rows; each column is one topic, top value over its partner:
#
#    🪨 ULTRA  │ Opus 5.5    │ ━━━━━━━━━━  20% │   3% ↻3h40m │ $6.98 │ ⎇ main
#   out 107k   │ high effort │       202k / 1M │  16% ↻5d16h │ 1h09m │ clean
#
# Width-aware: fits $COLUMNS by dropping low-value details first.
# The caveman column shows only when the caveman plugin's mode flag exists.
# Needs bash >= 4.2 and jq. Always exits 0: Claude Code hides the whole bar
# on a non-zero exit.
input=$(cat)
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2) )); then
  echo "statusline: needs bash >= 4.2 (this is $BASH_VERSION)"; exit 0
fi
command -v jq >/dev/null || { echo "statusline: needs jq"; exit 0; }
export LC_ALL=C.UTF-8   # ${#var} counts characters, not bytes

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
printf -v NOW '%(%s)T' -1
COLS=${COLUMNS:-120}
BUDGET=$(( COLS - 4 ))
MAX_BRANCH=28

fg() { printf '\033[38;2;%d;%d;%dm' "$((16#${1:0:2}))" "$((16#${1:2:2}))" "$((16#${1:4:2}))"; }
bg() { printf '\033[48;2;%d;%d;%dm' "$((16#${1:0:2}))" "$((16#${1:2:2}))" "$((16#${1:4:2}))"; }
RST=$'\033[0m'; BOLD=$'\033[1m'
PURPLE=$(fg bb9af7); CYAN=$(fg 7dcfff); GREEN=$(fg 9ece6a); YELLOW=$(fg e0af68)
ORANGE=$(fg ff9e64); RED=$(fg f7768e); TEXT=$(fg c0caf5); MUTED=$(fg 565f89)
TRACK=$(fg 3b4261); LINE=$(fg 292e42); DARK=$(fg 1a1b26)
COLSEP=" ${LINE}│${RST} "

IFS=$'\x1f' read -r model effort fast cwd transcript pct used size cost dur \
  r5 r5reset r7 r7reset < <(jq -r '[
    .model.display_name // "?",
    .effort.level // "",
    (.fast_mode // false),
    .workspace.current_dir // .cwd // "",
    .transcript_path // "",
    (.context_window.used_percentage // 0 | floor),
    ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)),
    .context_window.context_window_size // 200000,
    .cost.total_cost_usd // 0,
    .cost.total_duration_ms // 0,
    (.rate_limits.five_hour.used_percentage // "" | if . == "" then "" else floor end),
    .rate_limits.five_hour.resets_at // "",
    (.rate_limits.seven_day.used_percentage // "" | if . == "" then "" else floor end),
    .rate_limits.seven_day.resets_at // ""
  ] | map(tostring) | join("\u001f")' <<<"$input")

# Smooth color for a percentage: green at 0, yellow at 50, red at 100.
# Sets LV instead of printing, so callers avoid a subshell.
level() {
  local p=$1 a b t r g bl
  (( p < 0 )) && p=0; (( p > 100 )) && p=100
  if (( p <= 50 )); then a=(158 206 106); b=(224 175 104); t=$(( p * 2 ))
  else a=(224 175 104); b=(247 118 142); t=$(( (p - 50) * 2 )); fi
  r=$(( a[0] + (b[0] - a[0]) * t / 100 ))
  g=$(( a[1] + (b[1] - a[1]) * t / 100 ))
  bl=$(( a[2] + (b[2] - a[2]) * t / 100 ))
  printf -v LV '\033[38;2;%d;%d;%dm' "$r" "$g" "$bl"
}

# Model family color.
model_color() {
  case "${1,,}" in
    *fable*)  fg e0af68 ;;   # gold
    *opus*)   fg ff9e64 ;;   # orange
    *sonnet*) fg 7aa2f7 ;;   # blue
    *haiku*)  fg 9ece6a ;;   # green
    *)        fg 7dcfff ;;   # cyan
  esac
}

# Effort color, cool to hot.
effort_color() {
  case "$1" in
    low)    fg 7dcfff ;;   # cyan
    medium) fg 9ece6a ;;   # green
    high)   fg e0af68 ;;   # yellow
    xhigh)  fg ff9e64 ;;   # orange
    max)    fg f7768e ;;   # red
    *)      printf '%s' "$MUTED" ;;
  esac
}

# Bar of $2 cells for $1 percent; each filled cell takes the color of its position.
bar() {
  local pct=$1 width=$2 filled out="" i
  filled=$(( (pct * width + 50) / 100 ))
  (( pct > 0 && filled == 0 )) && filled=1
  for ((i = 0; i < width; i++)); do
    if (( i < filled )); then level $(( (i + 1) * 100 / width )); out+="${LV}━"
    else out+="${TRACK}━"; fi
  done
  printf '%s%s' "$out" "$RST"
}

# 1500 -> 1k, 164000 -> 164k, 1000000 -> 1M, 1250000 -> 1.2M
human() {
  local n=$1 v
  if (( n >= 1000000 )); then
    v=$(( (n + 50000) / 100000 ))
    if (( v % 10 == 0 )); then printf '%dM' $(( v / 10 )); else printf '%d.%dM' $(( v / 10 )) $(( v % 10 )); fi
  elif (( n >= 1000 )); then printf '%dk' $(( n / 1000 ))
  else printf '%d' "$n"; fi
}

# Seconds until an epoch timestamp, as "2d4h", "4h09m" or "12m".
until_fmt() {
  local s=$(( $1 - NOW )) d h m
  (( s <= 0 )) && { printf 'now'; return; }
  d=$(( s / 86400 )); h=$(( s % 86400 / 3600 )); m=$(( s % 3600 / 60 ))
  if (( d > 0 )); then printf '%dd%dh' "$d" "$h"
  elif (( h > 0 )); then printf '%dh%02dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}

# Display width without ANSI codes, stored in W. 🪨 is the only wide glyph used.
ANSI_RE=$'\e\\[[0-9;]*m'
width() {
  local s=$1
  while [[ $s =~ $ANSI_RE ]]; do s=${s/"${BASH_REMATCH[0]}"/}; done
  W=${#s}
  [[ $s == *🪨* ]] && (( W++ ))
}

# --- Data -------------------------------------------------------------------
cave=""; [[ -f "$CFG/.caveman-active" && ! -L "$CFG/.caveman-active" ]] && read -r cave < "$CFG/.caveman-active"
cave=${cave//[^a-z0-9-]/}
# Output tokens Claude wrote this session. The transcript repeats a message's
# usage on each streamed line, so keep the largest value per message id.
# Cached per transcript; recounted only when the transcript is newer than the cache.
session_out=""
cache="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-statusline-$UID-${transcript##*/}.out"
[[ -L "$cache" ]] && cache=/dev/null   # never follow a planted symlink
if [[ -f "$transcript" && -f "$cache" && ! "$transcript" -nt "$cache" ]]; then
  read -r session_out < "$cache"
elif [[ -f "$transcript" ]]; then
  session_out=$(jq -r 'select(.type == "assistant" and .message.id != null)
      | "\(.message.id)\t\(.message.usage.output_tokens // 0)"' "$transcript" 2>/dev/null \
    | awk -F'\t' '$2 > m[$1] { m[$1] = $2 } END { for (k in m) s += m[k]; print s + 0 }')
  printf '%s\n' "$session_out" > "$cache"
fi
badge=""
if [[ -f "$CFG/.caveman-active" ]]; then
  if [[ -n "$cave" && "$cave" != "off" ]]; then
    badge="$(bg bb9af7)${DARK}${BOLD} 🪨 ${cave^^} ${RST}"
  else
    badge="$(bg f7768e)${DARK}${BOLD} 🪨 CAVE OFF ${RST}"
  fi
fi

git_top=""; git_bot=""
if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
  branch=$(git -C "$cwd" symbolic-ref --short -q HEAD || git -C "$cwd" rev-parse --short HEAD)
  (( ${#branch} > MAX_BRANCH )) && branch="${branch:0:MAX_BRANCH-1}…"
  git_top="${GREEN}⎇ ${branch}${RST}"
  dirty=$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l)
  if (( dirty > 0 )); then git_bot="${YELLOW}●${dirty} changed${RST}"; else git_bot="${MUTED}clean${RST}"; fi
  if ab=$(git -C "$cwd" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null); then
    read -r behind ahead <<<"$ab"
    (( ahead > 0 )) && git_bot+=" ${CYAN}↑${ahead}${RST}"
    (( behind > 0 )) && git_bot+=" ${RED}↓${behind}${RST}"
  fi
fi

aws_top=""
if [[ -n "$AWS_PROFILE" ]]; then
  if [[ "$AWS_PROFILE" =~ (prd|prod) ]]; then aws_top="$(bg f7768e)${DARK}${BOLD} aws ${AWS_PROFILE} ${RST}"
  else aws_top="${MUTED}aws ${TEXT}${AWS_PROFILE}${RST}"; fi
fi

mins=$(( dur / 60000 ))
if (( mins >= 60 )); then elapsed="$(( mins / 60 ))h$(printf '%02d' $(( mins % 60 )))m"; else elapsed="${mins}m"; fi

# Usage limit cell: percentage right-aligned to 3 chars so both rows line up.
limit() {
  local pct=$1 reset=$2
  [[ -z "$pct" ]] && return
  level "$pct"
  printf '%s%s%3s%s' "$LV" "$BOLD" "${pct}%" "$RST"
  [[ -n "$reset" ]] && printf ' %s↻%s%s' "$MUTED" "$(until_fmt "$reset")" "$RST"
}

# --- Layout -----------------------------------------------------------------
# Columns, each one topic with its top and bottom value:
#   caveman   model    context   usage limits   cost      git       aws
#   badge     name     bar  %    5-hour         $ spent   branch    profile
#   output    effort   tokens    weekly         time      changes
# Columns marked "r" right-align both cells. Narrow panes drop whole
# columns from the end of DROP until both rows fit.
TOP=(); BOT=(); ALIGN=(); NAME=()
col() { NAME+=("$1"); ALIGN+=("$2"); TOP+=("$3"); BOT+=("$4"); }

out_cell="${session_out:+${MUTED}out ${PURPLE}$(human "$session_out")${RST}}"
if [[ -n "$badge" ]]; then col cave l "$badge" "$out_cell"; elif [[ -n "$out_cell" ]]; then col out l "$out_cell" ""; fi
eff=""; [[ -n "$effort" ]] && eff="$(effort_color "$effort")${effort}${RST} ${MUTED}effort${RST}"
[[ "$fast" == "true" ]] && eff+="${eff:+ }${ORANGE}fast${RST}"
col model l "$(model_color "$model")${BOLD}${model}${RST}" "$eff"
level "$pct"
col ctx r "$(bar "$pct" 10) ${LV}${BOLD}$(printf '%3s' "${pct}%")${RST}" \
          "${MUTED}$(human "$used") / $(human "$size")${RST}"
[[ -n "$r5$r7" ]] && col limits l "$(limit "$r5" "$r5reset")" "$(limit "$r7" "$r7reset")"
col cost r "$(printf '%s%s$%.2f%s' "$YELLOW" "$BOLD" "$cost" "$RST")" "${TEXT}${elapsed}${RST}"
[[ -n "$git_top" ]] && col git l "$git_top" "$git_bot"
[[ -n "$aws_top" ]] && col aws l "$aws_top" ""

DROP=(out cost git model limits)   # dropped in this order when too narrow; aws, ctx, cave always stay

build() {
  local i w1 w2 w t b p1 p2
  ROW1=""; ROW2=""
  for i in "${!NAME[@]}"; do
    [[ " ${SKIP[*]} " == *" ${NAME[i]} "* ]] && continue
    t=${TOP[i]}; b=${BOT[i]}
    width "$t"; w1=$W; width "$b"; w2=$W; w=$(( w1 > w2 ? w1 : w2 ))
    if [[ -n "$ROW1$ROW2" ]]; then ROW1+="$COLSEP"; ROW2+="$COLSEP"; fi
    printf -v p1 '%*s' $(( w - w1 )) ''; printf -v p2 '%*s' $(( w - w2 )) ''
    if [[ ${ALIGN[i]} == r ]]; then ROW1+="$p1$t"; ROW2+="$p2$b"
    else ROW1+="$t$p1"; ROW2+="$b$p2"; fi
  done
}

SKIP=()
build
for name in "${DROP[@]}"; do
  width "$ROW1"; w1=$W; width "$ROW2"
  (( (w1 > W ? w1 : W) <= BUDGET )) && break
  SKIP+=("$name"); build
done

printf '%s\n%s\n' "${ROW1%"${ROW1##*[! ]}"}" "${ROW2%"${ROW2##*[! ]}"}"
exit 0
