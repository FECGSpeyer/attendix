import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Multi-Tenant Security source analysis for the PEOPLE2 package.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// Body of a method: from its signature up to the next method doc comment.
  String body(String source, String name) {
    final start = source.indexOf(RegExp('(Future<[^>]*>+|void|bool) _?$name\\('));
    expect(start, isNot(-1), reason: 'method $name not found');
    final next = source.indexOf('\n  ///', start + 1);
    return source.substring(start, next == -1 ? source.length : next);
  }

  group('Multi-Tenant Security - PlayerRepository (PEOPLE2)', () {
    late String source;
    setUpAll(() {
      source = read('lib/data/repositories/player_repository.dart');
    });

    test('savePlayerOrder filters by id and tenantId', () {
      final b = body(source, 'savePlayerOrder');
      expect(b, contains(".eq('id', entry.key)"));
      expect(b, contains(".eq('tenantId', currentTenantId)"));
    });

    test('getPossibleDuplicatesInTenant is tenant-scoped and account-less', () {
      final b = body(source, 'getPossibleDuplicatesInTenant');
      expect(b, contains(".eq('tenantId', currentTenantId)"));
      expect(b, contains(".isFilter('appId', null)"));
      expect(b, contains(".eq('pending', false)"));
    });

    test('merge verifies both rows belong to the current tenant', () {
      final b = body(source, 'mergePendingPlayerIntoExisting');
      expect(b, contains(".inFilter('id', [pendingId, targetId])"));
      expect(b, contains(".eq('tenant_id', currentTenantId)"));
      // update target + delete pending both filter by tenant
      expect(
        RegExp(r"\.eq\('tenantId', currentTenantId\)").allMatches(b).length,
        greaterThanOrEqualTo(4),
      );
    });

    test('pausePlayer forwards pauseFrom to the attendance removal', () {
      final b = body(source, 'pausePlayer');
      expect(b, contains('removeFromUpcomingAttendances(player.id!, from: pauseFrom)'));
    });

    test('attendance sync queries are tenant-scoped', () {
      for (final name in [
        'addPlayerToAttendancesByDate',
        'syncPlayerWithUpcomingAttendances',
      ]) {
        final b = body(source, name);
        // LOGIC_PEOPLE: addPlayerToAttendancesByDate can target the handover
        // tenant (`targetTenantId = tenantId ?? currentTenantId`).
        expect(
            b.contains(".eq('tenantId', currentTenantId)") ||
                (b.contains('tenantId ?? currentTenantId') &&
                    b.contains(".eq('tenantId', targetTenantId)")),
            isTrue,
            reason: '$name must filter attendances by tenant');
      }
      // LOGIC_PEOPLE: optional explicit tenant (handover target), defaulting
      // to the current tenant.
      expect(body(source, 'existingAttendanceIds'),
          contains(".eq('attendance.tenantId', tenantId ?? currentTenantId)"));
      expect(body(source, 'loadTypeFilters'),
          contains(".eq('tenant_id', tenantId ?? currentTenantId)"));
    });
  });

  group('Multi-Tenant Security - CrossTenantPersonRepository (PEOPLE2)', () {
    late String source;
    setUpAll(() {
      source = read('lib/data/repositories/cross_tenant_person_repository.dart');
    });

    test('other-tenant methods are guarded by the linked tenant ids', () {
      for (final name in [
        'getUserIdsInTenant',
        'getPersonIdFromTenant',
        'pausePlayerInOtherTenant',
      ]) {
        expect(body(source, name), contains('linkedTenantIds.contains(tenantId)'),
            reason: '$name must only touch linked tenants');
      }
    });

    test('getLinkedTenantsOfUser excludes the current tenant and viewers', () {
      final b = body(source, 'getLinkedTenantsOfUser');
      expect(b, contains('id != currentTenantId'));
      expect(b, contains(".neq('role', _viewerRole)"));
    });
  });
}
