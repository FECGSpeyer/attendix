import 'package:patrol/patrol.dart';

import 'support/app.dart';

// Observers, parents and section leaders (docs/beta/szenarien: B-…, E-…,
// S-…).

void main() {
  patrolTest('B-02 Die Termine der Gruppe mit ihren Rückmeldungen ansehen', (
    $,
  ) async {
    await startApp($);
    await signInAs($, 'beobachter');
    await tapOn($, 'Termine');
    await see($, 'Sommerkonzert');
    await see($, RegExp(r'^\d+\s+zugesagt$'));
    // An observer cannot open a single Termin.
    await $('Sommerkonzert').tap();
    seeNot($, 'Anwesenheit');
    seeNot($, 'Bearbeiten');
  });

  patrolTest('B-03 Die Mitglieder der Gruppe ansehen', ($) async {
    await startApp($);
    await signInAs($, 'beobachter');
    await tapOn($, 'Mitglieder');
    await tapOn($, 'Mia Mitglied');
    await see($, RegExp('^Cello · seit 2022'));
    // Changing a person is for the lead only.
    seeNot($, 'Bearbeiten');
  });

  patrolTest('E-01 Für ein Kind zusagen', ($) async {
    await startApp($);
    await signInAs($, 'eltern');
    await see($, 'Lena');
    await tapOn($, 'Ist dabei');
    await see($, 'Dabei');
    await see($, 'Doch absagen');
  });

  patrolTest('S-01 Sehen, wer zu meiner Stimme gehört', ($) async {
    await startApp($);
    await signInAs($, 'stimmfuehrer');
    await tapOn($, 'Meine Stimme');
    await see($, 'Trompete · 2 Mitglieder');
    await see($, 'Sina Stimmhelfer');
    await see($, 'stimmhelfer@attendix.test');
  });
}
