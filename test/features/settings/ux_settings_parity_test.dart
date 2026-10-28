import 'dart:io';

import 'package:attendix/features/settings/presentation/widgets/calendar_subscription_dialog.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX_SETTINGS: the settings screens follow the Ionic information
/// architecture (section order + wording). I18N_INFRA: the wording now
/// comes from the Ionic i18n keys (context.l10n.settings*). These source checks guard the
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
        "title: l10n.settingsVoiceLeader",
        "title: l10n.settingsTenantAdmin",
        "title: l10n.settingsCommunication",
        "title: l10n.settingsUsersRoles",
        "title: l10n.settingsSongsRehearsals",
        "title: l10n.settingsFiles",
        "title: l10n.settingsPlanning",
        "title: l10n.settingsOrganisation",
        "title: l10n.settingsAnalyticsData",
        "title: l10n.settingsSystem",
      ]);
    });

    test('Instanz-Verwaltung items in Ionic order', () {
      expectInOrder(source, [
        "title: l10n.settingsSettings",
        "title: l10n.settingsGroups",
        "title: l10n.settingsTeachers",
        "title: l10n.settingsRolesPerms",
        "title: l10n.settingsConfigureDashboard",
      ]);
    });

    test('System items in Ionic order and logout wording', () {
      expectInOrder(source, [
        "title: l10n.settingsSwitchTenant",
        'const LanguagePickerTile()', // I18N_INFRA: Ionic ion-select "Sprache"
        "title: l10n.settingsNotifications",
        "title: l10n.settingsChangePassword",
        "title: l10n.settingsHelp",
        "title: l10n.settingsGiveFeedback",
        "title: l10n.settingsWhatsNew",
        "title: l10n.settingsLogout",
      ]);
      expect(source, contains('Text(l10n.settingsDeleteAccount)'));
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
