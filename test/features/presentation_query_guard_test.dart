// Database access belongs in lib/data/repositories (tenant filter, error
// reporting, demo guard in one place). This test keeps new direct Supabase
// table queries out of the presentation code under lib/features and
// lib/shared. Storage bucket calls (`storage.from(...)`) are not queries.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files that still query tables directly, with the reason. Shrink this
/// list when a flow moves into a repository; never grow it without one.
const _allowed = <String, String>{
  // Cross-tenant: reads and writes in another instance than the current one.
  'lib/features/shifts/presentation/widgets/copy_shift_to_tenant_sheet.dart': 'cross-tenant copy',
  'lib/features/songs/presentation/widgets/copy_to_tenant_sheet.dart': 'cross-tenant copy',
  'lib/features/people/presentation/widgets/person_detail/andere_instanzen_accordion.dart':
      'person in other instances',
  'lib/features/self_service/data/providers/upcoming_songs_provider.dart': 'all instances of the user',
  // Public registration before a tenant is selected.
  'lib/features/registration/data/providers/registration_providers.dart': 'public registration',
  'lib/features/registration/presentation/pages/tenant_registration_page.dart': 'public registration',
  // Save bound to the client and tenant captured when the save started.
  'lib/features/attendance/presentation/attendance_create_writes.dart': 'captured save session',
  // The settings map stays a literal here so db_query_columns_test checks
  // every column it writes.
  'lib/features/settings/presentation/pages/general_settings_page.dart': 'schema-checked literal',
};

final _query = RegExp(r"\.from\(\s*(?:'\w+'|SupabaseTable\.\w+\.tableName)\s*\)");

List<String> _filesWithQueries() {
  final result = <String>[];
  for (final dir in ['lib/features', 'lib/shared']) {
    for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      final hasQuery = _query.allMatches(s).any((m) {
        final before = s.substring(m.start - 40 < 0 ? 0 : m.start - 40, m.start);
        return !before.contains('storage');
      });
      if (hasQuery) result.add(f.path.replaceAll(r'\', '/'));
    }
  }
  return result;
}

void main() {
  test('presentation code queries tables only through repositories', () {
    final offenders = _filesWithQueries().where((p) => !_allowed.containsKey(p)).toList();
    expect(offenders, isEmpty,
        reason: 'Move these queries into a repository in lib/data/repositories:\n'
            '${offenders.join('\n')}');
  });

  test('the allowlist has no stale entries', () {
    final files = _filesWithQueries().toSet();
    final stale = _allowed.keys.where((p) => !files.contains(p)).toList();
    expect(stale, isEmpty, reason: 'No direct queries left, remove from _allowed:\n${stale.join('\n')}');
  });
}
