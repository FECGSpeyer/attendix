import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/optional_tabs_providers.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/settings/presentation/widgets/type_reminders_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shift_excused_as_present (Ionic Utils.getPercentage)', () {
    test('work-excused counts only when the flag is set', () {
      const s = AttendanceStatus.excused;
      expect(s.countsAsAttended(notes: 'Schichtbedingt'), isFalse);
      expect(
          s.countsAsAttended(notes: 'Schichtbedingt', shiftExcusedAsPresent: true),
          isTrue);
      expect(
          s.countsAsAttended(notes: 'Arbeitsbedingt', shiftExcusedAsPresent: true),
          isTrue);
      expect(s.countsAsAttended(notes: 'Krank', shiftExcusedAsPresent: true), isFalse);
    });

    test('absent with shift note never counts', () {
      expect(
          AttendanceStatus.absent
              .countsAsAttended(notes: 'Schichtbedingt', shiftExcusedAsPresent: true),
          isFalse);
    });

    test('present/late/lateExcused always count', () {
      for (final s in [
        AttendanceStatus.present,
        AttendanceStatus.late,
        AttendanceStatus.lateExcused,
      ]) {
        expect(s.countsAsAttended(), isTrue);
      }
    });

    test('Tenant parses shift_excused_as_present', () {
      final t = Tenant.fromJson({
        'shortName': 'A',
        'longName': 'B',
        'shift_excused_as_present': true,
      });
      expect(t.shiftExcusedAsPresent, isTrue);
      expect(Tenant.fromJson({'shortName': 'A', 'longName': 'B'}).shiftExcusedAsPresent,
          isFalse);
    });
  });

  group('TypeRemindersEditor validation (Ionic addReminder)', () {
    test('rejects negative, >168, duplicates and a 4th reminder', () {
      expect(TypeRemindersEditor.validate([], -1), isNotNull);
      expect(TypeRemindersEditor.validate([], null), isNotNull);
      expect(TypeRemindersEditor.validate([], 169), isNotNull);
      expect(TypeRemindersEditor.validate([24], 24), 'Diese Erinnerung existiert bereits');
      expect(TypeRemindersEditor.validate([1, 24, 48], 72),
          'Maximal 3 Erinnerungen pro Typ möglich');
      expect(TypeRemindersEditor.validate([1], 0), isNull);
      expect(TypeRemindersEditor.validate([], 168), isNull);
    });

    test('formats like Ionic getFormattedReminder', () {
      expect(TypeRemindersEditor.format(0), 'Zur gleichen Zeit');
      expect(TypeRemindersEditor.format(1), '1 Stunde vorher');
      expect(TypeRemindersEditor.format(12), '12 Stunden vorher');
      expect(TypeRemindersEditor.format(24), '1 Tag vorher');
      expect(TypeRemindersEditor.format(72), '3 Tage vorher');
    });
  });

  group('optional tabs (Ionic user_metadata keys)', () {
    test('reads per-tenant flags', () {
      final tabs = optionalTabsFromMetadata({
        'showSongsTab_5': true,
        'showOrgPlansTab_6': true,
      }, 5);
      expect(tabs.songs, isTrue);
      expect(tabs.orgPlans, isFalse);
      expect(songsTabKey(5), 'showSongsTab_5');
      expect(orgPlansTabKey(7), 'showOrgPlansTab_7');
    });

    test('defaults to hidden without metadata', () {
      final tabs = optionalTabsFromMetadata(null, 1);
      expect(tabs.songs, isFalse);
      expect(tabs.orgPlans, isFalse);
    });
  });
}
