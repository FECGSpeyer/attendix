# Fix-Paket „termine“

Soll: Ionic 4.19.9 (1923d203). Ist: Flutter 1aba6be, 2157fa0, b218510, 3bacc76, 8004a44, c9dd1aa, , b15b3b0, 40d2b43, da49473, 84c4c44, 6945c13, 3cdaaa1, a0550a4, 4e13f22, 2353b98, 00e183c, 57bb011 (normales Design).
Erzeugt mit `node tool/parity/parity.mjs fixlists` aus `docs/parity/status/`. Item-IDs siehe `ionic-inventory.json`.

## Angleichen (hoch/mittel): 0


## Flutter besser – Leon entscheidet: 26

- [ ] **niedrig** `attendance/att-list/att-list.page` `db-563bc99b` [attendance/att-list/att-list.page.ts:230](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L230)
  Flutter besser: Ionic-Handler lädt nur bei event.new.tenantId === Instanz neu, person_attendances hat aber keine tenantId-Spalte (Inserts ohne tenantId, alle Abfragen joinen attendance.tenantId) → Ionic aktualisiert die Liste bei Statusänderungen nie. Flutter lädt bei jedem person_attendances-UPDATE neu (INSERT/DELETE nicht).
  Flutter: lib/core/providers/realtime_providers.dart:308
- [ ] **niedrig** `attendance/att-list/att-list.page` `db-4719045d` [attendance/att-list/att-list.page.ts:230](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L230)
  Flutter besser: Ionic-Kanal "person-att-changes" (event *) greift wegen fehlender tenantId-Spalte in person_attendances nie / Flutter: UPDATE-Listener im selben Kanal "attendance_list_changes_<tenantId>" lädt neu.
  Flutter: lib/core/providers/realtime_providers.dart:308
- [ ] **niedrig** `attendance/att-list/att-list.page` `action-4fff8ad6` [attendance/att-list/att-list.page.html:287](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L287) (2. Prüfung: bestätigt)
  Flutter besser: Button „Termin hinzufügen“ im Leerzustand nur mit Anlegerecht (canCreateAttendanceProvider, wie der FAB) / Ionic zeigt ihn allen Rollen der Seite (auch Beobachter und Helfer ohne attendance_create) und öffnet das Anlege-Sheet.
  Flutter: lib/features/attendance/presentation/pages/attendance_list_page.dart:239
- [ ] **niedrig** `attendance/att-list/att-list.page` `field-b83547ff` [attendance/att-list/att-list.page.html:386](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L386) (2. Prüfung: bestätigt)
  Flutter besser: beim automatisch gewählten ersten Typ ist die Dauer mit duration_days des Typs vorbelegt / Ionic zeigt dort 1 (onTypeChange läuft nur bei Nutzerauswahl) und legt dann einen 1-Tages-Termin an. Sonst gleich (Zahlenfeld nur bei all_day, Werte < 1 werden in Flutter ignoriert).
  Flutter: lib/features/attendance/presentation/pages/attendance_create_page.dart:160, lib/features/attendance/presentation/pages/attendance_create_page.dart:684
- [ ] **niedrig** `attendance/att-list/att-list.page` `action-4ef97afb` [attendance/att-list/att-list.page.html:520](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L520) (2. Prüfung: bestätigt)
  Flutter besser: „Werk(e) hinzufügen“ erst aktiv mit ≥1 Werk und Dirigent bzw. Namen / Ionic immer aktiv (ohne Werk nur Schließen); bei „Anderer Dirigent“ ohne Namen übernimmt Ionic person_id 9999999999. Achtung: ohne aktive Dirigenten erlaubt Ionic Werke ohne Dirigent, Flutter nur mit „Anderer Dirigent“ + Name.
  Flutter: lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:214, lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:250
- [ ] **niedrig** `attendance/attendance/attendance.page` `native-248ec156` [attendance/attendance/attendance.page.ts:290](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L290)
  Flutter besser: Ionic teardown ruft Network.removeAllListeners() und entfernt damit auch den globalen Reconnect-Listener der OfflineQueue (offline-queue.service.ts:44) → nach dem ersten Öffnen/Schließen eines Termins werden offline erfasste Status bei Reconnect nicht mehr automatisch gesendet (nur noch bei offenem Termin oder App-Neustart). Flutter: Seiten-Listener endet mit dem Widget, OfflineQueueNotifier flusht weiter global bei jedem Reconnect.
  Flutter: lib/core/services/offline_queue_service.dart:540, lib/features/attendance/presentation/pages/attendance_detail_page.dart:383
- [ ] **niedrig** `attendance/attendance/attendance.page` `alert-1a679783` [attendance/attendance/attendance.page.ts:800](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L800) (2. Prüfung: korrigiert)
  Flutter besser: Helfer (HELPER) ohne player_notes_view bekommt in Ionic im Dialog „Eigene Notiz“ die echte Notiz vorbelegt (value = player.notes); Flutter belegt die maskierte Notiz „Notiz hinzugefügt“ vor (visibleNotes) und speichert sie unverändert nicht zurück. Sonst gleich (Platzhalter „Notiz eingeben...“, Abbrechen/Speichern, leer bei Standardgrund aus tenant.absence_reasons, alle Rollen der Seite); Flutter trimmt. Erstprüfer übersah die Rollen-Maskierung.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/attendance_detail_sheets.dart:55, lib/features/attendance/presentation/pages/attendance_detail_page.dart:600, lib/features/attendance/presentation/pages/attendance_detail_page.dart:765, lib/features/attendance/presentation/widgets/attendance_detail/attendance_person_tile.dart:197
- [ ] **niedrig** `attendance/attendance/attendance.page` `db-f3ad3394` [attendance/attendance/attendance.page.ts:1112](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L1112) (2. Prüfung: korrigiert)
  Flutter besser: Ionic löscht `<id>/attachment/<attachment_name>` mit dem Originalnamen, hochgeladen wurde aber unter dem bereinigten Namen → bei Leer-/Sonderzeichen bleibt die Datei im Bucket liegen / Flutter löscht den bereinigten Pfad (attachmentPath). DB-Update attachment_url/attachment_name = null gleich. Erstreviewer hat den Pfadunterschied übersehen.
  Flutter: lib/data/repositories/attendance_repository.dart:1113, lib/features/attendance/presentation/widgets/attendance_detail/description_attachment_sheet.dart:131
