import 'package:attendix/core/providers/locale_provider.dart'
    show appLanguageStorageKey;
import 'package:attendix/core/providers/redesign_providers.dart'
    show redesignEnabledStorageKey;
import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:attendix/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Password of every test account in the local test database
/// (e2e/supabase/seed). It only exists there, never in production.
const e2ePassword = 'attendix-e2e';

/// Starts the real app and waits for the login page.
///
/// [beta] chooses "Neues Design (Beta)" or the classic design; the app
/// language is German, whatever the device says.
Future<void> startApp(PatrolIntegrationTester $, {bool beta = true}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(appLanguageStorageKey, 'de');
  await prefs.setBool(redesignEnabledStorageKey, beta);
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
  await $(label('Anmelden')).tap();
}

/// Finds a text in both designs: the classic design writes button labels in
/// capitals on Android and web (like Ionic's Material mode), Beta does not.
Finder label(String text) => find.textContaining(
    RegExp('^${RegExp.escape(text)}\$', caseSensitive: false));
