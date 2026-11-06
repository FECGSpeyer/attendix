# Fix-Paket „uebersicht“

Soll: Ionic 4.19.9 (1923d203). Ist: Flutter 1aba6be, 2157fa0, b218510, 3bacc76, 8004a44, c9dd1aa, , b15b3b0, 40d2b43, da49473, 84c4c44, 6945c13, 3cdaaa1, a0550a4, 4e13f22, 2353b98, 00e183c, 57bb011, 0f74333, 3fe913c9, 2acb693, 447c007, 5ddaa2a, 4de3564, 96b8284, 525a06f, ed511da, 359f15d, 43a315b, 0e6c255 (normales Design).
Erzeugt mit `node tool/parity/parity.mjs fixlists` aus `docs/parity/status/`. Item-IDs siehe `ionic-inventory.json`.

## Angleichen (hoch/mittel): 0


## Flutter besser – Leon entscheidet: 12

- [ ] **niedrig** `export/export.page` `field-1f02578e` [export/export.page.html:23](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.html#L23)
  Flutter besser: Ionic ion-select multiple setzt nach OK die Reihenfolge auf die Optionsreihenfolge zurück und verwirft eigene Extrafelder (nicht in den Optionen) / Flutter behält die manuelle Reihenfolge und eigene Felder, neue Felder werden angehängt. Label 'Felder', Optionen (Standard + Extrafelder) gleich.
  Flutter: lib/features/export/presentation/pages/export_page.dart:192, lib/features/export/presentation/pages/export_page.dart:96
- [ ] **niedrig** `notifications/notifications.page` `field-cb78f4aa` [notifications/notifications.page.html:28](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/notifications/notifications.page.html#L28) (2. Prüfung: bestätigt)
  Flutter besser: Material-Darstellung mit zusätzlichem Kopieren-Button (Toast 'Benutzer-Id kopiert') und Monospace-Wert; iOS wie Ionic (Label + markierbarer Wert). Sichtbar nur ohne Telegram-Verknüpfung wie Ionic.
  Flutter: lib/features/notifications/presentation/pages/notifications_page.dart:209, lib/features/notifications/presentation/pages/notifications_page.dart:413
- [ ] **niedrig** `stats/stats.page` `field-0fc2d09f` [stats/stats.page.html:25](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L25) (2. Prüfung: bestätigt)
  Flutter besser: „Von“ auf ≤ „Bis“ begrenzt (Ionic jedes Datum, ggf. leerer Zeitraum). Übernahme bei Auswahl und Neuberechnung wie onDateFilterChange.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:326, lib/features/statistics/presentation/pages/statistics_page.dart:334, lib/core/providers/statistics_providers.dart:43
- [ ] **niedrig** `stats/stats.page` `field-e8b28445` [stats/stats.page.html:36](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L36) (2. Prüfung: bestätigt)
  Flutter besser: „Bis“ auf ≥ „Von“ begrenzt (Obergrenze heute + 2 Jahre), Ionic ohne Grenzen. Datumsdialog statt Inline-Kalender; Neuberechnung bei Auswahl gleich.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:326, lib/features/statistics/presentation/pages/statistics_page.dart:334, lib/core/providers/statistics_providers.dart:43
- [ ] **niedrig** `export/export.page` `x-f8165d88f7` **Rückmeldungen beim Export** [src/app/export/export.page.ts:178](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L178)
  Flutter besser: Ionic exportiert auch ohne gewählte Felder und meldet weder Erfolg noch Fehler / Flutter: Toast 'Bitte wähle mindestens ein Feld aus.' bei leerer Auswahl, Toast 'Export erfolgreich' bzw. 'Fehler beim Export: …'.
  Flutter: lib/features/export/presentation/pages/export_page.dart:347, lib/features/export/presentation/pages/export_page.dart:495
- [ ] **niedrig** `history/history.page` `x-7ddfeabbe3` **Reihenfolge der Datumsgruppen** [src/app/history/history.page.ts:86](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.ts#L86) (2. Prüfung: bestätigt)
  Flutter besser, weiter real: Gruppen in DB-Reihenfolge (date desc) = neueste zuerst; Ionic sortiert mit dayjs('DD.MM.YYYY') ohne customParseFormat, browserabhängig.
  Flutter: lib/features/history/presentation/pages/history_page.dart:249
- [ ] **niedrig** `history/history.page` `x-b33e35745e` **Zusätzliche Rückmeldungen in Flutter** [src/app/history/history.page.ts:59](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.ts#L59) (2. Prüfung: bestätigt)
  Flutter besser, weiter real: Toasts „{n} Werke hinzugefügt“ / „Eintrag gelöscht“, Fehlertoasts beim Hinzufügen/Löschen, Fehleransicht mit „Erneut versuchen“, Hinweis bei leerer Werkbibliothek statt Ionic-Absturz (songs[0].id).
  Flutter: lib/features/history/presentation/pages/history_page.dart:138, lib/features/history/presentation/pages/history_page.dart:578, lib/features/history/presentation/pages/history_page.dart:618, lib/features/history/presentation/pages/history_page.dart:297
- [ ] **niedrig** `home-dashboard/components/birthdays-card/birthdays-card.component` `x-0cf219a069` **Geburtstage über den Jahreswechsel** [src/app/home-dashboard/components/birthdays-card/birthdays-card.component.ts:63](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/home-dashboard/components/birthdays-card/birthdays-card.component.ts#L63)
  Flutter besser: Ionic prüft nur dieses und nächstes Jahr – Anfang Januar fehlen Dezember-Geburtstage im Rückblick 'Zuletzt'; 29.02. rollt in Nicht-Schaltjahren auf 01.03. / Flutter nimmt das nächstgelegene Vorkommen aus Vorjahr/Jahr/Folgejahr und hält 29.02. auf 28.02.
  Flutter: lib/core/utils/dashboard_utils.dart:95
- [ ] **niedrig** `home-dashboard/components/current-songs-card/current-songs-card.component` `x-b6cd253738` **Reihenfolge der aktuellen Werke** [src/app/services/db.service.ts:3162](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/db.service.ts#L3162)
  Flutter besser: Ionic sortiert mit dayjs(x, 'DD.MM.YYYY') ohne geladenes customParseFormat → browserabhängig (Safari/iOS: unsortiert umgekehrte DB-Reihenfolge, Chrome teils MM.DD.) / Flutter: wie beabsichtigt nach Datum aufsteigend, bei gleichem Datum nach Termin-ID.
  Flutter: lib/core/utils/dashboard_logic.dart:194
- [ ] **niedrig** `messages/message-compose/message-compose.component` `x-b299242fe2` **Preset-Versand löscht normalen Entwurf** [src/app/messages/message-compose/message-compose.component.ts:203](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/messages/message-compose/message-compose.component.ts#L203) (2. Prüfung: bestätigt)
  Flutter besser: Ionic löscht nach Versand im Preset-Modus („Unentschuldigte anschreiben“) trotzdem den normalen Entwurf 'message-draft-<tenantId>' / Flutter _clearDraft überspringt Preset, normaler Entwurf bleibt.
  Flutter: lib/features/messages/presentation/pages/message_compose_page.dart:157
- [ ] **niedrig** `messages/message-compose/message-compose.component` `x-7cfcb98063` **Nur-Leerzeichen-Text** [src/app/messages/message-compose/message-compose.component.ts:96](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/messages/message-compose/message-compose.component.ts#L96)
  Flutter besser: Ionic: hasText prüft nur, ob irgendein Textknoten existiert (auch nur Leerzeichen erlaubt Senden) / Flutter: TiptapConverter.hasText verlangt nicht-leeren Text nach trim.
  Flutter: lib/core/utils/tiptap_converter.dart:152
- [ ] **niedrig** `notifications/notifications.page` `x-87f20645a2` **Laden der Einstellungen** [src/app/notifications/notifications.page.ts:43](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/notifications/notifications.page.ts#L43) (2. Prüfung: bestätigt)
  Flutter besser: Ionic zeigt während des Ladens nur den Titel; bei Ladefehler liefert getNotificationConfig (supabase-js wirft nicht) die Standardwerte einer neu angelegten Zeile, ohne Hinweis / Flutter Spinner, bei Fehler Toast „Fehler beim Laden: …“ und Text „Konfiguration nicht gefunden“.
  Flutter: lib/features/notifications/presentation/pages/notifications_page.dart:61, lib/features/notifications/presentation/pages/notifications_page.dart:159-166

## Kleinigkeiten (niedrig): 41

- [ ] **niedrig** `export/export.page` `alert-ed41a2f2` [export/export.page.ts:159](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L159)
  Header 'Feld hinzufügen', Buttons Abbrechen/Hinzufügen gleich. Ionic: Textfeld ohne Label, leere Eingabe fügt eine leere Spalte hinzu / Flutter: Feld mit Label 'Spaltenname' (Flutter-Text), leere Eingabe wird ignoriert.
  Flutter: lib/features/export/presentation/pages/export_page.dart:315
- [ ] **niedrig** `export/export.page` `effect-6347ac25` [export/export.page.ts:204](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L204)
  Datei '{Kurzname}_Spielerliste_Stand_{Datum}.xlsx', ein Blatt 'Anwesenheit' wie Ionic. Ionic saveWorkbook: nativ Datei in Cache + Systemviewer, mobiler Browser (iOS/Android, PWA) Web-Share-Sheet, Desktop Download / Flutter NativeFileService.saveBytes: nativ Cache + OpenFilex (Cache-Name ohne Punkte/Umlaute, z. B. '…_Stand_04_11_2026.xlsx'), im Web immer Anker-Download über Printing.sharePdf (Blob-Typ application/pdf) – kein Teilen-Dialog im mobilen Browser.
  Flutter: lib/features/export/presentation/pages/export_page.dart:436, lib/features/export/presentation/pages/export_page.dart:442, lib/features/export/presentation/pages/export_page.dart:510, lib/core/services/native/native_file_service.dart:167
- [ ] **niedrig** `export/export.page` `effect-b5cfc616` [export/export.page.ts:278](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L278) (2. Prüfung: bestätigt)
  Weiter so: Spieler-PDF nativ (iOS/Android) in Cache schreiben und öffnen wie Ionic, Desktop-Browser Download; mobiler Browser/PWA: Ionic Teilen-Dialog (navigator.share), Flutter nur Anchor-Download (Printing.sharePdf web).
  Flutter: lib/core/services/export_service.dart:89, lib/core/services/native/native_file_service.dart:167
- [ ] **niedrig** `export/export.page` `effect-7662bf5a` [export/export.page.ts:335](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L335)
  Datei '{Kurzname}_Anwesenheit_Stand_{Datum}.xlsx', ein Blatt 'Anwesenheit' wie Ionic. Ionic saveWorkbook: nativ Datei in Cache + Systemviewer, mobiler Browser (iOS/Android, PWA) Web-Share-Sheet, Desktop Download / Flutter NativeFileService.saveBytes: nativ Cache + OpenFilex (Cache-Name ohne Punkte/Umlaute, z. B. '…_Stand_04_11_2026.xlsx'), im Web immer Anker-Download über Printing.sharePdf (Blob-Typ application/pdf) – kein Teilen-Dialog im mobilen Browser.
  Flutter: lib/features/export/presentation/pages/export_page.dart:483, lib/features/export/presentation/pages/export_page.dart:491, lib/features/export/presentation/pages/export_page.dart:510, lib/core/services/native/native_file_service.dart:167
- [ ] **niedrig** `export/export.page` `effect-b206f4b4` [export/export.page.ts:433](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.ts#L433) (2. Prüfung: bestätigt)
  Weiter so: nativ Datei in Cache schreiben und öffnen, Desktop-Browser Download wie Ionic; mobiler Browser/PWA: Ionic Web-Share-Sheet (navigator.share), Flutter Printing.sharePdf = im Web nur Anchor-Download (printing 5.15.1 printing_web.dart:249).
  Flutter: lib/core/services/export_service.dart:179, lib/core/services/native/native_file_service.dart:167
- [ ] **niedrig** `export/export.page` `action-affb31d3` [export/export.page.html:31](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.html#L31) (2. Prüfung: bestätigt)
  Ziehen am Griff rechts und Wischen zum Entfernen (Papierkorb) gleich. Flutter zeigt bei selbst hinzugefügten Feldern zusätzlich den Untertitel 'Eigenes Feld (leer)' (Flutter-Text), Ionic nur den Feldnamen.
  Flutter: lib/features/export/presentation/pages/export_page.dart:200, lib/features/export/presentation/pages/export_page.dart:236
- [ ] **niedrig** `history/history.page` `toast-a7d10e87` [history/history.page.ts:214](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.ts#L214) (2. Prüfung: bestätigt)
  Text „Bitte wähle mindestens ein Werk an“ gleich. Ionic danger (rot) / Flutter warning (orange). Der frühere Zusatz (Flutter ohne Vorauswahl) entfällt: Flutter wählt jetzt das erste Werk vor, Toast erscheint nur nach Abwahl wie Ionic.
  Flutter: lib/features/history/presentation/pages/history_page.dart:467
- [ ] **niedrig** `history/history.page` `toast-cafe4207` [history/history.page.ts:263](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.ts#L263) (2. Prüfung: bestätigt)
  Ionic: Fehlertext „Fehler beim Löschen des Eintrags“ (danger) / Flutter: „Fehler: <Meldung>“ (danger). Fehler wird gemeldet, gleiche Aussage.
  Flutter: lib/features/history/presentation/pages/history_page.dart:622
- [ ] **niedrig** `history/history.page` `action-85678212` [history/history.page.html:13](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L13) (2. Prüfung: bestätigt)
  Ionic: Pull-to-Refresh immer / Flutter: RefreshIndicator nur um gefüllte Liste, nicht im Leer-/Keine-Treffer-Zustand. Gleiche Funktion, nur Randfall.
  Flutter: lib/features/history/presentation/pages/history_page.dart:185
- [ ] **niedrig** `history/history.page` `field-ac79647a` [history/history.page.html:17](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L17) (2. Prüfung: bestätigt)
  Platzhalter „Werk suchen...“ gleich. Ionic: nur Werkname / Flutter: zusätzlich Werknummer und Dirigent, bei 0 Treffern „Keine Werke gefunden“ mit Icon.
  Flutter: lib/features/history/presentation/pages/history_page.dart:112, lib/features/history/presentation/pages/history_page.dart:238, lib/features/history/presentation/pages/history_page.dart:179
- [ ] **niedrig** `history/history.page` `text-dff66123` [history/history.page.html:60](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L60) (2. Prüfung: bestätigt)
  Datums-Akkordeon vorhanden, anfangs zu. Ionic: nur ein Datum gleichzeitig offen / Flutter: mehrere gleichzeitig offen.
  Flutter: lib/features/history/presentation/pages/history_page.dart:672, lib/features/history/presentation/pages/history_page.dart:653
- [ ] **niedrig** `history/history.page` `modal-9b3d2b28` [history/history.page.html:112](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L112) (2. Prüfung: korrigiert)
  Vollbild-Seite „Werke auswählen“ (fullscreenDialog). Ionic übernimmt Auswahl live, Schließen per Backdrop/Wischen behält sie / Flutter: Auswahl nur mit ✓, Zurück verwirft Änderungen. Gleiche Funktion.
  Flutter: lib/features/history/presentation/pages/history_page.dart:534, lib/features/history/presentation/pages/history_page.dart:537, lib/features/history/presentation/pages/history_page.dart:845
- [ ] **niedrig** `history/history.page` `field-c1a5fc20` [history/history.page.html:124](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L124) (2. Prüfung: bestätigt)
  Platzhalter gleich. Ionic sucht in „{prefix}{nummer} {name}“ / Flutter in „{prefix}{nummer} - {name}“; Begriffe über Nummer und Name hinweg („12 Ave“) finden nichts.
  Flutter: lib/features/history/presentation/pages/history_page.dart:836, lib/features/history/presentation/pages/history_page.dart:853, lib/data/models/song/song.dart:150
- [ ] **niedrig** `history/history.page` `action-a34c7dc7` [history/history.page.html:146](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L146) (2. Prüfung: bestätigt)
  Checkbox-Zeile mit Komponist, Tippen schaltet um. Ionic Titel „{prefix}{nummer} {name}“ / Flutter „{prefix}{nummer} - {name}“ (Bindestrich).
  Flutter: lib/features/history/presentation/pages/history_page.dart:878, lib/features/history/presentation/pages/history_page.dart:881, lib/data/models/song/song.dart:150
- [ ] **niedrig** `history/history.page` `field-1bf71ecb` [history/history.page.html:179](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L179) (2. Prüfung: bestätigt)
  Ionic: Name des anderen Dirigenten als editierbares Eingabefeld / Flutter: nur Textzeile; Korrektur über erneute Auswahl. Gleiche Funktion erreichbar.
  Flutter: lib/features/history/presentation/pages/history_page.dart:411
- [ ] **niedrig** `history/history.page` `field-1d1fb30d` [history/history.page.html:184](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L184) (2. Prüfung: bestätigt)
  Platzhalter „TT.MM.JJJJ“, Übernahme beim Verlassen, ungültig → letzter gültiger Wert. Ionic: zuletzt gewähltes Datum bleibt für nächsten Eintrag / Flutter: jedes Öffnen startet mit heute. Flutter besser: 31.02. wird verworfen (Ionic rollt über).
  Flutter: lib/features/history/presentation/pages/history_page.dart:415, lib/features/history/presentation/pages/history_page.dart:431, lib/features/history/presentation/pages/history_page.dart:318
- [ ] **niedrig** `history/history.page` `field-aa62edcf` [history/history.page.html:196](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.html#L196) (2. Prüfung: bestätigt)
  Ionic: ion-datetime Datumsrad, unbegrenzt / Flutter: Kalender-Datepicker, Bereich 2000 bis heute+365 Tage; Datum kann zusätzlich getippt werden.
  Flutter: lib/features/history/presentation/pages/history_page.dart:441, lib/shared/widgets/adaptive/app_pickers.dart:12
- [ ] **niedrig** `home-dashboard/home-dashboard.page` `loading-bee7e5e1` [home-dashboard/home-dashboard.page.ts:76](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/home-dashboard/home-dashboard.page.ts#L76) (2. Prüfung: bestätigt)
  Weiter so: Ionic blockierendes Lade-Overlay während des Instanzwechsels / Flutter kein Overlay, UI bleibt bis zur Navigation bedienbar. Ziel (role.defaultRoute) gleich.
  Flutter: lib/features/dashboard/presentation/pages/home_dashboard_page.dart:180
- [ ] **niedrig** `messages/message-list/message-list.page` `toast-d930edbc` [messages/message-list/message-list.page.ts:67](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/messages/message-list/message-list.page.ts#L67)
  Ionic: Toast 'Mitteilungen konnten nicht geladen werden' (danger), darunter Leerzustand 'Noch keine Mitteilungen' mit Button und Eintrag 'Automatische Nachrichten'. / Flutter: kein Toast, nur zentrierter Text 'Mitteilungen konnten nicht geladen werden' ohne Auto-Eintrag und Leerzustand.
  Flutter: lib/features/messages/presentation/pages/message_list_page.dart:73
- [ ] **niedrig** `messages/message-list/message-list.page` `action-4c1cdd16` [messages/message-list/message-list.page.html:34](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/messages/message-list/message-list.page.html#L34) (2. Prüfung: bestätigt)
  Text 'Erste Mitteilung schreiben', runde Form und Aktion gleich. Icon: Ionic create-outline / Flutter Icons.edit_note.
  Flutter: lib/features/messages/presentation/pages/message_list_page.dart:313
- [ ] **niedrig** `notifications/notifications.page` `native-1f2aa2b5` [notifications/notifications.page.ts:68](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/notifications/notifications.page.ts#L68) (2. Prüfung: bestätigt)
  Gleicher Link https://t.me/attendix_bot?start=<userId>. Ionic: Capacitor Browser.open (In-App-Browser in der App, neuer Tab im Web) / Flutter: launchUrl externalApplication (öffnet direkt Telegram bzw. externen Browser); bei Exception Toast „Konnte Telegram nicht öffnen“. Gleiches Ziel, nur andere Darstellung.
  Flutter: lib/features/notifications/presentation/pages/notifications_page.dart:131, lib/features/notifications/presentation/pages/notifications_page.dart:136, lib/core/services/telegram_service.dart:176
- [ ] **niedrig** `notifications/notifications.page` `text-bd81b782` [notifications/notifications.page.html:33](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/notifications/notifications.page.html#L33) (2. Prüfung: bestätigt)
  Text 'Telegramverknüpfung' gleich. Material: zusätzliches Telegram-Icon vor dem Titel (grün wenn verknüpft); Ionic ohne Icon. iOS wie Ionic.
  Flutter: lib/features/notifications/presentation/pages/notifications_page.dart:488, lib/features/notifications/presentation/pages/notifications_page.dart:535
- [ ] **niedrig** `stats/stats.page` `field-d9134dd8` [stats/stats.page.html:22](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L22) (2. Prüfung: bestätigt)
  Ionic ion-datetime-button (Intl-Kurzformat, z. B. „1. Sept. 2025“) / Flutter „01.09.2025“ – nur Anzeigeformat.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:349, lib/features/statistics/presentation/pages/statistics_page.dart:351
- [ ] **niedrig** `stats/stats.page` `field-d9134dd8-2` [stats/stats.page.html:33](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L33) (2. Prüfung: bestätigt)
  Wie field-d9134dd8: Anzeigeformat des Datums.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:349, lib/features/statistics/presentation/pages/statistics_page.dart:351
- [ ] **niedrig** `stats/stats.page` `text-729fe4d0` [stats/stats.page.html:97](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L97) (2. Prüfung: bestätigt)
  Ionic: Abschnitt immer sichtbar (bei 0 Terminen leeres Diagramm) / Flutter: bei 0 Terminen im Zeitraum entfällt der Abschnitt, stattdessen Leerzustand 'Keine Daten im ausgewählten Zeitraum'. Funktion und Daten sonst gleich. Zeilen aktualisiert.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:88, lib/features/statistics/presentation/pages/statistics_page.dart:237, lib/features/statistics/presentation/pages/statistics_page.dart:203
- [ ] **niedrig** `stats/stats.page` `text-a54abdb5` [stats/stats.page.html:112](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L112) (2. Prüfung: bestätigt)
  Ionic: Abschnitt immer sichtbar (bei 0 Terminen leeres Diagramm) / Flutter: bei 0 Terminen im Zeitraum entfällt der Abschnitt, stattdessen Leerzustand 'Keine Daten im ausgewählten Zeitraum'. Funktion und Daten sonst gleich. Zeilen aktualisiert.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:88, lib/features/statistics/presentation/pages/statistics_page.dart:239, lib/features/statistics/presentation/pages/statistics_page.dart:203
- [ ] **niedrig** `stats/stats.page` `media-542fed8c` [stats/stats.page.html:119](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L119) (2. Prüfung: bestätigt)
  Zählung gleich (Verspätet inkl. verspätet entschuldigt, gerundete Prozente). Titel „Statusverteilung (in %)“ jetzt auch in Flutter (Z. 641). Ionic: Legende mit „Anwesend (x%)“ / Flutter: Ring mit Prozent auf den Segmenten, Legende nur Statusnamen – gleiche Information.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:613, lib/features/statistics/presentation/pages/statistics_page.dart:641
- [ ] **niedrig** `stats/stats.page` `text-f6dad6f9` [stats/stats.page.html:127](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L127) (2. Prüfung: bestätigt)
  Ionic: Abschnitt immer sichtbar (bei 0 Terminen leeres Diagramm) / Flutter: bei 0 Terminen im Zeitraum entfällt der Abschnitt, stattdessen Leerzustand 'Keine Daten im ausgewählten Zeitraum'. Funktion und Daten sonst gleich. Zeilen aktualisiert.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:88, lib/features/statistics/presentation/pages/statistics_page.dart:241, lib/features/statistics/presentation/pages/statistics_page.dart:203
- [ ] **niedrig** `stats/stats.page` `text-0a14e583` [stats/stats.page.html:142](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L142) (2. Prüfung: bestätigt)
  Ionic: Abschnitt immer sichtbar (bei 0 Terminen leeres Diagramm) / Flutter: bei 0 Terminen entfallen die Anwesenheits-Abschnitte, stattdessen „Keine Daten im ausgewählten Zeitraum“.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:87, lib/features/statistics/presentation/pages/statistics_page.dart:236, lib/features/statistics/presentation/pages/statistics_page.dart:238
- [ ] **niedrig** `stats/stats.page` `text-5acf85be` [stats/stats.page.html:157](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L157) (2. Prüfung: bestätigt)
  Ionic: Abschnitt immer sichtbar (bei 0 Terminen leeres Diagramm) / Flutter: bei 0 Terminen Leerzustand „Keine Daten im ausgewählten Zeitraum“ statt Abschnitt.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:87, lib/features/statistics/presentation/pages/statistics_page.dart:236, lib/features/statistics/presentation/pages/statistics_page.dart:238
- [ ] **niedrig** `stats/stats.page` `media-c58a7f02` [stats/stats.page.html:210](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L210) (2. Prüfung: bestätigt)
  Senkrechte Balken je 3-Jahres-Gruppe, aktive Personen mit Geburtstag, Titel „Altersverteilung 🎂“ jetzt auch in Flutter (Z. 839). Ohne Geburtstage: Ionic leeres Diagramm / Flutter Hinweis „Keine Geburtsdaten vorhanden“.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:818, lib/features/statistics/presentation/pages/statistics_page.dart:839, lib/core/providers/statistics_providers.dart:500
- [ ] **niedrig** `stats/stats.page` `media-50089e70` [stats/stats.page.html:266](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L266)
  Ring mit Feldname als Titel, Farben je Option, Zeilenliste darunter gleich. Ionic: Chart.js-Legende 'Option (x%)' über dem Ring, Tooltip 'N Personen (x%)' / Flutter: keine Legende am Ring, Prozent auf Segmenten ab 8 %, kein Tooltip.
  Flutter: lib/features/statistics/presentation/widgets/field_stats_section.dart:110, lib/features/statistics/presentation/widgets/field_stats_section.dart:170
- [ ] **niedrig** `export/export.page` `x-0db4aad92e` **Hinweis PDF-Limit nur in Flutter** [src/app/export/export.page.html:65](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/export/export.page.html#L65)
  Ionic: kein Hinweis / Flutter: bei Anwesenheit+PDF zusätzlicher Text 'PDF-Export ist auf die letzten 8 Termine begrenzt. Für alle Termine der Saison nutze den Excel-Export.'
  Flutter: lib/features/export/presentation/pages/export_page.dart:288
- [ ] **niedrig** `history/history.page` `x-74a55a2af4` **Platzhaltertexte bei fehlendem Werk/Dirigent** [src/app/history/history.page.ts:73](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/history/history.page.ts#L73) (2. Prüfung: bestätigt)
  Weiter real: fehlendes Werk → „Unbekanntes Werk“, fehlender Dirigent → „Unbekannt“; Ionic zeigt leeren Namen bzw. leer hinter „|“.
  Flutter: lib/features/history/presentation/pages/history_page.dart:755, lib/data/models/history/history_entry.dart:42
- [ ] **niedrig** `home-dashboard/components/next-event-card/next-event-card.component` `x-5b81f95abe` **Sortierung der Abmeldungen** [src/app/home-dashboard/components/next-event-card/next-event-card.component.ts:104](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/home-dashboard/components/next-event-card/next-event-card.component.ts#L104)
  Ionic: Gruppe, dann Nachname per localeCompare (Umlaute bei Grundbuchstaben, Groß/klein egal) / Flutter: String.compareTo (Code-Einheiten: z. B. 'Özdemir' nach 'Zimmer', Kleinbuchstaben nach Großbuchstaben).
  Flutter: lib/core/utils/dashboard_logic.dart:133
- [ ] **niedrig** `home-dashboard/home-dashboard.page` `x-c6f9466555` **Meine Aufgaben beim Zurückkehren** [src/app/home-dashboard/home-dashboard.page.ts:47](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/home-dashboard/home-dashboard.page.ts#L47) (2. Prüfung: bestätigt)
  Besteht weiter: Ionic ionViewWillEnter lädt „Meine Aufgaben“ bei jeder Rückkehr aufs Dashboard neu / Flutter: myTasksProvider wird nur bei eigenen Änderungen (TeamTaskNotifier._invalidate), Abmeldung und Pull-to-Refresh (refreshDashboardCards) neu geladen; kein RouteReturnReload auf dem Dashboard. Von anderen zugewiesene/erledigte Aufgaben erst nach Herunterziehen. Funktion bleibt erreichbar → niedrig.
  Flutter: lib/core/providers/team_org_providers.dart:277, lib/features/team_organization/presentation/widgets/my_tasks_card.dart:53, lib/core/providers/dashboard_providers.dart:304
- [ ] **niedrig** `messages/message-detail/message-detail.page` `x-b5f5a215de` **Mitteilung aus verlassener Instanz nicht mehr abrufbar** [src/app/services/message/message.service.ts:46](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/message/message.service.ts#L46) (2. Prüfung: korrigiert)
  getMessageById filtert auf aktuelle + eigene Instanzen; Ionic zeigt auch Mitteilungen aus einer verlassenen Instanz. [Entscheidung Leon 05.11.2026 (Entscheidungs-Dokument Nr. 5): so lassen, wer ausgetreten ist, sieht die Instanz nicht mehr → bewusst abweichend, niedrig.]
  Flutter: lib/data/repositories/message_repository.dart:48, lib/core/providers/message_providers.dart:58, lib/features/messages/presentation/pages/message_detail_page.dart:201
- [ ] **niedrig** `notifications/notifications.page` `x-1957eb8534` **Fehler beim Speichern der Einstellungen** [src/app/services/notification/notification.service.ts:55](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/notification/notification.service.ts#L55) (2. Prüfung: bestätigt)
  Weiter so: Ionic Toast „Fehler beim Updaten der Konfiguration, bitte versuche es später erneut.“ (danger), Schalter bleibt im neuen, nicht gespeicherten Zustand / Flutter Toast „Fehler beim Aktualisieren der Konfiguration“, Schalter springt zurück. Fehlermeldung in beiden vorhanden → niedrig. Zusatz: beim Live-Activity-Schalter ruft Flutter setEnabled auch nach fehlgeschlagenem Speichern auf.
  Flutter: lib/features/notifications/presentation/pages/notifications_page.dart:104, lib/features/notifications/presentation/pages/notifications_page.dart:110-115, lib/features/notifications/presentation/pages/notifications_page.dart:120-122
- [ ] **niedrig** `stats/stats.page` `x-c78a5253ee` **Statusverteilung: Legende ohne Prozent** [src/app/stats/stats.page.ts:240](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.ts#L240) (2. Prüfung: bestätigt)
  Besteht weiter. Ionic: Legende „Anwesend (x%)“, „Entschuldigt (x%)“, „Verspätet (x%)“, „Abwesend (x%)“ über dem Kreisdiagramm (stats.pieLabel) / Flutter: gleiche gerundete Prozente auf den Segmenten, Legende rechts nur mit Statusnamen, Ring statt voller Kreis.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:613-722
- [ ] **niedrig** `stats/stats.page` `x-d30471180e` **Leere Einzeldiagramme mit Platzhaltertext** [src/app/stats/stats.page.ts:380](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.ts#L380) (2. Prüfung: bestätigt)
  Besteht weiter, Zeilen aktualisiert (alte 1112/1197 ungültig). Ionic: leeres Diagramm (mit Titel), wenn keine Daten / Flutter: Platzhalter „Keine Daten verfügbar“, „Keine Geburtsdaten vorhanden“ bzw. „Keine unentschuldigten Abwesenheiten“.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:971-996, lib/features/statistics/presentation/pages/statistics_page.dart:626, lib/features/statistics/presentation/pages/statistics_page.dart:826, lib/features/statistics/presentation/pages/statistics_page.dart:924, lib/features/statistics/presentation/pages/statistics_page.dart:953
- [ ] **niedrig** `stats/stats.page` `x-82cbaeffb4` **Pull-to-refresh nur in Flutter** [src/app/stats/stats.page.html:12](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/stats/stats.page.html#L12) (2. Prüfung: bestätigt)
  Besteht weiter, Zeile aktualisiert. Flutter besser: Herunterziehen lädt Termine und Personen neu / Ionic: kein Refresher (stats.page.html ohne ion-refresher), nur erneutes Öffnen.
  Flutter: lib/features/statistics/presentation/pages/statistics_page.dart:164-169
