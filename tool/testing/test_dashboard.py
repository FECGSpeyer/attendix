#!/usr/bin/env python3
"""Unit tests for tool/testing/generate_test_dashboard.py."""
from __future__ import annotations

import base64
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zlib

# Allow running via `python3 -m unittest tool/testing/test_dashboard.py`
sys.path.insert(0, str(Path(__file__).resolve().parent))

import generate_test_dashboard as dash  # noqa: E402


def _make_png(width: int, height: int) -> bytes:
    """Creates a minimal valid 1-pixel or WxH PNG header/file using stdlib zlib."""
    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    raw_scanline = b"\x00" + b"\xff\x00\x00" * width
    idat = zlib.compress(raw_scanline * height)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", idat)
        + chunk(b"IEND", b"")
    )


class ExtractionTests(unittest.TestCase):
    def test_extract_dart_tests_handles_variants_and_comments(self) -> None:
        source = r"""
        // test('commented out single line', () {});
        /*
         * testWidgets('commented out block', (tester) async {});
         */
        void main() {
          test('plain unit test', () {});
          test("double quoted \"escaped\"", () {});
          testWidgets(
            'multiline widget test with // inside string',
            (tester) async {},
          );
          patrolTest('M-01 Termin zusagen', tags: ['pr', 'mobil'], ($) async {});
          widgetTest('helper wrapper', (tester) async {});
          tenantIdTest('repo filters', () async {});
        }
        """
        cases = dash.extract_dart_tests(source)
        self.assertEqual(
            [(c.kind, c.name) for c in cases],
            [
                ("test", "plain unit test"),
                ("test", 'double quoted "escaped"'),
                ("testWidgets", "multiline widget test with // inside string"),
                ("patrolTest", "M-01 Termin zusagen"),
                ("widgetTest", "helper wrapper"),
                ("tenantIdTest", "repo filters"),
            ],
        )
        self.assertEqual(cases[3].tags, ["pr", "mobil"])

    def test_extract_tool_tests_js_and_python(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            js_file = tmp_dir / "sw.test.mjs"
            js_file.write_text(
                "import { test } from 'node:test';\n"
                "test('first js behavior', () => {});\n"
                "it(\"second behavior\", () => {});\n",
                encoding="utf-8",
            )
            py_file = tmp_dir / "test_sample.py"
            py_file.write_text(
                "def helper(): pass\n"
                "def test_alpha(self):\n    pass\n"
                "def test_beta(self):\n    pass\n",
                encoding="utf-8",
            )
            js_cases = dash.extract_tool_tests(js_file)
            py_cases = dash.extract_tool_tests(py_file)
            self.assertEqual([c.name for c in js_cases], ["first js behavior", "second behavior"])
            self.assertEqual([c.name for c in py_cases], ["test_alpha", "test_beta"])

    def test_infer_features_from_imports_paths_and_ui_filenames(self) -> None:
        known = {"shifts", "songs", "today", "people"}
        source = (
            "import 'package:attendix/features/songs/presentation/pages/works_page.dart';\n"
            "final f = File('lib/features/shifts/presentation/widgets/x.dart');\n"
            "final all = Directory('lib/features');\n"
        )
        self.assertEqual(
            dash.infer_features_for_dart_file("test/data/guard_test.dart", source, known),
            ["shifts", "songs"],
        )
        self.assertEqual(
            dash.infer_features_for_dart_file("test/features/people/a_test.dart", "", known),
            ["people"],
        )
        self.assertEqual(
            dash.infer_features_for_dart_file("test/ui/today_layout_test.dart", "", known),
            ["today"],
        )

    def test_classify_test_file_layers(self) -> None:
        self.assertEqual(dash.classify_test_file("test/ui/layout_guard_test.dart"), "ui")
        self.assertEqual(dash.classify_test_file("test/golden/pages_beta_test.dart"), "golden")
        self.assertEqual(dash.classify_test_file("test/features/songs/rd_works_test.dart"), "features")
        self.assertEqual(dash.classify_test_file("test/shared/widgets/logo_test.dart"), "features")
        self.assertEqual(dash.classify_test_file("test/core/utils/date_test.dart"), "core")
        self.assertEqual(dash.classify_test_file("test/data/repositories/repo_test.dart"), "core")
        self.assertEqual(dash.classify_test_file("test/widget_test.dart"), "core")
        self.assertEqual(dash.classify_test_file("patrol_test/login_test.dart"), "patrol")
        self.assertEqual(dash.classify_test_file("tool/web/test/sw_behavior.test.mjs"), "tool")


class NdjsonAndIntegrationTests(unittest.TestCase):
    def _build_synthetic_repo(self, root: Path) -> None:
        # Features: attendance, songs, empty_feat
        for feat in ("attendance", "songs", "empty_feat"):
            (root / "lib" / "features" / feat / "presentation").mkdir(parents=True)

        (root / "lib" / "features" / "attendance" / "presentation" / "events_page.dart").write_text(
            "class RdEventsPage {}\n", encoding="utf-8"
        )

        # Layer 1: test/ui/
        (root / "test" / "ui").mkdir(parents=True)
        (root / "test" / "ui" / "attendance_guard_test.dart").write_text(
            "import 'package:attendix/features/attendance/presentation/events_page.dart';\n"
            "void main() {\n  testWidgets('no overflow', (t) async {});\n}\n",
            encoding="utf-8",
        )

        # Layer 2: test/golden/
        (root / "test" / "golden" / "goldens").mkdir(parents=True)
        (root / "test" / "golden" / "pages_beta_test.dart").write_text(
            "import 'package:attendix/features/attendance/presentation/events_page.dart';\n"
            "void main() {\n"
            "  testWidgets('Termine', (t) async {\n"
            "    await pumpGolden(t, const RdEventsPage());\n"
            "    await expectGolden(t, _look, 'termine');\n"
            "  });\n"
            "}\n",
            encoding="utf-8",
        )
        (root / "test" / "golden" / "goldens" / "beta_termine.png").write_bytes(
            _make_png(12, 24)
        )

        # Layer 3: test/features/
        (root / "test" / "features" / "songs").mkdir(parents=True)
        (root / "test" / "features" / "songs" / "works_test.dart").write_text(
            "void main() {\n"
            "  test('filters works', () {});\n"
            "  testWidgets('renders list </script>', (t) async {});\n"
            "}\n",
            encoding="utf-8",
        )

        # Layer 4: test/core/
        (root / "test" / "core").mkdir(parents=True)
        (root / "test" / "core" / "tenant_test.dart").write_text(
            "void main() {\n  test('enforces tenantId', () {});\n}\n",
            encoding="utf-8",
        )

        # Patrol E2E
        (root / "patrol_test").mkdir(parents=True)
        (root / "patrol_test" / "helfer_test.dart").write_text(
            "void main() {\n"
            "  patrolTest('H-10 Neuen Termin anlegen', tags: ['pr'], ($) async {\n"
            "    await tapOn($, 'Termine');\n"
            "  });\n"
            "}\n",
            encoding="utf-8",
        )

        # Tool test
        (root / "tool" / "testing").mkdir(parents=True)
        (root / "tool" / "testing" / "test_sample.py").write_text(
            "def test_ok(self):\n    pass\n", encoding="utf-8"
        )

    def test_scan_repository_static_and_feature_matrix(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._build_synthetic_repo(root)

            report = dash.scan_repository(root, embed_goldens=True)
            self.assertFalse(report.has_live_results)
            self.assertEqual(report.totals["flutter_files"], 4)
            self.assertEqual(report.totals["goldens"], 1)
            self.assertEqual(report.totals["patrol_flows"], 1)
            self.assertEqual(report.totals["features_total"], 3)
            self.assertEqual(report.totals["features_covered"], 2)

            self.assertEqual(report.goldens[0].width, 12)
            self.assertEqual(report.goldens[0].height, 24)
            self.assertTrue(report.goldens[0].data_uri.startswith("data:image/png;base64,"))
            decoded = base64.b64decode(report.goldens[0].data_uri.split(",", 1)[1])
            self.assertEqual(decoded[:8], b"\x89PNG\r\n\x1a\n")

            by_feat = {row["feature"]: row for row in report.feature_matrix}
            self.assertEqual(by_feat["attendance"]["ui_cases"], 1)
            self.assertEqual(by_feat["attendance"]["goldens"], 1)
            self.assertEqual(by_feat["attendance"]["patrol_flows"], 1)
            self.assertEqual(by_feat["songs"]["unit_cases"], 2)
            self.assertEqual(by_feat["empty_feat"]["total"], 0)

    def test_parse_multi_shard_ndjson_and_render_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._build_synthetic_repo(root)

            shard1 = root / "shard-1.json"
            shard2 = root / "shard-2.json"
            shard1.write_text(
                "\n".join([
                    json.dumps({"type": "suite", "suite": {"id": 0, "path": "/home/runner/work/attendix/attendix/test/ui/attendance_guard_test.dart"}, "time": 0}),
                    json.dumps({"type": "testStart", "test": {"id": 1, "name": "loading ...", "suiteID": 0}, "time": 0}),
                    json.dumps({"type": "testDone", "testID": 1, "result": "success", "hidden": True, "skipped": False, "time": 50}),
                    json.dumps({"type": "testStart", "test": {"id": 2, "name": "no overflow", "suiteID": 0, "root_line": 3}, "time": 50}),
                    json.dumps({"type": "testDone", "testID": 2, "result": "success", "hidden": False, "skipped": False, "time": 120}),
                ]),
                encoding="utf-8",
            )
            # Note overlapping suite id 0 and test id 2 across shards, plus a failure & skip
            shard2.write_text(
                "\n".join([
                    "{corrupt json line ignored",
                    json.dumps({"type": "suite", "suite": {"id": 0, "path": str(root / "test/features/songs/works_test.dart")}, "time": 0}),
                    json.dumps({"type": "testStart", "test": {"id": 2, "name": "filters works", "suiteID": 0, "root_line": 2}, "time": 100}),
                    json.dumps({"type": "error", "testID": 2, "error": "Expected: 2\nActual: 1"}),
                    json.dumps({"type": "testDone", "testID": 2, "result": "failure", "hidden": False, "skipped": False, "time": 260}),
                    json.dumps({"type": "testStart", "test": {"id": 3, "name": "renders list </script>", "suiteID": 0, "metadata": {"skip": True}}, "time": 260}),
                    json.dumps({"type": "testDone", "testID": 3, "result": "success", "hidden": False, "skipped": True, "time": 265}),
                ]),
                encoding="utf-8",
            )

            html_out = root / "build" / "test-dashboard" / "index.html"
            md_out = root / "summary.md"
            exit_code = dash.main([
                "--root", str(root),
                "--results", str(shard1), str(shard2), str(root / "missing.json"),
                "--html", str(html_out),
                "--embed-goldens",
                "--markdown", str(md_out),
            ])
            self.assertEqual(exit_code, 0)
            self.assertTrue(html_out.is_file())
            self.assertTrue(md_out.is_file())

            html_text = html_out.read_text(encoding="utf-8")
            self.assertIn("Attendix · Test- &amp; Qualitäts-Dashboard", html_text)
            self.assertIn("Wie &amp; was wird getestet?", html_text)
            self.assertIn("UI-Layout &amp; Design-Guards", html_text)
            self.assertIn("data:image/png;base64,", html_text)
            # Script injection inside test names must be escaped in embedded JSON
            self.assertNotIn("renders list </script>", html_text)
            self.assertIn(r"renders list \u003c/script>", html_text)

            md_text = md_out.read_text(encoding="utf-8")
            self.assertIn("❌ **1 Test(s) fehlgeschlagen**", md_text)
            self.assertIn("test/features/songs/works_test.dart", md_text)
            self.assertIn("filters works", md_text)
            self.assertIn("Expected: 2", md_text)
            self.assertIn("`empty_feat`", md_text)


def _ndjson(*events: dict) -> str:
    return "\n".join(json.dumps(e) for e in events)


def _suite(sid: int, path: str) -> dict:
    return {"type": "suite", "suite": {"id": sid, "path": path}, "time": 0}


def _start(tid: int, sid: int, name: str, time: int = 0) -> dict:
    return {"type": "testStart", "test": {"id": tid, "name": name, "suiteID": sid}, "time": time}


def _done(tid: int, result: str = "success", time: int = 10, **extra: object) -> dict:
    event = {"type": "testDone", "testID": tid, "result": result, "hidden": False, "skipped": False, "time": time}
    event.update(extra)
    return event


_DONE_OK = {"type": "done", "success": True, "time": 999}


class MultiShardIdCollisionTests(unittest.TestCase):
    """Every CI shard is its own `flutter test` process whose suite and test
    IDs all start at 0; results of one shard must never overwrite, absorb or
    misattribute results of another."""

    def test_identical_ids_across_four_shards_stay_isolated(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            paths = []
            for shard in range(1, 5):
                shard_file = root / f"test-results-shard-{shard}.json"
                result = "failure" if shard == 3 else "success"
                events = [
                    _suite(0, f"/runner/work/attendix/test/core/shard{shard}_test.dart"),
                    _start(1, 0, f"loading shard {shard}"),
                    _done(1, hidden=True),
                    _start(2, 0, f"case A of shard {shard}", time=100),
                    _done(2, time=100 + shard * 10),
                    _start(3, 0, f"case B of shard {shard}", time=200),
                ]
                if shard == 3:
                    events.append({"type": "error", "testID": 3, "error": "shard 3 boom"})
                events += [_done(3, result=result, time=300), _DONE_OK]
                shard_file.write_text(_ndjson(*events), encoding="utf-8")
                paths.append(shard_file)

            info: dict = {}
            live = dash.parse_ndjson_results(paths, root, info)

            self.assertEqual(
                sorted(live),
                [f"test/core/shard{n}_test.dart" for n in range(1, 5)],
            )
            for shard in range(1, 5):
                entry = live[f"test/core/shard{shard}_test.dart"]
                self.assertEqual(
                    [c.name for c in entry["cases"]],
                    [f"case A of shard {shard}", f"case B of shard {shard}"],
                )
                self.assertEqual(entry["cases"][0].duration_ms, shard * 10)
                if shard == 3:
                    self.assertEqual((entry["passed"], entry["failed"]), (1, 1))
                    self.assertEqual(entry["cases"][1].error, "shard 3 boom")
                else:
                    self.assertEqual((entry["passed"], entry["failed"]), (2, 0))
                    # The error of shard 3's test 3 must not leak into test 3 elsewhere.
                    self.assertEqual(entry["cases"][1].error, "")
            self.assertEqual(info["parsed"], [p.name for p in paths])
            self.assertEqual(info["incomplete"], [])

    def test_testdone_without_start_in_same_shard_is_not_borrowed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            first = root / "shard-1.json"
            second = root / "shard-2.json"
            first.write_text(
                _ndjson(_suite(0, "test/ui/a_test.dart"), _start(5, 0, "only in shard 1"), _done(5), _DONE_OK),
                encoding="utf-8",
            )
            # Same IDs, but no suite/testStart in this file: must be ignored.
            second.write_text(
                _ndjson({"type": "error", "testID": 5, "error": "foreign"}, _done(5, result="error"), _DONE_OK),
                encoding="utf-8",
            )
            live = dash.parse_ndjson_results([first, second], root)
            self.assertEqual(list(live), ["test/ui/a_test.dart"])
            case = live["test/ui/a_test.dart"]["cases"][0]
            self.assertEqual((case.status, case.error), ("passed", ""))

    def test_same_suite_split_over_two_files_is_merged_not_overwritten(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            first = root / "a.json"
            second = root / "b.json"
            for path, name in ((first, "first run"), (second, "second run")):
                path.write_text(
                    _ndjson(_suite(0, "test/ui/same_test.dart"), _start(1, 0, name), _done(1), _DONE_OK),
                    encoding="utf-8",
                )
            live = dash.parse_ndjson_results([first, second], root)
            entry = live["test/ui/same_test.dart"]
            self.assertEqual([c.name for c in entry["cases"]], ["first run", "second run"])
            self.assertEqual(entry["passed"], 2)


class ResultHealthTests(unittest.TestCase):
    def test_error_after_testdone_marks_test_failed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            results = root / "late.json"
            results.write_text(
                _ndjson(
                    _suite(0, "test/core/late_test.dart"),
                    _start(1, 0, "late failure"),
                    _done(1, result="success"),
                    {"type": "error", "testID": 1, "error": "This test failed after it had already completed."},
                    _DONE_OK,
                ),
                encoding="utf-8",
            )
            live = dash.parse_ndjson_results([results], root)
            entry = live["test/core/late_test.dart"]
            self.assertEqual((entry["passed"], entry["failed"]), (0, 1))
            self.assertIn("already completed", entry["cases"][0].error)

    def test_missing_and_incomplete_shards_produce_warnings(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "test" / "core").mkdir(parents=True)
            (root / "test" / "core" / "a_test.dart").write_text(
                "void main() { test('a', () {}); }\n", encoding="utf-8"
            )
            (root / "test" / "core" / "b_test.dart").write_text(
                "void main() { test('b', () {}); }\n", encoding="utf-8"
            )
            crashed = root / "test-results-shard-1.json"
            # No final `done` event: the run was killed mid-way.
            crashed.write_text(
                _ndjson(_suite(0, str(root / "test/core/a_test.dart")), _start(1, 0, "a"), _done(1)),
                encoding="utf-8",
            )
            md_out = root / "summary.md"
            html_out = root / "index.html"
            exit_code = dash.main([
                "--root", str(root),
                "--results", str(crashed),
                "--expected-results", "4",
                "--html", str(html_out),
                "--markdown", str(md_out),
            ])
            self.assertEqual(exit_code, 0)
            md_text = md_out.read_text(encoding="utf-8")
            self.assertNotIn("✅", md_text)
            self.assertIn("Nur 1 von 4 erwarteten Ergebnisdateien", md_text)
            self.assertIn("test-results-shard-1.json", md_text)
            self.assertIn("`test/core/b_test.dart`", md_text)
            html_text = html_out.read_text(encoding="utf-8")
            self.assertIn("Live-Ergebnis unvollständig", html_text)
            self.assertIn('class="result-warning"', html_text)

    def test_markdown_escapes_backticks_pipes_and_newlines(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            results = root / "r.json"
            results.write_text(
                _ndjson(
                    _suite(0, "test/core/x_test.dart"),
                    _start(1, 0, "name with `tick` | pipe *bold*"),
                    {"type": "error", "testID": 1, "error": "Expected: `a|b`\nActual: c"},
                    _done(1, result="failure"),
                    _DONE_OK,
                ),
                encoding="utf-8",
            )
            # x_test.dart does not exist on disk: its live failure must still be
            # reported instead of silently vanishing from the summary.
            report = dash.scan_repository(root, [str(results)])
            self.assertEqual(report.totals["failed"], 1)
            self.assertEqual([f.path for f in report.files], ["test/core/x_test.dart"])
            md_text = dash.render_markdown(report)
            failure_line = next(ln for ln in md_text.splitlines() if "x_test.dart" in ln)
            self.assertIn(r"name with \`tick\` \| pipe \*bold\*", failure_line)
            self.assertIn("`Expected: 'a¦b'`", failure_line)

    def test_empty_markdown_path_is_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            exit_code = dash.main(["--root", str(root), "--html", str(root / "i.html"), "--markdown", ""])
            self.assertEqual(exit_code, 0)
            self.assertTrue((root / "i.html").is_file())

    def test_classify_strips_only_dot_slash_prefix(self) -> None:
        self.assertEqual(dash.classify_test_file("./test/ui/a_test.dart"), "ui")
        self.assertEqual(dash.classify_test_file("././patrol_test/a_test.dart"), "patrol")


if __name__ == "__main__":
    unittest.main()
