import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// REVIEW_FIX: source analysis for the security/riverpod review findings.
void main() {
  String read(String path) => File(path).readAsStringSync();

  String body(String source, String start, [int length = 2500]) {
    final i = source.indexOf(start);
    expect(i, greaterThan(-1), reason: 'not found: $start');
    return source.substring(i, (i + length).clamp(0, source.length));
  }

  group('HIGH1 registration of an existing account', () {
    late String source;
    setUpAll(() => source = read(
        'lib/features/registration/data/providers/registration_providers.dart'));

    test('existing account goes through registerUser (no duplicate tenantUsers)',
        () {
      final branch = body(source, 'user.identities?.isEmpty ?? true', 1200);
      expect(branch, contains('registration.registerUser('));
      expect(branch, contains('selfRegister: true'));
      final existingBranch = branch.substring(0, branch.indexOf('} else {'));
      expect(existingBranch, isNot(contains('addUserToTenant')));
    });

    test('only left rows are reactivated, active rows are never overwritten',
        () {
      final reactivate = body(source, 'final existing = await supabase', 1200);
      expect(reactivate, contains(".select('id, left')"));
      expect(reactivate, contains(".eq('tenantId', tenantId)"));
      expect(reactivate, contains("existing['left'] == null"));
      expect(reactivate, contains('reactivationPlayerData(playerData)'));
    });

    test('raw exception text is not shown to the user', () {
      expect(source, isNot(contains('RegistrationResult.error(e.toString())')));
    });
  });

  group('HIGH2 person detail sync uses the previous group', () {
    test('oldInstrument is the stored instrument', () {
      final source =
          read('lib/features/people/presentation/pages/person_detail_page.dart');
      final call = body(source, 'syncPlayerWithUpcomingAttendances(', 400);
      expect(call, contains('oldInstrument: person.instrument'));
      expect(call, isNot(contains('oldInstrument: _selectedGroupId')));
    });
  });

  group('MED4 AdminRepository', () {
    late String source;
    setUpAll(() => source = read('lib/data/repositories/admin_repository.dart'));

    test('e-mail lookup is exact (no ilike wildcards)', () {
      expect(source, isNot(contains('.ilike(')));
      expect(source, contains(".eq('email', email)"));
    });

    test('inform mail failure does not throw after the admin insert', () {
      final inform = body(source, 'Future<bool> _informAdmin', 800);
      expect(inform, contains('catch (_)'));
      expect(inform, contains('return false'));
      expect(source, contains('on AdminException'));
    });
  });

  group('MED6 pausing in other tenants requires admin/responsible there', () {
    late String source;
    setUpAll(() => source =
        read('lib/data/repositories/cross_tenant_person_repository.dart'));

    test('pausePlayerInOtherTenant checks the role before writing', () {
      final pause = body(source, 'Future<void> pausePlayerInOtherTenant(', 1500);
      final check = pause.indexOf('getManageableTenantIds(');
      final write = pause.indexOf(".from('player')");
      expect(check, greaterThan(-1));
      expect(check, lessThan(write));
    });

    test('getManageableTenantIds filters the current user and the roles', () {
      final q = body(source, 'Future<Set<int>> getManageableTenantIds(', 1000);
      expect(q, contains('supabase.auth.currentUser?.id'));
      expect(q, contains(".eq('userId', userId)"));
      expect(q, contains('linkedTenantIds.contains'));
      expect(q, contains('Role.admin.value, Role.responsible.value'));
    });

    test('viewer role uses the enum', () {
      expect(source, isNot(contains('_viewerRole = 3')));
      expect(source, contains('Role.viewer.value'));
    });

    test('pause sheet only offers manageable tenants', () {
      final sheet = read(
          'lib/features/people/presentation/widgets/pause_person_sheet.dart');
      expect(sheet, contains('getManageableTenantIds('));
    });
  });

  group('LOW10 merge pending player', () {
    test('role follows the main group and paused targets are not backfilled',
        () {
      final source = read('lib/data/repositories/player_repository.dart');
      final merge =
          body(source, 'Future<void> mergePendingPlayerIntoExisting(', 4500);
      expect(merge, contains('UserRegistrationRepository.accountRoleFor('));
      expect(merge, contains(".eq('maingroup', true)"));
      expect(merge, contains(".update({'role': role.value})"));
      expect(merge, contains('if (!target.paused)'));
    });
  });

  group('Attendance repository paging', () {
    test('person_attendances paging has a stable order', () {
      final source = read('lib/data/repositories/attendance_repository.dart');
      final q = body(source, 'getPersonAttendancesForAttendances(', 1500);
      expect(q.indexOf(".order('id')"), lessThan(q.indexOf('.range(')));
      expect(q.indexOf(".order('id')"), greaterThan(-1));
    });
  });

  group('Attendance detail', () {
    late String source;
    setUpAll(() => source = read(
        'lib/features/attendance/presentation/pages/attendance_detail_page.dart'));

    // LOGIC_ATT: rows are synced one by one (Ionic add/update/remove
    // history entry) – no bulk delete, and no early return in between.
    test('song history sync never stops half-way', () {
      final sync = body(source, 'Future<void> _syncHistoryEntries(', 2400);
      expect(sync, contains('deleteHistoryEntry'));
      expect(sync, contains('addHistoryEntries'));
      expect(sync, isNot(contains('if (!mounted) return;')));
      expect(sync, isNot(contains('.delete()')));
    });

    test('mutating menu actions and description are gated', () {
      final menu = body(source, 'List<PopupMenuEntry<String>> _buildAttDetailMenuItems(', 3000);
      expect(menu, contains("if (canMutate) item('add_person'"));
      expect(menu, contains("if (canMutate) item('reminder'"));
      expect(menu, contains("if (canMutate) item('photo'"));
      expect(source, contains('onEditDescription: canMutateAttendanceDetail('));
    });
  });

  group('Attendance create', () {
    test('typeInfo defaults to empty string (Ionic)', () {
      final source = read(
          'lib/features/attendance/presentation/pages/attendance_create_page.dart');
      expect(source, contains("'typeInfo': _typeInfo ?? '',"));
      expect(source, contains('shouldCloseOnMinExtent: !isSaving'));
      expect(source, contains('canPop: !_isLoading'));
    });
  });
}
