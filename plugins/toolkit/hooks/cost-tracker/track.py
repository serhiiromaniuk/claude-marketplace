#!/usr/bin/env python3
"""Claude Code cost tracker — token/USD usage from local transcripts.

Reads Claude Code's own session transcripts (`<config-dir>/projects/**/*.jsonl`)
and records one row per API response in a local SQLite database. Runs as a
`Stop` hook (which fires at the end of every turn) and as a CLI.

    track.py                  # hook: ingest the session named on stdin; with no
                              #   stdin payload, every transcript, incrementally
    track.py --backfill       # re-read every transcript in every known config dir
    track.py <file.jsonl> ... # re-read specific transcripts
    track.py --status         # collector health: last run, last error, gaps
    track.py --report         # spend by day, project, model, session and tool
    track.py --csv FILE       # export every row
    track.py --reprice        # recompute every row's cost from its stored tokens
    track.py --self-test      # run the bundled tests, in a temp dir only

One response is one row. Claude Code writes a response as several transcript
lines (thinking, text, each tool_use), each with its own uuid and a copy of the
response's usage, so rows are keyed by API message id + request id: the last
line's usage wins and tool names are merged across the lines.

Privacy: only metadata is stored — message ids, timestamp, project directory
*name*, tool names, model, token counts, computed cost, session id. Prompt and
response text are never read into the database.

Environment overrides:
    CLAUDE_CONFIG_DIR    extra config dir to scan (Claude Code's own variable)
    CLAUDE_COST_DB       database path (default ~/.claude-cost-tracker/usage.db);
                         last-run.json and last-error.json live next to it
    CLAUDE_COST_PRICING  JSON file of extra or replacement rates, see pricing.py
    CLAUDE_COST_QUIET    same as --quiet
"""
import argparse
import glob
import json
import os
import select
import sqlite3
import sys
import time

sys.dont_write_bytecode = True  # runs from a plugin cache dir: leave it clean
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pricing  # noqa: E402
import store  # noqa: E402

HOME = os.path.expanduser("~")
DB_PATH = os.environ.get("CLAUDE_COST_DB") or os.path.join(
    HOME, ".claude-cost-tracker", "usage.db"
)
STDIN_TIMEOUT = 2.0  # seconds to wait for a hook payload on a non-TTY stdin
# Unattended runs (hook, scan, post-migration rescan) stop starting new files
# after this many seconds, well inside the hook's 30 s timeout; per-file
# offsets let the next turn carry on where this one stopped.
TIME_BUDGET = 15.0


class UsageError(Exception):
    pass


class Parser(argparse.ArgumentParser):
    # argparse exits 2 on a bad flag, and a Stop hook that exits 2 blocks
    # Claude from stopping. Raise instead; __main__ picks a safe exit code.
    def error(self, message):
        raise UsageError(message)


# ---------------------------------------------------------------- discovery

def config_dirs():
    """Every plausible Claude Code config dir, in priority order, de-duplicated.

    A moved CLAUDE_CONFIG_DIR is the usual reason a tracker silently stops
    collecting, so both the environment's dir and the default are scanned.
    """
    candidates = [os.environ.get("CLAUDE_CONFIG_DIR"), os.path.join(HOME, ".claude")]
    seen, out = set(), []
    for c in candidates:
        if not c:
            continue
        real = os.path.realpath(os.path.expanduser(c))
        if real in seen or not os.path.isdir(real):
            continue
        seen.add(real)
        out.append(real)
    return out


def transcript_files():
    files, seen = [], set()
    for d in config_dirs():
        for path in glob.glob(os.path.join(glob.escape(d), "projects", "**", "*.jsonl"),
                              recursive=True):
            real = os.path.realpath(path)
            if real not in seen:
                seen.add(real)
                files.append(path)
    return files


def session_files(payload):
    """The hook's transcript plus its subagents' (`<session>/subagents/*.jsonl`)."""
    path = payload.get("transcript_path") if isinstance(payload, dict) else None
    if not isinstance(path, str) or not path.endswith(".jsonl"):
        return None
    path = os.path.expanduser(path)
    if not os.path.isfile(path):
        return None
    stem = glob.escape(path[: -len(".jsonl")])
    nested = glob.glob(os.path.join(stem, "**", "*.jsonl"), recursive=True)
    return [path] + sorted(nested)


def read_hook_payload(timeout=STDIN_TIMEOUT):
    """The Stop hook's stdin JSON, or None. Never waits on a terminal."""
    stdin = sys.stdin
    try:
        if stdin is None or stdin.closed or stdin.isatty():
            return None
        fd = stdin.fileno()
    except (OSError, ValueError):
        return None
    chunks, deadline = [], time.monotonic() + timeout
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        try:
            ready, _, _ = select.select([fd], [], [], remaining)
        except (OSError, ValueError):  # select() cannot poll this stdin
            break
        if not ready:
            break
        chunk = os.read(fd, 65536)
        if not chunk:
            break
        chunks.append(chunk)
        payload = _parse_payload(chunks)
        if payload is not None:  # complete; do not wait for the writer to close
            return payload
    return _parse_payload(chunks)


