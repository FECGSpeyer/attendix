import 'dart:io';

import 'package:attendix/features/auth/presentation/widgets/ion_form_list.dart'
    as auth;
import 'package:attendix/features/settings/presentation/widgets/settings_list.dart';
import 'package:attendix/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' as shared;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// IOS_SETTINGS2: Mehr tab opens the Ionic inline sheets, creates missing
/// accounts directly (Ionic alert) and has no Flutter-only extras; the
/// inset list metrics follow @rdlabo/ionic-theme-ios26 9.4 (20 / 28 / 53).
void main() {
  String read(String path) => File(path).readAsStringSync();
  const settingsPath = 'lib/features/settings/presentation/pages/settings_page.dart';

  group('Mehr entry points (settings.page.html)', () {
    late String source;
    setUpAll(() => source = read(settingsPath));

    test('pending / viewers / parents / archive / instances open sheets', () {
      expect(source, contains('onTap: () => showPendingPersonsSheet(context)'));
      expect(source, contains('onTap: () => showViewersSheet(context)'));
      expect(source, contains('onTap: () => showParentsSheet(context)'));
      expect(source, contains('onTap: () => showArchiveSheet(context)'));
      expect(source, contains('void openTenants() => showTenantsSheet(context);'));
      for (final route in [
        "'/settings/pending'",
        "'/settings/viewers'",
        "'/settings/parents'",
        "'/settings/left'",
        "context.go('/tenants')",
      ]) {
        expect(source, isNot(contains(route)), reason: route);
      }
    });

    test('Ionic breakpoints: archive + instances half sheet, others full', () {
      final left = read('lib/features/settings/presentation/pages/left_players_page.dart');
      final tenants = read('lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart');
      expect(left, contains('initialBreakpoint: 0.5'));
      expect(tenants, contains('initialBreakpoint: 0.5'));
      for (final path in [
        'lib/features/settings/presentation/pages/pending_players_page.dart',
        'lib/features/settings/presentation/pages/viewers_page.dart',
        'lib/features/settings/presentation/pages/parents_page.dart',
        'lib/features/settings/presentation/widgets/settings_admins_sheet.dart',
      ]) {
        final src = read(path);
        expect(src, contains('showSettingsSheet<void>('), reason: path);
        expect(src, isNot(contains('initialBreakpoint')), reason: path);
      }
    });

    test('"Fehlende Accounts erstellen" asks and creates directly', () {
      expect(source, contains('createMissingAccounts(context, ref, playersWithoutAccount)'));
      expect(source, contains('title: l10n.settingsCreateAccounts'));
      expect(source, contains('l10n.settingsCreateAccountsMessage('));
      expect(source, contains('confirmText: l10n.settingsContinue'));
      expect(source, contains('.createAccounts(players, stopOnError: true)'));
      expect(source, contains('l10n.settingsCreateAccountsFailed('));
      expect(source, contains('l10n.settingsAccountsCreated'));
      final notifier = read('lib/core/providers/user_registration_providers.dart');
      expect(notifier, contains('if (stopOnError) break;'));
    });

    test('no Flutter-only extras (Benutzerverwaltung, Bewerber-, PWA-Hinweis)', () {
      expect(source, isNot(contains("'/settings/users'")));
      expect(source, isNot(contains('settingsFlutterUsers')));
      expect(source, isNot(contains('_ApplicantHint')));
      expect(source, isNot(contains('_PwaInstallHint')));
      expect(source, isNot(contains('batch-accounts')));
      final router = read('lib/core/router/app_router.dart');
      expect(router, isNot(contains('batch-accounts')));
      expect(
        File('lib/features/settings/presentation/pages/batch_account_creation_page.dart').existsSync(),
        isFalse,
      );
    });
  });

  group('ios26 inset list metrics', () {
    test('settings, auth and shared use 20 / 28 / 53', () {
      expect(shared.IonIos.insetMargin, 20);
      expect(shared.IonIos.groupRadius, 28);
      expect(shared.IonIos.itemMinHeight, 53);
      expect(IonIos.insetMargin, shared.IonIos.insetMargin);
      expect(IonIos.groupRadius, shared.IonIos.groupRadius);
      expect(IonIos.itemMinHeight, shared.IonIos.itemMinHeight);
      expect(IonIos.itemPaddingEnd, 16);
    });

    testWidgets('auth helpers and settings margin agree on iOS', (tester) async {
      late double authMargin, authRadius, settingsMargin;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Builder(builder: (context) {
          authMargin = auth.ionInsetMargin(context);
          authRadius = auth.ionInsetRadius(context);
          settingsMargin = ionListMargin(context);
          return const SizedBox();
        }),
      ));
      expect(authMargin, 20);
      expect(authRadius, 28);
      expect(settingsMargin, 20);
    });

    testWidgets('inset group rows are 53pt high on iOS', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const Scaffold(
          body: IonInsetGroup(children: [ListTile(title: Text('a'))]),
        ),
      ));
      expect(tester.getSize(find.byType(ListTile)).height, 53);
    });
  });

  group('showSettingsSheet', () {
    Future<void> open(WidgetTester tester, double breakpoint) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsSheet<void>(
                context,
                initialBreakpoint: breakpoint,
                builder: (context) => Scaffold(
                  appBar: settingsSheetBar(context, title: 'Beobachter'),
                  body: ListView(children: const [Text('row')]),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('full sheet: title only, no close button', (tester) async {
      await open(tester, 1);
      expect(find.byType(IonModalHeader), findsOneWidget);
      expect(find.text('Beobachter'), findsOneWidget);
      expect(find.byType(IonCloseButton), findsNothing);
      final screen = tester.getSize(find.byType(MaterialApp));
      final sheet = tester.getSize(find.byType(BottomSheet));
      expect(sheet.height, screen.height - 10);
    });

    testWidgets('half sheet starts at 50 %', (tester) async {
      await open(tester, 0.5);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      final screen = tester.getSize(find.byType(MaterialApp));
      final sheet = tester.getRect(find.byType(IonModalHeader));
      expect(sheet.top, closeTo(screen.height / 2, 1));
    });
  });
}
