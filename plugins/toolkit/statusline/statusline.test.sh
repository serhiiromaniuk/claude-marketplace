#!/usr/bin/env bash
# shellcheck disable=SC2034 # reason: OUT/PLAIN/RC are read inside check's eval
# Tests for statusline.sh. Run: bash plugins/toolkit/statusline/statusline.test.sh
# Hermetic: a scratch config dir, a scratch git repo, a fake transcript.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SL="$HERE/statusline.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/statusline-test.XXXXXX")
trap 'rm -rf "$T"' EXIT
export LC_ALL=C.UTF-8 XDG_RUNTIME_DIR="$T/run"
mkdir -p "$T/cfg" "$T/run" "$T/repo"

run=0 failed=0
ok()   { run=$((run + 1)); echo "  ok   $1"; }
fail() { run=$((run + 1)); failed=$((failed + 1)); echo "  FAIL $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /'; }
check() { if eval "$2"; then ok "$1"; else fail "$1" "$OUT"; fi; }

strip() { sed -E $'s/\033\\[[0-9;]*m//g'; }
# Display width of the widest line in characters (awk may count bytes); 🪨 is 2 columns.
maxw() {
  local line m=0 n
  while IFS= read -r line; do
    n=${#line}; [[ $line == *🪨* ]] && n=$((n + 1)); ((n > m)) && m=$n
  done < <(strip)
  echo "$m"
}

git -C "$T/repo" init -q -b main
git -C "$T/repo" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
printf '%s\n' \
  '{"type":"assistant","message":{"id":"m1","usage":{"output_tokens":100}}}' \
  '{"type":"assistant","message":{"id":"m1","usage":{"output_tokens":1500}}}' \
  '{"type":"assistant","message":{"id":"m2","usage":{"output_tokens":500}}}' >"$T/t.jsonl"

json() {
  cat <<EOF
{"model":{"display_name":"Opus 5.5"},"effort":{"level":"high"},"fast_mode":false,
 "workspace":{"current_dir":"$T/repo"},"transcript_path":"$T/t.jsonl",
 "context_window":{"used_percentage":42.7,"total_input_tokens":80000,"total_output_tokens":4000,"context_window_size":200000},
 "cost":{"total_cost_usd":1.234,"total_duration_ms":4500000},
 "rate_limits":{"five_hour":{"used_percentage":12.3,"resets_at":$(( $(date +%s) + 3600 ))},
                "seven_day":{"used_percentage":55,"resets_at":$(( $(date +%s) + 200000 ))}}}
EOF
}
render() { OUT=$(json | env -u AWS_PROFILE CLAUDE_CONFIG_DIR="$T/cfg" COLUMNS="${1:-160}" bash "$SL" 2>&1); RC=$?; PLAIN=$(strip <<<"$OUT"); }

echo "statusline.sh"
render 160
check "exits 0"                          '[ "$RC" -eq 0 ]'
check "prints two rows"                  '[ "$(wc -l <<<"$OUT")" -eq 2 ]'
check "model and effort"                 'grep -q "Opus 5.5" <<<"$PLAIN" && grep -q "high effort" <<<"$PLAIN"'
check "context percent floors"           'grep -q "42%" <<<"$PLAIN"'
check "tokens used / window"             'grep -q "84k / 200k" <<<"$PLAIN"'
check "limits with reset countdown"      'grep -q "12% ↻" <<<"$PLAIN" && grep -q "55% ↻2d" <<<"$PLAIN"'
check "cost and elapsed"                 'grep -q "\$1.23" <<<"$PLAIN" && grep -q "1h15m" <<<"$PLAIN"'
check "git branch and clean tree"        'grep -q "⎇ main" <<<"$PLAIN" && grep -q "clean" <<<"$PLAIN"'
check "output tokens keep max per id"    'grep -q "out 2k" <<<"$PLAIN"'
check "no caveman badge without its flag" '! grep -q "🪨" <<<"$PLAIN"'

echo ultra >"$T/cfg/.caveman-active"; render 160
check "caveman badge from the flag"      'grep -q "🪨 ULTRA" <<<"$PLAIN"'
echo off >"$T/cfg/.caveman-active"; render 160
check "caveman off is shown as off"      'grep -q "CAVE OFF" <<<"$PLAIN"'
echo '$(touch pwned)' >"$T/cfg/.caveman-active"; render 160
check "flag content is never executed"   '[ ! -e pwned ] && [ ! -e "$T/repo/pwned" ]'
rm -f "$T/cfg/.caveman-active"

touch "$T/repo/new"; render 160
check "dirty tree counts changes"        'grep -q "●1 changed" <<<"$PLAIN"'
rm -f "$T/repo/new"

for c in 120 90 70 60; do
  render "$c"
  w=$(maxw <<<"$OUT")
  check "fits COLUMNS=$c (widest row $w)" '[ "$w" -le "$c" ]'
done
render 40
check "narrow pane keeps the context bar" 'grep -q "42%" <<<"$PLAIN"'

OUT=$(AWS_PROFILE=team-prod CLAUDE_CONFIG_DIR="$T/cfg" COLUMNS=200 bash "$SL" < <(json)); PLAIN=$(strip <<<"$OUT")
check "AWS profile shown"                'grep -q "aws team-prod" <<<"$PLAIN"'

OUT=$(echo '{}' | CLAUDE_CONFIG_DIR="$T/cfg" bash "$SL" 2>&1); RC=$?
check "empty input still exits 0"        '[ "$RC" -eq 0 ] && [ -n "$OUT" ]'
OUT=$(echo 'not json' | CLAUDE_CONFIG_DIR="$T/cfg" bash "$SL" 2>&1); RC=$?
check "garbage input still exits 0"      '[ "$RC" -eq 0 ]'

mkdir -p "$T/bin" && ln -s "$(command -v cat)" "$T/bin/cat"
OUT=$(json | PATH="$T/bin" CLAUDE_CONFIG_DIR="$T/cfg" "$BASH" "$SL" 2>&1); RC=$?
check "no jq: one-line notice, exit 0"   '[ "$RC" -eq 0 ] && [ "$OUT" = "statusline: needs jq" ]'

rm -f "$T/run/claude-statusline-$UID-t.jsonl.out"
ln -s "$T/victim" "$T/run/claude-statusline-$UID-t.jsonl.out"; render 160
check "never writes through a planted symlink" '[ ! -e "$T/victim" ] && grep -q "out 2k" <<<"$PLAIN"'

echo
echo "$run run, $failed failed"
[ "$failed" -eq 0 ]
