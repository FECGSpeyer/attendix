import 'package:attendix/core/constants/app_constants.dart';
import 'package:attendix/core/providers/locale_provider.dart'
    show appLanguageStorageKey;
import 'package:attendix/core/providers/redesign_providers.dart'
    show redesignEnabledStorageKey;
import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/features/attendance/presentation/pages/attendance_detail_page.dart';
import 'package:attendix/features/attendance/presentation/pages/attendance_list_page.dart';
import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:attendix/features/help/presentation/pages/help_page.dart';
import 'package:attendix/features/instruments/presentation/pages/instruments_list_page.dart';
import 'package:attendix/features/messages/presentation/pages/auto_message_list_page.dart';
import 'package:attendix/features/people/presentation/pages/people_list_page.dart';
import 'package:attendix/features/people/presentation/pages/person_detail_page.dart';
import 'package:attendix/features/people/presentation/widgets/ion/ion_widgets.dart'
    show IonItem, IonSearchbar;
import 'package:attendix/features/settings/presentation/pages/files_page.dart';
import 'package:attendix/main.dart' as app;
import 'package:attendix/shared/widgets/event_list/event_list_widgets.dart'
    show EventRow, EventTodayFilledCard;
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:attendix/shared/widgets/layout/main_shell.dart';
import 'package:attendix/shared/widgets/layout/side_nav/side_nav.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pumps frames until [finder] matches at least once or [timeout] elapses.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    finder,
    findsWidgets,
    reason: reason ?? 'Timed out waiting for $finder',
  );
}

/// Dismisses optional startup notices (e.g. "Später" on app hint or iCal alert).
Future<void> _dismissOptionalDialogs(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    final later = find.textContaining(RegExp(r'^später$', caseSensitive: false));
    if (later.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(later.hitTestable().first);
      await tester.pump(const Duration(milliseconds: 300));
      continue;
    }
    break;
  }
}

/// Navigates to a main shell section adaptively across SideNav (macOS / wide
/// tablet landscape), IosTabBar (iPhone / tablet portrait), and NavigationBar (Android).
Future<void> _openMainDestination(
  WidgetTester tester, {
  required String sideNavLabel,
  required String tabLabel,
}) async {
  await _dismissOptionalDialogs(tester);
  final sideNav = find.byType(SideNav);
  if (sideNav.evaluate().isNotEmpty) {
    final target = find.descendant(
      of: sideNav,
      matching: find.textContaining(
        RegExp('^${RegExp.escape(sideNavLabel)}\$', caseSensitive: false),
      ),
    );
    await _pumpUntil(tester, target, reason: 'SideNav item "$sideNavLabel"');
    await tester.ensureVisible(target.first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(target.first);
    await tester.pump(const Duration(milliseconds: 400));
    return;
  }

  final iosBar = find.byType(IosTabBar);
  if (iosBar.evaluate().isNotEmpty) {
    final target = find.descendant(
      of: iosBar,
      matching: find.textContaining(
        RegExp('^${RegExp.escape(tabLabel)}\$', caseSensitive: false),
      ),
    );
    await _pumpUntil(tester, target, reason: 'IosTabBar item "$tabLabel"');
    await tester.tap(target.first);
    await tester.pump(const Duration(milliseconds: 400));
    return;
  }

  final mdBar = find.byType(NavigationBar);
  await _pumpUntil(tester, mdBar, reason: 'NavigationBar');
  final target = find.descendant(
    of: mdBar,
    matching: find.textContaining(
      RegExp('^${RegExp.escape(tabLabel)}\$', caseSensitive: false),
    ),
  );
  await _pumpUntil(tester, target, reason: 'NavigationBar item "$tabLabel"');
  await tester.tap(target.first);
  await tester.pump(const Duration(milliseconds: 400));
}

/// Taps a visible label (e.g. a tile on SettingsPage), scrolling down (then
/// up if needed) so lazy ListView children on small phone screens are built.
Future<void> _scrollAndTapText(WidgetTester tester, String text) async {
  await _dismissOptionalDialogs(tester);
  final target = find.textContaining(
    RegExp('^${RegExp.escape(text)}\$', caseSensitive: false),
  );
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (target.evaluate().isEmpty) {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      final scrollable = scrollables.last;
      for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 150));
      }
      for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
        await tester.drag(scrollable, const Offset(0, 300));
        await tester.pump(const Duration(milliseconds: 150));
      }
    }
  }
  await _pumpUntil(tester, target, reason: 'Text "$text"');
  await tester.ensureVisible(target.first);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(target.first);
  await tester.pump(const Duration(milliseconds: 400));
}

