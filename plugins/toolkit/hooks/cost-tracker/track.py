#!/usr/bin/env python3
"""Claude Code cost tracker — token/USD usage from local transcripts.

Reads Claude Code's own session transcripts (`<config-dir>/projects/**/*.jsonl`)
and records one row per assistant message in a local SQLite database. Runs as a
`Stop` hook for continuous capture, and as a CLI for backfilling history.

    track.py                  # scan every known config dir, ingest what is new
    track.py <file.jsonl> ... # ingest specific transcripts
    track.py --status         # when did the last ingest run, and did it see data
    track.py --self-test      # synthetic end-to-end check, touches only a temp dir

Idempotent: rows are keyed by assistant-message uuid, so re-running is free and
losing the hook for a while costs nothing as long as the transcripts survive.

Privacy: only metadata is stored — message uuid, timestamp, project directory
*name*, tool name, model, token counts, computed cost, session id. Prompt and
response text are never read into the database.

Environment overrides:
    CLAUDE_CONFIG_DIR    extra config dir to scan (Claude Code's own variable)
    CLAUDE_COST_DB       database path (default ~/.claude-cost-tracker/usage.db)
    CLAUDE_COST_PRICING  path to a JSON file of per-model rates, see PRICING
"""
import glob
import json
import os
import sqlite3
import sys
import tempfile
import time

HOME = os.path.expanduser("~")
DB_PATH = os.environ.get("CLAUDE_COST_DB") or os.path.join(
    HOME, ".claude-cost-tracker", "usage.db"
)

# Pricing in USD per 1,000,000 tokens, as (input, output, cache_write, cache_read).
# ESTIMATES — verify against your own plan. Anthropic first-party rates; Bedrock
# and Vertex are partner-operated and priced separately.
#
# Cache multipliers are structural, not per-model: write = 1.25x input,
# read = 0.10x input. Keep them derived from the input rate when editing a row.
#
# LONG-CONTEXT TIER: every current model (Opus 5/4.8/4.7/4.6, Sonnet 5/4.6,
# Fable 5, Mythos 5) has a 1M window at a SINGLE price — there is no >200K
# premium to apply, so "long" equals "std" for every family below. The tier
# machinery is kept because the CLAUDE_COST_PRICING override uses it and older
# 1M-context betas did carry a ~2x premium; do not reintroduce a premium for a
# current model without a published rate for it.
#
# Order matters: first substring match wins.
# Override the whole table with CLAUDE_COST_PRICING pointing at a JSON file:
#   {"threshold": 200000, "default": {...},
#    "models": [["opus", {"std": [5,25,6.25,0.50], "long": [...]}], ...]}
LONG_CTX_THRESHOLD = 200_000
PRICING = [
    # Opus 5 / 4.8 / 4.7 / 4.6 — $5 in, $25 out. NOT the retired Claude 3 Opus
    # $15/$75, which is the single easiest way to overstate a bill by 3x.
    ("opus",   {"std": (5.0, 25.0, 6.25, 0.50), "long": (5.0, 25.0, 6.25, 0.50)}),
    # Sonnet 5 / 4.6 — $3/$15 is the durable rate. Sonnet 5 carries a $2/$10
    # introductory rate through 2026-08-31; this table deliberately does NOT
    # encode it, because a hardcoded intro price silently overstates the
    # discount the day it lapses. Undercounts Sonnet slightly until then.
    ("sonnet", {"std": (3.0, 15.0, 3.75, 0.30), "long": (3.0, 15.0, 3.75, 0.30)}),
    ("haiku",  {"std": (1.0,  5.0, 1.25, 0.10), "long": (1.0,  5.0, 1.25, 0.10)}),
    # Fable 5 and Mythos 5 — $10 in, $50 out. Above the Opus tier, not equal to it.
    ("fable",  {"std": (10.0, 50.0, 12.50, 1.00), "long": (10.0, 50.0, 12.50, 1.00)}),
    ("mythos", {"std": (10.0, 50.0, 12.50, 1.00), "long": (10.0, 50.0, 12.50, 1.00)}),
]
# Unknown / unreleased model: assume the Sonnet tier rather than the top tier —
# a new id is far more often mid-tier than frontier, and guessing high turns
# every unrecognised model into a phantom bill. Verify before quoting.
DEFAULT_PRICE = {"std": (3.0, 15.0, 3.75, 0.30), "long": (3.0, 15.0, 3.75, 0.30)}


def load_pricing():
    """Return (threshold, models, default), honouring CLAUDE_COST_PRICING."""
    path = os.environ.get("CLAUDE_COST_PRICING")
    if not path:
        return LONG_CTX_THRESHOLD, PRICING, DEFAULT_PRICE
    try:
        with open(path, "r", encoding="utf-8") as fh:
            cfg = json.load(fh)
        models = [(str(k).lower(), v) for k, v in cfg.get("models", [])]
        return (
            int(cfg.get("threshold", LONG_CTX_THRESHOLD)),
            models or PRICING,
            cfg.get("default", DEFAULT_PRICE),
        )
    except (OSError, ValueError, TypeError):
        # A malformed override must not stop collection — fall back to built-ins.
        return LONG_CTX_THRESHOLD, PRICING, DEFAULT_PRICE


