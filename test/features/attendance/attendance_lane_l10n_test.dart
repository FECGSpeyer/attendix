import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/status_chip.dart';
import 'package:attendix/features/export/export_fields.dart';
import 'package:attendix/features/history/history_utils.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// i18n lane "attendance": attendance, history, statistics, export.
void main() {
  tearDown(() => setActiveLanguage('de'));

  group('labels follow the active language', () {
    test('German stays the default', () {
      expect(rehearsalsLabel(1), '1 Probe');
      expect(ionicStatusLabel(AttendanceStatus.late), 'Verspätet');
      expect(exportFieldLabel('Vorname'), 'Vorname');
      expect(exportFieldLabel('Anwesenheit %'), 'Anwesenheit %');
    });

    test('English after switching the language', () {
      setActiveLanguage('en');
      expect(rehearsalsLabel(3), '3 rehearsals');
      expect(ionicStatusLabel(AttendanceStatus.present), 'Present');
      expect(exportFieldLabel('Vorname'), 'First name');
      // Extra fields / custom columns keep their name
      expect(exportFieldLabel('Lieblingsfarbe'), 'Lieblingsfarbe');
    });

    test('export sort options use translated labels but German ids', () {
      setActiveLanguage('en');
      final options = exportSortOptions('player', const []);
      expect(options.first.value, 'nachname');
      expect(options.first.label, 'Last name');
    });
  });

  test('lane pages contain no hard-coded German UI literals', () {
    const files = [
      'lib/features/attendance/presentation/pages/attendance_list_page.dart',
      'lib/features/attendance/presentation/pages/attendance_create_page.dart',
      'lib/features/attendance/presentation/pages/attendance_detail_page.dart',
      'lib/features/history/presentation/pages/history_page.dart',
      'lib/features/statistics/presentation/pages/statistics_page.dart',
      'lib/features/export/presentation/pages/export_page.dart',
    ];
    final literal = RegExp(r"(Text|tooltip:|title:|label:|showSuccess\(context,|showError\(context,|showWarning\(context,)\s*\(?'[^']*[äöüÄÖÜß][^']*'");
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(literal.hasMatch(source), isFalse, reason: path);
    }
  });
}
