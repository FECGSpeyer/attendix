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

// SOL_FIX7: method declarations (`Future<bool> name(...) {` / `=> ...;`).
final _methodDecl = RegExp(
    r'^[ \t]*(?:static\s+)?(?:[\w<>?,\[\] ]+?\s+)?(\w+)\s*\((?:[^()]|\([^()]*\))*\)\s*(?:async\s*)?(\{|=>)',
    multiLine: true);
const _notMethods = {'if', 'for', 'while', 'switch', 'catch', 'return', 'build'};

/// Extracts the body after [start] (just past `{`) up to the matching `}`.
String _braceBody(String source, int start) {
  var depth = 1;
  var i = start;
  while (depth > 0 && i < source.length) {
    final c = source[i];
    if (c == '{') depth++;
    if (c == '}') depth--;
    i++;
  }
  return source.substring(start, i);
}

RegExp _use(String name) => RegExp('(?<![\\w.])${RegExp.escape(name)}\\b(?!\\s*=>)');

/// SOL_FIX7: names of helper methods that (transitively) read a tenant
/// repository from its provider. Calling one of them after an await is the
/// same bug as reading the provider directly (e.g. `saveBlockTemplates(..)`
/// called after `await ref.read(templatesProvider.future)`).
Set<String> findTenantHelpers(String source, Set<String> getters) {
  final bodies = <String, String>{};
  for (final m in _methodDecl.allMatches(source)) {
    final name = m.group(1)!;
    if (_notMethods.contains(name) || getters.contains(name)) continue;
    final end = source.indexOf(';', m.end);
    final body = m.group(2) == '{'
        ? _braceBody(source, m.end)
        : source.substring(m.end, end < 0 ? source.length : end + 1);
    final code = body.replaceAll(RegExp(r'//[^\n]*'), '');
    bodies[name] = '${bodies[name] ?? ''}$code';
  }
  final helpers = <String>{};
  var changed = true;
  while (changed) {
    changed = false;
    final uses = [
      _readRepo,
      for (final g in getters) _use(g),
      for (final h in helpers) RegExp('(?<![\\w.])${RegExp.escape(h)}\\s*\\('),
    ];
    for (final e in bodies.entries) {
      if (helpers.contains(e.key)) continue;
      if (uses.any((p) => p.hasMatch(e.value))) {
        helpers.add(e.key);
        changed = true;
      }
    }
  }
  return helpers;
}

/// Returns `file:line: code` for each repository read after an await.
List<String> findReadsAfterAwait(String path, String source,
    {bool helpers = true}) {
  final violations = <String>[];
  final getters = _getter.allMatches(source).map((m) => m.group(1)!).toSet();
  final helperNames =
      helpers ? findTenantHelpers(source, getters) : const <String>{};
  final patterns = [
    _readRepo,
    for (final g in getters) _use(g),
    // A call of a helper method that reads the tenant repository itself.
    for (final h in helperNames) RegExp('(?<![\\w.])${RegExp.escape(h)}\\s*\\('),
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

    // SOL_FIX7: the read hidden in a helper method called after an await.
    test('scanner flags a tenant helper method called after an await', () {
      const bad = '''
class X {
  Future<bool> save(List<T> items) {
    return _run(() => ref.read(fooRepositoryWithTenantProvider).save(items));
  }
  Future<bool> saveOne(T item) async {
    final existing = await ref.read(itemsProvider.future);
    return save([...existing, item]);
  }
}
''';
      expect(findReadsAfterAwait('bad.dart', bad), hasLength(1));
    });

    test('scanner accepts a bound repository passed to a helper', () {
      const good = '''
class X {
  Future<bool> save(List<T> items) =>
      _saveWith(ref.read(fooRepositoryWithTenantProvider), items);
  Future<bool> _saveWith(FooRepository repo, List<T> items) {
    return _run(() => repo.save(items));
  }
  Future<bool> saveOne(T item) async {
    final repo = ref.read(fooRepositoryWithTenantProvider);
    final existing = await repo.getAll();
    return _saveWith(repo, [...existing, item]);
  }
}
''';
      expect(findReadsAfterAwait('good.dart', good), isEmpty);
    });

    // SOL_FIX7: notifiers and services are also checked for tenant helper
    // methods (and `_repo` getters) called after an await.
    for (final dir in ['lib/core/providers', 'lib/core/services']) {
      test('no notifier/service in $dir reads a tenant repository after an await', () {
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

    // UI_TENANT_HOIST: UI handlers (often after a confirmation dialog) must
    // capture their tenant-bound repositories before the first await, too.
    // (Direct reads and getters only; page-local helper methods are not
    // traced here.)
    for (final dir in ['lib/features', 'lib/shared']) {
      test('no UI code in $dir reads a tenant repository after an await', () {
        final files = Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        final violations = <String>[
          for (final f in files)
            ...findReadsAfterAwait(f.path, f.readAsStringSync(),
                helpers: false),
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
