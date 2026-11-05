import 'package:attendix/core/services/holiday_service.dart';
import 'package:attendix/data/models/shift/shift_plan.dart';
import 'package:attendix/data/repositories/files_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file names fold like Ionic NFKD (Wędrówka, NFD März)', () {
    expect(FilesRepository.sanitizeSegment('Wędrówka'), 'Wedrowka');
    expect(FilesRepository.sanitizeSegment('März'), 'Marz');
    expect(FilesRepository.sanitizeSegment('März'), 'Maerz');
  });

  test('holiday is gone once its start day is before today (Ionic)', () {
    final now = DateTime(2026, 11, 4, 15);
    expect(isHolidayGone(DateTime(2026, 11, 4), now), isFalse);
    expect(isHolidayGone(DateTime(2026, 11, 3), now), isTrue);
  });

  test('shift segments are sorted by index, stable (Ionic loadShifts)', () {
    final plan = ShiftPlan.fromJson({
      'name': 'S',
      'definition': [
        {'index': 2, 'repeat_count': 1, 'start_time': 'a'},
        {'index': 0, 'repeat_count': 1, 'start_time': 'b'},
        {'index': 2, 'repeat_count': 1, 'start_time': 'c'},
      ],
    });
    expect(plan.definition.map((d) => d.startTime), ['b', 'a', 'c']);
  });
}
