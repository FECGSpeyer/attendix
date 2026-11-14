import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:patrol/patrol.dart';

import 'support/app.dart';

// The local Supabase has accounts but no tables yet. Until the schema is
// there, these flows stay on the sign-in page: the app asks the local
// Supabase, gets the refusal and shows it. Flows behind the sign-in follow
// with the schema.
void main() {
  patrolTest('Falsches Passwort wird abgelehnt (Beta)', ($) async {
    await startApp($);
    await signIn($, email: 'admin@attendix.test', password: 'falsch-falsch');
    await $('Ungültige Anmeldedaten').waitUntilVisible(timeout: const Duration(seconds: 20));
    await waitForPage($, LoginPage);
  });

  patrolTest('Falsches Passwort wird abgelehnt (klassisch)', ($) async {
    await startApp($, beta: false);
    await signIn($, email: 'admin@attendix.test', password: 'falsch-falsch');
    await $('Ungültige Anmeldedaten').waitUntilVisible(timeout: const Duration(seconds: 20));
    await waitForPage($, LoginPage);
  });
}
