import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:patrol/patrol.dart';

import 'support/app.dart';

// What a member does (docs/beta/szenarien/mitglied.md, M-…).

void main() {
  patrolTest('M-01 Für den nächsten Termin zusagen', tags: ['pr'], ($) async {
    await startApp($);
    await signInAs($, 'mitglied');
    await see($, 'Bist du dabei?');
    await tapOn($, 'Bin dabei');
    await see($, 'Du bist dabei');
  });

  patrolTest('M-02 Sich von einem Termin abmelden', ($) async {
    await startApp($);
    await signInAs($, 'stimmfuehrer');
    await see($, 'Bist du dabei?');
    await tapOn($, 'Kann nicht');
    await see($, 'Warum kannst du nicht?');
    await tapOn($, 'Krankheitsbedingt');
    await see($, 'Du bist abgemeldet');
    await see($, RegExp('Grund: Krankheitsbedingt'));
  });

  patrolTest('M-08 Einen Termin im Detail ansehen', ($) async {
    await startApp($);
    await signInAs($, 'mitglied');
    await tapOn($, 'Termine');
    await tapOn($, 'Sommerkonzert');
    await see($, RegExp(r'Mi 1\. Juli · 18:00–20:00'));
    await see($, 'Auftritt');
    await see($, 'Bist du dabei?');
  });

  patrolTest('M-18 Ein Werk suchen', ($) async {
    await startApp($);
    await signInAs($, 'mitglied');
    await tapOn($, 'Werke');
    await see($, 'Ode an die Freude');
    await $(field('Titel oder Nummer')).enterText('Nacht');
    await see($, 'Kleine Nachtmusik');
    seeNot($, 'Ode an die Freude');
  });

  patrolTest('M-33 Mich ausloggen', ($) async {
    await startApp($);
    await signInAs($, 'mitglied');
    await tapOn($, 'Ich');
    await tapOn($, 'Ausloggen');
    await waitForPage($, LoginPage);
  });
}
