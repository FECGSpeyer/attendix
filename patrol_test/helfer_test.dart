import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

import 'support/app.dart';

// Termine and attendance (docs/beta/szenarien/helfer.md, H-…).
//
// Creating and changing a Termin happens in the second group (Kammerchor),
// so the next Termin of the first group stays the same for every other flow.

void main() {
  patrolTest('H-01 Sehen, wie der nächste Termin steht', ($) async {
    await startApp($);
    await signInAs($, 'helfer');
    await see($, RegExp('^NÄCHSTER TERMIN'));
    await see($, 'zugesagt');
    await see($, 'offen');
    await see($, 'Anwesenheit erfassen');
  });

  patrolTest('H-04 Die Anwesenheit eines Termins erfassen', tags: ['pr'], (
    $,
  ) async {
    await startApp($);
    await signInAs($, 'helfer');
    await tapOn($, 'Anwesenheit erfassen');
    await see($, 'Otto Ohnekonto');
    // Person 108 is Otto Ohnekonto (test data).
    await tapOn($, $(const Key('rd-record-108')).$(named('Anwesend')));
    await see($, 'Rückgängig');
  });

  patrolTest('H-05 Alle Offenen auf einmal als anwesend eintragen', ($) async {
    await startApp($);
    await signInAs($, 'verantwortlich');
    await tapOn($, 'Termine');
    await tapOn($, 'Sommerkonzert');
    await tapOn($, 'Anwesenheit');
    await tapOn($, 'Alle Offenen als anwesend');
    await see($, RegExp(r'^\d+ Personen als anwesend markiert$'));
    await tapOn($, 'Rückgängig');
    await see($, 'Alle Offenen als anwesend');
  });

  patrolTest('H-10 Einen neuen Termin anlegen', ($) async {
    await startApp($);
    await signInAs($, 'chor-admin');
    await tapOn($, 'Termine');
    await tapOn($, const Key('rd-events-add'));
    await see($, 'Neuer Termin');
    await $(TextField).first.enterText('Sonderprobe');
    await tapOn($, 'Anlegen');
    await see($, 'Sonderprobe');
  });

  patrolTest('H-11 Einen Termin ändern', ($) async {
    await startApp($);
    await signInAs($, 'chor-admin');
    await tapOn($, 'Termine');
    await tapOn($, 'Bearbeiten');
    await see($, 'Termin bearbeiten');
    await $(TextField).first.enterText('Generalprobe');
    await tapOn($, 'Fertig');
    await see($, 'Generalprobe');
  });
}
