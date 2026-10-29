import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/people/people_list_utils.dart';
import 'package:attendix/features/people/presentation/widgets/pause_person_sheet.dart';
import 'package:attendix/features/people/presentation/widgets/person_detail/historie_accordion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNewPerson', () {
    final now = DateTime(2026, 10, 28, 12);
    test('joined within the last month is new', () {
      expect(isNewPerson(const Person(joined: '2026-10-10'), now: now), isTrue);
    });
    test('joined earlier is not new', () {
      expect(isNewPerson(const Person(joined: '2026-09-01'), now: now), isFalse);
    });
    test('no join date is not new', () {
      expect(isNewPerson(const Person(), now: now), isFalse);
    });
  });

  test('accountRoleForGroup: main group → responsible', () {
    expect(accountRoleForGroup(1, 1), Role.responsible);
    expect(accountRoleForGroup(2, 1), Role.player);
    expect(accountRoleForGroup(2, null), Role.player);
  });

  group('buildPauseHistoryText', () {
    test('only reason', () {
      expect(buildPauseHistoryText('Urlaub'), 'Urlaub');
    });
    test('from and until', () {
      expect(
        buildPauseHistoryText('Urlaub',
            from: DateTime(2026, 1, 5), until: DateTime(2026, 2, 1)),
        'Urlaub (ab 05.01.2026 bis 01.02.2026)',
      );
    });
  });

  group('history entry labels (Ionic PlayerHistoryType codes)', () {
    final date = DateTime(2026, 3, 4, 9, 30);
    test('titles', () {
      expect(historyEntryTitle(1, date), 'Pausiert am 04.03.2026 09:30');
      expect(historyEntryTitle(5, date), 'Notiz geändert am 04.03.2026 09:30');
      expect(historyEntryTitle(6, date), 'Wieder aktiv seid 04.03.2026 09:30'); // Ionic person.activeSince (sic)
      expect(historyEntryTitle(8, date), 'Archiviert am 04.03.2026');
      expect(historyEntryTitle(9, date), 'Reaktiviert am 04.03.2026');
      expect(historyEntryTitle(10, date), 'Übertragen am 04.03.2026');
      expect(historyEntryTitle(13, date), 'Kopiert am 04.03.2026');
      expect(historyEntryTitle(7, date), '04.03.2026');
    });
    test('bodies', () {
      expect(historyEntryBody(5, 'alt'), 'alt');
      expect(historyEntryBody(1, 'Urlaub'), 'Pausiert: Urlaub');
      expect(historyEntryBody(7, 'A -> B'), 'Wechsel: A -> B');
      expect(historyEntryBody(14, ''), 'Sonstiges: Keine Anmerkung');
      expect(historyEntryBody(6, 'x'), '');
      expect(historyEntryBody(11, 'nach X'), 'nach X');
    });
  });
}
