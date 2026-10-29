import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/utils/duty_utils.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Body of the method starting at [signature] (up to the next method).
String _method(String src, String signature) {
  final start = src.indexOf(signature);
  expect(start, greaterThanOrEqualTo(0), reason: 'missing $signature');
  final next = src.indexOf('\n  Future<', start + signature.length);
  return src.substring(start, next < 0 ? src.length : next);
}

/// PARITY_A: DB reads/writes identical to Ionic (query-parity audit).
void main() {
  group('D1 no cross-tenant propagation', () {
    test('person detail no longer propagates identity fields', () {
      final page = _read('lib/features/people/presentation/pages/person_detail_page.dart');
      final repo = _read('lib/data/repositories/cross_tenant_person_repository.dart');
      expect(page, isNot(contains('propagateSharedFields')));
      expect(page, isNot(contains('_propagateSharedIdentityFields')));
      expect(repo, isNot(contains('propagateSharedFields')));
    });
  });

  group('D2 duty sync (Ionic syncDutyWithStatus)', () {
    final now = DateTime.utc(2026, 1, 2, 3);

    test('no fields for non-duty Termine', () {
      expect(
        dutySyncFieldsForStatus(
          isDutyTermin: false,
          currentDutyState: DutyState.confirmed,
          newStatus: AttendanceStatus.neutral,
          userId: 'u',
        ),
        isEmpty,
      );
    });

    test('excused keeps the duty state (no write)', () {
      expect(
        dutySyncFieldsForStatus(
          isDutyTermin: true,
          currentDutyState: DutyState.confirmed,
          newStatus: AttendanceStatus.excused,
          userId: 'u',
        ),
        isEmpty,
      );
    });

    test('neutral after confirmation goes back to requested', () {
      expect(
        dutySyncFieldsForStatus(
          isDutyTermin: true,
          currentDutyState: DutyState.confirmed,
          newStatus: AttendanceStatus.neutral,
          userId: 'u',
        ),
        {'duty_state': DutyState.requested},
      );
    });

    test('present without assignment confirms and assigns', () {
      expect(
        dutySyncFieldsForStatus(
          isDutyTermin: true,
          currentDutyState: null,
          newStatus: AttendanceStatus.present,
          userId: 'u',
          now: now,
        ),
        {
          'duty_state': DutyState.confirmed,
          'duty_reminder_sent': true,
          'duty_assigned_by': 'u',
          'duty_assigned_at': now.toIso8601String(),
        },
      );
    });

    test('present after request confirms without new assignment', () {
      expect(
        dutySyncFieldsForStatus(
          isDutyTermin: true,
          currentDutyState: DutyState.requested,
          newStatus: AttendanceStatus.present,
          userId: 'u',
        ),
        {'duty_state': DutyState.confirmed, 'duty_reminder_sent': true},
      );
    });

    test('absence excuse/reset write the duty fields', () {
      final src = _read('lib/data/repositories/player_absence_repository.dart');
      expect(src, contains('duty_state, attendance:attendance_id!inner('));
      expect(src, contains('attType:type_id(duty_mode)'));
      final excuse = _method(src, 'Future<int> excuseUpcomingAttendances(');
      expect(excuse, contains('..._dutySync(row, AttendanceStatus.excused)'));
      final reset = _method(src, 'Future<int> resetExcusedAttendances(');
      expect(reset, contains('..._dutySync(row, AttendanceStatus.fromValue(status))'));
      // tenant isolation stays
      expect(src, contains(".eq('attendance.tenantId', currentTenantId)"));
    });

    test('sign in/out and updatePersonAttendance share the helper', () {
      expect(_read('lib/data/repositories/sign_in_out_repository.dart'),
          contains('dutySyncFieldsForStatus('));
      expect(_read('lib/data/repositories/attendance_repository.dart'),
          contains('dutySyncFieldsForStatus('));
    });
  });

  group('D3 self registration', () {
    test('existing rows are overwritten like Ionic addPlayer', () {
      final src = _read('lib/features/registration/data/providers/registration_providers.dart');
      expect(src, isNot(contains("existing['left'] == null")));
      expect(src, contains('.update(reactivationPlayerData(playerData))'));
      expect(src, contains(".eq('tenantId', tenantId)"));
    });
  });

  group('D10 unavailability', () {
    test('created_by is always the current user', () {
      final src = _read('lib/data/repositories/duty_repository.dart');
      expect(src, contains("'created_by': _userId,"));
      expect(src, isNot(contains('rule.createdBy ?? _userId')));
    });
  });

  group('D12 song history date', () {
    test('history entries get the picked day (YYYY-MM-DD)', () {
      final src = _read('lib/features/attendance/presentation/attendance_create_writes.dart');
      expect(src, contains("attendanceId, DateFormat('yyyy-MM-dd').format(date))"));
    });
  });

  group('R1 getAttendances', () {
    test('no default limit / 180-day window, all pages', () {
      final src = _read('lib/data/repositories/attendance_repository.dart');
      final body = _method(src, 'Future<List<Attendance>> getAttendances(');
      expect(body, contains('int? limit,'));
      expect(body, isNot(contains('Duration(days: 180)')));
      expect(body, contains('fetchAllPages'));
      expect(body, contains(".eq('tenantId', currentTenantId)"));
    });

    test('currentAttDate = season start, fallback 2023-01-01', () {
      expect(AttendanceRepository.currentAttDate(null), DateTime(2023, 1, 1));
      expect(AttendanceRepository.currentAttDate('2025-09-01'), DateTime(2025, 9, 1));
    });

    test('callers no longer pass ad-hoc limits', () {
      expect(_read('lib/core/providers/statistics_providers.dart'),
          isNot(contains('limit: 500')));
      expect(_read('lib/features/export/presentation/pages/export_page.dart'),
          isNot(contains('limit: 10000')));
    });
  });
}
