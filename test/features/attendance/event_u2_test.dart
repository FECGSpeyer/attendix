
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/source_reader.dart';

void main() {
  test('Termin page uses the shared Ablauf viewer and binds the tenant repo before delete', () {
    final page = readDartLibrary('lib/features/attendance/presentation/pages/event_page.dart');
    final sections = readDartLibrary('lib/features/attendance/presentation/widgets/event/event_sections.dart');
    expect(sections, contains('openAttendancePlanViewer(context, att)'));
    expect(page, contains('final repo = ref.read(attendanceRepositoryWithTenantProvider);'));
  });
}
