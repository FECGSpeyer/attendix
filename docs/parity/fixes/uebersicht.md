# Fix-Paket „uebersicht“

Soll: Ionic 4.19.9 (1923d203). Ist: Flutter 1aba6be, 2157fa0, b218510, 3bacc76, 8004a44, c9dd1aa, , b15b3b0, 40d2b43, da49473, 84c4c44, 6945c13, 3cdaaa1, a0550a4, 4e13f22, 2353b98, 00e183c (normales Design).
Erzeugt mit `node tool/parity/parity.mjs fixlists` aus `docs/parity/status/`. Item-IDs siehe `ionic-inventory.json`.

## Angleichen (hoch/mittel): 1

- [ ] **mittel** `messages/message-detail/message-detail.page` `x-b5f5a215de` **Mitteilung aus verlassener Instanz nicht mehr abrufbar** [src/app/services/message/message.service.ts:46](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/message/message.service.ts#L46) (2. Prüfung: bestätigt)
  Real: Ionic getMessage ohne Instanzfilter; RLS 'recipient can read messages' (add_messages.sql) lässt die eigene Kopie auch nach Austritt lesen (alter Push-/E-Mail-Link, Glocke 'Alle Instanzen'), Ionic zeigt dann die Mitgliederansicht. Flutter getMessageById filtert auf aktuelle + eigene Instanzen → 'Diese Mitteilung gibt es nicht mehr oder du hast keinen Zugriff darauf.' Seltener Fall, mittel passt.
  Flutter: lib/data/repositories/message_repository.dart:48-66, lib/core/providers/message_providers.dart:58-68, lib/features/messages/presentation/pages/message_detail_page.dart:145-161

## Flutter besser – Leon entscheidet: 13

- [ ] **niedrig** `export/export.page` `field-1f02578e` [export/export.page.html:23](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.html#L23)
  Flutter besser: Ionic ion-select multiple setzt nach OK die Reihenfolge auf die Optionsreihenfolge zurück und verwirft eigene Extrafelder (nicht in den Optionen) / Flutter behält die manuelle Reihenfolge und eigene Felder, neue Felder werden angehängt. Label 'Felder', Optionen (Standard + Extrafelder) gleich.
  Flutter: lib/features/export/presentation/pages/export_page.dart:192, lib/features/export/presentation/pages/export_page.dart:96
- [ ] **niedrig** `notifications/notifications.page` `field-cb78f4aa` [notifications/notifications.page.html:28](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/notifications/notifications.page.html#L28)
  Flutter besser: Material-Darstellung mit zusätzlichem Kopieren-Button (Toast 'Benutzer-Id kopiert') und Monospace-Wert; iOS wie Ionic (Label + markierbarer Wert). Sichtbar nur ohne Telegram-Verknüpfung wie Ionic.
  Flutter: lib/features/notifications/presentation/pages/notifications_page.dart:208, lib/features/notifications/presentation/pages/notifications_page.dart:410, lib/features/notifications/presentation/pages/notifications_page.dart:446
- [ ] **niedrig** `stats/stats.page` `field-0fc2d09f` [stats/stats.page.html:25](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L25)
  Flutter besser: "Von" ist auf <= "Bis" begrenzt (Ionic: jedes Datum, ggf. leerer Zeitraum). Übernahme bei Auswahl und Neuberechnung wie onDateFilterChange.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:325, lib/features/statistics/presentation/pages/statistics_page.dart:341, lib/core/providers/statistics_providers.dart:43
- [ ] **niedrig** `stats/stats.page` `field-e8b28445` [stats/stats.page.html:36](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L36) (2. Prüfung: bestätigt)
  Flutter besser: 'Bis' ist auf ≥ 'Von' begrenzt (Obergrenze heute + 2 Jahre), Ionic ohne Grenzen. Ionic Kalender im Modal mit Sofortübernahme / Flutter Datumsdialog; Neuberechnung bei Auswahl gleich.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:325, lib/features/statistics/presentation/pages/statistics_page.dart:336, lib/core/providers/statistics_providers.dart:43
- [ ] **niedrig** `export/export.page` `x-f8165d88f7` **Rückmeldungen beim Export** [src/app/export/export.page.ts:178](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L178)
  Flutter besser: Ionic exportiert auch ohne gewählte Felder und meldet weder Erfolg noch Fehler / Flutter: Toast 'Bitte wähle mindestens ein Feld aus.' bei leerer Auswahl, Toast 'Export erfolgreich' bzw. 'Fehler beim Export: …'.
  Flutter: lib/features/export/presentation/pages/export_page.dart:347, lib/features/export/presentation/pages/export_page.dart:495
- [ ] **niedrig** `history/history.page` `x-7ddfeabbe3` **Reihenfolge der Datumsgruppen** [src/app/history/history.page.ts:86](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.ts#L86)
  Flutter besser: Ionic sortiert die Gruppen mit dayjs('DD.MM.YYYY') ohne customParseFormat → browserabhängig (iOS/Safari: Invalid Date → Einfügereihenfolge = neueste zuerst; Chrome/Android: teils als MM.DD. fehlgeparst, Reihenfolge durcheinander) / Flutter: stabil neueste zuerst (DB-Reihenfolge).
  Flutter: lib/features/history/presentation/pages/history_page.dart:241
- [ ] **niedrig** `history/history.page` `x-b33e35745e` **Zusätzliche Rückmeldungen in Flutter** [src/app/history/history.page.ts:59](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.ts#L59)
  Flutter besser: Toasts '{n} Werke hinzugefügt' / 'Eintrag gelöscht', Fehlertoast beim Hinzufügen, Fehleransicht mit 'Erneut versuchen' beim Laden; Ionic zeigt nichts davon (und bricht bei leerer Werkbibliothek in ngOnInit ab, songs[0].id).
  Flutter: lib/features/history/presentation/pages/history_page.dart:114, lib/features/history/presentation/pages/history_page.dart:554, lib/features/history/presentation/pages/history_page.dart:594
- [ ] **niedrig** `home-dashboard/components/birthdays-card/birthdays-card.component` `x-0cf219a069` **Geburtstage über den Jahreswechsel** [src/app/home-dashboard/components/birthdays-card/birthdays-card.component.ts:63](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/home-dashboard/components/birthdays-card/birthdays-card.component.ts#L63)
  Flutter besser: Ionic prüft nur dieses und nächstes Jahr – Anfang Januar fehlen Dezember-Geburtstage im Rückblick 'Zuletzt'; 29.02. rollt in Nicht-Schaltjahren auf 01.03. / Flutter nimmt das nächstgelegene Vorkommen aus Vorjahr/Jahr/Folgejahr und hält 29.02. auf 28.02.
  Flutter: lib/core/utils/dashboard_utils.dart:95
- [ ] **niedrig** `home-dashboard/components/current-songs-card/current-songs-card.component` `x-b6cd253738` **Reihenfolge der aktuellen Werke** [src/app/services/db.service.ts:3162](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/db.service.ts#L3162)
  Flutter besser: Ionic sortiert mit dayjs(x, 'DD.MM.YYYY') ohne geladenes customParseFormat → browserabhängig (Safari/iOS: unsortiert umgekehrte DB-Reihenfolge, Chrome teils MM.DD.) / Flutter: wie beabsichtigt nach Datum aufsteigend, bei gleichem Datum nach Termin-ID.
  Flutter: lib/core/utils/dashboard_logic.dart:194
- [ ] **niedrig** `messages/message-compose/message-compose.component` `x-b299242fe2` **Preset-Versand löscht normalen Entwurf** [src/app/messages/message-compose/message-compose.component.ts:203](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/messages/message-compose/message-compose.component.ts#L203)
  Flutter besser: Ionic: nach Versand im Preset-Modus ('Unentschuldigte anschreiben') wird trotzdem der normale Entwurf 'message-draft-<tenantId>' gelöscht / Flutter: _clearDraft überspringt Preset, normaler Entwurf bleibt erhalten.
  Flutter: lib/features/messages/presentation/pages/message_compose_page.dart:156
- [ ] **niedrig** `messages/message-compose/message-compose.component` `x-7cfcb98063` **Nur-Leerzeichen-Text** [src/app/messages/message-compose/message-compose.component.ts:96](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/messages/message-compose/message-compose.component.ts#L96)
  Flutter besser: Ionic: hasText prüft nur, ob irgendein Textknoten existiert (auch nur Leerzeichen erlaubt Senden) / Flutter: TiptapConverter.hasText verlangt nicht-leeren Text nach trim.
  Flutter: lib/core/utils/tiptap_converter.dart:152
- [ ] **niedrig** `notifications/notifications.page` `x-87f20645a2` **Laden der Einstellungen** [src/app/notifications/notifications.page.ts:43](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/notifications/notifications.page.ts#L43)
  Flutter besser: Ionic zeigt beim Laden und bei Ladefehler eine leere Seite (nur Titel) / Flutter zeigt Spinner, bei Fehler Toast 'Fehler beim Laden: …' und Text 'Konfiguration nicht gefunden'.
  Flutter: lib/features/notifications/presentation/pages/notifications_page.dart:60, lib/features/notifications/presentation/pages/notifications_page.dart:158
- [ ] **niedrig** `stats/stats.page` `x-82cbaeffb4` **Pull-to-refresh nur in Flutter** [src/app/stats/stats.page.html:12](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L12)
  Flutter besser: Herunterziehen lädt Termine und Personen neu / Ionic: kein Refresher, nur erneutes Öffnen.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:163

## Kleinigkeiten (niedrig): 39

- [ ] **niedrig** `export/export.page` `alert-ed41a2f2` [export/export.page.ts:159](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L159)
  Header 'Feld hinzufügen', Buttons Abbrechen/Hinzufügen gleich. Ionic: Textfeld ohne Label, leere Eingabe fügt eine leere Spalte hinzu / Flutter: Feld mit Label 'Spaltenname' (Flutter-Text), leere Eingabe wird ignoriert.
  Flutter: lib/features/export/presentation/pages/export_page.dart:315
- [ ] **niedrig** `export/export.page` `effect-6347ac25` [export/export.page.ts:204](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L204)
  Datei '{Kurzname}_Spielerliste_Stand_{Datum}.xlsx', ein Blatt 'Anwesenheit' wie Ionic. Ionic saveWorkbook: nativ Datei in Cache + Systemviewer, mobiler Browser (iOS/Android, PWA) Web-Share-Sheet, Desktop Download / Flutter NativeFileService.saveBytes: nativ Cache + OpenFilex (Cache-Name ohne Punkte/Umlaute, z. B. '…_Stand_04_11_2026.xlsx'), im Web immer Anker-Download über Printing.sharePdf (Blob-Typ application/pdf) – kein Teilen-Dialog im mobilen Browser.
  Flutter: lib/features/export/presentation/pages/export_page.dart:436, lib/features/export/presentation/pages/export_page.dart:442, lib/features/export/presentation/pages/export_page.dart:510, lib/core/services/native/native_file_service.dart:167
- [ ] **niedrig** `export/export.page` `effect-b5cfc616` [export/export.page.ts:278](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L278)
  Nativ (iOS/Android): Datei in Cache schreiben und öffnen wie Ionic; Desktop-Browser: Download wie Ionic. Ionic mobiler Browser (iOS/Android-PWA): Web-Share-Sheet (navigator.share) / Flutter: Printing.sharePdf → im Web nur Anchor-Download, kein Teilen-Dialog.
  Flutter: lib/core/services/export_service.dart:88, lib/core/services/native/native_file_service.dart:167
- [ ] **niedrig** `export/export.page` `effect-7662bf5a` [export/export.page.ts:335](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L335)
  Datei '{Kurzname}_Anwesenheit_Stand_{Datum}.xlsx', ein Blatt 'Anwesenheit' wie Ionic. Ionic saveWorkbook: nativ Datei in Cache + Systemviewer, mobiler Browser (iOS/Android, PWA) Web-Share-Sheet, Desktop Download / Flutter NativeFileService.saveBytes: nativ Cache + OpenFilex (Cache-Name ohne Punkte/Umlaute, z. B. '…_Stand_04_11_2026.xlsx'), im Web immer Anker-Download über Printing.sharePdf (Blob-Typ application/pdf) – kein Teilen-Dialog im mobilen Browser.
  Flutter: lib/features/export/presentation/pages/export_page.dart:483, lib/features/export/presentation/pages/export_page.dart:491, lib/features/export/presentation/pages/export_page.dart:510, lib/core/services/native/native_file_service.dart:167
- [ ] **niedrig** `export/export.page` `effect-b206f4b4` [export/export.page.ts:433](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L433)
  Wie beim Spieler-PDF: Ionic mobiler Browser → Web-Share-Sheet / Flutter → Anchor-Download (Printing.sharePdf web); nativ und Desktop gleich.
  Flutter: lib/core/services/export_service.dart:178, lib/core/services/native/native_file_service.dart:167
- [ ] **niedrig** `export/export.page` `action-affb31d3` [export/export.page.html:31](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.html#L31) (2. Prüfung: bestätigt)
  Ziehen am Griff rechts und Wischen zum Entfernen (Papierkorb) gleich. Flutter zeigt bei selbst hinzugefügten Feldern zusätzlich den Untertitel 'Eigenes Feld (leer)' (Flutter-Text), Ionic nur den Feldnamen.
  Flutter: lib/features/export/presentation/pages/export_page.dart:200, lib/features/export/presentation/pages/export_page.dart:236
- [ ] **niedrig** `history/history.page` `toast-a7d10e87` [history/history.page.ts:214](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.ts#L214) (2. Prüfung: bestätigt)
  Text 'Bitte wähle mindestens ein Werk an' gleich. Ionic: Farbe danger (rot) / Flutter: ToastHelper.showWarning (orange). Zudem startet Flutter ohne vorausgewähltes Werk (Ionic: selectedSongs = [songs[0].id]), der Hinweis kommt in Flutter also schon beim ersten 'Hinzufügen' ohne Auswahl.
  Flutter: lib/features/history/presentation/pages/history_page.dart:445
- [ ] **niedrig** `history/history.page` `toast-cafe4207` [history/history.page.ts:263](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.ts#L263)
  Ionic: 'Fehler beim Löschen des Eintrags' (danger) / Flutter: 'Fehler: <technische Meldung>' (danger).
  Flutter: lib/features/history/presentation/pages/history_page.dart:598
- [ ] **niedrig** `history/history.page` `action-85678212` [history/history.page.html:13](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L13)
  Ionic: Pull-to-Refresh immer (auch im Leerzustand) / Flutter: RefreshIndicator nur um die gefüllte Liste – im Leerzustand ('Noch keine Werke gespielt', keine Treffer) kein Pull-to-Refresh.
  Flutter: lib/features/history/presentation/pages/history_page.dart:177
- [ ] **niedrig** `history/history.page` `field-ac79647a` [history/history.page.html:17](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L17)
  Platzhalter 'Werk suchen...' gleich. Ionic: filtert nur nach Werkname, ohne Treffer leere Liste / Flutter: filtert zusätzlich nach Werknummer und Dirigent und zeigt bei 0 Treffern 'Keine Werke gefunden' mit Icon.
  Flutter: lib/features/history/presentation/pages/history_page.dart:104, lib/features/history/presentation/pages/history_page.dart:230, lib/features/history/presentation/pages/history_page.dart:160
- [ ] **niedrig** `history/history.page` `text-dff66123` [history/history.page.html:60](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L60)
  Datums-Akkordeon (hellgrau, anfangs zu) vorhanden. Ionic: ion-accordion-group – immer nur ein Datum gleichzeitig offen / Flutter: jede Gruppe unabhängig, mehrere gleichzeitig offen.
  Flutter: lib/features/history/presentation/pages/history_page.dart:648, lib/features/history/presentation/pages/history_page.dart:653
- [ ] **niedrig** `history/history.page` `action-6dccb9eb` [history/history.page.html:101](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L101)
  Zeile 'Werk(e)' mit 'N Werk(e) ausgewählt'/'Keine Werke ausgewählt' und Chevron öffnet die Auswahl. Ionic: beim ersten Öffnen ist das erste Werk der Bibliothek vorausgewählt ('1 Werk(e) ausgewählt'), Auswahl bleibt nach Schließen ohne Hinzufügen erhalten / Flutter: startet bei jedem Öffnen leer.
  Flutter: lib/features/history/presentation/pages/history_page.dart:326
- [ ] **niedrig** `history/history.page` `field-c1a5fc20` [history/history.page.html:124](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L124) (2. Prüfung: bestätigt)
  Platzhalter 'Werk suchen...' gleich. Ionic sucht in '{prefix}{nummer} {name}' (Anzeige ebenso) / Flutter in displayName '{prefix}{nummer} - {name}' (Anzeige mit ' - '); Suchbegriffe über Nummer und Name hinweg ('12 Ave') finden in Flutter nichts.
  Flutter: lib/features/history/presentation/pages/history_page.dart:812, lib/features/history/presentation/pages/history_page.dart:829, lib/data/models/song/song.dart:150
- [ ] **niedrig** `history/history.page` `action-a34c7dc7` [history/history.page.html:146](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L146)
  Checkbox-Zeile mit Komponist, Tippen schaltet um. Ionic Titel: '{prefix}{nummer} {name}' / Flutter: '{prefix}{nummer} - {name}' (zusätzlicher Bindestrich).
  Flutter: lib/features/history/presentation/pages/history_page.dart:854, lib/data/models/song/song.dart:150
- [ ] **niedrig** `history/history.page` `field-1bf71ecb` [history/history.page.html:179](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L179) (2. Prüfung: bestätigt)
  Ionic: eingegebener Name als editierbares ion-input / Flutter: nur als Textzeile; Korrektur nur über erneute Auswahl 'Anderer Dirigent'.
  Flutter: lib/features/history/presentation/pages/history_page.dart:388
- [ ] **niedrig** `history/history.page` `field-1d1fb30d` [history/history.page.html:184](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L184)
  Feld mit Platzhalter 'TT.MM.JJJJ', Übernahme beim Verlassen, ungültig → letzter gültiger Wert. Ionic: nach erfolgreichem Hinzufügen bleibt das zuletzt gewählte Datum für den nächsten Eintrag / Flutter: jedes Öffnen startet mit heute. Flutter besser: Tage wie 31.02. werden verworfen (Ionic rollt auf 03.03.).
  Flutter: lib/features/history/presentation/pages/history_page.dart:399, lib/features/history/presentation/pages/history_page.dart:884
- [ ] **niedrig** `history/history.page` `field-aa62edcf` [history/history.page.html:196](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L196)
  Ionic: ion-datetime als Datumsrad (preferWheel, Montag zuerst), Wert wird sofort übernommen, schließt bei Tageswechsel, unbegrenzter Bereich / Flutter: Kalender-Datepicker (md mit OK-Bestätigung), Bereich 01.01.2000 bis heute+365 Tage.
  Flutter: lib/features/history/presentation/pages/history_page.dart:420, lib/shared/widgets/adaptive/app_pickers.dart:12
- [ ] **niedrig** `home-dashboard/home-dashboard.page` `loading-bee7e5e1` [home-dashboard/home-dashboard.page.ts:76](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/home-dashboard/home-dashboard.page.ts#L76)
  Ionic: blockierendes Lade-Overlay (max. 3 s) während Tenantwechsel / Flutter: kein Overlay, UI bleibt bedienbar bis zur Navigation.
  Flutter: lib/features/dashboard/presentation/pages/home_dashboard_page.dart:180
- [ ] **niedrig** `messages/message-list/message-list.page` `toast-d930edbc` [messages/message-list/message-list.page.ts:67](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/messages/message-list/message-list.page.ts#L67)
  Ionic: Toast 'Mitteilungen konnten nicht geladen werden' (danger), darunter Leerzustand 'Noch keine Mitteilungen' mit Button und Eintrag 'Automatische Nachrichten'. / Flutter: kein Toast, nur zentrierter Text 'Mitteilungen konnten nicht geladen werden' ohne Auto-Eintrag und Leerzustand.
  Flutter: lib/features/messages/presentation/pages/message_list_page.dart:73
- [ ] **niedrig** `messages/message-list/message-list.page` `action-4c1cdd16` [messages/message-list/message-list.page.html:34](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/messages/message-list/message-list.page.html#L34) (2. Prüfung: bestätigt)
  Text 'Erste Mitteilung schreiben', runde Form und Aktion gleich. Icon: Ionic create-outline / Flutter Icons.edit_note.
  Flutter: lib/features/messages/presentation/pages/message_list_page.dart:313
- [ ] **niedrig** `notifications/notifications.page` `native-1f2aa2b5` [notifications/notifications.page.ts:68](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/notifications/notifications.page.ts#L68)
  Gleicher Link https://t.me/attendix_bot?start=<userId>. Ionic: Capacitor Browser.open (In-App-Browser in der App, neuer Tab im Web) / Flutter: launchUrl externalApplication (öffnet direkt Telegram bzw. externen Browser), bei Fehler Toast 'Konnte Telegram nicht öffnen'.
  Flutter: lib/features/notifications/presentation/pages/notifications_page.dart:130, lib/core/services/telegram_service.dart:176
- [ ] **niedrig** `notifications/notifications.page` `text-bd81b782` [notifications/notifications.page.html:33](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/notifications/notifications.page.html#L33)
  Text 'Telegramverknüpfung' gleich. Material: zusätzliches Telegram-Icon vor dem Titel (grün wenn verknüpft); Ionic ohne Icon. iOS wie Ionic.
  Flutter: lib/features/notifications/presentation/pages/notifications_page.dart:485, lib/features/notifications/presentation/pages/notifications_page.dart:531
- [ ] **niedrig** `stats/stats.page` `field-d9134dd8` [stats/stats.page.html:22](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L22) (2. Prüfung: bestätigt)
  Ionic ion-datetime-button mit locale de-DE zeigt das Intl-Kurzformat ('1. Sept. 2025'; Ionic-Paket nicht im Container) / Flutter '01.09.2025' (DateHelper.getShortDate).
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:347, lib/features/statistics/presentation/pages/statistics_page.dart:392
- [ ] **niedrig** `stats/stats.page` `field-d9134dd8-2` [stats/stats.page.html:33](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L33)
  Anzeigeformat wie field-d9134dd8: Ionic Intl-Kurzformat ('1. Sept. 2025') / Flutter '01.09.2025'.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:347, lib/features/statistics/presentation/pages/statistics_page.dart:392
- [ ] **niedrig** `stats/stats.page` `text-729fe4d0` [stats/stats.page.html:97](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L97)
  Ionic: Abschnitt immer sichtbar (bei 0 Terminen leeres Diagramm) / Flutter: bei 0 Terminen im Zeitraum entfallen die fünf Anwesenheits-Abschnitte, stattdessen ein Leerzustand 'Keine Daten im ausgewählten Zeitraum'.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:87, lib/features/statistics/presentation/pages/statistics_page.dart:236, lib/features/statistics/presentation/pages/statistics_page.dart:245
- [ ] **niedrig** `stats/stats.page` `text-a54abdb5` [stats/stats.page.html:112](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L112)
  Ionic: Abschnitt immer sichtbar (bei 0 Terminen leeres Diagramm) / Flutter: bei 0 Terminen im Zeitraum entfallen die fünf Anwesenheits-Abschnitte, stattdessen ein Leerzustand 'Keine Daten im ausgewählten Zeitraum'.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:87, lib/features/statistics/presentation/pages/statistics_page.dart:238, lib/features/statistics/presentation/pages/statistics_page.dart:245
- [ ] **niedrig** `stats/stats.page` `media-542fed8c` [stats/stats.page.html:119](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L119)
  Zählung gleich (Verspätet inkl. verspätet entschuldigt, gerundete Prozente). Ionic: voller Kreis, Titel 'Statusverteilung (in %)', Legende oben 'Anwesend (x%)', 'Entschuldigt (x%)', 'Verspätet (x%)', 'Abwesend (x%)' / Flutter: Ring mit Prozent auf den Segmenten, Legende rechts nur Statusnamen, kein Titel.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:603, lib/features/statistics/presentation/pages/statistics_page.dart:692
- [ ] **niedrig** `stats/stats.page` `text-f6dad6f9` [stats/stats.page.html:127](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L127)
  Ionic: Abschnitt immer sichtbar (bei 0 Terminen leeres Diagramm) / Flutter: bei 0 Terminen im Zeitraum entfallen die fünf Anwesenheits-Abschnitte, stattdessen ein Leerzustand 'Keine Daten im ausgewählten Zeitraum'.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:87, lib/features/statistics/presentation/pages/statistics_page.dart:240, lib/features/statistics/presentation/pages/statistics_page.dart:245
- [ ] **niedrig** `stats/stats.page` `text-0a14e583` [stats/stats.page.html:142](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L142)
  Ionic: Abschnitt immer sichtbar (bei 0 Terminen leeres Diagramm) / Flutter: bei 0 Terminen im Zeitraum entfallen die fünf Anwesenheits-Abschnitte, stattdessen ein Leerzustand 'Keine Daten im ausgewählten Zeitraum'.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:87, lib/features/statistics/presentation/pages/statistics_page.dart:242, lib/features/statistics/presentation/pages/statistics_page.dart:245
- [ ] **niedrig** `stats/stats.page` `text-5acf85be` [stats/stats.page.html:157](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L157)
  Ionic: Abschnitt immer sichtbar (bei 0 Terminen leeres Diagramm) / Flutter: bei 0 Terminen im Zeitraum entfallen die fünf Anwesenheits-Abschnitte, stattdessen ein Leerzustand 'Keine Daten im ausgewählten Zeitraum'.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:87, lib/features/statistics/presentation/pages/statistics_page.dart:244, lib/features/statistics/presentation/pages/statistics_page.dart:245
- [ ] **niedrig** `stats/stats.page` `media-c58a7f02` [stats/stats.page.html:210](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L210)
  Senkrechte Balken je 3-Jahres-Gruppe 'x-y', Y in 1er-Schritten, nur aktive Personen mit Geburtstag – wie Ionic. Ionic: Titel 'Altersverteilung 🎂' im Diagramm, ohne Geburtstage leeres Diagramm / Flutter: nur gleichlautende Abschnittsüberschrift, Platzhalter 'Keine Geburtsdaten vorhanden'.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:921, lib/core/providers/statistics_providers.dart:500
- [ ] **niedrig** `stats/stats.page` `media-50089e70` [stats/stats.page.html:266](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L266)
  Ring mit Feldname als Titel, Farben je Option, Zeilenliste darunter gleich. Ionic: Chart.js-Legende 'Option (x%)' über dem Ring, Tooltip 'N Personen (x%)' / Flutter: keine Legende am Ring, Prozent auf Segmenten ab 8 %, kein Tooltip.
  Flutter: lib/features/statistics/presentation/widgets/field_stats_section.dart:110, lib/features/statistics/presentation/widgets/field_stats_section.dart:170
- [ ] **niedrig** `export/export.page` `x-0db4aad92e` **Hinweis PDF-Limit nur in Flutter** [src/app/export/export.page.html:65](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.html#L65)
  Ionic: kein Hinweis / Flutter: bei Anwesenheit+PDF zusätzlicher Text 'PDF-Export ist auf die letzten 8 Termine begrenzt. Für alle Termine der Saison nutze den Excel-Export.'
  Flutter: lib/features/export/presentation/pages/export_page.dart:288
- [ ] **niedrig** `history/history.page` `x-74a55a2af4` **Platzhaltertexte bei fehlendem Werk/Dirigent** [src/app/history/history.page.ts:73](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.ts#L73)
  Ionic: leerer Name bzw. leerer Dirigent hinter '|' / Flutter: 'Unbekanntes Werk' bzw. 'Unbekannt'.
  Flutter: lib/features/history/presentation/pages/history_page.dart:731, lib/data/models/history/history_entry.dart:42
- [ ] **niedrig** `home-dashboard/components/next-event-card/next-event-card.component` `x-5b81f95abe` **Sortierung der Abmeldungen** [src/app/home-dashboard/components/next-event-card/next-event-card.component.ts:104](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/home-dashboard/components/next-event-card/next-event-card.component.ts#L104)
  Ionic: Gruppe, dann Nachname per localeCompare (Umlaute bei Grundbuchstaben, Groß/klein egal) / Flutter: String.compareTo (Code-Einheiten: z. B. 'Özdemir' nach 'Zimmer', Kleinbuchstaben nach Großbuchstaben).
  Flutter: lib/core/utils/dashboard_logic.dart:133
- [ ] **niedrig** `home-dashboard/home-dashboard.page` `x-c6f9466555` **Meine Aufgaben beim Zurückkehren** [src/app/home-dashboard/home-dashboard.page.ts:47](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/home-dashboard/home-dashboard.page.ts#L47)
  Ionic: ionViewWillEnter lädt die Karte 'Meine Aufgaben' bei jedem erneuten Betreten des Dashboards neu / Flutter: myTasksProvider wird nur nach eigenen Aufgaben-Änderungen (TeamTaskNotifier, Abmeldung) oder Pull-to-Refresh invalidiert; fremde Änderungen erscheinen erst nach Refresh.
  Flutter: lib/core/providers/team_org_providers.dart:277, lib/features/team_organization/presentation/widgets/my_tasks_card.dart:53
- [ ] **niedrig** `notifications/notifications.page` `x-1957eb8534` **Fehler beim Speichern der Einstellungen** [src/app/services/notification/notification.service.ts:55](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/notification/notification.service.ts#L55)
  Ionic: Toast 'Fehler beim Updaten der Konfiguration, bitte versuche es später erneut.', der Schalter bleibt im neuen (nicht gespeicherten) Zustand / Flutter: Toast 'Fehler beim Aktualisieren der Konfiguration', der Schalter springt zurück.
  Flutter: lib/features/notifications/presentation/pages/notifications_page.dart:103
- [ ] **niedrig** `stats/stats.page` `x-c78a5253ee` **Statusverteilung: Legende ohne Prozent** [src/app/stats/stats.page.ts:240](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.ts#L240)
  Ionic: Legende 'Anwesend (x%)', 'Entschuldigt (x%)', 'Verspätet (x%)', 'Abwesend (x%)' über dem Kreisdiagramm / Flutter: Prozent auf den Segmenten, Legende rechts nur mit Statusnamen, Ring statt voller Kreis.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:603, lib/features/statistics/presentation/pages/statistics_page.dart:692
- [ ] **niedrig** `stats/stats.page` `x-d30471180e` **Leere Einzeldiagramme mit Platzhaltertext** [src/app/stats/stats.page.ts:380](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.ts#L380)
  Ionic: leeres Diagramm (mit Titel), wenn keine Daten / Flutter: Platzhalter 'Keine Daten verfügbar', 'Keine Geburtsdaten vorhanden' bzw. 'Keine unentschuldigten Abwesenheiten'.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:1197, lib/features/statistics/presentation/pages/statistics_page.dart:929, lib/features/statistics/presentation/pages/statistics_page.dart:1112
