import 'dart:io';

import 'package:attendix/features/settings/presentation/widgets/calendar_subscription_dialog.dart';
import 'package:attendix/features/settings/presentation/widgets/settings_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
      expect(source, contains('l10n.settingsDeleteAccount,'));
    });

    test('Kalender abonnieren opens the Ionic alert instead of a page', () {
      expect(source, contains('showCalendarSubscriptionDialog(context, ref)'));
    });

    // IOS_MEHR (wave 8)
    test('System block has no "E-Mail ändern" row (Ionic has none)', () {
      expect(source, isNot(contains('settingsFlutterChangeEmail')));
      expect(source, isNot(contains('showChangeEmailDialog')));
    });

    test('ionicons: library-outline, apps-outline, musical-notes, chatbubble-ellipses', () {
      expect(source, contains('iconWidget: const IonLibraryOutlineIcon()'));
      expect(source, contains('icon: CupertinoIcons.circle_grid_3x3'));
      expect(source, contains('icon: CupertinoIcons.music_note_2'));
      expect(source, contains('icon: Icons.sms_outlined'));
      final lang = read('lib/features/settings/presentation/widgets/language_picker_tile.dart');
      expect(lang, contains('icon: Icons.translate'));
      expect(lang, contains('IonSelectIcon(')); // IOS_THEME2: chevron-expand
    });

    test('logout row has no chevron, delete link below the System card', () {
      final logout = source.indexOf('title: l10n.settingsLogout');
      final block = source.substring(logout, source.indexOf('onTap:', logout));
      expect(block, contains('detail: false'));
      expect(block, contains('background: AppColors.danger'));
      expectInOrder(source, [
        'title: l10n.settingsSystem',
        "context.push('/settings/delete-account')",
        'decoration: TextDecoration.underline',
      ]);
    });
  });

  group('Ionic iOS inset list (IOS_MEHR)', () {
    Widget app(Widget child) => MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(body: child),
        );

    testWidgets('separators are inset on both sides', (tester) async {
      await tester.pumpWidget(app(const IonInsetGroup(
        dividerIndent: IonIos.iconDividerIndent,
        children: [ListTile(title: Text('a')), ListTile(title: Text('b'))],
      )));
      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.indent, IonIos.iconDividerIndent);
      expect(divider.endIndent, IonIos.itemPaddingEnd);
    });

    testWidgets('detail=false rows show no chevron; iconWidget is used', (tester) async {
      await tester.pumpWidget(app(IonInsetGroup(children: [
        SettingsListTile(
          icon: Icons.logout,
          title: 'Ausloggen',
          detail: false,
          background: Colors.red,
          onTap: () {},
        ),
        SettingsListTile(
          iconWidget: const IonLibraryOutlineIcon(),
          title: 'Werke',
          onTap: () {},
        ),
      ])));
      expect(find.byType(IonDetailChevron), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Ausloggen'),
          matching: find.byIcon(CupertinoIcons.chevron_forward),
        ),
        findsNothing,
      );
      expect(find.byType(IonLibraryOutlineIcon), findsOneWidget);
      expect(tester.getSize(find.byType(IonLibraryOutlineIcon)), const Size.square(IonIos.itemIconSize));
    });
  });

  test('Allgemeine Einstellungen sections in Ionic order', () {
    final source = read('lib/features/settings/presentation/pages/general_settings_page.dart');
    expectInOrder(source, [
      'title: context.l10n.generalSettingsGeneral,',
      'title: context.l10n.generalSettingsAttendance,',
      'title: context.l10n.generalSettingsReasons,',
      'title: context.l10n.generalSettingsRegistration,',
      'title: context.l10n.generalSettingsSongDb,',
      'title: context.l10n.generalSettingsOther,',
      'title: context.l10n.generalSettingsCriticalRules,',
    ]);
    // Typen + Schichtpläne live under "Anwesenheiten" like in Ionic
    expectInOrder(source, ['generalSettingsAttTypes', "'/settings/types'", 'generalSettingsShiftPlans', "'/settings/shifts'"]);
  });

  test('Termintyp sections in Ionic order', () {
    final source = read('lib/features/settings/presentation/pages/attendance_type_edit_page.dart');
    expectInOrder(source, [
      'title: context.l10n.typeSettingsOptions,',
      '_buildDutySection(),',
      'title: context.l10n.typeSettingsEventReminders,',
      'title: context.l10n.typeSettingsAppearance,',
      '_buildRelevantGroupsSection(),',
      'title: context.l10n.typeSettingsRunSheet,',
      'title: context.l10n.typeSettingsChecklist,',
      'title: context.l10n.typeSettingsSignupFields,',
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
