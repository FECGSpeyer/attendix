import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:patrol/patrol.dart';

import 'support/app.dart';

// Sign-in and the first steps of a new account ("Neu dabei", N-…).

/// Start of the toast for a refused sign-in.
final _refused = RegExp('E-Mail oder Passwort falsch');

/// The app says no twice: a toast, and a dialog that offers the e-mail code.
/// Closing the dialog leaves the user on the sign-in page.
Future<void> _expectRefusal(PatrolIntegrationTester $) async {
  await see($, _refused);
  await see($, 'Anmeldung fehlgeschlagen');
  await $(label('Abbrechen')).tap();
  await waitForPage($, LoginPage);
}

void main() {
  patrolTest('N-02 Mich anmelden', tags: ['pr', 'mobil'], ($) async {
    await startApp($);
    await signInAs($, 'mitglied');
    await see($, 'Hallo Mia');
  });

  patrolTest('N-02 Falsches Passwort wird abgelehnt', tags: ['mobil'], (
    $,
  ) async {
    await startApp($);
    await signIn($, email: 'admin@attendix.test', password: 'falsch-falsch');
    await _expectRefusal($);
  });

  patrolTest('N-05 Angemeldet, aber noch in keiner Gruppe', ($) async {
    await startApp($);
    await signInAs($, 'fremd', inGroup: false);
    await see($, RegExp('Du bist noch in keiner Gruppe'));
    await see($, 'Ich habe eine Einladung');
    await see($, 'Eigene Gruppe gründen');
  });

  patrolTest('N-06 Auf die Freigabe warten', ($) async {
    await startApp($);
    await signInAs($, 'bewerber');
    await see($, RegExp('Deine Anmeldung bei Stadtorchester wird geprüft'));
    await see($, 'Andere Gruppe beitreten');
    // While waiting there is only "Heute" and "Ich".
    seeNot($, 'Termine');
    seeNot($, 'Werke');
  });
}
