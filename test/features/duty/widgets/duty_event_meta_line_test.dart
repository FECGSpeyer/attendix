import 'package:attendix/data/repositories/duty_repository.dart';
import 'package:attendix/features/duty/presentation/widgets/self_service_duty_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../factories/test_factories.dart';

/// Issue #337: duty cards ("Bitte bestätigen", "Nächster Dienst") show the
/// date line like Ionic getEventMeta(att, true, false) – with year and end time.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  DutyTermin termin({String? start, String? end}) => DutyTermin(
        attendance: TestFactories.createAttendance(id: 1, tenantId: 7, date: '2026-11-05T12:00:00')
            .copyWith(startTime: start, endTime: end),
        type: TestFactories.createAttendanceType(id: 'd', name: 'Dienst')
            .copyWith(startTime: null, endTime: null, allDay: false),
        required: 2,
        occupied: 1,
        persons: const [],
      );

  test('date with year and start–end time', () {
    expect(dutyEventMetaLine(termin(start: '19:00:00', end: '21:00:00')), 'Do., 05.11.2026 · 19:00–21:00');
  });

  test('without end time only the start time', () {
    expect(dutyEventMetaLine(termin(start: '19:00')), 'Do., 05.11.2026 · 19:00');
  });
}
