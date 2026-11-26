import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

const _duty = AttendanceType(id: 'd', name: 'Dienst', dutyMode: true);

void main() {
  group('Übersicht query and duty average', () {
    final repo = _read('lib/data/repositories/sign_in_out_repository.dart');
    final method = repo.substring(
      repo.indexOf('Future<List<CrossTenantPersonAttendance>> _ownAttendancesOfTenant'),
      repo.indexOf('static String tenantDisplayName'),
    );

    test('query uses the overview columns (no place / plan) and keeps the tenant filter', () {
      expect(method, contains('kOverviewAttendanceColumns'));
      expect(method, contains(".eq('attendance.tenantId', tenantId)"));
      expect(method, contains(".eq('tenantId', tenantId)"));
      final cols = RegExp(r"const String kOverviewAttendanceColumns =([^;]*);")
          .firstMatch(repo)!
          .group(1)!;
      expect(cols, isNot(contains('place')));
      expect(cols, isNot(contains('plan')));
      expect(cols, contains('files_folder'));
    });

    test('unassigned duty Termine are not filtered out', () {
      expect(method, isNot(contains('duty_mode')));
    });

    test('unassigned duty Termine count for the average', () {
      CrossTenantPersonAttendance att(String date, AttendanceStatus s, {String? duty}) =>
          CrossTenantPersonAttendance(
            id: date,
            date: date,
            status: s,
            attendanceType: _duty,
            dutyState: duty,
            tenantId: 1,
            tenantName: 'T',
            tenantColor: '#000000',
          );
      final data = buildOverviewData([
        att('2026-01-10T12:00:00', AttendanceStatus.present, duty: 'confirmed'),
        att('2026-01-11T12:00:00', AttendanceStatus.neutral),
      ], now: DateTime(2026, 6));
      expect(data.past, hasLength(2));
      expect(data.stats.percentage, 50);
    });
  });
}
