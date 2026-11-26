import 'package:attendix/core/providers/locale_provider.dart'
    show appLanguageStorageKey;
import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:attendix/main.dart' as app;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Password of every test account in the local test database. It only
/// exists there, never in production.
const e2ePassword = 'attendix-e2e';

/// Starts the real app and waits for the login page.
///
/// The app language is forced to German, whatever the device says.
Future<void> startApp(PatrolIntegrationTester $) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(appLanguageStorageKey, 'de');
  app.main();
  await $(LoginPage).waitUntilVisible(timeout: const Duration(seconds: 90));
}

/// Signs in with e-mail and password on the login page.
Future<void> signIn(
  PatrolIntegrationTester $, {
  required String email,
  String password = e2ePassword,
}) async {
  await $(TextFormField).at(0).enterText(email);
  await $(TextFormField).at(1).enterText(password);
  // Do not wait for the app to come to rest: the answer (a toast or the next
  // page) is what the flow checks next, and a toast is gone after 3 seconds.
  await $(label('Anmelden')).tap(settlePolicy: SettlePolicy.noSettle);
}

/// Signs in as a test account of the local test database: [name] is the part
/// before `@attendix.test` (admin, verantwortlich, helfer, mitglied,
/// beobachter, eltern, bewerber, stimmfuehrer, chor-admin …).
///
/// [inGroup] is false for an account without a group: it never reaches the
/// app's pages, so the store hint below does not come.
Future<void> signInAs(
  PatrolIntegrationTester $,
  String name, {
  bool inGroup = true,
}) async {
  await signIn($, email: '$name@attendix.test');
  if (inGroup && kIsWeb) {
    // The web app offers the store app once after a sign-in.
    await see(
      $,
      RegExp('^später\$', caseSensitive: false),
      timeout: const Duration(seconds: 60),
    );
    await $(label('Später')).tap();
  }
}

/// Finds a text case-insensitively.
Finder label(String text) => find.textContaining(
  RegExp('^${RegExp.escape(text)}\$', caseSensitive: false),
);

/// Finds the text field that shows [hint] while it is empty.
Finder field(String hint) => find.widgetWithText(TextField, hint);

/// Finds an icon button by the text it shows on a long press or hover.
Finder tooltip(String text) => find.byTooltip(text);

/// Finds a control by the name a screen reader gets, for buttons that only
/// show an icon.
Finder named(String name) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == name,
);

/// Waits for [text] (a whole text, or a RegExp for a part of one).
Future<void> see(
  PatrolIntegrationTester $,
  Pattern text, {
  Duration timeout = const Duration(seconds: 20),
}) => _orShowScreen(
  $,
  '"$text"',
  () => $(text).waitUntilVisible(timeout: timeout),
);

/// Checks that [text] is not on the screen.
void seeNot(PatrolIntegrationTester $, Pattern text) =>
    expect($(text), findsNothing, reason: '"$text" should not be on screen');

/// Taps [target] (a text, a Key or a Finder), after bringing it into view
/// where a list hides it.
Future<void> tapOn(PatrolIntegrationTester $, Object target) async {
  final finder = target is String ? $(label(target)) : $(target);
  await _orShowScreen($, '$target', () async {
    await finder.waitUntilExists(timeout: const Duration(seconds: 20));
    if (finder.hitTestable().evaluate().isEmpty) {
      await $.tester.ensureVisible(finder.first);
      await $.pump();
    }
    await finder.tap();
  });
}

/// Presses the round add button [key] at the bottom right of a page.
///
/// Flows run a debug build, and there the role switcher for developers lies
/// over that corner, so a tap would not reach the button.
Future<void> pressAddButton(PatrolIntegrationTester $, Key key) async {
  final finder = $(key);
  await _orShowScreen(
    $,
    '$key',
    () => finder.waitUntilExists(timeout: const Duration(seconds: 20)),
  );
  $.tester.widget<FloatingActionButton>(finder).onPressed!();
  await $.pump(const Duration(milliseconds: 500));
}

/// Waits for the page of type [page].
Future<void> waitForPage(
  PatrolIntegrationTester $,
  Type page, {
  Duration timeout = const Duration(seconds: 30),
}) =>
    _orShowScreen($, '$page', () => $(page).waitUntilVisible(timeout: timeout));

/// Runs [step]. When it does not find its widget in time, the failure names
/// the texts on the screen, so the log of a run shows where the app is.
Future<void> _orShowScreen(
  PatrolIntegrationTester $,
  String what,
  Future<void> Function() step,
) async {
  try {
    await step();
  } on Exception catch (error) {
    if (error is! WaitUntilVisibleTimeoutException &&
        error is! WaitUntilExistsTimeoutException) {
      rethrow;
    }
    final texts = $.tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
        .where((text) => text.trim().isNotEmpty)
        .take(60)
        .join(' | ');
    fail('$what did not appear. On screen: $texts');
  }
}