- [ ] **niedrig** `attendance/attendance/attendance.page` `alert-ad3c579a` [attendance/attendance/attendance.page.ts:1806](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L1806)
  Flutter besser: sucht den Ändernden unter allen Personen des Mandanten (Ionic nur unter den Personen des Termins → sonst „'Unbekannt'“). Ionic-Sonderfall UUID 665fe2b4-… → „Matthias Eckstädt“ fehlt in Flutter.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:870
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-d5ac7ad9` [attendance/attendance/attendance.page.html:134](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L134)
  Flutter besser: Ionic zeigt den Eintrag allen Rollen außer HELPER (isHelper = role === HELPER), also auch Beobachtern (VIEWER); Flutter blendet ihn für Beobachter aus (canMutateAttendanceDetail = canEdit && !helper). Ob Ionic-Beobachter das speichern dürfen (RLS), ist hier nicht prüfbar – Leon entscheidet.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:1113, lib/features/attendance/presentation/pages/attendance_detail_page.dart:2579
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-ab758e8d` [attendance/attendance/attendance.page.html:140](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L140) (2. Prüfung: bestätigt)
  Flutter besser: Ionic zeigt „Checkliste starten“ allen Rollen außer HELPER (isHelper = role === HELPER), also auch Beobachtern / Flutter nur Admin, Verantwortliche, Stimmführer-Helfer (canMutateAttendanceDetail). Praktisch selten: Beobachter erreichen die Ionic-Detailseite nur über Umwege (Liste, Dashboard und Push öffnen sie für VIEWER nicht).
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:1115, lib/features/attendance/presentation/pages/attendance_detail_page.dart:2579
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-eb230380` [attendance/attendance/attendance.page.html:146](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L146)
  Flutter besser: Ionic zeigt den Eintrag allen Rollen außer HELPER (isHelper = role === HELPER), also auch Beobachtern (VIEWER); Flutter blendet ihn für Beobachter aus (canMutateAttendanceDetail = canEdit && !helper). Ob Ionic-Beobachter das speichern dürfen (RLS), ist hier nicht prüfbar – Leon entscheidet. Wiederherstellen ohne Rückfrage wie Ionic.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:1117
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-9dea2cd5` [attendance/attendance/attendance.page.html:166](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L166)
  Flutter besser: Ionic zeigt den Eintrag allen Rollen außer HELPER (isHelper = role === HELPER), also auch Beobachtern (VIEWER); Flutter blendet ihn für Beobachter aus (canMutateAttendanceDetail = canEdit && !helper). Ob Ionic-Beobachter das speichern dürfen (RLS), ist hier nicht prüfbar – Leon entscheidet.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:1123
- [ ] **niedrig** `attendance/attendance/attendance.page` `field-5f1a024e` [attendance/attendance/attendance.page.html:334](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L334) (2. Prüfung: bestätigt)
  Flutter besser: Ionic zeigt ein Zahlenfeld „Dauer (Tage)“, onInfoChanged schreibt duration_days aber nicht (Änderung geht beim Neuladen verloren) / Flutter zeigt die Dauer nur an.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/general_info_accordion.dart:281
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-da89e903` [attendance/attendance/attendance.page.html:378](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L378)
  Flutter besser: Ionic zeigt den Eintrag allen Rollen ohne Bedingung, also auch Beobachtern (VIEWER); Flutter blendet ihn für Beobachter aus (canEditAttendanceDescription = canEdit). Ob Ionic-Beobachter das speichern dürfen (RLS), ist hier nicht prüfbar – Leon entscheidet.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/general_info_accordion.dart:398, lib/features/attendance/presentation/pages/attendance_detail_page.dart:674
- [ ] **niedrig** `attendance/attendance/attendance.page` `text-592be266` [attendance/attendance/attendance.page.html:697](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L697) (2. Prüfung: bestätigt)
  Flutter besser: Helfer (HELPER) ohne player_notes_view sehen „Notiz hinzugefügt“ statt des Grundes / Ionic zeigt pa.notes im Besetzungsblock unmaskiert.
  Flutter: lib/features/duty/presentation/widgets/duty_staffing_section.dart:206, lib/features/duty/presentation/widgets/duty_staffing_section.dart:38
- [ ] **niedrig** `attendance/attendance/attendance.page` `text-dd2e2f27` [attendance/attendance/attendance.page.html:1022](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L1022)
  Flutter besser: „Andere Personen“ ist aufgeklappt, wenn es keine passenden Personen gibt / Ionic: immer eingeklappt.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/add_persons_sheet.dart:180, lib/features/attendance/presentation/widgets/attendance_detail/add_persons_sheet.dart:187
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-84a45123` [attendance/attendance/attendance.page.html:1062](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L1062)
  Flutter besser: iOS-FAB (Ablaufplan bearbeiten) fehlt für Beobachter / Ionic zeigt ihn allen Rollen, obwohl Beobachter den Ablaufplan-Bereich nicht sehen.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:456, lib/features/attendance/presentation/pages/attendance_detail_page.dart:800
