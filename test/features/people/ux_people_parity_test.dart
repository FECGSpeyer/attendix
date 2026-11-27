import 'dart:io';

import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX_PEOPLE: source checks that the people/groups/teachers screens keep the
/// Ionic information architecture and wording. Since the i18n migration the
/// screens use the Ionic transloco keys (l10n), so the checks look for keys;
/// the German texts are checked once against the generated German ARB.
void main() {
  test('German texts of the core people/groups/teachers l10n keys stay intact', () {
    final de = lookupAppLocalizations(const Locale('de'));
    expect(de.peopleShowAll, 'Alle Anzeigen');
    expect(de.peoplePeopleCount(3), 'Personen (3)');
    expect(de.personEditPerson, 'Person bearbeiten');
    expect(de.attendanceRemovePerson, 'Person entfernen');
    expect(de.instrumentsGroupsCount(4), 'Gruppen (4)');
    expect(de.teachersTitle, 'Lehrer');
    expect(de.teachersPlayerCount(2), '2 Spieler');
    expect(de.teachersUpdate, 'Lehrer updaten');
  });

  test('lane folders contain no hard-coded German UI texts', () {
    // I18N people lane: Flutter-only strings live in lib/l10n/fragments/people.json.
    for (final dir in [
      'lib/features/people',
      'lib/features/instruments',
      'lib/features/teachers',
    ]) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        for (final literal in [
          "'Abbrechen'",
          "'Speichern'",
          "'Löschen'",
          "'Erneut versuchen'",
          "'Fehler: \$e'",
        ]) {
          expect(src, isNot(contains(literal)), reason: '${f.path}: $literal');
        }
      }
    }
  });
}
