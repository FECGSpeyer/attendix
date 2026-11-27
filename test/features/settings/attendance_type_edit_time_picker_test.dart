import 'package:flutter_test/flutter_test.dart';
import '../../helpers/source_reader.dart';

/// Source code verification tests for AttendanceTypeEditPage TimePicker
///
/// Ensures that the time input uses TimePicker instead of plain TextFormField.
/// This is a UX improvement to match the pattern used in attendance_create_page.dart.
void main() {
  late String pageSource;
  late String betaSource;

  setUpAll(() {
    pageSource = readDartLibrary('lib/features/settings/presentation/pages/attendance_type_edit_page.dart');
    betaSource = readDartLibrary('lib/features/settings/presentation/pages/attendance_type_edit_view.dart');
  });

  group('AttendanceTypeEditPage - Time Input', () {
    test('uses showTimePicker for time selection', () {
      expect(
        pageSource,
        contains('showAppTimePicker'),
        reason: 'Time selection should use showTimePicker instead of TextFormField',
      );
    });

    test('has TimeOfDay state for start and end time', () {
      expect(
        pageSource,
        contains('TimeOfDay'),
        reason: 'Should use TimeOfDay type for time handling',
      );
    });

    test('time section uses tappable widgets, not TextFormField', () {
      final timeSectionMatch = RegExp(
        r'title:\s*l10n\.rdTypeTime.*?_pickTime\(isStart: false\)',
        dotAll: true,
      ).firstMatch(betaSource);

      expect(
        timeSectionMatch,
        isNotNull,
        reason: 'Time section should exist',
      );

      if (timeSectionMatch != null) {
        final timeSection = timeSectionMatch.group(0)!;

        expect(
          timeSection,
          isNot(contains('TextFormField')),
          reason: 'Time section should NOT use TextFormField - use tappable widgets with TimePicker instead',
        );

        expect(
          timeSection,
          contains('RdValueBox'),
          reason: 'Time section should use tappable RdValueBox widgets',
        );

        expect(
          timeSection,
          contains('onTap'),
          reason: 'Time widgets should be tappable to open TimePicker',
        );
      }
    });

    test('has _pickTime method like attendance_create_page', () {
      // Should have a _pickTime method
      expect(
        pageSource,
        contains('_pickTime'),
        reason: 'Should have _pickTime method like attendance_create_page.dart',
      );
    });

    test('has time formatting helpers', () {
      // Should have helper methods for time formatting
      final hasFormatTime = pageSource.contains('_formatTime') ||
                            pageSource.contains('formatTime');
      expect(
        hasFormatTime,
        isTrue,
        reason: 'Should have time formatting helper method',
      );
    });
  });
}