def price_for(model, ctx_tokens, threshold, models, default):
    m = (model or "").lower()
    fam = default
    for key, tiers in models:
        if key in m:
            fam = tiers
            break
    return fam["long"] if ctx_tokens > threshold else fam["std"]


def cost_usd(model, in_tok, out_tok, cache_w, cache_r, pricing):
    threshold, models, default = pricing
    # A request's billable context is fresh input plus cache traffic; that sum is
    # what crosses into the long-context tier, not output.
    ctx = in_tok + cache_w + cache_r
    pi, po, pcw, pcr = price_for(model, ctx, threshold, models, default)
    return round(
        (in_tok * pi + out_tok * po + cache_w * pcw + cache_r * pcr) / 1_000_000, 6
    )


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
        for path in glob.glob(os.path.join(d, "projects", "**", "*.jsonl"), recursive=True):
            real = os.path.realpath(path)
            if real not in seen:
                seen.add(real)
                files.append(path)
    return files


def project_from_cwd(cwd):
    if not cwd:
        return "unknown"
    return os.path.basename(cwd.rstrip("/")) or cwd


def primary_tool(content):
    if isinstance(content, list):
        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                return block.get("name", "tool")
    return "text"


def connect(db_path):
    directory = os.path.dirname(db_path)
    if directory:
        os.makedirs(directory, exist_ok=True)
        try:
            os.chmod(directory, 0o700)
        except OSError:
            pass
    fresh = not os.path.exists(db_path)
    conn = sqlite3.connect(db_path)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS usage (
            uuid          TEXT PRIMARY KEY,
            timestamp     TEXT,
            project       TEXT,
            tool_name     TEXT,
            model         TEXT,
            input_tokens  INTEGER,
            output_tokens INTEGER,
            cache_write   INTEGER,
            cache_read    INTEGER,
            cost_usd      REAL,
            session_id    TEXT
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS usage_ts ON usage(timestamp)")
    conn.commit()
    if fresh:
        # Spend and project names are nobody else's business on a shared box.
        try:
            os.chmod(db_path, 0o600)
        except OSError:
            pass
    return conn


def ingest_file(conn, path, pricing):
    added = 0
    try:
        # Streamed line by line: transcripts reach tens of MB and a Stop hook
        # must not hold one in memory.
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line or '"assistant"' not in line:
                    continue
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(rec, dict) or rec.get("type") != "assistant":
                    continue
                msg = rec.get("message") or {}
                usage = msg.get("usage") if isinstance(msg, dict) else None
                uuid = rec.get("uuid")
                if not isinstance(usage, dict) or not uuid:
                    continue

                def count(key):
                    value = usage.get(key, 0)
                    return value if isinstance(value, int) and value >= 0 else 0

                in_tok = count("input_tokens")
                out_tok = count("output_tokens")
                cache_w = count("cache_creation_input_tokens")
                cache_r = count("cache_read_input_tokens")
                model = msg.get("model") or "unknown"
                row = (
                    str(uuid),
                    str(rec.get("timestamp", "")),
                    project_from_cwd(str(rec.get("cwd", ""))),
                    primary_tool(msg.get("content")),
                    str(model),
                    in_tok,
                    out_tok,
                    cache_w,
                    cache_r,
                    cost_usd(model, in_tok, out_tok, cache_w, cache_r, pricing),
                    str(rec.get("sessionId", "")),
                )
                cur = conn.execute(
                    "INSERT OR IGNORE INTO usage VALUES (?,?,?,?,?,?,?,?,?,?,?)", row
                )
                added += cur.rowcount
    except OSError:
        return 0
    conn.commit()
    return added


def write_status(db_path, files_seen, rows_added):
    """Leave a breadcrumb so a silently-broken tracker is discoverable.

    The hook exits 0 whatever happens; without this, a moved config dir looks
    exactly like a quiet week.
    """
    path = os.path.join(os.path.dirname(db_path) or ".", "last-run.json")
    payload = {
        "ran_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "config_dirs": config_dirs(),
        "transcripts_seen": files_seen,
        "rows_added": rows_added,
    }
    try:
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
        os.chmod(path, 0o600)
    except OSError:
        pass


def cmd_status(db_path):
    path = os.path.join(os.path.dirname(db_path) or ".", "last-run.json")
    print(f"database:    {db_path}")
    print(f"config dirs: {', '.join(config_dirs()) or '(none found)'}")
    print(f"transcripts: {len(transcript_files())}")
    try:
        with open(path, "r", encoding="utf-8") as fh:
            last = json.load(fh)
        print(f"last run:    {last.get('ran_at')} "
              f"(+{last.get('rows_added')} rows from {last.get('transcripts_seen')} files)")
    except (OSError, ValueError):
        print("last run:    never (no last-run.json)")
    if os.path.exists(db_path):
        conn = sqlite3.connect(db_path)
        try:
            row = conn.execute(
                "SELECT MIN(date(timestamp)), MAX(date(timestamp)), COUNT(*),"
                " COUNT(DISTINCT session_id), ROUND(SUM(cost_usd), 2) FROM usage"
            ).fetchone()
            print(f"rows:        {row[2]} over {row[3]} sessions, {row[0]} .. {row[1]}")
            print(f"estimated:   ${row[4]}")
            stale = conn.execute(
                "SELECT julianday('now') - julianday(MAX(timestamp)) FROM usage"
            ).fetchone()[0]
            if stale is not None and stale > 3:
                print(f"WARNING:     newest row is {stale:.0f} days old — "
                      "check CLAUDE_CONFIG_DIR and re-run a backfill")
        finally:
            conn.close()
    return 0


def cmd_self_test():
    """End-to-end check on synthetic data in a temp dir. Touches nothing real."""
    sample = {
        "type": "assistant",
        "uuid": "test-uuid-1",
        "timestamp": "2026-01-01T00:00:00Z",
        "cwd": "/tmp/demo-project",
        "sessionId": "sess-1",
        "message": {
            "model": "claude-sonnet-test",
            "usage": {
                "input_tokens": 100_000,
                "output_tokens": 10_000,
                "cache_creation_input_tokens": 0,
                "cache_read_input_tokens": 0,
            },
            "content": [{"type": "tool_use", "name": "Bash"}],
        },
    }
    with tempfile.TemporaryDirectory() as tmp:
        transcript = os.path.join(tmp, "t.jsonl")
        with open(transcript, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(sample) + "\n")
            fh.write("not json\n")
            fh.write(json.dumps({"type": "user", "uuid": "u1"}) + "\n")
            fh.write(json.dumps(sample) + "\n")  # duplicate uuid
        db = os.path.join(tmp, "usage.db")
        conn = connect(db)
        added = ingest_file(conn, transcript, load_pricing())
        row = conn.execute(
            "SELECT tool_name, project, input_tokens, cost_usd FROM usage"
        ).fetchone()
        total = conn.execute("SELECT COUNT(*) FROM usage").fetchone()[0]
        conn.close()

        checks = [
            ("one row added", added == 1),
            ("duplicate uuid ignored", total == 1),
            ("tool captured", row[0] == "Bash"),
            ("project is dir name", row[1] == "demo-project"),
            ("tokens captured", row[2] == 100_000),
            # 100k in @ $3/M + 10k out @ $15/M = $0.45 on the Sonnet tier
            ("standard tier priced", abs(row[3] - 0.45) < 1e-6),
            # Crossing 200k must NOT change the rate: no current model has a
            # long-context premium. This is the regression guard for the phantom
            # ~2x that shipped in 0.12.0.
            ("no long-context premium",
             abs(cost_usd("claude-sonnet-test", 300_000, 10_000, 0, 0, load_pricing())
                 - (300_000 * 3.0 + 10_000 * 15.0) / 1_000_000) < 1e-9),
            # Opus must be the $5/$25 tier, never Claude 3 Opus $15/$75.
            ("opus priced at 5/25",
             abs(cost_usd("claude-opus-5", 1_000_000, 1_000_000, 0, 0, load_pricing())
                 - 30.0) < 1e-9),
            # Cache read is a tenth of input; write is 1.25x.
            ("opus cache multipliers",
             abs(cost_usd("claude-opus-5", 0, 0, 1_000_000, 1_000_000, load_pricing())
                 - (6.25 + 0.50)) < 1e-9),
            # Fable is above the Opus tier.
            ("fable priced at 10/50",
             abs(cost_usd("claude-fable-5", 1_000_000, 0, 0, 0, load_pricing())
                 - 10.0) < 1e-9),
            ("unknown model falls back", cost_usd("mystery", 1_000, 0, 0, 0,
                                                 load_pricing()) > 0),
        ]
        failed = [name for name, ok in checks if not ok]
        for name, ok in checks:
            print(f"  {'ok  ' if ok else 'FAIL'} {name}")
        if failed:
            print(f"self-test FAILED: {', '.join(failed)}")
            return 1
        print("self-test passed")
        return 0


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("-")]
    flags = {a for a in argv[1:] if a.startswith("-")}

    if "--self-test" in flags:
        return cmd_self_test()
    if "--status" in flags:
        return cmd_status(DB_PATH)

    quiet = "--quiet" in flags or bool(os.environ.get("CLAUDE_COST_QUIET"))
    pricing = load_pricing()
    files = args or transcript_files()
    conn = connect(DB_PATH)
    total = 0
    try:
        for path in files:
            total += ingest_file(conn, path, pricing)
    finally:
        conn.close()
    write_status(DB_PATH, len(files), total)
    if not quiet:
        print(f"Ingested {total} new message rows from {len(files)} transcript(s) "
              f"into {DB_PATH}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as exc:  # never let a hook break the session
        sys.stderr.write(f"cost-tracker: {type(exc).__name__}: {exc}\n")
        sys.exit(0)