def _parse_payload(chunks):
    try:
        payload = json.loads(b"".join(chunks).decode("utf-8", "replace"))
    except ValueError:
        return None
    return payload if isinstance(payload, dict) else None


# ---------------------------------------------------------------- parsing

def project_from_cwd(cwd):
    if not cwd:
        return "unknown"
    return os.path.basename(cwd.rstrip("/")) or cwd


def tool_names(content):
    names = []
    if isinstance(content, list):
        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                names.append(str(block.get("name") or "tool"))
    return names


def merge_tools(*lists):
    out = []
    for names in lists:
        for name in names:
            if name and name != "text" and name not in out:
                out.append(name)
    return out


def count(usage, key):
    value = usage.get(key, 0)
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        return 0
    return value


def read_messages(path, offset):
    """Parse assistant responses from byte `offset`; return ({key: msg}, next_offset).

    A trailing line without a newline may still be being written: it is parsed
    if complete, but the offset stays before it so the next run reads it again.
    """
    msgs, pos = {}, offset
    with open(path, "rb") as fh:
        fh.seek(offset)
        for raw in fh:
            if raw.endswith(b"\n"):
                pos += len(raw)
            if b'"assistant"' not in raw:
                continue
            try:
                rec = json.loads(raw.decode("utf-8", "replace"))
            except (ValueError, RecursionError):
                continue
            if not isinstance(rec, dict) or rec.get("type") != "assistant":
                continue
            msg = rec.get("message")
            usage = msg.get("usage") if isinstance(msg, dict) else None
            uuid = rec.get("uuid")
            if not isinstance(usage, dict) or not uuid:
                continue
            mid = msg.get("id")
            key = "msg:%s:%s" % (mid, rec.get("requestId") or "") if mid else "uuid:%s" % uuid
            m = msgs.get(key)
            if m is None:
                m = msgs[key] = {
                    "timestamp": str(rec.get("timestamp", "")),
                    "project": project_from_cwd(str(rec.get("cwd", ""))),
                    "session_id": str(rec.get("sessionId", "")),
                    "model": str(msg.get("model") or "unknown"),
                    "uuids": [], "tools": [],
                }
            m["uuids"].append(str(uuid))
            m["usage"] = usage  # earlier lines carry partial output; the last wins
            m["tools"] = merge_tools(m["tools"], tool_names(msg.get("content")))
    return msgs, pos


def build_row(key, m, table):
    usage = m["usage"]
    cache = usage.get("cache_creation")
    in_tok, out_tok = count(usage, "input_tokens"), count(usage, "output_tokens")
    cache_w = count(usage, "cache_creation_input_tokens")
    cache_w_1h = 0
    if isinstance(cache, dict):
        cache_w_1h = count(cache, "ephemeral_1h_input_tokens")
        cache_w = max(cache_w, count(cache, "ephemeral_5m_input_tokens") + cache_w_1h)
    cache_r = count(usage, "cache_read_input_tokens")
    speed = usage.get("speed") if isinstance(usage.get("speed"), str) else None
    cost, priced_as = pricing.cost_usd(m["model"], speed, in_tok, out_tok, cache_w,
                                       cache_w_1h, cache_r, table)
    return {
        "msg_key": key, "uuid": m["uuids"][-1], "timestamp": m["timestamp"],
        "project": m["project"], "tool_name": ",".join(m["tools"]) or "text",
        "model": m["model"], "input_tokens": in_tok, "output_tokens": out_tok,
        "cache_write": cache_w, "cache_write_1h": cache_w_1h, "cache_read": cache_r,
        "speed": speed, "cost_usd": cost, "priced_as": priced_as,
        "session_id": m["session_id"], "legacy": 0,
    }


# ---------------------------------------------------------------- ingest

INSERT_SQL = "INSERT OR IGNORE INTO usage (%s) VALUES (%s)" % (
    ", ".join(store.COLUMNS), ", ".join("?" * len(store.COLUMNS)))
TOKEN_COLUMNS = ("uuid", "input_tokens", "output_tokens", "cache_write", "cache_write_1h",
                 "cache_read", "speed", "cost_usd", "priced_as")


