import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// DEMO_GUARD: Demo-mode write protection (Ionic db.service
/// `checkDemoRestriction()` in 82 mutation methods).
///
/// Source analysis: every repository mutation that Ionic blocks for the demo
/// account must call `ensureNotDemo(...)` before touching Supabase, and the
/// operations Ionic deliberately leaves open (marking attendance,
/// notifications, background syncs) must NOT be blocked.
void main() {
  const guarded = <String, List<String>>{
    'player': [
      'createPlayer', 'updatePlayer', 'updatePlayerFields', 'archivePlayer',
      'reactivatePlayer', 'deletePlayer', 'pausePlayer', 'unpausePlayer',
      'approvePlayer', 'declinePlayer', 'updatePlayerInstrument',
      'resetLateCount', 'resolveCritical', 'linkAccount', 'unlinkAccount',
      'handoverPlayer', 'handoverPlayers', 'savePlayerOrder',
    ],
    'song': [
      'createSong', 'updateSong', 'deleteSong', 'updateSongSourceTenantId',
      'addSongCategory', 'updateSongCategory', 'deleteSongCategory',
      'addSongHistory',
    ],
    'group': [
      'createGroup', 'updateGroup', 'deleteGroup', 'createGroupCategory',
      'updateGroupCategory', 'updateGroupSortOrders',
      'updateGroupCategorySortOrders', 'deleteGroupCategory',
    ],
    'attendance': [
      'createAttendance', 'updateAttendance', 'deleteAttendance',
      'updateHistoryDatesForAttendance', 'uploadAttachment', 'removeAttachment',
    ],
    'attendance_type': ['createType', 'updateType', 'deleteType', 'reorderTypes'],
    'shift': ['createShift', 'updateShift', 'deleteShift'],
    'church': ['createChurch', 'renameChurch', 'mergeChurches'],
    'teacher': ['createTeacher', 'updateTeacher', 'deleteTeacher'],
    'agenda_item': [
      'createAgendaItem', 'proposeAgendaItem', 'updateAgendaItem',
      'deleteAgendaItem',
    ],
    'protocol': [
      'saveSection', 'publish', 'deleteProtocol', 'uploadPdf', 'removePdf',
      'updateAttendancePlan', 'createAttendance',
    ],
    'task': ['createTask', 'updateTask', 'deleteTask'],
    'organisation': [
      'create', 'linkTenantToOrganisation', 'unlinkTenantFromOrganisation',
    ],
    'organisation_settings': [
      'uploadLogo', 'removeLogo', 'updateBranding', 'setGlobalPersonId',
    ],
    'org_plan': ['updateOrganisation'],
    'parent': ['createParent', 'deleteParent'],
    'viewer': ['createViewer', 'deleteViewer'],
    'player_absence': ['addAbsence', 'deleteAbsence'],
    'import': ['insertPlayer', 'insertSong'],
    'admin': ['createAdmin', 'removeAdmin'],
    'profile': [
      'updateOwnProfile', 'updateSharedFieldValues', 'uploadOwnImage',
      'removeOwnImage',
    ],
    'cross_tenant_person': ['setGlobalPersonId'],
    'extra_fields': ['saveFields', 'updateFieldValue', 'resetFieldValues'],
    'tenant_create': ['createTenant'],
    'plan': [
      'updateAttendancePlanFields', 'setTypeDefaultOrgPlan', 'saveBlockTemplates',
    ],
    'user_registration': ['registerUser', 'createPlayerAccount'],
  };

  // Ionic leaves these open for the demo account (no checkDemoRestriction):
  // marking attendance, notes, notifications, background syncs.
  const open = <String, List<String>>{
    'attendance': [
      'updatePersonAttendance', 'createPersonAttendances',
      'ensurePersonAttendances', 'recalculatePercentage',
    ],
    'player': ['checkAndUnpausePlayers', 'mergePendingPlayerIntoExisting'],
    'sign_in_out': ['updateAttendanceNote'],
    'user_notification': ['setRead', 'markAllRead', 'deleteOne'],
    'feedback': ['sendQuestion', 'sendFeedback'],
    'role_permission': ['updatePermission'],
  };

  group('Demo Guard - BaseRepository', () {
    late String base;
    setUpAll(() {
      base = File('lib/data/repositories/base_repository.dart')
          .readAsStringSync();
    });

    test('provides ensureNotDemo()', () {
      expect(base, contains('void ensureNotDemo(String operation)'));
    });

    test('handleError passes DemoModeException through', () {
      expect(base, contains('if (error is DemoModeException)'));
    });

    test('Ionic toast text', () {
      final guard =
          File('lib/core/utils/demo_guard.dart').readAsStringSync();
      expect(guard,
          contains("'Diese Funktion ist im Demo-Modus nicht verfügbar.'"));
    });
  });

  group('Demo Guard - guarded mutations (Ionic checkDemoRestriction)', () {
    guarded.forEach((repo, methods) {
      final source =
          File('lib/data/repositories/${repo}_repository.dart').readAsStringSync();
      for (final m in methods) {
        test('$repo.$m calls ensureNotDemo first', () {
          final body = _methodBody(source, m);
          expect(body, isNotNull, reason: '$m should exist in $repo');
          final guardIdx = body!.indexOf("ensureNotDemo('$m')");
          expect(guardIdx, greaterThanOrEqualTo(0),
              reason: '$repo.$m must call ensureNotDemo');
          final supaIdx = body.indexOf('supabase');
          if (supaIdx >= 0) {
            expect(guardIdx, lessThan(supaIdx),
                reason: '$repo.$m must check demo before Supabase access');
          }
        });
      }
    });
  });

  group('Demo Guard - operations Ionic keeps open', () {
    open.forEach((repo, methods) {
      final source =
          File('lib/data/repositories/${repo}_repository.dart').readAsStringSync();
      for (final m in methods) {
        test('$repo.$m is not demo-blocked', () {
          final body = _methodBody(source, m);
          expect(body, isNotNull, reason: '$m should exist in $repo');
          expect(body, isNot(contains('ensureNotDemo')));
        });
      }
    });
  });

  group('Demo Guard - pages (Ionic people.demoUnavailable)', () {
    for (final path in [
      'lib/features/people/presentation/pages/person_import_page.dart',
      'lib/features/people/presentation/pages/bulk_edit_page.dart',
      'lib/features/songs/presentation/pages/song_import_page.dart',
    ]) {
      test('$path blocks the demo account', () {
        final src = File(path).readAsStringSync();
        expect(src, contains('ref.read(isDemoProvider)'));
        expect(src, contains('ToastHelper.showDemoRestricted(context)'));
      });
    }
  });
}

/// Body of the method [name] (from its signature to the matching brace).
String? _methodBody(String source, String name) {
  final sig = RegExp(r'\n  (?:Future<[^\n]*?>|void) ' + name + r'\(');
  final m = sig.firstMatch(source);
  if (m == null) return null;
  var i = m.end;
  var depth = 1;
  while (depth > 0 && i < source.length) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    i++;
  }
  final open = source.indexOf('{', i);
  if (open < 0) return null;
  depth = 1;
  var j = open + 1;
  while (depth > 0 && j < source.length) {
    final c = source[j];
    if (c == '{') depth++;
    if (c == '}') depth--;
    j++;
  }
  return source.substring(open, j);
}
