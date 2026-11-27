import 'package:attendix/core/constants/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for AttendanceType update payload format
///
/// The database expects:
/// - default_status: INTEGER
/// - available_statuses: INTEGER[]
///
/// The AttendanceStatus enum provides .value (int) for this purpose.
void main() {
  group('AttendanceType Update Payload', () {
    test('default_status should use integer value, not name', () {
      final status = AttendanceStatus.present;

      // .name returns string - WRONG for DB
      expect(status.name, equals('present'));
      expect(status.name, isA<String>());

      // .value returns int - CORRECT for DB
      expect(status.value, equals(1));
      expect(status.value, isA<int>());

      // The update payload should use .value
      final correctPayload = {
        'default_status': status.value,
      };
      expect(correctPayload['default_status'], isA<int>());
    });

    test('available_statuses should use integer array, not string array', () {
      final statuses = {
        AttendanceStatus.present,
        AttendanceStatus.absent,
        AttendanceStatus.excused,
      };

      // .name gives strings - WRONG for DB
      final wrongPayload = statuses.map((s) => s.name).toList();
      expect(wrongPayload, equals(['present', 'absent', 'excused']));
      expect(wrongPayload, isA<List<String>>());

      // .value gives integers - CORRECT for DB
      final correctPayload = statuses.map((s) => s.value).toList();
      expect(correctPayload, equals([1, 4, 2]));
      expect(correctPayload, isA<List<int>>());
    });

    test('all AttendanceStatus values have correct integer mapping', () {
      expect(AttendanceStatus.neutral.value, equals(0));
      expect(AttendanceStatus.present.value, equals(1));
      expect(AttendanceStatus.excused.value, equals(2));
      expect(AttendanceStatus.late.value, equals(3));
      expect(AttendanceStatus.absent.value, equals(4));
      expect(AttendanceStatus.lateExcused.value, equals(5));
    });

    test('AttendanceStatus.fromValue correctly parses integers', () {
      expect(AttendanceStatus.fromValue(0), equals(AttendanceStatus.neutral));
      expect(AttendanceStatus.fromValue(1), equals(AttendanceStatus.present));
      expect(AttendanceStatus.fromValue(2), equals(AttendanceStatus.excused));
      expect(AttendanceStatus.fromValue(3), equals(AttendanceStatus.late));
      expect(AttendanceStatus.fromValue(4), equals(AttendanceStatus.absent));
      expect(AttendanceStatus.fromValue(5), equals(AttendanceStatus.lateExcused));
    });
  });
}
