---
description: Preview, install or remove the toolkit's two-row status line (model, effort, context bar, usage limits, cost, git, AWS profile).
argument-hint: [preview|install|uninstall]
---

# Status line

The toolkit ships a two-row, width-aware status line at
`${CLAUDE_PLUGIN_ROOT}/statusline/statusline.sh`:

```
 🪨 ULTRA  │ Opus 5.5    │ ━━━━━━━━━━  20% │   3% ↻3h40m │ $6.98 │ ⎇ main
out 107k   │ high effort │       202k / 1M │  16% ↻5d16h │ 1h09m │ clean
```

Columns: caveman mode (only when the caveman plugin's flag file exists) and
output tokens · model and effort · context bar and tokens · 5-hour and weekly
usage limits with reset countdowns · session cost and elapsed time · git branch,
changes and ahead/behind · `AWS_PROFILE` (red when it contains `prd`/`prod`).
Narrow panes drop cost, git, model and limits, in that order. It needs bash ≥ 4.2
and `jq`, and always exits 0.

A plugin cannot set `statusLine` itself, and `${CLAUDE_PLUGIN_ROOT}` is not
expanded in the user's `settings.json`. So `install` copies the script to a stable
path in the active config dir and points `statusLine` at that copy. Re-run
`install` after a plugin update to pick up a newer script.

`$ARGUMENTS` selects the mode: empty or `preview` (default), `install`, `uninstall`.
Every step is one self-contained command: the Bash tool keeps no shell variables
between calls.

## preview

Render the script with a sample payload, so the user sees it before installing:

```bash
printf '%s' '{"model":{"display_name":"Opus 5.5"},"effort":{"level":"high"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":20,"total_input_tokens":190000,"total_output_tokens":12000,"context_window_size":1000000},"cost":{"total_cost_usd":6.98,"total_duration_ms":4140000},"rate_limits":{"five_hour":{"used_percentage":3,"resets_at":'"$(( $(date +%s) + 13200 ))"'},"seven_day":{"used_percentage":16,"resets_at":'"$(( $(date +%s) + 489600 ))"'}}}' | COLUMNS=120 bash "${CLAUDE_PLUGIN_ROOT}/statusline/statusline.sh"
```

Show the output in a code block and say it renders in colour in the real bar.
If it printed `statusline: needs …`, report the missing requirement and stop.

## install

1. Show what is configured now:

   ```bash
   jq -c '.statusLine // "none"' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" 2>/dev/null || echo "no settings.json yet"
   ```

2. If a `statusLine` exists and its command does not already point at
   `statusline-toolkit.sh`, show it and **ask the user to confirm** replacing it.
   Never replace another status line silently. Once confirmed, back it up:

   ```bash
   C="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; jq '.statusLine' "$C/settings.json" > "$C/statusline-toolkit.previous.json" && echo "backed up to $C/statusline-toolkit.previous.json"
   ```

3. Copy the script and point `settings.json` at it. The edit goes through a
   temporary file, so a failed `jq` leaves the settings untouched:

   ```bash
   C="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; install -m 755 "${CLAUDE_PLUGIN_ROOT}/statusline/statusline.sh" "$C/statusline-toolkit.sh" && { [ -f "$C/settings.json" ] || echo '{}' > "$C/settings.json"; } && jq --arg cmd "bash \"$C/statusline-toolkit.sh\"" '.statusLine = {type: "command", command: $cmd, refreshInterval: 5}' "$C/settings.json" > "$C/settings.json.tmp" && mv "$C/settings.json.tmp" "$C/settings.json" && jq -c '.statusLine' "$C/settings.json"
   ```

4. Tell the user the bar appears on the next refresh (within about 5 s), and that
   `/toolkit:statusline uninstall` restores the previous one.

## uninstall

Restore the backed-up status line if there is one, otherwise remove the key, then
delete the copied script:

```bash
C="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; B="$C/statusline-toolkit.previous.json"; if [ -s "$B" ] && [ "$(cat "$B")" != "null" ]; then jq --slurpfile prev "$B" '.statusLine = $prev[0]' "$C/settings.json" > "$C/settings.json.tmp"; else jq 'del(.statusLine)' "$C/settings.json" > "$C/settings.json.tmp"; fi && mv "$C/settings.json.tmp" "$C/settings.json" && rm -f "$C/statusline-toolkit.sh" "$B" && jq -c '.statusLine // "none"' "$C/settings.json"
```

Report what `statusLine` is now.
