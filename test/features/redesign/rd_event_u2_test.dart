import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Termin page uses the shared Ablauf viewer and binds the tenant repo before delete', () {
    final page = File('lib/features/redesign/presentation/pages/rd_event_page.dart').readAsStringSync();
    final sections = File('lib/features/redesign/presentation/widgets/event/rd_event_sections.dart').readAsStringSync();
    expect(sections, contains('openAttendancePlanViewer(context, att)'));
    expect(page, contains('final repo = ref.read(attendanceRepositoryWithTenantProvider);'));
  });
}
