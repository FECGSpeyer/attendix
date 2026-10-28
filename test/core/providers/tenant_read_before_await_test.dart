// SOL_FIX4: a notifier must read its tenant-bound repositories BEFORE the
// first `await` of a method. Reading `xxxRepositoryWithTenantProvider` (or a
// `_repo` getter that reads it) after an await resolves the repository of
// whatever tenant is current *then* — a tenant switch A→B mid-flow would run
// the second half of the operation in tenant B.
//
// Deliberate re-reads (e.g. after an intended tenant switch) are marked with
// a `tenant-read-after-await` comment on the line before.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// `ref\n    .read(...)` (formatter line breaks) counts as well.
final _readRepo =
    RegExp(r'ref\s*\.read\(\s*\w+RepositoryWithTenantProvider');
final _getter = RegExp(
    r'get\s+(\w+)\s*=>\s*_?ref\.read\(\s*\w+Repository(?:WithTenant|ForTenant)Provider');
final _asyncBody = RegExp(r'\)\s*async\s*\{');

/// Returns `file:line: code` for each repository read after an await.
List<String> findReadsAfterAwait(String path, String source) {
  final violations = <String>[];
  final getters = _getter.allMatches(source).map((m) => m.group(1)!).toSet();
  final patterns = [
    _readRepo,
    for (final g in getters)
      RegExp('(?<![\\w.])${RegExp.escape(g)}\\b(?!\\s*=>)'),
  ];
  final lines = source.split('\n');

  for (final m in _asyncBody.allMatches(source)) {
    final start = m.end;
    var depth = 1;
    var i = start;
    while (depth > 0 && i < source.length) {
      final c = source[i];
      if (c == '{') depth++;
      if (c == '}') depth--;
      i++;
    }
    final body = source.substring(start, i);

    for (final p in patterns) {
      for (final r in p.allMatches(body)) {
        final pre = body.substring(0, r.start);
        // Ignore an await of the same statement (`await ref.read(..).x()`).
        final cut = [pre.lastIndexOf(';'), pre.lastIndexOf('{'), pre.lastIndexOf('}')]
            .reduce((a, b) => a > b ? a : b);
        final before = pre
            .substring(0, cut + 1)
            .replaceAll(RegExp(r'//[^\n]*'), '');
        if (!RegExp(r'\bawait\b').hasMatch(before)) continue;
        final line = '\n'.allMatches(source.substring(0, start + r.start)).length;
        final previous = line > 0 ? lines[line - 1] : '';
        final previous2 = line > 1 ? lines[line - 2] : '';
        if (previous.contains('tenant-read-after-await') ||
            previous2.contains('tenant-read-after-await')) {
          continue;
        }
        violations.add('$path:${line + 1}: ${lines[line].trim()}');
      }
    }
  }
  return violations;
}

void main() {
  group('Multi-Tenant Security: tenant repository read before await', () {
    test('scanner flags a read after an await', () {
      const bad = '''
class X {
  Foo get _repo => ref.read(fooRepositoryWithTenantProvider);
  Future<void> a() async {
    await _repo.one();
    await _repo.two();
  }
  Future<void> b() async {
    await something();
    await ref.read(barRepositoryWithTenantProvider).go();
  }
}
''';
      expect(findReadsAfterAwait('bad.dart', bad), hasLength(2));
    });

    test('scanner accepts hoisted reads and marked exceptions', () {
      const good = '''
class X {
  Foo get _repo => ref.read(fooRepositoryWithTenantProvider);
  Future<void> a() async {
    final repo = _repo;
    await repo.one();
    await repo.two();
  }
  Future<void> b() async {
    await ref.read(barRepositoryWithTenantProvider).go();
  }
  Future<void> c() async {
    await switchTenant();
    // tenant-read-after-await: intended
    final repo = ref.read(barRepositoryWithTenantProvider);
  }
}
''';
      expect(findReadsAfterAwait('good.dart', good), isEmpty);
    });

    test('no notifier in lib/core/providers reads a tenant repository after an await', () {
      final files = Directory('lib/core/providers')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final violations = <String>[
        for (final f in files)
          ...findReadsAfterAwait(f.path, f.readAsStringSync()),
      ];
      expect(violations, isEmpty,
          reason: 'Hoist the repository read before the first await:\n'
              '${violations.join('\n')}');
    });

    // UI_TENANT_HOIST: UI handlers (often after a confirmation dialog) must
    // capture their tenant-bound repositories before the first await, too.
    for (final dir in ['lib/features', 'lib/shared']) {
      test('no UI code in $dir reads a tenant repository after an await', () {
        final files = Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        final violations = <String>[
          for (final f in files)
            ...findReadsAfterAwait(f.path, f.readAsStringSync()),
        ];
        expect(violations, isEmpty,
            reason: 'Hoist the repository read before the first await:\n'
                '${violations.join('\n')}');
      });
    }

    test('approvePlayer binds player + registration repositories up front', () {
      final src =
          File('lib/core/providers/player_providers.dart').readAsStringSync();
      final approve = src.substring(src.indexOf('Future<void> approvePlayer('));
      final firstAwait = approve.indexOf('await ');
      expect(approve.indexOf('userRegistrationRepositoryWithTenantProvider'),
          inInclusiveRange(0, firstAwait));
      expect(src, contains('_notifyApproval(registration, player)'));
      expect(src, contains('_notifyReject(registration, player)'));
    });
  });
}
