import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:patrol/patrol.dart';

import 'support/app.dart';

// The local Supabase has accounts but no tables yet. Until the schema is
// there, these flows stay on the sign-in page: the app asks the local
// Supabase, gets the refusal and shows it. Flows behind the sign-in follow
// with the schema.
/// Start of the toast for a refused sign-in.
final _refused = RegExp('E-Mail oder Passwort falsch');

/// The app says no twice: a toast, and a dialog that offers the e-mail code.
/// Closing the dialog leaves the user on the sign-in page.
Future<void> _expectRefusal(PatrolIntegrationTester $) async {
  await $(_refused).waitUntilVisible(timeout: const Duration(seconds: 20));
  await $('Anmeldung fehlgeschlagen').waitUntilVisible();
  await $(label('Abbrechen')).tap();
  await waitForPage($, LoginPage);
}

void main() {
  patrolTest('Falsches Passwort wird abgelehnt (Beta)', ($) async {
    await startApp($);
    await signIn($, email: 'admin@attendix.test', password: 'falsch-falsch');
    await _expectRefusal($);
  });

  patrolTest('Falsches Passwort wird abgelehnt (klassisch)', ($) async {
    await startApp($, beta: false);
    await signIn($, email: 'admin@attendix.test', password: 'falsch-falsch');
    await _expectRefusal($);
  });
}
