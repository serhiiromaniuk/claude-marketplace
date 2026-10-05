---
description: Report local Claude Code token spend by day, project, model and session.
argument-hint: [csv|status|backfill|reprice]
---

# Cost Report

Report this machine's own Claude Code usage — tokens and estimated USD — from the
SQLite database maintained by the `cost-tracker` Stop hook shipped with this
plugin. Nothing leaves the machine and no API is called.

Every step below is one self-contained command. Run each exactly as written: the
Bash tool keeps no shell variables between calls, so never split a step or rely
on a value set by an earlier one.

`$ARGUMENTS` selects the mode: empty for the full report, `csv` to export rows,
`status` for collector health only, `backfill` to re-ingest transcripts,
`reprice` to recompute every cost after a price-table change.

## Ground rules

- **Costs are estimates.** Rates live in
  `${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/pricing.py`, copied per model from
  Anthropic's published first-party pricing, with separate input, output,
  5-minute cache-write, 1-hour cache-write and cache-read rates. Bedrock and
  Vertex are priced separately by those platforms. Present figures as
  estimates, never as an invoice. If the user has a real bill that disagrees,
  the bill wins.
- **Never price an unknown model by analogy.** A model id missing from the table
  is stored unpriced and listed as `UNPRICED` in the status and report notes;
  its spend is excluded from every dollar figure. Say so, name the model, and
  point at `CLAUDE_COST_PRICING` (a JSON file of exact model ids to
  `[input, output, cache_write_5m, cache_write_1h, cache_read]`) followed by
  `reprice`. Do not estimate it from a similar-looking model.
- **Sanity-check the magnitude before presenting it.** The Summary prints
  `usd_per_mtok`, the blended rate. Agentic sessions are dominated by cache
  reads, the cheapest token type, so a blended rate far above ~1 USD/MTok on a
  cache-heavy workload means the rate table is wrong, not that the work was
  expensive. The cache-read discount differs by model: a tenth of the input
  rate on most, a twentieth on Opus 5.5, a fortieth on Fable 5.1. Use the
  "Where the money goes" table to say what drives the total — output, cache
  writes or cache reads.
- **Coverage.** The Stop hook fires at the end of every turn and ingests that
  session's transcript plus its subagents'. A session that never ran with this
  plugin loaded — another config dir, another machine, anything before install
  — is missing until a backfill. If a project the user knows they hammered
  shows near-zero, run the backfill in section 4 before reporting anything.
- **Legacy rows.** Databases written before 1.0 stored one row per transcript
  line, which counted most responses about twice. The migration keeps every
  row; rows whose transcript still exists are collapsed to one per response,
  and rows whose transcript is gone are kept as recorded and flagged `legacy`,
  with an estimate of how much they overstate. Quote the total and that
  estimate side by side; do not silently subtract it.
- If the database is missing, say the collector has not run yet and offer the
  backfill — do not invent numbers.
- Sessions on a subscription plan cost nothing marginal. Say so if the user
  reads these numbers as money actually owed.

## 1. Health first

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py" --status
```

Reports the database, the config dirs scanned, the last ingest (mode, rows,
duration), the last error, the row date range and the estimated total. Lines to
act on:

- `ERROR:` — the hook is failing; it exits 0 so the session is never blocked,
  which also means nobody sees it but this line. Fix it before reporting.
- `WARNING: newest row is N days old` — collection has silently stopped,
  usually because `CLAUDE_CONFIG_DIR` moved. Fix collection first.
- `UNPRICED:`, `legacy:`, `pending:`, `pricing:` — carry these into the answer;
  `pricing:` means run `reprice` (section 5).

If `$ARGUMENTS` is `status`, stop here and summarise.

## 2. Report (default)

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py" --report
```

One command prints everything: Summary (today, 7 and 30 days, all time,
responses, sessions, tokens, blended rate), where the money goes by token type,
by day, by project, by model, the most expensive sessions, the tools in the
responses, and Notes. Days are UTC.

`cache_read_pct` is the useful signal in the model breakdown: a high share means
long sessions are being served from cache; a low share on an expensive model
usually means context is rebuilt from scratch too often. In the tools table a
response that called several tools counts once for each, with its cost split
evenly, so the column still sums to the total.

## 3. CSV export (when `$ARGUMENTS` is `csv`)

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py" --csv claude-usage.csv
```

Writes every row to `claude-usage.csv` in the current directory and prints the
path and row count; pass both on to the user.

## 4. Backfill (when `$ARGUMENTS` is `backfill`, or history looks short)

Every figure the hook records already exists in the transcripts, so history is
recoverable for any session whose `.jsonl` still exists — including sessions
from before this plugin was installed, and a Claude install in a different
config directory. Ingest is idempotent: rows are keyed by API message id and
request id.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py" --backfill
```

A specific install elsewhere:

```bash
CLAUDE_CONFIG_DIR=/path/to/other/.claude python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py" --backfill
```

One transcript:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py" /path/to/session.jsonl
```

The hard limit is transcript retention: Claude Code deletes transcripts after
`cleanupPeriodDays` (30 by default), so the database may be the only record of
older spend. Never delete it to "start fresh" — that loses those rows for good.
To fix costs after a rate change, reprice instead.

## 5. Reprice (when `$ARGUMENTS` is `reprice`)

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py" --reprice
```

Recomputes every row's cost from its stored tokens with the current rate table
(plus any `CLAUDE_COST_PRICING` override) and prints the before and after
totals. Rows recorded before 1.0 have no 5-minute / 1-hour split, so their cache
writes are priced at the 5-minute rate.

## 6. Verify the collector works

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-tracker/track.py" --self-test
```

Runs the bundled tests in a temp directory: one row per multi-line response,
per-model rates against the published table, unknown models left unpriced,
1-hour cache writes, hook-mode scoping, schema migration that keeps every row,
and the quiet hook never failing. Touches no real data.
