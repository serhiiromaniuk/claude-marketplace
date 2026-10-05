"""--status, --report, --csv and --self-test for the cost tracker.

Everything here reads the database through Python's own sqlite3, so the
report needs no `sqlite3` binary and no shell state between commands.
"""
import csv
import json
import os
import sqlite3

import pricing
import store

STALE_DAYS = 3


def _fmt(value):
    if value is None:
        return "-"
    if isinstance(value, float):
        return "%.2f" % value
    if isinstance(value, int):
        return "{:,}".format(value)
    return str(value)


def print_table(title, headers, rows):
    print("\n## " + title)
    if not rows:
        print("(no rows)")
        return
    cells = [[_fmt(v) for v in row] for row in rows]
    widths = [max(len(h), *(len(r[i]) for r in cells)) for i, h in enumerate(headers)]
    numeric = [all(isinstance(row[i], (int, float)) or row[i] is None for row in rows)
               for i in range(len(headers))]
    def line(values):
        return "  ".join(v.rjust(w) if n else v.ljust(w)
                         for v, w, n in zip(values, widths, numeric)).rstrip()
    print(line(headers))
    print(line(["-" * w for w in widths]))
    for r in cells:
        print(line(r))


def _read_json(path):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


# ---------------------------------------------------------------- --status

def status(db_path, config_dirs, transcripts):
    state_dir = os.path.dirname(db_path) or "."
    print("database:    %s" % db_path)
    print("config dirs: %s" % (", ".join(config_dirs) or "(none found)"))
    print("transcripts: %d visible" % len(transcripts))
    last = _read_json(os.path.join(state_dir, "last-run.json"))
    if last:
        last.setdefault("at", last.get("ran_at"))  # pre-1.0 breadcrumb
        print("last run:    %s (%s: +%s new, %s updated from %s of %s transcripts, %s ms)" % (
            last.get("at"), last.get("mode", "?"), last.get("rows_added"),
            last.get("rows_updated", "?"), last.get("transcripts_read", "?"),
            last.get("transcripts_seen"), last.get("elapsed_ms", "?")))
        if last.get("pricing_warning"):
            print("WARNING:     " + last["pricing_warning"])
        if last.get("file_errors"):
            print("WARNING:     %s transcript(s) failed to parse, last: %s" % (
                last["file_errors"], last.get("file_error")))
        if last.get("complete") is False:
            print("partial:     the last run hit its time budget; the next one carries on")
    else:
        print("last run:    never (no last-run.json)")
    err = _read_json(os.path.join(state_dir, "last-error.json"))
    if err:
        older = last and str(err.get("at")) < str(last.get("at"))
        print("%s %s: %s%s" % ("last error: " if older else "ERROR:      ", err.get("at"),
                               err.get("error"),
                               " (a later run succeeded)" if older else ""))
    if not os.path.exists(db_path):
        print("rows:        none — the collector has not run yet; run track.py --backfill")
        return 0
    try:
        conn = store.open_readonly(db_path)
        try:
            _status_rows(conn, db_path)
        finally:
            conn.close()
    except sqlite3.DatabaseError as exc:
        print("ERROR:       database unreadable (%s); the hook records nothing until it is "
              "fixed. Move it aside and run --backfill to rebuild what transcripts still hold."
              % exc)
        return 1
    return 0


def _status_rows(conn, db_path):
    version = conn.execute("PRAGMA user_version").fetchone()[0]
    if version < store.SCHEMA_VERSION:
        n, usd = conn.execute("SELECT COUNT(*), ROUND(SUM(cost_usd), 2) FROM usage").fetchone()
        print("schema:      v%d (one row per transcript line, double counts); the next "
              "ingest migrates it in place, keeping all %d rows (backup: %s.v%d.bak)"
              % (version, n, os.path.basename(db_path), version))
        print("estimated:   $%s as recorded under the old schema" % usd)
        return
    row = conn.execute(
        "SELECT MIN(date(timestamp)), MAX(date(timestamp)), COUNT(*), COUNT(DISTINCT session_id),"
        " ROUND(SUM(cost_usd), 2), SUM(input_tokens + output_tokens + cache_write + cache_read)"
        " FROM usage").fetchone()
    print("rows:        %d over %d sessions, %s .. %s" % (row[2], row[3], row[0], row[1]))
    blended = (row[4] or 0) / row[5] * 1e6 if row[5] else 0
    print("estimated:   $%s over %s tokens (blended %.2f USD/MTok)" % (row[4], _fmt(row[5] or 0), blended))
    for line in notes(conn):
        print(line)
    stale = conn.execute("SELECT julianday('now') - julianday(MAX(timestamp)) FROM usage").fetchone()[0]
    if stale is not None and stale > STALE_DAYS:
        print("WARNING:     newest row is %.0f days old — check CLAUDE_CONFIG_DIR and "
              "re-run a backfill" % stale)


