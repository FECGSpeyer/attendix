# Fix-Paket „selbstservice“

Soll: Ionic 4.19.7 (9f9b82af). Ist: Flutter 1aba6be, 2157fa0,  (normales Design).
Erzeugt mit `node tool/parity/parity.mjs fixlists` aus `docs/parity/status/`. Item-IDs siehe `ionic-inventory.json`.

## Angleichen (hoch/mittel): 17

- [ ] **hoch** `selfService/overview/overview.page` `actionsheet-1394033e` [selfService/overview/overview.page.ts:275](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/overview/overview.page.ts#L275) (2. Prüfung: bestätigt)
  Ionic (overview.page.ts:218-233): bei 'E'/'A' nur 'Abmelden'/'Verspätung eintragen' entfernt, 'Anmelden mit Notiz' bleibt; bei 'L' (Verspätung gemeldet) bleiben 'Abmelden' und 'Verspätung eintragen'; kein Header, keine Icons / Flutter (buildActions): bei isExcusedStatus (Entschuldigt und Verspätung gemeldet) nur 'Anmelden', kein 'Anmelden mit Notiz', kein 'Abmelden'/'Verspätung eintragen'; nach Frist bzw. in 'Weitere Optionen' Toast 'keine Aktionen'; Header mit Titel + Datum/Zeit, Icons. Übrige Einträge, Reihenfolge und rotes 'Abbrechen' gleich.
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:373-428, lib/features/self_service/presentation/widgets/self_service_event_actions.dart:434-477
- [ ] **hoch** `selfService/overview/overview.page` `x-9e43a66882` **Aktionsblatt bei Entschuldigt / Verspätung gemeldet** [src/app/selfService/overview/overview.page.ts:218](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/overview/overview.page.ts#L218) (2. Prüfung: bestätigt)
  Befund echt. Ionic Übersicht: Entschuldigt (E) → „Anmelden“ + „Anmelden mit Notiz“; Verspätung gemeldet (text 'L') → zusätzlich „Abmelden“ + „Verspätung eintragen“, nach Fristende bleiben diese beiden. / Flutter overviewMode: isExcusedStatus blendet „Anmelden mit Notiz“ aus und sperrt „Abmelden“/„Verspätung eintragen“ → kein direkter Wechsel von „Verspätung gemeldet“ zu Abmelden, nach Frist nur Toast „keine Aktionen“.
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:377, lib/features/self_service/presentation/widgets/self_service_event_actions.dart:391, lib/features/self_service/presentation/widgets/self_service_event_actions.dart:394
- [ ] **hoch** `selfService/signout/signout.page` `modal-ef7b9f1b` [selfService/signout/signout.page.ts:1082](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L1082) (2. Prüfung: bestätigt)
  Ionic: PlanViewer bekommt attendance aus getPersonAttendances inkl. extra_plans/duration_days (db.service.ts:2716) → bei mehrtägigen Terminen Tages-/Plan-Chips (heute vorausgewählt); defaultLive nicht gesetzt → Live-Modus nur im Zeitfenster (isLiveNow: 5 Min. vor bis 15 Min. nach Planende) / Flutter signoutEventActions.openPlan: extra_plans weder geladen (kSignoutAttendanceColumns) noch übergeben → nur der erste Plan; defaultLive = isToday → Live-Modus an jedem Termintag. Vollbild wie Ionic.
  Flutter: lib/features/self_service/presentation/pages/signout_page.dart:716, lib/features/self_service/presentation/widgets/plan_viewer_sheet.dart:384, lib/data/repositories/sign_in_out_repository.dart:21
- [ ] **hoch** `selfService/signout/signout.page` `action-89fbd54f` [selfService/signout/signout.page.html:711](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L711) (2. Prüfung: korrigiert)
  Erstprüfer: ok übersieht abweichende Schreibwirkung. Gleich: Rollen (player_planned_absence der eigenen Rolle), deaktiviert ohne Grund/Start/Ende, Insert player_absences (tenant_id, person_id, from/until, reason), Erfolgs-Toast. Ionic: entschuldigt nur die geladenen kommenden Termine current+actualAttendances (ohne nicht zugeteilte Dienste, in Dienstplan-Ansicht ohne eigene Dienste) / Flutter: alle eigenen kommenden person_attendances im Zeitraum → status 2 + Notiz auch auf diesen Zeilen. Gleiche Ursache wie x-1962646a5f (nur einmal beheben).
  Flutter: lib/features/self_service/presentation/widgets/self_service_absences.dart:361, lib/features/self_service/presentation/widgets/self_service_absences.dart:59, lib/data/repositories/player_absence_repository.dart:122, lib/data/repositories/player_absence_repository.dart:191
- [ ] **hoch** `selfService/signout/signout.page` `x-f56fb3f1cc` **Push/Deep-Link öffnet Termin ohne Dienst-Logik** [src/app/selfService/signout/signout.page.ts:581](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L581) (2. Prüfung: korrigiert)
  Befund real, Sev zu niedrig. Push "Wer springt ein?" (duty_understaffed/duty_urgent, laut duty-notify an Springer ohne duty_state): Ionic → Zeile per applyDutyView gefiltert → Sheet "Offene Dienste" mit "Übernehme ich" (take). Flutter sucht in ungefilterten signoutData → Aktionsblatt der nicht zugeteilten Dienstzeile; "Anmelden" schreibt status=Anwesend ohne duty_state → Dienst bleibt unterbesetzt, Nutzer glaubt eingesprungen zu sein (duty_filled-Push: Ionic nichts, Flutter ebenso Aktionsblatt). Eigener Dienst in Dienstplan-Ansicht: Aktionsblatt statt Scrollen, funktional gleichwertig.
  Flutter: lib/features/self_service/presentation/pages/signout_page.dart:66, lib/core/services/push/push_navigation.dart:134, lib/features/self_service/presentation/widgets/self_service_event_actions.dart:434
- [ ] **hoch** `selfService/signout/signout.page` `x-1962646a5f` **Abwesenheit: andere Zeilen entschuldigt/zurückgesetzt** [src/app/selfService/signout/signout.page.ts:1240](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L1240) (2. Prüfung: bestätigt)
  Befund real: _upcomingInRange nimmt alle eigenen kommenden person_attendances im Zeitraum (inkl. nicht zugeteilter Dienstzeilen, in Dienstplan-Ansicht auch eigene Dienste) zum Entschuldigen bzw. Zurücksetzen; Ionic nur geladene Liste nach applyDutyView/applyDutyLayout. Eigener Dienst wird in Flutter so still abgesagt (kein understaffed). Teilweise Flutter besser: Ionic bricht im "alle Termine"-Modus am ersten fremden Termin (id null) ab. Auch bei action-89fbd54f bzw. alert-cf2e9968 (dort mittel) – einmal beheben.
  Flutter: lib/data/repositories/player_absence_repository.dart:122, lib/data/repositories/player_absence_repository.dart:191, lib/data/repositories/player_absence_repository.dart:228
- [ ] **hoch** `selfService/signout/signout.page` `x-a5a4d95ac2` **Aktuelle Werke: Instrument aus anderer Instanz** [src/app/selfService/signout/signout.page.ts:1141](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L1141)
  Ionic: Rotmarkierung (hasSongNotesForPlayer) und Notenoptionen (openSongOptions) nutzen this.player.instrument (Person per appId + tenantId). / Flutter: UpcomingSongsSheet nimmt currentPlayerInstrumentProvider = player per appId ohne tenantId, limit(1). Bei Personen in mehreren Instanzen kann die Stimme einer anderen Instanz kommen → alle Werke rot, Toast "keine Noten für dein Instrument", Notenoptionen ohne eigene Stimme. Drucken nutzt die gefilterte Person (ok).
  Flutter: lib/features/self_service/data/providers/upcoming_songs_provider.dart:87, lib/features/self_service/data/providers/upcoming_songs_provider.dart:96, lib/features/self_service/presentation/widgets/upcoming_songs_sheet.dart:56, lib/features/self_service/presentation/widgets/upcoming_songs_sheet.dart:127, lib/features/self_service/presentation/widgets/upcoming_songs_sheet.dart:266
- [ ] **mittel** `selfService/overview/overview.page` `modal-44ffacb0` [selfService/overview/overview.page.html:96](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/overview/overview.page.html#L96) (2. Prüfung: bestätigt)
  Ionic: Sheet (0.6/1) mit Toolbar 'Beschreibung' + X, Inhalt als Quill-HTML (Formatierung, Links klickbar) / Flutter showEventDescriptionSheet: Bottom-Sheet mit Griff, max. 70 % Höhe, Titel des Termins, Text per QuillUtils.stripHtml als SelectableText (Fett/Listen/Links gehen verloren), kein X
  Flutter: lib/shared/widgets/event_list/excuse_reason_sheet.dart:425-449, lib/features/self_service/presentation/widgets/self_service_event_actions.dart:217-222
- [ ] **mittel** `selfService/parents/parents.page` `text-afd4ff21` [selfService/parents/parents.page.html:96](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L96) (2. Prüfung: bestätigt)
  Reihenfolge der Kinder-Chips: Ionic getPlayers (Eltern) sortiert nach Instrument, isLeader absteigend, Nachname / Flutter getChildrenForParent nur nach Nachname (Geschwister mit gleichem Nachnamen in beliebiger Reihenfolge)
  Flutter: lib/features/parents/presentation/widgets/parents_header_widgets.dart:148-154, lib/data/repositories/player_repository.dart:252-263
- [ ] **mittel** `selfService/parents/parents.page` `modal-fc6bc685` [selfService/parents/parents.page.html:163](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L163) (2. Prüfung: bestätigt)
  Ionic: Sheet (0.6/1) mit Toolbar 'Beschreibung' + X, Inhalt als Quill-HTML (Formatierung, Links klickbar) / Flutter: Bottom-Sheet mit Griff, max. 70 % Höhe, Beschreibung per stripHtml als Klartext (Fett/Listen/Links gehen verloren), kein X
  Flutter: lib/shared/widgets/event_list/excuse_reason_sheet.dart:425-449, lib/features/parents/presentation/pages/parents_portal_page.dart:121-126
- [ ] **mittel** `selfService/parents/parents.page` `x-3b9835638f` **Benachrichtigung bei Anmeldung nach 'Verspätung gemeldet'** [src/app/selfService/parents/parents.page.ts:434](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.ts#L434) (2. Prüfung: bestätigt)
  Befund echt. Ionic parents.signin: attendance ist das zusammengebaute Termin-Objekt ohne status → Typ immer 'signin' → quick-processor benachrichtigt. / Flutter: Typ je Kindstatus, bei „Verspätung gemeldet“ 'lateSignIn'; quick-processor kennt nur 'lateSignin' → keine Push-/Telegram-Benachrichtigung. DB-Schreibung gleich.
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:468, lib/data/repositories/sign_in_out_repository.dart:670
- [ ] **mittel** `selfService/parents/parents.page` `x-afb9c7a207` **Reihenfolge der Kinder** [src/app/services/db.service.ts:1586](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/db.service.ts#L1586) (2. Prüfung: bestätigt)
  Befund echt. Ionic getPlayers (PARENT): order instrument, isLeader desc, lastName; Kinder je Termin in dieser Reihenfolge (stabile Sortierung). / Flutter getChildrenForParent nur order lastName; Kinder je Termin in DB-Reihenfolge von getPersonAttendancesForPersons (nur nach Termin-Datum sortiert).
  Flutter: lib/data/repositories/player_repository.dart:222, lib/features/parents/data/providers/parents_providers.dart:254
- [ ] **mittel** `selfService/signout/signout.page` `alert-cf2e9968` [selfService/signout/signout.page.ts:1292](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L1292) (2. Prüfung: bestätigt)
  Titel 'Abwesenheit löschen', Text, 'Abbrechen'/'Löschen' (destruktiv) gleich (DialogHelper.showConfirmation, selfService-Text). Wirkung abweichend: Ionic setzt nur Zeilen aus currentAttendance + actualAttendances zurück (ohne nicht zugeteilte Dienste, in der Dienstplan-Ansicht ohne eigene Dienste) / Flutter resetExcusedAttendances: alle eigenen kommenden person_attendances der Instanz im Zeitraum mit Entschuldigt + Notiz = Grund → Standardstatus; DB-Abweichung als hoch im extra 'Abwesenheit: andere Zeilen' (b15).
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:248, lib/data/repositories/player_absence_repository.dart:228, lib/features/self_service/presentation/widgets/self_service_absences.dart:184
- [ ] **mittel** `selfService/signout/signout.page` `action-47659591` [selfService/signout/signout.page.html:108](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L108) (2. Prüfung: bestätigt)
  Ionic handleRefresh: getAttendances (inkl. loadOpenDuties → Dienst-Termine neu) + Aufgaben / Flutter _refresh: invalidiert signoutData, Person, Werke, Aufgaben, aber nicht upcomingDutyTermineProvider (myDutyOverviewProvider baut nur mit dem gecachten Ergebnis neu) → 'Bitte bestätigen', 'Offene Dienste', 'Meine Dienste', Zähler bleiben nach Pull-to-Refresh veraltet.
  Flutter: lib/features/self_service/presentation/pages/signout_page.dart:87, lib/features/self_service/presentation/pages/signout_page.dart:259
- [ ] **mittel** `selfService/signout/signout.page` `modal-819b10ac` [selfService/signout/signout.page.html:323](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L323) (2. Prüfung: bestätigt)
  Ionic: Sheet 60 % mit Toolbar ("Beschreibung" + X) und quill-view, d. h. formatiertes HTML (fett, Listen, anklickbare Links) / Flutter: Sheet mit Griff, Titel als Text, Beschreibung per QuillUtils.stripHtml als reiner Text (Formatierung weg, Links nicht anklickbar).
  Flutter: lib/shared/widgets/event_list/excuse_reason_sheet.dart:425
- [ ] **mittel** `selfService/signout/signout.page` `text-7ab3ea5e` [selfService/signout/signout.page.html:490](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L490) (2. Prüfung: bestätigt)
  Ionic statusLabelOf/statusColorOf: zugeteilter, unbestätigter Dienst (duty_state requested) → Pill "Bitte bestätigen" in Orange / Flutter: immer EventPill.status(att.status) → z. B. "Neutral" grau.
  Flutter: lib/features/self_service/presentation/pages/signout_page.dart:501
- [ ] **mittel** `selfService/signout/signout.page` `action-836ea596` [selfService/signout/signout.page.html:530](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L530) (2. Prüfung: bestätigt)
  Zeile, Dienst-Tag, Meta, Info-Text, Chips, "Nicht eingeladen" und Tippen → Aktionsblatt gleich. Ionic: unbestätigter zugeteilter Dienst zeigt Pill "Bitte bestätigen" (orange) / Flutter: normale Status-Pill (z. B. "Neutral").
  Flutter: lib/features/self_service/presentation/pages/signout_page.dart:525, lib/features/self_service/presentation/pages/signout_page.dart:550

## Flutter besser – Leon entscheidet: 13

- [ ] **niedrig** `selfService/overview/overview.page` `text-78132b6e` [selfService/overview/overview.page.html:78](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/overview/overview.page.html#L78) (2. Prüfung: bestätigt)
  Flutter besser: Ionic zeigt die Karte mit Spinner und 'Termine werden geladen...' bei jedem Neuladen (Pull-to-Refresh, nach Zusagen/Absagen/Notiz) und blendet Zusammenfassung und Listen solange aus / Flutter nur beim ersten Laden, beim Neuladen bleibt die Liste stehen
  Flutter: lib/features/self_service/presentation/pages/self_service_overview_page.dart:150-167
- [ ] **niedrig** `selfService/signout/signout.page` `field-4434ae39` [selfService/signout/signout.page.html:644](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L644)
  Flutter besser: Kalender erst ab heute (vergangene Daten nicht wählbar) / Ionic ion-datetime ohne min, vergangene "bis"-Daten möglich (führen zur sofortigen Auto-Reaktivierung).
  Flutter: lib/features/self_service/presentation/widgets/self_service_absences.dart:455
- [ ] **niedrig** `selfService/overview/overview.page` `x-68b090e7ef` **Typfilter im Aktionsblatt** [src/app/selfService/overview/overview.page.ts:218-240](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/overview/overview.page.ts#L218-240)
  Flutter besser: Ionic prüft available_statuses nur in einer else-if-Kette (nur wenn Anmelden möglich; 'Verspätung' ungeprüft, wenn 'Entschuldigt' fehlt; bei Zugesagt oder abgelaufener Frist gar nicht; in 'Weitere Optionen' bleibt 'Abmelden', wenn der Typ 'Entschuldigt' nicht erlaubt) → zeigt gesperrte Status-Aktionen / Flutter filtert immer nach den erlaubten Status des Typs
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:146-150, lib/features/self_service/presentation/widgets/self_service_event_actions.dart:395-400
- [ ] **niedrig** `selfService/overview/overview.page` `x-ef8455052e` **Archivierte Termine** [src/app/services/db.service.ts:4172](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/db.service.ts#L4172)
  Flutter besser: Ionic lädt `archived` nicht mit (Select ohne archived), der Rollenfilter greift daher nie → archivierte Termine für alle Rollen sichtbar und im Prozentwert / Flutter lädt archived und blendet sie für Nicht-Admins/-Verantwortliche aus
  Flutter: lib/data/repositories/sign_in_out_repository.dart:29-32, lib/data/repositories/sign_in_out_repository.dart:625
- [ ] **niedrig** `selfService/overview/overview.page` `x-300001854a` **Person je Instanz** [src/app/services/db.service.ts:4053](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/db.service.ts#L4053)
  Flutter besser: Ionic getPersonIdForTenant mit .single() → bei mehreren verknüpften player-Zeilen in einer Instanz fehlen deren Termine ganz / Flutter wählt die aktive Zeile (nicht pending/left)
  Flutter: lib/data/repositories/sign_in_out_repository.dart:597-603
- [ ] **niedrig** `selfService/overview/overview.page` `x-b53add21cb` **changed_by bei Abmeldung** [src/app/services/sign-in-out/sign-in-out.service.ts:23](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/sign-in-out/sign-in-out.service.ts#L23)
  Flutter besser: Ionic signout übergibt keine userId → changed_by = null (Dirigent sieht 'Status wurde nicht geändert') / Flutter schreibt changed_by = aktueller Nutzer
  Flutter: lib/data/repositories/sign_in_out_repository.dart:104-113
- [ ] **niedrig** `selfService/overview/overview.page` `x-5cc345ba99` **Dienst-Sync bei Terminen anderer Instanzen** [src/app/utilities/db-helpers.ts:343](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/utilities/db-helpers.ts#L343)
  Flutter besser: Ionic syncDutyWithStatus kennt nur die Dienst-Typen der aktuellen Instanz (getDutyTypeIds) → Zusagen zu einem angefragten Dienst einer anderen Instanz bestätigt ihn nicht / Flutter prüft duty_mode des Termintyps und setzt duty_state=confirmed auch dort
  Flutter: lib/data/repositories/sign_in_out_repository.dart:141-162, lib/data/repositories/sign_in_out_repository.dart:183-185
- [ ] **niedrig** `selfService/overview/overview.page` `x-393643e049` **Fehlerbehandlung** [src/app/selfService/overview/overview.page.ts:307](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/overview/overview.page.ts#L307)
  Flutter besser: Ionic zeigt bei Fehlern beim Laden/Anmelden/Abmelden/Notiz nichts (unbehandelte Exception, kein Toast) / Flutter zeigt Fehleransicht mit 'Erneut versuchen' bzw. Toasts 'Anmeldung fehlgeschlagen…', 'Abmeldung fehlgeschlagen…', 'Notiz konnte nicht gespeichert werden.'
  Flutter: lib/features/self_service/presentation/pages/self_service_overview_page.dart:169-179, lib/features/self_service/presentation/widgets/self_service_event_actions.dart:274-283, lib/features/self_service/presentation/widgets/self_service_event_actions.dart:338-342
- [ ] **niedrig** `selfService/parents/parents.page` `x-624a9ec520` **changed_by bei Abmeldung** [src/app/services/sign-in-out/sign-in-out.service.ts:23](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/sign-in-out/sign-in-out.service.ts#L23)
  Flutter besser: Ionic signout (Eltern) übergibt keine userId → changed_by = null / Flutter schreibt changed_by = aktueller Nutzer
  Flutter: lib/data/repositories/sign_in_out_repository.dart:104-113
- [ ] **niedrig** `selfService/parents/parents.page` `x-e6cab2d2c9` **Fehlerbehandlung** [src/app/selfService/parents/parents.page.ts:432](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.ts#L432)
  Flutter besser: Ionic bricht bei Fehlern ohne Rückmeldung ab (kein Toast) / Flutter zeigt 'Anmeldung fehlgeschlagen…'/'Abmeldung fehlgeschlagen…' bzw. Fehleransicht mit 'Erneut versuchen'; Instanzwechsel-Fehler als Toast
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:474-480, lib/features/parents/presentation/pages/parents_portal_page.dart:497-499, lib/features/parents/presentation/pages/parents_portal_page.dart:537-557
- [ ] **niedrig** `selfService/signout/signout.page` `x-e518bd9a17` **Sortierung am selben Tag** [src/app/selfService/signout/signout.page.ts:336](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L336)
  Flutter besser: Ionic sortiert nur nach date (gleicher Tag in DB-Reihenfolge) / Flutter nach Datum + Startzeit, dann eigene Termine zuerst, dann attendance_id.
  Flutter: lib/core/providers/signout_providers.dart:98
- [ ] **niedrig** `selfService/signout/signout.page` `x-db4615b9c2` **changed_by bei Abmeldung** [src/app/services/sign-in-out/sign-in-out.service.ts:23](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/sign-in-out/sign-in-out.service.ts#L23)
  Flutter besser: Ionic db.signout schreibt changed_by = null (kein userId) / Flutter schreibt changed_by = angemeldeter Nutzer.
  Flutter: lib/data/repositories/sign_in_out_repository.dart:201, lib/data/repositories/sign_in_out_repository.dart:111
- [ ] **niedrig** `selfService/signout/signout.page` `x-97da4e3911` **Fehler-Toasts und Leerzustände** [src/app/selfService/signout/signout.page.ts:227](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L227)
  Flutter besser: Flutter meldet fehlgeschlagene Zusage/Absage/Notiz/Anmeldefelder/Instanzwechsel per Fehler-Toast (Ionic: unbehandelte Exception, kein Hinweis) und zeigt "Keine Termine gefunden" bzw. Hinweis ohne verknüpfte Person (Ionic: leere Seite).
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:281, lib/features/self_service/presentation/widgets/self_service_event_actions.dart:341, lib/features/self_service/presentation/pages/signout_page.dart:113, lib/features/self_service/presentation/pages/signout_page.dart:281, lib/features/self_service/presentation/pages/signout_page.dart:327

## Kleinigkeiten (niedrig): 55

- [ ] **niedrig** `selfService/overview/overview.page` `action-aabe41a2` [selfService/overview/overview.page.html:102](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/overview/overview.page.html#L102) (2. Prüfung: bestätigt)
  Kein Schließen-Button (X) im Beschreibungs-Sheet; schließen nur per Wischen/Tippen daneben
- [ ] **niedrig** `selfService/overview/overview.page` `action-3ebb3e71` [selfService/overview/overview.page.html:191](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/overview/overview.page.html#L191)
  Bedingungen/Funktion gleich. Ionic: aktiver Zustand (zugesagt) ist zugleich disabled → grün gefüllt mit 50 % Deckkraft / Flutter: grün gefüllt in voller Farbe, Tippen wirkungslos
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:171-176, lib/shared/widgets/event_list/event_list_widgets.dart:856-866
- [ ] **niedrig** `selfService/overview/overview.page` `action-d9485f56` [selfService/overview/overview.page.html:194](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/overview/overview.page.html#L194)
  Bedingungen/Funktion gleich. Ionic: 'Verspätung gemeldet' → rosa gefüllt, aber disabled (gedimmt) / Flutter: rosa gefüllt in voller Farbe, Tippen wirkungslos
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:177-183, lib/shared/widgets/event_list/event_list_widgets.dart:856-866
- [ ] **niedrig** `selfService/overview/overview.page` `action-b04641d5` [selfService/overview/overview.page.html:198](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/overview/overview.page.html#L198) (2. Prüfung: bestätigt)
  Bedingungen/Funktion gleich. Ionic: 'Entschuldigt' → gelb, aber disabled (gedimmt) / Flutter EventActionButton: aktiv gelb gefüllt in voller Farbe, onPressed ?? () {} → Tippen wirkungslos
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:184-190, lib/shared/widgets/event_list/event_list_widgets.dart:856-866
- [ ] **niedrig** `selfService/parents/parents.page` `loading-2ab41b5d` [selfService/parents/parents.page.ts:86](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.ts#L86)
  Ionic: blockierendes Lade-Overlay (max. 3 s) während des Instanzwechsels / Flutter: kein Overlay, Wechsel ohne Ladeanzeige
  Flutter: lib/features/parents/presentation/widgets/parents_header_widgets.dart:87-106
- [ ] **niedrig** `selfService/parents/parents.page` `actionsheet-da064539` [selfService/parents/parents.page.ts:416](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.ts#L416)
  Einträge, Reihenfolge und Bedingungen gleich (Anmelden/Abmelden/Verspätung eintragen je Kindstatus und Typ, Ablaufplan anzeigen, Beschreibung anzeigen, Anhang öffnen, Navigation öffnen, rotes Abbrechen). Ionic: ohne Header und Icons / Flutter: Header 'Vorname · Titel' bzw. Titel plus Datum/Zeit/Ort, Icons
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:399-459
- [ ] **niedrig** `selfService/parents/parents.page` `text-525b7dae` [selfService/parents/parents.page.html:135](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L135)
  Gruppenkopf 'TT.MM.JJJJ | Titel': Ionic: Titel = typeInfo oder Typname auch bei hide_name (attType-Join in getPersonAttendances ohne hide_name) / Flutter: bei hide_name ohne typeInfo das Datum (z. B. 'So., 20.10.2026'); Fallback-Datum in Flutter ohne Mehrtages-Spanne
  Flutter: lib/features/parents/data/providers/parents_providers.dart:401-411
- [ ] **niedrig** `selfService/parents/parents.page` `action-3365e82a` [selfService/parents/parents.page.html:140](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L140) (2. Prüfung: bestätigt)
  'Nr. Name', 'Dirigent: …', Download-Icon und Link öffnen gleich. Ionic: nur Zeilen mit Link sind Buttons (iOS-Chevron) / Flutter: alle Zeilen tippbar mit iOS-Chevron, ohne Link wirkungslos
  Flutter: lib/features/parents/presentation/widgets/parents_header_widgets.dart:265-283
- [ ] **niedrig** `selfService/parents/parents.page` `action-838329cd` [selfService/parents/parents.page.html:169](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L169) (2. Prüfung: bestätigt)
  Kein Schließen-Button (X) im Beschreibungs-Sheet; schließen nur per Wischen/Tippen daneben
- [ ] **niedrig** `selfService/parents/parents.page` `text-ec0de4fb` [selfService/parents/parents.page.html:209](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L209)
  Ionic: Titel = typeInfo oder Typname auch bei hide_name (attType-Join in getPersonAttendances ohne hide_name) / Flutter: bei hide_name ohne typeInfo das Datum (z. B. 'So., 20.10.2026')
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:58-63, lib/features/parents/presentation/pages/parents_portal_page.dart:258
- [ ] **niedrig** `selfService/parents/parents.page` `action-ea934dc1` [selfService/parents/parents.page.html:219](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L219)
  Zeile (Initialen, Vorname, 'Notiz: …', Status-Pill) und Aktionsblatt gleich. Funktion gleich; Reihenfolge der Kinder je Termin: Ionic nach Kinder-Sortierung (Instrument, isLeader, Nachname) / Flutter Reihenfolge der DB-Zeilen (nicht garantiert gleich)
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:264-271, lib/features/parents/presentation/pages/parents_portal_page.dart:561-621
- [ ] **niedrig** `selfService/parents/parents.page` `text-45095c3b` [selfService/parents/parents.page.html:252](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L252) (2. Prüfung: bestätigt)
  Ionic: Titel = typeInfo oder Typname auch bei hide_name (attType-Join in getPersonAttendances ohne hide_name) / Flutter: bei hide_name ohne typeInfo das Datum (z. B. 'So., 20.10.2026')
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:58-63, lib/features/parents/presentation/pages/parents_portal_page.dart:294
- [ ] **niedrig** `selfService/parents/parents.page` `action-b0f208df` [selfService/parents/parents.page.html:264](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L264)
  Chip 'Initialen Vorname · Status' öffnet Aktionsblatt des Kindes. Funktion gleich; Reihenfolge der Kinder je Termin: Ionic nach Kinder-Sortierung (Instrument, isLeader, Nachname) / Flutter Reihenfolge der DB-Zeilen (nicht garantiert gleich)
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:313-320, lib/features/parents/presentation/pages/parents_portal_page.dart:623-679
- [ ] **niedrig** `selfService/parents/parents.page` `text-45095c3b-2` [selfService/parents/parents.page.html:288](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L288) (2. Prüfung: bestätigt)
  Ionic: Titel = typeInfo oder Typname auch bei hide_name (attType-Join in getPersonAttendances ohne hide_name) / Flutter: bei hide_name ohne typeInfo das Datum (z. B. 'So., 20.10.2026')
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:58-63, lib/features/parents/presentation/pages/parents_portal_page.dart:333
- [ ] **niedrig** `selfService/parents/parents.page` `text-cb64c81a` [selfService/parents/parents.page.html:294](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L294)
  'Vorname · Status' (vergangene Form) gleich. Funktion gleich; Reihenfolge der Kinder je Termin: Ionic nach Kinder-Sortierung (Instrument, isLeader, Nachname) / Flutter Reihenfolge der DB-Zeilen (nicht garantiert gleich)
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:344-349
- [ ] **niedrig** `selfService/signout/signout.page` `loading-6042fa43` [selfService/signout/signout.page.ts:126](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L126) (2. Prüfung: bestätigt)
  Ionic: blockierendes Lade-Overlay während setTenant + Navigation / Flutter _switchTenant (über TenantSwitcherTitle): kein Overlay, Wechsel ohne Sperre; bei Fehler Toast signoutFlutterSwitchTenantFailed.
  Flutter: lib/features/self_service/presentation/pages/signout_page.dart:95
- [ ] **niedrig** `selfService/signout/signout.page` `loading-3ab7973e` [selfService/signout/signout.page.ts:228](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L228)
  Ionic: Lade-Overlay (max. 10 s) während Absage/Verspätung gespeichert wird / Flutter: kein blockierendes Overlay (submitSignout speichert im Hintergrund, danach Toast).
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:265, lib/core/providers/signout_providers.dart:284
- [ ] **niedrig** `selfService/signout/signout.page` `actionsheet-6737d9dc` [selfService/signout/signout.page.ts:824](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L824)
  Einträge, Reihenfolge und Filterregeln (Zusagen/Abmeldung zurücknehmen, Anmelden mit Notiz, Abmelden, Verspätung eintragen, Anmeldefelder anpassen, Notiz anpassen, Werke/Ablaufplan/Beschreibung/Anhang/Navigation/Dateiablage, "Abbrechen" rot) gleich. Ionic: Aktionsblatt ohne Kopf und ohne Icons / Flutter: Kopf mit Termin-Titel + Meta-Zeile und Icons je Eintrag. Randfall: "Ablaufplan anzeigen" Ionic bei share_plan && plan, Flutter nur wenn der Plan Felder hat.
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:373, lib/features/self_service/presentation/widgets/self_service_event_actions.dart:461
- [ ] **niedrig** `selfService/signout/signout.page` `toast-36f88117` [selfService/signout/signout.page.ts:916](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L916)
  Einzelfeld-Dialog: gleicher Warn-Toast. Ionic: auch im Anmeldefelder-Modal (2+ Felder) Toast "Bitte "{field}" ausfüllen" / Flutter: dort roter Hinweistext im Sheet statt Toast.
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:310, lib/shared/widgets/event_list/excuse_reason_sheet.dart:305
- [ ] **niedrig** `selfService/signout/signout.page` `loading-45966010` [selfService/signout/signout.page.ts:1246](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L1246)
  Ionic: Lade-Overlay während Abwesenheit gespeichert und Termine entschuldigt werden / Flutter: kein blockierendes Overlay.
  Flutter: lib/features/self_service/presentation/widgets/self_service_absences.dart:59
- [ ] **niedrig** `selfService/signout/signout.page` `loading-19b27361` [selfService/signout/signout.page.ts:1301](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L1301)
  Ionic: Lade-Overlay beim Löschen der Abwesenheit / Flutter: kein blockierendes Overlay.
  Flutter: lib/features/people/presentation/widgets/planned_absences.dart:248
- [ ] **niedrig** `selfService/signout/signout.page` `action-cbdd0bb5` [selfService/signout/signout.page.html:114](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L114) (2. Prüfung: bestätigt)
  Ionic: Bild lädt nicht → Platzhalter-Avatar / Flutter: Platzhalter nur bei leerem img; bei kaputter URL bleibt der Kreis leer (kein onBackgroundImageError).
  Flutter: lib/features/self_service/presentation/pages/signout_page.dart:357
- [ ] **niedrig** `selfService/signout/signout.page` `text-1871da89` [selfService/signout/signout.page.html:188](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L188)
  Ionic: Datumskachel (Wochentag + Tag) links / Flutter: keine Kachel, Datum steht als "Di, 05.11." in der Textzeile.
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:99, lib/features/duty/presentation/widgets/self_service_duty_section.dart:272
- [ ] **niedrig** `selfService/signout/signout.page` `text-ed1a1b2e` [selfService/signout/signout.page.html:189](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L189) (2. Prüfung: bestätigt)
  Ionic: Datumskachel mit Tag / Flutter: keine Kachel, Tag in der Textzeile "Di, 05.11. · 19:00 Uhr".
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:99, lib/features/duty/presentation/widgets/self_service_duty_section.dart:272
- [ ] **niedrig** `selfService/signout/signout.page` `text-76bcf174` [selfService/signout/signout.page.html:193](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L193) (2. Prüfung: bestätigt)
  Ionic getEventMeta(att, true, false): "Di., 05.11.2026 · 19:00–21:00" / Flutter _dateLine: "Di, 05.11. · 19:00 Uhr" (ohne Jahr, ohne Endzeit).
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:99, lib/features/duty/presentation/widgets/self_service_duty_section.dart:278
- [ ] **niedrig** `selfService/signout/signout.page` `text-9febe693` [selfService/signout/signout.page.html:223](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L223)
  Ionic: nur dutyMeta "19:00 · 1 von 2 besetzt" (kein Datum im Modal) / Flutter: zusätzlich Datum vorne "Di, 05.11. · …".
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:347
- [ ] **niedrig** `selfService/signout/signout.page` `text-b04b96f3` [selfService/signout/signout.page.html:270](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L270) (2. Prüfung: bestätigt)
  Ionic Gruppenkopf '05.11.2026 | Probe' (dateFmt + getEventTitle) / Flutter IonListHeader 'Heute · Probe', 'Morgen · …' bzw. 'Mi, 5. Nov · Probe' (DateHelper.getReadableDate + eventTitle).
  Flutter: lib/features/self_service/presentation/widgets/upcoming_songs_sheet.dart:175
- [ ] **niedrig** `selfService/signout/signout.page` `action-5aeab82c` [selfService/signout/signout.page.html:329](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L329)
  Ionic: X-Button in der Toolbar / Flutter: kein Schließen-Button, nur Wischen bzw. Tippen außerhalb.
  Flutter: lib/shared/widgets/event_list/excuse_reason_sheet.dart:425
- [ ] **niedrig** `selfService/signout/signout.page` `text-341d2a0e` [selfService/signout/signout.page.html:374](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L374) (2. Prüfung: korrigiert)
  Rollen/Bedingung (useDutyView, Dienst vorhanden) gleich, aber Darstellung abweichend, vom Erstprüfer übersehen. Ionic: „NÄCHSTER DIENST“ als .ev-month-Label (0.8rem, semibold, Großbuchstaben, grau, wie „Heute“/Monatsköpfe) / Flutter: _SectionTitle „Nächster Dienst“ fett in Textfarbe (titleMedium). EventMonthHeader wäre die Entsprechung.
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:130, lib/features/duty/presentation/widgets/self_service_duty_section.dart:455, lib/core/providers/duty_providers.dart:131, lib/core/router/route_access.dart:73
- [ ] **niedrig** `selfService/signout/signout.page` `text-5aa30f5e` [selfService/signout/signout.page.html:378](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L378)
  Ionic: Datumskachel (Wochentag) / Flutter: keine Kachel, Datum in der Textzeile "Di, 05.11. · 19:00 Uhr".
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:143
- [ ] **niedrig** `selfService/signout/signout.page` `text-0a41e2ca` [selfService/signout/signout.page.html:379](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L379)
  Ionic: Datumskachel (Tag) / Flutter: keine Kachel, Tag in der Textzeile.
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:143
- [ ] **niedrig** `selfService/signout/signout.page` `text-4beefbd6` [selfService/signout/signout.page.html:383](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L383)
  Ionic "Di., 05.11.2026 · 19:00–21:00" / Flutter "Di, 05.11. · 19:00 Uhr" (ohne Jahr/Endzeit).
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:143, lib/features/duty/presentation/widgets/self_service_duty_section.dart:278
- [ ] **niedrig** `selfService/signout/signout.page` `text-74a3b56c` [selfService/signout/signout.page.html:400](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L400) (2. Prüfung: korrigiert)
  Erstprüfer übersah die Darstellung. Text/Bedingung gleich (immer in der Dienstplan-Ansicht, keine Rollenprüfung). Ionic: .ev-section h2 1.35rem fett wie „Anstehend“/„Vergangen“ / Flutter: _SectionTitle titleMedium (16) fett – sichtbar kleiner als die übrigen Abschnittsköpfe der Seite (EventSectionHeader).
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:170, lib/features/duty/presentation/widgets/self_service_duty_section.dart:468, lib/core/providers/duty_providers.dart:131
- [ ] **niedrig** `selfService/signout/signout.page` `text-5a0ac94b` [selfService/signout/signout.page.html:409](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L409)
  Ionic: Datumskachel links / Flutter: keine Kachel, "Di, 05.11." am Anfang der Untertitelzeile.
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:190
- [ ] **niedrig** `selfService/signout/signout.page` `text-ceeea6ff` [selfService/signout/signout.page.html:410](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L410) (2. Prüfung: bestätigt)
  Ionic: Datumskachel (Tag) / Flutter: Tag in der Untertitelzeile.
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:190
- [ ] **niedrig** `selfService/signout/signout.page` `text-4dca8fd9` [selfService/signout/signout.page.html:416](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L416) (2. Prüfung: bestätigt)
  Ionic: 'Dringend' rot und fett (.duty-urgent) vor der Meta-Zeile / Flutter: 'Dringend' als normaler Text nach dem Datum ('Di, 05.11. · Dringend · 19:00 · …').
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:190
- [ ] **niedrig** `selfService/signout/signout.page` `action-1351f460` [selfService/signout/signout.page.html:421](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L421) (2. Prüfung: korrigiert)
  Erstprüfer übersah die Darstellung. Wirkung gleich (RPC duty_take + notify filled, Toasts ok/voll/nicht erlaubt), Rollen gleich. Farbe abweichend: Ionic ion-button small solid primary (petrol, weiße Schrift) / Flutter FilledButton.tonal → secondaryContainer hellblau (#6FD4FF) mit dunkelblauer Schrift.
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:191, lib/core/theme/app_theme.dart:166, lib/features/duty/presentation/widgets/duty_actions.dart:157, lib/core/providers/duty_providers.dart:131
- [ ] **niedrig** `selfService/signout/signout.page` `text-1914b2e8` [selfService/signout/signout.page.html:432](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L432) (2. Prüfung: korrigiert)
  Erstprüfer übersah die Darstellung. Bedingung (weitere bestätigte Dienste nach dem nächsten) gleich. Ionic: .ev-section h2 1.35rem fett / Flutter: _SectionTitle titleMedium (16) fett – kleiner als „Anstehend“/„Vergangen“.
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:205, lib/features/duty/presentation/widgets/self_service_duty_section.dart:468, lib/core/providers/duty_providers.dart:131
- [ ] **niedrig** `selfService/signout/signout.page` `text-5f79bd8f` [selfService/signout/signout.page.html:433](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L433) (2. Prüfung: korrigiert)
  Erstprüfer übersah die Darstellung. Zahl gleich (bestätigte Dienste ohne den nächsten). Ionic: .ev-section__count als graue Zahl (0.95rem) neben der Überschrift wie bei „Anstehend“ / Flutter: farbige Primary-Pill (DutyPill).
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:205, lib/features/duty/presentation/widgets/self_service_duty_section.dart:471, lib/core/providers/duty_providers.dart:131
- [ ] **niedrig** `selfService/signout/signout.page` `action-afccefe5` [selfService/signout/signout.page.html:437](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L437)
  Tippen → Aktionsblatt und Pill "bestätigt" gleich. Ionic: Datumskachel, Meta "19:00–21:00 · Ort · mit Namen" / Flutter: ohne Kachel, "Di, 05.11. · 19:00 Uhr · mit Namen" (ohne Ort, ohne Endzeit).
  Flutter: lib/features/duty/presentation/widgets/self_service_duty_section.dart:211, lib/features/self_service/presentation/pages/signout_page.dart:305
- [ ] **niedrig** `selfService/signout/signout.page` `action-22f32baf` [selfService/signout/signout.page.html:505](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L505) (2. Prüfung: bestätigt)
  Bedingungen/Wirkung gleich. Ionic: bei Zugesagt gefüllt grün, aber disabled (halbe Deckkraft) / Flutter: gefüllt grün in voller Deckkraft, Tippen ohne Wirkung.
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:171, lib/shared/widgets/event_list/event_list_widgets.dart:858
- [ ] **niedrig** `selfService/signout/signout.page` `action-c9b28995` [selfService/signout/signout.page.html:508](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L508)
  Bedingungen/Wirkung gleich. Ionic: bei "Verspätung gemeldet" gefüllt rosa + disabled (halbe Deckkraft) / Flutter: gefüllt rosa in voller Deckkraft, Tippen ohne Wirkung.
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:177, lib/shared/widgets/event_list/event_list_widgets.dart:858
- [ ] **niedrig** `selfService/signout/signout.page` `action-b6ce9099` [selfService/signout/signout.page.html:512](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L512)
  Bedingungen/Wirkung gleich. Ionic: bei Entschuldigt gefüllt orange + disabled (halbe Deckkraft) / Flutter: gefüllt orange in voller Deckkraft, Tippen ohne Wirkung.
  Flutter: lib/features/self_service/presentation/widgets/self_service_event_actions.dart:184, lib/shared/widgets/event_list/event_list_widgets.dart:858
- [ ] **niedrig** `selfService/signout/signout.page` `text-70ddef87` [selfService/signout/signout.page.html:573](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L573)
  Ionic: jeder Punkt hat title-Tooltip "Datum: Status" und die Reihe aria-label "Status der letzten Termine" / Flutter: Punkte ohne Tooltip/Semantik.
  Flutter: lib/features/self_service/presentation/pages/signout_page.dart:572, lib/shared/widgets/event_list/event_list_widgets.dart:925
- [ ] **niedrig** `selfService/signout/signout.page` `field-4c957531` [selfService/signout/signout.page.html:699](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L699)
  Erster/zweiter Tipp mit Tausch gleich. Ionic: gewählter Zeitraum im Kalender farbig hervorgehoben, keine Datumsgrenzen / Flutter CalendarDatePicker: nur ein markierter Tag, keine Bereichs-Hervorhebung, Auswahl nur Vorjahr bis +5 Jahre.
  Flutter: lib/features/self_service/presentation/widgets/self_service_absences.dart:343, lib/features/self_service/presentation/widgets/self_service_absences.dart:226
- [ ] **niedrig** `selfService/signout/signout.page` `modal-76fb71e5` [selfService/signout/signout.page.html:721](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L721) (2. Prüfung: bestätigt)
  Ionic: Sheet 85 % (Breakpoints 0/0.85/1), backdropDismiss=false in beiden Modi / Flutter showRegistrationFieldsSheet: Sheet in Inhaltshöhe mit Griff, isDismissible nur im Bearbeiten-Modus → dort durch Tippen außerhalb schließbar.
  Flutter: lib/shared/widgets/event_list/excuse_reason_sheet.dart:238
- [ ] **niedrig** `selfService/signout/signout.page` `action-e5b8dd6d` [selfService/signout/signout.page.html:730](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.html#L730)
  Ionic: "Abbrechen" nur im Bearbeiten-Modus / Flutter: "Abbrechen" auch im Anmelde-Modus.
  Flutter: lib/shared/widgets/event_list/excuse_reason_sheet.dart:393
- [ ] **niedrig** `selfService/overview/overview.page` `x-97aaedb765` **Instanzfarben** [src/app/services/db.service.ts:4025](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/db.service.ts#L4025)
  Ionic: 16 Farben inkl. #FFB300 (Amber) / Flutter: 15 Farben → ab der 16. Mitgliedschaft andere Farbe (Modulo 15 statt 16)
  Flutter: lib/data/repositories/sign_in_out_repository.dart:45-69
- [ ] **niedrig** `selfService/parents/parents.page` `x-4d33ddc0eb` **Titel ignoriert hide_name in Ionic** [src/app/services/db.service.ts:2716](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/db.service.ts#L2716)
  Ionic: Titel = typeInfo oder Typname auch bei hide_name (attType-Join in getPersonAttendances ohne hide_name) / Flutter: bei hide_name ohne typeInfo das Datum (z. B. 'So., 20.10.2026'); betrifft Heute-Karte, anstehende/vergangene Termine, Werke-Sheet und 'Aktuelle Werke'
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:58-63, lib/features/parents/data/providers/parents_providers.dart:401-406
- [ ] **niedrig** `selfService/parents/parents.page` `x-00d4ebd018` **Welcher laufende Termin auf der Heute-Karte** [src/app/selfService/parents/parents.page.ts:196](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.ts#L196)
  Ionic: bei mehreren laufenden Terminen der zuletzt begonnene (Liste nach Datum absteigend) / Flutter: der früheste; die übrigen laufenden fehlen in beiden
  Flutter: lib/features/parents/data/providers/parents_providers.dart:359-362, lib/features/parents/presentation/pages/parents_portal_page.dart:148
- [ ] **niedrig** `selfService/parents/parents.page` `x-ca932f307d` **Zeitraum der Termine** [src/app/services/db.service.ts:2718](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/db.service.ts#L2718)
  Ionic: nur Termine nach dem 01.01.2020 (getPersonAttendances all=true) / Flutter: ohne Untergrenze (ältere Termine zählen in 'Vergangen' und im Prozentwert)
  Flutter: lib/data/repositories/attendance_repository.dart:383-400
- [ ] **niedrig** `selfService/parents/parents.page` `x-d0a0a6c0b4` **Leere Zustände** [src/app/selfService/parents/parents.page.html:89](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.html#L89)
  Ionic: ohne Kinder bzw. ohne Termine einfach leere Seite / Flutter: 'Keine Kinder gefunden' + 'Es wurden keine Kinder mit Ihrem Eltern-Account verknüpft.' bzw. 'Keine Termine gefunden'
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:200-219, lib/features/parents/presentation/pages/parents_portal_page.dart:364-372
- [ ] **niedrig** `selfService/parents/parents.page` `x-fa926ddb86` **Ablaufplan ohne Felder** [src/app/selfService/parents/parents.page.ts:380](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/parents/parents.page.ts#L380)
  Ionic: 'Ablaufplan anzeigen' im Aktionsblatt (share_plan && plan) öffnet den Viewer auch bei leerem Plan / Flutter: Toast 'Kein Ablaufplan verfügbar.'
  Flutter: lib/features/parents/presentation/pages/parents_portal_page.dart:510-514
- [ ] **niedrig** `selfService/signout/signout.page` `x-1a458121e1` **Offene-Dienste-Sheet bleibt offen** [src/app/selfService/signout/signout.page.ts:576](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L576)
  Ionic takeDuty: schließt das Modal, wenn danach keine offenen Dienste mehr da sind / Flutter: Sheet bleibt offen und zeigt "Gerade sind alle Dienste besetzt. Danke!".
  Flutter: lib/features/duty/presentation/widgets/duty_actions.dart:157, lib/features/duty/presentation/widgets/self_service_duty_section.dart:317
- [ ] **niedrig** `selfService/signout/signout.page` `x-a20a83b4d6` **Aktuelle Werke aus ungefilterten Terminen** [src/app/selfService/signout/signout.page.ts:372](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/signout/signout.page.ts#L372)
  Ionic loadAttendanceSongs nach applyDutyView (ohne nicht zugeteilte Dienst-Termine) / Flutter signoutAttendanceSongsProvider/upcomingSongsProvider auf ungefilterten signoutData → Werke nicht zugeteilter Dienst-Termine können in "Aktuelle Werke" erscheinen.
  Flutter: lib/features/self_service/data/providers/upcoming_songs_provider.dart:29, lib/features/self_service/data/providers/upcoming_songs_provider.dart:53
