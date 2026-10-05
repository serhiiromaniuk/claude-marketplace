"""SQLite schema, migration and repricing for the cost tracker.

Schema history (PRAGMA user_version):
    0  0.12-0.19: one row per transcript *line*, keyed by line uuid. A response
       written as several lines (thinking / text / tool_use) was counted once
       per line, roughly doubling spend.
    2  1.0: one row per API response, keyed by message id + request id, with
       the 1-hour cache-write split and the price-table row used.
"""
import os
import sqlite3
import time

from urllib.parse import quote

import pricing

SCHEMA_VERSION = 2
BUSY_TIMEOUT = 10  # seconds

COLUMNS = (
    "msg_key", "uuid", "timestamp", "project", "tool_name", "model",
    "input_tokens", "output_tokens", "cache_write", "cache_write_1h",
    "cache_read", "speed", "cost_usd", "priced_as", "session_id", "legacy",
)
USAGE_DDL = """
CREATE TABLE {name} (
    msg_key        TEXT PRIMARY KEY,  -- 'msg:<message.id>:<requestId>'; legacy 'uuid:<uuid>'
    uuid           TEXT,              -- last transcript line of the response
    timestamp      TEXT,
    project        TEXT,
    tool_name      TEXT,              -- tool_use names, comma-joined; 'text' if none
    model          TEXT,
    input_tokens   INTEGER NOT NULL DEFAULT 0,
    output_tokens  INTEGER NOT NULL DEFAULT 0,
    cache_write    INTEGER NOT NULL DEFAULT 0,  -- all cache creation (5m + 1h)
    cache_write_1h INTEGER NOT NULL DEFAULT 0,  -- the 1-hour part of cache_write
    cache_read     INTEGER NOT NULL DEFAULT 0,
    speed          TEXT,
    cost_usd       REAL,              -- NULL: model not in the price table
    priced_as      TEXT,              -- price-table row used; NULL if unpriced
    session_id     TEXT,
    legacy         INTEGER NOT NULL DEFAULT 0   -- 1: pre-1.0 per-line row
)"""


def table_columns(conn, name):
    return [row[1] for row in conn.execute("PRAGMA table_info(%s)" % name)]


def connect(db_path):
    """Open (creating if needed) and migrate to the current schema."""
    directory = os.path.dirname(db_path)
    if directory and not os.path.isdir(directory):
        os.makedirs(directory)
        # Spend and project names are nobody else's business on a shared box.
        # Only a directory created here is tightened; an existing one is the
        # user's choice.
        try:
            os.chmod(directory, 0o700)
        except OSError:
            pass
    fresh = not os.path.exists(db_path)
    # Busy timeout well under the hook's 30 s: a turn that loses the race
    # gives up, and the next Stop picks the work up from the saved offsets.
    conn = sqlite3.connect(db_path, timeout=BUSY_TIMEOUT, isolation_level=None)
    if fresh:
        try:
            os.chmod(db_path, 0o600)
        except OSError:
            pass
    try:
        refuse_newer(conn, db_path)
        conn.execute("PRAGMA journal_mode=WAL")
        migrate(conn, db_path)
    except BaseException:
        conn.close()
        raise
    return conn


def open_readonly(db_path):
    """Read-only handle for --status: never creates, never migrates."""
    uri = "file:%s?mode=ro" % quote(os.path.abspath(db_path))
    return sqlite3.connect(uri, uri=True, timeout=BUSY_TIMEOUT)


def refuse_newer(conn, db_path):
    version = conn.execute("PRAGMA user_version").fetchone()[0]
    if version > SCHEMA_VERSION:
        raise RuntimeError("%s is schema v%d, newer than this tracker (v%d); "
                           "refusing to write" % (db_path, version, SCHEMA_VERSION))