def store_messages(conn, msgs, table, collapse_legacy, stats):
    for key, m in msgs.items():
        if collapse_legacy:
            legacy_keys = ["uuid:" + u for u in m["uuids"]]
            stats["legacy_collapsed"] += conn.execute(
                "DELETE FROM usage WHERE legacy = 1 AND msg_key IN (%s)"
                % ",".join("?" * len(legacy_keys)), legacy_keys).rowcount
        row = build_row(key, m, table)
        if conn.execute(INSERT_SQL, [row[c] for c in store.COLUMNS]).rowcount:
            stats["rows_added"] += 1
            continue
        # Seen before: from an earlier offset, another file (a forked session),
        # or a run that caught it mid-stream. Keep the fullest usage, union tools.
        old_out, old_tools = conn.execute(
            "SELECT output_tokens, tool_name FROM usage WHERE msg_key = ?", (key,)).fetchone()
        tools = ",".join(merge_tools((old_tools or "").split(","), m["tools"])) or "text"
        sets = {"tool_name": tools}
        if row["output_tokens"] > (old_out or 0):
            sets.update((c, row[c]) for c in TOKEN_COLUMNS)
        elif tools == old_tools:
            continue
        conn.execute("UPDATE usage SET %s WHERE msg_key = ?" % ", ".join("%s = ?" % c for c in sets),
                     list(sets.values()) + [key])
        stats["rows_updated"] += 1


def ingest_file(conn, path, table, full, collapse_legacy, stats):
    real = os.path.realpath(path)
    try:
        st = os.stat(real)
    except OSError:
        return
    prev = conn.execute("SELECT size, mtime_ns, offset FROM files WHERE path = ?",
                        (real,)).fetchone()
    if prev and not full and prev[0] == st.st_size and prev[1] == st.st_mtime_ns:
        return  # unchanged since the last run
    offset = prev[2] if prev and not full and st.st_size >= prev[2] else 0
    try:
        msgs, next_offset = read_messages(real, offset)
    except OSError:
        return
    stats["transcripts_read"] += 1
    # Legacy rows predate the migration, so their lines are never past a saved
    # offset: only a read from the start of a file can collapse them.
    collapse = collapse_legacy and offset == 0

    def write(conn):
        store_messages(conn, msgs, table, collapse, stats)
        conn.execute("INSERT OR REPLACE INTO files (path, size, mtime_ns, offset)"
                     " VALUES (?, ?, ?, ?)", (real, st.st_size, st.st_mtime_ns, next_offset))

    store.transaction(conn, write)


def ingest(db_path, paths=None, backfill=False, payload=None, budget=TIME_BUDGET):
    """Explicit paths > --backfill > a pending post-migration rescan > the hook
    payload's session > every transcript. Only the first two ignore offsets and
    the time budget; the rest are unattended and resume where they stopped."""
    started = time.monotonic()
    table = pricing.load_pricing()
    conn = store.connect(db_path)
    try:
        rescan = store.get_meta(conn, "needs_rescan") == "1"
        if paths:
            mode, files, full = "paths", list(paths), True
        elif backfill:
            mode, files, full = "backfill", transcript_files(), True
        elif rescan:
            mode, files, full = "rescan", transcript_files(), False
        else:
            files = session_files(payload) if payload else None
            mode, full = ("hook" if files else "scan"), False
            files = files or transcript_files()
        collapse = bool(conn.execute(
            "SELECT EXISTS(SELECT 1 FROM usage WHERE legacy = 1)").fetchone()[0])
        stats = {"rows_added": 0, "rows_updated": 0, "legacy_collapsed": 0,
                 "transcripts_read": 0, "file_errors": 0, "complete": True}
        for n, path in enumerate(files):
            if not full and n and time.monotonic() - started > budget:
                stats["complete"] = False
                break
            try:
                ingest_file(conn, path, table, full, collapse, stats)
            except sqlite3.Error:
                raise  # the database itself is unwell: stop, leave a breadcrumb
            except Exception as exc:  # one odd transcript must not starve the rest
                stats["file_errors"] += 1
                stats["file_error"] = ("%s: %s: %s" % (path, type(exc).__name__, exc))[:500]
        if rescan and mode in ("backfill", "rescan") and stats["complete"]:
            store.set_meta(conn, "needs_rescan", None)
        if store.get_meta(conn, "priced_with") != table.fingerprint():
            store.set_meta(conn, "reprice_hint", "1")
    finally:
        conn.close()
    stats.update(mode=mode, transcripts_seen=len(files),
                 elapsed_ms=int((time.monotonic() - started) * 1000),
                 pricing_warning=table.warning)
    write_state(db_path, "last-run.json", stats)
    return stats


def cmd_reprice(db_path):
    if not os.path.exists(db_path):
        print("no database at %s — nothing to reprice" % db_path)
        return 0
    table = pricing.load_pricing()
    conn = store.connect(db_path)
    try:
        before = conn.execute("SELECT ROUND(SUM(cost_usd), 2) FROM usage").fetchone()[0]

        def write(conn):
            result = store.reprice_rows(conn, table)
            store.set_meta(conn, "reprice_hint", None)
            return result

        total, changed = store.transaction(conn, write)
        after = conn.execute("SELECT ROUND(SUM(cost_usd), 2) FROM usage").fetchone()[0]
    finally:
        conn.close()
    if table.warning:
        print("WARNING: " + table.warning)
    print("repriced %d rows (%d changed): $%s -> $%s" % (total, changed, before, after))
    return 0


