import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

import 'support/app.dart';

// What the lead of a group does (docs/beta/szenarien/leitung.md, L-…).

void main() {
  patrolTest('L-14 Die Mitgliederliste durchsehen und filtern', ($) async {
    await startApp($);
    await signInAs($, 'admin');
    await tapOn($, 'Mitglieder');
    await see($, 'Mia Mitglied');
    await $(field('Name, Instrument, Register')).enterText('Trompete');
    await see($, 'Stefan Stimmführer');
    seeNot($, 'Mia Mitglied');
  });

  patrolTest('L-15 Eine Person von Hand anlegen', tags: ['pr'], ($) async {
    await startApp($);
    await signInAs($, 'verantwortlich');
    await tapOn($, 'Mitglieder');
    await tapOn($, const Key('rd-members-add'));
    await tapOn($, 'Person hinzufügen');
    await see($, 'Neue Person');
    await $(field('Max')).enterText('Paula');
    await $(field('Mustermann')).enterText('Neu');
    await tapOn($, 'Cello');
    await tapOn($, const Key('rd-person-create'));
    await see($, 'Paula Neu');
  });

  patrolTest('L-17 Eine Anmeldung prüfen und freigeben', ($) async {
    await startApp($);
    await signInAs($, 'admin');
    await tapOn($, 'Mitglieder');
    await tapOn($, $(RegExp(r'^Wartet · \d+$')));
    await tapOn($, 'Bea Bewerberin');
    await tapOn($, 'Aufnehmen');
    // The other applicant is still waiting, Bea is not.
    await see($, RegExp(r'^Wartet · 1$'));
    await tapOn($, $(RegExp(r'^Aktiv · \d+$')));
    await see($, 'Bea Bewerberin');
  });

  patrolTest('L-29 Ein neues Werk anlegen', ($) async {
    await startApp($);
    await signInAs($, 'admin');
    await tapOn($, 'Werke');
    await tapOn($, const Key('rd-works-add'));
    await tapOn($, 'Neues Werk');
    await $(const Key('rd-work-create-name')).enterText('Morgenstimmung');
    await tapOn($, const Key('rd-work-create-submit'));
    await see($, 'Morgenstimmung');
  });

  patrolTest('L-46 Ein Instrument anlegen', ($) async {
    await startApp($);
    await signInAs($, 'admin');
    await tapOn($, 'Verwaltung');
    await tapOn($, 'Instrumente');
    await pressAddButton($, const Key('rd-manage-list-add'));
    await see($, 'Neues Instrument');
    await $(field('z.B. Mädchen, Posaune, Alt 1, etc.')).enterText('Harfe');
    await tapOn($, 'Fertig');
    await see($, 'Harfe');
  });
}
