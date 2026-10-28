import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/utils/dashboard_utils.dart';
import 'package:attendix/core/utils/demo_guard.dart';
import 'package:attendix/core/utils/duty_utils.dart';
import 'package:attendix/core/utils/event_list_utils.dart';
import 'package:attendix/core/utils/person_matcher.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// I18N lane "core": helpers without BuildContext follow the active
/// language; German output stays unchanged.
void main() {
  setUpAll(() => initializeDateFormatting());
  tearDown(() => setActiveLanguage('de'));

  group('German (default) output unchanged', () {
    test('enum label getters', () {
      expect(AttendanceStatus.present.label, 'Anwesend');
      expect(AttendanceStatus.late.label, 'Verspätet');
      expect(AttendanceStatus.lateExcused.label, 'Verspätet (entsch.)');
    });

    test('event list helpers', () {
      expect(EventListUtils.statusLabel(AttendanceStatus.present), 'Zugesagt');
      expect(EventListUtils.defaultShowAllInfoText,
          'Du bist bei diesem Termin nicht dabei.');
      expect(
        EventListUtils.deadlineText('2000-01-01T10:00:00Z'),
        'Anmeldefrist abgelaufen',
      );
    });

    test('dashboard and duty helpers', () {
      final now = DateTime(2026, 10, 28);
      expect(DashboardUtils.relativeDays(DateTime(2026, 10, 25), now: now),
          'vor 3 Tagen');
      expect(DashboardUtils.tileMonth(DateTime(2026, 3, 1)), 'März');
      expect(weekdayShortNames.first, 'Mo');
      expect(dutyStateLabel(DutyState.confirmed), 'bestätigt');
    });

    test('demo message and match reasons', () {
      expect(kDemoRestrictedMessage,
          'Diese Funktion ist im Demo-Modus nicht verfügbar.');
      expect(MatchReason.swapped, 'Vor-/Nachname vertauscht');
    });
  });

  group('English', () {
    setUp(() => setActiveLanguage('en'));

    test('labels switch with the active language', () {
      expect(AttendanceStatus.present.label, 'Present');
      expect(EventListUtils.statusLabel(AttendanceStatus.present), 'Accepted');
      expect(
        EventListUtils.deadlineText('2000-01-01T10:00:00Z'),
        l10nWithoutContext.signoutDeadlinePassed,
      );
      expect(MatchReason.swapped, 'First/last name swapped');
      expect(
        DashboardUtils.relativeDays(DateTime(2026, 10, 25),
            now: DateTime(2026, 10, 28)),
        '3 days ago',
      );
      expect(weekdayLongNames.first, 'Monday');
      expect(monthNames[2], 'March');
    });
  });
}
