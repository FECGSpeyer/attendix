import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source code verification tests for AttendanceTypeEditPage TimePicker
///
/// Ensures that the time input uses TimePicker instead of plain TextFormField.
/// This is a UX improvement to match the pattern used in attendance_create_page.dart.
void main() {
  late String pageSource;

  setUpAll(() {
    final file = File(
      'lib/features/settings/presentation/pages/attendance_type_edit_page.dart',
    );
    pageSource = file.readAsStringSync();
  });

  group('AttendanceTypeEditPage - Time Input', () {
    test('uses showTimePicker for time selection', () {
      // Should have a method that calls showTimePicker
      expect(
        pageSource,
        contains('showTimePicker'),
        reason: 'Time selection should use showTimePicker instead of TextFormField',
      );
    });

    test('has TimeOfDay state for start and end time', () {
      // Should use TimeOfDay state variables instead of TextEditingController
      expect(
        pageSource,
        contains('TimeOfDay'),
        reason: 'Should use TimeOfDay type for time handling',
      );
    });

    test('time section uses tappable widgets, not TextFormField', () {
      // Find the Time Settings section
      final timeSectionMatch = RegExp(
        // UX_SETTINGS: Beginn/Ende tiles inside "Optionen" (Ionic order)
        r"title:\s*Text\(context\.l10n\.typeSettingsStart\).*?_pickTime\(isStart: false\)",
        dotAll: true,
      ).firstMatch(pageSource);

      expect(
        timeSectionMatch,
        isNotNull,
        reason: 'Time section should exist',
      );

      if (timeSectionMatch != null) {
        final timeSection = timeSectionMatch.group(0)!;

        // Should NOT have TextFormField for time input
        expect(
          timeSection,
          isNot(contains('TextFormField')),
          reason: 'Time section should NOT use TextFormField - use tappable widgets with TimePicker instead',
        );

        // Should have onTap handler for TimePicker
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
