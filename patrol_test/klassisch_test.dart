import 'package:patrol/patrol.dart';

import 'support/app.dart';

// The classic design, which looks and works like the earlier app. Its flows
// have no number: docs/beta describes the new design only.

void main() {
  patrolTest('Klassisch: Für den nächsten Termin zusagen', ($) async {
    await startApp($, beta: false);
    await signInAs($, 'stimmhelfer');
    await see($, RegExp('Shalom Sina'));
    await tapOn($, 'Zusagen');
    await see($, 'Zugesagt');
  });

  patrolTest('Klassisch: Termine der Gruppe ansehen', ($) async {
    await startApp($, beta: false);
    await signInAs($, 'helfer');
    await tapOn($, 'Termine');
    await see($, 'Anstehend');
    await see($, 'Sommerkonzert');
    await see($, 'Vergangen');
  });
}
