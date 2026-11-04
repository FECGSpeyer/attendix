# Fix-Paket „personen“

Soll: Ionic 4.19.7 (9f9b82af). Ist: Flutter 1aba6be, 2157fa0, b218510 (normales Design).
Erzeugt mit `node tool/parity/parity.mjs fixlists` aus `docs/parity/status/`. Item-IDs siehe `ionic-inventory.json`.

## Angleichen (hoch/mittel): 79

- [ ] **hoch** `instruments/instrument-list/instrument-list.page` `action-d2efa7e3` [instruments/instrument-list/instrument-list.page.html:94](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.html#L94) (2. Prüfung: korrigiert)
  Titel „{Name} (Hauptgruppe)“ / „Name (Stimmung)“ / nur Name bei Chor/Allgemein, Schlüssel-Zeile, sort_order-Badge, Badge „n Personen“ (rot bei 0), Tipp öffnet Bearbeiten nur für Admin/Verantwortliche und nicht im Sortiermodus wie Ionic. Abweichung Anzahl: Ionic zählt aus db.getPlayers() (left = null, pending = false) / Flutter getPlayerCountsForGroups filtert nur left = null – ausstehende Registrierungen (tenant-register setzt instrument) werden mitgezählt, Badge zeigt zu hohe Zahl bzw. nicht rot. Erstprüfer „mittel“ → „hoch“: falsche Daten, gleicher Fehlertyp wie teachers action-5b603f4a (dort hoch). Kosmetisch: leere Stimmung „(C)“ statt „()“.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:278, lib/data/repositories/group_repository.dart:216
- [ ] **hoch** `people/import/import.page` `field-bdcf25e7` [people/import/import.page.html:25](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.html#L25) (2. Prüfung: bestätigt)
  Auswahl .xlsx/.xls/.csv gleich. Ionic: SheetJS liest auch .xls / Flutter: .xls wird mit 'Das alte Excel-Format (.xls) wird nicht unterstützt…' abgelehnt, obwohl der Einleitungstext .xls nennt.
  Flutter: lib/core/utils/import_file_io.dart:10, lib/core/utils/spreadsheet_reader.dart:43
- [ ] **hoch** `people/import/import.page` `field-2d96b151` [people/import/import.page.html:44](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.html#L44) (2. Prüfung: korrigiert)
  Dropdown je Spalte (Label = Spaltenname, Platzhalter 'Feld wählen...', Standardoptionen in gleicher Reihenfolge) gleich. Ionic: danach alle Zusatzfelder inkl. Org-Felder / Flutter: nur Tenant-Zusatzfelder → Spalten für Org-Felder lassen sich nicht zuordnen, ihre Werte gehen beim Import verloren. Erstprüfung: mittel – fehlende Funktion/Daten ist hoch (wie das zugehörige extra).
  Flutter: lib/features/people/presentation/widgets/import_widgets.dart:92, lib/features/people/presentation/pages/person_import_page.dart:63
- [ ] **hoch** `people/import/import.page` `x-081d71cc45` **Org-Zusatzfelder beim Import nicht verfügbar** [src/app/people/import/import.page.ts:57-63](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.ts#L57-L63) (2. Prüfung: bestätigt)
  Real: Ionic buildContext/downloadTemplate nutzen db.getPersonExtraFields() (Org-Felder + Instanz-Felder); die Werte landen in player.additional_fields und werden angezeigt (hydrateSharedPersonFieldValues überschreibt nur bei vorhandenem Org-Wert). Flutter _buildContext und Vorlage nur currentTenant.additionalFields (personListExtraFieldsProvider ungenutzt) → in Instanzen einer Organisation mit Org-Zusatzfeldern keine Zuordnung, Werte gehen verloren, Vorlage ohne diese Spalten.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:52-61, lib/features/people/presentation/pages/person_import_page.dart:108-111, lib/core/providers/profile_providers.dart:67-91
- [ ] **hoch** `people/import/import.page` `x-dce118d389` **.xls-Dateien nicht lesbar** [src/app/people/import/import.page.ts:101-104](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.ts#L101-L104) (2. Prüfung: bestätigt)
  Real: Ionic readSpreadsheetFile/SheetJS read() liest auch .xls (accept '.xlsx,.xls,.csv'). Flutter: Dateiauswahl erlaubt .xls, readSpreadsheet lehnt ab mit 'Das alte Excel-Format (.xls) wird nicht unterstützt. Bitte als .xlsx oder .csv speichern.' – obwohl der Einleitungstext (wie Ionic) 'Excel- (.xlsx/.xls)' verspricht. Import aus .xls nicht möglich → hoch.
  Flutter: lib/core/utils/spreadsheet_reader.dart:39-50, lib/core/utils/import_file_io.dart:13, lib/features/people/presentation/pages/person_import_page.dart:249
- [ ] **hoch** `people/list/list.page` `action-982a1154` [people/list/list.page.html:233](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L233) (2. Prüfung: bestätigt)
  Tipp öffnet die Person (Darstellung siehe modal-38ba21ec); Name, Untertext (Gruppe | Geburtsdatum | Testergebnis | Instrumente | Sonstige Dienste), Notizen und Badges (Stimmführer/Neu/Problemfall/Pausiert/Prüfling, Prozent 75/50) in Ionic-Reihenfolge. Nachgeprüft: Ansicht 'Lehrer' zeigt in Flutter immer 'Kein Lehrer', weil Person.teacherName nie befüllt wird (Ionic 'Lehrer: <Name>'); Zusatzfeld-Badges/-Zeilen ohne aufgefüllte Defaults; kein '0%'-Badge ohne gezählte Termine.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:604, lib/features/people/presentation/pages/people_list_page.dart:1575, lib/data/models/person/person.dart:141
- [ ] **hoch** `people/list/list.page` `action-0df20264` [people/list/list.page.html:342](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L342) (2. Prüfung: bestätigt)
  Tipp öffnet die Person (Darstellung siehe modal-38ba21ec); Name, Untertext (Gruppe | Geburtsdatum | Testergebnis | Instrumente | Sonstige Dienste), Notizen und Badges (Stimmführer/Neu/Problemfall/Pausiert/Prüfling, Prozent 75/50) in Ionic-Reihenfolge. Nachgeprüft: Ansicht 'Lehrer' zeigt in Flutter immer 'Kein Lehrer', weil Person.teacherName nie befüllt wird (Ionic 'Lehrer: <Name>'); Zusatzfeld-Badges/-Zeilen ohne aufgefüllte Defaults; kein '0%'-Badge ohne gezählte Termine.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:604, lib/features/people/presentation/pages/people_list_page.dart:1575, lib/data/models/person/person.dart:141
- [ ] **hoch** `people/list/list.page` `x-542476aae8` **Lehrer-Zeile immer 'Kein Lehrer'** [src/app/people/list/list.page.html:254](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L254) (2. Prüfung: bestätigt)
  Echt: teacherName ist includeFromJson false und wird nirgends gesetzt (enrichPlayers setzt nur groupName) → Ansicht 'Lehrer' zeigt bei allen Nicht-Hauptgruppen-Personen 'Kein Lehrer', Ionic 'Lehrer: <Name>'. Falsche Daten → hoch. Zusätzlich: Flutter prüft beim Anzeigen maintainTeachers nicht (Ionic showTeachers && maintainTeachers).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1573, lib/data/models/person/person.dart:141, lib/core/providers/realtime_providers.dart:46
- [ ] **hoch** `people/person/person.page` `field-8adac9da` [people/person/person.page.html:367](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L367) (2. Prüfung: bestätigt)
  Label „Spielt beim Lehrer“ und Bedingung gleich. Ionic: Ausschalten ändert nur hasTeacher, teacher bleibt gespeichert (Lehrer-Seiten zählen Schüler über p.teacher) / Flutter: Ausschalten setzt teacher auf null, und jedes Speichern schreibt teacher=null, solange hasTeacher aus ist → anderer DB-Wert, Person fällt aus der Schülerliste des Lehrers.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:415, lib/features/people/presentation/pages/person_detail_page.dart:636
- [ ] **hoch** `people/person/person.page` `field-7b7c2d2d` [people/person/person.page.html:444](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L444) (2. Prüfung: bestätigt)
  Ionic: nur sichtbar, wenn Schichtpläne existieren; Leer-Option „Keine Schicht zugewiesen“; Wechsel setzt shift_name auf die erste Schicht bzw. shift_start auf jetzt / Flutter: Zeile „Schichtplan“ immer sichtbar (auch ohne Schichtpläne), Leer-Option „Kein Schichtplan“, Wechsel setzt shift_name und shift_start auf null → ohne weitere Auswahl anderer DB-Wert (Schicht/Startdatum leer).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:475, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:513
- [ ] **hoch** `people/person/person.page` `field-247f92a0-2` [people/person/person.page.html:588](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L588) (2. Prüfung: bestätigt)
  Ionic: ion-input type=number (Dezimalzahlen möglich, leer → kein Wert; Paketquelle @ionic/angular nicht im Container) / Flutter: Editor-Sheet, int.tryParse → Dezimalzahlen („1.5“, „1,5“) und leere Eingabe werden als 0 gespeichert (falscher Wert).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:779, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:787
- [ ] **hoch** `people/person/person.page` `field-0a2daf88` [people/person/person.page.html:1124](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1124) (2. Prüfung: bestätigt)
  Ionic: Ziel-Instanzen = Instanzen der Organisation außer der aktuellen (getTenantsFromOrganisation, unabhängig von der eigenen Mitgliedschaft), erste vorausgewählt / Flutter: alle Instanzen, in denen der Nutzer Mitglied ist (userTenantsProvider), außer der aktuellen – auch außerhalb der Organisation; Organisations-Instanzen ohne eigene Mitgliedschaft fehlen.
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:85, lib/features/people/presentation/widgets/handover_sheet.dart:130, lib/features/people/presentation/widgets/handover_sheet.dart:465
- [ ] **hoch** `people/person/person.page` `x-51a2c3a242` **Veraltete Anzeige nach Aktionen auf der Seite** [src/app/people/person/person.page.ts:1117](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1117) (2. Prüfung: bestätigt)
  Bestätigt: _PersonDetailContent hat kein didUpdateWidget, _draft wird nur in initState gesetzt; nach ref.invalidate bleibt der State erhalten (Riverpod 2.6 when: skipLoadingOnRefresh) → Bild, rote Leiste, Problemfall, Account (Verknüpft/Rolle, E-Mail) und Geburtstags-Markierung bleiben veraltet. Zusätzlich: ein späteres Speichern schreibt 'email': _draft.email → nach „In anderer Instanz suchen“, „Meinen Benutzer zuweisen“ oder „Verknüpfung aufheben“ wird die alte E-Mail zurückgeschrieben.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:294, lib/features/people/presentation/pages/person_detail_page.dart:357, lib/features/people/presentation/pages/person_detail_page.dart:650, lib/features/people/presentation/pages/person_detail_page.dart:1690, lib/features/people/presentation/widgets/person_detail/person_header.dart:91
- [ ] **hoch** `people/person/person.page` `x-c4faf6c06b` **Notiz-Historie bei jedem Speichern ohne Notiz** [src/app/people/person/person.page.ts:661](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L661) (2. Prüfung: bestätigt)
  Bestätigt: _draft.notes ist bei Person ohne Notiz null, Vergleich null != '' → jedes Speichern hängt einen Eintrag „Keine Notiz“ (Typ Notiz geändert) an. Verstärkt, weil Flutter leere Notizen selbst als null speichert (Zeile 625).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:603, lib/features/people/presentation/pages/person_detail_page.dart:625
- [ ] **hoch** `people/person/person.page` `x-70a0612c36` **Zusatzfelder: keine Standardwerte bei bestehenden Personen** [src/app/people/person/person.page.ts:171](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L171) (2. Prüfung: bestätigt)
  Bestätigt (Ionic person.page.ts:169-175 mit Utils.getFieldTypeDefaultValue): Ionic zeigt fehlende Zusatzfelder vorbelegt (Ja/Nein an, Auswahl erste Option, Datum heute …) und schreibt sie beim nächsten Speichern / Flutter zeigt „Nicht angegeben“ bzw. Schalter aus und schreibt nichts.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:366, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:752
- [ ] **hoch** `people/person/person.page` `x-9a5e7d5318` **Neu-Seite: Zusatzfeld-Standardwerte** [src/app/people/person/person.page.ts:216](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L216) (2. Prüfung: bestätigt)
  Bestätigt: Ionic 9f9b82af übergibt field.defaultValue und Gemeinden (person.page.ts:223, Utils.ts:1446) / Flutter ignoriert defaultValue (z. B. Ja/Nein mit Standard „Nein“ wird true), Gemeinde '' („Nicht gelistet“) statt erste Gemeinde, Datum YYYY-MM-DD statt ISO-Zeitstempel.
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:238, lib/features/people/presentation/pages/person_create_page.dart:291
- [ ] **hoch** `teachers/teachers.page` `action-5b603f4a` [teachers/teachers.page.html:18](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/teachers/teachers.page.html#L18) (2. Prüfung: bestätigt)
  Name, Instrumentnamen, Badge „{n} Spieler“ (rot bei 0), Sortierung nach Name, Tipp öffnet Bearbeiten nur für Admin/Verantwortliche wie Ionic. Ionic: n = aktive Personen (db.getPlayers: left = null, pending = false) / Flutter: getStudentCounts zählt alle Personen mit diesem Lehrer inkl. ausgetretener und ausstehender – zu hohe Zahlen, Badge nicht rot.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:195, lib/data/repositories/teacher_repository.dart:115
- [ ] **mittel** `duty/duty-distribute-modal/duty-distribute-modal.component` `alert-500b3722` [duty/duty-distribute-modal/duty-distribute-modal.component.ts:205](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L205) (2. Prüfung: bestätigt)
  Titel „{Vorname} tauschen“ / „Person wählen“, Untertitel „{Titel} · {Datum}“, „Niemand (Platz offen lassen)“ nur beim Tauschen, Einträge „Name (Anzahl)“ nach Anzahl sortiert, Toast „Niemand sonst …“ bei leerer Auswahl ohne current wie Ionic. Ionic: ion-alert mit Radio-Liste und „Abbrechen“/„Übernehmen“, Auswahl gilt erst mit „Übernehmen“ / Flutter: SimpleDialog (iOS-Look: Karte mit Zeilen) ohne Radios und ohne Buttons, Tipp übernimmt sofort, Abbrechen nur durch Tippen daneben. Nebenbei: Datum im Untertitel ohne führende Null („Mo, 3.2.“ statt „Mo, 03.02.“, siehe text-e73248fa).
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:236
- [ ] **mittel** `instruments/instrument-list/instrument-list.page` `toast-4c623e8a` [instruments/instrument-list/instrument-list.page.ts:211](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L211) (2. Prüfung: bestätigt)
  Ionic: leerer Name → roter Toast „Bitte gib einem Namen an“, Alert bleibt offen (return false) / Flutter: „Hinzufügen“ bei leerem (getrimmtem) Namen tut nichts, Dialog bleibt offen, kein Hinweis.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:281
- [ ] **mittel** `instruments/instrument-list/instrument-list.page` `toast-30c6ec59` [instruments/instrument-list/instrument-list.page.ts:270](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L270) (2. Prüfung: bestätigt)
  Ionic: leerer Name → roter Toast „Bitte gib einem Namen an“, Alert bleibt offen / Flutter: „Speichern“ bei leerem Namen tut nichts, Dialog bleibt offen, kein Hinweis.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:320
- [ ] **mittel** `instruments/instrument-list/instrument-list.page` `toast-e4f5c17f` [instruments/instrument-list/instrument-list.page.ts:410](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L410) (2. Prüfung: bestätigt)
  Ionic: grüner Toast „Reihenfolge gespeichert“ nach dem Speichern der Gruppen-Reihenfolge / Flutter: _toggleReorder zeigt nur bei Fehler einen Toast (das Kategorien-Sheet hat die Erfolgsmeldung, die Gruppenliste nicht).
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:57
- [ ] **mittel** `instruments/instrument/instrument.page` `toast-39c411aa` [instruments/instrument/instrument.page.ts:84](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument/instrument.page.ts#L84) (2. Prüfung: bestätigt)
  Gleicher Text. Ionic: Prüfung sofort beim Tippen auf „Entfernen“ (getPlayers(true): inkl. ausgetretene, ohne ausstehende), Toast ohne Bestätigungsdialog, Seite bleibt offen / Flutter: erst Dialog „Gruppe wirklich löschen?“, nach „Ja“ schließt die Seite, dann Prüfung in der Liste (playerCounts, danach deleteGroup mit Archivierten) und Toast; zählt auch ausstehende Registrierungen und zeigt den Text bei jedem Löschfehler.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:458, lib/data/repositories/group_repository.dart:244
- [ ] **mittel** `instruments/instrument/instrument.page` `x-70eb019a5f` **Seite schließt vor dem Speichern** [src/app/instruments/instrument/instrument.page.ts:64](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument/instrument.page.ts#L64) (2. Prüfung: bestätigt)
  Bestätigt. Ionic update() (instrument.page.ts:58) speichert zuerst; bei Fehler Service-Toast „Fehler beim updaten des Instruments“ bzw. „Es kann nur eine Hauptgruppe existieren“, Modal bleibt mit den Eingaben offen / Flutter: _save schließt sofort, gespeichert wird danach in der Liste; bei Fehler „Fehler beim Speichern“, Eingaben verloren.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:730, lib/features/instruments/presentation/pages/instruments_list_page.dart:750, lib/features/instruments/presentation/pages/instruments_list_page.dart:471, lib/features/instruments/presentation/pages/instruments_list_page.dart:477
- [ ] **mittel** `people/bulk-edit/bulk-edit.page` `field-523de84f-2` [people/bulk-edit/bulk-edit.page.html:63](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L63) (2. Prüfung: bestätigt)
  Zahlenfeld mit Platzhalter = Feldname gleich. Startwert: Ionic 0 (Feld-Standardwert ignoriert) / Flutter Feld-Standardwert, sonst leer (null) → 'Für alle setzen' ohne Eingabe schreibt null statt 0.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:531, lib/features/people/presentation/pages/bulk_edit_page.dart:115
- [ ] **mittel** `people/bulk-edit/bulk-edit.page` `field-817de781` [people/bulk-edit/bulk-edit.page.html:65](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L65) (2. Prüfung: bestätigt)
  Ionic: ion-toggle mit Beschriftung = Feldname, Startwert true / Flutter: Schalter ohne Beschriftung, Startwert Feld-Standardwert, sonst false → 'Für alle setzen' ohne Änderung schreibt false statt true.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:537, lib/features/people/presentation/pages/bulk_edit_page.dart:115
- [ ] **mittel** `people/bulk-edit/bulk-edit.page` `field-fc367be8-2` [people/bulk-edit/bulk-edit.page.html:75](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L75) (2. Prüfung: bestätigt)
  Gemeinde-Auswahl gleich. Startwert: Ionic erste Gemeinde (churches[0].id) / Flutter Feld-Standardwert, sonst '' → Auswahl leer, 'Für alle setzen' schreibt ''.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:546, lib/features/people/presentation/pages/bulk_edit_page.dart:115
- [ ] **mittel** `people/bulk-edit/bulk-edit.page` `x-b434dfaf0e` **Startwert 'Für alle setzen' bei Zusatzfeldern** [src/app/people/bulk-edit/bulk-edit.page.ts:106-126](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.ts#L106-L126) (2. Prüfung: bestätigt)
  Real: Ionic getDefaultBulkValue ruft Utils.getFieldTypeDefaultValue(type, undefined, options, churches) → Feld-Standardwert ignoriert: Boolean true, Zahl 0, Auswahl erste Option, Gemeinde erste Gemeinde (falls geladen), Datum new Date().toISOString() (im type=date-Feld nicht sichtbar, wird aber geschrieben), Text ''. Flutter: Feld-Standardwert, sonst false / null / erste Option / ''. 'Für alle setzen' ohne Anpassung schreibt andere Werte. Deckt sich mit den Feld-Items (field-817de781, field-523de84f-2, field-fc367be8-2 …), als logic-Befund berechtigt; mittel passt (Startwert ist sichtbar außer beim Datum).
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:115-134
- [ ] **mittel** `people/bulk-edit/bulk-edit.page` `x-994adc4d18` **Personenwerte der Zusatzfelder ohne aufgefüllte Defaults** [src/app/people/list/list.page.ts:1040](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L1040) (2. Prüfung: bestätigt)
  Real: Ionic getModifiedPlayersForList füllt player.additional_fields in place mit Defaults (Utils.ts:121-126; defaultValue, sonst Boolean true, Auswahl erste Option, Gemeinde erste Gemeinde …), openBulkEditModal übergibt diese Objekte (list.page.ts:1035-1041). Flutter _openBulkEdit übergibt nur mergeSharedPersonFieldValues ohne Defaults → bei Personen ohne gespeicherten Wert Schalter aus bzw. Auswahl leer, andere Änderungszahl; Ionic schreibt beim Speichern das aufgefüllte Objekt (auch Defaults anderer Felder), Flutter nur Rohwerte + bearbeitetes Feld.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1280-1294, lib/features/people/presentation/pages/bulk_edit_page.dart:102-112, lib/features/people/presentation/pages/bulk_edit_page.dart:161-206
- [ ] **mittel** `people/import/import.page` `effect-31a0aedd` [people/import/import.page.ts:275](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.ts#L275)
  Datei 'Personen_Import_Vorlage.xlsx', Blatt 'Import', Kopf- und Beispielzeile wie Ionic (Org-Zusatzfelder fehlen: eigener Befund). Ionic saveWorkbook: nativ Datei in Cache + Systemviewer, mobiler Browser Web-Share-Sheet, Desktop Download / Flutter: nativ Teilen-Dialog (share_plus) mit Begleittext 'Song-Dateien', im Web immer Anker-Download (Blob-Typ application/zip); bei Fehler Toast 'Fehler: …' nur in Flutter.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:119, lib/features/people/presentation/pages/person_import_page.dart:137, lib/core/utils/import_file_io.dart:25, lib/core/services/zip_service_io.dart:9, lib/core/services/zip_service_web.dart:7
- [ ] **mittel** `people/import/import.page` `action-2d35c2c8` [people/import/import.page.html:27](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.html#L27) (2. Prüfung: bestätigt)
  Datei 'Personen_Import_Vorlage.xlsx', Blatt 'Import', Beispielzeile gleich. Ionic: Spalten inkl. Org-Zusatzfelder; nativ Datei öffnen (FileViewer), mobiles Web Share-Sheet / Flutter: nur Tenant-Zusatzfelder; nativ Share-Sheet mit Text 'Song-Dateien', Web immer Download.
  Flutter: lib/features/people/presentation/widgets/import_widgets.dart:42, lib/features/people/presentation/pages/person_import_page.dart:108, lib/core/services/zip_service_io.dart:9
- [ ] **mittel** `people/import/import.page` `x-1a63f4f2ee` **Vorlage herunterladen: Ausgabe** [src/app/utilities/Utils.ts:1220-1237](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/utilities/Utils.ts#L1220-L1237) (2. Prüfung: bestätigt)
  Real: Ionic Utils.saveWorkbook → nativ Datei im Cache + FileViewer-Vorschau, mobiles Web Web-Share-Sheet, Desktop writeFile-Download, Fehler ohne Hinweis. Flutter nutzt den ZIP-Export-Code: nativ Share-Sheet mit Begleittext 'Song-Dateien' (falscher Text), Web immer Anker-Download (Blob-Typ application/zip), bei Fehler Toast 'Fehler: …'.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:104-129, lib/core/utils/import_file_io.dart:25-27, lib/core/services/zip_service_io.dart:9-18, lib/core/services/zip_service_web.dart:7-28
- [ ] **mittel** `people/list/list.page` `modal-38ba21ec` [people/list/list.page.ts:233](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L233) (2. Prüfung: bestätigt)
  Ionic: PersonPage als Modal (iOS Karten-Modal mit presentingElement, backdropDismiss false), readOnly = nicht Admin/Verantwortlicher / Flutter: context.push('/people/<id>') bzw. '/people/new' als normale Seite im Shell. Leserecht für Betrachter in der Detailseite gleich.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:604, lib/features/people/presentation/pages/people_list_page.dart:563, lib/features/people/presentation/pages/people_list_page.dart:664, lib/core/router/app_router.dart:799, lib/core/router/app_router.dart:804, lib/features/people/presentation/pages/person_detail_page.dart:1702
- [ ] **mittel** `people/list/list.page` `db-a9ead6a0` [people/list/list.page.ts:383](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L383) (2. Prüfung: korrigiert)
  Ionic: update player.sort_order nur für Personen mit sort_order != null (verschobene Gruppe + schon gesetzte Werte), Filter nur id / Flutter: schreibt sort_order 1..n für alle angezeigten Personen aller Gruppen, mit id + tenantId. Folge: auch nie sortierte Gruppen werden dauerhaft eingefroren; später angelegte oder umbenannte Personen stehen dort am Gruppenende statt alphabetisch. Erstprüfung: niedrig – dauerhaft andere Reihenfolge ist mittel.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1163, lib/features/people/presentation/pages/people_list_page.dart:1171, lib/data/repositories/player_repository.dart:1844
- [ ] **mittel** `people/list/list.page` `alert-76ef2f5f` [people/list/list.page.ts:589](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L589) (2. Prüfung: bestätigt)
  Ionic: Alert mit Radio-Liste (Optionen bzw. Gemeindenamen, gespeicherte bzw. erste Option vorausgewählt) und 'Abbrechen' (→ Alle) / 'Filtern' / Flutter: Auswahl-Dialog ohne Buttons und Vorauswahl, Tipp filtert sofort (Wegtippen → Alle). Ionic trifft Personen ohne Wert über den aufgefüllten Default, Flutter nicht (extra 'Zusatzfeld-Defaults'). Flutter wertet auch Org-Felder aus (Ionic nur tenant.additional_fields).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:993, lib/features/people/presentation/pages/people_list_page.dart:1044, lib/features/people/presentation/pages/people_list_page.dart:296
- [ ] **mittel** `people/list/list.page` `modal-99a2d84a` [people/list/list.page.ts:1062](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L1062) (2. Prüfung: bestätigt)
  Trigger, Sheet (Start 0.5) und Untertitel 'Personen' gleich. Daten: Ionic zählt Personen ohne Gemeinde-Wert über den aufgefüllten Default (defaultValue bzw. erste Gemeinde) / Flutter als 'ohne Gemeinde' (churchIdOf → null).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1128, lib/features/people/presentation/pages/people_list_page.dart:1139, lib/shared/widgets/sheets/church_overview_sheet.dart:61, lib/shared/widgets/sheets/church_overview_sheet.dart:70
- [ ] **mittel** `people/list/list.page` `action-4792cae3` [people/list/list.page.html:461](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L461) (2. Prüfung: bestätigt)
  Ionic: Button für alle Rollen der Liste, öffnet PersonPage mit readOnly = nicht Admin (Betrachter sieht gesperrtes Formular) / Flutter: push '/people/new' ohne Rollenprüfung (Route nur canSeePeopleTab, PersonCreatePage prüft keine Rolle) → Betrachter erhält bei leerer Instanz das editierbare Anlageformular; Speichern scheitert laut RLS (admins_manage_player nur Rolle 1/5).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:563, lib/core/router/app_router.dart:187, lib/core/router/app_router.dart:799
- [ ] **mittel** `people/list/list.page` `modal-11a551b4` [people/list/list.page.html:499](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L499) (2. Prüfung: bestätigt)
  Ionic: eigenes Vollbild-Modal (Titel + X, Datumsfeld, Notiz, FAB unten rechts, backdropDismiss false) / Flutter: AlertDialog (nicht wegtippbar) mit Datum-Zeile, Notizfeld und 'Abbrechen'/'Archivieren'. Geschriebene Daten (left, Historie, Zugang entziehen) gleich.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1385, lib/features/people/presentation/pages/people_list_page.dart:1392
- [ ] **mittel** `people/list/list.page` `x-122934c2b4` **Zusatzfeld-Defaults nicht angewendet** [src/app/utilities/Utils.ts:121](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/utilities/Utils.ts#L121) (2. Prüfung: bestätigt)
  Echt. Beide Apps füllen beim Speichern der Zusatzfelder fehlende Werte auf (Flutter extra_fields_page.dart:186), daher v. a.: Zahlenfelder (mit 0 aufgefüllt) zeigen in Flutter Badge/Zeile '<Feld> 0' bei allen, Ionic blendet 0 aus; Personen ohne gespeicherten Wert (z. B. Org-Felder) bekommen in Ionic Defaults für Badge/Filter/Gemeinde-Übersicht, in Flutter nicht.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:296, lib/features/people/presentation/pages/people_list_page.dart:1530, lib/features/people/presentation/pages/people_list_page.dart:1589, lib/features/people/presentation/pages/people_list_page.dart:1620, lib/shared/widgets/sheets/church_overview_sheet.dart:61
- [ ] **mittel** `people/list/list.page` `x-efc684b2eb` **Umlaute in Gruppen-Sortierung** [src/app/utilities/Utils.ts:100](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/utilities/Utils.ts#L100) (2. Prüfung: bestätigt)
  Echt: sortPeopleByGroup nutzt toLowerCase().compareTo (ü=U+00FC nach z) → z. B. 'Mustermann' vor 'Müller', 'Schmidt' vor 'Schäfer'; Ionic localeCompare. Sichtbare Reihenfolge in der Standard-Sortierung 'Gruppe'.
  Flutter: lib/features/people/people_list_utils.dart:75, lib/features/people/people_list_utils.dart:85
- [ ] **mittel** `people/members/members.page` `field-f9de5b80` [people/members/members.page.html:30](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/members/members.page.html#L30) (2. Prüfung: bestätigt)
  Segment (md, scrollbar) mit 'Alle' + Optionen ohne '-' gleich. Filterwirkung: Ionic vergleicht mit dem durch getModifiedPlayersForList aufgefüllten Default (defaultValue bzw. erste Option) → Personen ohne Wert erscheinen unter der Default-Option / Flutter: nur Personen mit gespeichertem Wert.
  Flutter: lib/features/members/presentation/pages/members_page.dart:72, lib/features/members/data/providers/members_providers.dart:116
- [ ] **mittel** `people/members/members.page` `x-e7ca7e309b` **Einteilungs-Filter ohne Default** [src/app/people/members/members.page.ts:101](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/members/members.page.ts#L101) (2. Prüfung: bestätigt)
  Echt: Ionic füllt fehlende 'einteilung' mit defaultValue bzw. erster Option (Mitgliederseite ohne Org-Werte-Hydrierung, ein Org-Feld 'einteilung' landet damit immer beim Default) / Flutter vergleicht nur den gespeicherten Wert. Betrifft Personen ohne gespeicherten Wert.
  Flutter: lib/features/members/data/providers/members_providers.dart:116
- [ ] **mittel** `people/members/members.page` `x-24bba1cc4b` **Umlaute in der Sortierung** [src/app/utilities/Utils.ts:109](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/utilities/Utils.ts#L109) (2. Prüfung: bestätigt)
  Echt: gleiche Ursache wie x-efc684b2eb (sortPeopleByGroup mit toLowerCase().compareTo), hier auf der Mitgliederseite; Ionic localeCompare.
  Flutter: lib/features/members/data/providers/members_providers.dart:28, lib/features/people/people_list_utils.dart:75, lib/features/people/people_list_utils.dart:85
- [ ] **mittel** `people/person/person.page` `alert-f1974eb4` [people/person/person.page.ts:556](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L556) (2. Prüfung: bestätigt)
  Titel/Text gleich („E-Mail Adresse hinzugefügt“ / „Möchtest du gleich ein Konto für die Person anlegen?“). Ionic: Abbrechen (speichert nichts) / Ja (Account wird in updatePlayer vor dem Speichern registriert, danach schließt die Seite) / Flutter: zusätzlicher Button „Nur speichern“, bei „Ja“ erst speichern, dann Account anlegen (Toast „Account erstellt…“ + „…aktualisiert“), Seite bleibt offen. Bedingung appId==null entspricht Ionic (E-Mail-Feld bei appId gesperrt).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:547, lib/features/people/presentation/pages/person_detail_page.dart:559, lib/features/people/presentation/pages/person_detail_page.dart:712
- [ ] **mittel** `people/person/person.page` `alert-75bf15c2` [people/person/person.page.ts:719](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L719) (2. Prüfung: bestätigt)
  Ionic: „Account entfernen“ / „Möchtest du den Account wirklich aus der Instanz entfernen? Die Personendaten bleiben erhalten.“ Abbrechen/Ja, danach schließt die Seite, Toast „Der Benutzer wurde erfolgreich entfernt“ / Flutter: „Account-Verknüpfung aufheben?“ / „Die Account-Verknüpfung für {name} wird aufgehoben. Die Person kann sich dann nicht mehr in der App anmelden.“ Abbrechen/„Verknüpfung aufheben“ (rot), Seite bleibt offen (zeigt weiter „Verknüpft“, veralteter _draft), Toast „Account-Verknüpfung aufgehoben“. DB-Wirkung gleich (removeUserFromTenant, appId/email = null).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1532, lib/features/people/presentation/pages/person_detail_page.dart:1536, lib/features/people/presentation/pages/person_detail_page.dart:1575
- [ ] **mittel** `people/person/person.page` `toast-9e8a666e` [people/person/person.page.ts:1211](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1211) (2. Prüfung: korrigiert)
  Menüpunkt gleich (kein appId, Admin/Verantwortlicher). Erstprüfer übersah die Rollenlogik in db.createAccount → registerUser/getAppIdByEmail: Ionic Admin → nur player.appId gesetzt (E-Mail nur lokal angezeigt), Toast. Ionic Verantwortlicher → ist sein Account schon mit einer Person der Instanz verknüpft: Fehler 'Der Benutzer ist bereits in diesem Mandanten: …', keine Zuweisung; sonst wird sein tenantUsers-Eintrag gelöscht und mit Rolle Spieler (Hauptgruppe: Verantwortlich) neu angelegt + Info-Mail / Flutter: schreibt für beide Rollen direkt appId + E-Mail, immer Erfolgs-Toast, Rolle unverändert. Verantwortliche können so ihren Account an eine zweite Person hängen, was Ionic verweigert (die Ionic-Selbstherabstufung entfällt).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:962, lib/features/people/presentation/pages/person_detail_page.dart:1384
- [ ] **mittel** `people/person/person.page` `actionsheet-fba9657b` [people/person/person.page.ts:1329](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1329) (2. Prüfung: bestätigt)
  Header „Aktionen“, Einträge, Reihenfolge, Bedingungen (appId/isAdmin, paused, Organisation, nicht man selbst) und „Abbrechen“ gleich. Wirkung abweichend: „Wieder aktivieren“ – Ionic schließt die Seite ohne Toast / Flutter bleibt offen mit Toast „Die Person wurde erfolgreich wieder aktiviert“; „In andere Instanz übertragen/kopieren“ öffnet das Massen-Übergabe-Sheet statt des Ionic-Sheets; „Archivieren“ öffnet einen Dialog statt Vollbild-Modal.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1354, lib/features/people/presentation/pages/person_detail_page.dart:1378, lib/features/people/presentation/pages/person_detail_page.dart:1013, lib/features/people/presentation/pages/person_detail_page.dart:1403, lib/features/people/presentation/pages/person_detail_page.dart:1050
- [ ] **mittel** `people/person/person.page` `alert-97cf5262` [people/person/person.page.ts:1354](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1354) (2. Prüfung: bestätigt)
  Ionic: „Person kopieren“/„Person übertragen“, „Möchtest du die Person wirklich in die andere Instanz kopieren?“ bzw. „…übertragen? Alle zugehörigen Daten (Abwesenheiten, Notizen, etc.) gehen dabei verloren!“, Abbrechen/Ja / Flutter: „Spieler kopieren?“/„Spieler übertragen?“, „1 Spieler nach "{Instanz}" kopieren?“ bzw. „1 Spieler an "{Instanz}" übertragen? Die Spieler werden in dieser Instanz archiviert. Dieser Vorgang kann nicht rückgängig gemacht werden.“, Abbrechen/„Kopieren“/„Übertragen“.
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:772
- [ ] **mittel** `people/person/person.page` `alert-692c7626` [people/person/person.page.ts:1663](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1663) (2. Prüfung: bestätigt)
  Ionic: Header „Person ablehnen“, subHeader „Gib einen Grund an.“, Textarea ohne Label; leerer Grund → Meldung „Bitte gib einen Grund an!“ im Alert; Buttons Abbrechen/„Ablehnen“ / Flutter: ohne subHeader, zusätzlicher Text „{Name} wird abgelehnt und archiviert.“, Feld „Grund *“ mit Hinweis „Warum wird die Person abgelehnt?“, leerer Grund → SnackBar; „Ablehnen“ rot; danach Toast „Person wurde abgelehnt“ statt „Die Spielerdaten wurden erfolgreich aktualisiert.“ DB-Wirkung gleich.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1256, lib/features/people/presentation/pages/person_detail_page.dart:1262, lib/features/people/presentation/pages/person_detail_page.dart:1288
- [ ] **mittel** `people/person/person.page` `field-a9ab8c88` [people/person/person.page.html:23](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L23) (2. Prüfung: bestätigt)
  Ionic: <input type=file accept=image/*> (auf iOS/Android auch Kamera/Datei wählbar), Original hochgeladen, >2 MB abgelehnt / Flutter: ImagePicker nur Galerie (keine Kamera), verkleinert auf 800 px / 80 % Qualität vor dem Upload.
  Flutter: lib/features/people/presentation/widgets/person_image_picker.dart:14, lib/features/people/presentation/widgets/person_detail/person_header.dart:220
- [ ] **mittel** `people/person/person.page` `action-40313396` [people/person/person.page.html:25](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L25) (2. Prüfung: bestätigt)
  Ionic: Tipp auf Avatar öffnet bei vorhandenem Bild den Bildbetrachter (darin Ersetzen/Entfernen), ohne Bild (bearbeitbar) direkt die Dateiauswahl / Flutter (bearbeitbar): Aktionsblatt „Passbild ersetzen“/„Passbild entfernen“/„Passbild ansehen“, auch ohne Bild (dann nur „ersetzen“); nur Leser: Betrachter wie Ionic. Kamera-Badge gleich.
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:65, lib/features/people/presentation/widgets/person_detail/person_header.dart:159
- [ ] **mittel** `people/person/person.page` `modal-ecac8535` [people/person/person.page.html:47](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L47) (2. Prüfung: bestätigt)
  Ionic: Bildbetrachter-Modal öffnet direkt beim Tipp auf den Avatar / Flutter: für Bearbeiter nur über Aktionsblatt „Passbild ansehen“ (Vollbild-Viewer), für Leser direkt.
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:163, lib/features/people/presentation/widgets/person_detail/person_header.dart:205
- [ ] **mittel** `people/person/person.page` `action-ea218e71` [people/person/person.page.html:53](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L53) (2. Prüfung: bestätigt)
  Ionic: Button „Ersetzen“ im Bildbetrachter (wenn !readOnly) / Flutter: „Passbild ersetzen“ nur im Avatar-Aktionsblatt, Viewer ohne Aktionen.
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:182
- [ ] **mittel** `people/person/person.page` `action-0a1221be` [people/person/person.page.html:57](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L57) (2. Prüfung: bestätigt)
  Ionic: Button „Entfernen“ im Bildbetrachter (wenn !readOnly) / Flutter: „Passbild entfernen“ nur im Avatar-Aktionsblatt; Rückfrage und Toast gleich, danach zeigt die Seite bis zum Neuöffnen weiter das alte Bild (veralteter _draft).
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:188, lib/features/people/presentation/widgets/person_detail/person_header.dart:279
- [ ] **mittel** `people/person/person.page` `action-caeb0a85` [people/person/person.page.html:137](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L137) (2. Prüfung: korrigiert)
  Für Admin/Verantwortliche gleich (Icon/Farbe nach Konto/E-Mail, Name, Gruppe · Instanz, Grund, Badge Konto/E-Mail, Prozent; Tipp übernimmt Daten, Toast „Die Daten wurden erfolgreich übernommen“). Erstprüfer übersah die Rolle Beobachter: bei leerer Personenliste zeigt die Liste „Person hinzufügen“ ohne Rollenprüfung (people_list_page:563, wie Ionic list.page.html:461), Ionic öffnet die Neu-Seite dann aber readOnly (list.page.ts:238: Felder gesperrt, onNameInput bricht ab → keine Vorschläge, Anlegen scheitert an leeren Namen) / Flutter-Neu-Seite hat keinen Rollen-Check → Beobachter sieht Vorschläge aus verknüpften Instanzen, kann übernehmen und Anlegen versuchen (Insert nur noch durch RLS blockiert, falls aktiv). Nebenbei Flutter besser: übernommenes Passbild wird beim Anlegen gespeichert (Ionic pickPersonFields ohne img → nur Vorschau).
  Flutter: lib/features/people/presentation/widgets/person_match_suggestions.dart:52, lib/features/people/presentation/pages/person_create_page.dart:397, lib/features/people/presentation/pages/person_create_page.dart:224, lib/features/people/presentation/pages/person_create_page.dart:1028, lib/features/people/presentation/pages/people_list_page.dart:563
- [ ] **mittel** `people/person/person.page` `text-b133c084` [people/person/person.page.html:163](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L163) (2. Prüfung: korrigiert)
  Ionic: „Notizen“ bei existingPlayer && isAdmin, bei Ausgetretenen (readOnly, Admin) deaktiviert sichtbar / Flutter: nur bei canEdit (isAdmin && !hasLeft) → Admins sehen die Notizen archivierter Personen nirgends; zusätzlich auf der Neu-Seite sichtbar (Ionic nicht). Erstprüfer „niedrig“: fehlender Inhalt in der Archiv-Ansicht ist mehr als kosmetisch.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1839, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:269
- [ ] **mittel** `people/person/person.page` `field-fe3a2971` [people/person/person.page.html:181](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L181) (2. Prüfung: bestätigt)
  Ionic: Toggle „Mit Person gesprochen“ markiert Änderung; gelöst wird beim Speichern (FAB, Seite schließt; im Genehmigungsmodus beim Genehmigen) zusammen mit den übrigen Änderungen / Flutter: Toggle (Untertitel „Bestätigen, dass das Problem besprochen wurde“) markiert keine Änderung; Lösen nur über eigenen Button „Zurücksetzen (Gespräch geführt)“, sofort, Toast „Problemfall gelöst“; Speichern-FAB löst nicht. DB-Werte (isCritical, lastSolve, Historie Typ 3) gleich.
  Flutter: lib/features/people/presentation/widgets/person_detail/problemfall_accordion.dart:89, lib/features/people/presentation/pages/person_detail_page.dart:1178
- [ ] **mittel** `people/person/person.page` `field-3abdeaf8` [people/person/person.page.html:254](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L254) (2. Prüfung: bestätigt)
  Ionic: Texteingabe TT.MM.JJJJ (Platzhalter „TT.MM.JJJJ“, Übernahme bei Blur) plus Kalender-Button (Rad) / Flutter: Zeile nur antippbar → Datumsauswahl, keine direkte Texteingabe (iOS-Look nur Monatskalender; Material-Picker hat Eingabemodus). Warnfarbe (correctBirthday) bleibt in Flutter bis zum Neuöffnen, Ionic entfernt sie sofort.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:159, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:377
- [ ] **mittel** `people/person/person.page` `field-6c24372b` [people/person/person.page.html:286](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L286) (2. Prüfung: bestätigt)
  Ionic: Texteingabe TT.MM.JJJJ (Platzhalter „TT.MM.JJJJ“, Übernahme bei Blur) plus Kalender-Button / Flutter: Zeile nur antippbar → Datumsauswahl, keine direkte Texteingabe (iOS-Look nur Kalender; Material-Picker hat Eingabemodus).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:174, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:377
- [ ] **mittel** `people/person/person.page` `field-0755eef9` [people/person/person.page.html:318](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L318) (2. Prüfung: bestätigt)
  Ionic: Texteingabe TT.MM.JJJJ (Platzhalter „TT.MM.JJJJ“, Übernahme bei Blur) plus Kalender-Button / Flutter: Zeile nur antippbar → Datumsauswahl, keine direkte Texteingabe (iOS-Look nur Kalender; Material-Picker hat Eingabemodus).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:184, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:377
- [ ] **mittel** `people/person/person.page` `field-528d183b` [people/person/person.page.html:377](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L377) (2. Prüfung: bestätigt)
  Ionic: nur Lehrer, die das Instrument der gewählten Gruppe unterrichten; keine Leer-Option / Flutter (Detail): alle Lehrer der Instanz (teachersProvider ungefiltert), zusätzliche Option „Kein Lehrer“, Anzeige „Nicht ausgewählt“ (Neu-Seite filtert wie Ionic).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:428, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:458
- [ ] **mittel** `people/person/person.page` `modal-b80602d8` [people/person/person.page.html:548](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L548) (2. Prüfung: bestätigt)
  Inhalt gleich (accountHelp nur ohne appId, existingUserHint). Ionic: Sheet-Modal (Breakpoint 0.5) mit Toolbar „Hilfe“ und X / Flutter: AlertDialog „Hilfe“ mit „Schließen“.
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:278
- [ ] **mittel** `people/person/person.page` `field-b8f6d19b` [people/person/person.page.html:592](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L592) (2. Prüfung: bestätigt)
  Ionic: Toggle ohne gespeicherten Wert ist mit defaultValue bzw. true vorbelegt / Flutter: fehlender Wert wird als aus (false) angezeigt. Flutter besser: Toggle nur bei Bearbeitungsrecht änderbar (Ionic auch bei readOnly, ohne Speichermöglichkeit).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:745
- [ ] **mittel** `people/person/person.page` `field-8438f479` [people/person/person.page.html:596](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L596) (2. Prüfung: bestätigt)
  Ionic: Texteingabe TT.MM.JJJJ + Kalender-Button (max heute); fehlender Wert vorbelegt mit jetzt / Flutter: nur Datumsauswahl per Tipp (1900–2100), leer „Nicht angegeben“; speichert „YYYY-MM-DD“ statt ISO-Zeitstempel (UTC-Mitternacht).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:791, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:803
- [ ] **mittel** `people/person/person.page` `text-408e4921` [people/person/person.page.html:690](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L690) (2. Prüfung: korrigiert)
  Erstprüfer prüfte nur die Anzeige, nicht die Instanzliste. Ionic getTenantsFromUser: nur Instanzen, die über die Organisation mit der aktuellen verknüpft sind (getLinkedTenants), und nicht, wenn die Person dort Beobachter ist / Flutter: alle tenantUsers-Instanzen der Person außer der aktuellen, auch ohne Organisations-Verknüpfung und mit Rolle Beobachter → zusätzliche Zeilen (Instanzname, Rolle, Quote) für alle, die die Seite öffnen (Admin, Verantwortliche, Beobachter); bei aktiver RLS begrenzt auf Instanzen, die der Betrachter selbst verwaltet. Name longName (Fallback shortName) sonst gleich.
  Flutter: lib/features/people/presentation/widgets/person_detail/andere_instanzen_accordion.dart:24, lib/features/people/presentation/widgets/person_detail/andere_instanzen_accordion.dart:33, lib/features/people/presentation/widgets/person_detail/andere_instanzen_accordion.dart:222
- [ ] **mittel** `people/person/person.page` `text-a48aa58c` [people/person/person.page.html:691](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L691) (2. Prüfung: korrigiert)
  Ionic Utils.getRoleText: Elternteil, Stimmführer, Stimmführer & Helfer, unbekannte Rolle (z. B. Bewerber) „Unbekannt“ / Flutter: nur Rollen 1–5 übersetzt, Rollen 6–9 und alle anderen als „Mitglied“ → z. B. Stimmführer in der anderen Instanz erscheint als „Mitglied“.
  Flutter: lib/features/people/presentation/widgets/person_detail/andere_instanzen_accordion.dart:94, lib/features/people/presentation/widgets/person_detail/andere_instanzen_accordion.dart:110, lib/features/people/presentation/widgets/person_detail/andere_instanzen_accordion.dart:225
- [ ] **mittel** `people/person/person.page` `text-34177970` [people/person/person.page.html:693](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L693) (2. Prüfung: korrigiert)
  Ionic: Prozent über getPersonAttendances der Person in der anderen Instanz (nur ab Saisonstart der aktuellen Instanz, archivierte Termine für Nicht-Admins ausgeblendet, shift_excused_as_present) / Flutter: alle Termine bis heute ohne Saison-/Archiv-/Schicht-Filter → andere Prozentwerte. Ohne Wert zeigt Ionic „Nicht verfügbar“ in warning (person.page.ts:251-253), Flutter „n/a“ in grau.
  Flutter: lib/features/people/presentation/widgets/person_detail/andere_instanzen_accordion.dart:76, lib/features/people/presentation/widgets/person_detail/andere_instanzen_accordion.dart:211
- [ ] **mittel** `people/person/person.page` `action-53209882` [people/person/person.page.html:723](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L723) (2. Prüfung: bestätigt)
  Tipp auf Notiz-Eintrag (Alert „Notiz geändert“) und Löschen wie Ionic. Ionic: Zeiten der Historieneinträge („Mit Person gesprochen ({dd.MM.yyyy HH:mm})“ usw.) in Ortszeit; Termintitel leer bei hide_name; Typ 14/15 ohne Titelzeile / Flutter: Datum aus ISO-String mit Z bleibt UTC und wird so formatiert (Uhrzeit 1–2 h zu früh, Datum kippt kurz nach Mitternacht), Termintitel ignoriert hide_name (Typname), Typ 7/14/15 mit Datum als Titel.
  Flutter: lib/features/people/presentation/widgets/person_detail/historie_accordion.dart:181, lib/features/people/presentation/widgets/person_detail/historie_accordion.dart:374, lib/features/people/presentation/pages/person_detail_page.dart:131
- [ ] **mittel** `people/person/person.page` `action-bf4fde99` [people/person/person.page.html:877](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L877) (2. Prüfung: bestätigt)
  Ionic: im Genehmigungsmodus immer FAB „…“ → Aktionsblatt Genehmigen/Ablehnen/Abbrechen; onChange markiert dort nichts, Änderungen (inkl. Problemfall gelöst) werden beim Genehmigen mitgespeichert / Flutter: bei Änderungen erscheint stattdessen der Speichern-FAB; Genehmigen schreibt nur pending/Historie (ungespeicherte Änderungen gehen nicht mit), vorher zusätzliche Rückfrage.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1736, lib/features/people/presentation/pages/person_detail_page.dart:1330, lib/features/people/presentation/pages/person_detail_page.dart:1210
- [ ] **mittel** `people/person/person.page` `action-29de3e84` [people/person/person.page.html:886](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L886) (2. Prüfung: bestätigt)
  Ionic: nach erfolgreichem Speichern schließt die Seite (Toast „Die Spielerdaten wurden erfolgreich aktualisiert.“) / Flutter: Seite bleibt offen (nur Toast).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1733, lib/features/people/presentation/pages/person_detail_page.dart:722
- [ ] **mittel** `people/person/person.page` `action-77040b65` [people/person/person.page.html:896](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L896) (2. Prüfung: bestätigt)
  Bedingung gleich (!hasChanges, kein appId, E-Mail). Ionic: Schlüssel-FAB legt Account sofort an (ohne Rückfrage, Loading) und schließt die Seite / Flutter: zusätzlicher Bestätigungsdialog „Account erstellen?“, Seite bleibt offen; wegen veraltetem _draft bleibt der Schlüssel-FAB bis zum Neuöffnen sichtbar.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1738, lib/features/people/presentation/pages/person_detail_page.dart:1596
- [ ] **mittel** `people/person/person.page` `action-c704728e` [people/person/person.page.html:987](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L987) (2. Prüfung: bestätigt)
  Button „Pausieren“ gleich (deaktiviert ohne Grund). Ionic: nach dem Pausieren (und ggf. Abfrage andere Instanzen) schließt die Seite, kein Erfolgs-Toast / Flutter: Seite bleibt offen, zusätzlicher Toast „{Vorname} wurde pausiert“.
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:163, lib/features/people/presentation/pages/person_detail_page.dart:994
- [ ] **mittel** `people/person/person.page` `modal-75561fb4` [people/person/person.page.html:1077](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1077) (2. Prüfung: bestätigt)
  Ionic: Vollbild-Modal (nicht per Hintergrund schließbar) mit Toolbar „{Name} Archivieren“, X und Archiv-FAB / Flutter: AlertDialog mit gleichem Titel, Buttons Abbrechen/„Archivieren“; Notizfeld „Grund (optional)“ statt „Notiz“.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1050
- [ ] **mittel** `people/person/person.page` `modal-f11c7cfb` [people/person/person.page.html:1107](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1107) (2. Prüfung: bestätigt)
  Ionic: eigenes Sheet-Modal (0.5) „Kopieren von {name}“/„Übertragen von {name}“ mit Ziel-Instanz + Ziel-Gruppe / Flutter: Massen-Übergabe-Sheet (DraggableScrollableSheet) für 1 Person mit Titel „Spieler kopieren“/„Spieler übertragen“, Modus-Umschalter, Gruppen-Zuordnung, Hinweis-Karte.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1403, lib/features/people/presentation/widgets/handover_sheet.dart:102
- [ ] **mittel** `people/person/person.page` `field-272c2c28` [people/person/person.page.html:1132](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1132) (2. Prüfung: bestätigt)
  Ionic: eine Auswahl „Ziel-Gruppe“ (Pflicht, Button sonst deaktiviert) / Flutter: „Gruppen-Zuordnung“ je Quellgruppe mit Auto-Zuordnung nach Namen und Option „-- Nicht zuordnen --“.
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:514
- [ ] **mittel** `people/person/person.page` `x-ab8dec14f2` **Neu-Seite: Standarddaten Geburtsdatum/Spielt seit** [src/app/people/person/person.page.ts:35](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L35) (2. Prüfung: bestätigt)
  Bestätigt: Ionic newPlayer setzt Geburtstag und „Spielt seit“ auf heute (correctBirthday false, später gelb markiert) / Flutter leer (null), correctBirthday = birthday != null. Spalten sind nullable, Anlegen funktioniert.
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:60, lib/features/people/presentation/pages/person_create_page.dart:85, lib/features/people/presentation/pages/person_create_page.dart:1025, lib/features/people/presentation/pages/person_create_page.dart:1043
- [ ] **mittel** `people/person/person.page` `x-8ce7bfd4a3` **Neu-Seite: strengere E-Mail-Prüfung** [src/app/people/person/person.page.ts:525](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L525) (2. Prüfung: bestätigt)
  Bestätigt: Ionic addPerson prüft nur Vor-/Nachname / Flutter-Validator ^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$ blockiert „+“ und TLDs über 4 Zeichen (Detailseite erlaubt sie, Zeile 531).
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:471
- [ ] **mittel** `people/person/person.page` `x-c8b7613536` **Problemfall: Kasten „Grund“ zeigt Rohwert** [src/app/people/person/person.page.html:173](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L173) (2. Prüfung: bestätigt)
  Bestätigt: Kasten „Grund“ zeigt person.criticalReason roh (int-Spalte als Text, z. B. „2“); DashboardUtils.criticalReasonText wird hier nicht genutzt. Ionic zeigt im Problemfall-Bereich keinen Grund.
  Flutter: lib/features/people/presentation/widgets/person_detail/problemfall_accordion.dart:58, lib/features/people/presentation/widgets/person_detail/problemfall_accordion.dart:79
- [ ] **mittel** `teacher/teacher.page` `field-fc1d0925` [teacher/teacher.page.html:18](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/teacher/teacher.page.html#L18) (2. Prüfung: korrigiert)
  Label „Instrumente“, Mehrfachauswahl aus allen Gruppen (inkl. Hauptgruppe), Anzeige der gewählten Namen; Ionic ion-select interface=modal / Flutter Dialog mit Checkboxen „Abbrechen“/„OK“ (niedrig). Übersehen: _openTeacherPage übergibt ref.read(groupsProvider).valueOrNull ?? [] als feste Liste; groupsProvider wird weder von Lehrerliste (groupsMapProvider), Personenliste noch Einstellungen geladen. Nach App-Start ohne vorherigen Besuch einer Seite mit groupsProvider (z. B. Gruppen, Termin-Detail) zeigt das Feld beim ersten Öffnen keine Namen und der Auswahldialog ist leer; erst beim nächsten Öffnen gefüllt (read startet das Laden, keepAlive). Gespeicherte Instrumente bleiben beim Speichern erhalten. Ionic: db.groups() immer geladen.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:385, lib/features/teachers/presentation/pages/teachers_list_page.dart:296, lib/features/teachers/presentation/pages/teachers_list_page.dart:140
- [ ] **mittel** `teachers/teachers.page` `x-f65abbf51d` **„Lehrer hinzufügen“: Instrumentliste leer nach App-Start** [src/app/teachers/teachers.page.ts:34](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/teachers/teachers.page.ts#L34) (2. Prüfung: bestätigt)
  Bestätigt, Begründung präzisiert: _showAddSheet liest groupsProvider nur per ref.read als feste Liste; ist er noch nicht geladen, ist die Auswahl „Instrumente“ leer und „Hinzufügen“ endet mit „Bitte fülle alle Felder aus...“, erst beim nächsten Öffnen gefüllt. Anders als notiert lädt die Personenliste groupsProvider, wenn nach Gruppe sortiert (Standard). Die Lücke tritt also auf, wenn die Lehrerseite ohne vorheriges Laden erreicht wird (z. B. Neuladen/Direktlink /settings/teachers, Personenliste anders sortiert). Ionic: db.groups() immer geladen. Bearbeiten-Fall: teacher/teacher.page#field-fc1d0925.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:113, lib/core/providers/group_providers.dart:42, lib/features/people/presentation/pages/people_list_page.dart:396

## Flutter besser – Leon entscheidet: 28

- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `action-7bb1a2ef` [duty/duty-distribute-modal/duty-distribute-modal.component.html:69](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L69)
  Flutter besser: Ionic: Plus-Button bleibt bei 10 aktiv, Tippen wirkungslos (Math.min 10) / Flutter: Button bei 10 ausgegraut. Maximum 10 gleich.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:420
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-09922adb` [instruments/instrument-list/instrument-list.page.html:152](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.html#L152) (2. Prüfung: korrigiert)
  Flutter besser: Rolle gleich (nur Admin/Verantwortlicher); Insert name, maingroup false, tuning C, clefs [g], tenantId, category (nur wenn gesetzt) gleich; leerer Name → „Bitte gib einem Namen an“. Erstprüfer übersah: Ionic speichert den Namen ungetrimmt (nur Leerzeichen wird angelegt) und prüft den Insert-Fehler nicht (group.service.ts:34, Modal schließt still) / Flutter trimmt und zeigt bei Fehler „Fehler beim Hinzufügen“.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:427, lib/features/instruments/presentation/pages/instruments_list_page.dart:371, lib/features/instruments/presentation/pages/instruments_list_page.dart:347, lib/data/repositories/group_repository.dart:94
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `action-5c670508` [people/bulk-edit/bulk-edit.page.html:5](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L5)
  Flutter besser: Ionic: X schließt das Modal immer (auch während Speichern) / Flutter: X während _isSaving deaktiviert.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:268-271
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-3f70cbe7` [people/bulk-edit/bulk-edit.page.html:16](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L16)
  Flutter besser: Label 'Feld auswählen', Platzhalter 'Feld wählen...', 'Standard-Felder' (deaktiviert) + Gruppe/Stimmführer/Notizen/Telefon, 'Zusatzfelder' + Felder gleich. Ionic: Zusatzfeld-Block nur wenn db.tenant().additional_fields.length > 0 (Org-Felder fehlen also, wenn der Tenant keine eigenen Felder hat) / Flutter: sobald irgendein Zusatzfeld (Org oder Tenant) existiert (hasExtra).
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:282-322
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-4964deb8-2` [people/bulk-edit/bulk-edit.page.html:135](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L135)
  Flutter besser: Ionic: (ionChange) $event.detail.value liefert bei ion-input einen String → Zusatzfeld wird als "5" gespeichert (laut Ionic-Core; @ionic/angular nicht im Container) / Flutter: parst zu num (Komma erlaubt), leer → null. Ionic übernimmt erst bei Blur, Flutter bei jedem Tastendruck.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:398-406, lib/features/people/presentation/pages/bulk_edit_page.dart:531-536, lib/features/people/presentation/pages/bulk_edit_page.dart:475-479
- [ ] **niedrig** `people/list/list.page` `toast-9a849d38` [people/list/list.page.ts:390](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L390) (2. Prüfung: korrigiert)
  Flutter besser: Ionic prüft das {error} der Supabase-Updates nicht; postgrest-js wirft ohne throwOnError auch bei Netzfehlern nicht (geprüft an @supabase/postgrest-js 2.x im npx-Cache, Ionic-Version selbst nicht im Container) → der Catch mit 'Fehler beim Speichern der Reihenfolge' ist praktisch unerreichbar, Ionic meldet auch bei Fehlschlag 'Reihenfolge gespeichert'. Flutter zeigt den roten Fehler-Toast, wenn ein Update scheitert. Erstprüfung: ok.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1176
- [ ] **niedrig** `people/list/list.page` `alert-eeaa4fb8` [people/list/list.page.ts:489](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L489) (2. Prüfung: korrigiert)
  Flutter besser: Für Zahlenfelder der Instanz gleich (Titel = Feldname, Zahlenfeld 'Wert eingeben', 'Abbrechen' → Alle, 'Filtern', leer → Alle; sichtbar für alle Rollen der Personenliste = Admin/Verantwortlicher/Beobachter, in beiden). Erstprüfer übersah den Mandanten-Fall Organisationsfelder: Ionic listet Org-Zahlenfelder im Filter (getPersonExtraFields), öffnet den Alert aber nur für tenant().additional_fields (list.page.ts:474) → kein Dialog, Filter wirkungslos (alle Personen, Icon trotzdem farbig) / Flutter: Dialog und Filter auch für Org-Zahlenfelder (personListExtraFieldsProvider). Vorbelegung: Ionic letzter gespeicherter Zusatzwert, Flutter nur bei gleichem aktivem Filter (kosmetisch). Treffer für Personen ohne Wert (Ionic-Default 0) siehe x-122934c2b4.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:986, lib/features/people/presentation/pages/people_list_page.dart:1002, lib/features/people/presentation/pages/people_list_page.dart:1013, lib/features/people/presentation/pages/people_list_page.dart:1016, lib/features/people/presentation/pages/people_list_page.dart:1019, lib/core/providers/profile_providers.dart:67
- [ ] **niedrig** `people/list/list.page` `alert-86b4fbec` [people/list/list.page.ts:909](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L909)
  Flutter besser: Titel, Text, Checkboxen (Instanzname), 'Überspringen'/'Pausieren' gleich; Ionic bietet aber alle verknüpften Instanzen an, in denen die Person (nicht als Betrachter) Mitglied ist, Flutter nur jene, in denen der angemeldete Nutzer Admin/Verantwortlicher ist (Ionic scheitert dort sonst mit 'Fehler bei …').
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:229, lib/features/people/presentation/widgets/pause_person_sheet.dart:236, lib/features/people/presentation/widgets/pause_person_sheet.dart:284
- [ ] **niedrig** `people/list/list.page` `field-27abe29e` [people/list/list.page.html:58](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L58)
  Flutter besser: Platzhalter 'Person suchen...' und Suchfelder (Vor-/Nachname, Gruppe, Text-/Zahl-Zusatzfelder) gleich; Ionic verwirft bei der Suche aber den aktiven Filter und die gewählte Sortierung (Ergebnis in Gruppenreihenfolge), Flutter kombiniert Suche, Filter und Sortierung.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:510, lib/features/people/presentation/pages/people_list_page.dart:514, lib/features/people/presentation/pages/people_list_page.dart:309, lib/features/people/people_list_utils.dart:8
- [ ] **niedrig** `people/list/list.page` `action-de48c2e0` [people/list/list.page.html:451](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L451)
  Flutter besser: Ionic clearFilters leert nur filterOptAdd und zeigt alle Personen, Filterauswahl (Icon bleibt farbig) und Suchtext bleiben stehen / Flutter setzt Filter auf 'Alle Anzeigen', leert die Suche und speichert das.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:582, lib/features/people/presentation/pages/people_list_page.dart:1243
- [ ] **niedrig** `people/person/person.page` `alert-40883a4d` [people/person/person.page.ts:503](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L503) (2. Prüfung: korrigiert)
  Flutter besser: Detailseite gleich ('Änderungen verwerfen?' / Text, 'Abbrechen' / 'Ja'; Änderungen nur für Admin/Verantwortliche möglich wie Ionic !readOnly). Erstprüfer übersah: Ionic onChange setzt hasChanges nur bei existingPlayer, das Neu-Modal schließt daher immer ohne Rückfrage / Flutter fragt auf der Neu-Seite bei jeder Eingabe (Name, E-Mail, Bild …) ebenfalls nach.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1742, lib/features/people/presentation/pages/person_create_page.dart:123
- [ ] **niedrig** `people/person/person.page` `alert-01934766` [people/person/person.page.ts:1343](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1343) (2. Prüfung: korrigiert)
  Flutter besser: Titel 'Kopieren/Übertragen nicht möglich', Text mit Instanz und E-Mail bzw. Name, 'OK' gleich. Ionic prüft keine Rechte in der Zielinstanz und zeigt den Hinweis für jede eigene Ziel-Rolle / Flutter prüft vorher canEdit in der Zielinstanz und zeigt sonst den roten Toast 'Keine Berechtigung in der Ziel-Instanz' statt des Hinweises (Ionic-Übertragung scheitert dann später). Andere Ziel-Instanzliste: field-0a2daf88.
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:723, lib/features/people/presentation/widgets/handover_sheet.dart:763
- [ ] **niedrig** `people/person/person.page` `field-9f6c9acb` [people/person/person.page.html:237](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L237)
  Flutter besser: Ionic-Input ohne ionChange (Änderung allein aktiviert Speichern nicht) / Flutter markiert Änderung. Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; leer + nicht bearbeitbar ausgeblendet
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:829
- [ ] **niedrig** `teachers/teachers.page` `field-8a21ddb5` [teachers/teachers.page.html:49](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/teachers/teachers.page.html#L49) (2. Prüfung: bestätigt)
  Flutter besser: Ionic: addTeacher bekommt private.value der ion-toggle (Formularwert, Standard „on“), pri === 'true' ist nie wahr → neue Lehrer immer private = false (Ionic-Paket nicht im Container, Standardwert laut Ionic-API) / Flutter: speichert den Schalterzustand.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:392, lib/data/repositories/teacher_repository.dart:57
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `x-a485e4b055` **Zusatzfelder-Abschnitt Sichtbarkeit** [src/app/people/bulk-edit/bulk-edit.page.html:24](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L24)
  Flutter besser: Ionic: Zusatzfelder (inkl. Org-Felder) nur im Auswahlfeld, wenn der Tenant selbst additional_fields hat / Flutter: immer, wenn Org- oder Tenant-Felder existieren.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:255, lib/features/people/presentation/pages/bulk_edit_page.dart:306-319
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `x-1aab272cf3` **Zahlen-Zusatzfeld pro Person als String** [src/app/people/bulk-edit/bulk-edit.page.html:135-138](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L135-L138)
  Flutter besser: Ionic: Einzelwert aus ionChange ist String ("5"), Sammelwert über NumericValueAccessor Zahl; changedCount vergleicht strikt / Flutter: immer num (oder null).
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:475-479
- [ ] **niedrig** `people/import/import.page` `x-281b9c9094` **Liste wird auch ohne Import neu geladen** [src/app/people/import/import.page.ts:236-238](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.ts#L236-L238)
  Flutter besser: Ionic: Personenliste nur neu geladen, wenn mindestens eine Person importiert wurde / Flutter: invalidiert playersProvider immer (auch teilweise gespeicherte, fehlgeschlagene Zeilen erscheinen).
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:207-210
- [ ] **niedrig** `people/list/list.page` `x-5d4cb428e1` **Flutter besser: Suche/Filter/Sortierung kombiniert** [src/app/people/list/list.page.ts:714](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L714)
  Ionic: search() setzt die Liste auf alle Personen zurück (aktiver Filter verloren) und sortiert nach Gruppe; onFilterChanged sortiert ebenfalls nach Gruppe trotz anderer Sortierung; ein gespeicherter Filter wird beim Laden nur bei Sortierung 'Gruppe' angewendet / Flutter: Filter, Suche und Sortierung werden immer zusammen angewendet.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:250, lib/features/people/presentation/pages/people_list_page.dart:316
- [ ] **niedrig** `people/list/list.page` `x-c1c5493cd5` **Flutter besser: schmalere Pausen-Schreibvorgänge** [src/app/services/db.service.ts:2219](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/db.service.ts#L2219)
  Ionic: Pausieren/Aktivieren über updatePlayer schreibt den ganzen Listen-Datensatz zurück (inkl. mit Defaults aufgefüllter additional_fields); Pausieren in anderen Instanzen überschreibt dort die Historie mit der Quell-Historie / Flutter: schreibt nur paused, paused_until, history (+ tenantId-Filter); in anderen Instanzen wird der Eintrag an deren Historie angehängt.
  Flutter: lib/data/repositories/player_repository.dart:816, lib/data/repositories/player_repository.dart:861, lib/data/repositories/cross_tenant_person_repository.dart:288
- [ ] **niedrig** `people/person/person.page` `x-5c4108ee61` **Pausieren in anderen Instanzen: Historie** [src/app/people/person/person.page.ts:1453](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1453)
  Flutter besser: Ionic überschreibt die Historie der Person in der anderen Instanz mit der kompletten Historie dieser Instanz (pausePlayerInOtherTenant(..., history)) / Flutter hängt nur einen Pausiert-Eintrag an
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:247
- [ ] **niedrig** `people/person/person.page` `x-e0dc1b2b62` **Verspätungszähler zurücksetzen schreibt nur lastSolve** [src/app/people/person/person.page.ts:396](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L396)
  Flutter besser: Ionic resetLateCount speichert den ganzen Spieler (db.updatePlayer(this.player)) inkl. noch ungespeicherter Änderungen / Flutter schreibt nur lastSolve
  Flutter: lib/data/repositories/player_repository.dart:1391
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-d3edffbcbe` **Gleicher-Tag-Sperre zählt mehr Termine** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:111](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L111)
  Flutter besser: Ionic: lädt nur die gewählten Termintypen und filtert voll besetzte Termine vor distributeDuties heraus, deren Eingeteilte blockieren den Tag daher nicht / Flutter: lädt alle Dienst-Typen und gibt voll besetzte und nicht gewählte Termine mit open 0 mit, deren Eingeteilte blockieren bei „Nicht zweimal am selben Tag“ den Tag. Der Vorschlag kann sich dadurch unterscheiden.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:123, lib/features/duty/presentation/pages/duty_distribute_page.dart:164
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-9bddce3977` **Ladefehler beim Berechnen** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:79](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L79)
  Flutter besser: Ionic: kein catch, getUpcomingDutyTermine verschluckt Fehler und liefert [], dann Vorschau „Im Zeitraum gibt es keine Termine mit Dienst-Modus.“ / Flutter: roter Toast „Fehler: …“, bleibt im Regeln-Schritt.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:145
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-a43d5a3f61` **Pull-to-Refresh nur in Flutter** [src/app/instruments/instrument-list/instrument-list.page.html:70](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.html#L70)
  Flutter besser: Ionic: kein ion-refresher auf der Gruppenliste / Flutter: Herunterziehen lädt Gruppen, Kategorien und Personenanzahlen neu.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:82
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-5824d283fc` **Fehler beim Hinzufügen einer Gruppe** [src/app/instruments/instrument-list/instrument-list.page.ts:178](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L178)
  Flutter besser: Ionic: groupSvc.addGroup prüft den Fehler nicht, Sheet schließt ohne Meldung / Flutter: Sheet schließt, roter Toast „Fehler beim Hinzufügen“.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:346
- [ ] **niedrig** `teachers/teachers.page` `x-42f2057e70` **Pull-to-Refresh nur in Flutter** [src/app/teachers/teachers.page.html:10](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/teachers/teachers.page.html#L10)
  Flutter besser: Ionic: kein ion-refresher / Flutter: Herunterziehen lädt Lehrer und Schüleranzahlen neu.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:49
- [ ] **niedrig** `teachers/teachers.page` `x-c00bd9fd3a` **Gelöschte Gruppe in Lehrer-Instrumenten** [src/app/teachers/teachers.page.ts:41](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/teachers/teachers.page.ts#L41)
  Flutter besser: Ionic: getTeachers liest .name einer nicht mehr existierenden Gruppe → TypeError, die Lehrerliste bleibt leer / Flutter: unbekannte Gruppen-IDs werden übersprungen.
  Flutter: lib/core/providers/teacher_providers.dart:75
- [ ] **niedrig** `people/person/person.page` `x-4b8b68cee9` **Neu-Seite: zusätzliche Duplikat-Rückfrage** [src/app/people/person/person.page.ts:525](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L525)
  Flutter besser: Ionic addPerson legt ohne Namensprüfung an / Flutter fragt bei gleichem Vor- und Nachnamen in der Instanz (auch archivierte/ausstehende) „Mögliches Duplikat“ – „Eine Person mit dem Namen "{name}" existiert bereits ({count}x). Trotzdem erstellen?“ mit Abbrechen/„Trotzdem erstellen“.
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:997, lib/features/people/presentation/pages/person_create_page.dart:999

## Kleinigkeiten (niedrig): 164

- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `loading-e612daf1` [duty/duty-distribute-modal/duty-distribute-modal.component.ts:77](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L77)
  Ionic: blockierendes Overlay „Verteile Dienste…“ / Flutter: Body durch Spinner mit gleichem Text ersetzt, das X in der AppBar bleibt bedienbar.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:326
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `loading-ef16b6da` [duty/duty-distribute-modal/duty-distribute-modal.component.ts:232](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L232)
  Ionic: blockierendes Overlay „Teile ein…“ / Flutter: Body durch Spinner mit gleichem Text ersetzt, Speichern-Button deaktiviert, aber „Zurück“ und „Neu verteilen“ in der AppBar bleiben während des Speicherns bedienbar.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:326, lib/features/duty/presentation/pages/duty_distribute_page.dart:347
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-b28d8f3e` [duty/duty-distribute-modal/duty-distribute-modal.component.html:29](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L29)
  Anzeigeformat: Ionic ion-datetime-button zeigt das Intl-Kurzformat (z. B. „1. Dez. 2026“, Ionic-Paket nicht im Container) / Flutter IonDatetimeChip „01.12.2026“ (dateFmt()).
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:375
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-71fefb63` [duty/duty-distribute-modal/duty-distribute-modal.component.html:32](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L32)
  Ionic: Kalender (Montag zuerst) mit Buttons „Fertig“/„Abbrechen“, Wert erst mit „Fertig“, unbegrenzter Bereich / Flutter: md showDatePicker mit „OK“/„Abbrechen“ bzw. iOS-Look Kalenderkarte ohne Buttons (Tipp übernimmt sofort), Bereich 2020–2100.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:96
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-b28d8f3e-2` [duty/duty-distribute-modal/duty-distribute-modal.component.html:39](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L39)
  Anzeigeformat: Ionic ion-datetime-button Intl-Kurzformat (z. B. „31. Dez. 2026“, Ionic-Paket nicht im Container) / Flutter IonDatetimeChip „31.12.2026“.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:379
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-bca25190` [duty/duty-distribute-modal/duty-distribute-modal.component.html:42](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L42)
  Ionic: Kalender mit „Fertig“/„Abbrechen“, unbegrenzter Bereich / Flutter: md showDatePicker mit „OK“/„Abbrechen“ bzw. iOS-Look Kalenderkarte ohne Buttons, Bereich 2020–2100. Keine Prüfung Von ≤ Bis in beiden.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:96
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `text-e73248fa` [duty/duty-distribute-modal/duty-distribute-modal.component.html:96](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L96)
  Ionic: dayjs „dd, DD.MM.“ + „ · HH:mm“, z. B. „Mo, 03.02. · 19:00“ / Flutter: Tag und Monat ohne führende Null, „Mo, 3.2. · 19:00“ (auch im Untertitel des Tausch-Dialogs).
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:88
- [ ] **niedrig** `duty/unavailability-modal/unavailability-modal.component` `field-bb90d03c` [duty/unavailability-modal/unavailability-modal.component.html:57](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/unavailability-modal/unavailability-modal.component.html#L57)
  Ionic: natives Datumsfeld (ion-input type=date) mit gestapeltem Label „Gültig bis (optional)“, zeigt das Datum im Browser-Format bzw. leer / Flutter: Zeile mit Label, Wert „bis 31.12.2026“ bzw. „unbefristet“, Tipp öffnet Datumsauswahl (Vorjahr bis +10 Jahre), X-Button zum Leeren. Gespeichert wird in beiden YYYY-MM-DD oder null.
  Flutter: lib/features/duty/presentation/pages/unavailability_page.dart:350, lib/features/duty/presentation/pages/unavailability_page.dart:166
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `modal-1bead9c9` [instruments/instrument-list/instrument-list.page.ts:159](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L159)
  Nur für Admin/Verantwortliche, übergibt die Gruppe (plus Kategorien). Ionic: iOS Karten-Modal (presentingElement), md Vollbild / Flutter: Vollbild-Dialog (fullscreenDialog) auf allen Plattformen. Neuladen nach Änderung in beiden.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:437
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `alert-eeb83d29` [instruments/instrument-list/instrument-list.page.ts:191](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L191)
  Titel „Neue Kategorie“, Buttons „Abbrechen“/„Hinzufügen“, legt Kategorie an. Ionic: Platzhalter „Name der Kategorie“, „Abbrechen“ mit role destructive (iOS rot) / Flutter: schwebendes Label „Name der Kategorie“, „Abbrechen“ neutral; Name wird getrimmt.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:260
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `alert-415386f9` [instruments/instrument-list/instrument-list.page.ts:223](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L223)
  Titel „Bestätigen“, Text „Kategorie wirklich löschen? …“, Buttons „Abbrechen“/„Ja“, löscht. Ionic: „Abbrechen“ mit role destructive (iOS rot), „Ja“ normal / Flutter: „Abbrechen“ neutral, „Ja“ rot gefüllt.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:339
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `alert-bd4338b7` [instruments/instrument-list/instrument-list.page.ts:249](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L249)
  Titel „Kategorie bearbeiten“, vorbelegter Name, Buttons „Abbrechen“/„Speichern“, speichert Namen. Ionic: Platzhalter „Name der Kategorie“, „Abbrechen“ role destructive (iOS rot) / Flutter: schwebendes Label, „Abbrechen“ neutral; Name getrimmt.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:298
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `loading-c2ec3077` [instruments/instrument-list/instrument-list.page.ts:314](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L314)
  Ionic: blockierendes Overlay „Reihenfolge wird gespeichert...“ / Flutter: nur LinearProgressIndicator im Sheet-Kopf, ohne Text, nicht blockierend.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:135
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `loading-7d7ff756` [instruments/instrument-list/instrument-list.page.ts:396](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L396) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay „Reihenfolge wird gespeichert...“ (max. 5 s) / Flutter: kein Ladehinweis, Liste bleibt bedienbar; zudem springt die Liste nach dem Häkchen bis zum Ende von Speichern + Neuladen auf die alte Reihenfolge zurück (_reorderSections = null vor dem await).
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:54
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-3f2a74e6` [instruments/instrument-list/instrument-list.page.html:23](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.html#L23)
  Ionic: Plus-Button immer sichtbar, auch im Sortiermodus / Flutter: im Sortiermodus ausgeblendet.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:122
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `text-49ad7035` [instruments/instrument-list/instrument-list.page.html:33](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.html#L33)
  Gleicher Text „Ziehe die Kategorien …“. Ionic: ion-item mit primary-Hintergrund und weißem Info-Icon / Flutter: normale ListTile mit blauem Info-Icon.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:191
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-a01ef8cf` [instruments/instrument-list/instrument-list.page.html:38](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.html#L38)
  Sortieren per Ziehen und Speichern wie Ionic. Ionic: Zeile mit Griff-Icon (im Sortiermodus) und Badge der gespeicherten sort_order (immer, auch außerhalb des Sortiermodus) / Flutter: Karten; außerhalb des Sortiermodus Kategorie-Icon statt sort_order-Badge, im Sortiermodus Positionsnummer im Kreis, Ziehen per Long-Press (Standard-Griff).
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:197, lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:384
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-623e8e94` [instruments/instrument-list/instrument-list.page.html:51](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.html#L51) (2. Prüfung: bestätigt)
  Nur Admin/Verantwortliche (Sheet-Button), nur außerhalb des Sortiermodus, öffnet „Kategorie bearbeiten“ wie Ionic. Ionic: Stift-Icon in warning-Farbe (orange) / Flutter: Icons.edit in Standardfarbe.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:392
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `text-1d015e65` [instruments/instrument-list/instrument-list.page.html:89](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.html#L89)
  Text „Kategorie (n)“ in primary gleich. Ionic: ion-item-divider sticky (bleibt beim Scrollen oben stehen) / Flutter: IonItemDivider in einer Column, scrollt mit.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:243
- [ ] **niedrig** `instruments/instrument/instrument.page` `loading-2112917a` [instruments/instrument/instrument.page.ts:43](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument/instrument.page.ts#L43)
  Ionic: blockierendes Overlay „Synonyme werden generiert...“ / Flutter: kleiner Spinner statt Funken-Button im Synonym-Feld, ohne Text, Seite bleibt bedienbar.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:683
- [ ] **niedrig** `instruments/instrument/instrument.page` `toast-283b4da3` [instruments/instrument/instrument.page.ts:60](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument/instrument.page.ts#L60) (2. Prüfung: bestätigt)
  Gleicher Text „Bitte gib einen Namen an!“, Seite bleibt offen. Ionic: roter Toast / Flutter: roter Validierungstext unter dem Namensfeld; Flutter wertet reine Leerzeichen ebenfalls als leer.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:604
- [ ] **niedrig** `instruments/instrument/instrument.page` `alert-cb09ce26` [instruments/instrument/instrument.page.ts:88](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument/instrument.page.ts#L88) (2. Prüfung: bestätigt)
  Titel „Bestätigen“, Text „Gruppe wirklich löschen?“, „Abbrechen“/„Ja“, „Ja“ löscht und schließt. Ionic: „Abbrechen“ mit role destructive (iOS rot) / Flutter: beide neutral. Zeitpunkt (Dialog auch bei zugeordneten Personen) siehe toast-39c411aa.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:755
- [ ] **niedrig** `instruments/instrument/instrument.page` `text-60ebf1b1` [instruments/instrument/instrument.page.html:4](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument/instrument.page.html#L4)
  Ionic: Titel an instrument.name gebunden, ändert sich beim Tippen im Namensfeld / Flutter: fester Titel mit dem ursprünglichen Namen.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:585
- [ ] **niedrig** `instruments/instrument/instrument.page` `field-679fa215` [instruments/instrument/instrument.page.html:42](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument/instrument.page.html#L42)
  Label „Stimmung“, Optionen C, Es, B, F, Sichtbarkeit gleich. Ionic: Popover-Auswahl, leerer Wert bleibt leer / Flutter: Dropdown, leerer (oder unbekannter) Wert wird als „C“ angezeigt, leerer Wert wird beim Speichern zu „C“.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:628
- [ ] **niedrig** `instruments/instrument/instrument.page` `field-ae69e131` [instruments/instrument/instrument.page.html:66](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument/instrument.page.html#L66)
  Optionen Violinschlüssel (G), Bassschlüssel (F), Altschlüssel (C), Mehrfachauswahl. Ionic: Popover-Mehrfachauswahl mit (fehlerhaftem) Label „Stimmung“, alle abwählbar / Flutter: Überschrift „Notenschlüssel“ mit FilterChips, mindestens ein Schlüssel bleibt gewählt.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:646
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-9dd7902a` [people/bulk-edit/bulk-edit.page.html:53](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L53)
  Ionic: ion-toggle mit Beschriftung 'Stimmführer' / Flutter: nur Switch rechts ohne Beschriftung. Startwert false in beiden.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:514-518
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-523de84f` [people/bulk-edit/bulk-edit.page.html:61](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L61)
  Eingabefeld mit Platzhalter = Feldname gleich. Startwert: Ionic immer '' (getFieldTypeDefaultValue ohne defaultValue) / Flutter: konfigurierter Standardwert des Feldes, sonst ''.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:573-574, lib/features/people/presentation/pages/bulk_edit_page.dart:123-133
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-fc367be8` [people/bulk-edit/bulk-edit.page.html:67](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L67)
  Dropdown mit Optionen in Reihenfolge, Platzhalter = Feldname gleich. Startwert: Ionic immer erste Option / Flutter: Standardwert des Feldes, sonst erste Option.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:542-545, lib/features/people/presentation/pages/bulk_edit_page.dart:126-130
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-d2bdf3b7` [people/bulk-edit/bulk-edit.page.html:73](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L73)
  Ionic: ion-textarea mit autoGrow (mehrzeilig) / Flutter: einzeiliges TextFormField (default-Zweig). Startwert Ionic '' / Flutter Standardwert des Feldes oder ''.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:573-574, lib/features/people/presentation/pages/bulk_edit_page.dart:469-485
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-523de84f-3` [people/bulk-edit/bulk-edit.page.html:81](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L81) (2. Prüfung: bestätigt)
  Ionic: natives input type=date (leerbar), Startwert new Date().toISOString() (nicht angezeigt, aber von 'Für alle setzen' geschrieben) / Flutter: Button mit Datumsdialog ('Kein Datum gewählt'), nicht leerbar, Startwert Standardwert oder '' → schreibt ''.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:552, lib/features/people/presentation/pages/bulk_edit_page.dart:115
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-4964deb8-4` [people/bulk-edit/bulk-edit.page.html:165](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L165)
  Ionic: natives input type=date (Wert leerbar) / Flutter: Button mit Datumsauswahl, zeigt 'Kein Datum gewählt' bzw. Datum, Wert kann nicht geleert werden. Format yyyy-MM-dd gleich.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:398-406, lib/features/people/presentation/pages/bulk_edit_page.dart:552-572
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `action-a2a2fcd3` [people/bulk-edit/bulk-edit.page.html:176](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/bulk-edit/bulk-edit.page.html#L176) (2. Prüfung: bestätigt)
  Texte 'Speichern...' / '# Änderung(en) speichern' / 'Keine Änderungen' und Deaktivierung gleich. Ionic: Spinner vor 'Speichern...' / Flutter: nur Text.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:433
- [ ] **niedrig** `people/import/import.page` `loading-3194637c` [people/import/import.page.ts:97](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.ts#L97)
  Flutter blockiert mit Overlay (Spinner) und deaktiviertem X, aber ohne Text 'Datei wird gelesen...' (peopleReadingFile ungenutzt).
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:82, lib/features/people/presentation/pages/person_import_page.dart:262-284
- [ ] **niedrig** `people/import/import.page` `loading-b32cfbfa` [people/import/import.page.ts:135](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.ts#L135)
  Ionic: blockierendes Overlay 'Daten werden geprüft...' / Flutter: Overlay nur mit Spinner (peopleCheckingData ungenutzt), 'Zurück' in der unteren Leiste bleibt bedienbar.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:137, lib/features/people/presentation/pages/person_import_page.dart:262-284
- [ ] **niedrig** `people/import/import.page` `loading-bab0752f` [people/import/import.page.ts:213](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.ts#L213)
  Fortschritt '{done} / {total} importiert...' wird angezeigt und aktualisiert, aber Ionic blockiert den ganzen Bildschirm / Flutter: Overlay nur über dem Inhalt, 'Zurück' in der unteren Leiste bleibt während des Imports bedienbar.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:174-177, lib/features/people/presentation/pages/person_import_page.dart:200-202, lib/features/people/presentation/pages/person_import_page.dart:262-284
- [ ] **niedrig** `people/import/import.page` `alert-3b9d1c7b` [people/import/import.page.ts:254](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.ts#L254)
  Titel 'Nicht importierte Personen', max. 10 Zeilen '• Vorname Nachname: Grund', '… und N weitere', Button 'OK' gleich. Grund: Ionic error.message / Flutter '$e' (z. B. 'RepositoryException: … (operation: …, code: …)').
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:198, lib/features/people/presentation/pages/person_import_page.dart:220, lib/features/people/presentation/widgets/import_widgets.dart:226-243
- [ ] **niedrig** `people/import/import.page` `text-da6273ad` [people/import/import.page.html:16](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.html#L16) (2. Prüfung: bestätigt)
  Text gleich. Ionic: grau (.intro medium, 0.9rem) / Flutter: normale Textfarbe. Der Text nennt .xls, das Flutter ablehnt (siehe field-bdcf25e7).
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:245, lib/features/people/presentation/widgets/import_widgets.dart:30
- [ ] **niedrig** `people/import/import.page` `text-ac3c014f` [people/import/import.page.html:37](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.html#L37)
  '— N Zeilen' gleich. Ionic: grau (medium) / Flutter: normale Textfarbe.
  Flutter: lib/features/people/presentation/widgets/import_widgets.dart:85-88
- [ ] **niedrig** `people/import/import.page` `text-432acf42` [people/import/import.page.html:37](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.html#L37)
  Dateiname fett gleich. Ionic: grau (medium) / Flutter: normale Textfarbe.
  Flutter: lib/features/people/presentation/widgets/import_widgets.dart:86
- [ ] **niedrig** `people/import/import.page` `text-9a34d1ef` [people/import/import.page.html:38](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.html#L38)
  Text gleich. Ionic: grau (medium, 0.9rem) / Flutter: normale Textfarbe.
  Flutter: lib/features/people/presentation/widgets/import_widgets.dart:90
- [ ] **niedrig** `people/import/import.page` `field-018f6a18` [people/import/import.page.html:102](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/import/import.page.html#L102)
  Gruppen-Dropdown pro Zeile (nicht bei Fehlern), Auswahl setzt groupResolved, gleich. Ionic: Label 'Gruppe' immer über dem Wert, ungeklärte Gruppe mit orangem Rahmen / Flutter: 'Gruppe' nur als Hinweis bei leerem Wert, ungeklärte Gruppe als orange Schrift.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:364-385
- [ ] **niedrig** `people/list/list.page` `loading-a2fa55fe` [people/list/list.page.ts:97](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L97)
  Ionic: blockierendes Loading-Overlay (ohne Text, 3 s) beim Instanzwechsel über das Header-Popover / Flutter: switchTenant ohne Overlay.
  Flutter: lib/shared/widgets/tenant/tenant_switcher_title.dart:389
- [ ] **niedrig** `people/list/list.page` `loading-275de79e` [people/list/list.page.ts:377](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L377)
  Ionic: blockierendes Overlay 'Reihenfolge wird gespeichert...' / Flutter: nur Spinner im Häkchen-Button, kein Overlay (X-Abbrechen und Ziehen bleiben bedienbar).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:463, lib/features/people/presentation/pages/people_list_page.dart:1169
- [ ] **niedrig** `people/list/list.page` `alert-0eb34b23` [people/list/list.page.ts:437](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L437)
  Ionic: Alert 'Instanz wählen' mit Radio-Liste (gespeicherte Instanz vorausgewählt) und Buttons 'Abbrechen' (setzt Filter auf Alle) / 'Filtern' / Flutter: Auswahl-Dialog 'Instanz wählen' ohne Buttons, Tipp auf eine Instanz filtert sofort, Schließen lässt den bisherigen Filter stehen. Gefilterte Daten gleich (Nicht-Betrachter-Konten der Instanz).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1084, lib/features/people/presentation/pages/people_list_page.dart:1095
- [ ] **niedrig** `people/list/list.page` `alert-1081984d` [people/list/list.page.ts:538](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L538)
  Ionic: Alert mit Radio 'Ja'/'Nein' (Ja bzw. gespeicherter Wert vorausgewählt) und 'Abbrechen' (→ Alle) / 'Filtern' / Flutter: einfacher Auswahl-Dialog 'Ja'/'Nein' ohne Buttons, Tipp filtert sofort, Schließen → Alle. Default true für leere Werte gleich.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1027, lib/features/people/presentation/pages/people_list_page.dart:1029, lib/features/people/presentation/pages/people_list_page.dart:1036
- [ ] **niedrig** `people/list/list.page` `loading-5e1535fb` [people/list/list.page.ts:821](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L821)
  Ionic: blockierendes Overlay 'Person wird entfernt...' / Flutter: kein Overlay.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1480
- [ ] **niedrig** `people/list/list.page` `loading-93ed0021` [people/list/list.page.ts:872](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L872) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay 'Wird pausiert...' / Flutter: kein Overlay; danach zusätzlich grüne Snackbar '<Vorname> wurde pausiert' (Ionic: keine Meldung).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:211, lib/features/people/presentation/widgets/pause_person_sheet.dart:221
- [ ] **niedrig** `people/list/list.page` `loading-8b3a6dad` [people/list/list.page.ts:969](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L969)
  Ionic: blockierendes Overlay 'Wird aktiviert...' / Flutter: kein Overlay.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1357
- [ ] **niedrig** `people/list/list.page` `modal-a495856e` [people/list/list.page.ts:1036](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L1036) (2. Prüfung: korrigiert)
  Gefilterte Personen übergeben, Neuladen bei Rückgabe true gleich. Ionic: Modal mit presentingElement → auf iOS Karten-Modal (Seite dahinter sichtbar, Wischen schließt), md Vollbild / Flutter: Vollbild-Dialog (fullscreenDialog) auf allen Plattformen. Erstprüfung: ok – Darstellung auf iOS weicht ab (wie instrument-list modal-1bead9c9 bewertet).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1280, lib/features/people/presentation/pages/people_list_page.dart:1289
- [ ] **niedrig** `people/list/list.page` `action-15041222` [people/list/list.page.html:47](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L47) (2. Prüfung: bestätigt)
  Ionic: Pull-to-Refresh lädt Personen und Termine (Prozente) neu und wartet / Flutter: invalidiert nur realtimePlayersProvider, Spinner endet sofort; Prozente kommen aus playerAttendancePercentagesProvider (nur per Realtime-Zähler aktualisiert).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:503, lib/features/people/presentation/pages/people_list_page.dart:648, lib/features/people/presentation/pages/people_list_page.dart:670
- [ ] **niedrig** `people/list/list.page` `text-ccf5d7d7` [people/list/list.page.html:228](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L228)
  Normalfall gleich ('<Gruppe> (n)', primärer Trenner). Sonderfälle: Personen ohne bekannte Gruppe – Ionic Trenner ' (n)' ohne Namen / Flutter 'Keine Gruppe (n)'; Flutter gruppiert nach Gruppenname statt Gruppen-ID (gleichnamige Gruppen würden zusammengelegt).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:404, lib/features/people/presentation/pages/people_list_page.dart:622
- [ ] **niedrig** `people/list/list.page` `action-e7b7f732` [people/list/list.page.html:230](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L230) (2. Prüfung: bestätigt)
  Ionic: Reihenfolge direkt in der normalen Liste (ion-reorder-Griffe in den vollen Zeilen, Gruppen-Trenner) / Flutter: eigene vereinfachte Liste (Karten nur mit Name + Ziehgriff, Gruppentitel als Text) plus X zum Verwerfen. Zeileninhalt siehe action-982a1154.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1189, lib/features/people/presentation/pages/people_list_page.dart:1147
- [ ] **niedrig** `people/list/list.page` `action-6ccc25e4` [people/list/list.page.html:505](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L505)
  Ionic: X-Icon in der Modal-Toolbar / Flutter: Textbutton 'Abbrechen' im Dialog.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1426
- [ ] **niedrig** `people/list/list.page` `action-64a96898` [people/list/list.page.html:521](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L521) (2. Prüfung: bestätigt)
  Ionic: FAB mit Archiv-Icon unten rechts im Modal / Flutter: Button 'Archivieren' mit Archiv-Icon in der Dialog-Aktionsleiste.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1430
- [ ] **niedrig** `people/list/list.page` `field-c1d3a82f` [people/list/list.page.html:545](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L545)
  Platzhalter Ionic 'Bitte gib einen Grund an...' / Flutter 'Gib einen Grund für die Pause an...' (personPauseReasonPlaceholder); sonst gleich (mehrzeilig, Satzanfang groß).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:112, lib/features/people/presentation/widgets/pause_person_sheet.dart:116
- [ ] **niedrig** `people/list/list.page` `field-187f6bb7` [people/list/list.page.html:567](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L567)
  Ionic: Inline-Kalender im Akkordeon (max heute, keine Untergrenze) / Flutter: Datumspicker-Dialog beim Tippen auf die Zeile (max heute, frühestens vor 5 Jahren).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:131, lib/features/people/presentation/widgets/pause_person_sheet.dart:135
- [ ] **niedrig** `people/list/list.page` `field-315040b9` [people/list/list.page.html:594](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L594) (2. Prüfung: bestätigt)
  Ionic: Inline-Kalender im Akkordeon (ab heute, ohne Obergrenze, keine Vorauswahl) / Flutter: Datumsdialog (ab heute, bis +3 Jahre, Start heute + 30 Tage).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:141, lib/features/people/presentation/widgets/pause_person_sheet.dart:150
- [ ] **niedrig** `people/list/list.page` `text-63b77c8c` [people/list/list.page.html:606](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L606)
  Ionic: '… Wenn ein Enddatum angegeben wird, wird die Person automatisch reaktiviert.' / Flutter: '… Wenn ein Enddatum angegeben ist, wird die Person danach automatisch wieder aktiviert.' (gleiche Bedeutung).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:157
- [ ] **niedrig** `people/list/list.page` `action-32a9bf9f` [people/list/list.page.html:610](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L610)
  Ionic: Block-Button in Primärfarbe / Flutter: gelber (warning) Button; sonst gleich (Pause-Icon, 'Pausieren', ohne Grund deaktiviert).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:163, lib/features/people/presentation/widgets/pause_person_sheet.dart:177
- [ ] **niedrig** `people/members/members.page` `toast-d347f87a` [people/members/members.page.ts:72](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/members/members.page.ts#L72)
  Ionic: roter Toast 'Fehler beim Laden der Mitglieder.' + darunter 'Keine Mitglieder gefunden.' / Flutter: kein Toast, Text 'Fehler beim Laden der Mitglieder.' inline mit Personen-Icon.
  Flutter: lib/features/members/presentation/pages/members_page.dart:98, lib/features/members/presentation/pages/members_page.dart:99
- [ ] **niedrig** `people/person/person.page` `loading-be5cc2f1` [people/person/person.page.ts:389](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L389)
  Ionic: blockierendes Loading „Wird zurückgesetzt...“ / Flutter: kein Ladeindikator beim Zurücksetzen
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1151, lib/features/people/presentation/widgets/person_detail/late_warning_card.dart
- [ ] **niedrig** `people/person/person.page` `toast-9348bff8` [people/person/person.page.ts:528](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L528)
  Ionic: Toast „Bitte gib den Vornamen und Nachnamen an.“ / Flutter: Inline-Validierung unter den Feldern „Vorname ist erforderlich“/„Nachname ist erforderlich“, Labels mit „*“
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:370, lib/features/people/presentation/pages/person_create_page.dart:389
- [ ] **niedrig** `people/person/person.page` `loading-b5454ced` [people/person/person.page.ts:532](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L532)
  Ionic: blockierendes Loading (3 s) beim Hinzufügen / Flutter: nur Speichern-Button deaktiviert, kein Overlay
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:334, lib/features/people/presentation/pages/person_create_page.dart:989
- [ ] **niedrig** `people/person/person.page` `loading-d68742ec` [people/person/person.page.ts:553](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L553)
  Ionic: blockierendes Loading beim Speichern / Flutter: nur Speichern-FAB deaktiviert (_isSaving), kein Overlay
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:587, lib/features/people/presentation/pages/person_detail_page.dart:1733
- [ ] **niedrig** `people/person/person.page` `toast-cee56561` [people/person/person.page.ts:738](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L738)
  Ionic: „Der Benutzer wurde erfolgreich entfernt“ / Flutter: „Account-Verknüpfung aufgehoben“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1582
- [ ] **niedrig** `people/person/person.page` `toast-f55609ac` [people/person/person.page.ts:740](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L740) (2. Prüfung: bestätigt)
  Ionic: „Fehler beim Entfernen des Benutzers“ (danger) / Flutter: „Fehler: {error}“ (danger).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1590
- [ ] **niedrig** `people/person/person.page` `alert-cd59453f` [people/person/person.page.ts:848](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L848)
  1 Treffer: gleich (Abbrechen/Ja). Mehrere Treffer: Ionic Alert mit Radio-Liste (erster vorausgewählt) + Abbrechen/Ja / Flutter: SimpleDialog, Tippen auf Eintrag übernimmt sofort, nur „Abbrechen“
  Flutter: lib/features/people/presentation/widgets/person_match_suggestions.dart:120, lib/features/people/presentation/widgets/person_match_suggestions.dart:148
- [ ] **niedrig** `people/person/person.page` `loading-ae31ca18` [people/person/person.page.ts:903](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L903)
  Ionic: blockierendes Loading „Die Personen werden zusammengeführt...“ / Flutter: nur LinearProgressIndicator in der Karte, nicht blockierend, ohne Text
  Flutter: lib/features/people/presentation/widgets/duplicate_candidates_card.dart:81, lib/features/people/presentation/widgets/duplicate_candidates_card.dart:132
- [ ] **niedrig** `people/person/person.page` `loading-9ba0a7e4` [people/person/person.page.ts:1013](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1013)
  Ionic: blockierendes Loading beim Account anlegen / Flutter: kein Ladeindikator
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1596
- [ ] **niedrig** `people/person/person.page` `toast-8807fdd9` [people/person/person.page.ts:1019](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1019) (2. Prüfung: bestätigt)
  Ionic: „Account wurde erfolgreich angelegt“ / Flutter: „Account erstellt. Passwort-E-Mail wurde gesendet.“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1655
- [ ] **niedrig** `people/person/person.page` `toast-fc0e45e2` [people/person/person.page.ts:1022](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1022)
  Ionic: Roh-Fehlermeldung error.message / Flutter: „{name} - Fehler beim Erstellen des Accounts: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1664
- [ ] **niedrig** `people/person/person.page` `loading-b96f785a` [people/person/person.page.ts:1090](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1090)
  Ionic: blockierendes Loading beim Bildupload / Flutter: nur Info-Toast „Lade Passbild hoch...“, nicht blockierend
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:225
- [ ] **niedrig** `people/person/person.page` `toast-7e0a2ff5` [people/person/person.page.ts:1119](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1119)
  Ionic: Roh-Fehler / Flutter: „Fehler beim Hochladen: {error}“
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:274
- [ ] **niedrig** `people/person/person.page` `loading-fc02b5d4` [people/person/person.page.ts:1203](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1203) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading während „Meinen Benutzer zuweisen“ / Flutter: kein Ladeindikator.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:962
- [ ] **niedrig** `people/person/person.page` `toast-968501f7` [people/person/person.page.ts:1213](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1213)
  Ionic: Roh-Fehler error.message / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:988
- [ ] **niedrig** `people/person/person.page` `toast-f74ad707` [people/person/person.page.ts:1251](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1251)
  Ionic: Roh-Fehler / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1044
- [ ] **niedrig** `people/person/person.page` `toast-f74ad707-2` [people/person/person.page.ts:1312](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1312)
  Ionic: Roh-Fehler / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1488
- [ ] **niedrig** `people/person/person.page` `toast-d7c9e86c` [people/person/person.page.ts:1371](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1371) (2. Prüfung: bestätigt)
  Ionic: „Die Person wurde erfolgreich kopiert/übertragen“ / Flutter: „1 Spieler erfolgreich kopiert/übertragen“.
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:819
- [ ] **niedrig** `people/person/person.page` `toast-b4300d3e` [people/person/person.page.ts:1373](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1373)
  Ionic: Roh-Fehler / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:830
- [ ] **niedrig** `people/person/person.page` `toast-f4e0ab31` [people/person/person.page.ts:1433](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1433)
  Ionic: Roh-Fehler / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:212
- [ ] **niedrig** `people/person/person.page` `alert-71956f19` [people/person/person.page.ts:1439](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1439)
  Texte/Buttons gleich (Überspringen/Pausieren, Checkboxen). Flutter besser: bietet nur Instanzen an, in denen der Nutzer Personen verwalten darf; Ionic listet alle verknüpften Instanzen
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:236, lib/features/people/presentation/widgets/pause_person_sheet.dart:284
- [ ] **niedrig** `people/person/person.page` `loading-cd6c7935` [people/person/person.page.ts:1496](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1496)
  Ionic: blockierendes Loading beim Eintragen der Abwesenheit / Flutter: kein Ladeindikator
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:230
- [ ] **niedrig** `people/person/person.page` `loading-6f0c380f` [people/person/person.page.ts:1546](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1546)
  Ionic: blockierendes Loading beim Löschen der Abwesenheit / Flutter: kein Ladeindikator
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:248
- [ ] **niedrig** `people/person/person.page` `actionsheet-eadcf3f0` [people/person/person.page.ts:1641](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1641) (2. Prüfung: korrigiert)
  Bedingung gleich (ausstehende Person, Admin/Verantwortliche), Texte, Reihenfolge und Wirkung gleich. Ionic: keine Icons, 'Abbrechen' mit role destructive (rot, in der Button-Gruppe) / Flutter: grünes Haken-Icon und grüne Schrift bei 'Person genehmigen', Icon bei 'Person ablehnen', 'Abbrechen' als normaler separater Abbrechen-Button (cancelDestructive fehlt, anders als im '…'-Menü).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1330
- [ ] **niedrig** `people/person/person.page` `loading-58ec291d` [people/person/person.page.ts:1680](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1680)
  Ionic: blockierendes Loading „Die Person wird abgelehnt...“ / Flutter: kein Ladeindikator
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1300
- [ ] **niedrig** `people/person/person.page` `toast-55836540` [people/person/person.page.ts:1702](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1702)
  Ionic: „Die Spielerdaten wurden erfolgreich aktualisiert.“ / Flutter: „Person wurde abgelehnt“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1313
- [ ] **niedrig** `people/person/person.page` `toast-26c7e22c` [people/person/person.page.ts:1705](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1705)
  Ionic: „Fehler beim aktualisieren des Spielers“ / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1322
- [ ] **niedrig** `people/person/person.page` `loading-00357310` [people/person/person.page.ts:1717](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1717) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading „Die Person wird genehmigt...“ / Flutter: kein Ladeindikator (vorher zusätzlicher Bestätigungsdialog „Person genehmigen?“).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1210, lib/features/people/presentation/pages/person_detail_page.dart:1233
- [ ] **niedrig** `people/person/person.page` `toast-c09ff9ac` [people/person/person.page.ts:1741](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1741)
  Ionic: „Die Spielerdaten wurden erfolgreich aktualisiert.“ / Flutter: „Person wurde genehmigt“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1241
- [ ] **niedrig** `people/person/person.page` `toast-1b04b6d6` [people/person/person.page.ts:1744](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L1744)
  Ionic: „Fehler beim aktualisieren des Spielers“ / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1250
- [ ] **niedrig** `people/person/person.page` `action-5615e0d7` [people/person/person.page.html:49](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L49)
  Ionic: Viewer-Titel „Passbild“, Bild in voller Qualität (ohne ?quality=20) / Flutter: Titel „{Vorname Nachname}.jpg“, Bild-URL unverändert, keine Aktionen im Viewer
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:205, lib/shared/widgets/sheets/image_viewer_sheet.dart:276
- [ ] **niedrig** `people/person/person.page` `text-e915fb37` [people/person/person.page.html:74](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L74)
  Detail: Label „Vorname“ gleich; Neu-Seite: „Vorname *“
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:236, lib/features/people/presentation/pages/person_create_page.dart:365
- [ ] **niedrig** `people/person/person.page` `field-4b77b853` [people/person/person.page.html:75](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L75)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe (Detail, mit Pflicht-Validierung); Neu-Seite: TextFormField mit Pflicht-Validierung, Namensvorschläge wie Ionic
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:233, lib/features/people/presentation/pages/person_create_page.dart:362
- [ ] **niedrig** `people/person/person.page` `text-c4ad9070` [people/person/person.page.html:82](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L82)
  Detail: Label „Nachname“ gleich; Neu-Seite: „Nachname *“
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:252, lib/features/people/presentation/pages/person_create_page.dart:384
- [ ] **niedrig** `people/person/person.page` `field-6e1a9b00` [people/person/person.page.html:83](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L83)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe (Detail, mit Pflicht-Validierung); Neu-Seite: TextFormField mit Pflicht-Validierung
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:249, lib/features/people/presentation/pages/person_create_page.dart:381
- [ ] **niedrig** `people/person/person.page` `text-5dbfd756` [people/person/person.page.html:116](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L116) (2. Prüfung: bestätigt)
  Prozent-Badge (Score) der Duplikat-Kandidaten fehlt in der Flutter-Karte (lib/features/people/presentation/widgets/duplicate_candidates_card.dart:133).
- [ ] **niedrig** `people/person/person.page` `action-c72e602e` [people/person/person.page.html:131](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L131)
  Schließen-Button gleich; Flutter zeigt zusätzlich Überschrift „Person in anderer Instanz gefunden?“ über den Vorschlägen (Ionic ohne Überschrift)
  Flutter: lib/features/people/presentation/widgets/person_match_suggestions.dart:40, lib/features/people/presentation/widgets/person_match_suggestions.dart:46
- [ ] **niedrig** `people/person/person.page` `field-05790430` [people/person/person.page.html:164](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L164) (2. Prüfung: bestätigt)
  Ionic: Inline-Textarea (autoGrow) / Flutter: Zeile („Keine Notizen“ wenn leer), Tipp öffnet Editor-Sheet; leere Notiz wird als null gespeichert.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:273, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:278
- [ ] **niedrig** `people/person/person.page` `field-4bf62b27` [people/person/person.page.html:221](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L221)
  Ionic: Label „Gruppe“, Modal-Select / Flutter: Label je Instanztyp „Stimme“/„Instrument“/„Gruppe“, Auswahl-Sheet; Wechsel setzt Stimmführer zurück wie Ionic
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:289, lib/features/people/presentation/pages/person_detail_page.dart:444
- [ ] **niedrig** `people/person/person.page` `text-bb66373a` [people/person/person.page.html:245](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L245)
  Ionic: „Telefon-/Handynummer“ / Flutter: „Telefon“
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:336
- [ ] **niedrig** `people/person/person.page` `field-84804c14` [people/person/person.page.html:246](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L246) (2. Prüfung: bestätigt)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; zusätzlich Anruf-Button; leer + nicht bearbeitbar ausgeblendet (Ionic: leeres deaktiviertes Feld).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:330
- [ ] **niedrig** `people/person/person.page` `action-02594b69` [people/person/person.page.html:259](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L259)
  Ionic: separater Kalender-Button am Feld / Flutter: kein eigener Button, Tipp auf die Zeile öffnet die Datumsauswahl
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `modal-9c171caa` [people/person/person.page.html:266](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L266)
  Ionic: Modal mit Rad-Datumsauswahl (preferWheel) / Flutter: Material-DatePicker-Dialog bzw. Kalender-Karte (iOS-Look)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371, lib/shared/widgets/adaptive/app_pickers.dart:12
- [ ] **niedrig** `people/person/person.page` `field-946f7994` [people/person/person.page.html:268](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L268)
  Ionic: ion-datetime Rad, max = heute / Flutter: Kalender, lastDate = heute; Speichern als Datum wie Ionic; setzt correctBirthday beim Speichern
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371, lib/features/people/presentation/pages/person_detail_page.dart:643
- [ ] **niedrig** `people/person/person.page` `action-02594b69-2` [people/person/person.page.html:291](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L291)
  Ionic: separater Kalender-Button am Feld / Flutter: kein eigener Button, Tipp auf die Zeile öffnet die Datumsauswahl
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `modal-637d2f88` [people/person/person.page.html:298](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L298)
  Ionic: Modal mit Rad-Datumsauswahl (preferWheel) / Flutter: Material-DatePicker-Dialog bzw. Kalender-Karte (iOS-Look)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `field-6cfcad0a` [people/person/person.page.html:300](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L300)
  Ionic: ion-datetime Rad, max = heute / Flutter: Kalender, lastDate = heute; Speichern als Datum wie Ionic
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `action-02594b69-3` [people/person/person.page.html:323](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L323) (2. Prüfung: bestätigt)
  Ionic: separater Kalender-Button am Feld „Beigetreten am“ / Flutter: kein eigener Button, Tipp auf die Zeile öffnet die Datumsauswahl.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:184, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:377
- [ ] **niedrig** `people/person/person.page` `modal-5e3cc20f` [people/person/person.page.html:330](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L330)
  Ionic: Modal mit Rad-Datumsauswahl (preferWheel) / Flutter: Material-DatePicker-Dialog bzw. Kalender-Karte (iOS-Look)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `field-8c59f281` [people/person/person.page.html:332](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L332)
  Ionic: ion-datetime Rad, max = heute / Flutter: Kalender, lastDate = heute; Speichern als Datum wie Ionic
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:371
- [ ] **niedrig** `people/person/person.page` `text-c617e6c6` [people/person/person.page.html:349](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L349)
  Label „Eltern“ gleich; Flutter-Bedingung ohne „!isParent“ (Ionic blendet das Feld für Benutzer mit Rolle Elternteil aus)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:194, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:599
- [ ] **niedrig** `people/person/person.page` `field-06ab1bbe` [people/person/person.page.html:350](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L350)
  Ionic: Modal-Select, ohne Auswahl „Nicht festgelegt“ / Flutter: Auswahl-Sheet mit Option „Nicht festgelegt“, Anzeige ohne Auswahl aber „Nicht zugewiesen“
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:599
- [ ] **niedrig** `people/person/person.page` `field-6acc513f` [people/person/person.page.html:402](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L402)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; leer + nicht bearbeitbar ausgeblendet
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:848
- [ ] **niedrig** `people/person/person.page` `field-7662f2a7` [people/person/person.page.html:435](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L435)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; leer + nicht bearbeitbar ausgeblendet (Ionic: immer sichtbar)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:877
- [ ] **niedrig** `people/person/person.page` `field-016207ea` [people/person/person.page.html:462](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L462)
  Flutter: zusätzliche Leer-Option „Keine Schicht zugewiesen“, Anzeige „Nicht ausgewählt“ (Ionic: keine Leer-Option, vorbelegt mit erster Schicht)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:529
- [ ] **niedrig** `people/person/person.page` `field-ea337733` [people/person/person.page.html:474](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L474)
  Ionic: ion-datetime-button / Flutter: Zeile mit Datum, leer „Nicht angegeben“, Tipp öffnet Datumsauswahl
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:568
- [ ] **niedrig** `people/person/person.page` `modal-ac91c261` [people/person/person.page.html:475](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L475)
  Ionic: Modal mit ion-datetime / Flutter: DatePicker-Dialog bzw. Kalender-Karte
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:583
- [ ] **niedrig** `people/person/person.page` `text-79d104bf` [people/person/person.page.html:490](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L490) (2. Prüfung: korrigiert)
  Bedingung nicht ganz gleich. Ionic: !readOnly || otherExercise (leerer String gilt als leer) / Flutter: otherExercise != null || canEdit → Beobachter und archivierte Personen sehen bei gespeichertem '' eine leere Zeile „Sonstige Dienste“.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:223, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:644
- [ ] **niedrig** `people/person/person.page` `field-eb1656da` [people/person/person.page.html:491](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L491)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:641
- [ ] **niedrig** `people/person/person.page` `field-d1e5b0ca` [people/person/person.page.html:510](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L510)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; Prüfung im Sheet nur auf „@“; Suche in anderen Instanzen nach Änderung statt bei Blur; gesperrt wenn appId wie Ionic
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:84, lib/features/people/presentation/pages/person_detail_page.dart:852
- [ ] **niedrig** `people/person/person.page` `action-06c55240` [people/person/person.page.html:514](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L514)
  Ionic: Lupen-Icon-Button rechts im E-Mail-Feld, deaktiviert ohne E-Mail / Flutter: Textbutton „In anderer Instanz suchen“ unter dem Feld, nur sichtbar mit E-Mail
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:94
- [ ] **niedrig** `people/person/person.page` `action-0de62271` [people/person/person.page.html:519](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L519)
  Ionic: roter Papierkorb-Icon-Button rechts im E-Mail-Feld / Flutter: Outlined-Button „Account-Verknüpfung aufheben“ unter der Rollenauswahl
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:127
- [ ] **niedrig** `people/person/person.page` `field-280cafd6` [people/person/person.page.html:530](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L530) (2. Prüfung: bestätigt)
  Optionen/Reihenfolge, Stimmführer-Optionen nur bei isLeader, Sperre bei Hauptgruppe, sofortiges Schreiben + Toast „Die Rolle wurde erfolgreich aktualisiert.“ gleich. Flutter besser: aktuelle Rolle außerhalb der Liste (z. B. Admin) wird angezeigt statt leerem Select; Bedingung nur appId (Ionic email && appId).
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:211, lib/features/people/presentation/widgets/person_detail/account_accordion.dart:225, lib/features/people/presentation/pages/person_detail_page.dart:1492
- [ ] **niedrig** `people/person/person.page` `action-36a985b0` [people/person/person.page.html:554](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L554)
  Ionic: X-Icon in der Toolbar / Flutter: Textbutton „Schließen“
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:296
- [ ] **niedrig** `people/person/person.page` `field-247f92a0` [people/person/person.page.html:585](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L585)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:766
- [ ] **niedrig** `people/person/person.page` `modal-9dba127a` [people/person/person.page.html:608](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L608)
  Ionic: Modal mit Rad-Datumsauswahl / Flutter: DatePicker-Dialog bzw. Kalender-Karte
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:795
- [ ] **niedrig** `people/person/person.page` `field-e423e2ec` [people/person/person.page.html:610](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L610)
  Ionic: max = heute / Flutter: Kalender 1900–2100 (kein Maximum heute)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:795, lib/shared/widgets/sheets/field_editor_sheet.dart:213
- [ ] **niedrig** `people/person/person.page` `field-50c752ee` [people/person/person.page.html:621](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L621)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe (Auswahl-Sheet); fehlender Wert in Ionic mit erster Option vorbelegt, Flutter „Nicht angegeben“
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:808
- [ ] **niedrig** `people/person/person.page` `field-049486aa` [people/person/person.page.html:628](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L628)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe (4 Zeilen)
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:766
- [ ] **niedrig** `people/person/person.page` `modal-cc0c1d20` [people/person/person.page.html:635](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L635)
  Ionic: Vollbild-Modal / Flutter: Bottom-Sheet mit 85 % Höhe
  Flutter: lib/features/people/presentation/widgets/church_picker_sheet.dart:26
- [ ] **niedrig** `people/person/person.page` `text-4ba50278` [people/person/person.page.html:707](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L707) (2. Prüfung: bestätigt)
  Ionic: Bereich „Historie“ nur sichtbar, wenn Einträge vorhanden (personAttendance wird nie befüllt, also history.length) / Flutter: immer sichtbar, leer mit „Keine Historie vorhanden“ (Durchschnitt 0 %), zusätzlicher Umschalter „Alle anzeigen“ (alle Saisons).
  Flutter: lib/features/people/presentation/widgets/person_detail/historie_accordion.dart:49, lib/features/people/presentation/widgets/person_detail/historie_accordion.dart:76, lib/features/people/presentation/widgets/person_detail/historie_accordion.dart:102
- [ ] **niedrig** `people/person/person.page` `text-0f8281df` [people/person/person.page.html:803](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L803)
  Text gleich; Flutter zählt Termine ab heute (gte heute), Ionic nur Termine nach jetzt — heutige Termine erscheinen in Flutter zusätzlich hier und in der Historie
  Flutter: lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:20, lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:121
- [ ] **niedrig** `people/person/person.page` `text-9bed7686` [people/person/person.page.html:811](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L811) (2. Prüfung: bestätigt)
  Format „dd.MM.yyyy | Titel“ gleich; Flutter ignoriert hide_name der Terminart (Ionic zeigt dann nur das Datum).
  Flutter: lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:41, lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:142
- [ ] **niedrig** `people/person/person.page` `field-31cb4e6e` [people/person/person.page.html:954](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L954)
  Ionic: Inline-Kalender im aufklappbaren Bereich, max = heute / Flutter: Datumsdialog beim Tipp, lastDate heute, frühestens vor 5 Jahren
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:131
- [ ] **niedrig** `people/person/person.page` `field-932fcf9d` [people/person/person.page.html:976](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L976)
  Ionic: Inline-Kalender im aufklappbaren Bereich, min = heute / Flutter: Datumsdialog, firstDate heute, bis +3 Jahre, Start +30 Tage
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:145
- [ ] **niedrig** `people/person/person.page` `action-35f05e9d` [people/person/person.page.html:1029](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1029) (2. Prüfung: bestätigt)
  Ionic: eigener Löschen-Button am „Von“-Datum (löscht nur Von) / Flutter: kein Button an „Von“, ein Button an „Bis“ löscht beide Daten (Datumsbereichs-Auswahl).
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:172
- [ ] **niedrig** `people/person/person.page` `field-3c608429` [people/person/person.page.html:1035](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1035)
  Ionic: zwei Inline-Kalender (Von/Bis) ohne Grenzen / Flutter: ein Zeitraum-Dialog (showDateRangePicker) für Von und Bis, Vorjahr bis +3 Jahre
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:96
- [ ] **niedrig** `people/person/person.page` `action-227003e4` [people/person/person.page.html:1051](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1051)
  Ionic: löscht nur „Bis“ / Flutter: löscht „Von“ und „Bis“
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:180
- [ ] **niedrig** `people/person/person.page` `field-e2731760` [people/person/person.page.html:1057](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1057)
  Ionic: Inline-Kalender, min = Von / Flutter: gemeinsamer Zeitraum-Dialog
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:96
- [ ] **niedrig** `people/person/person.page` `action-22e55c57` [people/person/person.page.html:1083](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1083)
  Ionic: X-Button in der Toolbar / Flutter: Textbutton „Abbrechen“
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1092
- [ ] **niedrig** `people/person/person.page` `field-03332121` [people/person/person.page.html:1092](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1092) (2. Prüfung: bestätigt)
  Ionic: natives Datumsfeld (type=date), keine Grenze / Flutter: Zeile mit Datum, Tipp öffnet Datumsauswahl, lastDate heute.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1063, lib/features/people/presentation/pages/person_detail_page.dart:1069
- [ ] **niedrig** `people/person/person.page` `text-b8f39c05` [people/person/person.page.html:1095](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1095)
  Ionic: Label „Notiz“ / Flutter: „Grund (optional)“ mit Hinweistext
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1084
- [ ] **niedrig** `people/person/person.page` `action-7114e66d` [people/person/person.page.html:1099](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1099) (2. Prüfung: bestätigt)
  Ionic: FAB mit Archiv-Icon / Flutter: roter Button „Archivieren“ im Dialog.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1093
- [ ] **niedrig** `people/person/person.page` `text-0f2b968d` [people/person/person.page.html:1112](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1112)
  Ionic: „Kopieren von {name}“/„Übertragen von {name}“ / Flutter: „Spieler kopieren“/„Spieler übertragen“
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:114
- [ ] **niedrig** `people/person/person.page` `action-cf8fa6af` [people/person/person.page.html:1141](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.html#L1141)
  Ionic: Button „Kopieren“/„Übertragen“, deaktiviert ohne Instanz/Gruppe / Flutter: Button „Kopieren“/„Übertragen“ des Massen-Sheets mit Fortschritt
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:200
- [ ] **niedrig** `teachers/teachers.page` `modal-81bd0046` [teachers/teachers.page.ts:67](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/teachers/teachers.page.ts#L67)
  Nur für Admin/Verantwortliche, übergibt den Lehrer (Schüler aus playersProvider). Ionic: iOS Karten-Modal (presentingElement), md Vollbild / Flutter: Vollbild-Dialog (fullscreenDialog) auf allen Plattformen; Liste wird danach neu geladen.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:135
- [ ] **niedrig** `teachers/teachers.page` `field-cfeef758` [teachers/teachers.page.html:41](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/teachers/teachers.page.html#L41)
  Label „Instrumente“, Gruppen ohne Hauptgruppe, Mehrfachauswahl. Ionic: ion-select interface=modal (Vollbild-Auswahlliste), Auswahl bleibt nach dem Anlegen für das nächste Öffnen erhalten (selInstruments) / Flutter: Dialog mit Checkboxen und „Abbrechen“/„OK“, Formular startet jedes Mal leer.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:385, lib/features/teachers/presentation/pages/teachers_list_page.dart:113
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `x-5b376c7a36` **Fehler beim Org-Feld-Speichern: zusätzlicher Toast** [src/app/services/organisation/organisation.service.ts:88-91](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/organisation/organisation.service.ts#L88-L91)
  Ionic: orgSvc.updatePersonFieldValues zeigt bei Fehler zusätzlich 'Fehler beim Speichern der gemeinsamen Zusatzfelder' (danger), danach 'Fehler beim Speichern' / Flutter: nur 'Fehler beim Speichern'.
  Flutter: lib/data/repositories/profile_repository.dart:281-319, lib/features/people/presentation/pages/bulk_edit_page.dart:240-243
- [ ] **niedrig** `people/import/import.page` `x-ab5b4f49ad` **Fehlergrund im Fehlerdialog technisch** [src/app/services/db.service.ts:3638-3640](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/db.service.ts#L3638-L3640)
  Ionic: reason = error.message ?? 'Unbekannter Fehler' / Flutter: '$e' inkl. Klassenname/Operation/Code (z. B. 'RepositoryException: … (operation: createPlayer, code: 23505)').
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:197-199
- [ ] **niedrig** `people/list/list.page` `x-dac55a9bd1` **Anwesenheits-Badge / Prozentbasis** [src/app/utilities/Utils.ts:129](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/utilities/Utils.ts#L129)
  Ionic: Personen ohne gezählte Termine zeigen roten '0%'-Badge; Basis ab seasonStart bzw. 2023-01-01 bis jetzt+24 h, für Nicht-Admins ohne archivierte Termine / Flutter: kein Badge, wenn keine gezählten Termine; Basis ab seasonStart (ohne Fallback) bis jetzt, archivierte Termine mitgezählt.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1629, lib/core/providers/attendance_providers.dart:286
- [ ] **niedrig** `people/list/list.page` `x-325647b4ef` **Reorder-Modus** [src/app/people/list/list.page.ts:324](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L324)
  Ionic: Griffe in der normalen Liste, kein Abbrechen, Overlay beim Speichern, schreibt nur Personen mit sort_order / Flutter: separate Kartenliste, zusätzliches X zum Verwerfen, kein Overlay, schreibt sort_order für alle gefilterten Personen aller Gruppen (mit tenantId).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:448, lib/features/people/presentation/pages/people_list_page.dart:1148, lib/features/people/presentation/pages/people_list_page.dart:1189, lib/data/repositories/player_repository.dart:1844
- [ ] **niedrig** `people/list/list.page` `x-f6927de895` **Auto-Entpausieren nur beim ersten Öffnen** [src/app/people/list/list.page.ts:140](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.ts#L140)
  Ionic: checkAndUnpausePlayers (Admin/Verantwortlicher) in jedem initializeData, also auch nach Instanzwechsel, vor dem Laden der Liste / Flutter: nur im initState per Post-Frame-Callback; ein Instanzwechsel bei offener Seite löst es nicht erneut aus.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:125, lib/features/people/presentation/pages/people_list_page.dart:128
- [ ] **niedrig** `people/list/list.page` `x-56b7f726f5` **Flutter-Zusatz: Personen übertragen** [src/app/people/list/list.page.html:166](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/list/list.page.html#L166)
  Ionic: kein Mehrfachauswahl-Modus in der Personenliste / Flutter: Optionsmenü-Eintrag 'Personen übertragen' (Admin/Verantwortlicher) mit Auswahlmodus, AppBar 'n ausgewählt' und Übergabe-Sheet.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:963, lib/features/people/presentation/pages/people_list_page.dart:651, lib/features/people/presentation/pages/people_list_page.dart:1255
- [ ] **niedrig** `people/members/members.page` `x-1730d62932` **Ladefehler inline statt Toast** [src/app/people/members/members.page.ts:72](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/members/members.page.ts#L72)
  Ionic: roter Toast und leere Liste / Flutter: Fehlertext inline, kein Toast.
  Flutter: lib/features/members/presentation/pages/members_page.dart:98
- [ ] **niedrig** `people/person/person.page` `x-78e8317eac` **Datenübernahme (E-Mail vergeben) ohne Passbild** [src/app/people/person/person.page.ts:813](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/person/person.page.ts#L813) (2. Prüfung: korrigiert)
  Zu hoch bewertet: Ionic speichert img beim Aktualisieren nie (pickPersonFields ohne img, db-helpers.ts:86) – das übernommene Passbild ist dort nur bis zum Schließen im Header sichtbar. Bleibt: fehlende Header-Vorschau; Ionic überschreibt otherExercise/range mit den Werten des Treffers auch wenn null (leert vorhandene Werte), Flutter nur wenn gesetzt (hier Flutter besser).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:866, lib/features/people/presentation/pages/person_detail_page.dart:873, lib/features/people/presentation/pages/person_detail_page.dart:874
- [ ] **niedrig** `duty/duty-assign-modal/duty-assign-modal.component` `x-9cfbd56a81` **Namens-Tiebreak nicht locale-aware** [src/app/duty/duty-assign-modal/duty-assign-modal.component.ts:41](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-assign-modal/duty-assign-modal.component.ts#L41)
  Ionic: bei gleicher Dienstanzahl a.name.localeCompare(b.name) (Umlaute bei Grundbuchstaben, Groß/Klein egal) / Flutter: a.name.compareTo(b.name) (Code-Unit-Reihenfolge, z. B. „Özil“ nach „Zoe“, Kleinbuchstaben nach Großbuchstaben).
  Flutter: lib/features/duty/presentation/widgets/duty_assign_sheet.dart:95
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-41b22d1e2d` **Speichern bei Fehler** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:236](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L236)
  Ionic: dutySvc.assign zeigt „Fehler beim Einteilen“ und wirft, die Schleife bricht beim ersten fehlerhaften Termin ab, übrige Termine werden nicht eingeteilt / Flutter: Fehler pro Termin abgefangen, alle übrigen Termine werden trotzdem eingeteilt, danach ein Toast „Fehler beim Einteilen“; Seite bleibt in beiden offen.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:277
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-3829883249` **Namens-Tiebreak nicht locale-aware** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:174](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L174)
  Ionic: „Dienste pro Person“ und Tausch-Optionen bei Gleichstand mit localeCompare sortiert / Flutter: String.compareTo (Umlaute nach Z, Kleinbuchstaben nach Großbuchstaben).
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:229, lib/features/duty/presentation/pages/duty_distribute_page.dart:469
- [ ] **niedrig** `duty/unavailability-modal/unavailability-modal.component` `x-1017c7460d` **Ladefehler der Regeln** [src/app/duty/unavailability-modal/unavailability-modal.component.ts:54](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/unavailability-modal/unavailability-modal.component.ts#L54)
  Ionic: Toast „Fehler beim Laden der Verfügbarkeit“, dann leere Liste mit „Noch keine Regel…“ und Button „Regel hinzufügen“ / Flutter: nur Text „Fehler: …“ im Body, kein Button „Regel hinzufügen“.
  Flutter: lib/features/duty/presentation/pages/unavailability_page.dart:233
- [ ] **niedrig** `duty/unavailability-modal/unavailability-modal.component` `x-21dc916f43` **Typnamen in der Regel-Liste** [src/app/duty/unavailability-modal/unavailability-modal.component.ts:62](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/duty/unavailability-modal/unavailability-modal.component.ts#L62)
  Ionic: typesText sucht nur in den sichtbaren Typen (visible !== false), unsichtbare Typen fehlen im Text / Flutter: Liste nutzt alle Typen, Namen unsichtbarer Typen erscheinen.
  Flutter: lib/features/duty/presentation/pages/unavailability_page.dart:230
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-d0c116c654` **Sortiermodus ohne Verschieben nummeriert neu** [src/app/instruments/instrument-list/instrument-list.page.ts:401](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L401)
  Ionic: Häkchen ohne Verschieben speichert nur vorhandene sort_order-Werte unverändert (null bleibt null) / Flutter: computeGlobalSortOrder vergibt beim Verlassen immer 1..n an alle Gruppen und schreibt sie (Badges ändern sich, Gruppen ohne sort_order bekommen eine).
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:49
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-353ca926f3` **Namens-Tiebreak der Kategorien** [src/app/instruments/instrument-list/instrument-list.page.ts:150](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument-list/instrument-list.page.ts#L150)
  Ionic: Kategorien ohne sort_order per localeCompare sortiert / Flutter: toLowerCase().compareTo (Umlaute nach Z).
  Flutter: lib/core/utils/instrument_sort.dart:79
- [ ] **niedrig** `instruments/instrument/instrument.page` `x-718f3b20d0` **Geschriebene Werte beim Aktualisieren** [src/app/instruments/instrument/instrument.page.ts:64](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/instruments/instrument/instrument.page.ts#L64)
  Ionic: schreibt notes, range, tuning, clefs, name, maingroup, category, synonyms so wie sie sind ('' bleibt '', versteckte Felder unverändert) / Flutter: trimmt, schreibt leere range/synonyms/notes als null, maingroup nicht, und schreibt tuning/clefs immer – bei Chor/Allgemein/Hauptgruppe (Felder versteckt) wird ein leerer Wert zu „C“ bzw. [g].
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:730
- [ ] **niedrig** `teachers/teachers.page` `x-791ebfa771` **Löschen von Lehrern nur in Flutter** [src/app/teachers/teachers.page.html:18](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/teachers/teachers.page.html#L18)
  Ionic: keine Löschfunktion für Lehrer / Flutter: Wischen nach links (Admin/Verantwortliche) → Dialog „Lehrer löschen“ / „Möchtest du "{Name}" wirklich löschen?“ mit „Abbrechen“/„Löschen“, löscht den Lehrer und zeigt „Lehrer gelöscht“ (auch wenn das Löschen fehlschlägt, da deleteTeacher den Fehler verschluckt).
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:172, lib/features/teachers/presentation/pages/teachers_list_page.dart:211