- [ ] **niedrig** `attendance/att-list/att-list.page` `x-ad2ef27978` **Datumsbereich mehrtägiger ganztägiger Termine** [src/app/utilities/Utils.ts:1594](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/utilities/Utils.ts#L1594)
  Flutter besser: Ionic Utils.getReadableDate nutzt duration_days des Typs, auch wenn der Termin eine andere Dauer hat / Flutter nutzt duration_days des Termins (Fallback Typ).
  Flutter: lib/features/attendance/presentation/pages/attendance_list_page.dart:387
- [ ] **niedrig** `attendance/att-list/att-list.page` `x-a17a2b8a34` **Realtime für person_attendances** [src/app/attendance/att-list/att-list.page.ts:230](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L230)
  Flutter besser: Ionic-Handler prüft event.new.tenantId, die Tabelle hat keine tenantId → Liste wird nie aktualisiert / Flutter lädt bei jedem person_attendances-UPDATE neu.
  Flutter: lib/core/providers/realtime_providers.dart:308
- [ ] **niedrig** `attendance/att-list/att-list.page` `x-faa1356e28` **Typauswahl springt bei Neuladen zurück (Ionic)** [src/app/attendance/att-list/att-list.page.ts:311](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L311)
  Flutter besser: Ionic applyAttendances setzt type_id bei jedem Neuladen (z. B. Realtime-Ereignis) auf den ersten sichtbaren Typ, auch bei offenem Anlege-Modal / Flutter behält die gewählte Auswahl.
  Flutter: lib/features/attendance/presentation/pages/attendance_create_page.dart:155
- [ ] **niedrig** `attendance/att-list/att-list.page` `x-70670a344b` **Dauer-Vorbelegung beim Default-Typ** [src/app/attendance/att-list/att-list.page.ts:139](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L139)
  Flutter besser: Ionic ruft onTypeChange für den vorausgewählten Typ nicht auf → allDayDuration 1 statt duration_days des Typs / Flutter ruft _onTypeChanged auch für die Vorauswahl.
  Flutter: lib/features/attendance/presentation/pages/attendance_create_page.dart:159, lib/features/attendance/presentation/pages/attendance_create_page.dart:675
- [ ] **niedrig** `attendance/att-list/att-list.page` `x-8a16c9ab3f` **Anlegen: Rechteprüfung und Fehlermeldung** [src/app/attendance/att-list/att-list.page.ts:370](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L370)
  Flutter besser: Flutter prüft vor dem Schreiben erneut das Anlegerecht (Toast "Keine Berechtigung") und zeigt Schreibfehler als SnackBar / Ionic prüft nicht und bleibt bei Fehlern stumm (Overlay endet nach 3 s).
  Flutter: lib/features/attendance/presentation/pages/attendance_create_page.dart:841, lib/features/attendance/presentation/pages/attendance_create_page.dart:894
- [ ] **niedrig** `attendance/attendance/attendance.page` `x-5905254b84` **Helfer-Gruppenrecht bei Ladefehler** [src/app/attendance/attendance/attendance.page.ts:425](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L425) (2. Prüfung: bestätigt)
  Flutter besser, weiter real: Ionic (Z. 425–437) zeigt einem eingeschränkten Helfer/Stimmführer-Helfer bei Fehler beim Profil-Laden oder Profil ohne Gruppe die ungefilterte Liste aller Gruppen; Flutter zeigt dann niemanden (AttendanceGroupScope.denied, auch während des Ladens). Fehlt die Berechtigungszeile, sehen beide alle Gruppen.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:569, lib/core/providers/role_permission_providers.dart:227
- [ ] **niedrig** `attendance/attendance/attendance.page` `x-b6a4d5b9be` **Realtime übernimmt mehr** [src/app/attendance/attendance/attendance.page.ts:691](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L691)
  Flutter besser: von anderen Geräten hinzugefügte Personenzeilen (INSERT) erscheinen sofort, changed_by/changed_at werden live übernommen („Wer hat geändert?“ aktuell) / Ionic: INSERT wird ignoriert (players[-1]), Änderer-Info bleibt auf dem Ladestand.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:307, lib/features/attendance/presentation/pages/attendance_detail_page.dart:352
- [ ] **niedrig** `attendance/attendance/attendance.page` `x-443cc37b67` **„Person hinzufügen“: Kandidaten** [src/app/attendance/attendance/attendance.page.ts:2388](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L2388)
  Flutter besser: (1) Ionic schließt nur Personen aus this.players aus – ein eingeschränkter Stimmführer-Helfer bekommt Personen anderer Gruppen angeboten, die schon im Termin sind (Doppelzeile möglich); Flutter schließt alle vorhandenen Zeilen aus. (2) Ionic sucht die Gruppe in this.instruments ohne Hauptgruppe → Personen der Hauptgruppe heißen „Keine Gruppe“ und stehen ganz unten; Flutter zeigt deren Gruppennamen und sortiert nach deren sort_order.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:1356, lib/features/attendance/presentation/widgets/attendance_detail/add_persons_sheet.dart:55, lib/features/attendance/presentation/attendance_add_persons.dart:51

## Kleinigkeiten (niedrig): 67

- [ ] **niedrig** `attendance/att-list/att-list.page` `loading-e1caea8b` [attendance/att-list/att-list.page.ts:254](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L254)
  Ionic: blockierendes Loading-Overlay (3 s) während setTenant + Navigation / Flutter: switchTenant ohne Overlay oder Ladeanzeige.
  Flutter: lib/shared/widgets/tenant/tenant_switcher_title.dart:389
- [ ] **niedrig** `attendance/att-list/att-list.page` `loading-64f98ca9` [attendance/att-list/att-list.page.ts:371](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L371) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading-Overlay (Utils.getLoadingElement, endet spätestens nach 3 s) / Flutter: kein Overlay, Spinner im Absenden-Eintrag, Eintrag deaktiviert, Sheet per PopScope/shouldCloseOnMinExtent nicht schließbar; übrige Felder bleiben bedienbar.
  Flutter: lib/features/attendance/presentation/pages/attendance_create_page.dart:850, lib/features/attendance/presentation/pages/attendance_create_page.dart:475, lib/features/attendance/presentation/pages/attendance_create_page.dart:491
- [ ] **niedrig** `attendance/att-list/att-list.page` `toast-2921a95c` [attendance/att-list/att-list.page.ts:385](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L385) (2. Prüfung: bestätigt)
  Ionic: Toast (danger) „Ungültiger Anwesenheitstyp ausgewählt“, wenn type_id keinem Typ entspricht (z. B. kein sichtbarer Typ) / Flutter: neutrale SnackBar „Bitte wähle einen Veranstaltungstyp“ (attListInvalidType ungenutzt), Prüfung vor der Datumsprüfung.
  Flutter: lib/features/attendance/presentation/pages/attendance_create_page.dart:821
- [ ] **niedrig** `attendance/att-list/att-list.page` `alert-c973a254` [attendance/att-list/att-list.page.ts:621](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L621) (2. Prüfung: korrigiert)
  Alert „Dirigent eingeben“ (Platzhalter „Dirigent“, Abbrechen/Speichern) gleich. Flutter besser: bei Abbrechen oder leerem Namen wird die vorherige Dirigentenauswahl wiederhergestellt; Ionic lässt „Anderer Dirigent“ ohne Namen stehen bzw. speichert leeren Namen.
  Flutter: lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:106
- [ ] **niedrig** `attendance/att-list/att-list.page` `action-d02e9e23` [attendance/att-list/att-list.page.html:115](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L115)
  Ionic: Titel getEventTitle (typeInfo / Typname außer hide_name / Datum), Meta "Di., 20.10.2026 · 19:00–21:00"; Tap öffnet Termin nur für Dirigent/Helfer / Flutter: Titel typeInfo / Typname / "Dienst" (hide_name ignoriert), Meta "Di, 20.10. · 19:00" (ohne Jahr, ohne Endzeit); Tap ohne Rollenprüfung.
  Flutter: lib/features/duty/presentation/widgets/my_duty_requests_section.dart:42, lib/features/duty/presentation/widgets/my_duty_requests_section.dart:71, lib/data/repositories/duty_repository.dart:41
- [ ] **niedrig** `attendance/att-list/att-list.page` `action-c806441b` [attendance/att-list/att-list.page.html:129](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L129)
  Gefüllte Karte mit Datumskachel, Titel, Ort mit Icon, Dienst-Besetzung bzw. "% · anwesend · entschuldigt · abwesend", CTAs und Tap wie Ionic. Abweichung Meta: Flutter lässt die Uhrzeit bei ganztägigen Typen weg (Ionic zeigt start_time, z. B. Plan-Start) und nimmt für den Datumsbereich duration_days des Termins statt des Typs.
  Flutter: lib/features/attendance/presentation/pages/attendance_list_page.dart:493, lib/features/attendance/presentation/pages/attendance_list_page.dart:195, lib/features/attendance/presentation/pages/attendance_list_page.dart:405
- [ ] **niedrig** `attendance/att-list/att-list.page` `action-15811e3a` [attendance/att-list/att-list.page.html:192](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L192)
  Zeile wie Ionic (Kachel mit Hervorhebung, Headset-Icon, Titel, Meta, Dienst-Namen, Ablaufplan-Button, Besetzung bzw. %-Pill, Tap). Abweichung: bei ganztägigen Typen fehlt in Flutter die Uhrzeit in der Meta-Zeile (Ionic zeigt start_time, falls gesetzt).
  Flutter: lib/features/attendance/presentation/pages/attendance_list_page.dart:531, lib/features/attendance/presentation/pages/attendance_list_page.dart:405
- [ ] **niedrig** `attendance/att-list/att-list.page` `action-15811e3a-2` [attendance/att-list/att-list.page.html:249](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L249)
  Ionic: vergangene Zeilen zeigen immer "{percentage}%" / Flutter: percentPill zeigt bei Dienst-Terminen (letzte 180 Tage) die Besetzung "1/2" statt Prozent. Rest (Archiv-Icon, "Datum · x von y anwesend", Tap nur Dirigent/Helfer) gleich.
  Flutter: lib/features/attendance/presentation/pages/attendance_list_page.dart:585, lib/features/attendance/presentation/pages/attendance_list_page.dart:433
- [ ] **niedrig** `attendance/att-list/att-list.page` `text-16ffe6c1` [attendance/att-list/att-list.page.html:326](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L326) (2. Prüfung: bestätigt)
  Text „Feiertage des ausgewählten Bundeslandes“ gleich, gleiche Bedingung; Punktfarbe AppColors.danger (#B95B5B) statt Ionic „holiday“ (#9f6073, als AppColors.holiday vorhanden).
  Flutter: lib/features/attendance/presentation/pages/attendance_create_page.dart:772
- [ ] **niedrig** `attendance/att-list/att-list.page` `text-eda8e24c` [attendance/att-list/att-list.page.html:342](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L342)
  Format "dd.MM.yyyy - dd.MM.yyyy: Name" gleich. Ionic blendet Ferien aus, sobald sie begonnen haben (gone = startDate < heute) / Flutter erst nach dem Ende (isPast = endDate < jetzt) → laufende Ferien stehen in Flutter noch in der Liste.
  Flutter: lib/features/attendance/presentation/pages/attendance_create_page.dart:784, lib/core/services/holiday_service.dart:168
- [ ] **niedrig** `attendance/att-list/att-list.page` `text-eda8e24c-2` [attendance/att-list/att-list.page.html:356](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L356)
  Format "dd.MM.yyyy: Name" gleich. Ionic zeigt einen Feiertag am Tag selbst noch (gone = startDate < heute) / Flutter blendet ihn am Tag selbst aus (isPast = endDate 00:00 < jetzt).
  Flutter: lib/features/attendance/presentation/pages/attendance_create_page.dart:790, lib/core/services/holiday_service.dart:122
- [ ] **niedrig** `attendance/att-list/att-list.page` `modal-c5f95b6f` [attendance/att-list/att-list.page.html:365](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L365)
  Ionic: kleines Karten-Modal (290×382) nur mit dem Kalender, Auswahl wirkt sofort, Schließen per Hintergrund / Flutter: Dialog mit Titel "Datum auswählen", X, Legende und "Abbrechen"/"Übernehmen"; Schließen ohne "Übernehmen" verwirft die Auswahl.
  Flutter: lib/features/attendance/presentation/pages/attendance_create_page.dart:702, lib/features/attendance/presentation/widgets/multi_date_calendar.dart:347
- [ ] **niedrig** `attendance/att-list/att-list.page` `field-6afb28e4` [attendance/att-list/att-list.page.html:367](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L367)
  Mehrfachauswahl, Montag als Wochenstart, Hervorhebung von Terminen (Typfarbe), Feiertagen und Ferien vorhanden. Abweichungen: Feiertagsfarbe rot statt #9f6073; Termine unsichtbarer Typen nicht hervorgehoben (visibleAttendanceTypesProvider statt aller Typen); wählbar nur heute−365 bis heute+730 Tage.
  Flutter: lib/features/attendance/presentation/widgets/multi_date_calendar.dart:58, lib/features/attendance/presentation/widgets/multi_date_calendar.dart:195, lib/features/attendance/presentation/widgets/multi_date_calendar.dart:67
- [ ] **niedrig** `attendance/att-list/att-list.page` `modal-aff28de3` [attendance/att-list/att-list.page.html:447](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L447) (2. Prüfung: bestätigt)
  Vollbildseite „Werke auswählen“ mit Suche wie Ionic, aber Auswahl wird nur mit ✓ übernommen; X/Zurück verwirft sie (Ionic: Auswahl wirkt sofort, jedes Schließen behält sie). Suchbegriff wird in Flutter bei jedem Öffnen zurückgesetzt.
  Flutter: lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:234, lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:323
- [ ] **niedrig** `attendance/att-list/att-list.page` `text-55882df1` [attendance/att-list/att-list.page.html:473](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L473)
  Ionic: "Keine Werke gefunden" nur bei leerem Ergebnis UND Suchbegriff / Flutter: auch ohne Suchbegriff, wenn die Instanz gar keine Werke hat.
  Flutter: lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:350
- [ ] **niedrig** `attendance/att-list/att-list.page` `text-8babe4ac` [attendance/att-list/att-list.page.html:533](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L533) (2. Prüfung: bestätigt)
  Ionic: „{number} {name}“ (ohne Präfix) bzw. „Unbekanntes Lied“ / Flutter: „{prefix}{number} - {name}“ bzw. „Unbekannt“.
  Flutter: lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:413, lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:284, lib/data/models/song/song.dart:150
- [ ] **niedrig** `attendance/attendance/ad-hoc-reminder-modal/ad-hoc-reminder-modal.component` `action-bd4f009d` [attendance/attendance/ad-hoc-reminder-modal/ad-hoc-reminder-modal.component.html:5](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/ad-hoc-reminder-modal/ad-hoc-reminder-modal.component.html#L5)
  Ionic: Schließen-Button (X) in der Toolbar / Flutter: kein X; Schließen nur per Wischen, Tippen außerhalb oder Zurück.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/ad_hoc_reminder_sheet.dart:59
- [ ] **niedrig** `attendance/attendance/ad-hoc-reminder-modal/ad-hoc-reminder-modal.component` `action-a496bc4d` [attendance/attendance/ad-hoc-reminder-modal/ad-hoc-reminder-modal.component.html:56](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/ad-hoc-reminder-modal/ad-hoc-reminder-modal.component.html#L56)
  Ionic: Link antippbar (<a target="_blank"> öffnet den Browser) / Flutter: nur SelectableText, nicht antippbar.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/ad_hoc_reminder_sheet.dart:163
- [ ] **niedrig** `attendance/attendance/attendance.page` `toast-87a629e9` [attendance/attendance/attendance.page.ts:544](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L544)
  Ionic: Toast (danger) „Neu laden fehlgeschlagen — bitte erneut versuchen.“ / Flutter: „Neu laden“ invalidiert nur die Provider; bei erneutem Fehler kein Toast, Banner/Fehlerseite bleibt.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:1461, lib/features/attendance/presentation/pages/attendance_detail_page.dart:1486
- [ ] **niedrig** `attendance/attendance/attendance.page` `actionsheet-5fe69f80` [attendance/attendance/attendance.page.ts:789](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L789)
  Sheet gleich (Header „Notiz hinzufügen“, „Aktuell: …“, Gründe, „Eigene Notiz...“, „Notiz löschen“ destruktiv, Abbrechen). Flutter zeigt nach dem Speichern zusätzlich einen Erfolgs-Toast „Notiz hinzugefügt“/„Notiz gelöscht“ (Ionic: kein Toast).
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/attendance_detail_sheets.dart:26, lib/features/attendance/presentation/pages/attendance_detail_page.dart:857
- [ ] **niedrig** `attendance/attendance/attendance.page` `loading-41558b08` [attendance/attendance/attendance.page.ts:1077](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L1077)
  Ionic: blockierendes Loading während des Uploads / Flutter: nur Spinner im Sheet, nicht blockierend.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/description_attachment_sheet.dart:110
- [ ] **niedrig** `attendance/attendance/attendance.page` `effect-839f92ba` [attendance/attendance/attendance.page.ts:1275](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L1275) (2. Prüfung: korrigiert)
  mittel-Lücke behoben (#306): Segment „Nur <Plan>“/„Alle n Pläne“ × PDF / PDF 2x A5 (2x A5 jetzt auch für alle), Titel mit planning_title/Typname wie getPlanningTitle, Name „…_alle“/„_2x“. Rest niedrig: Dateidatum = Termin-Start statt Plandatum (bei „Nur“ eines späteren Tages), Unterzeile hängt bei mehreren Plänen immer „· <Plan>“ an (Ionic planSubtitle nur ohne Tag oder mit eigenem Namen), „Alle“ nimmt auch Pläne ohne Punkte als Seite auf (Ionic filtert sie heraus).
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/plan_accordion.dart:128, lib/features/attendance/presentation/widgets/attendance_detail/plan_accordion.dart:154, lib/features/planning/presentation/widgets/plan_export_actions.dart:114
- [ ] **niedrig** `attendance/attendance/attendance.page` `effect-7cdd0978` [attendance/attendance/attendance.page.ts:1436](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L1436) (2. Prüfung: korrigiert)
  mittel-Lücke behoben (#306): Bei mehreren Plänen Teilen-Sheet mit „Nur <Plan>“/„Alle n Pläne“, Telegram PDF / PDF 2x A5 für einen oder alle Pläne, Bild nur für einen (nur mit Chat-ID), Titel plan.title || planning_title (typeInfo) || typeInfo || Typname, Name mit „_alle“/„_2x“. Rest niedrig: Dateiname nimmt immer das Termin-Startdatum (Ionic planDate des ersten exportierten Plans → bei „Nur Tag 2“ anderes Datum) und bei „Alle“ den Titel des gerade gezeigten statt des ersten Plans.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/plan_accordion.dart:149, lib/features/attendance/presentation/widgets/attendance_detail/plan_accordion.dart:166, lib/features/planning/presentation/widgets/plan_export_actions.dart:261, lib/features/planning/presentation/widgets/plan_export_actions.dart:170
- [ ] **niedrig** `attendance/attendance/attendance.page` `actionsheet-0085a6c3` [attendance/attendance/attendance.page.ts:1574](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L1574)
  Optionen gleich („Dirigent ändern“, „Zum Werk“, Abbrechen). Header Ionic „12 Name“ (Nummer ohne Präfix) / Flutter Song.displayName mit Präfix und „ - “; unbekannt: Ionic „Unbekanntes Lied“ / „Unbekannter Dirigent“, Flutter „Unbekanntes Werk“ / „Unbekannt“.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:2126, lib/features/attendance/presentation/widgets/attendance_detail/songs_history_accordion.dart:33
- [ ] **niedrig** `attendance/attendance/attendance.page` `alert-aadedcba` [attendance/attendance/attendance.page.ts:1692](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L1692) (2. Prüfung: korrigiert)
  Alert „Dirigent eingeben“ (Platzhalter „Dirigent“, Abbrechen/Speichern) gleich. Flutter besser: bei Abbrechen oder leerem Namen wird die vorherige Dirigentenauswahl wiederhergestellt; Ionic lässt „Anderer Dirigent“ ohne Namen stehen bzw. speichert leeren Namen.
  Flutter: lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:106
- [ ] **niedrig** `attendance/attendance/attendance.page` `actionsheet-1aaa2155` [attendance/attendance/attendance.page.ts:1954](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L1954)
  Reihenfolge und Bedingungen gleich. Flutter besser: „Erinnerung“ für eine Person ohne Account zeigt „Die Person hat keinen Account“; Ionic sendet dann (playerAppId undefined) an alle Personen des Termins.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/attendance_person_tile.dart:207, lib/features/attendance/presentation/pages/attendance_detail_page.dart:775
- [ ] **niedrig** `attendance/attendance/attendance.page` `effect-8f43ff82` [attendance/attendance/attendance.page.ts:1963](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L1963) (2. Prüfung: korrigiert)
  hoch-Lücke behoben (#306): Excel exportiert jetzt die Personen der Liste (Helfer/Helfer-Stimmführer ohne attendance_all_groups nur die eigene Gruppe, resolvedGroupScope) sortiert nach Hauptgruppe/Gruppenreihenfolge/Name. Spalten, Status, Gemeinde, Dateiname gleich. Bleibt: Flutter besser: HELPER ohne player_notes_view bekommt eine leere Notizspalte (Ionic exportiert user.notes ungefiltert, obwohl die Ansicht sie verbirgt).
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:2517, lib/features/attendance/presentation/pages/attendance_detail_page.dart:2533, lib/features/attendance/presentation/pages/attendance_detail_page.dart:2539, lib/core/providers/role_permission_providers.dart:97
- [ ] **niedrig** `attendance/attendance/attendance.page` `alert-3e7845a6` [attendance/attendance/attendance.page.ts:2022](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L2022)
  Dialog gleich („To-Do hinzufügen“, Text, Frist in Stunden, Abbrechen/Hinzufügen). Flutter zeigt zusätzlich Toast „To-Do hinzugefügt“.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:1530, lib/features/attendance/presentation/pages/attendance_detail_page.dart:1601
- [ ] **niedrig** `attendance/attendance/attendance.page` `alert-87434869` [attendance/attendance/attendance.page.ts:2126](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L2126)
  Titel „To-Do löschen?“ (Flutter-Key), Text und Buttons gleich. Flutter zeigt nach dem Löschen zusätzlich Toast „To-Do gelöscht“.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:1610
- [ ] **niedrig** `attendance/attendance/attendance.page` `loading-b675baf2` [attendance/attendance/attendance.page.ts:2349](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L2349)
  Ionic: blockierendes Loading „Wird versendet...“ / Flutter: kein Overlay (nur Doppelversand-Sperre).
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:1401
- [ ] **niedrig** `attendance/attendance/attendance.page` `loading-c10b1ad4` [attendance/attendance/attendance.page.ts:2488](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L2488)
  Ionic: blockierendes Loading „Personen werden hinzugefügt...“ / Flutter: kein Overlay.
  Flutter: lib/features/attendance/presentation/attendance_add_persons.dart:55
- [ ] **niedrig** `attendance/attendance/attendance.page` `text-4ed35fba` [attendance/attendance/attendance.page.html:251](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L251)
  Ionic: Typ nicht auflösbar → Badge „Unbekannt“ / Flutter: Zeile „Typ“ fehlt dann ganz.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/general_info_accordion.dart:171, lib/features/attendance/presentation/widgets/attendance_detail/general_info_accordion.dart:182
- [ ] **niedrig** `attendance/attendance/attendance.page` `field-3d7244ba` [attendance/attendance/attendance.page.html:259](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L259)
  Speichern beim Verlassen wie Ionic; leeres Feld: Ionic schreibt '' / Flutter null (gleiche Anzeige).
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/general_info_accordion.dart:93, lib/features/attendance/presentation/pages/attendance_detail_page.dart:2280
- [ ] **niedrig** `attendance/attendance/attendance.page` `field-291ed873` [attendance/attendance/attendance.page.html:264](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L264)
  Speichern beim Verlassen wie Ionic; leeres Feld: Ionic schreibt '' / Flutter null (gleiche Anzeige).
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/general_info_accordion.dart:99, lib/features/attendance/presentation/pages/attendance_detail_page.dart:639
- [ ] **niedrig** `attendance/attendance/attendance.page` `field-55765067` [attendance/attendance/attendance.page.html:270](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L270)
  Standardfrist (Vortag, Typ-Start+2 h, sonst Termintag) wie Ionic. Flutter zeigt zusätzlich Toast „Frist aktiviert/deaktiviert“; auf iOS ohne Hilfetext (laut Flutter-Kommentar wie Ionic iOS; ion-toggle-Interna nicht im Container).
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/general_info_accordion.dart:220, lib/features/attendance/presentation/pages/attendance_detail_page.dart:1735
- [ ] **niedrig** `attendance/attendance/attendance.page` `modal-761bba53` [attendance/attendance/attendance.page.html:280](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L280)
  Ionic: ein Modal mit Datum+Uhrzeit (date-time) / Flutter: erst Datums-, dann Uhrzeit-Dialog.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:1774
- [ ] **niedrig** `attendance/attendance/attendance.page` `field-f27959a3` [attendance/attendance/attendance.page.html:297](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L297)
  Speichern + Schicht-Neuberechnung wie Ionic. Ionic: Minuten nur in 5er-Schritten / Flutter: freie Minutenwahl; Flutter zeigt zusätzlich einen Erfolgs-Toast.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/general_info_accordion.dart:265, lib/features/attendance/presentation/pages/attendance_detail_page.dart:2297
- [ ] **niedrig** `attendance/attendance/attendance.page` `field-95734d84` [attendance/attendance/attendance.page.html:316](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L316)
  Ionic: Minuten nur in 5er-Schritten / Flutter: freie Minutenwahl; Flutter zeigt zusätzlich einen Erfolgs-Toast.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/general_info_accordion.dart:275, lib/features/attendance/presentation/pages/attendance_detail_page.dart:2352
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-a166edd0` [attendance/attendance/attendance.page.html:382](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L382)
  Export wie Ionic; Flutter zeigt vorher zusätzlich einen Info-Toast „Excel wird erstellt…“.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/general_info_accordion.dart:405, lib/features/attendance/presentation/pages/attendance_detail_page.dart:2418
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-009eaece` [attendance/attendance/attendance.page.html:404](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L404)
  Ionic: X-Button zum Schließen / Flutter: kein Schließen-Button (nur Wischen/Griff).
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/description_attachment_sheet.dart:24
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-771e09e7` [attendance/attendance/attendance.page.html:448](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L448)
  Ionic: „12 Name“ (Nummer ohne Präfix), „Unbekanntes Lied“ / „Unbekannter Dirigent“ / Flutter: „W12 - Name“ (Song.displayName), „Unbekanntes Werk“ / „Unbekannt“.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/songs_history_accordion.dart:33
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-9a1384d5` [attendance/attendance/attendance.page.html:453](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L453) (2. Prüfung: bestätigt)
  Entfernen ohne Rückfrage wie Ionic (Flutter über Abgleich der history-Zeilen statt direktem Löschen per id); Flutter zeigt zusätzlich Toast „Werk entfernt“.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/songs_history_accordion.dart:41, lib/features/attendance/presentation/pages/attendance_detail_page.dart:2079
- [ ] **niedrig** `attendance/attendance/attendance.page` `modal-a9aad035` [attendance/attendance/attendance.page.html:460](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L460)
  Sheet wie Ionic (0.7); Flutter hat zusätzlich ein X oben.
  Flutter: lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:133
- [ ] **niedrig** `attendance/attendance/attendance.page` `field-3ee5c084` [attendance/attendance/attendance.page.html:493](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L493) (2. Prüfung: korrigiert)
  Ionic: ion-searchbar mit Lösch-X (ionClear → resetSongSearch) / Flutter: SearchBar ohne Lösch-Button, Text nur manuell löschbar. Platzhalter „Werk suchen...“ und Suche über „Präfix+Nummer Name“ gleich. Rollen/Mandant gleich: Werke-Bereich für alle Rollen mit Terminzugriff (Admin, Verantwortlich, Helfer, StF-Helfer), nur bei Typ manage_songs und Mandant ≠ general (showSongsForType), keine weitere Rollenprüfung. Erstprüfung übersah das fehlende Clear.
  Flutter: lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:330, lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:343
- [ ] **niedrig** `attendance/attendance/attendance.page` `text-5c344678` [attendance/attendance/attendance.page.html:503](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L503) (2. Prüfung: bestätigt)
  Ionic: „Keine Werke gefunden“ nur bei Suchbegriff ohne Treffer / Flutter: auch ohne Suchbegriff, wenn keine Werke existieren.
  Flutter: lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:350
- [ ] **niedrig** `attendance/attendance/attendance.page` `field-2a3cbef9` [attendance/attendance/attendance.page.html:530](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L530) (2. Prüfung: korrigiert)
  Optionen (aktive Dirigenten + „Anderer Dirigent“), Label „Dirigent“ und Rollen gleich. Aber Vorauswahl: Ionic setzt immer den ersten aktiven Dirigenten / Flutter liest im postFrameCallback ref.read(activeConductorsProvider).valueOrNull; der Provider wird erst beim Öffnen des Sheets erzeugt und ist dann noch AsyncLoading → beim ersten Öffnen pro App-Sitzung keine Vorauswahl („Wählen“), „Werk(e) hinzufügen“ bleibt bis zur manuellen Auswahl deaktiviert. Erstprüfung nahm Vorauswahl als gegeben an.
  Flutter: lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:163, lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:95
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-8beaeeab` [attendance/attendance/attendance.page.html:549](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L549)
  Ionic: „Hinzufügen“, immer tippbar / Flutter: „Werk(e) hinzufügen“, deaktiviert bis Werk und Dirigent gewählt.
  Flutter: lib/features/attendance/presentation/widgets/songs_selection_sheet.dart:216
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-2f4b32ed` [attendance/attendance/attendance.page.html:604](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L604) (2. Prüfung: korrigiert)
  Dialog gleich (Header „To-Do hinzufügen“, Text + Stunden, Abbrechen/Hinzufügen, Warnung ohne Text, dueDate ab Terminbeginn); Flutter zeigt nach dem Speichern zusätzlich Toast „To-Do hinzugefügt“ (Ionic keiner). Erstreviewer hat das als ok gewertet, die gleichartigen Zusatz-Toasts bei action-9a1384d5/action-5fb9b753 aber als diff.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/checklist_accordion.dart:137, lib/features/attendance/presentation/pages/attendance_detail_page.dart:1577, lib/features/attendance/presentation/pages/attendance_detail_page.dart:1601
- [ ] **niedrig** `attendance/attendance/attendance.page` `media-5cb3848f` [attendance/attendance/attendance.page.html:639](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L639) (2. Prüfung: bestätigt)
  Ionic: Besetzungsblock zeigt vor jeder eingeteilten Person ein ion-avatar mit pa.img (für alle Rollen) / Flutter: ListTile ohne leading, kein Bild.
  Flutter: lib/features/duty/presentation/widgets/duty_staffing_section.dart:126
- [ ] **niedrig** `attendance/attendance/attendance.page` `text-da1403f3` [attendance/attendance/attendance.page.html:641](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L641)
  Ionic: Avatar (pa.img) vor dem Namen / Flutter: ohne Avatar.
  Flutter: lib/features/duty/presentation/widgets/duty_staffing_section.dart:129
- [ ] **niedrig** `attendance/attendance/attendance.page` `text-39e7db32` [attendance/attendance/attendance.page.html:780](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L780) (2. Prüfung: korrigiert)
  Label „Start“ und Rollen gleich. Aber Live-Modus in den 5 Min vor Beginn: Ionic markiert schon das erste Feld als aktiv (Countdown-Badge bis Feldende), unter „Start“ nichts / Flutter: kein aktives Feld vor Beginn, dafür Flutter-eigene Zeile „beginnt in X Min.“ unter „Start“. Erstprüfung hat den Live-Modus übersehen.
  Flutter: lib/features/planning/presentation/widgets/plan_view_list.dart:88, lib/features/planning/presentation/widgets/plan_view_list.dart:99, lib/core/utils/plan_utils.dart:459
- [ ] **niedrig** `attendance/attendance/attendance.page` `text-1ffb6841` [attendance/attendance/attendance.page.html:781](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L781)
  Ionic: „19:00 Uhr“ als Badge / Flutter: graue Textnotiz.
  Flutter: lib/features/planning/presentation/widgets/plan_view_list.dart:102
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-0c508800` [attendance/attendance/attendance.page.html:785](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L785)
  Tap auf TOP öffnet das Thema (nur Leitung) wie Ionic. Ionic: list-circle-Icon vor TOP-Feldern, Minuten als Badge / Flutter: kein Icon, Minuten als graue Notiz.
  Flutter: lib/features/planning/presentation/widgets/plan_view_list.dart:150, lib/features/planning/presentation/widgets/plan_view_list.dart:161, lib/features/attendance/presentation/widgets/attendance_detail/plan_accordion.dart:239
- [ ] **niedrig** `attendance/attendance/attendance.page` `text-1ffb6841-2` [attendance/attendance/attendance.page.html:812](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L812)
  Ionic: Uhrzeit als Badge / Flutter: graue Textnotiz.
  Flutter: lib/features/planning/presentation/widgets/plan_view_list.dart:214
- [ ] **niedrig** `attendance/attendance/attendance.page` `text-d9253f57` [attendance/attendance/attendance.page.html:876](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L876) (2. Prüfung: bestätigt)
  Ionic: Notiz einzeilig abgeschnitten (ion-label ohne ion-text-wrap) / Flutter: bis zu 2 Zeilen. Maskierung für Helfer ohne Recht gleich.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/attendance_person_tile.dart:116
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-7ee9567b` [attendance/attendance/attendance.page.html:969](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L969)
  Ionic: X-Button zum Schließen / Flutter: kein Schließen-Button (nur Wischen/Griff).
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/add_persons_sheet.dart:77
- [ ] **niedrig** `attendance/attendance/attendance.page` `text-eec80d76` [attendance/attendance/attendance.page.html:979](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L979)
  Ionic: Sheet öffnet sofort mit Spinner „Lade Personen...“ / Flutter: lädt vor dem Öffnen, kein Ladehinweis.
  Flutter: lib/features/attendance/presentation/attendance_add_persons.dart:32
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-33556934` [attendance/attendance/attendance.page.html:1077](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L1077)
  Ionic: X-Icon (close-outline) / Flutter: Textbutton „Abbrechen“.
  Flutter: lib/shared/widgets/event_list/excuse_reason_sheet.dart:389
- [ ] **niedrig** `attendance/attendance/attendance.page` `action-5fb9b753` [attendance/attendance/attendance.page.html:1121](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.html#L1121) (2. Prüfung: bestätigt)
  Speichern (Merge in registration_answers inkl. Standardwerten, offline-fähig) wie Ionic; Flutter zeigt zusätzlich Toast „Anmeldefelder gespeichert“.
  Flutter: lib/shared/widgets/event_list/excuse_reason_sheet.dart:408, lib/features/attendance/presentation/pages/attendance_detail_page.dart:2263
- [ ] **niedrig** `attendance/auto-message-panel/auto-message-panel.component` `action-32eb1cf7` [attendance/auto-message-panel/auto-message-panel.component.html:34](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/auto-message-panel/auto-message-panel.component.html#L34) (2. Prüfung: korrigiert)
  Button, Bedingung (Admin/Verantwortliche, Regel noch nicht gelaufen, Sendezeit in der Zukunft) und Insert in auto_message_runs (status suspended, created_by) gleich. Aber created_by_name: Ionic nimmt db.teamPerson() – nur geladen mit Teamorganisation (Einstellungen/Teamorg/Meine Aufgaben), sonst E-Mail / Flutter nimmt ownProfileProvider – nur geladen nach Besuch der Einstellungen oder mit Seitenleiste (Tablet), sonst E-Mail. „Ausgesetzt von …“ zeigt daher je nach Situation Name statt E-Mail oder umgekehrt.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/auto_message_panel.dart:165, lib/data/repositories/auto_message_repository.dart:206
- [ ] **niedrig** `attendance/att-list/att-list.page` `x-57163c321f` **Vergangene Dienst-Termine mit Besetzungs-Pill** [src/app/attendance/att-list/att-list.page.html:263](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.html#L263)
  Ionic: vergangene Termine immer mit "{percentage}%" / Flutter: Dienst-Termine der letzten 180 Tage zeigen die Besetzung ("1/2", "1/2 ?").
  Flutter: lib/features/attendance/presentation/pages/attendance_list_page.dart:433, lib/features/attendance/presentation/pages/attendance_list_page.dart:608
- [ ] **niedrig** `attendance/att-list/att-list.page` `x-62e5886e11` **"Deine Dienste: bitte bestätigen" – Quelle und Anzeige** [src/app/attendance/att-list/att-list.page.ts:485](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L485)
  Ionic: aus allen geladenen Terminen, nicht beendet (auch laufende mehrtägige), nur mit myPersonId (Dirigent/Helfer); Titel getEventTitle, Meta mit Jahr und Endzeit / Flutter: myDutyOverviewProvider ab heute 00:00 (laufende mehrtägige Dienste fehlen), für jede Rolle mit eigener Person (z. B. Beobachter), Titel ohne hide_name-Logik, Meta "Di, 20.10. · 19:00".
  Flutter: lib/core/providers/duty_providers.dart:148, lib/features/duty/presentation/widgets/my_duty_requests_section.dart:71, lib/data/repositories/duty_repository.dart:254
- [ ] **niedrig** `attendance/att-list/att-list.page` `x-9a86a96938` **Meta-Zeile: Uhrzeit bei ganztägigen Typen** [src/app/attendance/att-list/att-list.page.ts:699](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L699)
  Ionic getEventMeta zeigt eventTimeRange(start_time/end_time) auch bei ganztägigen Typen (z. B. Plan-Start) / Flutter lässt die Uhrzeit bei allDay-Typen weg.
  Flutter: lib/features/attendance/presentation/pages/attendance_list_page.dart:412
- [ ] **niedrig** `attendance/att-list/att-list.page` `x-ca6698be06` **Formular-Zustand nach Schließen ohne Speichern** [src/app/attendance/att-list/att-list.page.ts:426](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/att-list/att-list.page.ts#L426)
  Ionic: Eingaben (Daten, Info-Text, Ort, Werke, Werk-Auswahl) bleiben im Modal erhalten, zurückgesetzt wird nur nach erfolgreichem Anlegen / Flutter: Sheet wird jedes Mal neu aufgebaut (heute, erster Typ, leere Felder).
  Flutter: lib/features/attendance/presentation/pages/attendance_create_page.dart:29
- [ ] **niedrig** `attendance/attendance/attendance.page` `x-4dd0cff1ed` **history.visible-Abgleich fehlt** [src/app/attendance/attendance/attendance.page.ts:1521](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L1521) (2. Prüfung: bestätigt)
  Weiter real (Ionic attendance.page.ts:1533–1537 unverändert): onInfoChanged setzt nach Info/Notizen/Zeiten/Frist alle Werke-Einträge auf visible = save_in_history, wenn der erste abweicht; Flutter liest save_in_history nirgends. Wirkt nur bei Alt-Terminen mit save_in_history false/null (beide Apps legen true an, Feld nicht editierbar), daher niedrig.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:2280
- [ ] **niedrig** `attendance/attendance/attendance.page` `x-33b53c7e65` **Sortierung „Person hinzufügen“** [src/app/attendance/attendance/attendance.page.ts:2421](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L2421) (2. Prüfung: bestätigt)
  Weiter real: Ionic sortiert gleiche Gruppen nach Nachname/Vorname mit localeCompare (attendance.page.ts:2444), Flutter computeAddPersonCandidates mit String.compareTo (Umlaute/Kleinbuchstaben hinten). Die Personenliste selbst nutzt localeCompareDe, nur „Person hinzufügen“ nicht.
  Flutter: lib/features/attendance/presentation/widgets/attendance_detail/add_persons_sheet.dart:60
- [ ] **niedrig** `attendance/attendance/attendance.page` `x-7bed677ddc` **Feldsortierung: Reihenfolge bei gleichem Wert** [src/app/attendance/attendance/attendance.page.ts:133](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/attendance/attendance/attendance.page.ts#L133)
  Ionic: sortiert this.players (bereits Hauptgruppe/Gruppe/Nachname) stabil → gleiche Werte bleiben nach Gruppe und Name geordnet / Flutter: sortiert die nach Nachname geladene Liste mit List.sort (ab 33 Personen nicht stabil) → gleiche Werte nur nach Nachname bzw. beliebig.
  Flutter: lib/features/attendance/presentation/pages/attendance_detail_page.dart:578, lib/features/attendance/presentation/widgets/attendance_detail/attendance_view_options.dart:124
