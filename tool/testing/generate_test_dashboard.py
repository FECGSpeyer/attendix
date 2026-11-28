#!/usr/bin/env python3
"""Generates an interactive HTML Test & Quality Dashboard and Markdown summary.

Uses Python 3 standard library only (zero third-party dependencies).

Examples:
    python3 tool/testing/generate_test_dashboard.py --open
    python3 tool/testing/generate_test_dashboard.py \\
        --results shard-results/**/test-results-shard-*.json \\
        --html build/test-dashboard/index.html \\
        --embed-goldens \\
        --markdown "$GITHUB_STEP_SUMMARY"
"""
from __future__ import annotations

import argparse
import base64
from dataclasses import dataclass, field
from datetime import datetime, timezone
import glob
import html
import json
import os
from pathlib import Path
import platform
import re
import struct
import subprocess
import sys
from typing import Any


LAYER_ORDER = ("ui", "golden", "features", "core", "patrol", "tool")

LAYER_META: dict[str, dict[str, str]] = {
    "ui": {
        "title": "UI-Layout & Design-Guards",
        "short": "UI-Guards",
        "path_hint": "test/ui/**",
        "badge": "Schicht 1",
        "catches": (
            "Layout-Overflows, abgeschnittene Texte, zu kleine Touch-Targets, "
            "Kontrast- & Spacing-Fehler sowie Design-System-Regeln."
        ),
        "ci": "ci.yml · 4 parallele Test-Shards (Ubuntu)",
        "cmd": "flutter test test/ui/",
    },
    "golden": {
        "title": "Visuelle Goldens",
        "short": "Goldens",
        "path_hint": "test/golden/**",
        "badge": "Schicht 2",
        "catches": (
            "Unbeabsichtigte Pixel-, Farb-, Icon-, Abstands- und Typografie-"
            "Abweichungen ganzer App-Seiten gegenüber Referenz-Screenshots."
        ),
        "ci": "ci.yml (Linux-Pixelvergleich) & golden-preview.yml (PR Vorher/Nachher)",
        "cmd": "flutter test test/golden",
    },
    "features": {
        "title": "Widget- & Feature-Tests",
        "short": "Features & Shared",
        "path_hint": "test/features/**, test/shared/**",
        "badge": "Schicht 3",
        "catches": (
            "Fehler in User-Flows, Riverpod-Provider-State, Rollenrechten, "
            "Formularen, Navigation, Dialogen und adaptiven Action-Sheets."
        ),
        "ci": "ci.yml · 4 parallele Test-Shards (Ubuntu)",
        "cmd": "flutter test test/features/ test/shared/",
    },
    "core": {
        "title": "Core, Data, Security & Helpers",
        "short": "Core, Data & Security",
        "path_hint": "test/core/**, test/data/**, test/helpers/**, test/*_test.dart",
        "badge": "Schicht 4",
        "catches": (
            "Multi-Tenant-Security-Lecks (fehlende tenantId-Filter), Modell-"
            "Parsing, Datums-/Berechnungslogik, i18n-Vollständigkeit und PWA-Tooling."
        ),
        "ci": "ci.yml · 4 parallele Test-Shards & Analyze-Job",
        "cmd": "flutter test test/core/ test/data/",
    },
    "patrol": {
        "title": "Patrol E2E-Flows",
        "short": "Patrol E2E",
        "path_hint": "patrol_test/*_test.dart",
        "badge": "E2E",
        "catches": (
            "Durchgängige Benutzerreisen in der echten App gegen lokales "
            "Supabase inkl. Login, Rollenrechten, DB-Schreibvorgängen & Routing."
        ),
        "ci": "e2e.yml · Web (Chromium) auf PRs/Nachts & Android-Emulator manuell",
        "cmd": "patrol test --device chrome --tags pr",
    },
    "tool": {
        "title": "Tooling- & Skript-Tests",
        "short": "Tool-Tests",
        "path_hint": "tool/**/*test*",
        "badge": "Tools",
        "catches": (
            "Regressionen im Service-Worker-Verhalten (Node.js) und im "
            "Test-Dashboard-Generator (Python unittest)."
        ),
        "ci": "ci.yml · Analyze-Job & test/tool/",
        "cmd": "python3 -m unittest tool/testing/test_dashboard.py",
    },
}

# Maps German/domain page slugs (e.g. beta_heute.png) to lib/features/<name>.
GOLDEN_SLUG_FEATURE_ALIASES: dict[str, str] = {
    "heute": "today",
    "today": "today",
    "mitglieder": "people",
    "personen": "people",
    "people": "people",
    "termine": "attendance",
    "termin": "attendance",
    "anwesenheit": "attendance",
    "attendance": "attendance",
    "werke": "songs",
    "lieder": "songs",
    "songs": "songs",
    "ich": "profile",
    "profil": "profile",
    "profile": "profile",
    "verwaltung": "settings",
    "einstellungen": "settings",
    "settings": "settings",
    "instrumente": "instruments",
    "instruments": "instruments",
    "planung": "planning",
    "planning": "planning",
    "dienst": "duty",
    "dienste": "duty",
    "duty": "duty",
    "statistik": "statistics",
    "statistics": "statistics",
    "lehrer": "teachers",
    "teachers": "teachers",
    "nachrichten": "messages",
    "messages": "messages",
    "hilfe": "help",
    "help": "help",
    "login": "auth",
    "anmeldung": "auth",
    "auth": "auth",
    "organisation": "organisation",
    "schichten": "shifts",
    "shifts": "shifts",
    "team": "team_organization",
}

GOLDEN_CATEGORY_ORDER = ("main", "page", "sheet", "dark", "desktop")

GOLDEN_CATEGORY_META: dict[str, dict[str, str]] = {
    "main": {
        "label": "Hauptseiten",
        "description": "Mobile Hauptansichten (Light Mode, 390×844)",
    },
    "page": {
        "label": "Subpages",
        "description": "Sekundäre Detail-, Formular- & Login-Seiten",
    },
    "sheet": {
        "label": "Sheets",
        "description": "Bottom-Sheets, Menüs & adaptive Action-Sheets",
    },
    "dark": {
        "label": "Dark Mode",
        "description": "Hauptseiten im Dark Mode (Brightness.dark)",
    },
    "desktop": {
        "label": "Desktop",
        "description": "Desktop Split-View mit Navigation-Rail (1280×800)",
    },
}

# Explicit compound slug mappings (after stripping look & category prefixes).
GOLDEN_COMPOUND_FEATURE_MAP: dict[str, tuple[str, ...]] = {
    "org_settings": ("organisation",),
    "event_create": ("attendance",),
    "person_detail": ("people",),
    "work_detail": ("songs",),
    "login": ("auth",),
    "org_song_copy": ("organisation", "songs"),
    "event_create_menu": ("attendance", "team_organization"),
    "org_info": ("organisation",),
    "action_sheet": (),
}

RISK_CLASS_ORDER = ("layout", "visual", "flows", "security", "e2e")

RISK_CLASS_META: dict[str, dict[str, str]] = {
    "layout": {
        "badge": "Risiko 1",
        "title": "Layout & Overflows",
        "short": "Layout",
        "source_hint": "test/ui/**, Layout-, Header-, Sheet- & Spacing-Tests",
        "catches": (
            "RenderFlex-Overflows, abgeschnittene Texte, zu kleine Touch-Targets, "
            "Header-/Sheet-Umbruchfehler und Design-System-Verstöße über Viewports & Text-Skalen."
        ),
    },
    "visual": {
        "badge": "Risiko 2",
        "title": "Visuelle Regression",
        "short": "Visuell",
        "source_hint": "test/golden/goldens/*.png (Hauptseiten, Subpages, Sheets, Dark Mode, Desktop)",
        "catches": (
            "Pixel-, Farb-, Icon-, Kontrast- und Typografie-Regressionen auf "
            "Hauptseiten, Subpages, Bottom-Sheets, Dark Mode und Desktop Split-View."
        ),
    },
    "flows": {
        "badge": "Risiko 3",
        "title": "Empty / Error / Rollen / Flows",
        "short": "Flows & Rollen",
        "source_hint": "empty_error_roles_ui_test.dart, test/features/** & test/shared/**",
        "catches": (
            "Kaputte Empty-/Error-States, fehlende Rollen-Sichtbarkeit, "
            "Provider-State-Bugs, kaputte Such-/Filter-/Formular-Flows und Navigation."
        ),
    },
    "security": {
        "badge": "Risiko 4",
        "title": "Multi-Tenant & Security",
        "short": "Tenant & Sec",
        "source_hint": "tenant, security, db_query_columns, guard, rls, offline, force_unwrap",
        "catches": (
            "Mandanten-Lecks (fehlende tenantId-Filter), unsichere DB-Spalten/"
            "RLS-Zugriffe, Offline-Cache-Lecks beim Accountwechsel und Force-Unwrap-Crashes."
        ),
    },
    "e2e": {
        "badge": "Risiko 5",
        "title": "Echte E2E-Journeys",
        "short": "E2E",
        "source_hint": "patrol_test/** (Web & Android gegen lokales Supabase)",
        "catches": (
            "Durchgängige Benutzerreisen über echte Supabase-Queries, Auth-Flows, "
            "Rollenrechte, DB-Mutationen und Routing im Browser & auf Mobilgeräten."
        ),
    },
}

_LAYOUT_RISK_PATH_RE = re.compile(
    r"(?:^|[/_])(?:layout|overflow|header|sheet|spacing|responsive|alignment|popover|dismiss)(?:[/_.]|$)"
)
_SECURITY_RISK_KEYWORDS = (
    "tenant",
    "security",
    "db_query_columns",
    "guard",
    "rls",
    "offline",
    "force_unwrap",
)
_SECURITY_CASE_RE = re.compile(
    r"\b(?:tenantid|tenant_id|cross-tenant|rls|security|db_query_columns|force[-_ ]unwrap)\b"
)

# Keyword rules for attributing Patrol E2E flow snippets to lib/features/<name>.
PATROL_FEATURE_KEYWORDS: list[tuple[str, tuple[str, ...]]] = [
    ("auth", ("loginpage", "signin", "anmelden", "passwort", "ausloggen")),
    ("today", ("heute", "nächster termin", "bist du dabei", "bin dabei", "kann nicht", "ist dabei")),
    ("attendance", ("termine", "termin", "anwesenheit", "sommerkonzert", "sonderprobe", "generalprobe", "chortermin")),
    ("people", ("mitglieder", "person hinzufügen", "neue person", "bewerber", "aufnehmen", "aktiv ·")),
    ("songs", ("werke", "neues werk", "ode an die freude", "kleine nachtmusik", "morgenstimmung")),
    ("settings", ("verwaltung",)),
    ("instruments", ("instrumente", "instrument", "harfe")),
    ("team_organization", ("meine stimme", "stimmhelfer")),
    ("profile", ("'ich'", '"ich"', "ausloggen")),
    ("registration", ("freigabe", "bewerber", "eigene gruppe", "einladung", "keiner gruppe")),
    ("tenant_selection", ("andere gruppe", "eigene gruppe gründen", "keiner gruppe")),
    ("self_service", ("bist du dabei", "bin dabei", "kann nicht", "abgemeldet", "ist dabei")),
]

DART_IMPORT_FEATURE_RE = re.compile(
    r"""import\s+['"]package:attendix/features/([a-z0-9_]+)/([^'"]+)['"]"""
)
# `widgetTest` / `tenantIdTest` are the wrappers in test/helpers/.
DART_TEST_RE = re.compile(
    r"""(?:^|[;\s{}])\s*(testWidgets|widgetTest|tenantIdTest|patrolTest|test)\(\s*r?(['"])((?:\\.|(?!\2)[^\\\n])+)\2""",
    re.MULTILINE,
)
# Source-scanner tests reference feature files by path ('lib/features/x/...').
DART_PATH_FEATURE_RE = re.compile(r"""['"]lib/features/([a-z0-9_]+)/""")
DART_PATROL_TAGS_RE = re.compile(r"""tags\s*:\s*\[([^\]]*)\]""")
DART_EXPECT_GOLDEN_RE = re.compile(
    r"""expectGolden\([^;]*?['"]([a-zA-Z0-9_]+)['"]"""
)
JS_TEST_RE = re.compile(
    r"""(?:^|[;\s{}])\s*(?:it|test)\(\s*(['"`])((?:\\.|(?!\1)[^\\\n])+)\1""",
    re.MULTILINE,
)
PY_TEST_RE = re.compile(r"""^\s*def\s+(test_[a-zA-Z0-9_]+)\s*\(""", re.MULTILINE)