def migrate(conn, db_path):
    version = conn.execute("PRAGMA user_version").fetchone()[0]
    if version >= SCHEMA_VERSION:
        return
    if table_columns(conn, "usage"):
        backup_once(conn, db_path + ".v%d.bak" % version)
    conn.execute("BEGIN IMMEDIATE")
    try:
        # Re-read under the write lock: a concurrent hook may have migrated.
        if conn.execute("PRAGMA user_version").fetchone()[0] < SCHEMA_VERSION:
            conn.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)")
            conn.execute("CREATE TABLE IF NOT EXISTS files (path TEXT PRIMARY KEY,"
                         " size INTEGER, mtime_ns INTEGER, offset INTEGER)")
            if table_columns(conn, "usage"):
                migrate_v0(conn)
            else:
                conn.execute(USAGE_DDL.format(name="usage"))
            conn.execute("CREATE INDEX IF NOT EXISTS usage_ts ON usage(timestamp)")
            conn.execute("CREATE INDEX IF NOT EXISTS usage_session ON usage(session_id)")
            set_meta(conn, "priced_with", pricing.load_pricing().fingerprint())
            conn.execute("PRAGMA user_version = %d" % SCHEMA_VERSION)
        conn.execute("COMMIT")
    except BaseException:
        conn.execute("ROLLBACK")
        raise


def backup_once(conn, path):
    """Copy the pre-migration database aside. Written to a temp name and renamed,
    so a process killed mid-copy never leaves a half backup that looks done."""
    if os.path.exists(path):
        return
    tmp = "%s.%d.tmp" % (path, os.getpid())
    dst = sqlite3.connect(tmp)
    try:
        conn.backup(dst)
    finally:
        dst.close()
    try:
        os.chmod(tmp, 0o600)
    except OSError:
        pass
    os.replace(tmp, path)


def migrate_v0(conn):
    """Per-line rows (0.12-0.19) -> v2, in the caller's transaction.

    Claude Code deletes old transcripts (about 30 days by default), so these
    rows may be the only record of that spend. Every row is copied and counted
    before the old table goes. The old schema stored no message id, so rows
    cannot be collapsed from the database alone: they are marked legacy, and
    ingest collapses them wherever their transcript still exists. Costs are
    recomputed from the stored tokens; the old schema had no 1h split, so all
    cache writes are priced as 5-minute writes (the cheaper of the two).
    """
    columns = table_columns(conn, "usage")
    if "msg_key" in columns:
        return  # already v2-shaped, only the version stamp was missing
    before = conn.execute("SELECT COUNT(*) FROM usage").fetchone()[0]
    conn.execute(USAGE_DDL.format(name="usage_v2"))
    conn.execute(
        "INSERT INTO usage_v2 (%s) SELECT 'uuid:' || uuid, uuid, timestamp, project,"
        " tool_name, model, COALESCE(input_tokens, 0), COALESCE(output_tokens, 0),"
        " COALESCE(cache_write, 0), 0, COALESCE(cache_read, 0), NULL, cost_usd, NULL,"
        " session_id, 1 FROM usage" % ", ".join(COLUMNS)
    )
    after = conn.execute("SELECT COUNT(*) FROM usage_v2").fetchone()[0]
    if after != before:
        raise RuntimeError("migration copied %d of %d rows; rolled back" % (after, before))
    conn.execute("DROP TABLE usage")
    conn.execute("ALTER TABLE usage_v2 RENAME TO usage")
    reprice_rows(conn, pricing.load_pricing())
    set_meta(conn, "needs_rescan", "1")
    set_meta(conn, "migrated_v0", "%s, %d rows kept" % (time.strftime("%Y-%m-%d"), before))


def get_meta(conn, key):
    row = conn.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
    return row[0] if row else None


def set_meta(conn, key, value):
    if value is None:
        conn.execute("DELETE FROM meta WHERE key = ?", (key,))
    else:
        conn.execute("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", (key, value))


def reprice_rows(conn, table):
    """Recompute cost_usd / priced_as for every row from its stored tokens."""
    rows = conn.execute(
        "SELECT msg_key, model, speed, input_tokens, output_tokens, cache_write,"
        " cache_write_1h, cache_read, cost_usd, priced_as FROM usage"
    ).fetchall()
    changed = 0
    for key, model, speed, i, o, w, w1, r, old_cost, old_as in rows:
        cost, priced_as = pricing.cost_usd(model, speed, i or 0, o or 0, w or 0,
                                           w1 or 0, r or 0, table)
        if cost != old_cost or priced_as != old_as:
            conn.execute("UPDATE usage SET cost_usd = ?, priced_as = ? WHERE msg_key = ?",
                         (cost, priced_as, key))
            changed += 1
    set_meta(conn, "priced_with", table.fingerprint())
    return len(rows), changed


def transaction(conn, fn, *args):
    conn.execute("BEGIN IMMEDIATE")
    try:
        result = fn(conn, *args)
        conn.execute("COMMIT")
        return result
    except BaseException:
        conn.execute("ROLLBACK")
        raise
