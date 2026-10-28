import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Multi-Tenant Security tests for ProfileRepository and
/// NotificationSettingsRepository (source-code analysis).
///
/// - player: every select/update must filter tenantId AND appId (own data)
/// - tenant_group tables have no tenantId: scoped via the current tenant's
///   organisation id (resolved through tenant_group_tenants.tenant_id)
/// - attendance_types: filtered by tenant_id
void main() {
  late String profileSource;
  late String notificationSource;

  setUpAll(() {
    profileSource =
        File('lib/data/repositories/profile_repository.dart').readAsStringSync();
    notificationSource =
        File('lib/data/repositories/notification_settings_repository.dart')
            .readAsStringSync();
  });

  /// All query chains (from `.from('table')` to the end of the statement)
  List<String> queriesOn(String source, String table) {
    return RegExp("\\.from\\('$table'\\)[^;]*;", dotAll: true)
        .allMatches(source)
        .map((m) => m.group(0)!)
        .toList();
  }

  group('Multi-Tenant Security - ProfileRepository', () {
    test('uses TenantAwareRepository', () {
      expect(
          profileSource,
          matches(RegExp(
              r'extends BaseRepository\s+with TenantAwareRepository')));
    });

    test('all UPDATE operations on player filter tenantId and appId', () {
      final updates = queriesOn(profileSource, 'player')
          .where((q) => q.contains('.update('))
          .toList();
      expect(updates, isNotEmpty);
      for (final q in updates) {
        expect(q, contains(".eq('tenantId',"),
            reason: 'player update without tenantId filter:\n$q');
        expect(q, contains(".eq('appId', userId)"),
            reason: 'player update must be restricted to own rows:\n$q');
      }
    });

    test('current-tenant player queries use currentTenantId', () {
      final selects = queriesOn(profileSource, 'player')
          .where((q) => q.contains(".select('*')"))
          .toList();
      expect(selects, isNotEmpty);
      for (final q in selects) {
        expect(q, contains(".eq('tenantId', currentTenantId)"));
        expect(q, contains(".eq('appId', userId)"));
      }
    });

    test('cross-tenant player selects are restricted to own appId', () {
      for (final q in queriesOn(profileSource, 'player')) {
        expect(q, contains(".eq('appId', userId)"),
            reason: 'player query not restricted to own rows:\n$q');
      }
    });

    test('organisation lookup is scoped to the current tenant', () {
      for (final q in queriesOn(profileSource, 'tenant_group_tenants')) {
        expect(q, contains(".eq('tenant_id', currentTenantId)"));
      }
      for (final q in queriesOn(profileSource, 'tenants')) {
        expect(q, contains(".eq('id', currentTenantId)"));
      }
    });

    test('shared field values are scoped to organisation and person key', () {
      final selects = queriesOn(profileSource, 'tenant_group_person_fields')
          .where((q) => q.contains('.select('));
      for (final q in selects) {
        expect(q, contains(".eq('tenant_group', organisationId)"));
        expect(q, contains(".eq('person_key', personKey)"));
      }
    });

    test('all operations use handleError', () {
      final catches = RegExp(r'catch \(e, stack\)').allMatches(profileSource);
      final handles = RegExp(r'handleError\(e, stack,').allMatches(profileSource);
      expect(handles.length, catches.length);
    });
  });

  group('Multi-Tenant Security - NotificationSettingsRepository', () {
    test('attendance_types query filters tenant_id', () {
      final queries = queriesOn(notificationSource, 'attendance_types');
      expect(queries, isNotEmpty);
      for (final q in queries) {
        expect(q, contains(".eq('tenant_id', currentTenantId)"));
      }
    });
  });
}
