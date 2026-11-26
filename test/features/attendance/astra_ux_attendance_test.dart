import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _src(String p) => File(p).readAsStringSync();

void main() {
  test('ASTRA_UX1: event deletion only for admin and responsible (not viewer)', () {
    final s = _src('lib/features/redesign/presentation/pages/rd_event_edit_page.dart');
    expect(s, contains('if (role.isAdmin || role.isResponsible)'));
    expect(s, contains("Key('rd-event-delete')"));
  });

  test('ASTRA_UX1: viewers cannot open Termin detail from list', () {
    final s = _src('lib/features/redesign/presentation/pages/rd_events_page.dart');
    expect(s, contains('final canOpen = role.canAddAttendance;'));
    expect(s, contains('onTap: a.id != null && canOpen'));
  });

  test('ASTRA_UX: song row opens the in-app work page, not the share route', () {
    final s = _src('lib/features/redesign/presentation/widgets/event/rd_event_sections.dart');
    expect(s, contains('RedesignRoutes.work(entry.songId)'));
    expect(s, isNot(contains("push('/songs/\${entry.songId}')")));
  });
}
