# Fix-Paket „personen“

Soll: Ionic 4.19.9 (1923d203). Ist: Flutter 1aba6be, 2157fa0, b218510, 3bacc76, 8004a44, c9dd1aa, , b15b3b0, 40d2b43, da49473, 84c4c44, 6945c13, 3cdaaa1, a0550a4, 4e13f22, 2353b98, 00e183c, 57bb011, 0f74333 (normales Design).
Erzeugt mit `node tool/parity/parity.mjs fixlists` aus `docs/parity/status/`. Item-IDs siehe `ionic-inventory.json`.

## Angleichen (hoch/mittel): 1

- [ ] **mittel** `people/person/person.page` `alert-97cf5262` [people/person/person.page.ts:1354](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1354) (2. Prüfung: korrigiert)
  Dialog „Person kopieren/übertragen“ mit Ionic-Texten und Abbrechen/Ja gleich. Rollen-Abweichung: Flutter handoverPlayer vergibt RESPONSIBLE, wenn die Zielgruppe die Hauptgruppe der Zielinstanz ist (player_repository.dart:1716-1718). Ionic person.page.ts:1365 übergibt als mainGroup die Gruppe der QUELLE (isMainGroup ? player.instrument : null), db.service.ts:3824 vergleicht die Zielgruppe damit → praktisch immer PLAYER. Nur die Übergabe-Seite (handover-detail) vergibt in Ionic RESPONSIBLE für die Hauptgruppe. Die übertragene Person bekommt in Flutter also mehr Rechte als in Ionic (mittel statt niedrig wegen Rollenrechten; Leon entscheidet, ob wie Ionic PLAYER oder wie die Übergabe-Seite).
  Flutter: lib/features/people/presentation/widgets/person_transfer_sheet.dart, lib/data/repositories/player_repository.dart:1714-1724

## Flutter besser – Leon entscheidet: 28

- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `action-7bb1a2ef` [duty/duty-distribute-modal/duty-distribute-modal.component.html:69](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L69)
  Flutter besser: Ionic: Plus-Button bleibt bei 10 aktiv, Tippen wirkungslos (Math.min 10) / Flutter: Button bei 10 ausgegraut. Maximum 10 gleich.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:420
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-09922adb` [instruments/instrument-list/instrument-list.page.html:152](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L152) (2. Prüfung: korrigiert)
  Flutter besser: Rolle gleich (nur Admin/Verantwortlicher); Insert name, maingroup false, tuning C, clefs [g], tenantId, category (nur wenn gesetzt) gleich; leerer Name → „Bitte gib einem Namen an“. Erstprüfer übersah: Ionic speichert den Namen ungetrimmt (nur Leerzeichen wird angelegt) und prüft den Insert-Fehler nicht (group.service.ts:34, Modal schließt still) / Flutter trimmt und zeigt bei Fehler „Fehler beim Hinzufügen“.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:427, lib/features/instruments/presentation/pages/instruments_list_page.dart:371, lib/features/instruments/presentation/pages/instruments_list_page.dart:347, lib/data/repositories/group_repository.dart:94
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `action-5c670508` [people/bulk-edit/bulk-edit.page.html:5](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L5)
  Flutter besser: Ionic: X schließt das Modal immer (auch während Speichern) / Flutter: X während _isSaving deaktiviert.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:268-271
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-3f70cbe7` [people/bulk-edit/bulk-edit.page.html:16](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L16)
  Flutter besser: Label 'Feld auswählen', Platzhalter 'Feld wählen...', 'Standard-Felder' (deaktiviert) + Gruppe/Stimmführer/Notizen/Telefon, 'Zusatzfelder' + Felder gleich. Ionic: Zusatzfeld-Block nur wenn db.tenant().additional_fields.length > 0 (Org-Felder fehlen also, wenn der Tenant keine eigenen Felder hat) / Flutter: sobald irgendein Zusatzfeld (Org oder Tenant) existiert (hasExtra).
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:282-322
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-4964deb8-2` [people/bulk-edit/bulk-edit.page.html:135](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L135)
  Flutter besser: Ionic: (ionChange) $event.detail.value liefert bei ion-input einen String → Zusatzfeld wird als "5" gespeichert (laut Ionic-Core; @ionic/angular nicht im Container) / Flutter: parst zu num (Komma erlaubt), leer → null. Ionic übernimmt erst bei Blur, Flutter bei jedem Tastendruck.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:398-406, lib/features/people/presentation/pages/bulk_edit_page.dart:531-536, lib/features/people/presentation/pages/bulk_edit_page.dart:475-479
- [ ] **niedrig** `people/list/list.page` `toast-9a849d38` [people/list/list.page.ts:390](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L390) (2. Prüfung: korrigiert)
  Flutter besser: Ionic prüft das {error} der Supabase-Updates nicht; postgrest-js wirft ohne throwOnError auch bei Netzfehlern nicht (geprüft an @supabase/postgrest-js 2.x im npx-Cache, Ionic-Version selbst nicht im Container) → der Catch mit 'Fehler beim Speichern der Reihenfolge' ist praktisch unerreichbar, Ionic meldet auch bei Fehlschlag 'Reihenfolge gespeichert'. Flutter zeigt den roten Fehler-Toast, wenn ein Update scheitert. Erstprüfung: ok.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1176
- [ ] **niedrig** `people/list/list.page` `alert-eeaa4fb8` [people/list/list.page.ts:489](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L489) (2. Prüfung: korrigiert)
  Flutter besser: Für Zahlenfelder der Instanz gleich (Titel = Feldname, Zahlenfeld 'Wert eingeben', 'Abbrechen' → Alle, 'Filtern', leer → Alle; sichtbar für alle Rollen der Personenliste = Admin/Verantwortlicher/Beobachter, in beiden). Erstprüfer übersah den Mandanten-Fall Organisationsfelder: Ionic listet Org-Zahlenfelder im Filter (getPersonExtraFields), öffnet den Alert aber nur für tenant().additional_fields (list.page.ts:474) → kein Dialog, Filter wirkungslos (alle Personen, Icon trotzdem farbig) / Flutter: Dialog und Filter auch für Org-Zahlenfelder (personListExtraFieldsProvider). Vorbelegung: Ionic letzter gespeicherter Zusatzwert, Flutter nur bei gleichem aktivem Filter (kosmetisch). Treffer für Personen ohne Wert (Ionic-Default 0) siehe x-122934c2b4.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:986, lib/features/people/presentation/pages/people_list_page.dart:1002, lib/features/people/presentation/pages/people_list_page.dart:1013, lib/features/people/presentation/pages/people_list_page.dart:1016, lib/features/people/presentation/pages/people_list_page.dart:1019, lib/core/providers/profile_providers.dart:67
- [ ] **niedrig** `people/list/list.page` `alert-86b4fbec` [people/list/list.page.ts:909](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L909)
  Flutter besser: Titel, Text, Checkboxen (Instanzname), 'Überspringen'/'Pausieren' gleich; Ionic bietet aber alle verknüpften Instanzen an, in denen die Person (nicht als Betrachter) Mitglied ist, Flutter nur jene, in denen der angemeldete Nutzer Admin/Verantwortlicher ist (Ionic scheitert dort sonst mit 'Fehler bei …').
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:229, lib/features/people/presentation/widgets/pause_person_sheet.dart:236, lib/features/people/presentation/widgets/pause_person_sheet.dart:284
- [ ] **niedrig** `people/list/list.page` `field-27abe29e` [people/list/list.page.html:58](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L58)
  Flutter besser: Platzhalter 'Person suchen...' und Suchfelder (Vor-/Nachname, Gruppe, Text-/Zahl-Zusatzfelder) gleich; Ionic verwirft bei der Suche aber den aktiven Filter und die gewählte Sortierung (Ergebnis in Gruppenreihenfolge), Flutter kombiniert Suche, Filter und Sortierung.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:510, lib/features/people/presentation/pages/people_list_page.dart:514, lib/features/people/presentation/pages/people_list_page.dart:309, lib/features/people/people_list_utils.dart:8
- [ ] **niedrig** `people/list/list.page` `action-de48c2e0` [people/list/list.page.html:451](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L451)
  Flutter besser: Ionic clearFilters leert nur filterOptAdd und zeigt alle Personen, Filterauswahl (Icon bleibt farbig) und Suchtext bleiben stehen / Flutter setzt Filter auf 'Alle Anzeigen', leert die Suche und speichert das.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:582, lib/features/people/presentation/pages/people_list_page.dart:1243
- [ ] **niedrig** `people/person/person.page` `alert-40883a4d` [people/person/person.page.ts:503](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L503) (2. Prüfung: korrigiert)
  Flutter besser: Detailseite gleich ('Änderungen verwerfen?' / Text, 'Abbrechen' / 'Ja'; Änderungen nur für Admin/Verantwortliche möglich wie Ionic !readOnly). Erstprüfer übersah: Ionic onChange setzt hasChanges nur bei existingPlayer, das Neu-Modal schließt daher immer ohne Rückfrage / Flutter fragt auf der Neu-Seite bei jeder Eingabe (Name, E-Mail, Bild …) ebenfalls nach.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1742, lib/features/people/presentation/pages/person_create_page.dart:123
- [ ] **niedrig** `people/person/person.page` `alert-01934766` [people/person/person.page.ts:1343](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1343) (2. Prüfung: korrigiert)
  Flutter besser: Titel 'Kopieren/Übertragen nicht möglich', Text mit Instanz und E-Mail bzw. Name, 'OK' gleich. Ionic prüft keine Rechte in der Zielinstanz und zeigt den Hinweis für jede eigene Ziel-Rolle / Flutter prüft vorher canEdit in der Zielinstanz und zeigt sonst den roten Toast 'Keine Berechtigung in der Ziel-Instanz' statt des Hinweises (Ionic-Übertragung scheitert dann später). Andere Ziel-Instanzliste: field-0a2daf88.
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:723, lib/features/people/presentation/widgets/handover_sheet.dart:763
- [ ] **niedrig** `people/person/person.page` `field-9f6c9acb` [people/person/person.page.html:237](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L237)
  Flutter besser: Ionic-Input ohne ionChange (Änderung allein aktiviert Speichern nicht) / Flutter markiert Änderung. Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; leer + nicht bearbeitbar ausgeblendet
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:829
- [ ] **niedrig** `teachers/teachers.page` `field-8a21ddb5` [teachers/teachers.page.html:49](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teachers/teachers.page.html#L49) (2. Prüfung: bestätigt)
  Flutter besser: Ionic: addTeacher bekommt private.value der ion-toggle (Formularwert, Standard „on“), pri === 'true' ist nie wahr → neue Lehrer immer private = false (Ionic-Paket nicht im Container, Standardwert laut Ionic-API) / Flutter: speichert den Schalterzustand.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:392, lib/data/repositories/teacher_repository.dart:57
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `x-a485e4b055` **Zusatzfelder-Abschnitt Sichtbarkeit** [src/app/people/bulk-edit/bulk-edit.page.html:24](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L24)
  Flutter besser: Ionic: Zusatzfelder (inkl. Org-Felder) nur im Auswahlfeld, wenn der Tenant selbst additional_fields hat / Flutter: immer, wenn Org- oder Tenant-Felder existieren.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:255, lib/features/people/presentation/pages/bulk_edit_page.dart:306-319
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `x-1aab272cf3` **Zahlen-Zusatzfeld pro Person als String** [src/app/people/bulk-edit/bulk-edit.page.html:135-138](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L135-L138)
  Flutter besser: Ionic: Einzelwert aus ionChange ist String ("5"), Sammelwert über NumericValueAccessor Zahl; changedCount vergleicht strikt / Flutter: immer num (oder null).
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:475-479
- [ ] **niedrig** `people/import/import.page` `x-281b9c9094` **Liste wird auch ohne Import neu geladen** [src/app/people/import/import.page.ts:236-238](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.ts#L236-L238)
  Flutter besser: Ionic: Personenliste nur neu geladen, wenn mindestens eine Person importiert wurde / Flutter: invalidiert playersProvider immer (auch teilweise gespeicherte, fehlgeschlagene Zeilen erscheinen).
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:207-210
- [ ] **niedrig** `people/list/list.page` `x-5d4cb428e1` **Flutter besser: Suche/Filter/Sortierung kombiniert** [src/app/people/list/list.page.ts:714](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L714)
  Ionic: search() setzt die Liste auf alle Personen zurück (aktiver Filter verloren) und sortiert nach Gruppe; onFilterChanged sortiert ebenfalls nach Gruppe trotz anderer Sortierung; ein gespeicherter Filter wird beim Laden nur bei Sortierung 'Gruppe' angewendet / Flutter: Filter, Suche und Sortierung werden immer zusammen angewendet.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:250, lib/features/people/presentation/pages/people_list_page.dart:316
- [ ] **niedrig** `people/list/list.page` `x-c1c5493cd5` **Flutter besser: schmalere Pausen-Schreibvorgänge** [src/app/services/db.service.ts:2219](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/db.service.ts#L2219)
  Ionic: Pausieren/Aktivieren über updatePlayer schreibt den ganzen Listen-Datensatz zurück (inkl. mit Defaults aufgefüllter additional_fields); Pausieren in anderen Instanzen überschreibt dort die Historie mit der Quell-Historie / Flutter: schreibt nur paused, paused_until, history (+ tenantId-Filter); in anderen Instanzen wird der Eintrag an deren Historie angehängt.
  Flutter: lib/data/repositories/player_repository.dart:816, lib/data/repositories/player_repository.dart:861, lib/data/repositories/cross_tenant_person_repository.dart:288
- [ ] **niedrig** `people/person/person.page` `x-5c4108ee61` **Pausieren in anderen Instanzen: Historie** [src/app/people/person/person.page.ts:1453](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1453)
  Flutter besser: Ionic überschreibt die Historie der Person in der anderen Instanz mit der kompletten Historie dieser Instanz (pausePlayerInOtherTenant(..., history)) / Flutter hängt nur einen Pausiert-Eintrag an
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:247
- [ ] **niedrig** `people/person/person.page` `x-e0dc1b2b62` **Verspätungszähler zurücksetzen schreibt nur lastSolve** [src/app/people/person/person.page.ts:396](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L396)
  Flutter besser: Ionic resetLateCount speichert den ganzen Spieler (db.updatePlayer(this.player)) inkl. noch ungespeicherter Änderungen / Flutter schreibt nur lastSolve
  Flutter: lib/data/repositories/player_repository.dart:1391
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-d3edffbcbe` **Gleicher-Tag-Sperre zählt mehr Termine** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:111](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L111)
  Flutter besser: Ionic: lädt nur die gewählten Termintypen und filtert voll besetzte Termine vor distributeDuties heraus, deren Eingeteilte blockieren den Tag daher nicht / Flutter: lädt alle Dienst-Typen und gibt voll besetzte und nicht gewählte Termine mit open 0 mit, deren Eingeteilte blockieren bei „Nicht zweimal am selben Tag“ den Tag. Der Vorschlag kann sich dadurch unterscheiden.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:123, lib/features/duty/presentation/pages/duty_distribute_page.dart:164
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-9bddce3977` **Ladefehler beim Berechnen** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:79](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L79)
  Flutter besser: Ionic: kein catch, getUpcomingDutyTermine verschluckt Fehler und liefert [], dann Vorschau „Im Zeitraum gibt es keine Termine mit Dienst-Modus.“ / Flutter: roter Toast „Fehler: …“, bleibt im Regeln-Schritt.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:145
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-a43d5a3f61` **Pull-to-Refresh nur in Flutter** [src/app/instruments/instrument-list/instrument-list.page.html:70](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L70)
  Flutter besser: Ionic: kein ion-refresher auf der Gruppenliste / Flutter: Herunterziehen lädt Gruppen, Kategorien und Personenanzahlen neu.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:82
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-5824d283fc` **Fehler beim Hinzufügen einer Gruppe** [src/app/instruments/instrument-list/instrument-list.page.ts:178](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L178)
  Flutter besser: Ionic: groupSvc.addGroup prüft den Fehler nicht, Sheet schließt ohne Meldung / Flutter: Sheet schließt, roter Toast „Fehler beim Hinzufügen“.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:346
- [ ] **niedrig** `teachers/teachers.page` `x-42f2057e70` **Pull-to-Refresh nur in Flutter** [src/app/teachers/teachers.page.html:10](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teachers/teachers.page.html#L10)
  Flutter besser: Ionic: kein ion-refresher / Flutter: Herunterziehen lädt Lehrer und Schüleranzahlen neu.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:49
- [ ] **niedrig** `teachers/teachers.page` `x-c00bd9fd3a` **Gelöschte Gruppe in Lehrer-Instrumenten** [src/app/teachers/teachers.page.ts:41](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teachers/teachers.page.ts#L41)
  Flutter besser: Ionic: getTeachers liest .name einer nicht mehr existierenden Gruppe → TypeError, die Lehrerliste bleibt leer / Flutter: unbekannte Gruppen-IDs werden übersprungen.
  Flutter: lib/core/providers/teacher_providers.dart:75
- [ ] **niedrig** `people/person/person.page` `x-4b8b68cee9` **Neu-Seite: zusätzliche Duplikat-Rückfrage** [src/app/people/person/person.page.ts:525](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L525)
  Flutter besser: Ionic addPerson legt ohne Namensprüfung an / Flutter fragt bei gleichem Vor- und Nachnamen in der Instanz (auch archivierte/ausstehende) „Mögliches Duplikat“ – „Eine Person mit dem Namen "{name}" existiert bereits ({count}x). Trotzdem erstellen?“ mit Abbrechen/„Trotzdem erstellen“.
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:997, lib/features/people/presentation/pages/person_create_page.dart:999

## Kleinigkeiten (niedrig): 166

- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `loading-e612daf1` [duty/duty-distribute-modal/duty-distribute-modal.component.ts:77](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L77)
  Ionic: blockierendes Overlay „Verteile Dienste…“ / Flutter: Body durch Spinner mit gleichem Text ersetzt, das X in der AppBar bleibt bedienbar.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:326
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `loading-ef16b6da` [duty/duty-distribute-modal/duty-distribute-modal.component.ts:232](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L232)
  Ionic: blockierendes Overlay „Teile ein…“ / Flutter: Body durch Spinner mit gleichem Text ersetzt, Speichern-Button deaktiviert, aber „Zurück“ und „Neu verteilen“ in der AppBar bleiben während des Speicherns bedienbar.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:326, lib/features/duty/presentation/pages/duty_distribute_page.dart:347
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-b28d8f3e` [duty/duty-distribute-modal/duty-distribute-modal.component.html:29](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L29)
  Anzeigeformat: Ionic ion-datetime-button zeigt das Intl-Kurzformat (z. B. „1. Dez. 2026“, Ionic-Paket nicht im Container) / Flutter IonDatetimeChip „01.12.2026“ (dateFmt()).
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:375
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-71fefb63` [duty/duty-distribute-modal/duty-distribute-modal.component.html:32](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L32)
  Ionic: Kalender (Montag zuerst) mit Buttons „Fertig“/„Abbrechen“, Wert erst mit „Fertig“, unbegrenzter Bereich / Flutter: md showDatePicker mit „OK“/„Abbrechen“ bzw. iOS-Look Kalenderkarte ohne Buttons (Tipp übernimmt sofort), Bereich 2020–2100.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:96
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-b28d8f3e-2` [duty/duty-distribute-modal/duty-distribute-modal.component.html:39](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L39)
  Anzeigeformat: Ionic ion-datetime-button Intl-Kurzformat (z. B. „31. Dez. 2026“, Ionic-Paket nicht im Container) / Flutter IonDatetimeChip „31.12.2026“.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:379
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-bca25190` [duty/duty-distribute-modal/duty-distribute-modal.component.html:42](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L42)
  Ionic: Kalender mit „Fertig“/„Abbrechen“, unbegrenzter Bereich / Flutter: md showDatePicker mit „OK“/„Abbrechen“ bzw. iOS-Look Kalenderkarte ohne Buttons, Bereich 2020–2100. Keine Prüfung Von ≤ Bis in beiden.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:96
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `text-e73248fa` [duty/duty-distribute-modal/duty-distribute-modal.component.html:96](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L96)
  Ionic: dayjs „dd, DD.MM.“ + „ · HH:mm“, z. B. „Mo, 03.02. · 19:00“ / Flutter: Tag und Monat ohne führende Null, „Mo, 3.2. · 19:00“ (auch im Untertitel des Tausch-Dialogs).
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:88
- [ ] **niedrig** `duty/unavailability-modal/unavailability-modal.component` `field-bb90d03c` [duty/unavailability-modal/unavailability-modal.component.html:57](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/unavailability-modal/unavailability-modal.component.html#L57)
  Ionic: natives Datumsfeld (ion-input type=date) mit gestapeltem Label „Gültig bis (optional)“, zeigt das Datum im Browser-Format bzw. leer / Flutter: Zeile mit Label, Wert „bis 31.12.2026“ bzw. „unbefristet“, Tipp öffnet Datumsauswahl (Vorjahr bis +10 Jahre), X-Button zum Leeren. Gespeichert wird in beiden YYYY-MM-DD oder null.
  Flutter: lib/features/duty/presentation/pages/unavailability_page.dart:350, lib/features/duty/presentation/pages/unavailability_page.dart:166
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `modal-1bead9c9` [instruments/instrument-list/instrument-list.page.ts:159](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L159)
  Nur für Admin/Verantwortliche, übergibt die Gruppe (plus Kategorien). Ionic: iOS Karten-Modal (presentingElement), md Vollbild / Flutter: Vollbild-Dialog (fullscreenDialog) auf allen Plattformen. Neuladen nach Änderung in beiden.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:437
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `alert-eeb83d29` [instruments/instrument-list/instrument-list.page.ts:191](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L191)
  Titel „Neue Kategorie“, Buttons „Abbrechen“/„Hinzufügen“, legt Kategorie an. Ionic: Platzhalter „Name der Kategorie“, „Abbrechen“ mit role destructive (iOS rot) / Flutter: schwebendes Label „Name der Kategorie“, „Abbrechen“ neutral; Name wird getrimmt.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:260
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `alert-415386f9` [instruments/instrument-list/instrument-list.page.ts:223](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L223)
  Titel „Bestätigen“, Text „Kategorie wirklich löschen? …“, Buttons „Abbrechen“/„Ja“, löscht. Ionic: „Abbrechen“ mit role destructive (iOS rot), „Ja“ normal / Flutter: „Abbrechen“ neutral, „Ja“ rot gefüllt.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:339
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `alert-bd4338b7` [instruments/instrument-list/instrument-list.page.ts:249](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L249)
  Titel „Kategorie bearbeiten“, vorbelegter Name, Buttons „Abbrechen“/„Speichern“, speichert Namen. Ionic: Platzhalter „Name der Kategorie“, „Abbrechen“ role destructive (iOS rot) / Flutter: schwebendes Label, „Abbrechen“ neutral; Name getrimmt.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:298
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `loading-c2ec3077` [instruments/instrument-list/instrument-list.page.ts:314](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L314)
  Ionic: blockierendes Overlay „Reihenfolge wird gespeichert...“ / Flutter: nur LinearProgressIndicator im Sheet-Kopf, ohne Text, nicht blockierend.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:135
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `loading-7d7ff756` [instruments/instrument-list/instrument-list.page.ts:396](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L396) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay „Reihenfolge wird gespeichert...“ (max. 5 s) / Flutter: kein Ladehinweis, Liste bleibt bedienbar; zudem springt die Liste nach dem Häkchen bis zum Ende von Speichern + Neuladen auf die alte Reihenfolge zurück (_reorderSections = null vor dem await).
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:54
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-3f2a74e6` [instruments/instrument-list/instrument-list.page.html:23](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L23)
  Ionic: Plus-Button immer sichtbar, auch im Sortiermodus / Flutter: im Sortiermodus ausgeblendet.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:122
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `text-49ad7035` [instruments/instrument-list/instrument-list.page.html:33](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L33)
  Gleicher Text „Ziehe die Kategorien …“. Ionic: ion-item mit primary-Hintergrund und weißem Info-Icon / Flutter: normale ListTile mit blauem Info-Icon.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:191
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-a01ef8cf` [instruments/instrument-list/instrument-list.page.html:38](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L38)
  Sortieren per Ziehen und Speichern wie Ionic. Ionic: Zeile mit Griff-Icon (im Sortiermodus) und Badge der gespeicherten sort_order (immer, auch außerhalb des Sortiermodus) / Flutter: Karten; außerhalb des Sortiermodus Kategorie-Icon statt sort_order-Badge, im Sortiermodus Positionsnummer im Kreis, Ziehen per Long-Press (Standard-Griff).
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:197, lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:384
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-623e8e94` [instruments/instrument-list/instrument-list.page.html:51](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L51) (2. Prüfung: bestätigt)
  Nur Admin/Verantwortliche (Sheet-Button), nur außerhalb des Sortiermodus, öffnet „Kategorie bearbeiten“ wie Ionic. Ionic: Stift-Icon in warning-Farbe (orange) / Flutter: Icons.edit in Standardfarbe.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:392
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `text-1d015e65` [instruments/instrument-list/instrument-list.page.html:89](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L89)
  Text „Kategorie (n)“ in primary gleich. Ionic: ion-item-divider sticky (bleibt beim Scrollen oben stehen) / Flutter: IonItemDivider in einer Column, scrollt mit.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:243