# ---------------------------------------------------------------- state

def write_state(db_path, name, payload):
    """Leave a breadcrumb next to the database so a broken tracker is visible.

    The hook exits 0 whatever happens; without this, a moved config dir or a
    crashing ingest looks exactly like a quiet week.
    """
    path = os.path.join(os.path.dirname(db_path) or ".", name)
    payload = dict(payload, at=time.strftime("%Y-%m-%dT%H:%M:%S%z"), config_dirs=config_dirs())
    try:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
        os.chmod(path, 0o600)
    except OSError:
        pass


# ---------------------------------------------------------------- CLI

def build_parser():
    p = Parser(
        prog="track.py",
        description="Claude Code token spend from local transcripts, into SQLite.",
        epilog="Exit status: 0 on success and always with --quiet; 1 on error. "
               "With --quiet, failures land in last-error.json next to the database.",
    )
    p.add_argument("paths", nargs="*", metavar="FILE.jsonl",
                   help="transcripts to re-read (default: the hook payload's session, "
                        "else every transcript, incrementally)")
    mode = p.add_mutually_exclusive_group()
    mode.add_argument("--backfill", action="store_true",
                      help="re-read every transcript in every known config dir")
    mode.add_argument("--status", action="store_true", help="collector health")
    mode.add_argument("--report", action="store_true", help="print the spend report")
    mode.add_argument("--csv", metavar="FILE", help="export every row to FILE")
    mode.add_argument("--reprice", action="store_true",
                      help="recompute every row's cost with the current price table")
    mode.add_argument("--self-test", action="store_true", help="run the bundled tests")
    p.add_argument("--quiet", action="store_true",
                   help="hook mode: no output, exit 0 even on error")
    return p


def main(argv):
    args = build_parser().parse_args(argv)
    modal = args.status or args.report or args.csv or args.reprice or args.self_test
    if args.paths and (modal or args.backfill):
        raise UsageError("transcript paths cannot be combined with --%s" % (
            "backfill" if args.backfill else "status/--report/--csv/--reprice/--self-test"))
    if modal:
        import report  # only the read-side modes need it; keeps the hook lean
    if args.self_test:
        return report.self_test(os.path.dirname(os.path.abspath(__file__)))
    if args.status:
        return report.status(DB_PATH, config_dirs(), transcript_files())
    if args.report:
        return report.text_report(DB_PATH)
    if args.csv:
        return report.csv_export(DB_PATH, args.csv)
    if args.reprice:
        return cmd_reprice(DB_PATH)

    quiet = args.quiet or bool(os.environ.get("CLAUDE_COST_QUIET"))
    payload = None if (args.paths or args.backfill) else read_hook_payload()
    stats = ingest(DB_PATH, paths=args.paths, backfill=args.backfill, payload=payload)
    if not quiet:
        print("Ingested %d new and %d updated responses (%d legacy rows collapsed) from "
              "%d of %d transcript(s) into %s [%s, %d ms]" % (
                  stats["rows_added"], stats["rows_updated"], stats["legacy_collapsed"],
                  stats["transcripts_read"], stats["transcripts_seen"], DB_PATH,
                  stats["mode"], stats["elapsed_ms"]))
        if stats["pricing_warning"]:
            print("WARNING: " + stats["pricing_warning"])
        if stats["file_errors"]:
            print("WARNING: %d transcript(s) failed, last: %s" % (
                stats["file_errors"], stats["file_error"]))
    return 0


def run(argv):
    quiet = "--quiet" in argv or bool(os.environ.get("CLAUDE_COST_QUIET"))
    try:
        return main(argv)
    except KeyboardInterrupt:
        return 0 if quiet else 130
    except UsageError as exc:
        if quiet:  # a bad flag in hooks.json must still be visible in --status
            write_state(DB_PATH, "last-error.json", {"error": "usage: %s" % exc})
            return 0
        sys.stderr.write("track.py: error: %s (see --help)\n" % exc)
        return 1
    except Exception as exc:  # never let a hook break the session
        if quiet:  # unattended: the breadcrumb is the only place anyone sees it
            write_state(DB_PATH, "last-error.json",
                        {"error": ("%s: %s" % (type(exc).__name__, exc))[:500]})
            return 0
        sys.stderr.write("cost-tracker: %s: %s\n" % (type(exc).__name__, exc))
        return 1


if __name__ == "__main__":
    sys.exit(run(sys.argv[1:]))
