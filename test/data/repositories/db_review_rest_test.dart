import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/services/cross_tenant_service.dart';
import 'package:attendix/core/utils/profile_image_path.dart';
import 'package:attendix/core/utils/shift_utils.dart';
import 'package:attendix/core/utils/string_utils.dart';
import 'package:attendix/data/models/shift/shift_definition.dart';
import 'package:attendix/data/models/shift/shift_plan.dart';
import 'package:attendix/features/auth/data/auth_link_listener.dart';
import 'package:flutter_test/flutter_test.dart';

/// DB_REVIEW_REST: findings of reviews/db-und-paritaets-review-v0.7.0.md
/// (H4, M2–M9, F1–F7 and some NIEDRIG items) – unit tests for the pure
/// helpers and source analysis for query shapes / native config.
void main() {
  String read(String path) => File(path).readAsStringSync();

  String body(String source, String start, [int length = 2500]) {
    final i = source.indexOf(start);
    expect(i, greaterThan(-1), reason: 'not found: $start');
    return source.substring(i, (i + length).clamp(0, source.length));
  }

  group('H4 Termin-Foto (Ionic image.service updateAttendanceImage)', () {
    test('repository uploads to bucket attendances with key <id> and upsert', () {
      final repo = read('lib/data/repositories/attendance_repository.dart');
      final upload = body(repo, 'Future<String> uploadAttendanceImage', 1200);
      expect(upload, contains("storage.from('attendances')"));
      expect(upload, contains('attendanceImagePath(attendanceId)'));
      expect(upload, contains('FileOptions(upsert: true)'));
      expect(upload, contains("_assertAttendanceInTenant(attendanceId"));
      expect(upload, contains(".eq('tenantId', currentTenantId)"));
      expect(repo, contains("static String attendanceImagePath(int attendanceId) => '\$attendanceId';"));
    });

    test('detail page no longer uses the unknown attendance-images bucket', () {
      final page = read('lib/features/attendance/presentation/pages/attendance_detail_page.dart');
      expect(page, isNot(contains('attendance-images')));
      expect(page, contains('repo.uploadAttendanceImage(widget.attendanceId, bytes)'));
    });
  });

  group('M2 group change keeps future person_attendances', () {
    test('person detail disables the group branch of the sync', () {
      final page = read('lib/features/people/presentation/pages/person_detail_page.dart');
      final call = body(page, 'syncPlayerWithUpcomingAttendances(', 400);
      expect(call, contains('oldInstrument: _selectedGroupId'));
    });
  });

  group('M3 critical rules have no enabled switch (Ionic / edge function)', () {
    test('sheet always saves enabled rules, no switch', () {
      final sheet = read('lib/features/settings/presentation/widgets/critical_rule_sheet.dart');
      expect(sheet, isNot(contains('SwitchListTile')));
      expect(sheet, contains('enabled: true'));
    });

    test('enabled flag is ignored when reading rules', () {
      expect(read('lib/features/people/presentation/pages/person_detail_page.dart'),
          isNot(contains('rule.enabled')));
      expect(read('lib/features/settings/presentation/widgets/critical_rule_card.dart'),
          isNot(contains('rule.enabled')));
    });
  });

  group('M4 profile picture keys like Ionic', () {
    test('storage key is the bare player id', () {
      expect(profileImageStoragePath(42), '42');
    });

    test('object path from public URL (Ionic and legacy keys, query stripped)', () {
      const base = 'https://x.supabase.co/storage/v1/object/public/profiles';
      expect(profileImagePathFromUrl('$base/42'), '42');
      expect(profileImagePathFromUrl('$base/42?quality=20'), '42');
      expect(profileImagePathFromUrl('$base/7/42.jpg?t=1'), '7/42.jpg');
      expect(profileImagePathFromUrl(''), isNull);
      expect(profileImagePathFromUrl(null), isNull);
      expect(profileImagePathFromUrl('https://attendix.de/assets/default.png'), isNull);
    });

    test('person header and registration use the Ionic key and img ""', () {
      final header = read('lib/features/people/presentation/widgets/person_detail/person_header.dart');
      expect(header, isNot(contains(r"'${tenant.id}/$personId.jpg'")));
      expect(header, contains('profileImageStoragePath(personId)'));
      expect(header, contains("'img': ''"));
      expect(header, isNot(contains("'img': null")));
      final reg = read('lib/features/registration/data/providers/registration_providers.dart');
      expect(reg, isNot(contains(r"'$tenantId/$playerId.jpg'")));
      expect(reg, contains('profileImageStoragePath(playerId)'));
    });
  });

  group('M5 copy shift to another tenant', () {
    const shift = ShiftPlan(
      id: 's1',
      name: 'Nacht',
      definition: [ShiftDefinition(startTime: '18:00', duration: 8, repeatCount: 1)],
    );
    final types = [
      {'id': 't1', 'all_day': false, 'start_time': '19:00', 'end_time': '21:00', 'default_status': 1},
      {'id': 't2', 'all_day': true, 'start_time': '19:00', 'end_time': '21:00', 'default_status': 1},
    ];
    final attendances = [
      {'id': 1, 'date': '2026-11-05', 'type_id': 't1', 'start_time': null, 'end_time': null},
      {'id': 2, 'date': '2026-11-05', 'type_id': 't2', 'start_time': null, 'end_time': null},
    ];
    final shiftData = {10: (shiftName: null, shiftStart: '2026-11-01')};

    test('excuses colliding rows that still have the default status', () {
      final updates = ShiftUtils.copiedShiftAttendanceUpdates(
        shift: shift,
        attendances: attendances,
        types: types,
        personAttendances: [
          {'id': 'pa1', 'person_id': 10, 'attendance_id': 1, 'status': 1},
          {'id': 'pa2', 'person_id': 10, 'attendance_id': 2, 'status': 1}, // all-day type
          {'id': 'pa3', 'person_id': 99, 'attendance_id': 1, 'status': 1}, // not assigned
        ],
        shiftDataByPersonId: shiftData,
      );
      expect(updates.map((u) => u.id), ['pa1']);
      expect(updates.single.status, AttendanceStatus.excused);
      expect(updates.single.notes, ShiftUtils.shiftNote);
    });

    test('manually set statuses are kept', () {
      final updates = ShiftUtils.copiedShiftAttendanceUpdates(
        shift: shift,
        attendances: attendances,
        types: types,
        personAttendances: [
          {'id': 'pa1', 'person_id': 10, 'attendance_id': 1, 'status': AttendanceStatus.absent.value},
        ],
        shiftDataByPersonId: shiftData,
      );
      expect(updates, isEmpty);
    });

    test('only active people get the copy and attendances are recalculated', () {
      final sheet = read('lib/features/shifts/presentation/widgets/copy_shift_to_tenant_sheet.dart');
      expect(body(sheet, "inFilter('appId', appIds)", 80), contains(".isFilter('left', null)"));
      expect(sheet, contains('_updateShiftAttendancesInTenant('));
      final update = body(sheet, 'Future<void> _updateShiftAttendancesInTenant(', 2000);
      expect(update, contains(".eq('tenant_id', targetTenantId)"));
      expect(update, contains(".eq('tenantId', targetTenantId)"));
      expect(update, contains(".eq('attendance.tenantId', targetTenantId)"));
    });
  });

  group('M6 getPersonIdForTenant picks client-side (no PGRST116)', () {
    test('prefers the active row', () {
      expect(
        CrossTenantService.pickPersonIdForTenant([
          {'id': 1, 'pending': false, 'left': '2025-01-01'},
          {'id': 2, 'pending': false, 'left': null},
        ]),
        2,
      );
    });

    test('falls back to the first row, null without rows', () {
      expect(
        CrossTenantService.pickPersonIdForTenant([
          {'id': 5, 'pending': true, 'left': null},
          {'id': 6, 'pending': false, 'left': '2025-01-01'},
        ]),
        5,
      );
      expect(CrossTenantService.pickPersonIdForTenant([]), isNull);
    });

    test('query loads all rows instead of maybeSingle', () {
      final source = read('lib/core/services/cross_tenant_service.dart');
      final q = body(source, 'Future<int?> getPersonIdForTenant', 700);
      expect(q, isNot(contains('maybeSingle')));
      expect(q, contains(".eq('tenantId', tenantId)"));
    });
  });

  group('M7 case-insensitive e-mail lookup (Ionic ilike)', () {
    test('pattern escapes LIKE wildcards', () {
      expect(StringUtils.exactIlikePattern(' A_b%c@x.de '), r'A\_b\%c@x.de');
      expect(StringUtils.exactIlikePattern(r'a\b@x.de'), r'a\\b@x.de');
    });

    test('registration lookup uses ilike', () {
      final source = read('lib/data/repositories/user_registration_repository.dart');
      final q = body(source, 'Future<(String, bool)?> getAppIdByEmail', 900);
      expect(q, contains(".ilike('email', StringUtils.exactIlikePattern(email))"));
      expect(q, isNot(contains(".eq('email'")));
    });
  });

  test('M8 device token upsert targets UNIQUE(user_id, token)', () {
    final source = read('lib/data/repositories/device_token_repository.dart');
    expect(source, contains("onConflict: 'user_id,token'"));
  });

  group('M9 church merge / extra field cleanup are paged', () {
    test('church merge', () {
      final source = read('lib/data/repositories/church_repository.dart');
      // SOL_FIX3 moved the paged load into a helper used by mergeChurches.
      final q = source.substring(source.indexOf('Future<int> mergeChurches'));
      expect(q, contains('fetchAllPages'));
      expect(q, contains(".order('id')"));
    });

    test('extra fields', () {
      final source = read('lib/data/repositories/extra_fields_repository.dart');
      final q = body(source, '_loadRows(String table)', 600);
      expect(q, contains('fetchAllPages'));
      expect(q, contains(".eq('tenantId', currentTenantId)"));
      expect(q, contains(".order('id', ascending: true)"));
    });
  });

  group('F1 universal links / app links', () {
    test('only attendix.de https links map to an in-app location', () {
      expect(appLinkLocation(Uri.parse('https://attendix.de/tabs/attendance/5?tenantId=3')),
          '/tabs/attendance/5?tenantId=3');
      expect(appLinkLocation(Uri.parse('https://attendix.de')), '/');
      expect(appLinkLocation(Uri.parse('https://www.attendix.de/login')), '/login');
      expect(appLinkLocation(Uri.parse('https://evil.example/login')), isNull);
      expect(appLinkLocation(Uri.parse('attendix://live-plan?attendance=1')), isNull);
    });

    test('iOS associated domain and Android verified intent filter', () {
      expect(read('ios/Runner/Runner.entitlements'), contains('applinks:attendix.de'));
      final plist = read('ios/Runner/Info.plist');
      expect(body(plist, 'FlutterDeepLinkingEnabled', 60), contains('<false/>'));
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android:autoVerify="true"'));
      expect(manifest, contains('android:host="attendix.de"'));
      expect(manifest, contains('android:name="flutter_deeplinking_enabled" android:value="false"'));
    });

    test('well-known files list the Flutter iOS app next to the Ionic one', () {
      final aasa = read('web/.well-known/apple-app-site-association');
      expect(aasa, contains('WJ62LFJT38.de.attendix.attendix'));
      expect(aasa, contains('MXM3YWAKPL.io.stephanus.attendix'));
      expect(File('web/.well-known/assetlinks.json').existsSync(), isTrue);
    });
  });

  group('F2 Android live plan notification', () {
    test('native channel, messaging service and notification exist', () {
      const dir = 'android/app/src/main/kotlin/de/attendix/attendix/liveplan';
      final plugin = read('$dir/LiveActivityPlugin.kt');
      expect(plugin, contains('const val CHANNEL = "de.attendix/live_activity"'));
      for (final m in ['isAvailable', 'start', 'update', 'end', 'endAll', 'list', 'getTokens', 'takePendingUrl']) {
        expect(plugin, contains('"$m"'), reason: m);
      }
      expect(read('$dir/LivePlanNotifications.kt'), contains('CHANNEL_ID = "live_plan"'));
      expect(read('$dir/LivePlanMessagingService.kt'), contains('"live_plan"'));
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('.liveplan.LivePlanMessagingService'));
      expect(manifest, contains('android:scheme="attendix" android:host="live-plan"'));
      expect(read('android/app/src/main/kotlin/de/attendix/attendix/MainActivity.kt'),
          contains('LiveActivityPlugin('));
    });
  });

  test('F3 admins lift expired pauses when opening the people list', () {
    final page = read('lib/features/people/presentation/pages/people_list_page.dart');
    final check = body(page, 'Future<void> _checkAndUnpause()', 500);
    expect(check, contains('role.isAdmin || role.isResponsible'));
    expect(check, contains('checkAndUnpausePlayers()'));
  });

  test('F4 account deletion without an instance', () {
    final page = read('lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart');
    expect(page, contains('registerDeleteAccount'));
    expect(page, contains('accountNotifierProvider.notifier).deleteAccount()'));
    // "Neue Instanz" opens the tenant creation, not the (redirected) sign-up.
    expect(page, isNot(contains("context.push('/register')")));
    expect(page, contains("context.push('/tenants/new')"));
  });

  test('F6 web update check like Ionic (start, visibility, hourly)', () {
    final html = read('web/index.html');
    expect(html, isNot(contains('setInterval(() => registration.update(), 30000)')));
    expect(html, contains("addEventListener('visibilitychange', checkForUpdate)"));
    expect(html, contains('60 * 60 * 1000'));
  });

  test('F7 parents portal note label is localized', () {
    final page = read('lib/features/parents/presentation/pages/parents_portal_page.dart');
    expect(page, isNot(contains("'Notiz: ")));
    expect(page, contains('signoutNoteChip('));
  });

  group('NIEDRIG', () {
    test('getGroupsMap tolerates a null name', () {
      final source = read('lib/data/repositories/group_repository.dart');
      expect(source, contains("(row['name'] as String?) ?? ''"));
    });

    test('organisation lookup limits before maybeSingle', () {
      final source = read('lib/data/repositories/organisation_repository.dart');
      final q = body(source, 'Future<Organisation?> getOrganisationFromTenant', 500);
      expect(q, contains('.limit(1)'));
    });

    test('approval fails when the role update fails', () {
      final source = read('lib/core/providers/player_providers.dart');
      final notify = body(source, 'Future<void> _notifyApproval', 900);
      final roleUpdate = notify.indexOf('updateTenantUserRole');
      expect(roleUpdate, greaterThan(-1));
      expect(roleUpdate, lessThan(notify.indexOf('try {')));
    });
  });
}
