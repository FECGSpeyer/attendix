import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Sprint 2a Task 7 regression test.
///
/// attendance_detail_page.dart originally had 19 direct
/// `supabaseClientProvider` reads. Sprint 2a migrated 15 of them to
/// AttendanceRepository methods. The remaining 4 are intentionally deferred:
///
///   - 2 Realtime channel calls (subscribe + unsubscribe) — Sprint 2c
///   (the Storage upload in _takePhoto is gone since DB_REVIEW_REST H4:
///    it now uses AttendanceRepository.uploadAttendanceImage)
///   (the history-table bypass in _syncHistoryEntries is gone since
///    LOGIC_ATT: it now uses AttendanceRepository history methods)
///
/// When Sprint 2b and 2c finish, this count should drop to 0 and the
/// corresponding TODO markers should be removed.
void main() {
  test('attendance_detail_page has only 2 known bypasses left (2c scope)', () {
    final source = File(
      'lib/features/attendance/presentation/pages/attendance_detail_page.dart',
    ).readAsStringSync();

    final hits = RegExp(r'supabaseClientProvider')
        .allMatches(source)
        .length;

    expect(
      hits,
      equals(2),
      reason: 'Only Realtime (2c) should '
          'remain. If you fixed any of those in Sprint 2a, lower the count '
          'and remove the corresponding TODO marker.',
    );
  });

  test('all remaining supabaseClientProvider reads have a TODO marker', () {
    final source = File(
      'lib/features/attendance/presentation/pages/attendance_detail_page.dart',
    ).readAsStringSync();

    // Find each line containing a supabaseClientProvider read and check that
    // a TODO(sprint-2b) or TODO(sprint-2c) marker appears in the 10 lines
    // immediately preceding it (the same method block).
    final lines = source.split('\n');
    final indices = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains('supabaseClientProvider')) {
        indices.add(i);
      }
    }

    expect(indices.length, equals(2),
        reason: 'Expected exactly 2 remaining supabaseClientProvider reads');

    for (final i in indices) {
      final start = (i - 10).clamp(0, lines.length);
      final window = lines.sublist(start, i + 1).join('\n');
      expect(
        window.contains('TODO(sprint-2b)') || window.contains('TODO(sprint-2c)'),
        isTrue,
        reason: 'Line ${i + 1} has a supabaseClientProvider read without a '
            'nearby TODO(sprint-2b)/TODO(sprint-2c) marker:\n$window',
      );
    }
  });
}
