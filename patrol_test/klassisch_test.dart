import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:attendix/shared/widgets/layout/side_nav/side_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'support/app.dart';

// The classic design, which looks and works like the earlier app. Its flows
// have no number: docs/beta describes the new design only.

/// Polls until [text] leaves the tree (e.g. after a 250 ms search debounce).
Future<void> _seeGone(
  PatrolIntegrationTester $,
  Pattern text, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while ($(text).evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 100));
  }
  seeNot($, text);
}

/// Triggers an [IonFabButton] by its [key] even when the debug role FAB sits
/// over the bottom-right corner on mobile/debug builds.
Future<void> _pressIonFab(PatrolIntegrationTester $, Key key) async {
  final target = $(key);
  await target.waitUntilExists(timeout: const Duration(seconds: 20));
  final fabFinder = find.descendant(
    of: find.byKey(key),
    matching: find.byType(FloatingActionButton),
  );
  $.tester.widget<FloatingActionButton>(fabFinder).onPressed!();
  await $.pump(const Duration(milliseconds: 500));
}

void main() {
  patrolTest('Klassisch: Für den nächsten Termin zusagen', tags: ['mobil'], (
    $,
  ) async {
    await startApp($, beta: false);
    await signInAs($, 'stimmhelfer');
    await see($, RegExp('Shalom Sina'));
    await tapOn($, 'Zusagen');
    await see($, 'Zugesagt');
  });

  patrolTest('Klassisch: Termine der Gruppe ansehen', tags: ['mobil'], (
    $,
  ) async {
    await startApp($, beta: false);
    await signInAs($, 'helfer');
    await tapOn($, 'Termine');
    await see($, 'Anstehend');
    await see($, 'Sommerkonzert');
    await see($, 'Vergangen');
  });

  patrolTest(
    'Klassisch: Personenliste filtern und Detail öffnen',
    tags: ['pr', 'mobil'],
    ($) async {
      await startApp($, beta: false);
      await signInAs($, 'admin');
      await see($, RegExp('Mia Mitglied|Dashboard'));
      if ($(label('Mia Mitglied')).evaluate().isEmpty) {
        await tapOn($, 'Personen');
      }
      await see($, 'Mia Mitglied');
      await $(TextField).first.enterText('Trompete');
      await see($, 'Stefan Stimmführer');
      seeNot($, 'Mia Mitglied');
      await tapOn($, 'Stefan Stimmführer');
      await see($, 'Person bearbeiten');
      await tapOn($, 'Allgemein');
      await see($, 'Trompete');
    },
  );

  patrolTest(
    'Klassisch: Termin-Detail und Optionsmenü inkl. Telegram-Karte',
    tags: ['mobil'],
    ($) async {
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
    },
  );

  patrolTest('Klassisch: Werke suchen', ($) async {
    await startApp($, beta: false);
    await signInAs($, 'mitglied');
    await tapOn($, 'Werke');
    await see($, RegExp('Ode an die Freude'));
    await $(TextField).first.enterText('Nacht');
    await _seeGone($, RegExp('Ode an die Freude'));
    await see($, RegExp('Kleine Nachtmusik'));
  });

  patrolTest('Klassisch: Gruppen und Dateiablage öffnen', ($) async {
    await startApp($, beta: false);
    await signInAs($, 'admin');
    await tapOn($, 'Einstellungen');
    await tapOn($, 'Gruppen');
    await see($, RegExp('Trompete'));
    await see($, RegExp('Cello'));
    await tapOn($, 'Dateiablage');
    await see($, 'Dateien');
    await see($, 'Root');
  });

  patrolTest(
    'Klassisch: Elternportal zeigt Kind und Termine',
    tags: ['mobil'],
    ($) async {
      await startApp($, beta: false);
      await signInAs($, 'eltern');
      await see($, 'Lena');
      await see($, 'Sommerkonzert');
    },
  );

  patrolTest(
    'Klassisch: Beobachter sieht Termine schreibgeschützt',
    tags: ['mobil'],
    ($) async {
      await startApp($, beta: false);
      await signInAs($, 'beobachter');
      await tapOn($, 'Termine');
      await see($, 'Probe');
      await see($, RegExp(r'\d+ von 8 anwesend'));
      await $('Probe').first.tap();
      await $.pump(const Duration(milliseconds: 300));
      seeNot($, 'Allgemein');
      seeNot($, 'Erinnerung versenden');
    },
  );

  // Ionic core-parity & write flows (isolated in Kammerchor or read-only).
  patrolTest('Klassisch: Termin mit Grund absagen', tags: ['mobil'], ($) async {
    await startApp($, beta: false);
    await signInAs($, 'chor-mitglied');
    await tapOn($, 'Absagen');
    await see($, 'Abmeldung');
    await tapOn($, 'Krankheitsbedingt');
    await tapOn($, const Key('excuse-reason-confirm'));
    await see($, RegExp('Entschuldigt|Abgesagt'));
    await see($, RegExp('Krankheitsbedingt'));
  });

  patrolTest('Klassisch: Stimmführer sieht Meine Stimme', ($) async {
    await startApp($, beta: false);
    await signInAs($, 'stimmfuehrer');
    await tapOn($, 'Meine Stimme');
    await see($, 'Trompete');
    await see($, 'Sina Stimmhelfer');
  });

  patrolTest(
    'Klassisch: Beobachter sieht Personen schreibgeschützt',
    tags: ['mobil'],
    ($) async {
      await startApp($, beta: false);
      await signInAs($, 'beobachter');
      await see($, 'Mia Mitglied');
      await tapOn($, 'Mia Mitglied');
      await see($, 'Allgemein');
      seeNot($, 'Person bearbeiten');
      seeNot($, 'Speichern');
    },
  );

  patrolTest(
    'Klassisch: Neuen Termin anlegen und Anwesenheit öffnen',
    tags: ['mobil'],
    ($) async {
      await startApp($, beta: false);
      await signInAs($, 'chor-admin');
      await tapOn($, 'Termine');
      await _pressIonFab($, const Key('classic-events-add'));
      await see($, 'Termin hinzufügen');
      await $(const Key('classic-attendance-create-info'))
          .enterText('Klassik-Probe');
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 200));
      await tapOn($, const Key('classic-attendance-create-submit'));
      await see($, 'Klassik-Probe');
      await tapOn($, 'Klassik-Probe');
      await tapOn($, 'Allgemein');
      await see($, 'Info-Text');
      await see($, 'Notizen');
      await see($, 'Anmeldefrist setzen');
    },
  );

  patrolTest('Klassisch: Neue Person anlegen', ($) async {
    await startApp($, beta: false);
    await signInAs($, 'chor-admin');
    await see($, RegExp('Personen|Dashboard'));
    if ($(const Key('classic-people-add')).evaluate().isEmpty) {
      await tapOn($, 'Personen');
    }
    await _pressIonFab($, const Key('classic-people-add'));
    await see($, 'Person hinzufügen');
    await $(TextFormField).at(0).enterText('Klara');
    await $(TextFormField).at(1).enterText('Klassik');
    await _pressIonFab($, const Key('person_create_save'));
    await see($, 'Klara Klassik');
  });

  patrolTest(
    'Klassisch: Mitteilungen, Automatische Nachrichten und Ausloggen',
    ($) async {
      await startApp($, beta: false);
      await signInAs($, 'admin');
      await tapOn($, 'Mitteilungen');
      await tapOn($, 'Automatische Nachrichten');
      await see($, 'Unentschuldigt gefehlt');
      final sideMessages = $.tester.widget<Text>(
        find.descendant(
          of: find.byType(SideNav),
          matching: find.text('Mitteilungen'),
        ),
      );
      expect(sideMessages.style?.fontWeight, FontWeight.w600);
      await tapOn($, 'Ausloggen');
      await waitForPage($, LoginPage);
    },
  );

  patrolTest('Klassisch: Bewerber sieht Warteseite ohne Haupt-Tabs', ($) async {
    await startApp($, beta: false);
    await signInAs($, 'bewerber');
    await see($, RegExp('Deine Registrierung wurde erfolgreich übermittelt'));
    seeNot($, 'Termine');
    seeNot($, 'Personen');
    seeNot($, 'Werke');
  });
}
