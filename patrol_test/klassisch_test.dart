import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  patrolTest('Klassisch: Personenliste filtern und Detail öffnen', tags: ['pr'], (
    $,
  ) async {
    await startApp($, beta: false);
    await signInAs($, 'admin');
    await tapOn($, 'Personen');
    await see($, 'Mia Mitglied');
    await $(TextField).first.enterText('Trompete');
    await see($, 'Stefan Stimmführer');
    seeNot($, 'Mia Mitglied');
    await tapOn($, 'Stefan Stimmführer');
    await see($, 'Trompete');
  });

  patrolTest('Klassisch: Termin-Detail und Optionsmenü inkl. Telegram-Karte', (
    $,
  ) async {
    await startApp($, beta: false);
    await signInAs($, 'verantwortlich');
    await tapOn($, 'Termine');
    await tapOn($, 'Sommerkonzert');
    await see($, 'Allgemein');
    await see($, 'Otto Ohnekonto');
    await tapOn($, find.byIcon(AppIcons.moreVert));
    await see($, 'Status-Übersicht');
    await see($, 'Erinnerung versenden');
    await see($, 'Als Telegram-Karte senden');
  });

  patrolTest('Klassisch: Werke suchen', ($) async {
    await startApp($, beta: false);
    await signInAs($, 'mitglied');
    await tapOn($, 'Werke');
    await see($, RegExp('Ode an die Freude'));
    await $(TextField).first.enterText('Nacht');
    await see($, RegExp('Kleine Nachtmusik'));
    seeNot($, RegExp('Ode an die Freude'));
  });

  patrolTest('Klassisch: Gruppen und Dateiablage öffnen', ($) async {
    await startApp($, beta: false);
    await signInAs($, 'admin');
    await tapOn($, 'Einstellungen');
    await tapOn($, 'Gruppen');
    await see($, 'Trompete');
    await see($, 'Cello');
    await tapOn($, 'Dateiablage');
    await see($, 'Dateien');
    await see($, 'Root');
  });

  patrolTest('Klassisch: Elternportal zeigt Kind und Termine', ($) async {
    await startApp($, beta: false);
    await signInAs($, 'eltern');
    await see($, 'Lena');
    await see($, 'Sommerkonzert');
  });

  patrolTest('Klassisch: Beobachter sieht Termine schreibgeschützt', ($) async {
    await startApp($, beta: false);
    await signInAs($, 'beobachter');
    await tapOn($, 'Termine');
    await see($, 'Sommerkonzert');
    seeNot($, 'Erinnerung versenden');
  });
}