@dataclass
class TestCaseEntry:
    """Single extracted or executed test case inside a test file."""

    name: str
    kind: str = "test"  # test | testWidgets | widgetTest | tenantIdTest | patrolTest | executed | js-test | py-test
    line: int | None = None
    status: str = "unrun"  # passed | failed | skipped | unrun
    duration_ms: int | None = None
    error: str = ""
    tags: list[str] = field(default_factory=list)


@dataclass
class TestFileEntry:
    """Represents one discovered test file and its test cases."""

    path: str
    layer: str
    features: list[str] = field(default_factory=list)
    risk_classes: list[str] = field(default_factory=list)
    cases: list[TestCaseEntry] = field(default_factory=list)
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    duration_ms: int = 0
    has_live_results: bool = False


@dataclass
class GoldenEntry:
    """Represents one golden reference screenshot PNG."""

    name: str
    path: str
    features: list[str]
    size_bytes: int
    category: str = "main"
    width: int | None = None
    height: int | None = None
    data_uri: str | None = None


@dataclass
class DashboardReport:
    """Complete aggregated report used to render HTML and Markdown outputs."""

    repo_root: Path
    generated_at: str
    has_live_results: bool
    result_files: list[str]
    files: list[TestFileEntry]
    goldens: list[GoldenEntry]
    features: list[str]
    feature_matrix: list[dict[str, Any]]
    layer_stats: dict[str, dict[str, Any]]
    totals: dict[str, Any]
    failed_cases: list[dict[str, str]]
    risk_class_stats: dict[str, dict[str, Any]] = field(default_factory=dict)
    golden_category_counts: dict[str, int] = field(default_factory=dict)
    # Result-file health (CI shards): files without a final `done` event,
    # how many result files were expected, and Flutter test files that have
    # no live result although other files do.
    incomplete_results: list[str] = field(default_factory=list)
    expected_results: int | None = None
    files_without_results: list[str] = field(default_factory=list)

    @property
    def result_warnings(self) -> list[str]:
        """Human-readable (German) warnings about missing or partial results."""
        warnings: list[str] = []
        if (
            self.expected_results is not None
            and len(self.result_files) < self.expected_results
        ):
            warnings.append(
                f"Nur {len(self.result_files)} von {self.expected_results} "
                "erwarteten Ergebnisdateien gefunden – mindestens ein Test-Shard "
                "hat keine Ergebnisse geliefert."
            )
        if self.incomplete_results:
            warnings.append(
                "Unvollständige Ergebnisdatei(en) ohne Abschluss-Event "
                "(abgebrochener oder abgestürzter Lauf): "
                + ", ".join(self.incomplete_results)
            )
        if self.has_live_results and self.files_without_results:
            warnings.append(
                f"{len(self.files_without_results)} Flutter-Testdatei(en) ohne "
                "Live-Ergebnis."
            )
        return warnings


def strip_dart_comments(source: str) -> str:
    """Removes Dart // and /* */ comments while preserving string literals and newlines."""
    out: list[str] = []
    i = 0
    n = len(source)
    while i < n:
        ch = source[i]
        # Raw strings r'...' / r"..."
        if ch == "r" and i + 1 < n and source[i + 1] in ("'", '"'):
            quote = source[i + 1]
            if source[i + 1 : i + 4] == quote * 3:
                end = source.find(quote * 3, i + 4)
                end = n if end == -1 else end + 3
            else:
                end = source.find(quote, i + 2)
                end = n if end == -1 else end + 1
            out.append(source[i:end])
            i = end
            continue
        # Regular or triple-quoted strings
        if ch in ("'", '"'):
            if source[i : i + 3] == ch * 3:
                end = i + 3
                while end < n:
                    if source[end] == "\\" and end + 1 < n:
                        end += 2
                        continue
                    if source[end : end + 3] == ch * 3:
                        end += 3
                        break
                    end += 1
            else:
                end = i + 1
                while end < n:
                    if source[end] == "\\" and end + 1 < n:
                        end += 2
                        continue
                    if source[end] == ch or source[end] == "\n":
                        if source[end] == ch:
                            end += 1
                        break
                    end += 1
            out.append(source[i:end])
            i = end
            continue
        # Line comment
        if ch == "/" and i + 1 < n and source[i + 1] == "/":
            nl = source.find("\n", i)
            if nl == -1:
                break
            i = nl
            continue
        # Block comment (preserve newlines for accurate line numbers)
        if ch == "/" and i + 1 < n and source[i + 1] == "*":
            end = source.find("*/", i + 2)
            if end == -1:
                out.append("\n" * source[i:].count("\n"))
                break
            out.append("\n" * source[i : end + 2].count("\n"))
            i = end + 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _unescape_string(raw: str) -> str:
    return (
        raw.replace(r"\'", "'")
        .replace(r"\"", '"')
        .replace(r"\\n", " ")
        .replace(r"\n", " ")
        .replace(r"\\", "\\")
        .strip()
    )