def notes(conn):
    """Caveats that change how the totals should be read; shared by status and report."""
    out = []
    unpriced = conn.execute(
        "SELECT model, COUNT(*), SUM(input_tokens + output_tokens + cache_write + cache_read)"
        " FROM usage WHERE priced_as IS NULL GROUP BY model ORDER BY 2 DESC").fetchall()
    if unpriced:
        out.append("UNPRICED:    %d responses on models missing from the price table, "
                   "excluded from every $ figure: %s. Add them via CLAUDE_COST_PRICING, then "
                   "run --reprice." % (sum(r[1] for r in unpriced), ", ".join(
                       "%s (%d responses, %s tokens)" % (r[0], r[1], _fmt(r[2])) for r in unpriced)))
    legacy, legacy_usd = conn.execute(
        "SELECT COUNT(*), ROUND(SUM(cost_usd), 2) FROM usage WHERE legacy = 1").fetchone()
    if legacy:
        # Rows of one response share session, model and input/cache counts; only
        # output differs. Not proof enough to delete, but a fair estimate.
        dup_rows, dup_usd = conn.execute(
            "SELECT SUM(n - 1), ROUND(SUM(usd - top), 2) FROM (SELECT COUNT(*) AS n,"
            " SUM(cost_usd) AS usd, MAX(cost_usd) AS top FROM usage WHERE legacy = 1"
            " GROUP BY session_id, model, input_tokens, cache_write, cache_read)").fetchone()
        out.append("legacy:      %d rows ($%s) were recorded before 1.0, one per transcript "
                   "line, and their transcripts are gone, so they cannot be de-duplicated; "
                   "kept as recorded. About %s of them look like extra lines of another "
                   "response (~$%s overstated)." % (legacy, legacy_usd, _fmt(dup_rows or 0),
                                                    dup_usd or 0))
    meta = dict(conn.execute("SELECT key, value FROM meta").fetchall())
    if meta.get("needs_rescan"):
        out.append("pending:     migrated from the old schema; the next ingest re-reads every "
                   "transcript to collapse duplicate rows (or run --backfill now)")
    if meta.get("reprice_hint"):
        out.append("pricing:     the price table changed since rows were priced — run --reprice")
    return out


# ---------------------------------------------------------------- --report

def text_report(db_path):
    if not os.path.exists(db_path):
        print("No database at %s — the collector has not run yet. Run track.py --backfill." % db_path)
        return 1
    conn = store.connect(db_path)  # migrates a pre-1.0 database in place
    try:
        _summary(conn)
        _composition(conn)
        _breakdowns(conn)
        caveats = notes(conn)
        if caveats:
            print("\n## Notes")
            for line in caveats:
                print(line)
    finally:
        conn.close()
    return 0


def _summary(conn):
    row = conn.execute(
        "SELECT ROUND(SUM(CASE WHEN date(timestamp) = date('now') THEN cost_usd END), 2),"
        " ROUND(SUM(CASE WHEN date(timestamp) >= date('now', '-6 days') THEN cost_usd END), 2),"
        " ROUND(SUM(CASE WHEN date(timestamp) >= date('now', '-29 days') THEN cost_usd END), 2),"
        " ROUND(SUM(cost_usd), 2), COUNT(*), COUNT(DISTINCT session_id),"
        " SUM(input_tokens + output_tokens + cache_write + cache_read) FROM usage").fetchone()
    tokens = row[6] or 0
    blended = (row[3] or 0) / tokens * 1e6 if tokens else 0.0
    print_table("Summary (estimated USD, UTC days)",
                ["today", "last_7d", "last_30d", "all_time", "responses", "sessions",
                 "tokens", "usd_per_mtok"],
                [list(row[:6]) + [tokens, round(blended, 2)]])


