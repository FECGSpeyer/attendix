# Fix-Paket „personen“

Soll: Ionic 4.19.9 (1923d203). Ist: Flutter 1aba6be, 2157fa0, b218510, 3bacc76, 8004a44, c9dd1aa, , b15b3b0, 40d2b43, da49473, 84c4c44, 6945c13, 3cdaaa1, a0550a4, 4e13f22, 2353b98, 00e183c, 57bb011, 0f74333, 3fe913c9, 2acb693, 5ddaa2a, 4de3564, 96b8284, 525a06f, ed511da, 359f15d, 43a315b, 0e6c255 (normales Design).
Erzeugt mit `node tool/parity/parity.mjs fixlists` aus `docs/parity/status/`. Item-IDs siehe `ionic-inventory.json`.

## Angleichen (hoch/mittel): 0


## Flutter besser – Leon entscheidet: 25

- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `action-7bb1a2ef` [duty/duty-distribute-modal/duty-distribute-modal.component.html:69](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L69) (2. Prüfung: bestätigt)
  Flutter besser: Ionic Plus bei 10 aktiv aber wirkungslos (Math.min 10) / Flutter Button bei 10 deaktiviert; Maximum 10 gleich. Gleicher Wert, rein optisch.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:413
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-09922adb` [instruments/instrument-list/instrument-list.page.html:152](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L152) (2. Prüfung: bestätigt)
  Flutter besser: Rolle gleich (FAB nur Admin/Verantwortlicher). Insert in instruments: name, maingroup false, category nur wenn gesetzt, tenantId, tuning „C“, clefs [g] (createGroup putIfAbsent) wie Ionic group.service addGroup; leerer Name → „Bitte gib einem Namen an“. Ionic speichert den Namen ungetrimmt (nur Leerzeichen wird angelegt) und prüft den Insert-Fehler nicht / Flutter trimmt, lehnt Leerzeichen-Namen ab und zeigt bei Fehler „Fehler beim Hinzufügen“ (x-5824d283fc). f-Zeilen aktualisiert.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:429, lib/features/instruments/presentation/pages/instruments_list_page.dart:374, lib/features/instruments/presentation/pages/instruments_list_page.dart:349, lib/data/repositories/group_repository.dart:94
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `action-5c670508` [people/bulk-edit/bulk-edit.page.html:5](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L5) (2. Prüfung: bestätigt)
  Flutter besser: Ionic: X schließt das Modal immer, auch während Speichern / Flutter: X während _isSaving deaktiviert.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:271-274
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-3f70cbe7` [people/bulk-edit/bulk-edit.page.html:16](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L16) (2. Prüfung: bestätigt)
  Flutter besser: Label, Platzhalter, „Standard-Felder“/„Zusatzfelder“ und Optionen gleich. Ionic zeigt Zusatzfelder nur wenn db.tenant().additional_fields nicht leer (Organisationsfelder fehlen sonst) / Flutter sobald irgendein Zusatzfeld (Org oder Instanz) existiert.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:285-325
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-4964deb8-2` [people/bulk-edit/bulk-edit.page.html:135](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L135) (2. Prüfung: bestätigt)
  Flutter besser: Ionic: (ionChange) liefert bei ion-input einen String (laut Ionic-Core; @ionic/angular nicht im Container geprüft), Zusatzfeld wird evtl. als "5" gespeichert / Flutter: speichert num (Komma erlaubt), leer → null. Zahl-Tastatur gleich. Ionic übernimmt bei Blur, Flutter bei jedem Tastendruck.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:534-539, lib/features/people/presentation/pages/bulk_edit_page.dart:478-482
- [ ] **niedrig** `people/list/list.page` `toast-9a849d38` [people/list/list.page.ts:390](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L390) (2. Prüfung: bestätigt)
  Flutter besser: Ionic prüft {error} der Updates nicht und meldet praktisch immer 'Reihenfolge gespeichert'; Flutter zeigt bei Fehlschlag roten Toast 'Fehler beim Speichern der Reihenfolge'. Flutter schreibt sort_order nur für verschobene Gruppen (mit tenantId-Filter), Ionic für alle Personen mit sort_order (ohne tenantId).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1239, lib/data/repositories/player_repository.dart:1884
- [ ] **niedrig** `people/list/list.page` `alert-eeaa4fb8` [people/list/list.page.ts:489](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L489) (2. Prüfung: bestätigt)
  Flutter besser: Für Zahlenfelder der Instanz gleich (Titel = Feldname, Zahlenfeld „Wert eingeben“, „Abbrechen“ → Alle, „Filtern“, leer → Alle; alle Rollen der Personenliste). Ionic öffnet den Alert nur für tenant().additional_fields, ein Org-Zahlenfeld im Filter filtert nicht (alle Personen, Icon farbig) / Flutter: Dialog und Filter auch für Org-Felder. Vorbelegung: Ionic letzter gespeicherter Zusatzwert, Flutter nur bei gleichem aktivem Filter. Personen ohne Wert treffen jetzt in beiden „0“ (withExtraFieldDefaults).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1059, lib/features/people/presentation/pages/people_list_page.dart:1062, lib/features/people/presentation/pages/people_list_page.dart:1077, lib/features/people/presentation/pages/people_list_page.dart:1116, lib/features/people/presentation/pages/people_list_page.dart:305, lib/core/providers/profile_providers.dart:67
- [ ] **niedrig** `people/list/list.page` `alert-86b4fbec` [people/list/list.page.ts:909](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L909) (2. Prüfung: bestätigt)
  Flutter besser: Titel, Text, Checkboxen (Instanzname), „Überspringen“/„Pausieren“ gleich; Ionic bietet alle verknüpften Instanzen an, in denen die Person (nicht als Beobachter) Mitglied ist, Flutter nur jene, in denen der angemeldete Nutzer Admin/Verantwortlicher ist. In den übrigen bewirkt Ionics Update wegen RLS (admins_manage_player) nichts. Flutter hängt den Eintrag an die eigene Historie der anderen Instanz an statt sie mit der Quell-Historie zu überschreiben.
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:235, lib/features/people/presentation/widgets/pause_person_sheet.dart:240, lib/features/people/presentation/widgets/pause_person_sheet.dart:288, lib/data/repositories/cross_tenant_person_repository.dart:360
- [ ] **niedrig** `people/list/list.page` `field-27abe29e` [people/list/list.page.html:58](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L58) (2. Prüfung: bestätigt)
  Flutter besser: Platzhalter "Person suchen..." und Suchfelder (Vor-/Nachname, Gruppe, Text-/Zahl-Zusatzfelder) gleich; Ionic verwirft bei Suche den Filter und die Sortierung, Flutter kombiniert Suche, Filter und Sortierung.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:564, lib/features/people/presentation/pages/people_list_page.dart:322, lib/features/people/people_list_utils.dart:8
- [ ] **niedrig** `people/list/list.page` `action-de48c2e0` [people/list/list.page.html:451](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L451) (2. Prüfung: bestätigt)
  Flutter besser: Ionic clearFilters leert nur filterOptAdd und zeigt alle Personen; Filterauswahl und Suchtext bleiben stehen / Flutter setzt Filter auf "Alle Anzeigen", leert Suche und speichert. Leon entscheidet.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:634, lib/features/people/presentation/pages/people_list_page.dart:1308
- [ ] **niedrig** `people/person/person.page` `alert-01934766` [people/person/person.page.ts:1343](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1343) (2. Prüfung: korrigiert)
  Flutter besser: Titel 'Kopieren/Übertragen nicht möglich', Text mit Instanz und E-Mail bzw. Name, 'OK' gleich. Ionic prüft keine Rechte in der Zielinstanz und zeigt den Hinweis für jede eigene Ziel-Rolle / Flutter prüft vorher canEdit in der Zielinstanz und zeigt sonst den roten Toast 'Keine Berechtigung in der Ziel-Instanz' statt des Hinweises (Ionic-Übertragung scheitert dann später). Andere Ziel-Instanzliste: field-0a2daf88.
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:723, lib/features/people/presentation/widgets/handover_sheet.dart:763
- [ ] **niedrig** `teachers/teachers.page` `field-8a21ddb5` [teachers/teachers.page.html:49](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teachers/teachers.page.html#L49) (2. Prüfung: bestätigt)
  Flutter besser: Ionic: addTeacher bekommt private.value der ion-toggle (Formularwert, standardmäßig „on“), pri === 'true' ist nie wahr → neue Lehrer immer private=false / Flutter speichert den Schalterzustand. Leon entscheidet, ob so bleiben soll.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:362, lib/data/repositories/teacher_repository.dart:57
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `x-a485e4b055` **Zusatzfelder-Abschnitt Sichtbarkeit** [src/app/people/bulk-edit/bulk-edit.page.html:24](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L24) (2. Prüfung: bestätigt)
  Flutter besser: Ionic zeigt die Zusatzfelder (inkl. Org-Felder) im Feld-Auswahlmenü nur, wenn die Instanz selbst additional_fields hat / Flutter: immer, wenn Org- oder Instanz-Felder existieren. Admin/Verantwortlich kann diese Felder ohnehin pro Person bearbeiten; kein Rechtezuwachs.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:258, lib/features/people/presentation/pages/bulk_edit_page.dart:309, lib/features/people/presentation/pages/bulk_edit_page.dart:320
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `x-1aab272cf3` **Zahlen-Zusatzfeld pro Person als String** [src/app/people/bulk-edit/bulk-edit.page.html:135-138](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L135-L138) (2. Prüfung: bestätigt)
  Flutter besser: Ionic speichert Einzelwerte eines Zahlenfeldes aus ionChange als String ("5"), Sammelwert und Personenseite (NumericValueAccessor) als Zahl / Flutter immer Zahl oder null. Der JSON-Typ in additional_fields weicht nur vom Ionic-Fehlerpfad ab (Ionic schreibt sonst selbst Zahlen); Filter/Suche vergleichen per String(), Anzeige gleich. Leon entscheidet.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:478, lib/features/people/presentation/pages/bulk_edit_page.dart:481, lib/features/people/presentation/pages/bulk_edit_page.dart:534
- [ ] **niedrig** `people/list/list.page` `x-5d4cb428e1` **Flutter besser: Suche/Filter/Sortierung kombiniert** [src/app/people/list/list.page.ts:714](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L714) (2. Prüfung: bestätigt)
  Flutter besser: Ionic search() setzt auf alle Personen zurück (aktiver Filter verloren) und onFilterChanged sortiert nach Gruppe trotz anderer Sortierung; gespeicherter Filter wird beim Laden nur bei Sortierung 'Gruppe' angewendet / Flutter: _filterPeople (Filter + Suche) und _sortPeople werden immer kombiniert angewendet, gespeicherter Filter immer.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:262, lib/features/people/presentation/pages/people_list_page.dart:352, lib/features/people/presentation/pages/people_list_page.dart:155
- [ ] **niedrig** `people/list/list.page` `x-c1c5493cd5` **Flutter besser: schmalere Pausen-Schreibvorgänge** [src/app/services/db.service.ts:2219](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/db.service.ts#L2219) (2. Prüfung: bestätigt)
  Flutter besser: Ionic schreibt beim Pausieren/Aktivieren per updatePlayer den ganzen Listen-Datensatz (inkl. mit Defaults aufgefüllter additional_fields) und überschreibt in anderen Instanzen deren Historie mit der Quell-Historie / Flutter schreibt nur paused, paused_until, history (id + tenantId) und hängt in anderen Instanzen den Eintrag an deren eigene Historie an. Sichtbares Ergebnis (pausiert/aktiv, Historieneintrag, Terminlisten) gleich.
  Flutter: lib/data/repositories/player_repository.dart:837, lib/data/repositories/player_repository.dart:882, lib/data/repositories/cross_tenant_person_repository.dart:288
- [ ] **niedrig** `people/person/person.page` `x-5c4108ee61` **Pausieren in anderen Instanzen: Historie** [src/app/people/person/person.page.ts:1453](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1453) (2. Prüfung: bestätigt)
  Flutter besser: weiterhin – Ionic überschreibt die Historie der Person in der anderen Instanz mit der kompletten Historie dieser Instanz (pausePlayerInOtherTenant(..., history)) / Flutter liest die Historie dort und hängt nur den Pausiert-Eintrag an. Nebenbei: Flutter bietet nur Instanzen an, in denen der Nutzer Admin/Verantwortlich ist (Ionic alle Instanzen der Person, Schreiben dort scheitert sonst an RLS).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:251, lib/features/people/presentation/widgets/pause_person_sheet.dart:264, lib/data/repositories/cross_tenant_person_repository.dart:322
- [ ] **niedrig** `people/person/person.page` `x-e0dc1b2b62` **Verspätungszähler zurücksetzen schreibt nur lastSolve** [src/app/people/person/person.page.ts:396](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L396) (2. Prüfung: bestätigt)
  Flutter besser: weiterhin – Ionic resetLateCount speichert den ganzen Spieler (db.updatePlayer(this.player)) inkl. noch ungespeicherter Formularänderungen / Flutter schreibt nur lastSolve (id + tenantId), ungespeicherte Änderungen bleiben im Entwurf.
  Flutter: lib/data/repositories/player_repository.dart:1424, lib/features/people/presentation/pages/person_detail_page.dart:1343
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-d3edffbcbe` **Gleicher-Tag-Sperre zählt mehr Termine** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:111](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L111) (2. Prüfung: bestätigt)
  Flutter besser, weiter real: Flutter lädt alle Dienst-Typen und gibt voll besetzte sowie nicht gewählte Termine mit open 0 mit, deren Eingeteilte blockieren bei „Nicht zweimal am selben Tag“ den Tag; Ionic filtert sie vorher heraus. Vorschlag kann abweichen, Vorschau bleibt änderbar.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:124, lib/features/duty/presentation/pages/duty_distribute_page.dart:174
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-9bddce3977` **Ladefehler beim Berechnen** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:79](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L79) (2. Prüfung: bestätigt)
  Flutter besser, weiter real: Ionic verschluckt Ladefehler (getUpcomingDutyTermine → [], getDutyCounts → leere Map) und zeigt „Im Zeitraum gibt es keine Termine mit Dienst-Modus.“ bzw. verteilt ohne Basiszählung; Flutter zeigt roten Toast „Fehler: …“ und bleibt im Regeln-Schritt.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:146
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-a43d5a3f61` **Pull-to-Refresh nur in Flutter** [src/app/instruments/instrument-list/instrument-list.page.html:70](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L70) (2. Prüfung: bestätigt)
  Flutter besser: Ionic kein ion-refresher auf der Gruppenliste / Flutter: onRefresh lädt Gruppen, Kategorien und Personenanzahlen neu.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:85, lib/features/instruments/presentation/pages/instruments_list_page.dart:120
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-5824d283fc` **Fehler beim Hinzufügen einer Gruppe** [src/app/instruments/instrument-list/instrument-list.page.ts:178](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L178) (2. Prüfung: bestätigt)
  Flutter besser: Ionic groupSvc.addGroup prüft den Insert-Fehler nicht, Sheet schließt ohne Meldung / Flutter: createGroup → null, Sheet schließt, roter Toast „Fehler beim Hinzufügen“. f-Zeile aktualisiert.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:349
- [ ] **niedrig** `teachers/teachers.page` `x-42f2057e70` **Pull-to-Refresh nur in Flutter** [src/app/teachers/teachers.page.html:10](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teachers/teachers.page.html#L10) (2. Prüfung: bestätigt)
  Flutter besser: Ionic: kein ion-refresher / Flutter: IonPage onRefresh lädt Lehrer, Schüleranzahlen und Liste neu. Weiter vorhanden.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:48-59
- [ ] **niedrig** `teachers/teachers.page` `x-c00bd9fd3a` **Gelöschte Gruppe in Lehrer-Instrumenten** [src/app/teachers/teachers.page.ts:41](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teachers/teachers.page.ts#L41)
  Flutter besser: Ionic: getTeachers liest .name einer nicht mehr existierenden Gruppe → TypeError, die Lehrerliste bleibt leer / Flutter: unbekannte Gruppen-IDs werden übersprungen.
  Flutter: lib/core/providers/teacher_providers.dart:75
- [ ] **niedrig** `people/person/person.page` `x-4b8b68cee9` **Neu-Seite: zusätzliche Duplikat-Rückfrage** [src/app/people/person/person.page.ts:525](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L525) (2. Prüfung: bestätigt)
  Flutter besser: weiterhin – Ionic addPerson legt ohne Namensprüfung an / Flutter fragt bei gleichem Vor- und Nachnamen (ilike, Instanz inkl. archivierter/ausstehender, tenantId-Filter) „Mögliches Duplikat“ – „Eine Person mit dem Namen "{name}" existiert bereits ({count}x). Trotzdem erstellen?“ mit Abbrechen/„Trotzdem erstellen“.
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:962, lib/features/people/presentation/pages/person_create_page.dart:966, lib/data/repositories/player_repository.dart:302

## Kleinigkeiten (niedrig): 147

- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `loading-e612daf1` [duty/duty-distribute-modal/duty-distribute-modal.component.ts:77](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L77) (2. Prüfung: bestätigt)
  Weiter so: Ionic blockierendes Overlay „Verteile Dienste…“ / Flutter ersetzt den Body durch Spinner mit gleichem Text, das X in der AppBar bleibt bedienbar. Nur Ladeanzeige.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:319, lib/features/duty/presentation/pages/duty_distribute_page.dart:305
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `loading-ef16b6da` [duty/duty-distribute-modal/duty-distribute-modal.component.ts:232](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L232) (2. Prüfung: bestätigt)
  Weiter so: Ionic blockierendes Overlay „Teile ein…“ / Flutter Body-Spinner mit gleichem Text, Speichern-Button deaktiviert, „Zurück“ und „Neu verteilen“ bleiben während des Speicherns bedienbar (Speicherschleife läuft über die alte Zeilenliste weiter). Nur Ladeanzeige.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:319, lib/features/duty/presentation/pages/duty_distribute_page.dart:340, lib/features/duty/presentation/pages/duty_distribute_page.dart:299, lib/features/duty/presentation/pages/duty_distribute_page.dart:311
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-b28d8f3e` [duty/duty-distribute-modal/duty-distribute-modal.component.html:29](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L29) (2. Prüfung: bestätigt)
  Anzeigeformat des Von-Datums (Ionic Intl-Kurzformat / Flutter dateFmt()); Startwert Monatsanfang Folgemonat gleich. Nur Optik.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:366, lib/features/duty/presentation/pages/duty_distribute_page.dart:86
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-71fefb63` [duty/duty-distribute-modal/duty-distribute-modal.component.html:32](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L32) (2. Prüfung: bestätigt)
  Ionic: Kalender mit „Fertig“/„Abbrechen“, Wert erst nach „Fertig“ / Flutter: Plattform-Datumsdialog (OK/Abbrechen bzw. iOS-Look), Bereich 2020–2100. Gleiche Funktion, nur Optik.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:96
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-b28d8f3e-2` [duty/duty-distribute-modal/duty-distribute-modal.component.html:39](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L39) (2. Prüfung: bestätigt)
  Anzeigeformat des Bis-Datums (Ionic Intl-Kurzformat / Flutter dateFmt()); Startwert Monatsende Folgemonat gleich. Nur Optik.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:370, lib/features/duty/presentation/pages/duty_distribute_page.dart:86
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `field-bca25190` [duty/duty-distribute-modal/duty-distribute-modal.component.html:42](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L42) (2. Prüfung: bestätigt)
  Ionic: Kalender mit „Fertig“/„Abbrechen“ / Flutter: Plattform-Datumsdialog, Bereich 2020–2100. Gleiche Funktion, nur Optik.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:96
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `text-e73248fa` [duty/duty-distribute-modal/duty-distribute-modal.component.html:96](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.html#L96) (2. Prüfung: bestätigt)
  Ionic: dayjs „dd, DD.MM. · HH:mm“ (mit führender Null, sprachabhängiges dayMonth-Format) / Flutter: „Mo, 3.2. · 19:00“ ohne führende Null. Gleiche Information, nur Format.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:88
- [ ] **niedrig** `duty/unavailability-modal/unavailability-modal.component` `field-bb90d03c` [duty/unavailability-modal/unavailability-modal.component.html:57](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/unavailability-modal/unavailability-modal.component.html#L57) (2. Prüfung: bestätigt)
  Ionic: natives Datumsfeld, leer = unbefristet / Flutter: Zeile „Gültig bis (optional)“ mit Plattform-Datumsdialog und Löschen-X, zeigt „unbefristet“; gleicher gespeicherter Wert (YYYY-MM-DD bzw. null). Nur Optik.
  Flutter: lib/features/duty/presentation/pages/unavailability_page.dart:354, lib/features/duty/presentation/pages/unavailability_page.dart:170
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `modal-1bead9c9` [instruments/instrument-list/instrument-list.page.ts:159](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L159) (2. Prüfung: bestätigt)
  Nur für Admin/Verantwortliche (onEdit null sonst; im Sortiermodus kein Öffnen wie Ionic), übergibt die Gruppe (plus Kategorien, Tenant-Typ). Ionic: iOS Karten-Modal (presentingElement), md Vollbild / Flutter: Vollbild-Dialog (fullscreenDialog) überall. Neuladen nach Speichern/Löschen in beiden (Notifier invalidiert groupsProvider, Seite die Personenanzahl). f-Zeile aktualisiert.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:447, lib/features/instruments/presentation/pages/instruments_list_page.dart:156
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `alert-eeb83d29` [instruments/instrument-list/instrument-list.page.ts:191](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L191) (2. Prüfung: bestätigt)
  Gleiche Eingabe/Buttons/Anlegen; Flutter trimmt Namen, Label statt Placeholder; zusätzlich Fehlertoast. Nur Look.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:260
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `alert-415386f9` [instruments/instrument-list/instrument-list.page.ts:223](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L223) (2. Prüfung: bestätigt)
  Titel „Bestätigen“, Text „Kategorie wirklich löschen?…“, „Abbrechen“/„Ja“, löscht. Nur Look: Ionic Abbrechen role destructive, Flutter „Ja“ rot. Flutter besser: zeigt Fehlertoast bei Löschfehler.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:354
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `alert-bd4338b7` [instruments/instrument-list/instrument-list.page.ts:249](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L249) (2. Prüfung: bestätigt)
  Gleiche Eingabe/Buttons/Speichern; Flutter trimmt Namen, schwebendes Label statt Placeholder; Leerer Name → Toast. Nur Look.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:305
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `loading-c2ec3077` [instruments/instrument-list/instrument-list.page.ts:314](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L314) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay / Flutter: nur LinearProgressIndicator im Sheet-Kopf; Speichern der Kategorien- und Instrumentenreihenfolge + Toasts vorhanden.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:135, lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:55
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `loading-7d7ff756` [instruments/instrument-list/instrument-list.page.ts:396](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L396) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay „Reihenfolge wird gespeichert...“ / Flutter: kein Overlay; Speichern + Erfolg/Fehlertoast funktionieren (groupNotifier.saveGroupOrder). Reine Darstellung.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:55
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-3f2a74e6` [instruments/instrument-list/instrument-list.page.html:23](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L23) (2. Prüfung: bestätigt)
  Besteht weiter: Ionic Plus-Button auch im Sortiermodus / Flutter blendet ihn im Sortiermodus aus (if (!_isReordering)). Dialog „Neue Kategorie“ (Kategoriename, Abbrechen/Hinzufügen, leer → Toast, Dialog bleibt offen), Insert group_categories name+tenant_id, Fehler-Toast wie Ionic; Flutter trimmt den Namen (Flutter besser).
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:122, lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:260
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `text-49ad7035` [instruments/instrument-list/instrument-list.page.html:33](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L33) (2. Prüfung: bestätigt)
  Gleicher Text „Ziehe die Kategorien, um die Reihenfolge anzupassen. …“ nur im Sortiermodus. Ionic: ion-item mit primary-Hintergrund und weißem Info-Icon / Flutter: normale ListTile mit primary-farbenem Info-Icon.
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:191
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-a01ef8cf` [instruments/instrument-list/instrument-list.page.html:38](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L38) (2. Prüfung: bestätigt)
  Sortieren per Ziehen und Speichern beim Häkchen wie Ionic. Ionic: Zeile mit Griff-Icon im Sortiermodus und Badge der gespeicherten sort_order (immer) / Flutter: Karten; außerhalb des Sortiermodus Kategorie-Icon statt sort_order-Badge, im Sortiermodus Positionsnummer im Kreis, Ziehen per Long-Press (Standard-Griff). Reihenfolge selbst sichtbar → niedrig. f-Zeile korrigiert (384 → 400).
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:197, lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:400
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `action-623e8e94` [instruments/instrument-list/instrument-list.page.html:51](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L51) (2. Prüfung: bestätigt)
  Nur im Kategorien-Sheet (Admin/Verantwortliche), nur außerhalb des Sortiermodus; öffnet „Kategorie bearbeiten“ mit Name vorbefüllt, Abbrechen/Speichern, leer → Toast, Update name mit id + tenant_id, Fehler-Toast wie Ionic. Ionic: Stift-Icon orange (warning) / Flutter: Icons.edit in Standardfarbe. f-Zeile korrigiert (392 → 408).
  Flutter: lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:408, lib/features/instruments/presentation/widgets/instrument_categories_sheet.dart:305
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `text-1d015e65` [instruments/instrument-list/instrument-list.page.html:89](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.html#L89) (2. Prüfung: bestätigt)
  Text „Kategorie (n)“ gleich. Ionic: sticky Divider / Flutter: scrollt mit. Nur Look.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:254
- [ ] **niedrig** `instruments/instrument/instrument.page` `loading-2112917a` [instruments/instrument/instrument.page.ts:43](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.ts#L43) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay „Synonyme werden generiert...“ / Flutter: Spinner im Synonymfeld statt Funken-Button, kein Text, Seite bedienbar.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:683-694
- [ ] **niedrig** `instruments/instrument/instrument.page` `toast-283b4da3` [instruments/instrument/instrument.page.ts:60](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.ts#L60) (2. Prüfung: bestätigt)
  Gleicher Text „Bitte gib einen Namen an!“, Speichern wird abgebrochen. Ionic: roter Toast / Flutter: Validierungstext am Feld; Flutter trimmt (nur Leerzeichen = leer).
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:604-609
- [ ] **niedrig** `instruments/instrument/instrument.page` `alert-cb09ce26` [instruments/instrument/instrument.page.ts:88](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.ts#L88) (2. Prüfung: bestätigt)
  Titel „Bestätigen“, Text „Gruppe wirklich löschen?“, Abbrechen/Ja, Ja löscht (deleteGroup) und schließt. Ionic: „Abbrechen“ role destructive (nur iOS rot) / Flutter beide neutral. Gleiche Auswahl und Wirkung.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:779-806
- [ ] **niedrig** `instruments/instrument/instrument.page` `text-60ebf1b1` [instruments/instrument/instrument.page.html:4](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.html#L4) (2. Prüfung: bestätigt)
  Ionic: Titel an instrument.name gebunden (ändert sich beim Tippen) / Flutter: fester Titel mit ursprünglichem Namen.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:585
- [ ] **niedrig** `instruments/instrument/instrument.page` `field-679fa215` [instruments/instrument/instrument.page.html:42](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.html#L42) (2. Prüfung: bestätigt)
  Stimmung C/Es/B/F, gleiche Sichtbarkeit. Ionic: Popover, leerer Wert bleibt leer / Flutter: Dropdown, leerer Wert wird als „C“ angezeigt und beim Speichern „C“. Neue Gruppen haben in Ionic immer tuning „C“ (group.service:39), leer nur bei Altdaten → Randfall, niedrig.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:628-639
- [ ] **niedrig** `instruments/instrument/instrument.page` `field-ae69e131` [instruments/instrument/instrument.page.html:66](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument/instrument.page.html#L66) (2. Prüfung: bestätigt)
  Violin-/Bass-/Altschlüssel Mehrfachauswahl. Ionic: Popover, alle abwählbar (leeres Array möglich), Label „Stimmung“ / Flutter: FilterChips „Notenschlüssel“, mindestens einer bleibt gewählt. Neue Gruppen haben immer [g]; niedrig.
  Flutter: lib/features/instruments/presentation/pages/instruments_list_page.dart:646-672
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-9dd7902a` [people/bulk-edit/bulk-edit.page.html:53](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L53) (2. Prüfung: bestätigt)
  Ionic: Sammel-Toggle mit Beschriftung „Stimmführer“ / Flutter: nur Switch ohne Text (Feld steht bereits im Dropdown). Startwert false in beiden.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:517-521
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-d2bdf3b7` [people/bulk-edit/bulk-edit.page.html:73](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L73) (2. Prüfung: bestätigt)
  Ionic: ion-textarea mit autoGrow (mehrzeilig) / Flutter: einzeiliges Textfeld, Zeilenumbrüche im Sammelwert nicht eingebbar. Startwert jetzt gleich (). 
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:585-586, lib/features/people/presentation/pages/bulk_edit_page.dart:129-136
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-523de84f-3` [people/bulk-edit/bulk-edit.page.html:81](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L81) (2. Prüfung: bestätigt)
  Startwert jetzt gleich (heutiges Datum als ISO, „Für alle setzen“ schreibt es wie Ionic). Ionic: natives Datumsfeld, zeigt den ISO-Startwert nicht an, leerbar / Flutter: Button zeigt das Datum, nicht leerbar.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:564-584, lib/features/people/presentation/pages/bulk_edit_page.dart:129-136
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `field-4964deb8-4` [people/bulk-edit/bulk-edit.page.html:165](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L165) (2. Prüfung: bestätigt)
  Ionic: natives input type=date (Wert leerbar) / Flutter: Button mit Datumsdialog, zeigt „Kein Datum gewählt“ bzw. Datum; Wert nicht leerbar. Format yyyy-MM-dd gleich.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:564-584
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `action-a2a2fcd3` [people/bulk-edit/bulk-edit.page.html:176](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/bulk-edit/bulk-edit.page.html#L176) (2. Prüfung: bestätigt)
  Texte „Speichern...“ / „# Änderung(en) speichern“ / „Keine Änderungen“ und Deaktivierung (changedCount==0 oder isSaving) gleich. Ionic: Spinner vor „Speichern...“ / Flutter: nur Text. Schreiben: player-Update mit id+tenantId-Filter, Extrafelder wie Ionic (Org-Felder in Shared-Tabelle), Demo-Sperre, Attendance-Sync: gleich.
  Flutter: lib/features/people/presentation/pages/bulk_edit_page.dart:428-443
- [ ] **niedrig** `people/import/import.page` `loading-3194637c` [people/import/import.page.ts:97](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.ts#L97) (2. Prüfung: bestätigt)
  Flutter blockiert mit Overlay (Spinner), aber ohne Text „Datei wird gelesen...“ (peopleReadingFile ungenutzt).
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:95-121, lib/features/people/presentation/pages/person_import_page.dart:319-341
- [ ] **niedrig** `people/import/import.page` `loading-b32cfbfa` [people/import/import.page.ts:135](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.ts#L135) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay „Daten werden geprüft...“ / Flutter: Overlay nur Spinner (peopleCheckingData ungenutzt); „Zurück“ in der Leiste bleibt bedienbar.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:170-182, lib/features/people/presentation/pages/person_import_page.dart:319-341
- [ ] **niedrig** `people/import/import.page` `loading-bab0752f` [people/import/import.page.ts:213](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.ts#L213) (2. Prüfung: bestätigt)
  Fortschritt „{done} / {total} importiert...“ wird angezeigt und hochgezählt; Ionic blockiert den ganzen Bildschirm / Flutter: Overlay nur über dem Inhalt, Schließen-X gesperrt, aber „Zurück“ in der unteren Leiste bleibt während des Imports bedienbar (Import läuft weiter).
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:213, lib/features/people/presentation/pages/person_import_page.dart:254, lib/features/people/presentation/pages/person_import_page.dart:319, lib/features/people/presentation/pages/person_import_page.dart:351
- [ ] **niedrig** `people/import/import.page` `alert-3b9d1c7b` [people/import/import.page.ts:254](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.ts#L254) (2. Prüfung: bestätigt)
  Titel „Nicht importierte Personen“, max. 10 Zeilen „• Vorname Nachname: Grund“, „… und N weitere“, Button „OK“ gleich. Grund: Ionic error.message / Flutter „$e“ (kann technischen Präfix wie „RepositoryException:“ enthalten); Information bleibt erhalten.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:273, lib/features/people/presentation/pages/person_import_page.dart:250-251, lib/features/people/presentation/widgets/import_widgets.dart:226-243
- [ ] **niedrig** `people/import/import.page` `effect-31a0aedd` [people/import/import.page.ts:275](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.ts#L275) (2. Prüfung: korrigiert)
  hoch-Lücke behoben (#325): nativ (auch iPad) Datei im Cache + Systemviewer (OpenFilex) wie Ionic, kein Teilen-Popover mehr; Vorlage mit Org- und Instanz-Zusatzfeldern, Name/Blatt/Kopf/Beispiel gleich. Rest niedrig: mobiler Browser bekommt einen Anker-Download (printing sharePdf, Blob-Typ application/pdf) statt des Web-Share-Sheets (Ionic downloadFileNative); auf iPhone-Safari/PWA prüfen – lässt sich die .xlsx dort nicht speichern, wäre es mittel.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:137, lib/core/services/native/native_file_service.dart:167, lib/core/services/native/native_file_io.dart:14
- [ ] **niedrig** `people/import/import.page` `text-da6273ad` [people/import/import.page.html:16](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.html#L16) (2. Prüfung: bestätigt)
  Text gleich. Ionic: grau (.intro medium) / Flutter: normale Textfarbe. Frühere Notiz zu .xls ist überholt: Flutter-Picker und Reader unterstützen .xlsx/.xls/.csv (import_file_io.dart:13).
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:302, lib/features/people/presentation/widgets/import_widgets.dart:30
- [ ] **niedrig** `people/import/import.page` `text-ac3c014f` [people/import/import.page.html:37](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.html#L37)
  '— N Zeilen' gleich. Ionic: grau (medium) / Flutter: normale Textfarbe.
  Flutter: lib/features/people/presentation/widgets/import_widgets.dart:85-88
- [ ] **niedrig** `people/import/import.page` `text-432acf42` [people/import/import.page.html:37](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.html#L37)
  Dateiname fett gleich. Ionic: grau (medium) / Flutter: normale Textfarbe.
  Flutter: lib/features/people/presentation/widgets/import_widgets.dart:86
- [ ] **niedrig** `people/import/import.page` `text-9a34d1ef` [people/import/import.page.html:38](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.html#L38)
  Text gleich. Ionic: grau (medium, 0.9rem) / Flutter: normale Textfarbe.
  Flutter: lib/features/people/presentation/widgets/import_widgets.dart:90
- [ ] **niedrig** `people/import/import.page` `field-018f6a18` [people/import/import.page.html:102](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/import/import.page.html#L102) (2. Prüfung: bestätigt)
  Gruppen-Dropdown je Zeile (nicht bei Fehlerzeilen), Auswahl setzt groupResolved, gleich. Ionic: Label „Gruppe“ immer über dem Wert, ungeklärte Gruppe mit orangem Rahmen / Flutter: „Gruppe“ nur als Hinweis bei leerem Wert, ungeklärte Gruppe als orange Schrift.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:423-445
- [ ] **niedrig** `people/list/list.page` `loading-a2fa55fe` [people/list/list.page.ts:97](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L97)
  Ionic: blockierendes Loading-Overlay (ohne Text, 3 s) beim Instanzwechsel über das Header-Popover / Flutter: switchTenant ohne Overlay.
  Flutter: lib/shared/widgets/tenant/tenant_switcher_title.dart:389
- [ ] **niedrig** `people/list/list.page` `loading-275de79e` [people/list/list.page.ts:377](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L377) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay "Reihenfolge wird gespeichert..." / Flutter: Spinner im Häkchen-Button (Button gesperrt), Fehler/Erfolg-Toast wie Ionic.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:516, lib/features/people/presentation/pages/people_list_page.dart:1232
- [ ] **niedrig** `people/list/list.page` `alert-0eb34b23` [people/list/list.page.ts:437](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L437) (2. Prüfung: bestätigt)
  Ionic: Alert „Instanz wählen“ mit Radio-Liste (nichts vorausgewählt – `selected` kennt ion-alert nicht), „Abbrechen“ → Filter „Alle“, „Filtern“ ohne Auswahl → „Alle“ / Flutter: Auswahl-Dialog „Instanz wählen“ ohne Buttons, Tipp filtert sofort, Schließen lässt den bisherigen Filter stehen. Gefilterte Daten gleich (Nicht-Beobachter-Konten der Instanz).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1144, lib/features/people/presentation/pages/people_list_page.dart:1152, lib/features/people/presentation/pages/people_list_page.dart:1165, lib/features/people/presentation/pages/people_list_page.dart:1168
- [ ] **niedrig** `people/list/list.page` `alert-1081984d` [people/list/list.page.ts:538](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L538) (2. Prüfung: korrigiert)
  Erstprüfer-Unterschied behoben: Flutter zeigt jetzt wie Ionic einen Radio-Alert (Titel = Feldname, „Ja“ vorausgewählt bzw. „Nein“ bei gespeichertem Nein, „Abbrechen“ → Alle, „Filtern“), Leerwerte = Default true. Rest: Flutter besser: Ionic öffnet den Alert nur für Ja/Nein-Felder der Instanz (tenant().additional_fields), ein Org-Ja/Nein-Feld im Filter filtert gar nicht (alle Personen) / Flutter: Dialog und Filter auch für Org-Felder. Backdrop-Schließen: Flutter → Alle.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1084, lib/features/people/presentation/pages/people_list_page.dart:1104, lib/features/people/presentation/pages/people_list_page.dart:1116, lib/features/people/presentation/pages/people_list_page.dart:312, lib/shared/widgets/adaptive/app_dialog.dart:1253
- [ ] **niedrig** `people/list/list.page` `loading-5e1535fb` [people/list/list.page.ts:821](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L821) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay "Person wird entfernt..." / Flutter: kein Overlay, Toast bei Erfolg/Fehler.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1485
- [ ] **niedrig** `people/list/list.page` `loading-93ed0021` [people/list/list.page.ts:872](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L872) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay "Wird pausiert..." / Flutter: kein Overlay; zusätzlich grüne Snackbar "<Vorname> wurde pausiert" (Ionic: keine) und Fehler-Snackbar.
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:211, lib/features/people/presentation/widgets/pause_person_sheet.dart:221
- [ ] **niedrig** `people/list/list.page` `loading-8b3a6dad` [people/list/list.page.ts:969](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L969) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay "Wird aktiviert..." / Flutter: kein Overlay; Fehler-Toast.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1411
- [ ] **niedrig** `people/list/list.page` `modal-a495856e` [people/list/list.page.ts:1036](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L1036) (2. Prüfung: bestätigt)
  Gefilterte, sortierte Personen übergeben, Neuladen bei Rückgabe true. Ionic: Modal mit presentingElement (iOS Karte, Wischen schließt), backdropDismiss false / Flutter: Vollbild-Dialog auf allen Plattformen. Nur Darstellung.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1345, lib/features/people/presentation/pages/people_list_page.dart:1348
- [ ] **niedrig** `people/list/list.page` `modal-b8ba8673` [people/list/list.page.ts:1078](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L1078) (2. Prüfung: korrigiert)
  Import-Seite mit Rückgabe imported -> Neuladen gleich. Ionic: iOS-Karten-Modal / Flutter: Vollbild-Dialog (wie modal-a495856e); Korrektur ok->diff niedrig der Konsistenz wegen, nur Darstellung.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1361, lib/features/people/presentation/pages/people_list_page.dart:1363
- [ ] **niedrig** `people/list/list.page` `action-15041222` [people/list/list.page.html:47](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L47) (2. Prüfung: bestätigt)
  Ionic: Pull-to-Refresh lädt Personen und Termine neu und wartet / Flutter: _refresh invalidiert nur realtimePlayersProvider, Spinner endet sofort; Prozente kommen aus playerAttendancePercentagesProvider (Realtime-Zähler). Gleiche Funktion, Daten bleiben per Realtime aktuell.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:553, lib/features/people/presentation/pages/people_list_page.dart:706, lib/features/people/presentation/pages/people_list_page.dart:728
- [ ] **niedrig** `people/list/list.page` `text-ccf5d7d7` [people/list/list.page.html:228](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L228) (2. Prüfung: bestätigt)
  Normalfall gleich. Ionic: ohne Gruppe Trenner ' (n)' ohne Namen, Gruppierung nach Gruppen-ID / Flutter: 'Keine Gruppe (n)', Gruppierung nach Gruppenname. Nur Randfall, gleiche Funktion.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:440, lib/features/people/presentation/pages/people_list_page.dart:678
- [ ] **niedrig** `people/list/list.page` `action-e7b7f732` [people/list/list.page.html:230](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L230) (2. Prüfung: bestätigt)
  Ionic: Reihenfolge direkt in der normalen Liste (ion-reorder-Griffe, volle Zeilen) / Flutter: eigene vereinfachte Liste (Karten nur mit Name + Ziehgriff, Gruppentitel als Text) plus X zum Verwerfen. Nur Admin/Verantwortlicher und nur bei Sortierung Gruppe wie Ionic; sortiert pro Gruppe sort_order 1..n.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1018, lib/features/people/presentation/pages/people_list_page.dart:1207, lib/features/people/presentation/pages/people_list_page.dart:1252
- [ ] **niedrig** `people/list/list.page` `field-c1d3a82f` [people/list/list.page.html:545](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L545) (2. Prüfung: bestätigt)
  Platzhalter Ionic "Bitte gib einen Grund an..." / Flutter "Gib einen Grund für die Pause an..."; sonst gleich (mehrzeilig, Satzanfang groß).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:113, lib/features/people/presentation/widgets/pause_person_sheet.dart:116
- [ ] **niedrig** `people/list/list.page` `field-187f6bb7` [people/list/list.page.html:567](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L567) (2. Prüfung: bestätigt)
  Ionic: Inline-Kalender (max heute) / Flutter: Datumspicker-Dialog (max heute, frühestens vor 5 Jahren). Gleiche Funktion.
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:132, lib/features/people/presentation/widgets/pause_person_sheet.dart:137
- [ ] **niedrig** `people/list/list.page` `field-315040b9` [people/list/list.page.html:594](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L594) (2. Prüfung: bestätigt)
  Ionic: Inline-Kalender (ab heute, ohne Obergrenze, keine Vorauswahl) / Flutter: Datumsdialog (ab heute, bis +3 Jahre, Start heute+30 Tage). Beim Bestätigen wird dann ein Enddatum gesetzt, wie bei Ionic nach Auswahl.
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:142, lib/features/people/presentation/widgets/pause_person_sheet.dart:150
- [ ] **niedrig** `people/list/list.page` `text-63b77c8c` [people/list/list.page.html:606](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L606) (2. Prüfung: bestätigt)
  Ionic: "… Wenn ein Enddatum angegeben wird, wird die Person automatisch reaktiviert." / Flutter: "… Wenn ein Enddatum angegeben ist, wird die Person danach automatisch wieder aktiviert." (gleiche Bedeutung).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:158
- [ ] **niedrig** `people/list/list.page` `action-32a9bf9f` [people/list/list.page.html:610](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L610) (2. Prüfung: bestätigt)
  Ionic: Block-Button Primärfarbe / Flutter: gelber (warning) Button mit Pause-Icon; "Pausieren", ohne Grund deaktiviert (trim). Gleiche Funktion.
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:163
- [ ] **niedrig** `people/members/members.page` `toast-d347f87a` [people/members/members.page.ts:72](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/members/members.page.ts#L72)
  Ionic: roter Toast 'Fehler beim Laden der Mitglieder.' + darunter 'Keine Mitglieder gefunden.' / Flutter: kein Toast, Text 'Fehler beim Laden der Mitglieder.' inline mit Personen-Icon.
  Flutter: lib/features/members/presentation/pages/members_page.dart:98, lib/features/members/presentation/pages/members_page.dart:99
- [ ] **niedrig** `people/members/members.page` `field-f68af1a6` [people/members/members.page.html:23](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/members/members.page.html#L23) (2. Prüfung: korrigiert)
  Platzhalter 'Person suchen...' und Suche in Vor-/Nachname/Gruppenname gleich. Flutter vergleicht auch gegen den Ersatztext 'Ohne Gruppe' (Ionic filtert vor dem Ersatznamen), Suche 'ohne' findet dort nur in Flutter Personen ohne Gruppe.
  Flutter: lib/features/members/presentation/pages/members_page.dart:59, lib/features/members/data/providers/members_providers.dart:133
- [ ] **niedrig** `people/person/person.page` `loading-be5cc2f1` [people/person/person.page.ts:389](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L389) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading 'Wird zurückgesetzt...' / Flutter: kein Ladeindikator; Erfolgs-/Fehler-Toast vorhanden.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1343, lib/features/people/presentation/pages/person_detail_page.dart:1351
- [ ] **niedrig** `people/person/person.page` `alert-40883a4d` [people/person/person.page.ts:503](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L503) (2. Prüfung: bestätigt)
  Detailseite gleich ('Änderungen verwerfen?', Abbrechen / Ja; nicht im Genehmigen-Modus). Flutter besser: Neu-Seite fragt bei jeder Eingabe nach, Ionic schließt das Neu-Modal immer ohne Rückfrage.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1922, lib/features/people/presentation/pages/person_create_page.dart:140
- [ ] **niedrig** `people/person/person.page` `toast-9348bff8` [people/person/person.page.ts:528](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L528) (2. Prüfung: bestätigt)
  Ionic: Toast „Bitte gib den Vornamen und Nachnamen an.“ / Flutter: Inline-Fehler unter den Feldern „Vorname ist erforderlich“ / „Nachname ist erforderlich“ (Labels mit „*“, nur Leerzeichen zählt als leer). Meldung vorhanden, Nutzer erfährt dasselbe.
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:392, lib/features/people/presentation/pages/person_create_page.dart:411
- [ ] **niedrig** `people/person/person.page` `loading-b5454ced` [people/person/person.page.ts:532](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L532) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading (3 s) beim Hinzufügen / Flutter: nur Speichern-FAB deaktiviert (_isLoading), kein Overlay.
  Flutter: lib/features/people/presentation/pages/person_create_page.dart:346, lib/features/people/presentation/pages/person_create_page.dart:955
- [ ] **niedrig** `people/person/person.page` `loading-d68742ec` [people/person/person.page.ts:553](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L553) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading beim Speichern / Flutter: nur Speichern-FAB deaktiviert (_isSaving), kein Overlay.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:788, lib/features/people/presentation/pages/person_detail_page.dart:1913
- [ ] **niedrig** `people/person/person.page` `alert-cd59453f` [people/person/person.page.ts:848](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L848)
  1 Treffer: gleich (Abbrechen/Ja). Mehrere Treffer: Ionic Alert mit Radio-Liste (erster vorausgewählt) + Abbrechen/Ja / Flutter: SimpleDialog, Tippen auf Eintrag übernimmt sofort, nur „Abbrechen“
  Flutter: lib/features/people/presentation/widgets/person_match_suggestions.dart:120, lib/features/people/presentation/widgets/person_match_suggestions.dart:148
- [ ] **niedrig** `people/person/person.page` `loading-ae31ca18` [people/person/person.page.ts:903](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L903)
  Ionic: blockierendes Loading „Die Personen werden zusammengeführt...“ / Flutter: nur LinearProgressIndicator in der Karte, nicht blockierend, ohne Text
  Flutter: lib/features/people/presentation/widgets/duplicate_candidates_card.dart:81, lib/features/people/presentation/widgets/duplicate_candidates_card.dart:132
- [ ] **niedrig** `people/person/person.page` `loading-9ba0a7e4` [people/person/person.page.ts:1013](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1013) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading beim Account anlegen / Flutter: kein Ladeindikator (Erfolgs-/Fehler-Toast vorhanden).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1747, lib/features/people/presentation/pages/person_detail_page.dart:1799
- [ ] **niedrig** `people/person/person.page` `toast-fc0e45e2` [people/person/person.page.ts:1022](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1022) (2. Prüfung: bestätigt)
  Ionic: Roh-Fehlermeldung error.message / Flutter: „{Name} - Fehler beim Erstellen des Accounts: {error}“ (danger). Gleiche Information.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1825
- [ ] **niedrig** `people/person/person.page` `loading-b96f785a` [people/person/person.page.ts:1090](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1090) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading beim Bildupload / Flutter: nur Info-Toast 'Lade Passbild hoch...', nicht blockierend; Größenfehler-Toast vorhanden.
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:200
- [ ] **niedrig** `people/person/person.page` `toast-7e0a2ff5` [people/person/person.page.ts:1119](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1119) (2. Prüfung: bestätigt)
  Ionic: Roh-Fehler beim Bild-Upload / Flutter: „Fehler beim Hochladen: {error}“ (danger). Gleiche Information.
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:250
- [ ] **niedrig** `people/person/person.page` `loading-fc02b5d4` [people/person/person.page.ts:1203](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1203) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading während 'Meinen Benutzer zuweisen' / Flutter: kein Ladeindikator; Ergebnis und Toasts gleich.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1212
- [ ] **niedrig** `people/person/person.page` `toast-f74ad707` [people/person/person.page.ts:1251](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1251) (2. Prüfung: bestätigt)
  Wieder aktivieren (Mehr-Menü, pausierte Person): Ionic Roh-Fehler (error-Objekt) / Flutter „Fehler: {error}“ rot. Fehler wird in beiden gemeldet.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1291
- [ ] **niedrig** `people/person/person.page` `toast-f74ad707-2` [people/person/person.page.ts:1312](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1312) (2. Prüfung: bestätigt)
  Entfernen: Ionic schließt die Seite vor dem Löschen, Fehler roh / Flutter löscht erst, dann „Die Person wurde erfolgreich entfernt“ bzw. „Fehler: {error}“ rot. Fehler wird in beiden gemeldet.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1634
- [ ] **niedrig** `people/person/person.page` `toast-d7c9e86c` [people/person/person.page.ts:1371](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1371) (2. Prüfung: bestätigt)
  Ionic: „Die Person wurde erfolgreich kopiert/übertragen“ / Flutter: „1 Spieler erfolgreich kopiert/übertragen“.
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:819
- [ ] **niedrig** `people/person/person.page` `toast-b4300d3e` [people/person/person.page.ts:1373](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1373)
  Ionic: Roh-Fehler / Flutter: „Fehler: {error}“
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:830
- [ ] **niedrig** `people/person/person.page` `toast-f4e0ab31` [people/person/person.page.ts:1433](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1433) (2. Prüfung: bestätigt)
  Ionic: Roh-Fehler (danger) / Flutter: „Fehler: {error}“ (danger). Gleiche Information.
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:216
- [ ] **niedrig** `people/person/person.page` `alert-71956f19` [people/person/person.page.ts:1439](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1439) (2. Prüfung: bestätigt)
  Texte/Buttons gleich ('Auch in anderen Instanzen pausieren?', Name-Text, Checkboxen, Überspringen/Pausieren). Flutter besser: bietet nur verknüpfte Instanzen an, in denen der Nutzer Admin/Verantwortlicher ist (Ionic listet alle, dort greift RLS ohne Fehlermeldung); übergibt 'Pausiert bis' an die anderen Instanzen, während Ionic person.page pauseUntil durch dismissPauseModal schon geleert hat (paused_until null).
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:240, lib/features/people/presentation/widgets/pause_person_sheet.dart:288, lib/features/people/presentation/widgets/pause_person_sheet.dart:305, lib/features/people/presentation/pages/person_detail_page.dart:1254
- [ ] **niedrig** `people/person/person.page` `loading-cd6c7935` [people/person/person.page.ts:1496](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1496) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading beim Eintragen der Abwesenheit / Flutter: Sheet schließt, Speichern ohne Ladeindikator; Ergebnis-Toast gleich.
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:232
- [ ] **niedrig** `people/person/person.page` `loading-6f0c380f` [people/person/person.page.ts:1546](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1546) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading beim Löschen der Abwesenheit / Flutter: kein Ladeindikator; Bestätigung und Erfolg-/Fehler-Toast vorhanden.
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:249, lib/features/people/presentation/widgets/planned_absences.dart:287
- [ ] **niedrig** `people/person/person.page` `actionsheet-eadcf3f0` [people/person/person.page.ts:1641](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1641) (2. Prüfung: bestätigt)
  Bedingung/Texte/Reihenfolge/Wirkung gleich. Ionic: keine Icons, 'Abbrechen' destructive / Flutter: Icons (grün/rot), 'Abbrechen' normal.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1484
- [ ] **niedrig** `people/person/person.page` `loading-58ec291d` [people/person/person.page.ts:1680](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1680) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading 'Die Person wird abgelehnt...' / Flutter: kein Ladeindikator (Fehler-Toast vorhanden).
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1423, lib/features/people/presentation/pages/person_detail_page.dart:1467
- [ ] **niedrig** `people/person/person.page` `loading-00357310` [people/person/person.page.ts:1717](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.ts#L1717) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading 'Die Person wird genehmigt...' / Flutter: kein Ladeindikator während der Genehmigung (zusätzlicher Bestätigungsdialog inzwischen entfernt, Aktionsblatt → direkt genehmigen). Ergebnis und Toasts gleich.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:1372, lib/features/people/presentation/pages/person_detail_page.dart:1484
- [ ] **niedrig** `people/person/person.page` `action-5615e0d7` [people/person/person.page.html:49](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L49) (2. Prüfung: bestätigt)
  Viewer hat jetzt 'Ersetzen' und 'Entfernen' (nur canEdit) wie Ionic. Unterschied: Viewer-Titel '<Vorname Nachname>.jpg' statt 'Passbild'; Bild-URL ohne ?quality=20-Entfernung (Flutter-URLs enthalten es nicht).
  Flutter: lib/features/people/presentation/widgets/person_detail/person_header.dart:164, lib/features/people/presentation/widgets/person_detail/person_header.dart:179, lib/shared/widgets/sheets/image_viewer_sheet.dart:19
- [ ] **niedrig** `people/person/person.page` `text-e915fb37` [people/person/person.page.html:74](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L74) (2. Prüfung: bestätigt)
  Detail: „Vorname“ gleich; Neu-Seite: „Vorname *“. Reine Darstellung.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:236, lib/features/people/presentation/pages/person_create_page.dart:385
- [ ] **niedrig** `people/person/person.page` `field-4b77b853` [people/person/person.page.html:75](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L75) (2. Prüfung: bestätigt)
  Detail: Tipp → Editor-Sheet mit Pflicht-Validierung statt Inline-Eingabe (Fertig-Button vorhanden); Neu-Seite: Textfelder mit Namensvorschlägen wie Ionic; nur canEdit.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:232, lib/features/people/presentation/pages/person_create_page.dart:382
- [ ] **niedrig** `people/person/person.page` `text-c4ad9070` [people/person/person.page.html:82](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L82) (2. Prüfung: bestätigt)
  Detail: „Nachname“ gleich; Neu-Seite: „Nachname *“. Reine Darstellung.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:252, lib/features/people/presentation/pages/person_create_page.dart:404
- [ ] **niedrig** `people/person/person.page` `field-6e1a9b00` [people/person/person.page.html:83](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L83) (2. Prüfung: bestätigt)
  Ionic: Inline-Nachname (nur neue Person oder nach Stift-Tipp, Button 'Fertig'; Namensvorschläge nur bei neuer Person) / Flutter: Detail: Stift -> Zeile mit Editor-Sheet + Pflicht-Validierung, 'Fertig'-Button vorhanden; Neu-Seite TextFormField mit Pflicht. Nur Bedienung.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:254, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:238, lib/features/people/presentation/pages/person_create_page.dart:404
- [ ] **niedrig** `people/person/person.page` `text-5dbfd756` [people/person/person.page.html:116](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L116) (2. Prüfung: bestätigt)
  Prozent-Badge (Score) der Duplikat-Kandidaten fehlt in der Flutter-Karte (lib/features/people/presentation/widgets/duplicate_candidates_card.dart:133).
- [ ] **niedrig** `people/person/person.page` `action-c72e602e` [people/person/person.page.html:131](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L131)
  Schließen-Button gleich; Flutter zeigt zusätzlich Überschrift „Person in anderer Instanz gefunden?“ über den Vorschlägen (Ionic ohne Überschrift)
  Flutter: lib/features/people/presentation/widgets/person_match_suggestions.dart:40, lib/features/people/presentation/widgets/person_match_suggestions.dart:46
- [ ] **niedrig** `people/person/person.page` `field-05790430` [people/person/person.page.html:164](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L164) (2. Prüfung: bestätigt)
  Ionic: Inline-Textarea (autoGrow), für Admins auch bei archivierten Personen (dann deaktiviert, auch leer) / Flutter: Zeile ('Keine Notizen' wenn leer), Tipp öffnet Editor-Sheet, bei archivierten Personen ohne Notiz ausgeblendet; leere Notiz als null gespeichert; Historien-Eintrag bei Änderung gleich.
  Flutter: lib/features/people/presentation/pages/person_detail_page.dart:2021, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:271, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:280
- [ ] **niedrig** `people/person/person.page` `field-4bf62b27` [people/person/person.page.html:221](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L221) (2. Prüfung: bestätigt)
  Ionic: Label 'Gruppe', Modal-Select / Flutter: Label je Mandantentyp 'Stimme'/'Instrument'/'Gruppe', Auswahl-Sheet; Wechsel setzt Stimmführer zurück wie Ionic; nur canEdit.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:291, lib/features/people/presentation/pages/person_detail_page.dart:639
- [ ] **niedrig** `people/person/person.page` `field-9f6c9acb` [people/person/person.page.html:237](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L237) (2. Prüfung: bestätigt)
  Stimmumfang (Chor): Ionic-Input ohne ionChange / Flutter besser: Änderung aktiviert Speichern. Bearbeiten per Editor-Sheet; leer + nicht bearbeitbar ausgeblendet. Ionic disabled bei readOnly||!isAdmin = Flutter canEdit (Admin/Verantwortlicher).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:862, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:868
- [ ] **niedrig** `people/person/person.page` `text-bb66373a` [people/person/person.page.html:245](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L245) (2. Prüfung: bestätigt)
  Ionic: „Telefon-/Handynummer“ (immer sichtbar, bei readOnly deaktiviert) / Flutter: „Telefon“, ohne Nummer und ohne Bearbeitungsrecht ausgeblendet. Gleiche Funktion.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:338
- [ ] **niedrig** `people/person/person.page` `field-84804c14` [people/person/person.page.html:246](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L246) (2. Prüfung: bestätigt)
  Telefon: Bearbeiten per Editor-Sheet statt Inline; zusätzlich Anruf-Button; leer + nicht bearbeitbar ausgeblendet. Gleiche Funktion, Rollen gleich (canEdit = Admin/Verantwortlicher, nicht ausgetreten).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:332, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:338
- [ ] **niedrig** `people/person/person.page` `modal-9c171caa` [people/person/person.page.html:266](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L266) (2. Prüfung: bestätigt)
  Ionic: Modal mit Rad-Datumsauswahl / Flutter: Kalender-Dialog (DateEditorSheet) neben Tipp-Eingabe; gleiche Funktion, Optik.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:164, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:372, lib/features/people/presentation/widgets/person_detail/date_input_row.dart:113
- [ ] **niedrig** `people/person/person.page` `field-946f7994` [people/person/person.page.html:268](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L268) (2. Prüfung: bestätigt)
  Ionic: ion-datetime Rad (max heute) neben Tipp-Eingabe TT.MM.JJJJ / Flutter: DateInputRow mit Tipp-Eingabe (Übernahme bei Blur, ungültig wird zurückgesetzt) + Kalender-Dialog, lastDate heute; speichert UTC-Mitternacht-ISO wie Ionic. Nur Optik. correctBirthday=true sofort bei Änderung (Warnfarbe verschwindet) und beim Speichern, wie Ionic.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:164, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:372, lib/features/people/presentation/widgets/person_detail/date_input_row.dart:51, lib/features/people/presentation/pages/person_detail_page.dart:631, lib/features/people/presentation/pages/person_detail_page.dart:954
- [ ] **niedrig** `people/person/person.page` `modal-637d2f88` [people/person/person.page.html:298](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L298) (2. Prüfung: bestätigt)
  Ionic: Modal mit Rad-Datumsauswahl / Flutter: Kalender-Dialog (DateEditorSheet) neben Tipp-Eingabe; gleiche Funktion, Optik. Bedingung !general && !choir && !mainGroup wie Ionic.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:179, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:372
- [ ] **niedrig** `people/person/person.page` `field-6cfcad0a` [people/person/person.page.html:300](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L300) (2. Prüfung: bestätigt)
  Ionic: ion-datetime Rad, max = heute / Flutter: Datumsauswahl, lastDate = heute; zusätzlich Texteingabe TT.MM.JJJJ.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:372, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:392
- [ ] **niedrig** `people/person/person.page` `modal-5e3cc20f` [people/person/person.page.html:330](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L330) (2. Prüfung: bestätigt)
  Ionic: Modal mit Rad-Datumsauswahl / Flutter: Kalender-Dialog (DateEditorSheet) neben Tipp-Eingabe; gleiche Funktion, Optik.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:189, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:372
- [ ] **niedrig** `people/person/person.page` `field-8c59f281` [people/person/person.page.html:332](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L332) (2. Prüfung: bestätigt)
  Ionic: ion-datetime (Beigetreten am) Rad (max heute) neben Tipp-Eingabe TT.MM.JJJJ / Flutter: DateInputRow mit Tipp-Eingabe (Übernahme bei Blur, ungültig wird zurückgesetzt) + Kalender-Dialog, lastDate heute; speichert UTC-Mitternacht-ISO wie Ionic. Nur Optik.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:189, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:372, lib/features/people/presentation/widgets/person_detail/date_input_row.dart:51
- [ ] **niedrig** `people/person/person.page` `field-06ab1bbe` [people/person/person.page.html:350](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L350) (2. Prüfung: bestätigt)
  Ionic: Modal-Select, ohne Auswahl 'Nicht festgelegt' / Flutter: Auswahl-Sheet mit Option 'Nicht festgelegt' (setzt parent_id null), Anzeige ohne Auswahl aber 'Nicht zugewiesen' – gleiche Bedeutung.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:196, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:631, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:648
- [ ] **niedrig** `people/person/person.page` `field-6acc513f` [people/person/person.page.html:402](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L402) (2. Prüfung: bestätigt)
  Bedingung (Chor && !Hauptgruppe) und Bearbeitung nur Admin/Verantwortlich gleich; Tipp → Editor-Sheet statt Inline-Eingabe; leer + nicht bearbeitbar ausgeblendet.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:881, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:206
- [ ] **niedrig** `people/person/person.page` `field-7662f2a7` [people/person/person.page.html:435](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L435) (2. Prüfung: bestätigt)
  Testergebnis (VoS, nicht Hauptgruppe): Ionic immer sichtbar, bei Flutter leer + nicht bearbeitbar ausgeblendet; Bearbeiten per Editor-Sheet, speichert testResult (leer -> null). Gleiche Funktion.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:910, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:916
- [ ] **niedrig** `people/person/person.page` `field-ea337733` [people/person/person.page.html:474](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L474) (2. Prüfung: bestätigt)
  Ionic: ion-datetime-button 'Anfangsdatum' / Flutter: Zeile mit Datum, Tipp öffnet Kalender (2000-2100), leer 'Nicht angegeben'. Nur bei Plan ohne benannte Schichten. Nur Optik.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:591, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:607
- [ ] **niedrig** `people/person/person.page` `modal-ac91c261` [people/person/person.page.html:475](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L475) (2. Prüfung: bestätigt)
  Ionic: Modal mit ion-datetime / Flutter: Kalender-Dialog. Nur Optik.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:607
- [ ] **niedrig** `people/person/person.page` `text-79d104bf` [people/person/person.page.html:490](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L490) (2. Prüfung: bestätigt)
  Bedingung nicht ganz gleich. Ionic: !readOnly || otherExercise (leerer String gilt als leer) / Flutter: otherExercise != null || canEdit → Beobachter und archivierte Personen sehen bei gespeichertem '' eine leere Zeile 'Sonstige Dienste'. Label gleich.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:225, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:669
- [ ] **niedrig** `people/person/person.page` `field-eb1656da` [people/person/person.page.html:491](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L491) (2. Prüfung: bestätigt)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; Leeren speichert null statt '' (beides leer). Bedingung otherExercise != null || canEdit (siehe text-79d104bf).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:225, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:664, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:672
- [ ] **niedrig** `people/person/person.page` `text-e65374d2` [people/person/person.page.html:503](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L503) (2. Prüfung: korrigiert)
  Bearbeiten-Seite gleich: Akkordeon „Account“ nur canEdit (Admin/Verantwortliche) && !pending, also ohne Eltern/Beobachter/Bewerbungsmodus wie Ionic (!isParent && !readOnly && !approveMode). Erstreviewer hat die Neu-Seite übersehen: Ionic zeigt das Akkordeon „Account“ auch beim Anlegen (E-Mail, Suche, Hilfe darin) / Flutter-Neu-Seite: E-Mail-Feld und Hilfetext ohne Überschrift „Account“ direkt im Formular. Nur Anordnung.
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:66, lib/features/people/presentation/pages/person_detail_page.dart:2053, lib/features/people/presentation/pages/person_create_page.dart:475, lib/features/people/presentation/pages/person_create_page.dart:506
- [ ] **niedrig** `people/person/person.page` `field-d1e5b0ca` [people/person/person.page.html:510](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L510) (2. Prüfung: bestätigt)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe (Sheet prüft nur auf '@', volle Prüfung 'Ungültige E-Mail' beim Speichern wie Ionic); Suche nach gleicher E-Mail in anderen Instanzen nach Übernahme aus dem Sheet statt bei Blur, Dialog/Übernahme gleich; gesperrt wenn appId wie Ionic.
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:88, lib/features/people/presentation/widgets/person_detail/account_accordion.dart:92, lib/features/people/presentation/widgets/person_detail/account_accordion.dart:340, lib/features/people/presentation/pages/person_detail_page.dart:1080
- [ ] **niedrig** `people/person/person.page` `action-06c55240` [people/person/person.page.html:514](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L514) (2. Prüfung: bestätigt)
  Ionic: Lupen-Icon-Button rechts im E-Mail-Feld, sichtbar ohne Konto, deaktiviert ohne E-Mail / Flutter: Textbutton 'In anderer Instanz suchen' unter dem Feld, nur sichtbar mit E-Mail. Funktion gleich (Namenssuche in verknüpften Instanzen, Toast 'keine Treffer', Aktionsblatt 'Eintrag auswählen', schreibt email + global_person_id mit tenantId, Kandidat bekommt global_person_id, Toast 'E-Mail aktualisiert'). Flutter schreibt nur diese Felder statt des ganzen Entwurfs.
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:103, lib/features/people/presentation/pages/person_detail_page.dart:1130
- [ ] **niedrig** `people/person/person.page` `action-0de62271` [people/person/person.page.html:519](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L519) (2. Prüfung: bestätigt)
  Ionic: roter Papierkorb-Icon-Button rechts im E-Mail-Feld / Flutter: Outlined-Button 'Account-Verknüpfung aufheben' unter der Rollenauswahl (canEdit && appId). Ablauf gleich: Alert 'Account entfernen' Abbrechen/Ja, removeUserFromTenant (Admins/weitere aktive Person behalten Zugang), email + appId = null, Seite schließt, Toasts gleich.
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:131, lib/features/people/presentation/pages/person_detail_page.dart:1678
- [ ] **niedrig** `people/person/person.page` `field-280cafd6` [people/person/person.page.html:530](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L530) (2. Prüfung: bestätigt)
  Optionen/Reihenfolge (Mitglied, Verantwortlicher, Helfer, bei Stimmführer + Stimmführer & Helfer, Stimmführer), Sperre bei Hauptgruppe, sofortiges Schreiben (tenantUsers.role) + Toast 'Die Rolle wurde erfolgreich aktualisiert.' gleich. Flutter besser: Rolle außerhalb der Liste (z. B. Admin) wird angezeigt statt leerem Select; Bedingung nur appId (Ionic email && appId, Konto ohne E-Mail praktisch nicht vorhanden).
  Flutter: lib/features/people/presentation/widgets/person_detail/account_accordion.dart:122, lib/features/people/presentation/widgets/person_detail/account_accordion.dart:211, lib/features/people/presentation/widgets/person_detail/account_accordion.dart:266, lib/features/people/presentation/pages/person_detail_page.dart:1638
- [ ] **niedrig** `people/person/person.page` `field-247f92a0` [people/person/person.page.html:585](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L585) (2. Prüfung: bestätigt)
  Bearbeiten per Tipp → Editor-Sheet statt Inline-Eingabe; nur canEdit.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:793, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:797
- [ ] **niedrig** `people/person/person.page` `modal-9dba127a` [people/person/person.page.html:608](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L608) (2. Prüfung: bestätigt)
  Ionic: Modal mit Rad-Datumsauswahl / Flutter: Kalender-Dialog (DateEditorSheet) neben Tipp-Eingabe; gleiche Funktion, Optik.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:770, lib/features/people/presentation/widgets/person_detail/date_input_row.dart:113
- [ ] **niedrig** `people/person/person.page` `field-e423e2ec` [people/person/person.page.html:610](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L610) (2. Prüfung: bestätigt)
  Ionic: Datums-Zusatzfeld mit Tipp-Eingabe + Rad, max = heute, speichert UTC-Mitternacht-ISO / Flutter: DateInputRow (canEdit), lastDate heute, gleicher ISO-Wert; (alter Befund 'kein Maximum' ist behoben). Nur Optik.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:770, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:772, lib/features/people/presentation/widgets/person_detail/date_input_row.dart:51
- [ ] **niedrig** `people/person/person.page` `field-50c752ee` [people/person/person.page.html:621](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L621) (2. Prüfung: bestätigt)
  Bearbeiten per Tipp → Auswahl-Sheet statt Inline-Select; fehlende Werte werden wie in Ionic mit Standard/erster Option vorbelegt (_withExtraDefaults).
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:841
- [ ] **niedrig** `people/person/person.page` `field-049486aa` [people/person/person.page.html:628](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L628) (2. Prüfung: bestätigt)
  Bearbeiten per Tipp → Editor-Sheet (4 Zeilen) statt Inline-Textarea; nur canEdit.
  Flutter: lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:793, lib/features/people/presentation/widgets/person_detail/allgemein_accordion.dart:797
- [ ] **niedrig** `people/person/person.page` `modal-cc0c1d20` [people/person/person.page.html:635](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L635)
  Ionic: Vollbild-Modal / Flutter: Bottom-Sheet mit 85 % Höhe
  Flutter: lib/features/people/presentation/widgets/church_picker_sheet.dart:26
- [ ] **niedrig** `people/person/person.page` `text-4ba50278` [people/person/person.page.html:707](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L707) (2. Prüfung: bestätigt)
  Ionic: Bereich 'Historie' nur sichtbar, wenn Einträge vorhanden / Flutter: immer sichtbar, leer mit 'Keine Historie vorhanden' (ohne Durchschnitt); zusätzlich Umschalter 'Alle anzeigen' (alle Saisons). Nicht-Admins sehen nur Gruppenwechsel/Pausen wie Ionic.
  Flutter: lib/features/people/presentation/widgets/person_detail/historie_accordion.dart:50, lib/features/people/presentation/widgets/person_detail/historie_accordion.dart:76, lib/features/people/presentation/widgets/person_detail/historie_accordion.dart:126
- [ ] **niedrig** `people/person/person.page` `text-0f8281df` [people/person/person.page.html:803](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L803)
  Text gleich; Flutter zählt Termine ab heute (gte heute), Ionic nur Termine nach jetzt — heutige Termine erscheinen in Flutter zusätzlich hier und in der Historie
  Flutter: lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:20, lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:121
- [ ] **niedrig** `people/person/person.page` `text-9bed7686` [people/person/person.page.html:811](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L811) (2. Prüfung: bestätigt)
  Format „dd.MM.yyyy | Titel“ gleich; Flutter ignoriert hide_name der Terminart (Ionic zeigt dann nur das Datum).
  Flutter: lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:41, lib/features/people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart:142
- [ ] **niedrig** `people/person/person.page` `field-31cb4e6e` [people/person/person.page.html:954](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L954) (2. Prüfung: bestätigt)
  Ionic: Inline-Kalender im Aufklapp-Bereich, max = heute / Flutter: Datumsdialog beim Tipp, lastDate heute, frühestens vor 5 Jahren.
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:131
- [ ] **niedrig** `people/person/person.page` `field-932fcf9d` [people/person/person.page.html:976](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L976) (2. Prüfung: bestätigt)
  Ionic: Inline-Kalender in Akkordeon 'Pausiert bis', min = heute / Flutter: Kalender-Dialog je Zeile, firstDate heute, lastDate +3 Jahre (Ionic unbegrenzt), Start +30 Tage; 'Pausiert ab' max heute wie Ionic. Löschen-X vorhanden. Nur Optik/Grenze.
  Flutter: lib/features/people/presentation/widgets/pause_person_sheet.dart:132, lib/features/people/presentation/widgets/pause_person_sheet.dart:146
- [ ] **niedrig** `people/person/person.page` `action-35f05e9d` [people/person/person.page.html:1029](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1029) (2. Prüfung: bestätigt)
  Ionic: eigener Löschen-Button am 'Von'-Datum (nur Von) / Flutter: kein Button an 'Von', Button an 'Bis' löscht beide. Gleiche Funktion.
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:171, lib/features/people/presentation/widgets/planned_absences.dart:181
- [ ] **niedrig** `people/person/person.page` `field-3c608429` [people/person/person.page.html:1035](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1035) (2. Prüfung: bestätigt)
  Ionic: zwei Inline-Kalender (Von/Bis) / Flutter: ein Zeitraum-Dialog (showDateRangePicker) für Von und Bis, Vorjahr bis +3 Jahre.
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:96
- [ ] **niedrig** `people/person/person.page` `action-227003e4` [people/person/person.page.html:1051](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1051) (2. Prüfung: bestätigt)
  Ionic: löscht nur 'Bis' / Flutter: Button an 'Bis' löscht Von und Bis (Zeitraum-Auswahl). Gleiche Funktion (neu wählen).
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:181
- [ ] **niedrig** `people/person/person.page` `field-e2731760` [people/person/person.page.html:1057](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1057) (2. Prüfung: bestätigt)
  Ionic: zwei Inline-Kalender (Bis min = Von) / Flutter: gemeinsamer Zeitraum-Dialog (Von<=Bis erzwungen), Auswahl auf Vorjahr..+3 Jahre begrenzt (Ionic unbegrenzt). Pflicht Grund+Von+Bis wie Ionic (Button deaktiviert). Nur Optik.
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:96, lib/features/people/presentation/widgets/planned_absences.dart:166, lib/features/people/presentation/widgets/planned_absences.dart:175
- [ ] **niedrig** `people/person/person.page` `field-03332121` [people/person/person.page.html:1092](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1092) (2. Prüfung: bestätigt)
  Ionic: natives Datumsfeld (type=date) / Flutter: Zeile mit Datum + Datumsauswahl 2000-2100, Standard heute.
  Flutter: lib/features/people/presentation/widgets/archive_person_modal.dart:83
- [ ] **niedrig** `people/person/person.page` `text-0f2b968d` [people/person/person.page.html:1112](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1112)
  Ionic: „Kopieren von {name}“/„Übertragen von {name}“ / Flutter: „Spieler kopieren“/„Spieler übertragen“
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:114
- [ ] **niedrig** `people/person/person.page` `action-cf8fa6af` [people/person/person.page.html:1141](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/person/person.page.html#L1141)
  Ionic: Button „Kopieren“/„Übertragen“, deaktiviert ohne Instanz/Gruppe / Flutter: Button „Kopieren“/„Übertragen“ des Massen-Sheets mit Fortschritt
  Flutter: lib/features/people/presentation/widgets/handover_sheet.dart:200
- [ ] **niedrig** `teacher/teacher.page` `field-fc1d0925` [teacher/teacher.page.html:18](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teacher/teacher.page.html#L18) (2. Prüfung: bestätigt)
  Ionic: ion-select interface=modal, alle Gruppen inkl. Hauptgruppe, Mehrfachauswahl, keine Validierung beim Bearbeiten / Flutter: Dialog mit Checkboxen und Abbrechen/OK, gleiche Optionen (alle Gruppen), Label „Instrumente“, Validierung nur beim Anlegen. Nur Darstellung.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:147, lib/features/teachers/presentation/pages/teachers_list_page.dart:265, lib/features/teachers/presentation/pages/teachers_list_page.dart:356
- [ ] **niedrig** `teachers/teachers.page` `modal-81bd0046` [teachers/teachers.page.ts:67](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teachers/teachers.page.ts#L67) (2. Prüfung: bestätigt)
  Nur für Admin/Verantwortliche (onTap null sonst), übergibt den Lehrer, Schüler aus playersProvider, alle Gruppen zur Auswahl; nach Speichern Toast „teachers.updated“ und Liste neu geladen. Ionic: iOS Karten-Modal (presentingElement), md Vollbild / Flutter: Vollbild-Dialog (fullscreenDialog) auf allen Plattformen.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:142-178, lib/features/teachers/presentation/pages/teachers_list_page.dart:404-439
- [ ] **niedrig** `teachers/teachers.page` `field-cfeef758` [teachers/teachers.page.html:41](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/teachers/teachers.page.html#L41) (2. Prüfung: bestätigt)
  Gruppen ohne Hauptgruppe (Zeile 119), Label „Instrumente“, Mehrfachauswahl. Ionic: ion-select interface=modal, Auswahl bleibt nach dem Anlegen für das nächste Öffnen (selInstruments) / Flutter: Dialog Checkboxen Abbrechen/OK, Formular startet jedes Mal leer. Nur Komfort/Darstellung.
  Flutter: lib/features/teachers/presentation/pages/teachers_list_page.dart:116, lib/features/teachers/presentation/pages/teachers_list_page.dart:265, lib/features/teachers/presentation/pages/teachers_list_page.dart:356
- [ ] **niedrig** `people/bulk-edit/bulk-edit.page` `x-5b376c7a36` **Fehler beim Org-Feld-Speichern: zusätzlicher Toast** [src/app/services/organisation/organisation.service.ts:88-91](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/organisation/organisation.service.ts#L88-L91) (2. Prüfung: bestätigt)
  Ionic: orgSvc.updatePersonFieldValues zeigt bei Fehler zusätzlich „Fehler beim Speichern der gemeinsamen Zusatzfelder“ (danger), danach „Fehler beim Speichern“ / Flutter: nur „Fehler beim Speichern“. Fehler wird gemeldet. Schreibweg gleich (upsert tenant_group_person_fields, onConflict tenant_group,person_key,field_id).
  Flutter: lib/data/repositories/profile_repository.dart:310, lib/data/repositories/profile_repository.dart:345, lib/features/people/presentation/pages/bulk_edit_page.dart:243, lib/features/people/presentation/pages/bulk_edit_page.dart:245
- [ ] **niedrig** `people/import/import.page` `x-ab5b4f49ad` **Fehlergrund im Fehlerdialog technisch** [src/app/services/db.service.ts:3638-3640](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/db.service.ts#L3638-L3640) (2. Prüfung: bestätigt)
  Ionic: Grund = error.message ?? „Unbekannter Fehler“ / Flutter: '$e' mit Klassenname/Operation/Code (z. B. „RepositoryException: … (operation: …, code: 23505)“). Zeile und Fehlschlag werden in beiden gezeigt.
  Flutter: lib/features/people/presentation/pages/person_import_page.dart:250, lib/features/people/presentation/pages/person_import_page.dart:251, lib/data/repositories/base_repository.dart:170
- [ ] **niedrig** `people/list/list.page` `x-325647b4ef` **Reorder-Modus** [src/app/people/list/list.page.ts:324](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L324) (2. Prüfung: bestätigt)
  Ionic: Griffe in der normalen Liste, kein Abbrechen, Lade-Overlay 'Reihenfolge wird gespeichert' / Flutter: eigene Kartenliste je Gruppe, zusätzliches X zum Verwerfen, nur Spinner im Häkchen-Button. DB-Schreiben jetzt wie Ionic: sort_order 1..n nur für die verschobenen Gruppen (gefilterte Personen), je Zeile id + tenantId; Toasts gespeichert/fehlgeschlagen gleich. Nur Darstellung.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:498, lib/features/people/presentation/pages/people_list_page.dart:506, lib/features/people/presentation/pages/people_list_page.dart:1207, lib/features/people/presentation/pages/people_list_page.dart:1234, lib/features/people/presentation/pages/people_list_page.dart:1252, lib/data/repositories/player_repository.dart:1883
- [ ] **niedrig** `people/list/list.page` `x-f6927de895` **Auto-Entpausieren nur beim ersten Öffnen** [src/app/people/list/list.page.ts:140](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.ts#L140) (2. Prüfung: bestätigt)
  Ionic: checkAndUnpausePlayers (Admin/Verantwortlicher) in jedem initializeData, auch nach Instanzwechsel, vor dem Laden / Flutter: nur einmal im initState (Post-Frame); ref.listen auf Instanzwechsel setzt nur Filter zurück, löst kein Entpausieren aus. Abgelaufene Pausen der neuen Instanz werden erst beim nächsten Neuaufbau der Seite aufgehoben (verzögert, nicht anders).
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:132, lib/features/people/presentation/pages/people_list_page.dart:135, lib/features/people/presentation/pages/people_list_page.dart:454
- [ ] **niedrig** `people/list/list.page` `x-56b7f726f5` **Flutter-Zusatz: Personen übertragen** [src/app/people/list/list.page.html:166](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/list/list.page.html#L166) (2. Prüfung: bestätigt)
  Flutter-Zusatz: Optionsmenü 'Personen übertragen' (nur Admin/Verantwortlicher) mit Auswahlmodus, AppBar 'n ausgewählt' und Übergabe-Sheet. Ionic hat die Personenübergabe nur in den Einstellungen (/tabs/settings/handover, ebenfalls nur Admin/Verantwortlicher) – keine Rolle erhält mehr Rechte.
  Flutter: lib/features/people/presentation/pages/people_list_page.dart:1025, lib/features/people/presentation/pages/people_list_page.dart:752, lib/features/people/presentation/pages/people_list_page.dart:1373
- [ ] **niedrig** `people/members/members.page` `x-1730d62932` **Ladefehler inline statt Toast** [src/app/people/members/members.page.ts:72](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/people/members/members.page.ts#L72)
  Ionic: roter Toast und leere Liste / Flutter: Fehlertext inline, kein Toast.
  Flutter: lib/features/members/presentation/pages/members_page.dart:98
- [ ] **niedrig** `duty/duty-assign-modal/duty-assign-modal.component` `x-9cfbd56a81` **Namens-Tiebreak nicht locale-aware** [src/app/duty/duty-assign-modal/duty-assign-modal.component.ts:41](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-assign-modal/duty-assign-modal.component.ts#L41)
  Ionic: bei gleicher Dienstanzahl a.name.localeCompare(b.name) (Umlaute bei Grundbuchstaben, Groß/Klein egal) / Flutter: a.name.compareTo(b.name) (Code-Unit-Reihenfolge, z. B. „Özil“ nach „Zoe“, Kleinbuchstaben nach Großbuchstaben).
  Flutter: lib/features/duty/presentation/widgets/duty_assign_sheet.dart:95
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-41b22d1e2d` **Speichern bei Fehler** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:236](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L236) (2. Prüfung: bestätigt)
  Weiter real: Ionic bricht beim ersten fehlerhaften Termin ab (assign zeigt „Fehler beim Einteilen“ und wirft), Flutter teilt die übrigen Termine trotzdem ein und zeigt danach einmal „Fehler beim Einteilen“; Seite bleibt in beiden offen. Geschrieben werden nur die in der Vorschau bestätigten Einteilungen mit gleichen Werten, nur im Fehlerfall mehr davon → niedrig.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:271, lib/features/duty/presentation/pages/duty_distribute_page.dart:280
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-3829883249` **Namens-Tiebreak nicht locale-aware** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:174](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts#L174) (2. Prüfung: bestätigt)
  Weiter real: Tausch-Optionen und „Dienste pro Person“ bei Gleichstand mit String.compareTo statt localeCompare (Umlaute nach Z, Kleinbuchstaben nach Großbuchstaben). Nur Reihenfolge.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:229, lib/features/duty/presentation/pages/duty_distribute_page.dart:462
- [ ] **niedrig** `duty/unavailability-modal/unavailability-modal.component` `x-1017c7460d` **Ladefehler der Regeln** [src/app/duty/unavailability-modal/unavailability-modal.component.ts:54](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/unavailability-modal/unavailability-modal.component.ts#L54) (2. Prüfung: bestätigt)
  Weiter real: Ionic Toast „Fehler beim Laden der Verfügbarkeit“, dann leere Liste mit Button „Regel hinzufügen“ / Flutter nur „Fehler: …“ im Body, ohne Button. Fehler wird in beiden gemeldet.
  Flutter: lib/features/duty/presentation/pages/unavailability_page.dart:237
- [ ] **niedrig** `duty/unavailability-modal/unavailability-modal.component` `x-21dc916f43` **Typnamen in der Regel-Liste** [src/app/duty/unavailability-modal/unavailability-modal.component.ts:62](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/unavailability-modal/unavailability-modal.component.ts#L62) (2. Prüfung: bestätigt)
  Weiter real: Regel-Liste nutzt alle Termintypen (attendanceTypesProvider), Ionic typesText nur sichtbare → Namen unsichtbarer Typen erscheinen in Flutter zusätzlich.
  Flutter: lib/features/duty/presentation/pages/unavailability_page.dart:234, lib/features/duty/presentation/pages/unavailability_page.dart:260
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-353ca926f3` **Namens-Tiebreak der Kategorien** [src/app/instruments/instrument-list/instrument-list.page.ts:150](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L150)
  Ionic: Kategorien ohne sort_order per localeCompare sortiert / Flutter: toLowerCase().compareTo (Umlaute nach Z).
  Flutter: lib/core/utils/instrument_sort.dart:79
- [ ] **niedrig** `instruments/instrument-list/instrument-list.page` `x-1f38b1bd07` **Sektionen ohne sort_order: Namensvergleich** [src/app/instruments/instrument-list/instrument-list.page.ts:150](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/instruments/instrument-list/instrument-list.page.ts#L150)
  Ionic: Kategorie-Sektionen ohne sort_order nach a.name.localeCompare(b.name) (Umlaut Ü bei U) / Flutter groupInstrumentsByCategory: toLowerCase().compareTo (Code-Einheiten, „Übrige“ hinter „Z…“). Nur bei unnummerierten Kategorien mit Umlaut am Anfang.
  Flutter: lib/core/utils/instrument_sort.dart:79
- [ ] **niedrig** `duty/duty-distribute-modal/duty-distribute-modal.component` `x-5b0a6b0909` **Verteilung zählt voll besetzte Termine und andere Dienst-Typen für „Nicht zweimal am selben Tag“** [src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:run](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/duty/duty-distribute-modal/duty-distribute-modal.component.ts:run)
  Ionic: run() filtert Termine mit occupied>=required vor distributeDuties heraus und lädt nur gewählte Typen / Flutter (SOL_FIX2): voll besetzte und nicht gewählte Dienst-Typen gehen als Slots mit open 0 ein, damit deren Personen am selben Tag nicht nochmal eingeteilt werden. Flutter besser, Vorschlag kann daher von Ionic abweichen; Leon entscheidet.
  Flutter: lib/features/duty/presentation/pages/duty_distribute_page.dart:161
