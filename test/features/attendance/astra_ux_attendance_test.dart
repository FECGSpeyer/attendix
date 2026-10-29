import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _src(String p) => File(p).readAsStringSync();

void main() {
  const list = 'lib/features/attendance/presentation/pages/attendance_list_page.dart';

  test('ASTRA_UX1: row deletion only for admin and responsible (not viewer)', () {
    final s = _src(list);
    expect(s, contains('(role.isAdmin || role.isResponsible)'));
    expect(s, isNot(contains('helperToo ? role.canAddAttendance : role.isConductor')));
  });

  test('ASTRA_UX1: viewers get next Termin plus past, no upcoming section', () {
    final s = _src(list);
    expect(s, contains('[if (current != null) current, ...categorized.past]'));
    expect(s, contains('if (staff && categorized.upcoming.isNotEmpty)'));
    expect(s, contains('onTap: staff ? () => _navigateToDetail(att.id!) : null'));
  });

  test('ASTRA_UX3: Termine past midnight can be created', () {
    final s = _src('lib/features/attendance/presentation/pages/attendance_create_page.dart');
    expect(s, isNot(contains('attendanceFlutterEndAfterStart')));
  });

  test('ASTRA_UX: song row opens the in-app song page, not the share route', () {
    final s = _src('lib/features/attendance/presentation/pages/attendance_detail_page.dart');
    expect(s, contains("push('/settings/songs/\${entry.songId}')"));
    expect(s, isNot(contains("push('/songs/\${entry.songId}')")));
  });
}
