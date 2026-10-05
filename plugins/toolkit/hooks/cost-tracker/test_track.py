"""Tests for the cost tracker. Stdlib unittest; every test works in a temp dir.

    python3 -m unittest discover -s plugins/toolkit/hooks/cost-tracker -p 'test_*.py'
    python3 plugins/toolkit/hooks/cost-tracker/track.py --self-test
"""
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import pricing  # noqa: E402
import report  # noqa: E402
import store  # noqa: E402
import track  # noqa: E402

TRACK = os.path.join(HERE, "track.py")

# The 0.12-0.19 schema, verbatim, for migration tests.
V0_DDL = """CREATE TABLE usage (uuid TEXT PRIMARY KEY, timestamp TEXT, project TEXT,
    tool_name TEXT, model TEXT, input_tokens INTEGER, output_tokens INTEGER,
    cache_write INTEGER, cache_read INTEGER, cost_usd REAL, session_id TEXT)"""


def usage(i=0, o=0, w=0, r=0, w1h=None, **extra):
    u = {"input_tokens": i, "output_tokens": o, "cache_creation_input_tokens": w,
         "cache_read_input_tokens": r}
    if w1h is not None:
        u["cache_creation"] = {"ephemeral_5m_input_tokens": w - w1h,
                               "ephemeral_1h_input_tokens": w1h}
    u.update(extra)
    return u


def line(uuid, msg_id, u, block, model="claude-opus-5-5", req="req_1", session="s1",
         ts="2026-09-01T10:00:00Z"):
    return json.dumps({
        "type": "assistant", "uuid": uuid, "requestId": req, "sessionId": session,
        "timestamp": ts, "cwd": "/tmp/demo-project",
        "message": {"id": msg_id, "model": model, "usage": u, "content": [block]},
    }) + "\n"


def tool(name):
    return {"type": "tool_use", "name": name, "id": "t-" + name, "input": {}}


THINK = {"type": "thinking", "thinking": ""}
TEXT = {"type": "text", "text": "x"}


def response_a():
    """One API response written as three lines, as Claude Code does."""
    return [
        line("a1", "msg_A", usage(10, 5, 1000, 50000, w1h=400), THINK, req="req_A"),
        line("a2", "msg_A", usage(10, 40, 1000, 50000, w1h=400), TEXT, req="req_A"),
        line("a3", "msg_A", usage(10, 120, 1000, 50000, w1h=400), tool("Bash"), req="req_A"),
    ]


def response_b():
    return [
        line("b1", "msg_B", usage(3, 30, 0, 51000), tool("Read"), req="req_B"),
        line("b2", "msg_B", usage(3, 60, 0, 51000), tool("Grep"), req="req_B"),
    ]


class TempDirCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = self._tmp.name
        self.db = os.path.join(self.tmp, "state", "usage.db")
        self.config = os.path.join(self.tmp, "config")
        os.makedirs(os.path.join(self.config, "projects"))
        # Hermetic: no test may see the real config dirs or price override.
        patches = [mock.patch.object(track, "HOME", os.path.join(self.tmp, "home")),
                   mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": self.config})]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        os.environ.pop("CLAUDE_COST_PRICING", None)

    def tearDown(self):
        self._tmp.cleanup()

    def transcript(self, rel, lines):
        path = os.path.join(self.config, "projects", rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8") as fh:
            fh.writelines(lines)
        return path

    def rows(self, sql="SELECT msg_key, output_tokens, tool_name, cost_usd FROM usage ORDER BY msg_key"):
        conn = sqlite3.connect(self.db)
        try:
            return conn.execute(sql).fetchall()
        finally:
            conn.close()


class PricingTests(unittest.TestCase):
    # Published first-party rates, platform.claude.com/docs/en/about-claude/pricing
    # (input, output, 5m write, 1h write, cache read) USD per MTok.
    PUBLISHED = {
        "claude-fable-5-1": (10, 50, 12.5, 20, 0.25),
        "claude-fable-5": (10, 50, 12.5, 20, 1.0),
        "claude-opus-5-5": (4, 20, 5, 8, 0.20),
        "claude-opus-5": (5, 25, 6.25, 10, 0.50),
        "claude-opus-4-8": (5, 25, 6.25, 10, 0.50),
        "claude-sonnet-5-5": (2, 10, 2.5, 4, 0.20),
        "claude-sonnet-5": (2, 10, 2.5, 4, 0.20),
        "claude-sonnet-4-6": (3, 15, 3.75, 6, 0.30),
        "claude-haiku-4-5-20251001": (1, 5, 1.25, 2, 0.10),
        "claude-opus-4-1-20250805": (15, 75, 18.75, 30, 1.50),
        "claude-opus-4-20250514": (15, 75, 18.75, 30, 1.50),
    }

    def setUp(self):
        self.table = pricing.load_pricing(path="")

    def per_type(self, model):
        m = 1_000_000
        cases = [(m, 0, 0, 0, 0), (0, m, 0, 0, 0), (0, 0, m, 0, 0), (0, 0, m, m, 0), (0, 0, 0, 0, m)]
        return tuple(pricing.cost_usd(model, None, i, o, w, w1, r, self.table)[0]
                     for i, o, w, w1, r in cases)

    def test_every_current_model_matches_the_published_table(self):
        for model, expected in self.PUBLISHED.items():
            with self.subTest(model=model):
                got = self.per_type(model)
                for g, e in zip(got, expected):
                    self.assertAlmostEqual(g, e, places=9)

    def test_a_new_model_is_never_priced_as_its_predecessor(self):
        for model in ("claude-opus-5-7", "claude-sonnet-6", "claude-fable-5-2", "mystery", ""):
            with self.subTest(model=model):
                self.assertEqual(pricing.cost_usd(model, None, 1000, 0, 0, 0, 0, self.table),
                                 (None, None))

    def test_dated_and_platform_ids_resolve_to_their_row(self):
        for model, key in [("claude-haiku-4-5-20251001", "claude-haiku-4-5"),
                           ("us.anthropic.claude-opus-4-1-20250805-v1:0", "claude-opus-4-1"),
                           ("claude-opus-4-5@20251101", "claude-opus-4-5"),
                           ("claude-opus-4-6[1m]", "claude-opus-4-6"),
                           ("claude-opus-5-5", "claude-opus-5-5")]:
            with self.subTest(model=model):
                self.assertEqual(pricing.lookup(model, self.table), key)

    def test_1h_cache_writes_priced_from_the_split(self):
        cost, _ = pricing.cost_usd("claude-opus-5-5", None, 0, 0, 1_000_000, 400_000, 0, self.table)
        self.assertAlmostEqual(cost, 0.6 * 5 + 0.4 * 8)

    def test_no_long_context_premium(self):
        cost, _ = pricing.cost_usd("claude-sonnet-5-5", None, 900_000, 0, 0, 0, 0, self.table)
        self.assertAlmostEqual(cost, 1.8)

    def test_fast_mode_doubles_and_is_labelled(self):
        self.assertEqual(pricing.cost_usd("claude-opus-5-5", "fast", 1_000_000, 0, 0, 0, 0,
                                          self.table), (8.0, "claude-opus-5-5:fast"))
        self.assertEqual(pricing.cost_usd("claude-sonnet-5-5", "fast", 1_000_000, 0, 0, 0, 0,
                                          self.table), (2.0, "claude-sonnet-5-5"))

    def test_synthetic_messages_are_free_not_unpriced(self):
        self.assertEqual(pricing.cost_usd("<synthetic>", None, 0, 0, 0, 0, 0, self.table),
                         (0.0, "<synthetic>"))

    def test_override_adds_a_model_and_a_bad_override_warns(self):
        with tempfile.TemporaryDirectory() as tmp:
            good = os.path.join(tmp, "good.json")
            with open(good, "w") as fh:
                json.dump({"claude-opus-6": [3, 15, 3.75, 6, 0.3]}, fh)
            table = pricing.load_pricing(good)
            self.assertIsNone(table.warning)
            self.assertEqual(pricing.cost_usd("claude-opus-6", None, 1_000_000, 0, 0, 0, 0, table),
                             (3.0, "claude-opus-6"))
            bad = os.path.join(tmp, "bad.json")
            with open(bad, "w") as fh:
                json.dump({"opus": [5, 25]}, fh)
            table = pricing.load_pricing(bad)
            self.assertIn("ignored", table.warning)
            self.assertIsNone(pricing.lookup("opus", table))


class IngestTests(TempDirCase):
    def test_multi_line_response_is_one_row_with_last_usage_and_merged_tools(self):
        path = self.transcript("p/s1.jsonl", response_a() + ["not json\n",
                               json.dumps({"type": "user", "uuid": "u1"}) + "\n"] + response_b())
        stats = track.ingest(self.db, paths=[path])
        self.assertEqual(stats["rows_added"], 2)
        rows = self.rows()
        self.assertEqual([(r[0], r[1], r[2]) for r in rows],
                         [("msg:msg_A:req_A", 120, "Bash"), ("msg:msg_B:req_B", 60, "Read,Grep")])
        table = pricing.load_pricing()
        expect_a = pricing.cost_usd("claude-opus-5-5", None, 10, 120, 1000, 400, 50000, table)[0]
        expect_b = pricing.cost_usd("claude-opus-5-5", None, 3, 60, 0, 0, 51000, table)[0]
        self.assertAlmostEqual(sum(r[3] for r in rows), expect_a + expect_b)
        # The per-line keying this replaces would have counted five responses.
        self.assertGreater(3 * expect_a + 2 * expect_b, 1.9 * (expect_a + expect_b))

    def test_reingest_is_idempotent(self):
        path = self.transcript("p/s1.jsonl", response_a() + response_b())
        track.ingest(self.db, paths=[path])
        before = self.rows()
        stats = track.ingest(self.db, paths=[path])
        self.assertEqual((stats["rows_added"], stats["rows_updated"]), (0, 0))
        self.assertEqual(self.rows(), before)

    def test_incremental_run_merges_a_response_split_across_runs(self):
        path = self.transcript("p/s1.jsonl", response_a() + response_b()[:1])
        payload = {"transcript_path": path, "session_id": "s1"}
        self.assertEqual(track.ingest(self.db, payload=payload)["mode"], "hook")
        self.transcript("p/s1.jsonl", response_b()[1:] + [
            line("c1", "msg_C", usage(1, 7, 0, 52000), TEXT, req="req_C")])
        stats = track.ingest(self.db, payload=payload)
        self.assertEqual((stats["rows_added"], stats["rows_updated"]), (1, 1))
        self.assertEqual([(r[1], r[2]) for r in self.rows()],
                         [(120, "Bash"), (60, "Read,Grep"), (7, "text")])
        unchanged = track.ingest(self.db, payload=payload)
        self.assertEqual(unchanged["transcripts_read"], 0)

    def test_unterminated_last_line_is_read_again_not_twice(self):
        lines = response_a()
        path = self.transcript("p/s1.jsonl", lines[:-1] + [lines[-1].rstrip("\n")])
        payload = {"transcript_path": path}
        track.ingest(self.db, payload=payload)
        self.transcript("p/s1.jsonl", ["\n"] + response_b())
        track.ingest(self.db, payload=payload)
        self.assertEqual([(r[1], r[2]) for r in self.rows()], [(120, "Bash"), (60, "Read,Grep")])

    def test_forked_session_copy_counts_once(self):
        a = self.transcript("p/s1.jsonl", response_a())
        b = self.transcript("p/s2.jsonl", response_a() + response_b())
        track.ingest(self.db, paths=[a, b])
        self.assertEqual(len(self.rows()), 2)

    def test_hook_payload_reads_only_its_session_and_subagents(self):
        main = self.transcript("p/s1.jsonl", response_a())
        self.transcript("p/s1/subagents/agent-x.jsonl", response_b())
        self.transcript("p/s2.jsonl", [line("z1", "msg_Z", usage(1, 1), TEXT, req="req_Z",
                                            session="s2")])
        stats = track.ingest(self.db, payload={"transcript_path": main})
        self.assertEqual((stats["mode"], stats["transcripts_seen"]), ("hook", 2))
        self.assertEqual([r[0] for r in self.rows()], ["msg:msg_A:req_A", "msg:msg_B:req_B"])
        stats = track.ingest(self.db, payload={"transcript_path": "/nonexistent.jsonl"})
        self.assertEqual((stats["mode"], stats["rows_added"]), ("scan", 1))

    def test_a_half_written_trailing_line_is_picked_up_once_complete(self):
        lines = response_a()
        cut = len(lines[-1]) // 2
        path = self.transcript("p/s1.jsonl", lines[:-1] + [lines[-1][:cut]])
        payload = {"transcript_path": path}
        track.ingest(self.db, payload=payload)
        self.assertEqual([(r[1], r[2]) for r in self.rows()], [(40, "text")])
        self.transcript("p/s1.jsonl", [lines[-1][cut:]])
        track.ingest(self.db, payload=payload)
        self.assertEqual([(r[1], r[2]) for r in self.rows()], [(120, "Bash")])

    def test_a_pathological_line_is_skipped_not_fatal(self):
        nested = '{"type": "assistant", "x": ' + "[" * 100000 + "]" * 100000 + "}\n"
        path = self.transcript("p/s1.jsonl", [nested] + response_b())
        stats = track.ingest(self.db, paths=[path])
        self.assertEqual((stats["rows_added"], stats["file_errors"]), (1, 0))

    def test_glob_characters_in_paths_do_not_hide_subagents(self):
        main = self.transcript("proj[x]/s1.jsonl", response_a())
        self.transcript("proj[x]/s1/subagents/agent-1.jsonl", response_b())
        stats = track.ingest(self.db, payload={"transcript_path": main})
        self.assertEqual((stats["transcripts_seen"], stats["rows_added"]), (2, 2))
        self.assertEqual(len(track.transcript_files()), 2)

    def test_cache_split_without_a_total_still_counts_both_ttls(self):
        u = usage(0, 0, 0, 0)
        del u["cache_creation_input_tokens"]
        u["cache_creation"] = {"ephemeral_5m_input_tokens": 600_000,
                               "ephemeral_1h_input_tokens": 400_000}
        path = self.transcript("p/s1.jsonl", [line("c1", "msg_C", u, TEXT, req="req_C")])
        track.ingest(self.db, paths=[path])
        self.assertEqual(self.rows("SELECT cache_write, cache_write_1h, cost_usd FROM usage"),
                         [(1_000_000, 400_000, 6.2)])

    def test_unknown_model_is_stored_unpriced_and_reported(self):
        path = self.transcript("p/s1.jsonl", [line("n1", "msg_N", usage(100, 10), TEXT,
                                                   model="claude-opus-9", req="req_N")])
        track.ingest(self.db, paths=[path])
        self.assertEqual(self.rows("SELECT cost_usd, priced_as FROM usage"), [(None, None)])
        conn = store.open_readonly(self.db)
        try:
            self.assertTrue(any("UNPRICED" in n and "claude-opus-9" in n for n in report.notes(conn)))
        finally:
            conn.close()

    def test_reprice_applies_a_changed_table_to_stored_tokens(self):
        path = self.transcript("p/s1.jsonl", response_b())
        track.ingest(self.db, paths=[path])
        override = os.path.join(self.tmp, "rates.json")
        with open(override, "w") as fh:
            json.dump({"claude-opus-5-5": [0, 1000, 0, 0, 0]}, fh)
        with mock.patch.dict(os.environ, {"CLAUDE_COST_PRICING": override}):
            track.ingest(self.db, paths=[path])
            self.assertEqual(self.rows("SELECT value FROM meta WHERE key = 'reprice_hint'"), [("1",)])
            with mock.patch("sys.stdout"):
                track.cmd_reprice(self.db)
        self.assertAlmostEqual(self.rows()[0][3], 60 * 1000 / 1e6)
        self.assertEqual(self.rows("SELECT value FROM meta WHERE key = 'reprice_hint'"), [])


class MigrationTests(TempDirCase):
    def make_v0(self, rows):
        os.makedirs(os.path.dirname(self.db), exist_ok=True)
        conn = sqlite3.connect(self.db)
        conn.execute(V0_DDL)
        conn.executemany("INSERT INTO usage VALUES (?,?,?,?,?,?,?,?,?,?,?)", rows)
        conn.commit()
        conn.close()

    def v0_rows(self):
        def row(uuid, out, model="claude-opus-5-5", session="s1", i=10, w=1000, r=50000):
            return (uuid, "2026-08-01T00:00:00Z", "demo", "text", model, i, out, w, r, 99.0, session)
        return [
            row("a1", 5), row("a2", 40), row("a3", 120),            # transcript survives
            row("g1", 7, model="claude-opus-4-1-20250805", session="old"),  # transcript gone
            row("g2", 3, session="old2", i=2, r=1), row("g3", 9, session="old2", i=2, r=1),
            row("x1", 1, model="claude-unreleased", session="old3"),
        ]

    def test_v0_migration_keeps_every_row_reprices_and_backs_up(self):
        self.make_v0(self.v0_rows())
        conn = store.connect(self.db)
        try:
            self.assertEqual(conn.execute("PRAGMA user_version").fetchone()[0], store.SCHEMA_VERSION)
            self.assertEqual(conn.execute("SELECT COUNT(*), SUM(legacy) FROM usage").fetchone(), (7, 7))
            g1 = conn.execute("SELECT cost_usd, priced_as FROM usage WHERE uuid = 'g1'").fetchone()
            self.assertAlmostEqual(g1[0], (10 * 15 + 7 * 75 + 1000 * 18.75 + 50000 * 1.5) / 1e6)
            self.assertEqual(g1[1], "claude-opus-4-1")
            self.assertEqual(conn.execute("SELECT cost_usd FROM usage WHERE uuid = 'x1'").fetchone(),
                             (None,))
            self.assertEqual(store.get_meta(conn, "needs_rescan"), "1")
        finally:
            conn.close()
        bak = sqlite3.connect(self.db + ".v0.bak")
        self.assertEqual(bak.execute("SELECT COUNT(*), SUM(cost_usd) FROM usage").fetchone(), (7, 693.0))
        bak.close()

    def test_ingest_collapses_legacy_rows_whose_transcript_survives(self):
        self.make_v0(self.v0_rows())
        self.transcript("p/s1.jsonl", response_a())
        stats = track.ingest(self.db, payload={"transcript_path": "/nonexistent.jsonl"})
        self.assertEqual(stats["mode"], "rescan")  # the pending post-migration rescan
        self.assertEqual((stats["rows_added"], stats["legacy_collapsed"]), (1, 3))
        self.assertEqual(self.rows("SELECT COUNT(*), SUM(legacy) FROM usage"), [(5, 4)])
        conn = store.open_readonly(self.db)
        try:
            caveats = " ".join(report.notes(conn))
        finally:
            conn.close()
        self.assertIn("legacy:      4 rows", caveats)
        self.assertIn("About 1 of them", caveats)
        self.assertNotIn("pending", caveats)

    def test_a_newer_schema_is_refused_untouched(self):
        self.make_v0(self.v0_rows())
        conn = sqlite3.connect(self.db)
        conn.execute("PRAGMA user_version = 99")
        conn.close()
        with self.assertRaises(RuntimeError):
            store.connect(self.db)
        self.assertEqual(self.rows("SELECT COUNT(*) FROM usage"), [(7,)])
        self.assertEqual(self.rows("PRAGMA journal_mode"), [("delete",)])

    def test_a_migration_that_fails_midway_leaves_the_v0_database_intact(self):
        self.make_v0(self.v0_rows())
        with mock.patch.object(store, "reprice_rows", side_effect=RuntimeError("boom")):
            with self.assertRaises(RuntimeError):
                store.connect(self.db)
        self.assertEqual(self.rows("PRAGMA user_version"), [(0,)])
        self.assertEqual(self.rows("SELECT COUNT(*), SUM(cost_usd) FROM usage"), [(7, 693.0)])
        self.assertEqual(self.rows("SELECT name FROM sqlite_master WHERE name IN ('meta', 'files',"
                                   " 'usage_v2')"), [])
        conn = store.connect(self.db)  # and a later run migrates normally
        conn.close()
        self.assertEqual(self.rows("SELECT COUNT(*) FROM usage"), [(7,)])

    def test_an_interrupted_rescan_resumes_instead_of_restarting(self):
        self.make_v0(self.v0_rows())
        for n in range(3):
            self.transcript("p/s%d.jsonl" % n, [line("r%d" % n, "msg_R%d" % n, usage(1, 1), TEXT,
                                                     req="req_R%d" % n)])
        first = track.ingest(self.db, budget=0)  # out of time after one file
        self.assertEqual((first["mode"], first["transcripts_read"], first["complete"]),
                         ("rescan", 1, False))
        second = track.ingest(self.db, budget=60)
        self.assertEqual((second["mode"], second["transcripts_read"], second["complete"]),
                         ("rescan", 2, True))
        self.assertEqual(self.rows("SELECT value FROM meta WHERE key = 'needs_rescan'"), [])
        self.assertEqual(track.ingest(self.db)["mode"], "scan")
        self.assertEqual(self.rows("SELECT COUNT(*) FROM usage WHERE legacy = 0"), [(3,)])

    def test_a_hook_during_the_rescan_ingests_its_session_first_in_a_small_slice(self):
        self.make_v0(self.v0_rows())
        for n in range(3):
            self.transcript("p/s%d.jsonl" % n, [line("r%d" % n, "msg_R%d" % n, usage(1, 1), TEXT,
                                                     req="req_R%d" % n)])
        mine = os.path.join(self.config, "projects", "p", "s2.jsonl")
        with mock.patch.object(track, "HOOK_RESCAN_BUDGET", 0):
            stats = track.ingest(self.db, payload={"transcript_path": mine})
        self.assertEqual((stats["mode"], stats["transcripts_read"], stats["complete"]),
                         ("rescan", 1, False))
        self.assertEqual(self.rows("SELECT uuid FROM usage WHERE legacy = 0"), [("r2",)])
        self.assertEqual(self.rows("SELECT value FROM meta WHERE key = 'needs_rescan'"), [("1",)])


class CliTests(TempDirCase):
    def run_cli(self, *args, stdin=None):
        env = dict(os.environ, HOME=os.path.join(self.tmp, "home"), CLAUDE_CONFIG_DIR=self.config,
                   CLAUDE_COST_DB=self.db)
        env.pop("CLAUDE_COST_PRICING", None)
        env.pop("CLAUDE_COST_QUIET", None)
        return subprocess.run([sys.executable, TRACK] + list(args), env=env, cwd=self.tmp,
                              input=stdin, stdin=None if stdin is not None else subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              universal_newlines=True, timeout=60)

    def test_help_has_no_side_effects(self):
        res = self.run_cli("--help")
        self.assertEqual(res.returncode, 0)
        self.assertIn("--backfill", res.stdout)
        self.assertFalse(os.path.exists(os.path.dirname(self.db)))

    def test_unknown_flag_errors_out_without_ingesting(self):
        self.transcript("p/s1.jsonl", response_a())
        res = self.run_cli("--bogus")
        self.assertEqual(res.returncode, 1)
        self.assertIn("error", res.stderr)
        self.assertFalse(os.path.exists(self.db))
        res = self.run_cli("--quiet", "--bogus")
        self.assertEqual((res.returncode, res.stdout), (0, ""))
        self.assertFalse(os.path.exists(self.db))
        with open(os.path.join(os.path.dirname(self.db), "last-error.json")) as fh:
            self.assertIn("usage", json.load(fh)["error"])

    def test_hook_mode_ingests_the_payload_session_silently(self):
        main = self.transcript("p/s1.jsonl", response_a())
        self.transcript("p/s2.jsonl", response_b())
        payload = json.dumps({"session_id": "s1", "transcript_path": main,
                              "hook_event_name": "Stop", "stop_hook_active": False})
        res = self.run_cli("--quiet", stdin=payload)
        self.assertEqual((res.returncode, res.stdout, res.stderr), (0, "", ""))
        self.assertEqual([r[0] for r in self.rows()], ["msg:msg_A:req_A"])

    def test_quiet_hook_exits_0_on_a_broken_database_and_leaves_a_breadcrumb(self):
        main = self.transcript("p/s1.jsonl", response_a())
        os.makedirs(os.path.dirname(self.db))
        with open(self.db, "w") as fh:
            fh.write("this is not a database" * 100)
        res = self.run_cli("--quiet", stdin=json.dumps({"transcript_path": main}))
        self.assertEqual((res.returncode, res.stdout), (0, ""))
        status = self.run_cli("--status")
        self.assertIn("ERROR:", status.stdout)

    def test_no_payload_scans_every_transcript(self):
        self.transcript("p/s1.jsonl", response_a())
        self.transcript("p/s2.jsonl", response_b())
        res = self.run_cli()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("[scan,", res.stdout)
        self.assertEqual(len(self.rows()), 2)

    def test_report_csv_and_status(self):
        self.transcript("p/s1.jsonl", response_a() + response_b())
        self.run_cli("--backfill")
        rep = self.run_cli("--report")
        self.assertEqual(rep.returncode, 0, rep.stderr)
        for section in ("## Summary", "## Where the money goes", "## By model", "## Tools"):
            self.assertIn(section, rep.stdout)
        out = os.path.join(self.tmp, "rows.csv")
        self.assertEqual(self.run_cli("--csv", out).returncode, 0)
        with open(out) as fh:
            self.assertEqual(len(fh.read().strip().splitlines()), 3)
        status = self.run_cli("--status")
        self.assertIn("rows:        2 over 1 sessions", status.stdout)

    def test_concurrent_hooks_migrate_a_v0_database_once(self):
        MigrationTests.make_v0(self, MigrationTests.v0_rows(self))
        main = self.transcript("p/s1.jsonl", response_a())
        payload = json.dumps({"transcript_path": main})
        env = dict(os.environ, HOME=os.path.join(self.tmp, "home"), CLAUDE_CONFIG_DIR=self.config,
                   CLAUDE_COST_DB=self.db)
        procs = [subprocess.Popen([sys.executable, TRACK, "--quiet"], env=env,
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, universal_newlines=True)
                 for _ in range(4)]
        results = [p.communicate(payload, timeout=60) + (p.returncode,) for p in procs]
        self.assertEqual(results, [("", "", 0)] * 4)
        self.assertFalse(os.path.exists(os.path.join(os.path.dirname(self.db), "last-error.json")))
        self.assertEqual(self.rows("SELECT COUNT(*), SUM(legacy) FROM usage"), [(5, 4)])

    def test_status_does_not_migrate_a_v0_database(self):
        os.makedirs(os.path.dirname(self.db))
        conn = sqlite3.connect(self.db)
        conn.execute(V0_DDL)
        conn.commit()
        conn.close()
        res = self.run_cli("--status")
        self.assertIn("schema:      v0", res.stdout)
        conn = sqlite3.connect(self.db)
        self.assertEqual(conn.execute("PRAGMA user_version").fetchone()[0], 0)
        conn.close()


if __name__ == "__main__":
    unittest.main()