def _composition(conn):
    groups = conn.execute(
        "SELECT model, speed, SUM(input_tokens), SUM(output_tokens), SUM(cache_write),"
        " SUM(cache_write_1h), SUM(cache_read) FROM usage GROUP BY model, speed").fetchall()
    table = pricing.load_pricing()
    labels = ("input", "output", "cache write 5m", "cache write 1h", "cache read")
    usd, tok = [0.0] * 5, [0] * 5
    for model, speed, i, o, w, w1, r in groups:
        parts = pricing.components(model, speed, i or 0, o or 0, w or 0, w1 or 0, r or 0, table)
        if parts is None:
            continue
        for n, value in enumerate(parts):
            usd[n] += value
        for n, value in enumerate((i or 0, o or 0, (w or 0) - (w1 or 0), w1 or 0, r or 0)):
            tok[n] += value
    total = sum(usd) or 1.0
    print_table("Where the money goes (priced rows, current table)",
                ["token type", "tokens", "usd", "share_pct"],
                [[labels[n], tok[n], usd[n], round(100.0 * usd[n] / total, 1)] for n in range(5)])


def _breakdowns(conn):
    q = conn.execute
    print_table("By day (last 14)", ["day", "responses", "in_tok", "out_tok", "usd"], q(
        "SELECT date(timestamp) AS day, COUNT(*), SUM(input_tokens + cache_read + cache_write),"
        " SUM(output_tokens), ROUND(SUM(cost_usd), 2) FROM usage GROUP BY day"
        " ORDER BY day DESC LIMIT 14").fetchall())
    print_table("By project (top 15)", ["project", "sessions", "responses", "usd"], q(
        "SELECT project, COUNT(DISTINCT session_id), COUNT(*), ROUND(SUM(cost_usd), 2) AS usd"
        " FROM usage GROUP BY project ORDER BY usd DESC LIMIT 15").fetchall())
    print_table("By model", ["model", "priced_as", "responses", "usd", "cache_read_pct"], q(
        "SELECT model, COALESCE(GROUP_CONCAT(DISTINCT priced_as), 'UNPRICED'), COUNT(*),"
        " ROUND(SUM(cost_usd), 2) AS usd, ROUND(100.0 * SUM(cache_read) /"
        " NULLIF(SUM(input_tokens + cache_read + cache_write), 0), 1)"
        " FROM usage GROUP BY model ORDER BY usd DESC").fetchall())
    print_table("Most expensive sessions", ["session_id", "project", "started", "responses", "usd"], q(
        "SELECT session_id, MIN(project), MIN(date(timestamp)), COUNT(*),"
        " ROUND(SUM(cost_usd), 2) AS usd FROM usage GROUP BY session_id"
        " ORDER BY usd DESC LIMIT 10").fetchall())
    # A response that called three tools counts once for each; its cost is split
    # evenly, so the usd column still sums to the total.
    tools = {}
    for names, n, usd in q("SELECT tool_name, COUNT(*), SUM(cost_usd) FROM usage"
                           " GROUP BY tool_name").fetchall():
        split = [t for t in (names or "text").split(",") if t] or ["text"]
        for t in split:
            entry = tools.setdefault(t, [0, 0.0])
            entry[0] += n
            entry[1] += (usd or 0.0) / len(split)
    ranked = sorted(tools.items(), key=lambda kv: kv[1][1], reverse=True)[:12]
    print_table("Tools in the responses (cost split across a response's tools)",
                ["tool", "responses", "usd"], [[t, v[0], v[1]] for t, v in ranked])


# ---------------------------------------------------------------- --csv

CSV_COLUMNS = ("timestamp", "session_id", "project", "model", "priced_as", "tool_name",
               "input_tokens", "output_tokens", "cache_write", "cache_write_1h",
               "cache_read", "speed", "cost_usd", "legacy")


def csv_export(db_path, out_path):
    if not os.path.exists(db_path):
        print("No database at %s — nothing to export." % db_path)
        return 1
    conn = store.connect(db_path)
    try:
        rows = conn.execute("SELECT %s FROM usage ORDER BY timestamp DESC"
                            % ", ".join(CSV_COLUMNS)).fetchall()
    finally:
        conn.close()
    with open(out_path, "w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(CSV_COLUMNS)
        writer.writerows(rows)
    print("wrote %d rows to %s" % (len(rows), os.path.abspath(out_path)))
    return 0


# ---------------------------------------------------------------- --self-test

def self_test(here):
    """Run the bundled unit tests. They use temp dirs only — never the real DB."""
    import unittest
    if not os.path.exists(os.path.join(here, "test_track.py")):
        print("self-test: test_track.py is not next to track.py")
        return 1
    suite = unittest.defaultTestLoader.discover(here, pattern="test_track.py", top_level_dir=here)
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    return 0 if result.wasSuccessful() else 1