def _line_number_at(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def extract_dart_tests(source: str) -> list[TestCaseEntry]:
    """Extracts test(), testWidgets(), and patrolTest() cases from Dart source."""
    cleaned = strip_dart_comments(source)
    cases: list[TestCaseEntry] = []

    for match in DART_TEST_RE.finditer(cleaned):
        kind = match.group(1)
        title = _unescape_string(match.group(3))
        line = _line_number_at(cleaned, match.start(1))
        tags: list[str] = []
        if kind == "patrolTest":
            snippet = cleaned[match.end() : match.end() + 180]
            tags_match = DART_PATROL_TAGS_RE.search(snippet)
            if tags_match:
                tags = re.findall(r"['\"]([a-zA-Z0-9_-]+)['\"]", tags_match.group(1))
        cases.append(TestCaseEntry(name=title, kind=kind, line=line, tags=tags))
    return cases


def extract_tool_tests(path: Path) -> list[TestCaseEntry]:
    """Extracts JS (node:test) or Python (unittest) test names from tool test files."""
    text = path.read_text(encoding="utf-8", errors="replace")
    cases: list[TestCaseEntry] = []
    if path.suffix in (".mjs", ".js"):
        for match in JS_TEST_RE.finditer(text):
            cases.append(
                TestCaseEntry(
                    name=_unescape_string(match.group(2)),
                    kind="js-test",
                    line=_line_number_at(text, match.start()),
                )
            )
    elif path.suffix == ".py":
        for match in PY_TEST_RE.finditer(text):
            cases.append(
                TestCaseEntry(
                    name=match.group(1),
                    kind="py-test",
                    line=_line_number_at(text, match.start()),
                )
            )
    return cases


def classify_test_file(rel_path: str) -> str:
    """Classifies a repository-relative test path into one of the 6 layers."""
    norm = rel_path.replace("\\", "/")
    while norm.startswith("./"):
        norm = norm[2:]
    if norm.startswith("test/ui/"):
        return "ui"
    if norm.startswith("test/golden/"):
        return "golden"
    if norm.startswith("test/features/") or norm.startswith("test/shared/"):
        return "features"
    if norm.startswith("patrol_test/"):
        return "patrol"
    if norm.startswith("tool/"):
        return "tool"
    return "core"


def read_png_dimensions(path: Path) -> tuple[int | None, int | None]:
    """Reads (width, height) from a PNG header without external libraries."""
    try:
        with path.open("rb") as handle:
            header = handle.read(24)
        if len(header) >= 24 and header[:8] == b"\x89PNG\r\n\x1a\n":
            width, height = struct.unpack(">II", header[16:24])
            return int(width), int(height)
    except OSError:
        return None, None
    return None, None


def discover_features(repo_root: Path) -> list[str]:
    """Returns sorted feature directory names under lib/features/."""
    features_dir = repo_root / "lib" / "features"
    if not features_dir.is_dir():
        return []
    return sorted(
        entry.name
        for entry in features_dir.iterdir()
        if entry.is_dir() and not entry.name.startswith(".")
    )


def infer_features_for_dart_file(
    rel_path: str, source: str, known_features: set[str]
) -> list[str]:
    """Infers which lib/features/<name> features a Dart test file covers."""
    found: set[str] = set()
    parts = rel_path.replace("\\", "/").split("/")
    if len(parts) >= 3 and parts[0] == "test" and parts[1] == "features":
        if parts[2] in known_features:
            found.add(parts[2])

    for feat, _ in DART_IMPORT_FEATURE_RE.findall(source):
        if feat in known_features:
            found.add(feat)
    for feat in DART_PATH_FEATURE_RE.findall(source):
        if feat in known_features:
            found.add(feat)

    # Fallback filename matching for test/ui/<feature>_..._test.dart
    if rel_path.startswith("test/ui/"):
        stem = Path(rel_path).stem.lower()
        for feat in known_features:
            if re.search(rf"(?:^|_){re.escape(feat)}(?:_|$)", stem):
                found.add(feat)

    return sorted(found)


def infer_patrol_flow_features(
    case_body: str, file_imports: set[str], known_features: set[str]
) -> list[str]:
    """Infers which features a single patrolTest() block exercises."""
    lower = case_body.lower()
    matched: set[str] = set(file_imports & known_features)
    for feat, keywords in PATROL_FEATURE_KEYWORDS:
        if feat not in known_features:
            continue
        if any(kw in lower for kw in keywords):
            matched.add(feat)
    return sorted(matched)


def extract_patrol_flow_blocks(source: str) -> list[tuple[str, str]]:
    """Returns (flow_title, snippet) pairs for each patrolTest in a file."""
    cleaned = strip_dart_comments(source)
    matches = list(DART_TEST_RE.finditer(cleaned))
    blocks: list[tuple[str, str]] = []
    for idx, match in enumerate(matches):
        if match.group(1) != "patrolTest":
            continue
        title = _unescape_string(match.group(3))
        end_pos = matches[idx + 1].start() if idx + 1 < len(matches) else len(cleaned)
        blocks.append((title, cleaned[match.start() : end_pos]))
    return blocks


def classify_golden_category(name_or_filename: str) -> str:
    """Classifies a golden filename (e.g. beta_dark_heute.png) into a category id."""
    stem = Path(name_or_filename).stem.lower()
    slug = re.sub(r"^(?:beta|classic)_", "", stem)
    if slug.startswith("dark_"):
        return "dark"
    if slug.startswith("desktop_"):
        return "desktop"
    if slug.startswith("sheet_"):
        return "sheet"
    if slug.startswith("page_"):
        return "page"
    return "main"


def classify_test_risk_classes(
    rel_path: str,
    layer: str,
    case_names: list[str] | None = None,
) -> list[str]:
    """Classifies a test file into one or more bug-catching risk classes."""
    norm = rel_path.replace("\\", "/").lower()
    matched: set[str] = set()

    if layer == "ui":
        if "empty_error_roles" in norm:
            matched.add("flows")
        else:
            matched.add("layout")
    elif layer == "golden":
        matched.add("visual")
    elif layer == "patrol":
        matched.add("e2e")
    elif layer in ("features", "core"):
        if _LAYOUT_RISK_PATH_RE.search(norm):
            matched.add("layout")

        is_pure_security_guard = any(
            k in norm for k in ("security", "force_unwrap", "query_guard")
        )
        if layer == "features" and not is_pure_security_guard:
            matched.add("flows")
        elif "empty_error_roles" in norm or any(
            k in norm for k in ("role_permission", "route_access", "legacy_routes", "nav_replace")
        ):
            matched.add("flows")

        case_blob = " ".join(case_names or []).lower()
        if any(kw in norm for kw in _SECURITY_RISK_KEYWORDS) or (
            case_blob and _SECURITY_CASE_RE.search(case_blob)
        ):
            matched.add("security")

    return [rid for rid in RISK_CLASS_ORDER if rid in matched]


def map_goldens_to_features(
    repo_root: Path, known_features: set[str]
) -> dict[str, list[str]]:
    """Maps golden PNG filenames (e.g. beta_heute.png) to lib/features/<name>."""
    golden_dir = repo_root / "test" / "golden"
    slug_features: dict[str, set[str]] = {}

    if golden_dir.is_dir():
        for dart_file in sorted(golden_dir.glob("*_test.dart")):
            source = dart_file.read_text(encoding="utf-8", errors="replace")
            # Map widget/page identifiers imported from lib/features/<feat>/...
            widget_to_feat: dict[str, str] = {}
            for feat, rel_import in DART_IMPORT_FEATURE_RE.findall(source):
                if feat not in known_features:
                    continue
                target_file = repo_root / "lib" / "features" / feat / rel_import
                if target_file.is_file():
                    target_src = target_file.read_text(
                        encoding="utf-8", errors="replace"
                    )
                    for cls in re.findall(
                        r"\bclass\s+([A-Z][A-Za-z0-9_]*)\b", target_src
                    ):
                        widget_to_feat[cls] = feat

            cleaned = strip_dart_comments(source)
            matches = list(DART_TEST_RE.finditer(cleaned))
            for idx, match in enumerate(matches):
                end_pos = (
                    matches[idx + 1].start()
                    if idx + 1 < len(matches)
                    else len(cleaned)
                )
                block = cleaned[match.start() : end_pos]
                block_feats: set[str] = set()
                for widget_name, feat in widget_to_feat.items():
                    if re.search(rf"\b{re.escape(widget_name)}\b", block):
                        block_feats.add(feat)
                for slug in DART_EXPECT_GOLDEN_RE.findall(block):
                    slug_features.setdefault(slug.lower(), set()).update(block_feats)

    png_map: dict[str, list[str]] = {}
    goldens_dir = golden_dir / "goldens"
    if goldens_dir.is_dir():
        for png in sorted(goldens_dir.glob("*.png")):
            stem = png.stem.lower()
            # Strip common look prefixes (beta_/classic_) and category prefixes
            # (dark_/desktop_/page_/sheet_) for accurate fallback matching.
            raw_slug = re.sub(r"^(?:beta|classic)_", "", stem)
            base_slug = re.sub(r"^(?:dark|desktop|page|sheet)_", "", raw_slug)
            feats: set[str] = set(slug_features.get(raw_slug, set()))

            if base_slug in GOLDEN_COMPOUND_FEATURE_MAP:
                for candidate in GOLDEN_COMPOUND_FEATURE_MAP[base_slug]:
                    if candidate in known_features:
                        feats.add(candidate)
            elif not feats:
                if base_slug in GOLDEN_SLUG_FEATURE_ALIASES:
                    candidate = GOLDEN_SLUG_FEATURE_ALIASES[base_slug]
                    if candidate in known_features:
                        feats.add(candidate)
                else:
                    for token in base_slug.split("_"):
                        candidate = GOLDEN_SLUG_FEATURE_ALIASES.get(token, token)
                        if candidate in known_features:
                            feats.add(candidate)
            png_map[png.name] = sorted(feats)
    return png_map


def normalize_suite_path(raw_path: str, repo_root: Path) -> str:
    """Normalizes a Flutter JSON reporter suite path to a repo-relative POSIX path."""
    norm = raw_path.replace("\\", "/")
    root_posix = repo_root.resolve().as_posix().rstrip("/")
    if norm.startswith(root_posix + "/"):
        return norm[len(root_posix) + 1 :]
    for marker in ("/test/", "/patrol_test/", "/tool/"):
        idx = norm.find(marker)
        if idx != -1:
            return norm[idx + 1 :]
    if norm.startswith(("test/", "patrol_test/", "tool/")):
        return norm
    return Path(norm).name


def expand_result_paths(raw_paths: list[str] | None) -> list[Path]:
    """Expands file paths, directories, and glob patterns into existing JSON files."""
    if not raw_paths:
        return []
    collected: list[Path] = []
    seen: set[Path] = set()
    for raw in raw_paths:
        if any(ch in raw for ch in "*?["):
            candidates = [Path(p) for p in sorted(glob.glob(raw, recursive=True))]
        else:
            candidates = [Path(raw)]
        for candidate in candidates:
            if candidate.is_dir():
                for child in sorted(candidate.rglob("*.json")):
                    resolved = child.resolve()
                    if child.is_file() and resolved not in seen:
                        seen.add(resolved)
                        collected.append(child)
            elif candidate.is_file():
                resolved = candidate.resolve()
                if resolved not in seen:
                    seen.add(resolved)
                    collected.append(candidate)
    return collected


def _as_int(value: Any) -> int | None:
    """Returns [value] as int when it is a real integer (not bool), else None."""
    if isinstance(value, bool) or not isinstance(value, int):
        return None
    return value


def parse_ndjson_results(
    result_paths: list[Path],
    repo_root: Path,
    run_info: dict[str, Any] | None = None,
) -> dict[str, dict[str, Any]]:
    """Parses one or more `flutter test --file-reporter json:...` NDJSON files.

    Every result file is parsed in its own ID namespace: each CI shard is a
    separate `flutter test` process whose suite and test IDs all start at 0,
    so IDs must never be shared between files.

    Errors reported after a test's `testDone` (e.g. "This test failed after it
    had already completed") are still attached and turn the test into a
    failure.

    Returns a mapping: rel_path -> {
        "cases": [TestCaseEntry, ...],
        "passed": int,
        "failed": int,
        "skipped": int,
        "duration_ms": int,
    }

    When [run_info] is given it receives `parsed` (names of readable result
    files) and `incomplete` (names of result files without a final `done`
    event, i.e. a crashed, killed or cancelled `flutter test` run).
    """
    per_file: dict[str, dict[str, Any]] = {}
    parsed_names: list[str] = []
    incomplete_names: list[str] = []

    for json_path in result_paths:
        suites: dict[int, str] = {}
        tests: dict[int, dict[str, Any]] = {}
        errors: dict[int, list[str]] = {}
        # Finished tests of this file, in completion order: (testID, rel_path, case).
        finished: list[tuple[int, str, TestCaseEntry]] = []
        saw_done = False
        try:
            lines = json_path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        parsed_names.append(json_path.name)

        for raw_line in lines:
            line = raw_line.strip()
            if not line or not line.startswith("{"):
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            etype = event.get("type")
            if etype == "suite":
                suite = event.get("suite") or {}
                sid = _as_int(suite.get("id"))
                spath = suite.get("path")
                if sid is not None and isinstance(spath, str):
                    suites[sid] = normalize_suite_path(spath, repo_root)
            elif etype == "testStart":
                test_obj = event.get("test") or {}
                tid = _as_int(test_obj.get("id"))
                sid = _as_int(test_obj.get("suiteID"))
                if tid is not None and sid is not None:
                    meta = test_obj.get("metadata") or {}
                    tests[tid] = {
                        "name": str(test_obj.get("name") or ""),
                        "suite_id": sid,
                        "line": _as_int(test_obj.get("root_line"))
                        or _as_int(test_obj.get("line")),
                        "start_time": _as_int(event.get("time")) or 0,
                        "meta_skip": bool(meta.get("skip")),
                    }
            elif etype == "error":
                tid = _as_int(event.get("testID"))
                msg = str(event.get("error") or "").strip()
                if tid is not None and msg:
                    errors.setdefault(tid, []).append(msg)
            elif etype == "done":
                saw_done = True
            elif etype == "testDone":
                tid = _as_int(event.get("testID"))
                if tid is None or tid not in tests:
                    continue
                if event.get("hidden"):
                    continue
                info = tests[tid]
                rel_path = suites.get(info["suite_id"])
                if not rel_path:
                    continue
                done_time = _as_int(event.get("time")) or info["start_time"]
                duration_ms = max(0, done_time - info["start_time"])
                skipped = bool(event.get("skipped")) or info["meta_skip"]
                result = event.get("result")
                if skipped:
                    status = "skipped"
                elif result == "success":
                    status = "passed"
                else:
                    status = "failed"
                finished.append(
                    (
                        tid,
                        rel_path,
                        TestCaseEntry(
                            name=info["name"],
                            kind="executed",
                            line=info["line"],
                            status=status,
                            duration_ms=duration_ms,
                        ),
                    )
                )

        if not saw_done:
            incomplete_names.append(json_path.name)

        # Finalize after the whole file is read, so errors that arrive after
        # `testDone` are not lost.
        for tid, rel_path, case in finished:
            test_errors = errors.get(tid, [])
            case.error = "\n".join(test_errors)
            if test_errors and case.status == "passed":
                case.status = "failed"
            entry = per_file.setdefault(
                rel_path,
                {
                    "cases": [],
                    "passed": 0,
                    "failed": 0,
                    "skipped": 0,
                    "duration_ms": 0,
                },
            )
            entry["cases"].append(case)
            entry[case.status] += 1
            entry["duration_ms"] += case.duration_ms or 0

    if run_info is not None:
        run_info["parsed"] = parsed_names
        run_info["incomplete"] = incomplete_names
    return per_file


def scan_repository(
    repo_root: Path,
    result_paths: list[str] | None = None,
    embed_goldens: bool = False,
    expected_results: int | None = None,
) -> DashboardReport:
    """Scans the repository and merges optional live NDJSON test results."""
    features = discover_features(repo_root)
    known_features = set(features)

    expanded_results = expand_result_paths(result_paths)
    run_info: dict[str, Any] = {}
    live_by_file = parse_ndjson_results(expanded_results, repo_root, run_info)
    has_live = bool(live_by_file)

    files: list[TestFileEntry] = []

    # 1. Scan test/**/*_test.dart
    test_dir = repo_root / "test"
    if test_dir.is_dir():
        for dart_file in sorted(test_dir.rglob("*_test.dart")):
            rel_path = dart_file.relative_to(repo_root).as_posix()
            layer = classify_test_file(rel_path)
            source = dart_file.read_text(encoding="utf-8", errors="replace")
            file_feats = infer_features_for_dart_file(rel_path, source, known_features)
            static_cases = extract_dart_tests(source)

            live = live_by_file.get(rel_path)
            effective_cases = live["cases"] if live else static_cases
            risk_classes = classify_test_risk_classes(
                rel_path,
                layer,
                [c.name for c in effective_cases],
            )
            if live:
                cases = live["cases"]
                files.append(
                    TestFileEntry(
                        path=rel_path,
                        layer=layer,
                        features=file_feats,
                        risk_classes=risk_classes,
                        cases=cases,
                        passed=live["passed"],
                        failed=live["failed"],
                        skipped=live["skipped"],
                        duration_ms=live["duration_ms"],
                        has_live_results=True,
                    )
                )
            else:
                files.append(
                    TestFileEntry(
                        path=rel_path,
                        layer=layer,
                        features=file_feats,
                        risk_classes=risk_classes,
                        cases=static_cases,
                    )
                )

    # 2. Scan patrol_test/**/*_test.dart
    patrol_dir = repo_root / "patrol_test"
    patrol_flow_features: dict[str, int] = {f: 0 for f in features}
    if patrol_dir.is_dir():
        for dart_file in sorted(patrol_dir.rglob("*_test.dart")):
            rel_path = dart_file.relative_to(repo_root).as_posix()
            source = dart_file.read_text(encoding="utf-8", errors="replace")
            import_feats = {
                feat
                for feat, _ in DART_IMPORT_FEATURE_RE.findall(source)
                if feat in known_features
            }
            cases = extract_dart_tests(source)
            blocks = extract_patrol_flow_blocks(source)
            file_feats: set[str] = set(import_feats)
            for title, snippet in blocks:
                flow_feats = infer_patrol_flow_features(
                    f"{title}\n{snippet}", import_feats, known_features
                )
                for feat in flow_feats:
                    patrol_flow_features[feat] += 1
                    file_feats.add(feat)
            live = live_by_file.get(rel_path)
            effective_cases = live["cases"] if live else cases
            files.append(
                TestFileEntry(
                    path=rel_path,
                    layer="patrol",
                    features=sorted(file_feats),
                    risk_classes=classify_test_risk_classes(
                        rel_path,
                        "patrol",
                        [c.name for c in effective_cases],
                    ),
                    cases=effective_cases,
                    passed=live["passed"] if live else 0,
                    failed=live["failed"] if live else 0,
                    skipped=live["skipped"] if live else 0,
                    duration_ms=live["duration_ms"] if live else 0,
                    has_live_results=bool(live),
                )
            )

    # 3. Scan tool/ tests (Python unittest & JS node:test)
    tool_dir = repo_root / "tool"
    if tool_dir.is_dir():
        tool_candidates = sorted(
            p
            for p in tool_dir.rglob("*")
            if p.is_file()
            and (
                p.name.endswith(".test.mjs")
                or p.name.endswith(".test.js")
                or (
                    p.suffix == ".py"
                    and (p.name.startswith("test_") or p.name.endswith("_test.py"))
                )
            )
        )
        for tool_file in tool_candidates:
            rel_path = tool_file.relative_to(repo_root).as_posix()
            cases = extract_tool_tests(tool_file)
            files.append(
                TestFileEntry(
                    path=rel_path,
                    layer="tool",
                    features=[],
                    risk_classes=[],
                    cases=cases,
                )
            )

    # 3b. Live results whose suite path matches no scanned file (renamed or
    # deleted file, a different checkout root, an unexpected path format)
    # must still count, otherwise their failures silently disappear.
    scanned_paths = {f.path for f in files}
    for rel_path in sorted(set(live_by_file) - scanned_paths):
        live = live_by_file[rel_path]
        orphan_layer = classify_test_file(rel_path)
        files.append(
            TestFileEntry(
                path=rel_path,
                layer=orphan_layer,
                features=[],
                risk_classes=classify_test_risk_classes(
                    rel_path,
                    orphan_layer,
                    [c.name for c in live["cases"]],
                ),
                cases=live["cases"],
                passed=live["passed"],
                failed=live["failed"],
                skipped=live["skipped"],
                duration_ms=live["duration_ms"],
                has_live_results=True,
            )
        )

    # 4. Scan test/golden/goldens/*.png
    golden_feature_map = map_goldens_to_features(repo_root, known_features)
    goldens: list[GoldenEntry] = []
    golden_category_counts: dict[str, int] = {cat: 0 for cat in GOLDEN_CATEGORY_ORDER}
    goldens_dir = repo_root / "test" / "golden" / "goldens"
    if goldens_dir.is_dir():
        for png in sorted(goldens_dir.glob("*.png")):
            rel_path = png.relative_to(repo_root).as_posix()
            width, height = read_png_dimensions(png)
            category = classify_golden_category(png.name)
            golden_category_counts[category] = golden_category_counts.get(category, 0) + 1
            data_uri: str | None = None
            if embed_goldens:
                raw_bytes = png.read_bytes()
                b64 = base64.b64encode(raw_bytes).decode("ascii")
                data_uri = f"data:image/png;base64,{b64}"
            goldens.append(
                GoldenEntry(
                    name=png.stem,
                    path=rel_path,
                    features=golden_feature_map.get(png.name, []),
                    size_bytes=png.stat().st_size,
                    category=category,
                    width=width,
                    height=height,
                    data_uri=data_uri,
                )
            )

    # 5. Build Feature Coverage Matrix
    matrix: list[dict[str, Any]] = []
    for feat in features:
        unit_files = 0
        unit_cases = 0
        ui_files = 0
        ui_cases = 0
        feat_risks: set[str] = set()
        for fentry in files:
            if feat not in fentry.features:
                continue
            feat_risks.update(fentry.risk_classes)
            if fentry.layer in ("features", "core"):
                unit_files += 1
                unit_cases += len(fentry.cases)
            elif fentry.layer == "ui":
                ui_files += 1
                ui_cases += len(fentry.cases)
        golden_count = sum(1 for g in goldens if feat in g.features)
        patrol_count = patrol_flow_features.get(feat, 0)
        if golden_count > 0:
            feat_risks.add("visual")
        if patrol_count > 0:
            feat_risks.add("e2e")
        total_signals = unit_cases + ui_cases + golden_count + patrol_count
        matrix.append(
            {
                "feature": feat,
                "unit_files": unit_files,
                "unit_cases": unit_cases,
                "ui_files": ui_files,
                "ui_cases": ui_cases,
                "goldens": golden_count,
                "patrol_flows": patrol_count,
                "risk_classes": [rid for rid in RISK_CLASS_ORDER if rid in feat_risks],
                "total": total_signals,
            }
        )

    # 6. Aggregate layer stats, risk class stats, and global totals
    layer_stats: dict[str, dict[str, Any]] = {}
    for layer_id in LAYER_ORDER:
        layer_files = [f for f in files if f.layer == layer_id]
        layer_stats[layer_id] = {
            "files": len(layer_files),
            "cases": sum(len(f.cases) for f in layer_files),
            "passed": sum(f.passed for f in layer_files),
            "failed": sum(f.failed for f in layer_files),
            "skipped": sum(f.skipped for f in layer_files),
            "duration_ms": sum(f.duration_ms for f in layer_files),
            "has_live": any(f.has_live_results for f in layer_files),
        }

    risk_class_stats: dict[str, dict[str, Any]] = {}
    for risk_id in RISK_CLASS_ORDER:
        risk_files = [f for f in files if risk_id in f.risk_classes]
        risk_feats_covered = sum(
            1 for row in matrix if risk_id in row["risk_classes"]
        )
        risk_class_stats[risk_id] = {
            "files": len(risk_files),
            "cases": sum(len(f.cases) for f in risk_files),
            "passed": sum(f.passed for f in risk_files),
            "failed": sum(f.failed for f in risk_files),
            "skipped": sum(f.skipped for f in risk_files),
            "duration_ms": sum(f.duration_ms for f in risk_files),
            "has_live": any(f.has_live_results for f in risk_files),
            "features_covered": risk_feats_covered,
            "goldens": len(goldens) if risk_id == "visual" else 0,
            "golden_categories": (
                dict(golden_category_counts) if risk_id == "visual" else {}
            ),
        }

    failed_cases: list[dict[str, str]] = []
    for fentry in files:
        for case in fentry.cases:
            if case.status == "failed":
                failed_cases.append(
                    {
                        "file": fentry.path,
                        "layer": fentry.layer,
                        "name": case.name,
                        "error": case.error,
                    }
                )

    flutter_files = [f for f in files if f.layer in ("ui", "golden", "features", "core")]
    files_without_results = (
        [f.path for f in flutter_files if not f.has_live_results] if has_live else []
    )
    totals = {
        "all_files": len(files),
        "all_cases": sum(len(f.cases) for f in files),
        "flutter_files": len(flutter_files),
        "flutter_cases": sum(len(f.cases) for f in flutter_files),
        "passed": sum(f.passed for f in files),
        "failed": sum(f.failed for f in files),
        "skipped": sum(f.skipped for f in files),
        "duration_ms": sum(f.duration_ms for f in files),
        "goldens": len(goldens),
        "patrol_files": layer_stats["patrol"]["files"],
        "patrol_flows": layer_stats["patrol"]["cases"],
        "tool_files": layer_stats["tool"]["files"],
        "tool_cases": layer_stats["tool"]["cases"],
        "features_total": len(features),
        "features_covered": sum(1 for row in matrix if row["total"] > 0),
    }

    return DashboardReport(
        repo_root=repo_root,
        generated_at=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        has_live_results=has_live,
        result_files=list(run_info.get("parsed", [])),
        files=files,
        goldens=goldens,
        features=features,
        feature_matrix=matrix,
        layer_stats=layer_stats,
        totals=totals,
        failed_cases=failed_cases,
        risk_class_stats=risk_class_stats,
        golden_category_counts=golden_category_counts,
        incomplete_results=list(run_info.get("incomplete", [])),
        expected_results=expected_results,
        files_without_results=files_without_results,
    )


def format_duration(ms: int | None) -> str:
    """Formats milliseconds into a compact human-readable string."""
    if ms is None:
        return "—"
    if ms < 1000:
        return f"{ms} ms"
    seconds = ms / 1000.0
    if seconds < 60:
        return f"{seconds:.1f} s"
    minutes = int(seconds // 60)
    rem = seconds % 60
    return f"{minutes}m {rem:.0f}s"


def _md_text(value: str) -> str:
    """Escapes free text (test names, paths) for one line of GFM / a table cell."""
    flat = " ".join(str(value).split())
    for ch in ("\\", "`", "*", "_", "[", "]", "<", ">", "|"):
        flat = flat.replace(ch, "\\" + ch)
    return flat


def _md_code(value: str) -> str:
    """Formats text as inline code that a backtick or pipe inside cannot break."""
    flat = " ".join(str(value).split()).replace("`", "'").replace("|", "¦")
    return f"`{flat}`" if flat else ""


def render_markdown(report: DashboardReport) -> str:
    """Renders a GitHub-Flavored Markdown summary for $GITHUB_STEP_SUMMARY.

    Durations are the sum of all test durations (shards run in parallel, so
    this is not the wall-clock time of the CI run).
    """
    t = report.totals
    lines: list[str] = ["## Attendix · Test- & Qualitäts-Dashboard", ""]
    warnings = report.result_warnings

    if report.has_live_results:
        if t["failed"] == 0 and not warnings:
            lines.append(
                f"✅ **Alle {t['passed']} ausgeführten Tests bestanden** "
                f"({t['skipped']} übersprungen · Σ Testdauer {format_duration(t['duration_ms'])} · "
                f"{len(report.result_files)} Ergebnisdatei(en))"
            )
        elif t["failed"] == 0:
            lines.append(
                f"⚠️ **Keine Fehlschläge in den gelieferten Ergebnissen, aber "
                f"die Ergebnisse sind unvollständig** · {t['passed']} bestanden · "
                f"{t['skipped']} übersprungen · {len(report.result_files)} Ergebnisdatei(en)"
            )
        else:
            lines.append(
                f"❌ **{t['failed']} Test(s) fehlgeschlagen** · "
                f"{t['passed']} bestanden · {t['skipped']} übersprungen "
                f"(Σ Testdauer {format_duration(t['duration_ms'])})"
            )
    else:
        lines.append(
            f"ℹ️ **Statischer Repo-Scan** (keine Live-Ergebnisse): "
            f"**{t['all_files']} Testdateien** mit **{t['all_cases']} Testfällen** "
            f"über 4 Flutter-Schichten + Patrol E2E + Tooling."
        )
    if warnings:
        lines.append("")
        lines.extend(f"> ⚠️ {w}" for w in warnings)
        if report.has_live_results and report.files_without_results:
            shown = report.files_without_results[:15]
            lines.append(
                "> Ohne Ergebnis: "
                + ", ".join(_md_code(path) for path in shown)
                + (
                    f" … und {len(report.files_without_results) - len(shown)} weitere."
                    if len(report.files_without_results) > len(shown)
                    else ""
                )
            )

    lines.extend(
        [
            "",
            "| Schicht | Pfad | Dateien | Testfälle | Bestanden | Fehlgeschlagen | Übersprungen | Σ Testdauer |",
            "|---|---|---:|---:|---:|---:|---:|---:|",
        ]
    )

    for layer_id in LAYER_ORDER:
        meta = LAYER_META[layer_id]
        st = report.layer_stats[layer_id]
        if st["has_live"]:
            passed = str(st["passed"])
            failed = f"**{st['failed']}**" if st["failed"] > 0 else "0"
            skipped = str(st["skipped"])
            dur = format_duration(st["duration_ms"])
        else:
            passed = "—"
            failed = "—"
            skipped = "—"
            dur = "—"
        lines.append(
            f"| {meta['badge']}: {meta['title']} | `{meta['path_hint']}` | "
            f"{st['files']} | {st['cases']} | {passed} | {failed} | {skipped} | {dur} |"
        )

    if report.failed_cases:
        lines.extend(["", "### Fehlgeschlagene Tests", ""])
        for failure in report.failed_cases[:25]:
            first_line = next(
                (ln.strip() for ln in failure["error"].splitlines() if ln.strip()),
                "",
            )
            err_suffix = f" — {_md_code(first_line[:140])}" if first_line else ""
            lines.append(
                f"- {_md_code(failure['file'])} · **{_md_text(failure['name'])}**{err_suffix}"
            )
        if len(report.failed_cases) > 25:
            lines.append(f"- … und {len(report.failed_cases) - 25} weitere.")

    uncovered = [r["feature"] for r in report.feature_matrix if r["total"] == 0]
    golden_cat_parts = [
        f"{GOLDEN_CATEGORY_META[cid]['label']}: {report.golden_category_counts.get(cid, 0)}"
        for cid in GOLDEN_CATEGORY_ORDER
    ]
    lines.extend(
        [
            "",
            '### Bug-Risikoklassen-Abdeckung ("Welche echten Fehlerklassen fangen wir ab?")',
            "",
            "| Risikoklasse | Quelle | Dateien / Artefakte | Testfälle | Features | Live-Status |",
            "|---|---|---|---:|---:|---|",
        ]
    )
    for risk_id in RISK_CLASS_ORDER:
        rmeta = RISK_CLASS_META[risk_id]
        rst = report.risk_class_stats.get(
            risk_id,
            {
                "files": 0,
                "cases": 0,
                "passed": 0,
                "failed": 0,
                "skipped": 0,
                "has_live": False,
                "features_covered": 0,
                "goldens": 0,
            },
        )
        file_word = "Datei" if rst["files"] == 1 else "Dateien"
        if risk_id == "visual":
            artifact_col = f"{rst['files']} {file_word} · {rst.get('goldens', 0)} Goldens"
        else:
            artifact_col = f"{rst['files']} {file_word}"
        if rst["has_live"]:
            live_col = (
                f"❌ {rst['failed']} Fail · {rst['passed']} OK"
                if rst["failed"] > 0
                else f"✅ {rst['passed']} OK"
            )
        else:
            live_col = "—"
        lines.append(
            f"| **{rmeta['title']}** | `{rmeta['source_hint']}` | "
            f"{artifact_col} | {rst['cases']} | {rst['features_covered']}/{t['features_total']} | {live_col} |"
        )

    lines.extend(
        [
            "",
            "### Kennzahlen & Abdeckung",
            "",
            f"- **Feature-Abdeckung:** {t['features_covered']} / {t['features_total']} Features in `lib/features/` mit mindestens einem Test-Signal",
            f"- **Golden-Screenshots:** {t['goldens']} Referenzbilder in `test/golden/goldens/` ({' · '.join(golden_cat_parts)})",
            f"- **Patrol E2E-Flows:** {t['patrol_flows']} Szenarien in {t['patrol_files']} Rollen-Dateien (`patrol_test/`)",
        ]
    )
    if uncovered:
        lines.append(
            "- **Features ohne direkte Tests:** "
            + ", ".join(f"`{name}`" for name in uncovered)
        )

    lines.extend(
        [
            "",
            "> 💡 Das vollständige interaktive HTML-Dashboard inkl. Golden-Galerie "
            "und durchsuchbarem Test-Explorer steht als CI-Artifact **`test-dashboard`** bereit.",
            "",
        ]
    )
    return "\n".join(lines)


def _golden_src(golden: GoldenEntry, html_path: Path, repo_root: Path) -> str:
    if golden.data_uri:
        return golden.data_uri
    abs_png = repo_root / golden.path
    try:
        return os.path.relpath(abs_png, start=html_path.parent.resolve()).replace(
            "\\", "/"
        )
    except ValueError:
        return golden.path


def render_html(report: DashboardReport, html_path: Path) -> str:
    """Renders a self-contained, responsive HTML dashboard."""
    t = report.totals

    warnings = report.result_warnings
    if report.has_live_results:
        if t["failed"] == 0 and warnings:
            status_badge = (
                '<span class="pill pill-warn">Live-Ergebnis unvollständig · '
                f'{t["passed"]} bestanden</span>'
            )
        elif t["failed"] == 0:
            status_badge = (
                '<span class="pill pill-pass">Live-Ergebnis · '
                f'{t["passed"]} bestanden</span>'
            )
        else:
            status_badge = (
                '<span class="pill pill-fail">Live-Ergebnis · '
                f'{t["failed"]} fehlgeschlagen</span>'
            )
        status_card_value = f"{t['passed']} / {t['passed'] + t['failed'] + t['skipped']}"
        status_card_sub = (
            f"{t['failed']} fehlgeschlagen · {t['skipped']} übersprungen · "
            f"{format_duration(t['duration_ms'])}"
        )
        status_card_tone = (
            "kpi-fail" if t["failed"] else ("kpi-neutral" if warnings else "kpi-pass")
        )
    else:
        status_badge = '<span class="pill pill-info">Statischer Repo-Scan</span>'
        status_card_value = "Kein Lauf"
        status_card_sub = "Mit --results <json> live befüllbar"
        status_card_tone = "kpi-neutral"

    # Build 4+2 layer architecture cards
    layer_cards_html: list[str] = []
    for layer_id in LAYER_ORDER:
        meta = LAYER_META[layer_id]
        st = report.layer_stats[layer_id]
        if st["has_live"]:
            tone = "pill-pass" if st["failed"] == 0 else "pill-fail"
            live_text = (
                f"{st['passed']} OK"
                + (f" · {st['failed']} Fail" if st["failed"] else "")
                + f" · {format_duration(st['duration_ms'])}"
            )
            live_pill = f'<span class="pill {tone}">{html.escape(live_text)}</span>'
        else:
            live_pill = (
                f'<span class="pill pill-muted">{st["files"]} Dateien · '
                f'{st["cases"]} Tests</span>'
            )

        layer_cards_html.append(
            f"""
            <article class="layer-card" data-layer="{html.escape(layer_id)}">
              <div class="layer-head">
                <div>
                  <span class="layer-badge">{html.escape(meta['badge'])}</span>
                  <h3>{html.escape(meta['title'])}</h3>
                </div>
                {live_pill}
              </div>
              <p class="layer-path"><code>{html.escape(meta['path_hint'])}</code></p>
              <p class="layer-desc">{html.escape(meta['catches'])}</p>
              <dl class="layer-meta">
                <div><dt>CI</dt><dd>{html.escape(meta['ci'])}</dd></div>
                <div><dt>Lokal</dt><dd><code>{html.escape(meta['cmd'])}</code></dd></div>
              </dl>
            </article>
            """
        )

    # Build Bug-Risk-Class cards ("Welche echten Fehlerklassen fangen wir ab?")
    risk_cards_html: list[str] = []
    for risk_id in RISK_CLASS_ORDER:
        rmeta = RISK_CLASS_META[risk_id]
        rst = report.risk_class_stats.get(
            risk_id,
            {
                "files": 0,
                "cases": 0,
                "passed": 0,
                "failed": 0,
                "skipped": 0,
                "duration_ms": 0,
                "has_live": False,
                "features_covered": 0,
                "goldens": 0,
                "golden_categories": {},
            },
        )
        if rst["has_live"]:
            rtone = "pill-pass" if rst["failed"] == 0 else "pill-fail"
            rlive_text = (
                f"{rst['passed']} OK"
                + (f" · {rst['failed']} Fail" if rst["failed"] else "")
                + f" · {format_duration(rst['duration_ms'])}"
            )
            rpill = f'<span class="pill {rtone}">{html.escape(rlive_text)}</span>'
        elif risk_id == "visual":
            rpill = (
                f'<span class="pill pill-info">{rst.get("goldens", 0)} Goldens · '
                f'{rst["cases"]} Tests</span>'
            )
        else:
            file_word = "Datei" if rst["files"] == 1 else "Dateien"
            rpill = (
                f'<span class="pill pill-muted">{rst["files"]} {file_word} · '
                f'{rst["cases"]} Tests</span>'
            )

        golden_breakdown_html = ""
        if risk_id == "visual":
            cat_buttons = []
            for cat_id in GOLDEN_CATEGORY_ORDER:
                cat_label = GOLDEN_CATEGORY_META[cat_id]["label"]
                cat_cnt = report.golden_category_counts.get(cat_id, 0)
                cat_buttons.append(
                    f'<button type="button" class="chip-tag chip-link" '
                    f'onclick="focusGoldenCategory(\'{html.escape(cat_id)}\')">'
                    f'{html.escape(cat_label)}: {cat_cnt}</button>'
                )
            golden_breakdown_html = (
                '<div class="risk-subchips">' + "".join(cat_buttons) + "</div>"
            )

        risk_cards_html.append(
            f"""
            <article class="layer-card risk-card" data-risk="{html.escape(risk_id)}">
              <div class="layer-head">
                <div>
                  <span class="layer-badge">{html.escape(rmeta['badge'])}</span>
                  <h3>{html.escape(rmeta['title'])}</h3>
                </div>
                {rpill}
              </div>
              <p class="layer-path"><code>{html.escape(rmeta['source_hint'])}</code></p>
              <p class="layer-desc">{html.escape(rmeta['catches'])}</p>
              {golden_breakdown_html}
              <div class="risk-foot">
                <span class="muted">{rst['features_covered']} / {t['features_total']} Features abgedeckt</span>
                <button type="button" class="btn btn-sm" onclick="focusRisk('{html.escape(risk_id)}')">Tests filtern →</button>
              </div>
            </article>
            """
        )

    # Feature Coverage Matrix rows
    matrix_rows_html: list[str] = []
    for row in report.feature_matrix:
        feat = row["feature"]
        row_risks = set(row.get("risk_classes", []))
        row_cls = "row-gap" if row["total"] == 0 else ""

        def cell_badge(count: int, sub: str = "") -> str:
            if count == 0:
                return '<span class="num num-zero">0</span>'
            extra = f' <small class="muted">({html.escape(sub)})</small>' if sub else ""
            return f'<span class="num num-ok">{count}</span>{extra}'

        unit_sub = f"{row['unit_files']}D" if row["unit_files"] else ""
        ui_sub = f"{row['ui_files']}D" if row["ui_files"] else ""
        risk_badges_html = "".join(
            f'<span class="risk-mini {"risk-mini-on" if rid in row_risks else "risk-mini-off"}" '
            f'title="{html.escape(RISK_CLASS_META[rid]["title"])}">'
            f'{html.escape(RISK_CLASS_META[rid]["short"])}</span>'
            for rid in RISK_CLASS_ORDER
        )
        total_pill = (
            '<span class="pill pill-warn">Keine Tests</span>'
            if row["total"] == 0
            else f'<span class="pill pill-pass">{row["total"]} Signale</span>'
        )
        matrix_rows_html.append(
            f"""
            <tr class="{row_cls}" data-feature="{html.escape(feat)}" data-gap="{'1' if row['total'] == 0 else '0'}" data-risks="{html.escape(','.join(row.get('risk_classes', [])))}">
              <td><strong>{html.escape(feat)}</strong></td>
              <td class="tc">{cell_badge(row['unit_cases'], unit_sub)}</td>
              <td class="tc">{cell_badge(row['ui_cases'], ui_sub)}</td>
              <td class="tc">{cell_badge(row['goldens'])}</td>
              <td class="tc">{cell_badge(row['patrol_flows'])}</td>
              <td><div class="risk-mini-wrap">{risk_badges_html}</div></td>
              <td class="tc">{total_pill}</td>
            </tr>
            """
        )

    # Golden gallery category chips & cards
    golden_category_chips_html: list[str] = [
        f'<button type="button" class="chip active" data-golden-cat="all" '
        f'onclick="setGoldenCategory(\'all\')">Alle ({len(report.goldens)})</button>'
    ]
    for cat_id in GOLDEN_CATEGORY_ORDER:
        cat_label = GOLDEN_CATEGORY_META[cat_id]["label"]
        cat_count = report.golden_category_counts.get(cat_id, 0)
        golden_category_chips_html.append(
            f'<button type="button" class="chip" data-golden-cat="{html.escape(cat_id)}" '
            f'onclick="setGoldenCategory(\'{html.escape(cat_id)}\')">'
            f'{html.escape(cat_label)} ({cat_count})</button>'
        )

    golden_cards_html: list[str] = []
    for g in report.goldens:
        src = _golden_src(g, html_path, report.repo_root)
        dims = f"{g.width}×{g.height} px" if g.width and g.height else "PNG"
        size_kb = f"{g.size_bytes / 1024:.0f} KB"
        cat_label = GOLDEN_CATEGORY_META.get(g.category, {}).get("label", g.category)
        feat_tags = "".join(
            f'<span class="chip-tag">{html.escape(f)}</span>' for f in g.features
        )
        golden_cards_html.append(
            f"""
            <figure class="golden-card" data-name="{html.escape(g.name)}" data-category="{html.escape(g.category)}">
              <button type="button" class="golden-thumb-btn" onclick="openGoldenModal(this)"
                data-src="{html.escape(src)}" data-title="{html.escape(g.name)}"
                data-meta="{html.escape(g.path)} · {html.escape(cat_label)} · {dims} · {size_kb}">
                <img src="{html.escape(src)}" alt="{html.escape(g.name)}" loading="lazy" />
              </button>
              <figcaption>
                <div class="golden-title">{html.escape(g.name)}</div>
                <div class="golden-sub">{dims} · {size_kb}</div>
                <div class="golden-tags"><span class="chip-tag chip-cat">{html.escape(cat_label)}</span>{feat_tags or '<span class="chip-tag">App</span>'}</div>
              </figcaption>
            </figure>
            """
        )

    if not golden_cards_html:
        golden_cards_html.append(
            '<p class="empty-note">Keine Golden-Screenshots in <code>test/golden/goldens/</code> gefunden.</p>'
        )

    # Explorer JSON payload (escaped cleanly against </script>)
    explorer_payload = [
        {
            "path": f.path,
            "layer": f.layer,
            "layerLabel": LAYER_META[f.layer]["short"],
            "features": f.features,
            "riskClasses": f.risk_classes,
            "riskLabels": [RISK_CLASS_META[r]["short"] for r in f.risk_classes],
            "passed": f.passed,
            "failed": f.failed,
            "skipped": f.skipped,
            "durationMs": f.duration_ms,
            "hasLive": f.has_live_results,
            "cases": [
                {
                    "name": c.name,
                    "kind": c.kind,
                    "line": c.line,
                    "status": c.status,
                    "durationMs": c.duration_ms,
                    "error": c.error,
                    "tags": c.tags,
                }
                for c in f.cases
            ],
        }
        for f in report.files
    ]
    # Escape every "<" (covers </script> and <!--) plus the JS line
    # separators, so test names or error texts can never end the <script>.
    explorer_json = (
        json.dumps(explorer_payload, ensure_ascii=False)
        .replace("<", "\\u003c")
        .replace("\u2028", "\\u2028")
        .replace("\u2029", "\\u2029")
    )
    warnings_html = "".join(
        f'<p class="result-warning" role="alert">⚠️ {html.escape(w)}</p>'
        for w in warnings
    )

    return f"""<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Attendix · Test- &amp; Qualitäts-Dashboard</title>
  <style>
    :root {{
      --bg: #f6f8fb;
      --surface: #ffffff;
      --surface-2: #f0f3f8;
      --border: #dfe5ef;
      --text: #141b29;
      --muted: #5a6578;
      --accent: #2563eb;
      --accent-soft: rgba(37, 99, 235, 0.12);
      --pass: #15803d;
      --pass-bg: rgba(21, 128, 61, 0.12);
      --fail: #b91c1c;
      --fail-bg: rgba(185, 28, 28, 0.12);
      --warn: #b45309;
      --warn-bg: rgba(180, 83, 9, 0.12);
      --skip: #64748b;
      --skip-bg: rgba(100, 116, 139, 0.14);
      --shadow: 0 1px 3px rgba(15, 23, 42, 0.06), 0 8px 24px rgba(15, 23, 42, 0.04);
      --radius: 14px;
    }}
    @media (prefers-color-scheme: dark) {{
      :root:not([data-theme="light"]) {{
        --bg: #0b1120;
        --surface: #111827;
        --surface-2: #1a2334;
        --border: #253147;
        --text: #e5ecf6;
        --muted: #94a3b8;
        --accent: #60a5fa;
        --accent-soft: rgba(96, 165, 250, 0.16);
        --pass: #4ade80;
        --pass-bg: rgba(74, 222, 128, 0.15);
        --fail: #f87171;
        --fail-bg: rgba(248, 113, 113, 0.16);
        --warn: #fbbf24;
        --warn-bg: rgba(251, 191, 36, 0.15);
        --skip: #94a3b8;
        --skip-bg: rgba(148, 163, 184, 0.15);
        --shadow: 0 4px 20px rgba(0, 0, 0, 0.35);
      }}
    }}
    :root[data-theme="dark"] {{
      --bg: #0b1120;
      --surface: #111827;
      --surface-2: #1a2334;
      --border: #253147;
      --text: #e5ecf6;
      --muted: #94a3b8;
      --accent: #60a5fa;
      --accent-soft: rgba(96, 165, 250, 0.16);
      --pass: #4ade80;
      --pass-bg: rgba(74, 222, 128, 0.15);
      --fail: #f87171;
      --fail-bg: rgba(248, 113, 113, 0.16);
      --warn: #fbbf24;
      --warn-bg: rgba(251, 191, 36, 0.15);
      --skip: #94a3b8;
      --skip-bg: rgba(148, 163, 184, 0.15);
      --shadow: 0 4px 20px rgba(0, 0, 0, 0.35);
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Inter, sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.5;
    }}
    code {{
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      font-size: 0.86em;
      background: var(--surface-2);
      padding: 0.12rem 0.36rem;
      border-radius: 6px;
    }}
    .container {{
      max-width: 1280px;
      margin: 0 auto;
      padding: 1.5rem 1.25rem 4rem;
    }}
    header.topbar {{
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 1rem;
      margin-bottom: 1.5rem;
      padding-bottom: 1rem;
      border-bottom: 1px solid var(--border);
    }}
    header.topbar h1 {{
      margin: 0;
      font-size: 1.55rem;
      letter-spacing: -0.02em;
    }}
    .subtitle {{
      color: var(--muted);
      font-size: 0.9rem;
      margin-top: 0.25rem;
    }}
    .topbar-actions {{
      display: flex;
      align-items: center;
      gap: 0.65rem;
      flex-wrap: wrap;
    }}
    .btn {{
      border: 1px solid var(--border);
      background: var(--surface);
      color: var(--text);
      padding: 0.45rem 0.8rem;
      border-radius: 10px;
      font-size: 0.85rem;
      font-weight: 500;
      cursor: pointer;
    }}
    .btn:hover {{ border-color: var(--accent); }}
    .pill {{
      display: inline-flex;
      align-items: center;
      gap: 0.35rem;
      padding: 0.22rem 0.6rem;
      border-radius: 999px;
      font-size: 0.78rem;
      font-weight: 600;
      white-space: nowrap;
    }}
    .pill-pass {{ background: var(--pass-bg); color: var(--pass); }}
    .pill-fail {{ background: var(--fail-bg); color: var(--fail); }}
    .pill-warn {{ background: var(--warn-bg); color: var(--warn); }}
    .pill-info {{ background: var(--accent-soft); color: var(--accent); }}
    .pill-muted {{ background: var(--surface-2); color: var(--muted); }}

    .kpi-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
      gap: 1rem;
      margin-bottom: 2rem;
    }}
    .kpi-card {{
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      padding: 1.05rem 1.15rem;
      box-shadow: var(--shadow);
    }}
    .kpi-card.kpi-pass {{ border-left: 4px solid var(--pass); }}
    .kpi-card.kpi-fail {{ border-left: 4px solid var(--fail); }}
    .kpi-label {{
      font-size: 0.8rem;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 0.04em;
      font-weight: 600;
    }}
    .kpi-value {{
      font-size: 1.8rem;
      font-weight: 700;
      margin: 0.25rem 0 0.2rem;
      letter-spacing: -0.02em;
    }}
    .kpi-sub {{
      font-size: 0.82rem;
      color: var(--muted);
    }}

    section.block {{
      margin-bottom: 2.4rem;
    }}
    section.block > h2 {{
      font-size: 1.2rem;
      margin: 0 0 0.35rem;
    }}
    .section-lead {{
      color: var(--muted);
      margin: 0 0 1rem;
      font-size: 0.92rem;
    }}

    .layer-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 1rem;
    }}
    .layer-card {{
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      padding: 1.1rem 1.2rem;
      box-shadow: var(--shadow);
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
    }}
    .layer-head {{
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 0.5rem;
    }}
    .layer-badge {{
      display: inline-block;
      font-size: 0.72rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--accent);
      margin-bottom: 0.15rem;
    }}
    .layer-head h3 {{
      margin: 0;
      font-size: 1.02rem;
    }}
    .layer-path {{ margin: 0; }}
    .layer-desc {{
      margin: 0;
      font-size: 0.88rem;
      color: var(--text);
    }}
    .layer-meta {{
      margin: 0.25rem 0 0;
      padding-top: 0.6rem;
      border-top: 1px solid var(--border);
      display: grid;
      gap: 0.35rem;
      font-size: 0.8rem;
    }}
    .layer-meta > div {{
      display: grid;
      grid-template-columns: 44px 1fr;
      gap: 0.5rem;
      align-items: baseline;
    }}
    .layer-meta dt {{ color: var(--muted); font-weight: 600; }}
    .layer-meta dd {{ margin: 0; }}

    .panel {{
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      overflow: hidden;
    }}
    .panel-toolbar {{
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
      align-items: center;
      justify-content: space-between;
      padding: 0.9rem 1rem;
      border-bottom: 1px solid var(--border);
      background: var(--surface-2);
    }}
    .input {{
      border: 1px solid var(--border);
      background: var(--surface);
      color: var(--text);
      padding: 0.48rem 0.75rem;
      border-radius: 9px;
      font-size: 0.88rem;
      min-width: 240px;
    }}
    .input:focus {{ outline: 2px solid var(--accent-soft); border-color: var(--accent); }}
    .chips {{
      display: flex;
      flex-wrap: wrap;
      gap: 0.4rem;
    }}
    .chip {{
      border: 1px solid var(--border);
      background: var(--surface);
      color: var(--muted);
      padding: 0.32rem 0.68rem;
      border-radius: 999px;
      font-size: 0.8rem;
      font-weight: 500;
      cursor: pointer;
    }}
    .chip.active {{
      background: var(--accent);
      border-color: var(--accent);
      color: #ffffff;
    }}

    .table-wrap {{ overflow-x: auto; }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 0.88rem;
    }}
    th, td {{
      padding: 0.65rem 0.85rem;
      border-bottom: 1px solid var(--border);
      text-align: left;
    }}
    th {{
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      color: var(--muted);
      background: var(--surface);
    }}
    th.tc, td.tc {{ text-align: center; }}
    tr.row-gap {{ background: rgba(180, 83, 9, 0.04); }}
    .num {{
      display: inline-block;
      min-width: 1.6rem;
      font-weight: 700;
    }}
    .num-zero {{ color: var(--muted); font-weight: 400; opacity: 0.65; }}
    .num-ok {{ color: var(--text); }}
    .muted {{ color: var(--muted); }}

    .golden-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 1rem;
    }}
    .golden-card {{
      margin: 0;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      overflow: hidden;
      box-shadow: var(--shadow);
      display: flex;
      flex-direction: column;
    }}
    .golden-thumb-btn {{
      border: 0;
      padding: 0;
      background: var(--surface-2);
      cursor: pointer;
      aspect-ratio: 9 / 16;
      max-height: 280px;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
    }}
    .golden-card[data-category="desktop"] .golden-thumb-btn {{
      aspect-ratio: 16 / 10;
    }}
    .golden-thumb-btn img {{
      width: 100%;
      height: 100%;
      object-fit: cover;
      object-position: top;
      display: block;
    }}
    .golden-card figcaption {{
      padding: 0.7rem 0.85rem;
      border-top: 1px solid var(--border);
    }}
    .golden-title {{ font-weight: 600; font-size: 0.9rem; }}
    .golden-sub {{ font-size: 0.76rem; color: var(--muted); margin-top: 0.15rem; }}
    .golden-tags {{ display: flex; flex-wrap: wrap; gap: 0.3rem; margin-top: 0.45rem; }}
    .chip-tag {{
      font-size: 0.72rem;
      background: var(--surface-2);
      color: var(--muted);
      padding: 0.1rem 0.45rem;
      border-radius: 6px;
    }}
    .chip-tag.chip-cat {{
      background: var(--accent-soft);
      color: var(--accent);
      font-weight: 600;
    }}
    .chip-link {{
      border: 0;
      cursor: pointer;
    }}
    .chip-link:hover {{
      background: var(--accent-soft);
      color: var(--accent);
    }}
    .risk-card {{
      justify-content: space-between;
    }}
    .risk-subchips {{
      display: flex;
      flex-wrap: wrap;
      gap: 0.35rem;
      margin-top: 0.15rem;
    }}
    .risk-foot {{
      margin-top: auto;
      padding-top: 0.65rem;
      border-top: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 0.5rem;
      font-size: 0.8rem;
    }}
    .btn-sm {{
      padding: 0.28rem 0.6rem;
      font-size: 0.78rem;
    }}
    .risk-mini-wrap {{
      display: flex;
      flex-wrap: wrap;
      gap: 0.25rem;
    }}
    .risk-mini {{
      font-size: 0.7rem;
      padding: 0.1rem 0.42rem;
      border-radius: 999px;
      font-weight: 600;
      white-space: nowrap;
    }}
    .risk-mini-on {{
      background: var(--pass-bg);
      color: var(--pass);
    }}
    .risk-mini-off {{
      background: var(--surface-2);
      color: var(--muted);
      opacity: 0.45;
    }}

    .explorer-list {{ divide-y: 1px solid var(--border); }}
    .file-row {{
      border-bottom: 1px solid var(--border);
    }}
    .file-row:last-child {{ border-bottom: 0; }}
    .file-summary {{
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      justify-content: space-between;
      gap: 0.6rem;
      padding: 0.7rem 1rem;
      cursor: pointer;
      list-style: none;
    }}
    .file-summary:hover {{ background: var(--surface-2); }}
    .file-summary::-webkit-details-marker {{ display: none; }}
    .file-left {{
      display: flex;
      align-items: center;
      gap: 0.55rem;
      flex-wrap: wrap;
      min-width: 0;
    }}
    .file-path {{
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 0.84rem;
      font-weight: 600;
      word-break: break-all;
    }}
    .file-right {{
      display: flex;
      align-items: center;
      gap: 0.45rem;
      flex-wrap: wrap;
    }}
    .case-list {{
      margin: 0;
      padding: 0.25rem 1rem 0.85rem 2.2rem;
      list-style: none;
      display: grid;
      gap: 0.35rem;
    }}
    .case-item {{
      display: flex;
      flex-wrap: wrap;
      align-items: baseline;
      justify-content: space-between;
      gap: 0.5rem;
      padding: 0.35rem 0.6rem;
      border-radius: 8px;
      background: var(--surface-2);
      font-size: 0.84rem;
    }}
    .case-item.status-failed {{
      background: var(--fail-bg);
      border: 1px solid rgba(185, 28, 28, 0.25);
    }}
    .case-error {{
      width: 100%;
      margin: 0.3rem 0 0;
      padding: 0.45rem 0.6rem;
      background: rgba(0, 0, 0, 0.08);
      border-radius: 6px;
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 0.76rem;
      white-space: pre-wrap;
      overflow-x: auto;
    }}
    .result-warning {{
      margin: 0 0 1rem;
      padding: 0.75rem 1rem;
      border-radius: var(--radius);
      background: var(--warn-bg);
      color: var(--warn);
      font-weight: 600;
    }}
    .empty-note {{
      padding: 1.5rem;
      text-align: center;
      color: var(--muted);
      margin: 0;
    }}

    dialog.modal {{
      border: 1px solid var(--border);
      border-radius: var(--radius);
      background: var(--surface);
      color: var(--text);
      max-width: 92vw;
      max-height: 92vh;
      padding: 0;
      box-shadow: 0 24px 60px rgba(0, 0, 0, 0.45);
    }}
    dialog.modal::backdrop {{ background: rgba(15, 23, 42, 0.7); }}
    .modal-head {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 0.75rem 1rem;
      border-bottom: 1px solid var(--border);
    }}
    .modal-body {{
      padding: 1rem;
      overflow: auto;
      max-height: calc(92vh - 60px);
      text-align: center;
    }}
    .modal-body img {{
      max-width: 100%;
      height: auto;
      border-radius: 8px;
      border: 1px solid var(--border);
    }}
  </style>
</head>
<body>
  <div class="container">
    <header class="topbar">
      <div>
        <h1>Attendix · Test- &amp; Qualitäts-Dashboard</h1>
        <div class="subtitle">
          Generiert am {html.escape(report.generated_at)}
          {(' · Quellen: ' + html.escape(', '.join(report.result_files))) if report.result_files else ''}
        </div>
      </div>
      <div class="topbar-actions">
        {status_badge}
        <button type="button" class="btn" id="themeToggle" onclick="toggleTheme()">🌙 Design wechseln</button>
      </div>
    </header>
    {warnings_html}

    <section class="kpi-grid" aria-label="Kennzahlen">
      <div class="kpi-card">
        <div class="kpi-label">Testdateien</div>
        <div class="kpi-value">{t['all_files']}</div>
        <div class="kpi-sub">{t['flutter_files']} Flutter · {t['patrol_files']} Patrol · {t['tool_files']} Tooling</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">Testfälle</div>
        <div class="kpi-value">{t['all_cases']}</div>
        <div class="kpi-sub">{t['flutter_cases']} Unit/Widget/Golden · {t['patrol_flows']} E2E · {t['tool_cases']} Tool</div>
      </div>
      <div class="kpi-card {status_card_tone}">
        <div class="kpi-label">Testergebnis</div>
        <div class="kpi-value">{html.escape(status_card_value)}</div>
        <div class="kpi-sub">{html.escape(status_card_sub)}</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">Golden-Screenshots</div>
        <div class="kpi-value">{t['goldens']}</div>
        <div class="kpi-sub">Referenzbilder in test/golden/goldens/</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">Feature-Abdeckung</div>
        <div class="kpi-value">{t['features_covered']} / {t['features_total']}</div>
        <div class="kpi-sub">Features in lib/features/ mit Tests</div>
      </div>
    </section>

    <section class="block">
      <h2>Wie &amp; was wird getestet?</h2>
      <p class="section-lead">
        Attendix prüft Qualität auf vier aufeinander abgestimmten Test-Schichten plus durchgängigen Patrol-E2E-Flows und Tooling-Checks.
      </p>
      <div class="layer-grid">
        {''.join(layer_cards_html)}
      </div>
    </section>

    <section class="block" id="riskSection">
      <h2>Bug-Risikoklassen-Abdeckung (&bdquo;Welche echten Fehlerklassen fangen wir ab?&ldquo;)</h2>
      <p class="section-lead">
        Jeder Test zahlt auf eine oder mehrere reale Fehlerklassen ein. Klicke auf eine Risikoklasse, um passende Tests direkt im Explorer zu filtern.
      </p>
      <div class="layer-grid">
        {''.join(risk_cards_html)}
      </div>
    </section>

    <section class="block">
      <h2>Feature-Abdeckungsmatrix (<code>lib/features/*</code>)</h2>
      <p class="section-lead">
        Zeigt pro Fachbereich Unit-/Widget-Tests, UI-Guards, Golden-Screenshots, Patrol-E2E-Flows und abgedeckte Bug-Risikoklassen.
      </p>
      <div class="panel">
        <div class="panel-toolbar">
          <input type="search" id="featureSearch" class="input" placeholder="Feature filtern (z. B. attendance, songs)…" oninput="filterMatrix()" />
          <div style="display:flex;flex-wrap:wrap;gap:0.5rem;align-items:center;">
            <select id="matrixMissingRisk" class="input" style="min-width:190px;" onchange="filterMatrix()" aria-label="Fehlende Risikoklasse filtern">
              <option value="all">Alle Risikoklassen</option>
              <option value="missing:layout">Fehlt: Layout &amp; Overflows</option>
              <option value="missing:visual">Fehlt: Visuelle Regression</option>
              <option value="missing:flows">Fehlt: Empty / Error / Rollen / Flows</option>
              <option value="missing:security">Fehlt: Multi-Tenant &amp; Security</option>
              <option value="missing:e2e">Fehlt: Echte E2E-Journeys</option>
            </select>
            <label class="chip" id="gapToggleWrap">
              <input type="checkbox" id="gapOnly" onchange="filterMatrix()" style="margin-right:0.35rem;vertical-align:middle;" />
              Nur Lücken (0 Signale)
            </label>
          </div>
        </div>
        <div class="table-wrap">
          <table id="matrixTable">
            <thead>
              <tr>
                <th>Feature</th>
                <th class="tc">Unit &amp; Widget</th>
                <th class="tc">UI-Guards</th>
                <th class="tc">Goldens</th>
                <th class="tc">Patrol E2E</th>
                <th>Risikoklassen</th>
                <th class="tc">Status</th>
              </tr>
            </thead>
            <tbody>
              {''.join(matrix_rows_html)}
            </tbody>
          </table>
        </div>
      </div>
    </section>

    <section class="block" id="goldenSection">
      <h2>Golden-Screenshot-Galerie</h2>
      <p class="section-lead">
        Klicke auf einen Screenshot für die Vollansicht oder filtere nach Kategorie.{' Eingebettet als standalone Data-URIs.' if report.goldens and report.goldens[0].data_uri else ''}
      </p>
      <div class="panel" style="margin-bottom:1rem;">
        <div class="panel-toolbar">
          <div class="chips" id="goldenCategoryChips">
            {''.join(golden_category_chips_html)}
          </div>
          <span id="goldenCount" class="muted" style="font-size:0.82rem;">{len(report.goldens)} von {len(report.goldens)} Screenshots angezeigt</span>
        </div>
      </div>
      <div class="golden-grid" id="goldenGrid">
        {''.join(golden_cards_html)}
      </div>
    </section>

    <section class="block" id="explorerSection">
      <h2>Interaktiver Test-Explorer</h2>
      <p class="section-lead">
        Durchsuche Dateien, Features, Bug-Risikoklassen und einzelne Testfälle. Klicke auf eine Datei, um alle enthaltenen Tests anzuzeigen.
      </p>
      <div class="panel">
        <div class="panel-toolbar">
          <input type="search" id="explorerSearch" class="input" placeholder="Datei, Feature oder Testtitel suchen…" oninput="renderExplorer()" />
          <div class="chips" id="layerChips">
            <button type="button" class="chip active" data-layer="all" onclick="setLayer('all')">Alle Schichten</button>
            <button type="button" class="chip" data-layer="ui" onclick="setLayer('ui')">UI-Guards</button>
            <button type="button" class="chip" data-layer="golden" onclick="setLayer('golden')">Goldens</button>
            <button type="button" class="chip" data-layer="features" onclick="setLayer('features')">Features &amp; Shared</button>
            <button type="button" class="chip" data-layer="core" onclick="setLayer('core')">Core, Data &amp; Security</button>
            <button type="button" class="chip" data-layer="patrol" onclick="setLayer('patrol')">Patrol E2E</button>
            <button type="button" class="chip" data-layer="tool" onclick="setLayer('tool')">Tool-Tests</button>
          </div>
          <div class="chips" id="riskChips">
            <button type="button" class="chip active" data-risk="all" onclick="setRisk('all')">Alle Risiken</button>
            <button type="button" class="chip" data-risk="layout" onclick="setRisk('layout')">Layout &amp; Overflows</button>
            <button type="button" class="chip" data-risk="visual" onclick="setRisk('visual')">Visuelle Regression</button>
            <button type="button" class="chip" data-risk="flows" onclick="setRisk('flows')">Empty / Error / Rollen / Flows</button>
            <button type="button" class="chip" data-risk="security" onclick="setRisk('security')">Multi-Tenant &amp; Security</button>
            <button type="button" class="chip" data-risk="e2e" onclick="setRisk('e2e')">Echte E2E-Journeys</button>
          </div>
          <div class="chips" id="statusChips">
            <button type="button" class="chip active" data-status="all" onclick="setStatus('all')">Alle Status</button>
            <button type="button" class="chip" data-status="passed" onclick="setStatus('passed')">Bestanden</button>
            <button type="button" class="chip" data-status="failed" onclick="setStatus('failed')">Fehlgeschlagen</button>
            <button type="button" class="chip" data-status="skipped" onclick="setStatus('skipped')">Übersprungen</button>
            <button type="button" class="chip" data-status="unrun" onclick="setStatus('unrun')">Ohne Lauf</button>
          </div>
          <div class="chips">
            <button type="button" class="btn" onclick="toggleAllDetails(true)">Alle aufklappen</button>
            <button type="button" class="btn" onclick="toggleAllDetails(false)">Alle zuklappen</button>
          </div>
        </div>
        <div id="explorerCount" style="padding:0.55rem 1rem;font-size:0.82rem;color:var(--muted);border-bottom:1px solid var(--border);"></div>
        <div id="explorerList" class="explorer-list"></div>
      </div>
    </section>
  </div>

  <dialog id="goldenModal" class="modal">
    <div class="modal-head">
      <div>
        <strong id="modalTitle"></strong>
        <div id="modalMeta" class="muted" style="font-size:0.8rem;"></div>
      </div>
      <button type="button" class="btn" onclick="document.getElementById('goldenModal').close()">Schließen</button>
    </div>
    <div class="modal-body">
      <img id="modalImg" src="" alt="" />
    </div>
  </dialog>

  <script>
    const TEST_FILES = {explorer_json};
    let activeLayer = 'all';
    let activeRisk = 'all';
    let activeStatus = 'all';
    let activeGoldenCategory = 'all';

    function escapeHtml(str) {{
      return String(str ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
    }}

    function fmtMs(ms) {{
      if (ms === null || ms === undefined) return '—';
      if (ms < 1000) return ms + ' ms';
      const s = ms / 1000;
      if (s < 60) return s.toFixed(1) + ' s';
      return Math.floor(s / 60) + 'm ' + Math.round(s % 60) + 's';
    }}

    function toggleTheme() {{
      const root = document.documentElement;
      const cur = root.getAttribute('data-theme');
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      const next = cur ? (cur === 'dark' ? 'light' : 'dark') : (prefersDark ? 'light' : 'dark');
      root.setAttribute('data-theme', next);
    }}

    function openGoldenModal(btn) {{
      const dlg = document.getElementById('goldenModal');
      document.getElementById('modalTitle').textContent = btn.dataset.title || '';
      document.getElementById('modalMeta').textContent = btn.dataset.meta || '';
      const img = document.getElementById('modalImg');
      img.src = btn.dataset.src || '';
      img.alt = btn.dataset.title || '';
      dlg.showModal();
    }}

    function setGoldenCategory(cat) {{
      activeGoldenCategory = cat;
      document.querySelectorAll('#goldenCategoryChips .chip').forEach((c) => {{
        c.classList.toggle('active', c.dataset.goldenCat === cat);
      }});
      const cards = document.querySelectorAll('#goldenGrid .golden-card');
      let shown = 0;
      cards.forEach((card) => {{
        const visible = cat === 'all' || card.dataset.category === cat;
        card.style.display = visible ? '' : 'none';
        if (visible) shown += 1;
      }});
      const countEl = document.getElementById('goldenCount');
      if (countEl) {{
        countEl.textContent = shown + ' von ' + cards.length + ' Screenshots angezeigt';
      }}
    }}

    function focusGoldenCategory(cat) {{
      setGoldenCategory(cat);
      const section = document.getElementById('goldenSection');
      if (section) section.scrollIntoView({{ behavior: 'smooth', block: 'start' }});
    }}

    function filterMatrix() {{
      const q = (document.getElementById('featureSearch').value || '').trim().toLowerCase();
      const gapOnly = document.getElementById('gapOnly').checked;
      const riskFilterEl = document.getElementById('matrixMissingRisk');
      const riskFilter = riskFilterEl ? riskFilterEl.value : 'all';
      const rows = document.querySelectorAll('#matrixTable tbody tr');
      rows.forEach((tr) => {{
        const feat = (tr.dataset.feature || '').toLowerCase();
        const isGap = tr.dataset.gap === '1';
        const risks = (tr.dataset.risks || '').split(',').filter(Boolean);
        let riskOk = true;
        if (riskFilter.startsWith('missing:')) {{
          const target = riskFilter.slice('missing:'.length);
          riskOk = !risks.includes(target);
        }}
        const visible = (!q || feat.includes(q)) && (!gapOnly || isGap) && riskOk;
        tr.style.display = visible ? '' : 'none';
      }});
    }}

    function setLayer(layer) {{
      activeLayer = layer;
      document.querySelectorAll('#layerChips .chip').forEach((c) => {{
        c.classList.toggle('active', c.dataset.layer === layer);
      }});
      renderExplorer();
    }}

    function setRisk(risk) {{
      activeRisk = risk;
      document.querySelectorAll('#riskChips .chip').forEach((c) => {{
        c.classList.toggle('active', c.dataset.risk === risk);
      }});
      renderExplorer();
    }}

    function focusRisk(risk) {{
      setLayer('all');
      setRisk(risk);
      const section = document.getElementById('explorerSection');
      if (section) section.scrollIntoView({{ behavior: 'smooth', block: 'start' }});
    }}

    function setStatus(status) {{
      activeStatus = status;
      document.querySelectorAll('#statusChips .chip').forEach((c) => {{
        c.classList.toggle('active', c.dataset.status === status);
      }});
      renderExplorer();
    }}

    function toggleAllDetails(open) {{
      document.querySelectorAll('#explorerList details.file-row').forEach((d) => {{
        d.open = open;
      }});
    }}

    function statusPill(status) {{
      if (status === 'passed') return '<span class="pill pill-pass">Bestanden</span>';
      if (status === 'failed') return '<span class="pill pill-fail">Fehlgeschlagen</span>';
      if (status === 'skipped') return '<span class="pill pill-muted">Übersprungen</span>';
      return '<span class="pill pill-info">Statisch</span>';
    }}

    function renderExplorer() {{
      const q = (document.getElementById('explorerSearch').value || '').trim().toLowerCase();
      const list = document.getElementById('explorerList');
      const countEl = document.getElementById('explorerCount');

      const matchedFiles = [];
      let totalMatchedCases = 0;

      for (const file of TEST_FILES) {{
        if (activeLayer !== 'all' && file.layer !== activeLayer) continue;
        if (activeRisk !== 'all' && !(file.riskClasses || []).includes(activeRisk)) continue;

        const fileMatchesQuery =
          !q ||
          file.path.toLowerCase().includes(q) ||
          file.features.some((ft) => ft.toLowerCase().includes(q)) ||
          (file.riskLabels || []).some((rl) => rl.toLowerCase().includes(q));

        const visibleCases = file.cases.filter((c) => {{
          const statusOk = activeStatus === 'all' || c.status === activeStatus;
          const queryOk = fileMatchesQuery || c.name.toLowerCase().includes(q);
          return statusOk && queryOk;
        }});

        if (visibleCases.length === 0) {{
          if (!(fileMatchesQuery && activeStatus === 'all' && file.cases.length === 0)) {{
            continue;
          }}
        }}
        matchedFiles.push({{ file, visibleCases }});
        totalMatchedCases += visibleCases.length;
      }}

      countEl.textContent = matchedFiles.length + ' Dateien · ' + totalMatchedCases + ' Testfälle angezeigt';

      if (matchedFiles.length === 0) {{
        list.innerHTML = '<p class="empty-note">Keine passenden Tests für diese Filterauswahl gefunden.</p>';
        return;
      }}

      const htmlParts = matchedFiles.map(({{ file, visibleCases }}) => {{
        const openAttr = file.failed > 0 || (q && visibleCases.length > 0 && matchedFiles.length <= 12) ? ' open' : '';
        const riskChips = (file.riskLabels || [])
          .map((rl) => '<span class="chip-tag chip-cat">' + escapeHtml(rl) + '</span>')
          .join('');
        const featChips = file.features
          .map((ft) => '<span class="chip-tag">' + escapeHtml(ft) + '</span>')
          .join('');
        let rightBadges = '';
        if (file.hasLive) {{
          if (file.passed) rightBadges += '<span class="pill pill-pass">' + file.passed + ' OK</span>';
          if (file.failed) rightBadges += '<span class="pill pill-fail">' + file.failed + ' Fail</span>';
          if (file.skipped) rightBadges += '<span class="pill pill-muted">' + file.skipped + ' Skip</span>';
          rightBadges += '<span class="pill pill-muted">' + fmtMs(file.durationMs) + '</span>';
        }} else {{
          rightBadges += '<span class="pill pill-muted">' + file.cases.length + ' Tests</span>';
        }}

        const casesHtml = visibleCases.map((c) => {{
          const tags = (c.tags || []).map((tg) => '<span class="chip-tag">' + escapeHtml(tg) + '</span>').join('');
          const lineInfo = c.line ? '<span class="muted">:' + c.line + '</span>' : '';
          const dur = c.durationMs !== null && c.durationMs !== undefined ? '<span class="muted">' + fmtMs(c.durationMs) + '</span>' : '';
          const err = c.error ? '<pre class="case-error">' + escapeHtml(c.error) + '</pre>' : '';
          return (
            '<li class="case-item status-' + escapeHtml(c.status) + '">' +
              '<div><strong>' + escapeHtml(c.name) + '</strong> ' + lineInfo + ' ' + tags + '</div>' +
              '<div style="display:flex;align-items:center;gap:0.45rem;">' + dur + statusPill(c.status) + '</div>' +
              err +
            '</li>'
          );
        }}).join('');

        return (
          '<details class="file-row"' + openAttr + '>' +
            '<summary class="file-summary">' +
              '<div class="file-left">' +
                '<span class="pill pill-info">' + escapeHtml(file.layerLabel) + '</span>' +
                '<span class="file-path">' + escapeHtml(file.path) + '</span>' +
                riskChips + featChips +
              '</div>' +
              '<div class="file-right">' + rightBadges + '</div>' +
            '</summary>' +
            '<ul class="case-list">' + (casesHtml || '<li class="muted">Keine einzelnen Testfälle extrahiert.</li>') + '</ul>' +
          '</details>'
        );
      }});

      list.innerHTML = htmlParts.join('');
    }}

    renderExplorer();
  </script>
</body>
</html>
"""


def open_in_browser(path: Path) -> None:
    """Opens the generated HTML file in the OS default browser."""
    resolved = str(path.resolve())
    system = platform.system().lower()
    if system == "darwin":
        subprocess.run(["open", resolved], check=False)
    elif system == "windows":
        os.startfile(resolved)  # type: ignore[attr-defined]
    else:
        subprocess.run(["xdg-open", resolved], check=False)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generates Attendix HTML & Markdown Test & Quality Dashboard."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Repository root directory (defaults to repo root).",
    )
    parser.add_argument(
        "--results",
        nargs="+",
        default=[],
        help="One or more `flutter test --file-reporter json:<path>` NDJSON files or directories.",
    )
    parser.add_argument(
        "--html",
        type=Path,
        default=Path("build/test-dashboard/index.html"),
        help="Output path for self-contained HTML dashboard.",
    )
    parser.add_argument(
        "--embed-goldens",
        action="store_true",
        help="Embed golden PNG screenshots as base64 data URIs inside the HTML.",
    )
    parser.add_argument(
        "--markdown",
        type=Path,
        default=None,
        help="Optional output path for GitHub-Flavored Markdown summary.",
    )
    parser.add_argument(
        "--expected-results",
        type=int,
        default=None,
        metavar="N",
        help=(
            "Number of result files that should exist (e.g. 4 CI shards). "
            "Fewer readable files are reported as a warning in HTML & Markdown."
        ),
    )
    parser.add_argument(
        "--open",
        action="store_true",
        help="Open generated HTML dashboard in the default browser.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    repo_root = args.root.resolve()
    html_out = args.html if args.html.is_absolute() else (repo_root / args.html)

    report = scan_repository(
        repo_root=repo_root,
        result_paths=args.results,
        embed_goldens=args.embed_goldens,
        expected_results=args.expected_results,
    )

    html_out.parent.mkdir(parents=True, exist_ok=True)
    html_out.write_text(render_html(report, html_out), encoding="utf-8")
    print(f"Dashboard HTML written to {html_out}")

    if args.markdown is not None and str(args.markdown) in ("", "."):
        # e.g. `--markdown "$GITHUB_STEP_SUMMARY"` outside GitHub Actions.
        print("Markdown summary skipped: empty --markdown path", file=sys.stderr)
    elif args.markdown is not None:
        md_out = (
            args.markdown
            if args.markdown.is_absolute()
            else (repo_root / args.markdown)
        )
        md_out.parent.mkdir(parents=True, exist_ok=True)
        md_out.write_text(render_markdown(report), encoding="utf-8")
        print(f"Markdown summary written to {md_out}")

    if args.open:
        open_in_browser(html_out)

    return 0


if __name__ == "__main__":
    sys.exit(main())
