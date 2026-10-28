import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// UX_PEOPLE: source checks that the people/groups/teachers screens keep the
/// Ionic information architecture and wording.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('People list (Ionic people/list)', () {
    final src = read('lib/features/people/presentation/pages/people_list_page.dart');

    test('Gemeinde-Übersicht opens the church overview sheet', () {
      expect(src, contains('showChurchOverviewSheet('));
      expect(src, contains('churchIdOf('));
      expect(src, isNot(contains('Gemeinde-Übersicht ist noch nicht verfügbar')));
    });

    test('options popover holds filter, sort, view and admin actions', () {
      for (final label in [
        "'Alle Anzeigen'",
        "'Aktive Personen'",
        "'Problemfälle'",
        "'Ohne Account'",
        "'Anwesenheit ↑'",
        "'Beitrittsdatum ↓'",
        "'Nächster Geburtstag'",
        "'Gemeinde-Übersicht'",
        "'Bulk-Bearbeitung'",
        "'Personen importieren'",
        "'Reihenfolge anpassen'",
      ]) {
        expect(src, contains(label), reason: label);
      }
    });

    test('list header, badges and remove flow use Ionic texts', () {
      expect(src, contains("'Personen (\${sortedPeople.length})'"));
      expect(src, contains("'Person suchen...'"));
      expect(src, contains("'Stimmführer'"));
      expect(src, contains("'Problemfall'"));
      expect(src, contains("'Person wirklich entfernen?'"));
      expect(src, contains("'Person wieder aktivieren?'"));
      expect(src, contains("'Du kannst dich nicht selbst entfernen!'"));
    });
  });

  test('Person detail uses Ionic title and remove alert', () {
    final src = read('lib/features/people/presentation/pages/person_detail_page.dart');
    expect(src, contains("'Person bearbeiten'"));
    expect(src, contains("'Person entfernen'"));
    expect(src, contains("'In andere Instanz übertragen'"));
  });

  test('Groups list uses Ionic title, badges and add sheet', () {
    final src = read('lib/features/instruments/presentation/pages/instruments_list_page.dart');
    expect(src, contains("'Gruppen (\$count)'"));
    expect(src, contains("'Gruppe hinzufügen'"));
    expect(src, contains("'Aktualisieren'"));
    expect(src, contains("'Gruppe wirklich löschen?'"));
  });

  test('Teachers list uses Ionic texts', () {
    final src = read('lib/features/teachers/presentation/pages/teachers_list_page.dart');
    expect(src, contains("AppBar(title: const Text('Lehrer'))"));
    expect(src, contains("'\$count Spieler'"));
    expect(src, contains("'Lehrer hinzufügen'"));
    expect(src, contains("'Lehrer updaten'"));
    expect(src, contains("'Privatlehrer'"));
  });
}