- [ ] **niedrig** `instruments/instrument/instrument.page` `loading-2112917a` [instruments/instrument/instrument.page.ts:43](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.ts#L43)
  Ionic: blockierendes Overlay „Synonyme werden generiert...“ / Flutter: kleiner Spinner statt Funken-Button im Synonym-Feld, ohne Text, Seite bleibt bedienbar.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:683
- [ ] **niedrig** `instruments/instrument/instrument.page` `toast-283b4da3` [instruments/instrument/instrument.page.ts:60](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.ts#L60) (2. Prüfung: bestätigt)
  Gleicher Text „Bitte gib einen Namen an!“, Seite bleibt offen. Ionic: roter Toast / Flutter: roter Validierungstext unter dem Namensfeld; Flutter wertet reine Leerzeichen ebenfalls als leer.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:604
- [ ] **niedrig** `instruments/instrument/instrument.page` `alert-cb09ce26` [instruments/instrument/instrument.page.ts:88](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.ts#L88) (2. Prüfung: bestätigt)
  Titel „Bestätigen“, Text „Gruppe wirklich löschen?“, „Abbrechen“/„Ja“, „Ja“ löscht und schließt. Ionic: „Abbrechen“ mit role destructive (iOS rot) / Flutter: beide neutral. Zeitpunkt (Dialog auch bei zugeordneten Personen) siehe toast-39c411aa.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:755
- [ ] **niedrig** `instruments/instrument/instrument.page` `text-60ebf1b1` [instruments/instrument/instrument.page.html:4](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.html#L4)
  Ionic: Titel an instrument.name gebunden, ändert sich beim Tippen im Namensfeld / Flutter: fester Titel mit dem ursprünglichen Namen.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:585
- [ ] **niedrig** `instruments/instrument/instrument.page` `field-679fa215` [instruments/instrument/instrument.page.html:42](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.html#L42)
  Label „Stimmung“, Optionen C, Es, B, F, Sichtbarkeit gleich. Ionic: Popover-Auswahl, leerer Wert bleibt leer / Flutter: Dropdown, leerer (oder unbekannter) Wert wird als „C“ angezeigt, leerer Wert wird beim Speichern zu „C“.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:628
- [ ] **niedrig** `instruments/instrument/instrument.page` `field-ae69e131` [instruments/instrument/instrument.page.html:66](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.html#L66)
  Optionen Violinschlüssel (G), Bassschlüssel (F), Altschlüssel (C), Mehrfachauswahl. Ionic: Popover-Mehrfachauswahl mit (fehlerhaftem) Label „Stimmung“, alle abwählbar / Flutter: Überschrift „Notenschlüssel“ mit FilterChips, mindestens ein Schlüssel bleibt gewählt.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:646
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-9dd7902a` [people/bulk-edit/bulk-edit.page.html:53](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L53)
  Ionic: ion-toggle mit Beschriftung 'Stimmführer' / Flutter: nur Switch rechts ohne Beschriftung. Startwert false in beiden.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:514-518
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-523de84f` [people/bulk-edit/bulk-edit.page.html:61](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L61)
  Eingabefeld mit Platzhalter = Feldname gleich. Startwert: Ionic immer '' (getFieldTypeDefaultValue ohne defaultValue) / Flutter: konfigurierter Standardwert des Feldes, sonst ''.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:573-574, lib/features/people/presentation/pages/bulk_edit_page.dart:123-133
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-fc367be8` [people/bulk-edit/bulk-edit.page.html:67](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L67)
  Dropdown mit Optionen in Reihenfolge, Platzhalter = Feldname gleich. Startwert: Ionic immer erste Option / Flutter: Standardwert des Feldes, sonst erste Option.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:542-545, lib/features/people/presentation/pages/bulk_edit_page.dart:126-130
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-d2bdf3b7` [people/bulk-edit/bulk-edit.page.html:73](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L73)
  Ionic: ion-textarea mit autoGrow (mehrzeilig) / Flutter: einzeiliges TextFormField (default-Zweig). Startwert Ionic '' / Flutter Standardwert des Feldes oder ''.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:573-574, lib/features/people/presentation/pages/bulk_edit_page.dart:469-485
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-523de84f-3` [people/bulk-edit/bulk-edit.page.html:81](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L81) (2. Prüfung: bestätigt)
  Ionic: natives input type=date (leerbar), Startwert new Date().toISOString() (nicht angezeigt, aber von 'Für alle setzen' geschrieben) / Flutter: Button mit Datumsdialog ('Kein Datum gewählt'), nicht leerbar, Startwert Standardwert oder '' → schreibt ''.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:552, lib/features/people/presentation/pages/bulk_edit_page.dart:115
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-4964deb8-4` [people/bulk-edit/bulk-edit.page.html:165](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L165)
  Ionic: natives input type=date (Wert leerbar) / Flutter: Button mit Datumsauswahl, zeigt 'Kein Datum gewählt' bzw. Datum, Wert kann nicht geleert werden. Format yyyy-MM-dd gleich.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:398-406, lib/features/people/presentation/pages/bulk_edit_page.dart:552-572
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `action-a2a2fcd3` [people/bulk-edit/bulk-edit.page.html:176](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L176) (2. Prüfung: bestätigt)
  Texte 'Speichern...' / '# Änderung(en) speichern' / 'Keine Änderungen' und Deaktivierung gleich. Ionic: Spinner vor 'Speichern...' / Flutter: nur Text.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:433
- [ ] **niedrig** `people/import/import.page` `loading-3194637c` [people/import/import.page.ts:97](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.ts#L97)
  Flutter blockiert mit Overlay (Spinner) und deaktiviertem X, aber ohne Text 'Datei wird gelesen...' (peopleReadingFile ungenutzt).
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:82, lib/features/people/presentation/pages/person_import_page.dart:262-284
- [ ] **niedrig** `people/import/import.page` `loading-b32cfbfa` [people/import/import.page.ts:135](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.ts#L135)
  Ionic: blockierendes Overlay 'Daten werden geprüft...' / Flutter: Overlay nur mit Spinner (peopleCheckingData ungenutzt), 'Zurück' in der unteren Leiste bleibt bedienbar.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:137, lib/features/people/presentation/pages/person_import_page.dart:262-284
- [ ] **niedrig** `people/import/import.page` `loading-bab0752f` [people/import/import.page.ts:213](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.ts#L213)
  Fortschritt '{done} / {total} importiert...' wird angezeigt und aktualisiert, aber Ionic blockiert den ganzen Bildschirm / Flutter: Overlay nur über dem Inhalt, 'Zurück' in der unteren Leiste bleibt während des Imports bedienbar.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:174-177, lib/features/people/presentation/pages/person_import_page.dart:200-202, lib/features/people/presentation/pages/person_import_page.dart:262-284
- [ ] **niedrig** `people/import/import.page` `alert-3b9d1c7b` [people/import/import.page.ts:254](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.ts#L254)
  Titel 'Nicht importierte Personen', max. 10 Zeilen '• Vorname Nachname: Grund', '… und N weitere', Button 'OK' gleich. Grund: Ionic error.message / Flutter '$e' (z. B. 'RepositoryException: … (operation: …, code: …)').
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:198, lib/features/people/presentation/pages/person_import_page.dart:220, lib/features/people/presentation/widgets/import_widgets.dart:226-243
- [ ] **niedrig** `people/import/import.page` `effect-31a0aedd` [people/import/import.page.ts:275](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.ts#L275) (2. Prüfung: korrigiert)
  hoch-Lücke behoben (#325): nativ (auch iPad) Datei im Cache + Systemviewer (OpenFilex) wie Ionic, kein Teilen-Popover mehr; Vorlage mit Org- und Instanz-Zusatzfeldern, Name/Blatt/Kopf/Beispiel gleich. Rest niedrig: mobiler Browser bekommt einen Anker-Download (printing sharePdf, Blob-Typ application/pdf) statt des Web-Share-Sheets (Ionic downloadFileNative); auf iPhone-Safari/PWA prüfen – lässt sich die .xlsx dort nicht speichern, wäre es mittel.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:137, lib/core/services/native/native_file_service.dart:167, lib/core/services/native/native_file_io.dart:14
- [ ] **niedrig** `people/import/import.page` `text-da6273ad` [people/import/import.page.html:16](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.html#L16) (2. Prüfung: bestätigt)
  Text gleich. Ionic: grau (.intro medium, 0.9rem) / Flutter: normale Textfarbe. Der Text nennt .xls, das Flutter ablehnt (siehe field-bdcf25e7).
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:245, lib/features/people/presentation/widgets/import_widgets.dart:30
- [ ] **niedrig** `people/import/import.page` `text-ac3c014f` [people/import/import.page.html:37](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.html#L37)
  '— N Zeilen' gleich. Ionic: grau (medium) / Flutter: normale Textfarbe.
  Flutter: lib/features/people/presentation/widgets/import_widgets.dart:85-88
- [ ] **niedrig** `people/import/import.page` `text-432acf42` [people/import/import.page.html:37](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.html#L37)
  Dateiname fett gleich. Ionic: grau (medium) / Flutter: normale Textfarbe.
  Flutter: lib/features/people/presentation/widgets/import_widgets.dart:86
- [ ] **niedrig** `people/import/import.page` `text-9a34d1ef` [people/import/import.page.html:38](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.html#L38)
  Text gleich. Ionic: grau (medium, 0.9rem) / Flutter: normale Textfarbe.
  Flutter: lib/features/people/presentation/widgets/import_widgets.dart:90
- [ ] **niedrig** `people/import/import.page` `field-018f6a18` [people/import/import.page.html:102](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.html#L102)
  Gruppen-Dropdown pro Zeile (nicht bei Fehlern), Auswahl setzt groupResolved, gleich. Ionic: Label 'Gruppe' immer über dem Wert, ungeklärte Gruppe mit orangem Rahmen / Flutter: 'Gruppe' nur als Hinweis bei leerem Wert, ungeklärte Gruppe als orange Schrift.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:364-385
- [ ] **niedrig** `people/list/list.page` `loading-a2fa55fe` [people/list/list.page.ts:97](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L97)
  Ionic: blockierendes Loading-Overlay (ohne Text, 3 s) beim Instanzwechsel über das Header-Popover / Flutter: switchTenant ohne Overlay.
  Flutter: lib/shared/widgets/tenant/tenant_switcher_title.dart:389
- [ ] **niedrig** `people/list/list.page` `loading-275de79e` [people/list/list.page.ts:377](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L377)
  Ionic: blockierendes Overlay 'Reihenfolge wird gespeichert...' / Flutter: nur Spinner im Häkchen-Button, kein Overlay (X-Abbrechen und Ziehen bleiben bedienbar).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:463, lib/features/people/presentation/pages/people_list_page.dart:1169
- [ ] **niedrig** `people/list/list.page` `alert-0eb34b23` [people/list/list.page.ts:437](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L437)
  Ionic: Alert 'Instanz wählen' mit Radio-Liste (gespeicherte Instanz vorausgewählt) und Buttons 'Abbrechen' (setzt Filter auf Alle) / 'Filtern' / Flutter: Auswahl-Dialog 'Instanz wählen' ohne Buttons, Tipp auf eine Instanz filtert sofort, Schließen lässt den bisherigen Filter stehen. Gefilterte Daten gleich (Nicht-Betrachter-Konten der Instanz).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1084, lib/features/people/presentation/pages/people_list_page.dart:1095
- [ ] **niedrig** `people/list/list.page` `alert-1081984d` [people/list/list.page.ts:538](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L538)
  Ionic: Alert mit Radio 'Ja'/'Nein' (Ja bzw. gespeicherter Wert vorausgewählt) und 'Abbrechen' (→ Alle) / 'Filtern' / Flutter: einfacher Auswahl-Dialog 'Ja'/'Nein' ohne Buttons, Tipp filtert sofort, Schließen → Alle. Default true für leere Werte gleich.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1027, lib/features/people/presentation/pages/people_list_page.dart:1029, lib/features/people/presentation/pages/people_list_page.dart:1036
- [ ] **niedrig** `people/list/list.page` `loading-5e1535fb` [people/list/list.page.ts:821](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L821)
  Ionic: blockierendes Overlay 'Person wird entfernt...' / Flutter: kein Overlay.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1480
- [ ] **niedrig** `people/list/list.page` `loading-93ed0021` [people/list/list.page.ts:872](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L872) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay 'Wird pausiert...' / Flutter: kein Overlay; danach zusätzlich grüne Snackbar '<Vorname> wurde pausiert' (Ionic: keine Meldung).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:211, lib/features/people/presentation/widgets/pause_person_sheet.dart:221
- [ ] **niedrig** `people/list/list.page` `loading-8b3a6dad` [people/list/list.page.ts:969](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L969)
  Ionic: blockierendes Overlay 'Wird aktiviert...' / Flutter: kein Overlay.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1357
- [ ] **niedrig** `people/list/list.page` `modal-a495856e` [people/list/list.page.ts:1036](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L1036) (2. Prüfung: korrigiert)
  Gefilterte Personen übergeben, Neuladen bei Rückgabe true gleich. Ionic: Modal mit presentingElement → auf iOS Karten-Modal (Seite dahinter sichtbar, Wischen schließt), md Vollbild / Flutter: Vollbild-Dialog (fullscreenDialog) auf allen Plattformen. Erstprüfung: ok – Darstellung auf iOS weicht ab (wie instrument-list modal-1bead9c9 bewertet).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1280, lib/features/people/presentation/pages/people_list_page.dart:1289
- [ ] **niedrig** `people/list/list.page` `action-15041222` [people/list/list.page.html:47](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L47) (2. Prüfung: bestätigt)
  Ionic: Pull-to-Refresh lädt Personen und Termine (Prozente) neu und wartet / Flutter: invalidiert nur realtimePlayersProvider, Spinner endet sofort; Prozente kommen aus playerAttendancePercentagesProvider (nur per Realtime-Zähler aktualisiert).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:503, lib/features/people/presentation/pages/people_list_page.dart:648, lib/features/people/presentation/pages/people_list_page.dart:670
- [ ] **niedrig** `people/list/list.page` `text-ccf5d7d7` [people/list/list.page.html:228](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L228)
  Normalfall gleich ('<Gruppe> (n)', primärer Trenner). Sonderfälle: Personen ohne bekannte Gruppe – Ionic Trenner ' (n)' ohne Namen / Flutter 'Keine Gruppe (n)'; Flutter gruppiert nach Gruppenname statt Gruppen-ID (gleichnamige Gruppen würden zusammengelegt).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:404, lib/features/people/presentation/pages/people_list_page.dart:622
- [ ] **niedrig** `people/list/list.page` `action-e7b7f732` [people/list/list.page.html:230](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L230) (2. Prüfung: bestätigt)
  Ionic: Reihenfolge direkt in der normalen Liste (ion-reorder-Griffe in den vollen Zeilen, Gruppen-Trenner) / Flutter: eigene vereinfachte Liste (Karten nur mit Name + Ziehgriff, Gruppentitel als Text) plus X zum Verwerfen. Zeileninhalt siehe action-982a1154.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1189, lib/features/people/presentation/pages/people_list_page.dart:1147
- [ ] **niedrig** `people/list/list.page` `action-6ccc25e4` [people/list/list.page.html:505](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L505)
  Ionic: X-Icon in der Modal-Toolbar / Flutter: Textbutton 'Abbrechen' im Dialog.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1426
- [ ] **niedrig** `people/list/list.page` `action-64a96898` [people/list/list.page.html:521](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L521) (2. Prüfung: bestätigt)
  Ionic: FAB mit Archiv-Icon unten rechts im Modal / Flutter: Button 'Archivieren' mit Archiv-Icon in der Dialog-Aktionsleiste.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1430
- [ ] **niedrig** `people/list/list.page` `field-c1d3a82f` [people/list/list.page.html:545](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L545)
  Platzhalter Ionic 'Bitte gib einen Grund an...' / Flutter 'Gib einen Grund für die Pause an...' (personPauseReasonPlaceholder); sonst gleich (mehrzeilig, Satzanfang groß).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:112, lib/features/people/presentation/widgets/pause_person_sheet.dart:116
- [ ] **niedrig** `people/list/list.page` `field-187f6bb7` [people/list/list.page.html:567](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L567)
  Ionic: Inline-Kalender im Akkordeon (max heute, keine Untergrenze) / Flutter: Datumspicker-Dialog beim Tippen auf die Zeile (max heute, frühestens vor 5 Jahren).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:131, lib/features/people/presentation/widgets/pause_person_sheet.dart:135
- [ ] **niedrig** `people/list/list.page` `field-315040b9` [people/list/list.page.html:594](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L594) (2. Prüfung: bestätigt)
  Ionic: Inline-Kalender im Akkordeon (ab heute, ohne Obergrenze, keine Vorauswahl) / Flutter: Datumsdialog (ab heute, bis +3 Jahre, Start heute + 30 Tage).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:141, lib/features/people/presentation/widgets/pause_person_sheet.dart:150
- [ ] **niedrig** `people/list/list.page` `text-63b77c8c` [people/list/list.page.html:606](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L606)
  Ionic: '… Wenn ein Enddatum angegeben wird, wird die Person automatisch reaktiviert.' / Flutter: '… Wenn ein Enddatum angegeben ist, wird die Person danach automatisch wieder aktiviert.' (gleiche Bedeutung).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:157
- [ ] **niedrig** `people/list/list.page` `action-32a9bf9f` [people/list/list.page.html:610](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L610)
  Ionic: Block-Button in Primärfarbe / Flutter: gelber (warning) Button; sonst gleich (Pause-Icon, 'Pausieren', ohne Grund deaktiviert).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:163, lib/features/people/presentation/widgets/pause_person_sheet.dart:177
- [ ] **niedrig** `people/members/members.page` `toast-d347f87a` [people/members/members.page.ts:72](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/members/members.page.ts#L72)
  Ionic: roter Toast 'Fehler beim Laden der Mitglieder.' + darunter 'Keine Mitglieder gefunden.' / Flutter: kein Toast, Text 'Fehler beim Laden der Mitglieder.' inline mit Personen-Icon.
  Flutter: lib/features/members/presentation/pages/members_page.dart:98, lib/features/members/presentation/pages/members_page.dart:99
- [ ] **niedrig** `people/person/person.page` `loading-be5cc2f1` [people/person/person.page.ts:389](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L389)
  Ionic: blockierendes Loading „Wird zurückgesetzt...“ / Flutter: kein Ladeindikator beim Zurücksetzen
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1151, lib/features/people/presentation/widgets/person_detail/late_warning_card.dart
- [ ] **niedrig** `people/person/person.page` `toast-9348bff8` [people/person/person.page.ts:528](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L528)
  Ionic: Toast „Bitte gib den Vornamen und Nachnamen an.“ / Flutter: Inline-Validierung unter den Feldern „Vorname ist erforderlich“/„Nachname ist erforderlich“, Labels mit „*“
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:370, lib/features/people/presentation/pages/person_create_page.dart:389
- [ ] **niedrig** `people/person/person.page` `loading-b5454ced` [people/person/person.page.ts:532](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L532)
  Ionic: blockierendes Loading (3 s) beim Hinzufügen / Flutter: nur Speichern-Button deaktiviert, kein Overlay
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:334, lib/features/people/presentation/pages/person_create_page.dart:989
- [ ] **niedrig** `people/person/person.page` `loading-d68742ec` [people/person/person.page.ts:553](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L553)
  Ionic: blockierendes Loading beim Speichern / Flutter: nur Speichern-FAB deaktiviert (_isSaving), kein Overlay
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:587, lib/features/people/presentation/pages/person_detail_page.dart:1733
- [ ] **niedrig** `people/person/person.page` `toast-cee56561` [people/person/person.page.ts:738](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L738)
  Ionic: „Der Benutzer wurde erfolgreich entfernt“ / Flutter: „Account-Verknüpfung aufgehoben“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1582
- [ ] **niedrig** `people/person/person.page` `toast-f55609ac` [people/person/person.page.ts:740](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L740) (2. Prüfung: bestätigt)
  Ionic: „Fehler beim Entfernen des Benutzers“ (danger) / Flutter: „Fehler: {error}“ (danger).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1590
- [ ] **niedrig** `people/person/person.page` `alert-cd59453f` [people/person/person.page.ts:848](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L848)
  1 Treffer: gleich (Abbrechen/Ja). Mehrere Treffer: Ionic Alert mit Radio-Liste (erster vorausgewählt) + Abbrechen/Ja / Flutter: SimpleDialog, Tippen auf Eintrag übernimmt sofort, nur „Abbrechen“
  Flutter: lib/features/people/presentation/widgets/person_match_suggestions.dart:120, lib/features/people/presentation/widgets/person_match_suggestions.dart:148
- [ ] **niedrig** `people/person/person.page` `loading-ae31ca18` [people/person/person.page.ts:903](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L903)
  Ionic: blockierendes Loading „Die Personen werden zusammengeführt...“ / Flutter: nur LinearProgressIndicator in der Karte, nicht blockierend, ohne Text
  Flutter: lib/features/people/presentation/widgets/duplicate_candidates_card.dart:81, lib/features/people/presentation/widgets/duplicate_candidates_card.dart:132
- [ ] **niedrig** `people/person/person.page` `loading-9ba0a7e4` [people/person/person.page.ts:1013](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1013)
  Ionic: blockierendes Loading beim Account anlegen / Flutter: kein Ladeindikator
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1596
- [ ] **niedrig** `people/person/person.page` `toast-8807fdd9` [people/person/person.page.ts:1019](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1019) (2. Prüfung: bestätigt)
  Ionic: „Account wurde erfolgreich angelegt“ / Flutter: „Account erstellt. Passwort-E-Mail wurde gesendet.“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1655
- [ ] **niedrig** `people/person/person.page` `toast-fc0e45e2` [people/person/person.page.ts:1022](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1022)
  Ionic: Roh-Fehlermeldung error.message / Flutter: „{name} - Fehler beim Erstellen des Accounts: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1664
- [ ] **niedrig** `people/person/person.page` `loading-b96f785a` [people/person/person.page.ts:1090](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1090)
  Ionic: blockierendes Loading beim Bildupload / Flutter: nur Info-Toast „Lade Passbild hoch...“, nicht blockierend
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:225
- [ ] **niedrig** `people/person/person.page` `toast-7e0a2ff5` [people/person/person.page.ts:1119](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1119)
  Ionic: Roh-Fehler / Flutter: „Fehler beim Hochladen: {error}“
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:274
- [ ] **niedrig** `people/person/person.page` `loading-fc02b5d4` [people/person/person.page.ts:1203](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1203) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading während „Meinen Benutzer zuweisen“ / Flutter: kein Ladeindikator.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:962
- [ ] **niedrig** `people/person/person.page` `toast-968501f7` [people/person/person.page.ts:1213](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1213)
  Ionic: Roh-Fehler error.message / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:988
- [ ] **niedrig** `people/person/person.page` `toast-f74ad707` [people/person/person.page.ts:1251](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1251)
  Ionic: Roh-Fehler / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1044
- [ ] **niedrig** `people/person/person.page` `toast-f74ad707-2` [people/person/person.page.ts:1312](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1312)
  Ionic: Roh-Fehler / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1488
- [ ] **niedrig** `people/person/person.page` `toast-d7c9e86c` [people/person/person.page.ts:1371](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1371) (2. Prüfung: bestätigt)
  Ionic: „Die Person wurde erfolgreich kopiert/übertragen“ / Flutter: „1 Spieler erfolgreich kopiert/übertragen“.
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:819
- [ ] **niedrig** `people/person/person.page` `toast-b4300d3e` [people/person/person.page.ts:1373](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1373)
  Ionic: Roh-Fehler / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:830
- [ ] **niedrig** `people/person/person.page` `toast-f4e0ab31` [people/person/person.page.ts:1433](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1433)
  Ionic: Roh-Fehler / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:212
- [ ] **niedrig** `people/person/person.page` `alert-71956f19` [people/person/person.page.ts:1439](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1439)
  Texte/Buttons gleich (Überspringen/Pausieren, Checkboxen). Flutter besser: bietet nur Instanzen an, in denen der Nutzer Personen verwalten darf; Ionic listet alle verknüpften Instanzen
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:236, lib/features/people/presentation/widgets/pause_person_sheet.dart:284
- [ ] **niedrig** `people/person/person.page` `loading-cd6c7935` [people/person/person.page.ts:1496](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1496)
  Ionic: blockierendes Loading beim Eintragen der Abwesenheit / Flutter: kein Ladeindikator
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:230
- [ ] **niedrig** `people/person/person.page` `loading-6f0c380f` [people/person/person.page.ts:1546](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1546)
  Ionic: blockierendes Loading beim Löschen der Abwesenheit / Flutter: kein Ladeindikator
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:248
- [ ] **niedrig** `people/person/person.page` `actionsheet-eadcf3f0` [people/person/person.page.ts:1641](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1641) (2. Prüfung: korrigiert)
  Bedingung gleich (ausstehende Person, Admin/Verantwortliche), Texte, Reihenfolge und Wirkung gleich. Ionic: keine Icons, 'Abbrechen' mit role destructive (rot, in der Button-Gruppe) / Flutter: grünes Haken-Icon und grüne Schrift bei 'Person genehmigen', Icon bei 'Person ablehnen', 'Abbrechen' als normaler separater Abbrechen-Button (cancelDestructive fehlt, anders als im '…'-Menü).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1330
- [ ] **niedrig** `people/person/person.page` `loading-58ec291d` [people/person/person.page.ts:1680](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1680)
  Ionic: blockierendes Loading „Die Person wird abgelehnt...“ / Flutter: kein Ladeindikator
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1300
- [ ] **niedrig** `people/person/person.page` `toast-55836540` [people/person/person.page.ts:1702](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1702)
  Ionic: „Die Spielerdaten wurden erfolgreich aktualisiert.“ / Flutter: „Person wurde abgelehnt“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1313
- [ ] **niedrig** `people/person/person.page` `toast-26c7e22c` [people/person/person.page.ts:1705](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1705)
  Ionic: „Fehler beim aktualisieren des Spielers“ / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1322
- [ ] **niedrig** `people/person/person.page` `loading-00357310` [people/person/person.page.ts:1717](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1717) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading „Die Person wird genehmigt...“ / Flutter: kein Ladeindikator (vorher zusätzlicher Bestätigungsdialog „Person genehmigen?“).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1210, lib/features/people/presentation/pages/person_detail_page.dart:1233
- [ ] **niedrig** `people/person/person.page` `toast-c09ff9ac` [people/person/person.page.ts:1741](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1741)
  Ionic: „Die Spielerdaten wurden erfolgreich aktualisiert.“ / Flutter: „Person wurde genehmigt“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1241
- [ ] **niedrig** `people/person/person.page` `toast-1b04b6d6` [people/person/person.page.ts:1744](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1744)
  Ionic: „Fehler beim aktualisieren des Spielers“ / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1250
- [ ] **niedrig** `people/person/person.page` `action-5615e0d7` [people/person/person.page.html:49](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L49)
  Ionic: Viewer-Titel „Passbild“, Bild in voller Qualität (ohne ?quality=20) / Flutter: Titel „{Vorname Nachname}.jpg“, Bild-URL unverändert, keine Aktionen im Viewer
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:205, lib/shared/widgets/sheets/image_viewer_sheet.dart:276
- [ ] **niedrig** `people/person/person.page` `text-e915fb37` [people/person/person.page.html:74](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L74)
  Detail: Label „Vorname“ gleich; Neu-Seite: „Vorname *“
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:236, lib/features/people/presentation/pages/person_create_page.dart:365
- [ ] **niedrig** `people/person/person.page` `field-4b77b853` [people/person/person.page.html:75](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L75)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe (Detail, mit Pflicht-Validierung); Neu-Seite: TextFormField mit Pflicht-Validierung, Namensvorschläge wie Ionic
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:233, lib/features/people/presentation/pages/person_create_page.dart:362
- [ ] **niedrig** `people/person/person.page` `text-c4ad9070` [people/person/person.page.html:82](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L82)
  Detail: Label „Nachname“ gleich; Neu-Seite: „Nachname *“
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:252, lib/features/people/presentation/pages/person_create_page.dart:384
- [ ] **niedrig** `people/person/person.page` `field-6e1a9b00` [people/person/person.page.html:83](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L83)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe (Detail, mit Pflicht-Validierung); Neu-Seite: TextFormField mit Pflicht-Validierung
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:249, lib/features/people/presentation/pages/person_create_page.dart:381
- [ ] **niedrig** `people/person/person.page` `text-5dbfd756` [people/person/person.page.html:116](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L116) (2. Prüfung: bestätigt)
  Prozent-Badge (Score) der Duplikat-Kandidaten fehlt in der Flutter-Karte (lib/features/people/presentation/widgets/duplicate_candidates_card.dart:133).
- [ ] **niedrig** `people/person/person.page` `action-c72e602e` [people/person/person.page.html:131](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L131)
  Schließen-Button gleich; Flutter zeigt zusätzlich Überschrift „Person in anderer Instanz gefunden?“ über den Vorschlägen (Ionic ohne Überschrift)
  Flutter: lib/features/people/presentation/widgets/person_match_suggestions.dart:40, lib/features/people/presentation/widgets/person_match_suggestions.dart:46
- [ ] **niedrig** `people/person/person.page` `field-05790430` [people/person/person.page.html:164](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L164) (2. Prüfung: bestätigt)
  Ionic: Inline-Textarea (autoGrow) / Flutter: Zeile („Keine Notizen“ wenn leer), Tipp öffnet Editor-Sheet; leere Notiz wird als null gespeichert.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:273, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:278
- [ ] **niedrig** `people/person/person.page` `field-4bf62b27` [people/person/person.page.html:221](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L221)
  Ionic: Label „Gruppe“, Modal-Select / Flutter: Label je Instanztyp „Stimme“/„Instrument“/„Gruppe“, Auswahl-Sheet; Wechsel setzt Stimmführer zurück wie Ionic
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:289, lib/features/people/presentation/pages/person_detail_page.dart:444
- [ ] **niedrig** `people/person/person.page` `text-bb66373a` [people/person/person.page.html:245](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L245)
  Ionic: „Telefon-/Handynummer“ / Flutter: „Telefon“
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:336
- [ ] **niedrig** `people/person/person.page` `field-84804c14` [people/person/person.page.html:246](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L246) (2. Prüfung: bestätigt)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; zusätzlich Anruf-Button; leer + nicht bearbeitbar ausgeblendet (Ionic: leeres deaktiviertes Feld).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:330
- [ ] **niedrig** `people/person/person.page` `action-02594b69` [people/person/person.page.html:259](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L259)
  Ionic: separater Kalender-Button am Feld / Flutter: kein eigener Button, Tipp auf die Zeile öffnet die Datumsauswahl
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `modal-9c171caa` [people/person/person.page.html:266](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L266)
  Ionic: Modal mit Rad-Datumsauswahl (preferWheel) / Flutter: Material-DatePicker-Dialog bzw. Kalender-Karte (iOS-Look)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371, lib/shared/widgets/adaptive/app_pickers.dart:12
- [ ] **niedrig** `people/person/person.page` `field-946f7994` [people/person/person.page.html:268](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L268)
  Ionic: ion-datetime Rad, max = heute / Flutter: Kalender, lastDate = heute; Speichern als Datum wie Ionic; setzt correctBirthday beim Speichern
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371, lib/features/people/presentation/pages/person_detail_page.dart:643
- [ ] **niedrig** `people/person/person.page` `action-02594b69-2` [people/person/person.page.html:291](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L291)
  Ionic: separater Kalender-Button am Feld / Flutter: kein eigener Button, Tipp auf die Zeile öffnet die Datumsauswahl
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `modal-637d2f88` [people/person/person.page.html:298](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L298)
  Ionic: Modal mit Rad-Datumsauswahl (preferWheel) / Flutter: Material-DatePicker-Dialog bzw. Kalender-Karte (iOS-Look)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `field-6cfcad0a` [people/person/person.page.html:300](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L300)
  Ionic: ion-datetime Rad, max = heute / Flutter: Kalender, lastDate = heute; Speichern als Datum wie Ionic
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `action-02594b69-3` [people/person/person.page.html:323](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L323) (2. Prüfung: bestätigt)
  Ionic: separater Kalender-Button am Feld „Beigetreten am“ / Flutter: kein eigener Button, Tipp auf die Zeile öffnet die Datumsauswahl.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:184, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:377
- [ ] **niedrig** `people/person/person.page` `modal-5e3cc20f` [people/person/person.page.html:330](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L330)
  Ionic: Modal mit Rad-Datumsauswahl (preferWheel) / Flutter: Material-DatePicker-Dialog bzw. Kalender-Karte (iOS-Look)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `field-8c59f281` [people/person/person.page.html:332](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L332)
  Ionic: ion-datetime Rad, max = heute / Flutter: Kalender, lastDate = heute; Speichern als Datum wie Ionic
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `text-c617e6c6` [people/person/person.page.html:349](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L349)
  Label „Eltern“ gleich; Flutter-Bedingung ohne „!isParent“ (Ionic blendet das Feld für Benutzer mit Rolle Elternteil aus)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:194, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:599
- [ ] **niedrig** `people/person/person.page` `field-06ab1bbe` [people/person/person.page.html:350](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L350)
  Ionic: Modal-Select, ohne Auswahl „Nicht festgelegt“ / Flutter: Auswahl-Sheet mit Option „Nicht festgelegt“, Anzeige ohne Auswahl aber „Nicht zugewiesen“
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:599
- [ ] **niedrig** `people/person/person.page` `field-6acc513f` [people/person/person.page.html:402](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L402)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; leer + nicht bearbeitbar ausgeblendet
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:848
- [ ] **niedrig** `people/person/person.page` `field-7662f2a7` [people/person/person.page.html:435](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L435)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; leer + nicht bearbeitbar ausgeblendet (Ionic: immer sichtbar)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:877
- [ ] **niedrig** `people/person/person.page` `field-016207ea` [people/person/person.page.html:462](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L462)
  Flutter: zusätzliche Leer-Option „Keine Schicht zugewiesen“, Anzeige „Nicht ausgewählt“ (Ionic: keine Leer-Option, vorbelegt mit erster Schicht)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:529
- [ ] **niedrig** `people/person/person.page` `field-ea337733` [people/person/person.page.html:474](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L474)
  Ionic: ion-datetime-button / Flutter: Zeile mit Datum, leer „Nicht angegeben“, Tipp öffnet Datumsauswahl
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:568
- [ ] **niedrig** `people/person/person.page` `modal-ac91c261` [people/person/person.page.html:475](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L475)
  Ionic: Modal mit ion-datetime / Flutter: DatePicker-Dialog bzw. Kalender-Karte
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:583
- [ ] **niedrig** `people/person/person.page` `text-79d104bf` [people/person/person.page.html:490](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L490) (2. Prüfung: korrigiert)
  Bedingung nicht ganz gleich. Ionic: !readOnly || otherExercise (leerer String gilt als leer) / Flutter: otherExercise != null || canEdit → Beobachter und archivierte Personen sehen bei gespeichertem '' eine leere Zeile „Sonstige Dienste“.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:223, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:644
- [ ] **niedrig** `people/person/person.page` `field-eb1656da` [people/person/person.page.html:491](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L491)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:641
- [ ] **niedrig** `people/person/person.page` `field-d1e5b0ca` [people/person/person.page.html:510](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L510)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; Prüfung im Sheet nur auf „@“; Suche in anderen Instanzen nach Änderung statt bei Blur; gesperrt wenn appId wie Ionic
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:84, lib/features/people/presentation/pages/person_detail_page.dart:852
- [ ] **niedrig** `people/person/person.page` `action-06c55240` [people/person/person.page.html:514](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L514)
  Ionic: Lupen-Icon-Button rechts im E-Mail-Feld, deaktiviert ohne E-Mail / Flutter: Textbutton „In anderer Instanz suchen“ unter dem Feld, nur sichtbar mit E-Mail
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:94
- [ ] **niedrig** `people/person/person.page` `action-0de62271` [people/person/person.page.html:519](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L519)
  Ionic: roter Papierkorb-Icon-Button rechts im E-Mail-Feld / Flutter: Outlined-Button „Account-Verknüpfung aufheben“ unter der Rollenauswahl
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:127
- [ ] **niedrig** `people/person/person.page` `field-280cafd6` [people/person/person.page.html:530](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L530) (2. Prüfung: bestätigt)
  Optionen/Reihenfolge, Stimmführer-Optionen nur bei isLeader, Sperre bei Hauptgruppe, sofortiges Schreiben + Toast „Die Rolle wurde erfolgreich aktualisiert.“ gleich. Flutter besser: aktuelle Rolle außerhalb der Liste (z. B. Admin) wird angezeigt statt leerem Select; Bedingung nur appId (Ionic email && appId).
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:211, lib/features/people/presentation/widgets/person_detail/account_accordion.dart:225, lib/features/people/presentation/pages/person_detail_page.dart:1492
- [ ] **niedrig** `people/person/person.page` `action-36a985b0` [people/person/person.page.html:554](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L554)
  Ionic: X-Icon in der Toolbar / Flutter: Textbutton „Schließen“
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:296
- [ ] **niedrig** `people/person/person.page` `field-247f92a0` [people/person/person.page.html:585](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L585)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:766
- [ ] **niedrig** `people/person/person.page` `modal-9dba127a` [people/person/person.page.html:608](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L608)
  Ionic: Modal mit Rad-Datumsauswahl / Flutter: DatePicker-Dialog bzw. Kalender-Karte
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:795
- [ ] **niedrig** `people/person/person.page` `field-e423e2ec` [people/person/person.page.html:610](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L610)
  Ionic: max = heute / Flutter: Kalender 1900–2100 (kein Maximum heute)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:795, lib/shared/widgets/sheets/field_editor_sheet.dart:213
- [ ] **niedrig** `people/person/person.page` `field-50c752ee` [people/person/person.page.html:621](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L621)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe (Auswahl-Sheet); fehlender Wert in Ionic mit erster Option vorbelegt, Flutter „Nicht angegeben“
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:808
- [ ] **niedrig** `people/person/person.page` `field-049486aa` [people/person/person.page.html:628](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L628)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe (4 Zeilen)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:766
- [ ] **niedrig** `people/person/person.page` `modal-cc0c1d20` [people/person/person.page.html:635](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L635)
  Ionic: Vollbild-Modal / Flutter: Bottom-Sheet mit 85 % Höhe
  Flutter: lib/features/people/presentation/widgets/church_picker_sheet.dart:26
- [ ] **niedrig** `people/person/person.page` `text-4ba50278` [people/person/person.page.html:707](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L707) (2. Prüfung: bestätigt)
  Ionic: Bereich „Historie“ nur sichtbar, wenn Einträge vorhanden (personAttendance wird nie befüllt, also history.length) / Flutter: immer sichtbar, leer mit „Keine Historie vorhanden“ (Durchschnitt 0 %), zusätzlicher Umschalter „Alle anzeigen“ (alle Saisons).
  Flutter: lib/features/people/presentation/widgets/person_detail/historie_accordion.dart:49, lib/features/people/presentation/widgets/person_detail/historie_accordion.dart:76, lib/features/people/presentation/widgets/person_detail/historie_accordion.dart:102
- [ ] **niedrig** `people/person/person.page` `text-0f8281df` [people/person/person.page.html:803](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L803)
  Text gleich; Flutter zählt Termine ab heute (gte heute), Ionic nur Termine nach jetzt — heutige Termine erscheinen in Flutter zusätzlich hier und in der Historie
  Flutter: lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:20, lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:121
- [ ] **niedrig** `people/person/person.page` `text-9bed7686` [people/person/person.page.html:811](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L811) (2. Prüfung: bestätigt)
  Format „dd.MM.yyyy | Titel“ gleich; Flutter ignoriert hide_name der Terminart (Ionic zeigt dann nur das Datum).
  Flutter: lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:41, lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:142
- [ ] **niedrig** `people/person/person.page` `field-31cb4e6e` [people/person/person.page.html:954](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L954)
  Ionic: Inline-Kalender im aufklappbaren Bereich, max = heute / Flutter: Datumsdialog beim Tipp, lastDate heute, frühestens vor 5 Jahren
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:131
- [ ] **niedrig** `people/person/person.page` `field-932fcf9d` [people/person/person.page.html:976](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L976)
  Ionic: Inline-Kalender im aufklappbaren Bereich, min = heute / Flutter: Datumsdialog, firstDate heute, bis +3 Jahre, Start +30 Tage
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:145
- [ ] **niedrig** `people/person/person.page` `action-35f05e9d` [people/person/person.page.html:1029](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1029) (2. Prüfung: bestätigt)
  Ionic: eigener Löschen-Button am „Von“-Datum (löscht nur Von) / Flutter: kein Button an „Von“, ein Button an „Bis“ löscht beide Daten (Datumsbereichs-Auswahl).
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:172
- [ ] **niedrig** `people/person/person.page` `field-3c608429` [people/person/person.page.html:1035](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1035)
  Ionic: zwei Inline-Kalender (Von/Bis) ohne Grenzen / Flutter: ein Zeitraum-Dialog (showDateRangePicker) für Von und Bis, Vorjahr bis +3 Jahre
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:96
- [ ] **niedrig** `people/person/person.page` `action-227003e4` [people/person/person.page.html:1051](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1051)
  Ionic: löscht nur „Bis“ / Flutter: löscht „Von“ und „Bis“
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:180
- [ ] **niedrig** `people/person/person.page` `field-e2731760` [people/person/person.page.html:1057](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1057)
  Ionic: Inline-Kalender, min = Von / Flutter: gemeinsamer Zeitraum-Dialog
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:96
- [ ] **niedrig** `people/person/person.page` `action-22e55c57` [people/person/person.page.html:1083](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1083)
  Ionic: X-Button in der Toolbar / Flutter: Textbutton „Abbrechen“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1092
- [ ] **niedrig** `people/person/person.page` `field-03332121` [people/person/person.page.html:1092](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1092) (2. Prüfung: bestätigt)
  Ionic: natives Datumsfeld (type=date), keine Grenze / Flutter: Zeile mit Datum, Tipp öffnet Datumsauswahl, lastDate heute.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1063, lib/features/people/presentation/pages/person_detail_page.dart:1069
- [ ] **niedrig** `people/person/person.page` `text-b8f39c05` [people/person/person.page.html:1095](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1095)
  Ionic: Label „Notiz“ / Flutter: „Grund (optional)“ mit Hinweistext
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1084
- [ ] **niedrig** `people/person/person.page` `action-7114e66d` [people/person/person.page.html:1099](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1099) (2. Prüfung: bestätigt)
  Ionic: FAB mit Archiv-Icon / Flutter: roter Button „Archivieren“ im Dialog.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1093
- [ ] **niedrig** `people/person/person.page` `text-0f2b968d` [people/person/person.page.html:1112](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1112)
  Ionic: „Kopieren von {name}“/„Übertragen von {name}“ / Flutter: „Spieler kopieren“/„Spieler übertragen“
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:114
- [ ] **niedrig** `people/person/person.page` `action-cf8fa6af` [people/person/person.page.html:1141](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1141)
  Ionic: Button „Kopieren“/„Übertragen“, deaktiviert ohne Instanz/Gruppe / Flutter: Button „Kopieren“/„Übertragen“ des Massen-Sheets mit Fortschritt
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:200
- [ ] **niedrig** `teacher/teacher.page` `field-fc1d0925` [teacher/teacher.page.html:18](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teacher/teacher.page.html#L18) (2. Prüfung: korrigiert)
  Ladefehler behoben: _openTeacherPage wartet jetzt auf groupsProvider (_loadGroups), Namen und Auswahl immer gefüllt; Mehrfachauswahl aller Gruppen inkl. Hauptgruppe, Label „Instrumente“. Nicht behoben, aber schon vorher als niedrig vermerkt: Ionic ion-select interface=modal (eigene Vollbild-Auswahlseite) / Flutter Dialog mit Checkboxen und „Abbrechen“/„OK“. Der Fix setzte „ok“, die Darstellungsabweichung besteht weiter → diff niedrig.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:151, lib/features/teachers/presentation/pages/teachers_list_page.dart:308, lib/features/teachers/presentation/pages/teachers_list_page.dart:313
- [ ] **niedrig** `teachers/teachers.page` `modal-81bd0046` [teachers/teachers.page.ts:67](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teachers/teachers.page.ts#L67)
  Nur für Admin/Verantwortliche, übergibt den Lehrer (Schüler aus playersProvider). Ionic: iOS Karten-Modal (presentingElement), md Vollbild / Flutter: Vollbild-Dialog (fullscreenDialog) auf allen Plattformen; Liste wird danach neu geladen.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:135
- [ ] **niedrig** `teachers/teachers.page` `field-cfeef758` [teachers/teachers.page.html:41](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teachers/teachers.page.html#L41)
  Label „Instrumente“, Gruppen ohne Hauptgruppe, Mehrfachauswahl. Ionic: ion-select interface=modal (Vollbild-Auswahlliste), Auswahl bleibt nach dem Anlegen für das nächste Öffnen erhalten (selInstruments) / Flutter: Dialog mit Checkboxen und „Abbrechen“/„OK“, Formular startet jedes Mal leer.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:385, lib/features/teachers/presentation/pages/teachers_list_page.dart:113
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `x-5b376c7a36` **Fehler beim Org-Feld-Speichern: zusätzlicher Toast** [src/app/services/organisation/organisation.service.ts:88-91](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/organisation/organisation.service.ts#L88-L91)
  Ionic: orgSvc.updatePersonFieldValues zeigt bei Fehler zusätzlich 'Fehler beim Speichern der gemeinsamen Zusatzfelder' (danger), danach 'Fehler beim Speichern' / Flutter: nur 'Fehler beim Speichern'.
  Flutter: lib/data/repositories/profile_repository.dart:281-319, lib/features/people/presentation/pages/bulk_edit_page.dart:240-243
- [ ] **niedrig** `people/import/import.page` `x-ab5b4f49ad` **Fehlergrund im Fehlerdialog technisch** [src/app/services/db.service.ts:3638-3640](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/db.service.ts#L3638-L3640)
  Ionic: reason = error.message ?? 'Unbekannter Fehler' / Flutter: '$e' inkl. Klassenname/Operation/Code (z. B. 'RepositoryException: … (operation: createPlayer, code: 23505)').
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:197-199
- [ ] **niedrig** `people/list/list.page` `x-dac55a9bd1` **Anwesenheits-Badge / Prozentbasis** [src/app/utilities/Utils.ts:129](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/utilities/Utils.ts#L129)
  Ionic: Personen ohne gezählte Termine zeigen roten '0%'-Badge; Basis ab seasonStart bzw. 2023-01-01 bis jetzt+24 h, für Nicht-Admins ohne archivierte Termine / Flutter: kein Badge, wenn keine gezählten Termine; Basis ab seasonStart (ohne Fallback) bis jetzt, archivierte Termine mitgezählt.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1629, lib/core/providers/attendance_providers.dart:286
- [ ] **niedrig** `people/list/list.page` `x-325647b4ef` **Reorder-Modus** [src/app/people/list/list.page.ts:324](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L324)
  Ionic: Griffe in der normalen Liste, kein Abbrechen, Overlay beim Speichern, schreibt nur Personen mit sort_order / Flutter: separate Kartenliste, zusätzliches X zum Verwerfen, kein Overlay, schreibt sort_order für alle gefilterten Personen aller Gruppen (mit tenantId).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:448, lib/features/people/presentation/pages/people_list_page.dart:1148, lib/features/people/presentation/pages/people_list_page.dart:1189, lib/data/repositories/player_repository.dart:1844
- [ ] **niedrig** `people/list/list.page` `x-f6927de895` **Auto-Entpausieren nur beim ersten Öffnen** [src/app/people/list/list.page.ts:140](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L140)
  Ionic: checkAndUnpausePlayers (Admin/Verantwortlicher) in jedem initializeData, also auch nach Instanzwechsel, vor dem Laden der Liste / Flutter: nur im initState per Post-Frame-Callback; ein Instanzwechsel bei offener Seite löst es nicht erneut aus.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:125, lib/features/people/presentation/pages/people_list_page.dart:128
- [ ] **niedrig** `people/list/list.page` `x-56b7f726f5` **Flutter-Zusatz: Personen übertragen** [src/app/people/list/list.page.html:166](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L166)
  Ionic: kein Mehrfachauswahl-Modus in der Personenliste / Flutter: Optionsmenü-Eintrag 'Personen übertragen' (Admin/Verantwortlicher) mit Auswahlmodus, AppBar 'n ausgewählt' und Übergabe-Sheet.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:963, lib/features/people/presentation/pages/people_list_page.dart:651, lib/features/people/presentation/pages/people_list_page.dart:1255
- [ ] **niedrig** `people/members/members.page` `x-1730d62932` **Ladefehler inline statt Toast** [src/app/people/members/members.page.ts:72](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/members/members.page.ts#L72)
  Ionic: roter Toast und leere Liste / Flutter: Fehlertext inline, kein Toast.
  Flutter: lib/features/members/presentation/pages/members_page.dart:98
- [ ] **niedrig** `people/person/person.page` `x-78e8317eac` **Datenübernahme (E-Mail vergeben) ohne Passbild** [src/app/people/person/person.page.ts:813](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L813) (2. Prüfung: korrigiert)
  Zu hoch bewertet: Ionic speichert img beim Aktualisieren nie (pickPersonFields ohne img, db-helpers.ts:86) – das übernommene Passbild ist dort nur bis zum Schließen im Header sichtbar. Bleibt: fehlende Header-Vorschau; Ionic überschreibt otherExercise/range mit den Werten des Treffers auch wenn null (leert vorhandene Werte), Flutter nur wenn gesetzt (hier Flutter besser).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:866, lib/features/people/presentation/pages/person_detail_page.dart:873, lib/features/people/presentation/pages/person_detail_page.dart:874
- [ ] **niedrig** `duty/duty-assign-modal/duty-assign-modal.component` `x-9cfbd56a81` **Namens-Tiebreak nicht locale-aware** [src/app/duty/duty-assign-modal/duty-assign-modal.component.ts:41](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-assign-modal/duty-assign-modal.component.ts#L41)
  Ionic: bei gleicher Dienstanzahl a.name.localeCompare(b.name) (Umlaute bei Grundbuchstaben, Groß/Klein egal) / Flutter: a.name.compareTo(b.name) (Code-Unit-Reihenfolge, z. B. „Özil“ nach „Zoe“, Kleinbuchstaben nach Großbuchstaben).
  Flutter: lib/features/duty/presentation/widgets/duty_assign_sheet.dart:95
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-41b22d1e2d` **Speichern bei Fehler** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:236](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L236)
  Ionic: dutySvc.assign zeigt „Fehler beim Einteilen“ und wirft, die Schleife bricht beim ersten fehlerhaften Termin ab, übrige Termine werden nicht eingeteilt / Flutter: Fehler pro Termin abgefangen, alle übrigen Termine werden trotzdem eingeteilt, danach ein Toast „Fehler beim Einteilen“; Seite bleibt in beiden offen.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:277
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-3829883249` **Namens-Tiebreak nicht locale-aware** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:174](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L174)
  Ionic: „Dienste pro Person“ und Tausch-Optionen bei Gleichstand mit localeCompare sortiert / Flutter: String.compareTo (Umlaute nach Z, Kleinbuchstaben nach Großbuchstaben).
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:229, lib/features/duty/presentation/pages/duty_distribute_page.dart:469
- [ ] **niedrig** `duty/unavailability-modal/unavailability-modal.component` `x-1017c7460d` **Ladefehler der Regeln** [src/app/duty/unavailability-modal/unavailability-modal.component.ts:54](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/unavailability-modal/unavailability-modal.component.ts#L54)
  Ionic: Toast „Fehler beim Laden der Verfügbarkeit“, dann leere Liste mit „Noch keine Regel…“ und Button „Regel hinzufügen“ / Flutter: nur Text „Fehler: …“ im Body, kein Button „Regel hinzufügen“.
  Flutter: lib/features/duty/presentation/pages/unavailability_page.dart:233
- [ ] **niedrig** `duty/unavailability-modal/unavailability-modal.component` `x-21dc916f43` **Typnamen in der Regel-Liste** [src/app/duty/unavailability-modal/unavailability-modal.component.ts:62](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/unavailability-modal/unavailability-modal.component.ts#L62)
  Ionic: typesText sucht nur in den sichtbaren Typen (visible !== false), unsichtbare Typen fehlen im Text / Flutter: Liste nutzt alle Typen, Namen unsichtbarer Typen erscheinen.
  Flutter: lib/features/duty/presentation/pages/unavailability_page.dart:230
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-d0c116c654` **Sortiermodus ohne Verschieben nummeriert neu** [src/app/instruments/instrument-list/instrument-list.page.ts:401](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L401)
  Ionic: Häkchen ohne Verschieben speichert nur vorhandene sort_order-Werte unverändert (null bleibt null) / Flutter: computeGlobalSortOrder vergibt beim Verlassen immer 1..n an alle Gruppen und schreibt sie (Badges ändern sich, Gruppen ohne sort_order bekommen eine).
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:49
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-353ca926f3` **Namens-Tiebreak der Kategorien** [src/app/instruments/instrument-list/instrument-list.page.ts:150](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L150)
  Ionic: Kategorien ohne sort_order per localeCompare sortiert / Flutter: toLowerCase().compareTo (Umlaute nach Z).
  Flutter: lib/core/utils/instrument_sort.dart:79
- [ ] **niedrig** `instruments/instrument/instrument.page` `x-718f3b20d0` **Geschriebene Werte beim Aktualisieren** [src/app/instruments/instrument/instrument.page.ts:64](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.ts#L64)
  Ionic: schreibt notes, range, tuning, clefs, name, maingroup, category, synonyms so wie sie sind ('' bleibt '', versteckte Felder unverändert) / Flutter: trimmt, schreibt leere range/synonyms/notes als null, maingroup nicht, und schreibt tuning/clefs immer – bei Chor/Allgemein/Hauptgruppe (Felder versteckt) wird ein leerer Wert zu „C“ bzw. [g].
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:730
- [ ] **niedrig** `teachers/teachers.page` `x-791ebfa771` **Löschen von Lehrern nur in Flutter** [src/app/teachers/teachers.page.html:18](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teachers/teachers.page.html#L18)
  Ionic: keine Löschfunktion für Lehrer / Flutter: Wischen nach links (Admin/Verantwortliche) → Dialog „Lehrer löschen“ / „Möchtest du "{Name}" wirklich löschen?“ mit „Abbrechen“/„Löschen“, löscht den Lehrer und zeigt „Lehrer gelöscht“ (auch wenn das Löschen fehlschlägt, da deleteTeacher den Fehler verschluckt).
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:172, lib/features/teachers/presentation/pages/teachers_list_page.dart:211
