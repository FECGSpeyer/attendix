import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ATT_DETAIL: source analysis of the ad-hoc reminder and attachment
/// helpers in AttendanceRepository.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/data/repositories/attendance_repository.dart').readAsStringSync();
  });

  String methodBody(String name) {
    final start = source.indexOf('Future<');
    expect(start, isNot(-1));
    final idx = source.indexOf(' $name(');
    expect(idx, isNot(-1), reason: '$name not found');
    final next = source.indexOf('\n  Future<', idx + 1);
    final end = source.indexOf('// END ATT_DETAIL', idx);
    return source.substring(idx, next == -1 || (end != -1 && end < next) ? end : next);
  }

  group('Multi-Tenant Security - ATT_DETAIL', () {
    test('sendAdHocReminder validates the Termin and sends the current tenant id', () {
      final body = methodBody('sendAdHocReminder');
      expect(body, contains("_assertAttendanceInTenant(attendanceId"));
      expect(body, contains("'tenantId': currentTenantId"));
      expect(body, contains("functions.invoke('send-ad-hoc-reminder'"));
    });

    test('uploadAttachment validates the Termin and filters the update by tenantId', () {
      final body = methodBody('uploadAttachment');
      expect(body, contains('_assertAttendanceInTenant(attendanceId'));
      expect(body, contains(".eq('id', attendanceId)"));
      expect(body, contains(".eq('tenantId', currentTenantId)"));
    });

    test('removeAttachment validates the Termin and filters the update by tenantId', () {
      final body = methodBody('removeAttachment');
      expect(body, contains('_assertAttendanceInTenant(attendanceId'));
      expect(body, contains(".eq('tenantId', currentTenantId)"));
    });

    test('_assertAttendanceInTenant checks id AND tenantId', () {
      final idx = source.indexOf('Future<void> _assertAttendanceInTenant');
      final body = source.substring(idx, source.indexOf('\n  }', idx));
      expect(body, contains(".eq('id', attendanceId)"));
      expect(body, contains(".eq('tenantId', currentTenantId)"));
    });
  });
}