/// Navigates back from pushed pages / modals using whichever back/close button
/// the active platform look renders.
Future<void> _goBack(WidgetTester tester) async {
  await _dismissOptionalDialogs(tester);
  final candidates = <Finder>[
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(AppIcons.close),
    ),
    find.byIcon(AppIcons.arrowBackIosNew),
    find.byIcon(AppIcons.arrowBack),
    find.byType(BackButtonIcon),
    find.byType(BackButton),
  ];
  for (final finder in candidates) {
    if (finder.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(finder.hitTestable().first);
      await tester.pump(const Duration(milliseconds: 400));
      return;
    }
  }
  await tester.pageBack();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Logs in via the password form using the write-protected demo credentials.
Future<void> _signInDemo(WidgetTester tester) async {
  await _pumpUntil(
    tester,
    find.byType(LoginPage),
    timeout: const Duration(seconds: 60),
    reason: 'LoginPage should appear on launch',
  );
  expect(
    AppConstants.demoMail,
    isNotEmpty,
    reason: 'DEMO_EMAIL must be loaded from .env.app',
  );
  expect(
    AppConstants.demoPassword,
    isNotEmpty,
    reason: 'DEMO_PASSWORD must be loaded from .env.app',
  );

  await tester.enterText(find.byType(TextFormField).at(0), AppConstants.demoMail);
  await tester.enterText(
    find.byType(TextFormField).at(1),
    AppConstants.demoPassword,
  );
  await tester.pump(const Duration(milliseconds: 200));

  final loginBtn = find.textContaining(
    RegExp(r'^anmelden$', caseSensitive: false),
  );
  await tester.tap(loginBtn.first);

  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    await _dismissOptionalDialogs(tester);
    if (find.byType(MainShell).evaluate().isNotEmpty) {
      break;
    }
    final orchester = find.text('Orchester');
    if (orchester.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(orchester.hitTestable().first);
      await tester.pump(const Duration(milliseconds: 400));
    }
  }
  await _pumpUntil(
    tester,
    find.byType(MainShell),
    reason: 'MainShell should load for Demo Orchester',
  );
  await _dismissOptionalDialogs(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() async {
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  });

  testWidgets('Classic Demo multi-platform smoke and parity journey', (
    tester,
  ) async {
    final originalOnError = FlutterError.onError;
    final originalPlatformOnError = PlatformDispatcher.instance.onError;
    final recordedErrors = <FlutterErrorDetails>[];

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appLanguageStorageKey, 'de');
    await prefs.setBool(redesignEnabledStorageKey, false);

    try {
      app.main();
      await _signInDemo(tester);

      // Observe Flutter framework errors (e.g. RenderFlex overflows) without
      // breaking FlutterError.onError identity checks on test teardown.
      final appErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        final msg = details.exceptionAsString();
        final isOptionalNetworkImage =
            msg.contains('NetworkImageLoadException') ||
            msg.contains('HttpException');
        if (!isOptionalNetworkImage) {
          recordedErrors.add(details);
        }
        appErrorHandler?.call(details);
      };

      // 1. Personen: open list, filter via IonSearchbar, open first person & return.
      await _openMainDestination(
        tester,
        sideNavLabel: 'Personen',
        tabLabel: 'Personen',
      );
      await _pumpUntil(tester, find.byType(PeopleListPage));
      await _dismissOptionalDialogs(tester);

      final firstPerson = find.descendant(
        of: find.byType(PeopleListPage),
        matching: find.byWidgetPredicate((w) => w is IonItem && w.onTap != null),
      );
      await _pumpUntil(tester, firstPerson, reason: 'Demo person rows');

      final searchField = find.descendant(
        of: find.byType(IonSearchbar),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField.first, 'Test');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(searchField.first, '');
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(firstPerson.first);
      await _pumpUntil(tester, find.byType(PersonDetailPage));
      await _goBack(tester);
      await _pumpUntil(tester, find.byType(PeopleListPage));

      // 2. Termine: open list, open first Termin, expand Allgemein (checks MD
      //    Info-Text / Notizen spacing) and verify Telegram menu + Demo guard.
      await _openMainDestination(
        tester,
        sideNavLabel: 'Termine',
        tabLabel: 'Termine',
      );
      await _pumpUntil(tester, find.byType(AttendanceListPage));
      await _dismissOptionalDialogs(tester);

      final firstTermin = find.descendant(
        of: find.byType(AttendanceListPage),
        matching: find.byWidgetPredicate(
          (w) => w is EventTodayFilledCard || (w is EventRow && w.onTap != null),
        ),
      );
      await _pumpUntil(tester, firstTermin, reason: 'Demo Termin rows');
      await tester.tap(firstTermin.first);
      await _pumpUntil(tester, find.byType(AttendanceDetailPage));

      await _scrollAndTapText(tester, 'Allgemein');
      await _pumpUntil(tester, find.text('Info-Text'));
      await _pumpUntil(tester, find.text('Notizen'));

      final moreBtn = find.byIcon(AppIcons.moreVert);
      await _pumpUntil(tester, moreBtn);
      await tester.tap(moreBtn.first);
      await tester.pump(const Duration(milliseconds: 400));
      await _pumpUntil(tester, find.text('Status-Übersicht'));
      await _pumpUntil(tester, find.text('Erinnerung versenden'));
      final telegramItem = find.text('Als Telegram-Karte senden');
      await _pumpUntil(tester, telegramItem);
      await tester.tap(telegramItem.first);
      await tester.pump(const Duration(milliseconds: 600));

      // Demo write protection blocks creating a bot link without crashing.
      expect(
        find.byType(AttendanceDetailPage),
        findsOneWidget,
        reason: 'Demo guard must keep detail page intact',
      );

      await _goBack(tester);
      await _pumpUntil(tester, find.byType(AttendanceListPage));

      // 3. Settings sub-pages (top to bottom): Gruppen, Mitteilungen ->
      //    Automatische Nachrichten (including SideNav active state),
      //    Dateiablage (with back), Hilfe.
      await _openMainDestination(
        tester,
        sideNavLabel: 'Einstellungen',
        tabLabel: 'Mehr',
      );
      await _scrollAndTapText(tester, 'Gruppen');
      await _pumpUntil(tester, find.byType(InstrumentsListPage));
      await _goBack(tester);

      await _openMainDestination(
        tester,
        sideNavLabel: 'Mitteilungen',
        tabLabel: 'Mehr',
      );
      if (find.text('Automatische Nachrichten').evaluate().isEmpty) {
        await _scrollAndTapText(tester, 'Mitteilungen');
      }
      await _scrollAndTapText(tester, 'Automatische Nachrichten');
      await _pumpUntil(tester, find.byType(AutoMessageListPage));

      if (find.byType(SideNav).evaluate().isNotEmpty) {
        final msgText = tester.widget<Text>(
          find.descendant(
            of: find.byType(SideNav),
            matching: find.text('Mitteilungen'),
          ),
        );
        expect(
          msgText.style?.fontWeight,
          FontWeight.w600,
          reason: 'Mitteilungen must remain highlighted on /settings/auto-messages',
        );
      }

      await _openMainDestination(
        tester,
        sideNavLabel: 'Dateiablage',
        tabLabel: 'Mehr',
      );
      if (find.byType(FilesPage).evaluate().isEmpty) {
        await _scrollAndTapText(tester, 'Dateiablage');
      }
      await _pumpUntil(tester, find.byType(FilesPage));
      await _goBack(tester);

      await _openMainDestination(
        tester,
        sideNavLabel: 'Hilfe',
        tabLabel: 'Mehr',
      );
      if (find.byType(HelpPage).evaluate().isEmpty) {
        await _scrollAndTapText(tester, 'Hilfe');
      }
      await _pumpUntil(tester, find.byType(HelpPage));

      expect(
        recordedErrors,
        isEmpty,
        reason: 'Unexpected FlutterErrors: ${recordedErrors.map((e) => e.exceptionAsString()).join('; ')}',
      );
    } finally {
      try {
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
      FlutterError.onError = originalOnError;
      PlatformDispatcher.instance.onError = originalPlatformOnError;
    }
  });
}
