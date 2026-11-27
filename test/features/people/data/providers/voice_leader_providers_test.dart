import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-grep regression test for the voice_leader provider migration.
///
/// Sprint 2a Task 3 moved the three voice_leader providers off the raw
/// `supabaseClientProvider` and onto `*WithTenantProvider` repositories.
/// This test pins those decisions so the file cannot silently regress.
void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/people/data/providers/voice_leader_providers.dart',
    ).readAsStringSync();
  });

  test('voice_leader_providers does not bypass repositories', () {
    expect(
      source,
      isNot(contains('supabaseClientProvider')),
      reason: 'voice_leader_providers must go through repositories, '
          'not raw supabaseClientProvider',
    );
  });

  test('voice_leader_providers does not force-unwrap tenant.id', () {
    expect(
      source,
      isNot(contains('tenant.id!')),
      reason: 'Tenant guarding belongs in the *WithTenantProvider via '
          'repo.hasTenantId; tenant.id! is unsafe',
    );
  });

  test('voice_leader_providers uses the tenant-aware repositories', () {
    expect(source, contains('playerRepositoryWithTenantProvider'));
    expect(source, contains('groupRepositoryWithTenantProvider'));
    expect(source, contains('attendanceRepositoryWithTenantProvider'));
  });
}
