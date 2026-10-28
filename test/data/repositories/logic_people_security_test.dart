import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// LOGIC_PEOPLE: source analysis for the people / account parity fixes
/// (Ionic db.service archivePlayer, removePlayer, removeUserFromTenant,
/// deleteViewer/Parent, handoverPerson, activatePlayer, addPlayer).
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// Body of a method: from its signature up to the next method doc comment.
  String body(String source, String name) {
    final start =
        source.indexOf(RegExp('(Future<[^>]*>+|void|bool) _?$name\\('));
    expect(start, isNot(-1), reason: 'method $name not found');
    final next = source.indexOf('\n  ///', start + 1);
    return source.substring(start, next == -1 ? source.length : next);
  }

  group('Multi-Tenant Security - LOGIC_PEOPLE PlayerRepository', () {
    late String source;
    setUpAll(() {
      source = read('lib/data/repositories/player_repository.dart');
    });

    test('removeUserFromTenant is tenant-scoped and keeps admins', () {
      final b = body(source, 'removeUserFromTenant');
      expect(
        RegExp(r"\.eq\('tenantId', currentTenantId\)").allMatches(b).length,
        greaterThanOrEqualTo(4),
      );
      expect(b, contains(".eq('role', Role.admin.value)"));
      // Access is kept while another active person uses the account
      expect(b, contains(".neq('id', personId)"));
      expect(b, contains(".isFilter('left', null)"));
    });

    test('archivePlayer revokes access and removes later Termine', () {
      final b = body(source, 'archivePlayer');
      expect(b, contains('removeUserFromTenant(appId, personId: player.id)'));
      expect(b, contains('removeFromUpcomingAttendances(player.id!, from: leftDate)'));
      expect(b, contains("if (clearAppId) 'appId': null"));
      expect(b, contains(".eq('tenantId', currentTenantId)"));
    });

    test('deletePlayer removes the tenantUsers row after deleting', () {
      final b = body(source, 'deletePlayer');
      expect(b, contains(".eq('tenantId', currentTenantId)"));
      expect(b, contains('removeUserFromTenant(appId, personId: playerId)'));
    });

    test('declinePlayer uses the guarded removeUserFromTenant', () {
      final b = body(source, 'declinePlayer');
      expect(b, contains('removeUserFromTenant(player.appId!, personId: player.id)'));
      expect(b, isNot(contains(".from('tenantUsers')")));
      expect(b, contains('Person abgelehnt von'));
    });

    test('approvePlayer backfills all Termine since the join date', () {
      final b = body(source, 'approvePlayer');
      expect(b, contains('addPlayerToAttendancesByDate(player)'));
      expect(b, contains('Person genehmigt von'));
    });

    test('unlinkAccount clears email and appId with guarded removal', () {
      final b = body(source, 'unlinkAccount');
      expect(b, contains("{'appId': null, 'email': null}"));
      expect(b, contains('removeUserFromTenant(appId, personId: player.id)'));
      expect(b, contains(".eq('tenantId', currentTenantId)"));
    });

    test('reactivatePlayer creates the account and adds upcoming Termine', () {
      final b = body(source, 'reactivatePlayer');
      expect(b, contains('createPlayerAccount('));
      expect(b, contains('Person wieder aktiviert'));
      expect(b, contains('addToUpcomingAttendances(person)'));
    });

    test('resetLateCount only sets lastSolve (no history)', () {
      final b = body(source, 'resetLateCount');
      expect(b, contains("'lastSolve'"));
      expect(b, isNot(contains("'history'")));
    });

    test('resolveCritical keeps criticalReason', () {
      final b = body(source, 'resolveCritical');
      expect(b, isNot(contains("'criticalReason': null")));
    });

    test('addToUpcomingAttendances applies extra field filter and shifts', () {
      final b = body(source, 'addToUpcomingAttendances');
      expect(b, contains(".eq('tenantId', currentTenantId)"));
      expect(b, contains('_matchesType('));
      expect(b, contains('peopleStatusByShift('));
      expect(b, contains('!type.allDay'));
    });

    test('updateShiftAssignmentsForPerson is tenant-scoped', () {
      final b = body(source, 'updateShiftAssignmentsForPerson');
      expect(b, contains(".eq('attendance.tenantId', currentTenantId)"));
      expect(b, contains(".eq('person_id', personId)"));
    });

    test('handoverPlayer creates the target before touching the source', () {
      final b = body(source, 'handoverPlayer');
      final insert = b.indexOf(".insert(newPlayerData)");
      final sourceUpdate = b.indexOf("'history': sourceHistory");
      expect(insert, isNot(-1));
      expect(sourceUpdate, greaterThan(insert));
      expect(b, contains("'appId': appId"));
      expect(b, contains('tenantId: targetTenantId'));
      expect(b, contains('addPlayerToAttendancesByDate(createdPerson'));
      // source keeps its account like Ionic
      expect(b, isNot(contains("'appId': null")));
    });

    test('playerExistsInTenant falls back to the name', () {
      final b = body(source, 'playerExistsInTenant');
      expect(b, contains(".ilike('firstName'"));
      expect(b, contains(".ilike('lastName'"));
      expect(b, contains(".eq('tenantId', targetTenantId)"));
    });

    test('addPlayer reactivates an existing row of the same account', () {
      final b = body(source, 'addPlayer');
      expect(b, contains(".eq('appId', appId)"));
      expect(b, contains(".eq('tenantId', currentTenantId)"));
      expect(b, contains("..['left'] = null"));
    });
  });

  group('Multi-Tenant Security - viewers / parents removal', () {
    for (final entry in {
      'viewer': 'deleteViewer',
      'parent': 'deleteParent',
    }.entries) {
      test('${entry.value} revokes tenant access first', () {
        final source =
            read('lib/data/repositories/${entry.key}_repository.dart');
        final b = body(source, entry.value);
        final revoke = b.indexOf(".from('tenantUsers')");
        final delete = b.lastIndexOf('.delete()');
        expect(revoke, isNot(-1));
        expect(delete, greaterThan(revoke));
        expect(
          RegExp(r"\.eq\('tenantId', currentTenantId\)").allMatches(b).length,
          greaterThanOrEqualTo(3),
        );
        expect(b, contains(".eq('role', Role.admin.value)"));
      });
    }
  });

  group('PlayerNotifier surfaces errors', () {
    test('no notifier method swallows errors', () {
      final source = read('lib/core/providers/player_providers.dart');
      final start = source.indexOf('class PlayerNotifier');
      final end = source.indexOf('final playerNotifierProvider');
      final b = source.substring(start, end);
      final catches = RegExp(r'state = AsyncValue\.error\(e, stack\);[^\n]*\n\s*rethrow;')
          .allMatches(b)
          .length;
      final errors = RegExp(r'state = AsyncValue\.error\(e, stack\);').allMatches(b).length;
      expect(catches, errors);
    });
  });
}
