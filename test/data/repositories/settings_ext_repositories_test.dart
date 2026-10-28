import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Multi-Tenant Security tests (Source-Code-Analyse) für die SETTINGS_EXT-Repositories:
/// - RolePermissionRepository (tenant_role_permissions, Spalte tenant_id)
/// - FilesRepository (Storage-Bucket `files`, Präfix `<tenantId>/`)
/// - ExtraFieldsRepository (tenants / player / songs)
/// - OrganisationSettingsRepository (tenant_groups, player.global_person_id)
void main() {
  late String rolePermSource;
  late String filesSource;
  late String extraFieldsSource;
  late String orgSettingsSource;

  setUpAll(() {
    rolePermSource = File('lib/data/repositories/role_permission_repository.dart').readAsStringSync();
    filesSource = File('lib/data/repositories/files_repository.dart').readAsStringSync();
    extraFieldsSource = File('lib/data/repositories/extra_fields_repository.dart').readAsStringSync();
    orgSettingsSource = File('lib/data/repositories/organisation_settings_repository.dart').readAsStringSync();
  });

  group('Multi-Tenant Security - RolePermissionRepository', () {
    test('is tenant aware', () {
      expect(rolePermSource, contains('extends BaseRepository with TenantAwareRepository'));
    });

    test('all queries on tenant_role_permissions filter by tenant_id', () {
      final queries = RegExp(r"supabase[^;]*\.from\(table\)[^;]+", multiLine: true).allMatches(rolePermSource);
      expect(queries.length, greaterThanOrEqualTo(2));
      for (final m in queries) {
        expect(m.group(0), contains(".eq('tenant_id', currentTenantId)"),
            reason: 'Query ohne tenant_id-Filter:\n${m.group(0)}');
      }
    });

    test('UPDATE filters by id AND tenant_id', () {
      final update = RegExp(r"\.update\(permission\.toUpdatePayload\(\)\)[^;]+").firstMatch(rolePermSource);
      expect(update, isNotNull);
      expect(update!.group(0), contains(".eq('id', id)"));
      expect(update.group(0), contains(".eq('tenant_id', currentTenantId)"));
    });

    test('files_shared update only targets the current tenant', () {
      final update = RegExp(r"\.from\('tenants'\)[^;]+").firstMatch(rolePermSource);
      expect(update, isNotNull);
      expect(update!.group(0), contains(".eq('id', currentTenantId)"));
    });
  });

  group('Multi-Tenant Security - FilesRepository', () {
    test('is tenant aware', () {
      expect(filesSource, contains('extends BaseRepository with TenantAwareRepository'));
    });

    test('object keys are always prefixed with currentTenantId', () {
      expect(filesSource, contains(r"'$currentTenantId/$normalized'"));
      expect(filesSource, contains(r"'$currentTenantId'"));
    });

    test('no public method accepts a foreign tenant id', () {
      expect(filesSource.contains(RegExp(r'\(\s*int tenantId')), isFalse);
      expect(filesSource.contains(RegExp(r',\s*int tenantId')), isFalse);
    });

    test('move/remove assert own tenant prefix', () {
      expect(filesSource, contains('_assertOwnPrefix(oldKey)'));
      expect(filesSource, contains('_assertOwnPrefix(newKey)'));
      expect(filesSource, contains('_assertOwnPrefix(key)'));
    });

    test('usage RPC is called for the current tenant only', () {
      expect(filesSource, contains("rpc('files_used_bytes', params: {'p_tenant_id': currentTenantId})"));
    });
  });

  group('Multi-Tenant Security - ExtraFieldsRepository', () {
    test('tenants update targets current tenant', () {
      final update = RegExp(r"\.from\('tenants'\)\.update\([^;]+", multiLine: true).firstMatch(extraFieldsSource);
      expect(update, isNotNull);
      expect(update!.group(0), contains(".eq('id', currentTenantId)"));
    });

    test('player/songs SELECT filters tenantId', () {
      final select = RegExp(r"\.from\(table\)\s*\.select\([^;]+", multiLine: true).firstMatch(extraFieldsSource);
      expect(select, isNotNull);
      expect(select!.group(0), contains(".eq('tenantId', currentTenantId)"));
    });

    test('player/songs UPDATE filters id AND tenantId', () {
      final update = RegExp(r"\.from\(table\)\s*\.update\([^;]+", multiLine: true).firstMatch(extraFieldsSource);
      expect(update, isNotNull);
      expect(update!.group(0), contains(".eq('id', id)"));
      expect(update.group(0), contains(".eq('tenantId', currentTenantId)"));
    });
  });

  group('Multi-Tenant Security - OrganisationSettingsRepository', () {
    test('organisation is resolved from the current tenant', () {
      expect(orgSettingsSource, contains(".eq('tenant_id', currentTenantId)"));
    });

    test('no method accepts an organisation id from the caller', () {
      expect(orgSettingsSource.contains(RegExp(r'Future<[^>]+>\s+\w+\(\s*int org')), isFalse);
    });

    test('global_person_id update restricted to organisation tenants', () {
      final update = RegExp(r"\.from\('player'\)\s*\.update\([^;]+", multiLine: true).firstMatch(orgSettingsSource);
      expect(update, isNotNull);
      expect(update!.group(0), contains(".inFilter('tenantId', tenantIds)"));
      expect(orgSettingsSource, contains('tenantIds.contains(currentTenantId)'));
    });
  });
}
