// SOL_FIX15: every provider whose result depends on the signed-in account
// (its id, metadata, role or RLS-filtered rows) must depend on
// `currentAuthUserIdProvider` – directly or through another provider that
// does (e.g. the role, or a `*RepositoryWithTenantProvider`) – so an
// account switch A→B without a tenant change never keeps A's data.
//
// Best-effort source analysis: it builds the provider dependency graph of
// lib/ from the source text and fails for every provider that reads
// account data (Supabase client/auth, a raw repository) but cannot reach
// the account id.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Account-independent providers that read Supabase/auth on purpose.
/// Keep the reason – a new entry needs one too.
const _allowed = <String, String>{
  // Clients / services / repositories: no cached data of their own.
  'supabaseClientProvider': 'client',
  'supabaseAuthProvider': 'client',
  'currentAuthUserIdProvider': 'the account id itself',
  // Read at call time (functions), never cached.
  'offlineQueueUserIdProvider': 'callback read at call time',
  'offlineQueueSessionIdProvider': 'callback read at call time',
  'offlineQueueAuthEventsProvider': 'auth event stream',
  'offlineFlushFnProvider': 'replay callback; guarded per queued entry',
  // Global / public data, identical for every account.
  'churchesProvider': 'global church list',
  'legalContentProvider': 'public legal texts',
  'tenantByRegisterIdProvider': 'public registration lookup (anon)',
  'registrationGroupsProvider': 'public registration lookup (anon)',
  // The tenant selection itself: re-validated by the tenant flows.
  'currentTenantProvider': 'tenant selection (state, not a query cache)',
};

class _Decl {
  _Decl(this.name, this.file, this.source);
  final String name;
  final String file;
  final String source;
}

/// Index of the matching closing bracket for the opening one at [open].
int _matching(String s, int open) {
  const pairs = {'(': ')', '[': ']', '{': '}'};
  final stack = <String>[];
  var i = open;
  while (i < s.length) {
    final c = s[i];
    if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
      i = s.indexOf('\n', i);
      if (i == -1) return s.length;
      continue;
    }
    if (c == "'" || c == '"') {
      final triple = s.startsWith(c * 3, i);
      final end = triple ? s.indexOf(c * 3, i + 3) : _stringEnd(s, i, c);
      i = (end == -1 ? s.length : end) + (triple ? 3 : 1);
      continue;
    }
    if (pairs.containsKey(c)) {
      stack.add(pairs[c]!);
    } else if (stack.isNotEmpty && c == stack.last) {
      stack.removeLast();
      if (stack.isEmpty) return i;
    }
    i++;
  }
  return s.length;
}

int _stringEnd(String s, int start, String quote) {
  var i = start + 1;
  while (i < s.length) {
    if (s[i] == r'\') {
      i += 2;
      continue;
    }
    if (s[i] == quote || s[i] == '\n') return i;
    i++;
  }
  return -1;
}

