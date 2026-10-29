// LEFTOVERS: router guard for typed /attendance/:id, offline detail cache,
// offline-queued date-change resets, realtime duty_state + resume refresh,
// removed unused l10n keys.
import 'dart:convert';
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/router/attendance_detail_guard.dart';
import 'package:attendix/core/services/attendance_detail_cache.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/features/attendance/presentation/pages/attendance_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('attendanceDetailRedirect (Ionic att-list openAttendance)', () {
    test('admin, responsible, helper, voice-leader-helper may open a Termin', () {
      for (final role in [Role.admin, Role.responsible, Role.helper, Role.voiceLeaderHelper]) {
        expect(attendanceDetailRedirect('/attendance/42', role, canCreate: true), isNull, reason: role.name);
        expect(attendanceDetailRedirect('/attendance/new', role, canCreate: true), isNull, reason: role.name);
      }
    });

    test('viewer is sent to its home page (/people, Ionic /tabs/player)', () {
      expect(attendanceDetailRedirect('/attendance/42', Role.viewer, canCreate: true), '/people');
      expect(attendanceDetailRedirect('/attendance/new', Role.viewer, canCreate: true), '/people');
    });

    test('other roles land on their default route', () {
      expect(attendanceDetailRedirect('/attendance/42', Role.player, canCreate: true), '/signout');
      expect(attendanceDetailRedirect('/attendance/42', Role.voiceLeader, canCreate: true), '/signout');
      expect(attendanceDetailRedirect('/attendance/42', Role.parent, canCreate: true), '/parents');
    });

    // SOL_FIX2: attendance_create enforced for typed /attendance/new
    test('helper without attendance_create cannot open /attendance/new', () {
      for (final role in [Role.helper, Role.voiceLeaderHelper]) {
        expect(attendanceDetailRedirect('/attendance/new', role, canCreate: false), '/attendance');
        expect(attendanceDetailRedirect('/attendance/new?date=2026-01-01', role, canCreate: false), '/attendance');
        // an existing Termin stays reachable
        expect(attendanceDetailRedirect('/attendance/42', role, canCreate: false), isNull);
      }
      expect(attendanceDetailRedirect('/attendance/new', Role.viewer, canCreate: false), '/people');
    });

    test('router passes the resolved create permission', () {
      final src = File('lib/core/router/app_router.dart').readAsStringSync();
      expect(src, contains('canCreateAttendance: ref.read(canCreateAttendanceProvider)')); // PARITY_R7
    });

    test('list and unrelated routes are not touched', () {
      expect(attendanceDetailRedirect('/attendance', Role.viewer, canCreate: true), isNull);
      expect(attendanceDetailRedirect('/people', Role.viewer, canCreate: true), isNull);
      expect(attendanceDetailRedirect('/attendances/1', Role.viewer, canCreate: true), isNull);
    });

    test('router applies the rule before the generic route table', () {
      final src = File('lib/core/router/app_router.dart').readAsStringSync();
      final rule = src.indexOf('attendanceDetailRedirect(\n    location,\n    role,'); // PARITY_R7: roleRouteRedirect
      final table = src.indexOf('for (final entry in _protectedRoutes.entries)');
      expect(rule, greaterThan(0));
      expect(table, greaterThan(rule), reason: 'first match wins');
    });
  });

  group('AttendanceDetailCache (Ionic offline_att_detail_v1)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    const cache = AttendanceDetailCache();
    final key = AttendanceDetailCache.keyFor('u1', 7, 42, 'attendance');

    test('keys are user and tenant scoped (SOL_FIX7)', () {
      expect(key, 'offline_att_detail_v1_u1_7_42_attendance');
      expect(AttendanceDetailCache.keyFor('u1', 8, 42, 'attendance'), isNot(key));
      expect(AttendanceDetailCache.keyFor('u2', 7, 42, 'attendance'), isNot(key));
      expect(AttendanceDetailCache.playersKeyFor('u1', 7), 'offline_att_detail_v1_u1_7_players');
    });

    test('online: fetches and stores the result', () async {
      final result = await cache.fetchWithCache<Map<String, dynamic>>(
        key: key,
        isOnline: () async => true,
        fetch: () async => {'id': 42, 'notes': 'fresh'},
      );
      expect(result, {'id': 42, 'notes': 'fresh'});
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString(key)!), {'id': 42, 'notes': 'fresh'});
    });

    test('offline: returns the cached copy without fetching', () async {
      await cache.save(key, {'id': 42, 'notes': 'cached'});
      var fetched = false;
      final result = await cache.fetchWithCache<Map<String, dynamic>>(
        key: key,
        isOnline: () async => false,
        fetch: () async {
          fetched = true;
          return {'id': 42};
        },
      );
      expect(fetched, isFalse);
      expect(result, {'id': 42, 'notes': 'cached'});
    });

    test('offline lists are returned as List', () async {
      final listKey = AttendanceDetailCache.keyFor('u1', 7, 42, 'persons');
      await cache.save(listKey, [
        {'id': 'a', 'status': 1}
      ]);
      final result = await cache.fetchWithCache<List<dynamic>>(
        key: listKey,
        isOnline: () async => false,
        fetch: () async => throw StateError('no network'),
      );
      expect(result, hasLength(1));
    });

    test('failed fetch (network) falls back to cache, rethrows without one', () async {
      Future<Map<String, dynamic>?> failing() async =>
          throw http.ClientException('Failed to fetch');
      await expectLater(
        cache.fetchWithCache<Map<String, dynamic>>(key: key, isOnline: () async => true, fetch: failing),
        throwsA(isA<http.ClientException>()),
      );
      await cache.save(key, {'id': 42});
      expect(
        await cache.fetchWithCache<Map<String, dynamic>>(key: key, isOnline: () async => true, fetch: failing),
        {'id': 42},
      );
    });

    test('detail providers use the cache and still filter by tenant', () {
      final src = File('lib/core/providers/attendance_detail_providers.dart').readAsStringSync();
      expect(RegExp('fetchWithCache').allMatches(src).length, 4);
      expect(src, contains(".eq('tenantId', tenant.id!)"));
      expect(src, contains(".eq('tenant_id', tenant.id!)"));
      // SOL_FIX1: persons query uses the captured tenant id.
      expect(src, contains(".eq('attendance.tenantId', tenantId)"));
      expect(src, contains('final tenantId = tenant.id!;'));
    });
  });

  group('offline queue on the Termin page', () {
    // ASTRA_SIGNOUT_TOPICS: the date change of the Termin page is shared
    // with the Teamorganisation (attendance_date_change.dart).
    final page = File('lib/features/attendance/presentation/pages/attendance_detail_page.dart')
            .readAsStringSync() +
        File('lib/features/attendance/presentation/widgets/attendance_date_change.dart')
            .readAsStringSync();

    test('date-change status resets are queued while offline', () {
      final start = page.indexOf('final updates = dateChangeStatusUpdates(');
      final end = page.indexOf('updateShiftAssignmentsForAttendance', start);
      final block = page.substring(start, end);
      expect(block, contains('enqueueIfOffline(u.id'));
    });

    test('every person_attendances write goes through enqueueIfOffline', () {
      final writes = RegExp(r'repo\.updatePersonAttendance\(').allMatches(page).length;
      final queued = RegExp(r'enqueueIfOffline\(').allMatches(page).length;
      expect(queued, greaterThanOrEqualTo(writes));
    });
  });

  group('realtime parity (Ionic onPersonAttRealtimeChanges / onVisibilityChange)', () {
    const rows = [
      PersonAttendance(id: 'pa1', personId: 1, dutyState: 'requested'),
      PersonAttendance(id: 'pa2', personId: 2),
    ];

    test('duty_state change triggers a reload', () {
      expect(realtimeDutyStateChanged({'id': 'pa1', 'duty_state': 'confirmed'}, rows), isTrue);
      expect(realtimeDutyStateChanged({'id': 'pa2', 'duty_state': 'self'}, rows), isTrue);
      expect(realtimeDutyStateChanged({'id': 'pa1', 'duty_state': null}, rows), isTrue);
    });

    test('unchanged / unknown / missing duty_state does not', () {
      expect(realtimeDutyStateChanged({'id': 'pa1', 'duty_state': 'requested'}, rows), isFalse);
      expect(realtimeDutyStateChanged({'id': 'pa2', 'duty_state': null}, rows), isFalse);
      expect(realtimeDutyStateChanged({'id': 'pa2', 'duty_state': ''}, rows), isFalse);
      expect(realtimeDutyStateChanged({'id': 'zzz', 'duty_state': 'self'}, rows), isFalse);
      expect(realtimeDutyStateChanged({'id': 'pa1', 'status': 1}, rows), isFalse);
    });

    test('page reloads + resubscribes when it becomes visible again', () {
      final page = File('lib/features/attendance/presentation/pages/attendance_detail_page.dart')
          .readAsStringSync();
      expect(page, contains('AppLifecycleListener(onShow: _onBecameVisible)'));
      expect(page, contains('_lifecycleListener?.dispose()'));
      final start = page.indexOf('void _onBecameVisible()');
      final body = page.substring(start, page.indexOf('\n  }\n', start));
      expect(body, contains('ref.invalidate(attendanceDetailProvider'));
      expect(body, contains('ref.invalidate(personAttendancesForAttendanceProvider'));
      expect(body, contains('_subscribeToRealtimeChanges()'));
    });
  });

  test('unused l10n keys are gone', () {
    final de = File('lib/l10n/app_de.arb').readAsStringSync();
    expect(de, isNot(contains('coreFlutterRegisterPlan')));
    expect(de, isNot(contains('loginFlutterHaveAccount')));
  });
}
