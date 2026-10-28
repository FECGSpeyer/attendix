import 'dart:io';

import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX_PEOPLE: source checks that the people/groups/teachers screens keep the
/// Ionic information architecture and wording. Since the i18n migration the
/// screens use the Ionic transloco keys (l10n), so the checks look for keys;
/// the German texts are checked once against the generated German ARB.
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
      for (final key in [
        'l10n.peopleShowAll',
        'l10n.peopleActivePeople',
        'l10n.peopleProblemCases',
        'l10n.peopleWithoutAccount',
        'l10n.peopleAttendanceAsc',
        'l10n.peopleJoinDesc',
        'l10n.peopleNextBirthday',
        'l10n.attendanceChurchOverview',
        'l10n.peopleBulkEdit',
        'l10n.peopleImportPeople',
        'l10n.peopleReorder',
      ]) {
        expect(src, contains(key), reason: key);
      }
    });

    test('list header, badges and remove flow use Ionic texts', () {
      expect(src, contains('l10n.peoplePeopleCount(sortedPeople.length)'));
      expect(src, contains('l10n.peopleSearchPerson'));
      expect(src, contains('l10n.peopleVoiceLeader'));
      expect(src, contains('l10n.peopleProblemCase'));
      expect(src, contains('l10n.peopleRemoveConfirm'));
      expect(src, contains('l10n.peopleReactivateConfirm'));
      expect(src, contains('l10n.peopleCannotRemoveSelf'));
    });
  });

  test('Person detail uses Ionic title and remove alert', () {
    final src = read('lib/features/people/presentation/pages/person_detail_page.dart');
    expect(src, contains('l10n.personEditPerson'));
    expect(src, contains('l10n.attendanceRemovePerson'));
    expect(src, contains('l10n.personTransferOther'));
  });

  test('Groups list uses Ionic title, badges and add sheet', () {
    final src = read('lib/features/instruments/presentation/pages/instruments_list_page.dart');
    expect(src, contains('l10n.instrumentsGroupsCount(count)'));
    expect(src, contains('l10n.instrumentsAddGroup'));
    expect(src, contains('l10n.instrumentsUpdate'));
    expect(src, contains('l10n.instrumentsDeleteGroup'));
  });

  test('Teachers list uses Ionic texts', () {
    final src = read('lib/features/teachers/presentation/pages/teachers_list_page.dart');
    expect(src, contains('title: context.l10n.teachersTitle,'));
    expect(src, contains('l10n.teachersPlayerCount(count)'));
    expect(src, contains('l10n.teachersAdd'));
    expect(src, contains('l10n.teachersUpdate'));
    expect(src, contains('l10n.teachersPrivate'));
  });

  test('German texts of the used keys stay the Ionic wording', () {
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
      'lib/features/members',
      'lib/features/voice_leader',
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
