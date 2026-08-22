---
description: Report local Claude Code token spend by day, project, model and session.
argument-hint: [csv|status|backfill]
---

# Cost Report

Report this machine's own Claude Code usage — tokens and estimated USD — from the
SQLite database maintained by the `cost-tracker` Stop hook shipped with this
plugin. Nothing leaves the machine and no API is called.

`$ARGUMENTS` selects the mode: empty for the report, `csv` to export rows,
`status` for collector health, `backfill` to (re-)ingest transcripts.

## Ground rules

- **Costs are estimates.** The rate table lives in
  `${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py` — Anthropic first-party
  rates, no long-context premium (every current model is single-price at 1M).
  Present figures as estimates, never as an invoice. If the user has a real bill
  that disagrees, the bill wins.
- **Sanity-check the magnitude before presenting it.** Divide total USD by total
  tokens: a blended rate far above ~1 USD/MTok on a cache-heavy workload means the
  rate table is wrong, not that the work was expensive. Cache read is a tenth of
  input, so long agentic sessions are cheap per token and large in aggregate —
  say which of the two is driving the number.
- **The Stop hook only sees sessions that end with it loaded.** Headless
  `claude -p` runs (Ralph loops, subagents) never fire it, so their spend is
  missing until a backfill. If a project the user knows they hammered shows
  near-zero, run the backfill in the last section before reporting anything.
- If the database is missing, say the collector has not run yet and offer the
  backfill in the last section — do not invent numbers.
- Sessions on a subscription plan cost nothing marginal. Say so if the user reads
  these numbers as money actually owed.

## 1. Health first

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py" --status
```

Reports the database path, which config dirs are scanned, how many transcripts
are visible, when the last ingest ran, and the row date range. It warns when the
newest row is more than three days old — the signature of a collector that has
silently stopped, usually because `CLAUDE_CONFIG_DIR` moved.

Stop here and fix collection before reporting numbers, if that warning fires.

## 2. Summary

```bash
DB="${CLAUDE_COST_DB:-$HOME/.claude-cost-tracker/usage.db}"
sqlite3 -header -column "$DB" "
  SELECT
    ROUND(SUM(CASE WHEN date(timestamp) = date('now') THEN cost_usd END), 2) AS today,
    ROUND(SUM(CASE WHEN date(timestamp) >= date('now','-7 days') THEN cost_usd END), 2) AS last_7d,
    ROUND(SUM(cost_usd), 2) AS all_time,
    COUNT(*) AS messages,
    COUNT(DISTINCT session_id) AS sessions
  FROM usage;"
```

## 3. Breakdowns

```bash
# by day, last 14
sqlite3 -header -column "$DB" "
  SELECT date(timestamp) AS day, COUNT(*) AS msgs,
         SUM(input_tokens + cache_read + cache_write) AS in_tok,
         SUM(output_tokens) AS out_tok,
         ROUND(SUM(cost_usd), 2) AS usd
  FROM usage GROUP BY day ORDER BY day DESC LIMIT 14;"

# by project
sqlite3 -header -column "$DB" "
  SELECT project, COUNT(DISTINCT session_id) AS sessions, COUNT(*) AS msgs,
         ROUND(SUM(cost_usd), 2) AS usd
  FROM usage GROUP BY project ORDER BY usd DESC LIMIT 15;"

# by model
sqlite3 -header -column "$DB" "
  SELECT model, COUNT(*) AS msgs, ROUND(SUM(cost_usd), 2) AS usd,
         ROUND(100.0 * SUM(cache_read) / NULLIF(SUM(input_tokens + cache_read + cache_write), 0), 1) AS cache_read_pct
  FROM usage GROUP BY model ORDER BY usd DESC;"

# most expensive sessions
sqlite3 -header -column "$DB" "
  SELECT session_id, project, MIN(date(timestamp)) AS started, COUNT(*) AS msgs,
         ROUND(SUM(cost_usd), 2) AS usd
  FROM usage GROUP BY session_id ORDER BY usd DESC LIMIT 10;"

# which tools drive the turns
sqlite3 -header -column "$DB" "
  SELECT tool_name, COUNT(*) AS msgs, ROUND(SUM(cost_usd), 2) AS usd
  FROM usage GROUP BY tool_name ORDER BY usd DESC LIMIT 12;"
```

`cache_read_pct` is the useful signal in the model breakdown: high cache reads
mean long sessions are being served cheaply; a low share on an expensive model
usually means context is being rebuilt from scratch too often.

## 4. CSV export (when `$ARGUMENTS` is `csv`)

```bash
sqlite3 -header -csv "$DB" "
  SELECT timestamp, project, model, tool_name, input_tokens, output_tokens,
         cache_write, cache_read, cost_usd, session_id
  FROM usage ORDER BY timestamp DESC LIMIT 5000;" > claude-usage.csv
```

Write it to the current directory and tell the user the path and row count.

## 5. Backfill (when `$ARGUMENTS` is `backfill`, or history looks short)

The hook only fires at the end of a session, but every figure it records already
exists in the transcripts — so history is recoverable at any time, including for
sessions that ran before this plugin was installed, and for a Claude install in a
different config directory. Ingest is idempotent (keyed by message uuid).

```bash
# every transcript in every known config dir
python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py"

# a specific install elsewhere
CLAUDE_CONFIG_DIR=/path/to/other/.claude \
  python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py"

# one transcript
python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py" /path/to/session.jsonl
```

The only hard limit is transcript retention: once a `.jsonl` is deleted, that
session is unrecoverable. If the user cares about long-term history, suggest
archiving `projects/**/*.jsonl` rather than relying on the database alone.

## 6. Verify the collector works

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py" --self-test
```

Synthetic end-to-end check in a temp directory — row insertion, duplicate
suppression, tool and project capture, the per-family rates, and the
no-long-context-premium guard. Touches
no real data.
