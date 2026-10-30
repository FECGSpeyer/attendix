// Schema contract for every query in lib/: each table must exist and every
// literal column a query writes (insert/update/upsert map keys) or filters
// on (eq, order, inFilter, …) must be a column of that table.
//
// Unknown columns make PostgREST reject the whole statement (PGRST204 /
// 42703), which so far only showed up for users (telegramId,
// show_members_list). db_write_columns_test.dart checks the model-based
// writes; this test scans the source for the literal ones.
//
// Column lists: test/fixtures/db_columns.dart. Refresh after a schema change
// with `dart run tool/db/extract_db_columns.dart /path/to/ionic`.
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/db_columns.dart';

final _from = RegExp(r"\.from\(\s*(?:'(\w+)'|SupabaseTable\.(\w+)\.tableName)\s*\)");
final _write = RegExp(r'\.(insert|update|upsert)\(\s*\{');
final _filter = RegExp(
    r"\.(eq|neq|gt|gte|lt|lte|order|inFilter|isFilter|like|ilike|contains|not|is_)\(\s*'([\w.\->]+)'");

/// Top-level string keys of the map literal that opens at [open] (`{`).
List<String> _mapKeys(String s, int open) {
  final keys = <String>[];
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    final c = s[i];
    if (c == '{' || c == '[' || c == '(') {
      depth++;
    } else if (c == '}' || c == ']' || c == ')') {
      depth--;
      if (depth == 0) break;
    } else if (c == "'" || c == '"') {
      var j = i + 1;
      while (j < s.length && s[j] != c) {
        if (s[j] == r'\') j++;
        j++;
      }
      final literal = s.substring(i + 1, j);
      final after = s.substring(j + 1).trimLeft();
      if (depth == 1 && after.startsWith(':') && RegExp(r'^\w+$').hasMatch(literal)) {
        keys.add(literal);
      }
      i = j;
    }
  }
  return keys;
}

/// One finding: file:line, table and the offending column.
class _Finding {
  _Finding(this.where, this.table, this.what);
  final String where;
  final String table;
  final String what;
  @override
  String toString() => '$where  $table  $what';
}

List<_Finding> _scan() {
  final enumTables = {for (final t in SupabaseTable.values) t.name: t.tableName};
  final findings = <_Finding>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart') && !f.path.endsWith('.freezed.dart'));
  for (final f in files) {
    final s = f.readAsStringSync();
    for (final m in _from.allMatches(s)) {
      // Storage buckets use the same `.from('…')` call.
      final before = s.substring(m.start - 40 < 0 ? 0 : m.start - 40, m.start);
      if (before.contains('storage')) continue;
      final table = m.group(1) ?? enumTables[m.group(2)];
      final line = '\n'.allMatches(s.substring(0, m.start)).length + 1;
      final where = '${f.path}:$line';
      final cols = kDbColumns[table];
      if (table == null || cols == null) {
        findings.add(_Finding(where, table ?? m.group(0)!, 'unknown table'));
        continue;
      }
      final end = s.indexOf(';', m.end);
      final stmt = s.substring(m.end, end < 0 ? s.length : end);
      for (final w in _write.allMatches(stmt)) {
        for (final key in _mapKeys(stmt, w.end - 1)) {
          if (!cols.contains(key)) findings.add(_Finding(where, table, '${w.group(1)} $key'));
        }
      }
      for (final w in _filter.allMatches(stmt)) {
        final col = w.group(2)!;
        // Embedded resources (`attendance.tenantId`) and JSON paths are
        // checked by PostgREST against the joined table.
        if (col.contains('.') || col.contains('->')) continue;
        if (!cols.contains(col)) findings.add(_Finding(where, table, '${w.group(1)} $col'));
      }
    }
  }
  return findings;
}

void main() {
  test('every table and literal column used in a query exists in the schema', () {
    final findings = _scan();
    expect(findings, isEmpty, reason: 'Not in test/fixtures/db_columns.dart:\n${findings.join('\n')}');
  });

  test('the scanner finds queries, write keys and filters', () {
    // Guards against a regex change that silently scans nothing.
    final s = "supabase.from('player').update({'firstName': a, 'x': {'y': 1}}).eq('id', 1).eq('tenantId', t);";
    expect(_mapKeys(s, s.indexOf('{')), ['firstName', 'x']);
    expect(_from.allMatches(s), hasLength(1));
    expect(_filter.allMatches(s).map((m) => m.group(2)), ['id', 'tenantId']);
  });
}
