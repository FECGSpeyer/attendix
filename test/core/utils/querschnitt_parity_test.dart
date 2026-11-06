import 'dart:io';

import 'package:attendix/core/services/holiday_service.dart';
import 'package:attendix/data/models/shift/shift_plan.dart';
import 'package:attendix/data/repositories/files_repository.dart';
import 'package:attendix/features/organisation/presentation/pages/org_person_fields_page.dart';
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

  test('every .order() states its direction (postgrest-dart sorts descending by default)', () {
    // x-95b3cf867d: postgrest-dart 2.x `order()` defaults to ascending: false,
    // postgrest-js (Ionic) to ascending. A bare `.order('col')` is a bug.
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('.g.dart') || file.path.endsWith('.freezed.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        for (final m in RegExp(r"\.order\(([^()]*)\)").allMatches(line)) {
          if (!m.group(1)!.contains('ascending')) offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('org number field default is stored as a string like Ionic (TextValueAccessor)', () {
    expect(numberFieldDefaultText(' 5 '), '5');
    expect(numberFieldDefaultText('2.5'), '2.5');
    // Cleared or invalid → '' (not null: null would make persons show 0).
    expect(numberFieldDefaultText(''), '');
    expect(numberFieldDefaultText('abc'), '');
    expect(numberFieldDefaultText('NaN'), '');
    expect(numberFieldDefaultText('Infinity'), '');
  });
}