/// End of the top-level statement starting at [start] (its `;`).
int _statementEnd(String s, int start) {
  var i = start;
  while (i < s.length) {
    final c = s[i];
    if (c == ';') return i;
    if (c == '(' || c == '[' || c == '{' || c == "'" || c == '"') {
      if (c == "'" || c == '"') {
        final end = _stringEnd(s, i, c);
        i = (end == -1 ? s.length : end) + 1;
        continue;
      }
      i = _matching(s, i) + 1;
      continue;
    }
    i++;
  }
  return s.length;
}

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.dart') &&
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('.freezed.dart'))
      .toList();

  final providers = <String, _Decl>{};
  final classes = <String, String>{};
  final functions = <String, String>{};
  final providerDecl = RegExp(r'^final (\w+Provider)\s*=', multiLine: true);
  final classDecl =
      RegExp(r'^(?:abstract |final |base )*class (\w+)[^{]*\{', multiLine: true);
  final functionDecl = RegExp(
      r'^(?!class |final |const |import |export |part |typedef |enum |extension |mixin |abstract |@)[A-Za-z_][\w<>?, ]*\s(_?\w+)\([^;{]*?\)\s*(?:async\s*)?\{',
      multiLine: true);

  for (final f in files) {
    final s = f.readAsStringSync();
    for (final m in providerDecl.allMatches(s)) {
      final end = _statementEnd(s, m.end);
      providers[m.group(1)!] = _Decl(m.group(1)!, f.path, s.substring(m.start, end));
    }
    for (final m in classDecl.allMatches(s)) {
      final end = _matching(s, m.end - 1);
      classes[m.group(1)!] = s.substring(m.start, end);
    }
    for (final m in functionDecl.allMatches(s)) {
      final end = _matching(s, m.end - 1);
      functions[m.group(1)!] = s.substring(m.start, end);
    }
  }

  final providerRef = RegExp(r'\b(\w+Provider)\b');
  final classUse = RegExp(r'\b([A-Z]\w+)(?:\.new\b|\()');
  final functionUse = RegExp(r'\b(_?[a-z]\w*)\(ref\b');

  /// Provider source plus its notifier class and helper functions.
  String expanded(_Decl d) {
    final buf = StringBuffer(d.source);
    for (final m in classUse.allMatches(d.source)) {
      final c = classes[m.group(1)];
      if (c != null) buf.write(c);
    }
    for (final m in functionUse.allMatches(buf.toString())) {
      final fn = functions[m.group(1)];
      if (fn != null) buf.write(fn);
    }
    return buf.toString();
  }

  final expandedSource = {
    for (final d in providers.values) d.name: expanded(d),
  };
  final deps = {
    for (final e in expandedSource.entries)
      e.key: providerRef
          .allMatches(e.value)
          .map((m) => m.group(1)!)
          .where((n) => n != e.key && providers.containsKey(n))
          .toSet(),
  };

  const roots = {
    'currentAuthUserIdProvider',
    'currentUserProvider',
    'authStateProvider',
    'currentSessionProvider',
  };
  final scoped = <String>{...roots};
  var changed = true;
  while (changed) {
    changed = false;
    for (final e in deps.entries) {
      if (!scoped.contains(e.key) && e.value.any(scoped.contains)) {
        scoped.add(e.key);
        changed = true;
      }
    }
  }

  /// Markers of account-dependent reads.
  final accountRead = RegExp(
    r'supabaseClientProvider|supabaseAuthProvider|Supabase\.instance'
    r'|currentUser\b|currentSession\b|userMetadata'
    r'|\b[a-z]\w*RepositoryProvider\b',
  );

  bool isInfrastructure(_Decl d) {
    final n = d.name;
    if (n.endsWith('RepositoryProvider') ||
        n.endsWith('ServiceProvider') ||
        n.endsWith('RepositoryForAccountProvider')) {
      return true;
    }
    // Mutation notifiers keep no data.
    if (RegExp(r'NotifierProvider(?:\.autoDispose)?<\w+,\s*(?:AsyncValue<void>|void)>')
        .hasMatch(d.source)) {
      return true;
    }
    return false;
  }

  test('the dependency graph was parsed', () {
    expect(providers.length, greaterThan(150));
    // Sanity: known account-scoped providers are detected as such.
    for (final n in [
      'currentRoleProvider',
      'agendaItemsProvider',
      'protocolsProvider',
      'teamTasksProvider',
      'playersProvider',
      'mySharedPlansProvider',
    ]) {
      expect(scoped, contains(n), reason: n);
    }
  });

  test('every provider reading account data depends on the account id', () {
    final missing = <String>[];
    for (final d in providers.values) {
      if (scoped.contains(d.name)) continue;
      if (_allowed.containsKey(d.name) || isInfrastructure(d)) continue;
      if (!accountRead.hasMatch(expandedSource[d.name]!)) continue;
      missing.add('${d.name} (${d.file})');
    }
    expect(missing, isEmpty,
        reason: 'ref.watch(currentAuthUserIdProvider) (or a provider that '
            'does) is missing in:\n${missing.join('\n')}');
  });

  test('every tenant repository instance follows the account', () {
    final family = RegExp(
        r'final (\w+RepositoryForTenantProvider) =[\s\S]*?\n\}\);');
    var count = 0;
    for (final f in files) {
      for (final m in family.allMatches(f.readAsStringSync())) {
        count++;
        expect(m.group(0), contains('ref.watch(currentAuthUserIdProvider)'),
            reason: '${m.group(1)} (${f.path})');
      }
    }
    expect(count, greaterThanOrEqualTo(33));
  });
}
