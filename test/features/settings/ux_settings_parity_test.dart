import 'dart:io';

import 'package:attendix/features/settings/presentation/widgets/calendar_subscription_dialog.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX_SETTINGS: the settings screens follow the Ionic information
/// architecture (section order + wording). These source checks guard the
/// order so later edits don't silently drift away from Ionic again.
void main() {
  String read(String path) => File(path).readAsStringSync();

  void expectInOrder(String source, List<String> needles) {
    var last = -1;
    for (final n in needles) {
      final idx = source.indexOf(n, last + 1);
      expect(idx, greaterThan(last), reason: '"$n" missing or out of Ionic order');
      last = idx;
    }
  }

  group('Einstellungen (settings.page.html)', () {
    late String source;
    setUpAll(() => source = read('lib/features/settings/presentation/pages/settings_page.dart'));

    test('sections appear in Ionic order', () {
      expectInOrder(source, [
        "title: 'Stimmführer'",
        "title: 'Instanz-Verwaltung'",
        "title: 'Kommunikation'",
        "title: 'Benutzer & Rollen'",
        "title: 'Werke & Proben'",
        "title: 'Dateien'",
        "title: 'Planung'",
        "title: 'Organisation'",
        "title: 'Auswertung & Daten'",
        "title: 'System'",
      ]);
    });

    test('Instanz-Verwaltung items in Ionic order', () {
      expectInOrder(source, [
        "title: 'Einstellungen'",
        "title: 'Gruppen'",
        "title: 'Lehrer'",
        "title: 'Rollen & Berechtigungen'",
        "title: 'Dashboard konfigurieren'",
      ]);
    });

    test('System items in Ionic order and logout wording', () {
      expectInOrder(source, [
        "title: 'Instanz wechseln'",
        "title: 'Benachrichtigungen'",
        "title: 'Passwort ändern'",
        "title: 'Hilfe'",
        "title: 'Feedback geben'",
        "title: 'Was ist neu?'",
        "title: 'Ausloggen'",
      ]);
      expect(source, contains("const Text('Konto löschen')"));
    });

    test('Kalender abonnieren opens the Ionic alert instead of a page', () {
      expect(source, contains('showCalendarSubscriptionDialog(context, ref)'));
    });
  });

  test('Allgemeine Einstellungen sections in Ionic order', () {
    final source = read('lib/features/settings/presentation/pages/general_settings_page.dart');
    expectInOrder(source, [
      "title: 'Allgemein'",
      "title: 'Anwesenheiten'",
      "title: 'Abwesenheits- & Verspätungsgründe'",
      "title: 'Registrierung'",
      "title: 'Werk-Datenbank'",
      "title: 'Sonstiges'",
      "title: 'Problemfall-Regeln'",
    ]);
    // Typen + Schichtpläne live under "Anwesenheiten" like in Ionic
    expectInOrder(source, ["'Anwesenheits-Typen'", "'/settings/types'", "'Schichtpläne'", "'/settings/shifts'"]);
  });

  test('Termintyp sections in Ionic order', () {
    final source = read('lib/features/settings/presentation/pages/attendance_type_edit_page.dart');
    expectInOrder(source, [
      "title: 'Optionen'",
      '_buildDutySection(),',
      "title: 'Terminerinnerungen'",
      "title: 'Darstellung'",
      '_buildRelevantGroupsSection(),',
      "title: 'Ablaufplan'",
      "title: 'Checkliste'",
      "title: 'Anmeldefelder'",
    ]);
  });

  group('calendarSubscriptionLink', () {
    setUpAll(() => dotenv.testLoad(fileInput: 'SUPABASE_URL=https://abc.supabase.co'));

    test('tenant feed uses the ical-tenant edge function', () {
      expect(
        calendarSubscriptionLink(tenantId: 42),
        'https://abc.supabase.co/functions/v1/ical-tenant?tenantId=42',
      );
    });

    test('personal feed appends personId', () {
      expect(
        calendarSubscriptionLink(tenantId: 42, personId: 7),
        'https://abc.supabase.co/functions/v1/ical-tenant?tenantId=42&personId=7',
      );
    });
  });
}
