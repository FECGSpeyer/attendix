# Fix-Paket „einstellungen“

Soll: Ionic 4.19.9 (1923d203). Ist: Flutter 1aba6be, 2157fa0, b218510, 3bacc76, 8004a44, c9dd1aa, , 6945c13, 4e13f22 (normales Design).
Erzeugt mit `node tool/parity/parity.mjs fixlists` aus `docs/parity/status/`. Item-IDs siehe `ionic-inventory.json`.

## Angleichen (hoch/mittel): 7

- [ ] **mittel** `settings/general/type/type.page` `field-e2cc3102` [settings/general/type/type.page.html:550](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L550) (2. Prüfung: bestätigt)
  Schreibt wie Ionic type.start_time und ist bei ganztägigen Typen editierbar, aber nur bei „Werke verwalten“; kein 5-Minuten-Raster; keine Neuberechnung einer Endzeit (Flutter zeigt keine).
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:563-574, lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1196-1213
- [ ] **mittel** `settings/settings/settings.page` `field-f65b81d3` [settings/settings/settings.page.html:165](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L165) (2. Prüfung: bestätigt)
  Ionic: <input type=file accept=image/*> – in der App (iOS-WebView) Auswahl Mediathek/Foto aufnehmen/Datei, Originaldatei wird hochgeladen / Flutter: native Apps nur ImageSource.gallery (keine Kamera-Option; PWA: Browser-Dateiauswahl ohne capture wie Ionic); Bild wird auf max. 1200 px, Qualität 85 verkleinert.
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:165, lib/features/profile/presentation/widgets/master_data_sheet.dart:166, lib/features/profile/presentation/widgets/master_data_sheet.dart:169
- [ ] **mittel** `settings/settings/settings.page` `action-100a2fb9` [settings/settings/settings.page.html:269](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L269) (2. Prüfung: bestätigt)
  Speichern-Eintrag und Felder (Name, Telefon, Geburtstag mit correctBirthday nur bei Änderung, Zusatzfelder inkl. Org-Feldern, Kirche) gleich. Ionic: Sheet bleibt nach dem Speichern offen, Eingaben wirken sofort live auf die Hero-Karte (auch ungespeichert) / Flutter: Sheet schließt nach Erfolg, ungespeicherte Eingaben verfallen beim Schließen; Flutter trimmt Namen/Telefon. Korrektur zur Erstnotiz: Ionic meldet Fehler sehr wohl (db.updateProfile zeigt 'Fehler beim Aktualisieren des Profils', wie Flutter). Instanzübergreifender Schreibweg ist im Service-Batch (b17 db-d030c88f) bewertet.
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:346, lib/features/profile/presentation/widgets/master_data_sheet.dart:349, lib/features/profile/presentation/widgets/master_data_sheet.dart:227, lib/features/profile/presentation/widgets/master_data_sheet.dart:256, lib/features/profile/presentation/widgets/master_data_sheet.dart:258
- [ ] **mittel** `settings/settings/settings.page` `text-87e51c97` [settings/settings/settings.page.html:780](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L780) (2. Prüfung: bestätigt)
  Ionic: Badge mit package.json-Version (4.19.7) / Flutter: AppConstants.appVersion (0.38.1) – Nutzer sehen eine niedrigere, andere Versionsnummer.
  Flutter: lib/features/settings/presentation/pages/settings_page.dart:549, lib/core/constants/app_constants.dart:10
- [ ] **mittel** `settings/settings/settings.page` `text-7dea9c51` [settings/settings/settings.page.html:912](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L912) (2. Prüfung: bestätigt)
  Kopf „Version x (Datum)“ gleich. Inhalt verschieden: Ionic version-history.json (4.19.9 … 1.4.0, 326 Einträge) / Flutter assets/version_history.json mit eigener Flutter-Historie (0.41.0 … 0.1.0, 106 Einträge, darunter „Beta:“-Einträge). Gleiche Ursache wie text-8938a6a0.
  Flutter: lib/shared/widgets/sheets/version_history_sheet.dart:166, assets/version_history.json:1
- [ ] **mittel** `settings/settings/settings.page` `text-b8c80f4b` [settings/settings/settings.page.html:914](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L914) (2. Prüfung: bestätigt)
  Fallback „Version x“ ohne Datum im Code vorhanden, erscheint aber nie: alle Flutter-Einträge haben ein Datum / Ionic zeigt ihn für 58 alte Einträge (3.5.0 … 1.4.0). Ursache und Behebung wie text-7dea9c51 (eigene Flutter-Historie).
  Flutter: lib/shared/widgets/sheets/version_history_sheet.dart:167, assets/version_history.json:1
- [ ] **mittel** `settings/settings/settings.page` `text-8938a6a0` [settings/settings/settings.page.html:921](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L921) (2. Prüfung: bestätigt)
  Gleiche Darstellung ('Version x (Datum)' + je Änderung eine Zeile). Inhalt: Ionic version-history.json (4.19.x-Einträge) / Flutter assets/version_history.json mit eigener Flutter-Historie (0.38.x, andere Einträge).
  Flutter: lib/shared/widgets/sheets/version_history_sheet.dart:37, lib/shared/widgets/sheets/version_history_sheet.dart:176, lib/shared/widgets/sheets/version_history_sheet.dart:178, assets/version_history.json:1

## Flutter besser – Leon entscheidet: 35

- [ ] **niedrig** `settings/auto-messages/rule/auto-message-rule.page` `toast-31bb7a6e` [settings/auto-messages/rule/auto-message-rule.page.ts:95](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/auto-messages/rule/auto-message-rule.page.ts#L95)
  Flutter besser: Laden der Regel scheitert → gleicher roter Toast. Ionic zeigt den Toast auch, wenn nur der Verlauf (loadHistory) scheitert, und dann im Verlauf 0/0/0 + "Diese Regel hat noch nichts verschickt." / Flutter: kein Toast, im Tab Verlauf Hinweis "Automatische Nachrichten konnten nicht geladen werden".
  Flutter: lib/features/messages/presentation/pages/auto_message_rule_page.dart:109, lib/features/messages/presentation/pages/auto_message_rule_page.dart:110, lib/features/messages/presentation/pages/auto_message_rule_page.dart:872
- [ ] **niedrig** `settings/auto-messages/rule/auto-message-rule.page` `toast-6b7dde03` [settings/auto-messages/rule/auto-message-rule.page.ts:272](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/auto-messages/rule/auto-message-rule.page.ts#L272) (2. Prüfung: bestätigt)
  Flutter besser: gleiche Prüfungen/Reihenfolge, erster Fehler als Warn-Toast. Ionic akzeptiert beim eigenen Text einen Body, der nur Leerzeichen enthält (prüft nur auf "text"-Knoten) / Flutter verlangt nicht-leeren Text (TiptapConverter.hasText).
  Flutter: lib/features/messages/presentation/pages/auto_message_rule_page.dart:252, lib/features/messages/presentation/pages/auto_message_rule_page.dart:253, lib/features/messages/presentation/pages/auto_message_rule_page.dart:254, lib/features/messages/presentation/pages/auto_message_rule_page.dart:235, lib/features/messages/presentation/pages/auto_message_rule_page.dart:236, lib/features/messages/presentation/pages/auto_message_rule_page.dart:237, lib/features/messages/presentation/pages/auto_message_rule_page.dart:238, lib/features/messages/presentation/pages/auto_message_rule_page.dart:239, lib/features/messages/presentation/pages/auto_message_rule_page.dart:240, lib/features/messages/presentation/pages/auto_message_rule_page.dart:241, lib/features/messages/presentation/pages/auto_message_rule_page.dart:242, lib/features/messages/presentation/pages/auto_message_rule_page.dart:243, lib/features/messages/presentation/pages/auto_message_rule_page.dart:244, lib/features/messages/presentation/pages/auto_message_rule_page.dart:245
- [ ] **niedrig** `settings/general/branding/branding.page` `toast-c1d1cda9` [settings/general/branding/branding.page.ts:66](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/branding/branding.page.ts#L66) (2. Prüfung: bestätigt)
  Flutter besser: Ionic removeOrgLogo wertet {error} von storage.remove nicht aus (storage-js liefert Fehler zurück statt zu werfen) → Fehler-Toast praktisch nie, stattdessen 'Logo entfernt. Speichern nicht vergessen.' / Flutter: storage_client 2.4.1 remove wirft StorageException → Fehler-Toast (friendlyErrorMessage), Logo bleibt sichtbar.
  Flutter: lib/features/settings/presentation/pages/branding_page.dart:79-80, lib/data/repositories/organisation_settings_repository.dart:112-121
- [ ] **niedrig** `settings/general/branding/branding.page` `toast-833723a1` [settings/general/branding/branding.page.ts:82](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/branding/branding.page.ts#L82)
  Flutter besser: Ionic zeigt nach dem Service-Toast 'Fehler beim Speichern des Brandings' zusätzlich die rohe Fehlermeldung (error.message, z.B. PostgREST-Text) / Flutter zeigt nur 'Fehler beim Speichern des Brandings'
  Flutter: lib/features/settings/presentation/pages/branding_page.dart:97-98
- [ ] **niedrig** `settings/general/branding/branding.page` `nav-de11d527` [settings/general/branding/branding.page.ts:89](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/branding/branding.page.ts#L89)
  Flutter besser: Ionic navigateBack immer nach /tabs/settings/org-settings – auch wenn die Seite aus Allgemeine Einstellungen geöffnet wurde / Flutter: Navigator.maybePop zurück zur aufrufenden Seite (Allgemeine Einstellungen bzw. Organisation)
  Flutter: lib/features/settings/presentation/pages/branding_page.dart:119-122, lib/features/settings/presentation/pages/general_settings_page.dart:540, lib/features/organisation/presentation/pages/org_settings_page.dart:196
- [ ] **niedrig** `settings/general/extra-fields/extra-fields.page` `text-06537600` [settings/general/extra-fields/extra-fields.page.html:140](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/extra-fields/extra-fields.page.html#L140) (2. Prüfung: bestätigt)
  Flutter besser: Ionic getFieldTypeName kennt bfecg_church nicht → 'Unbekannt' / Flutter 'BFECG Gemeinde'; übrige Typen gleich.
  Flutter: lib/features/settings/presentation/pages/extra_fields_page.dart:356-361, lib/features/settings/presentation/pages/extra_fields_page.dart:46-47
- [ ] **niedrig** `settings/general/general.page` `action-c0d0384b` [settings/general/general.page.html:168](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L168)
  Flutter besser: meldet einen Kopierfehler (Toast „Link konnte nicht kopiert werden“), Ionic zeigt immer den Erfolgs-Toast. Sonst gleich (Bedingung, Text „Link kopieren“, Link https://attendix.de/register/<id>).
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:630, lib/features/settings/presentation/pages/general_settings_page.dart:397
- [ ] **niedrig** `settings/general/general.page` `action-b6b291b1` [settings/general/general.page.html:200](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L200)
  Flutter besser: meldet einen Kopierfehler (Toast „Link konnte nicht kopiert werden“), Ionic zeigt immer den Erfolgs-Toast. Sonst gleich (Bedingung, Text „Link kopieren“, Link https://attendix.de/<id>).
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:683, lib/features/settings/presentation/pages/general_settings_page.dart:397
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `action-02eec1c5` [settings/general/shifts/shift/shift.page.html:151](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.html#L151)
  Flutter besser: Ionic-Berechnung läuft in eine Endlosschleife, wenn der Plan feste Schichten aber keine Definition hat (currentDate.add(0)); Flutter zeigt eine leere Liste. Sonst gleich (Start am Anfangsdatum).
  Flutter: lib/features/shifts/presentation/pages/shift_detail_page.dart:627, lib/features/shifts/presentation/widgets/shift_preview_sheet.dart:44
- [ ] **niedrig** `settings/general/type/type.page` `toast-28259494` [settings/general/type/type.page.ts:254](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L254) (2. Prüfung: korrigiert)
  Flutter besser: Demo-Konto – Ionic: checkDemoRestriction zeigt den Demo-Hinweis und danach zusätzlich „Fehler beim Löschen des Anwesenheitstyps“ (rot, überlagert ihn) / Flutter: ensureNotDemo zeigt nur den Demo-Hinweis, der Fehler-Toast wird 4 s unterdrückt. Sonst gleicher Text/Farbe bei Fehlern; zusätzlich bei verwendeten Typen (siehe alert-57a11ee0, hoch). Rollen wie Ionic (nur Admin/Verantwortlich).
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1557-1563, lib/core/utils/toast_helper.dart:28-31, lib/data/repositories/attendance_type_repository.dart:175
- [ ] **niedrig** `settings/handover/handover.page` `action-0467769e` [settings/handover/handover.page.html:143](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/handover/handover.page.html#L143)
  Flutter besser: Ionic aktiviert den FAB, sobald irgendeine Person ausgewählt ist (auch wenn sie durch einen späteren Filter ausgeblendet ist) und navigiert dann mit leerer Personenliste / Flutter aktiviert nur, wenn mindestens eine ausgewählte Person im gefilterten Ergebnis ist.
  Flutter: lib/features/settings/presentation/pages/handover_page.dart:122, lib/features/settings/presentation/pages/handover_page.dart:132
- [ ] **niedrig** `settings/help/article/help-article.page` `nav-63850d0a` [settings/help/article/help-article.page.ts:55](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/help/article/help-article.page.ts#L55)
  Flutter besser: Ionic navigateBack('/tabs/settings/help') führt immer zur Hilfe-Übersicht, auch wenn der Artikel aus der Termin-Art-Seite (Teamorganisation aktivieren) geöffnet wurde / Flutter maybePop kehrt zur aufrufenden Seite zurück (aus der Hilfe: Hilfe-Übersicht, aus der Termin-Art: Termin-Art).
  Flutter: lib/features/help/presentation/pages/help_article_page.dart:34, lib/features/settings/presentation/widgets/type_protocol_settings.dart:126
- [ ] **niedrig** `settings/help/article/help-article.page` `action-40c0f47e` [settings/help/article/help-article.page.html:4](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/help/article/help-article.page.html#L4)
  Flutter besser: Button (arrow-back) gleich; Wirkung wie nav-63850d0a (Flutter kehrt zur aufrufenden Seite zurück statt immer zur Hilfe-Übersicht).
  Flutter: lib/features/help/presentation/pages/help_article_page.dart:32, lib/features/help/presentation/pages/help_article_page.dart:34
- [ ] **niedrig** `settings/role-permissions/role-permissions.page` `alert-c705cf47` [settings/role-permissions/role-permissions.page.ts:93](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/role-permissions/role-permissions.page.ts#L93) (2. Prüfung: bestätigt)
  Flutter besser: Titel „Ungespeicherte Änderungen“, Text und Buttons (Abbrechen / Verwerfen rot / Speichern) gleich. Ionic: bei „Speichern“ wird die Seite auch verlassen, wenn das Speichern fehlschlägt (save() fängt den Fehler, danach resolve(true)) / Flutter bleibt bei Fehler auf der Seite.
  Flutter: lib/features/settings/presentation/pages/role_permissions_page.dart:96-122, lib/features/settings/presentation/pages/role_permissions_page.dart:146-150
- [ ] **niedrig** `settings/settings/settings.page` `toast-05890c58` [settings/settings/settings.page.ts:550](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L550) (2. Prüfung: korrigiert)
  Flutter besser: Erfolgs-Toast gleich ('Die Instanz „…“ wurde als Favorit gesetzt/entfernt.', success, 3 s; Wischaktion für alle Rollen in beiden). Schlägt das Speichern fehl, zeigt nur Flutter 'Fehler beim Speichern' (Ionic schließt nur das Loading). Erster Prüfer führte das als ok mit Notiz – laut Brief diff/niedrig.
  Flutter: lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:241, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:250, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:254
- [ ] **niedrig** `settings/settings/settings.page` `toast-ab89dfb2` [settings/settings/settings.page.ts:808](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L808) (2. Prüfung: korrigiert)
  Flutter besser: gleicher Erfolgs-Toast 'Der Link wurde in die Zwischenablage kopiert'. Ionic ruft clipboard.writeText ohne await auf und zeigt den Erfolg auch, wenn das Kopieren scheitert / Flutter wartet und zeigt dann stattdessen 'Link konnte nicht kopiert werden'. Erster Prüfer: ok ohne diesen Unterschied.
  Flutter: lib/features/settings/presentation/widgets/calendar_subscription_dialog.dart:133, lib/features/settings/presentation/widgets/calendar_subscription_dialog.dart:136, lib/features/settings/presentation/widgets/calendar_subscription_dialog.dart:141
- [ ] **niedrig** `settings/settings/settings.page` `toast-453ee9ac` [settings/settings/settings.page.ts:964](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L964) (2. Prüfung: bestätigt)
  Flutter besser: gleicher Text 'Das Bild darf maximal 2MB groß sein.', aber Flutter prüft erst nach dem Verkleinern (image_picker maxWidth/Height 1200, Qualität 85, auch im Web per Canvas) – große Fotos werden verkleinert hochgeladen statt abgelehnt; Meldung erscheint praktisch nie. Ionic lehnt Originaldateien > 2 MB ab.
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:165, lib/features/profile/presentation/widgets/master_data_sheet.dart:175
- [ ] **niedrig** `settings/settings/settings.page` `field-509e17fd-2` [settings/settings/settings.page.html:256](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L256) (2. Prüfung: korrigiert)
  Flutter besser: Feldtyp textarea als dreizeiliges Eingabefeld (maxLines 3) / Ionic: für text, textarea und date dasselbe einzeilige ion-input. Sonst gleich (Label oben, Großschreibung Satzanfang, Rollen/editableByPlayers wie Ionic). Erstprüfer übersah die Textarea-Höhe. Nebenbei ohne Wirkung: unberührte leere Textfelder speichert Flutter als '', Ionic lässt den Schlüssel weg (Anzeige gleich).
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:406, lib/features/profile/presentation/widgets/master_data_sheet.dart:416
- [ ] **niedrig** `settings/settings/settings.page` `action-03eef951` [settings/settings/settings.page.html:502](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L502) (2. Prüfung: korrigiert)
  Flutter besser: Liste nach Nachname, Vorname sortiert / Ionic getViewers ohne ORDER BY (DB-Reihenfolge); die Erstprüfung übersah die Sortierung. Sonst gleich: Name + E-Mail, kein Chevron, Tippen → Entfernen-Dialog; Rollen gleich (Admin/Verantwortliche).
  Flutter: lib/features/settings/presentation/pages/viewers_page.dart:88-92, lib/features/settings/presentation/pages/viewers_page.dart:253-259, lib/data/repositories/viewer_repository.dart:19-26
- [ ] **niedrig** `settings/settings/settings.page` `action-ca440363` [settings/settings/settings.page.html:856](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L856)
  Flutter besser: leere Frage wird mit Warnung 'Bitte gib eine Frage ein' (Flutter-only) blockiert, Ionic sendet auch leer. Flutter trimmt Text/Telefon und schreibt leeres Telefon als null statt ''. md: Flutter-only Einleitung 'Hast du eine Frage oder brauchst Hilfe?'.
  Flutter: lib/shared/widgets/sheets/feedback_sheet.dart:80, lib/shared/widgets/sheets/feedback_sheet.dart:81, lib/shared/widgets/sheets/feedback_sheet.dart:82, lib/shared/widgets/sheets/feedback_sheet.dart:89, lib/shared/widgets/sheets/feedback_sheet.dart:90
- [ ] **niedrig** `settings/general/extra-fields/extra-fields.page` `x-b7ea470e58` **Personen-Bereinigung erfasst andere Personen** [src/app/settings/general/extra-fields/extra-fields.page.ts:319](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/extra-fields/extra-fields.page.ts#L319) (2. Prüfung: korrigiert)
  Flutter besser: Befund real (Flutter bereinigt alle Personen der Instanz inkl. archivierter und ausstehender, gepaged; Ionic db.getPlayers() nur aktive, nicht ausstehende, max. 1000), aber ohne sichtbare Folge: fehlende Werte zeigen beide Apps ohnehin als Standard an, entfernt werden nur Werte gelöschter Felder, ungültige Auswahlwerte werden ersetzt. Ergebnis: konsistente Daten auch bei Archivierten/Bewerbern. Erstreview mittel zu hoch.
  Flutter: lib/data/repositories/extra_fields_repository.dart:72, lib/data/repositories/extra_fields_repository.dart:94, lib/features/settings/presentation/pages/extra_fields_page.dart:186
- [ ] **niedrig** `settings/general/extra-fields/extra-fields.page` `x-a3d381bce7` **Werk-Bereinigung bei synchronisierter Werkbibliothek** [src/app/settings/general/extra-fields/extra-fields.page.ts:353](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/extra-fields/extra-fields.page.ts#L353) (2. Prüfung: korrigiert)
  Flutter besser (mit Einschränkung): Befund real. Ionic schreibt bei genutzter Quell-Bibliothek die Werkfelder der eigenen Instanz in die Werke der Quell-Instanz (RLS admins_manage_songs erlaubt es) und löscht dort Werte von Feldern, die nur die Quell-Instanz kennt – fremde Daten werden verändert. Flutter fasst nur eigene Werke an. Folge in Flutter: ungültige Auswahlwerte/Reste gelöschter Felder in Bibliothekswerken bleiben; fehlende Standardwerte zeigen beide Apps beim Öffnen ohnehin an. Erstreview mittel zu hoch.
  Flutter: lib/data/repositories/extra_fields_repository.dart:72, lib/features/settings/presentation/pages/extra_fields_page.dart:187, lib/features/songs/presentation/pages/song_detail_page.dart:112
- [ ] **niedrig** `settings/general/link-persons/link-persons.page` `x-42261d1068` **Ladefehler wird gemeldet** [src/app/settings/general/link-persons/link-persons.page.ts:48](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/link-persons/link-persons.page.ts#L48)
  Flutter besser: Ionic zeigt bei Ladefehler still „Keine weiteren Vorschläge.“ / Flutter zeigt zusätzlich Toast „Fehler beim Laden: …“.
  Flutter: lib/features/settings/presentation/pages/link_persons_page.dart:121
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `x-e9a63ed372` **Ungespeicherte Änderungen im Cache** [src/app/settings/general/shifts/shift/shift.page.ts:34](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.ts#L34)
  Flutter besser: Ionic bearbeitet das Objekt aus db.shifts() direkt – ungespeicherte Änderungen erscheinen nach Zurück in der Liste bis zum Neuladen / Flutter arbeitet auf einer lokalen Kopie, die Liste bleibt unverändert.
  Flutter: lib/features/shifts/presentation/pages/shift_detail_page.dart:65
- [ ] **niedrig** `settings/general/shifts/shifts.page` `x-63c823b827` **Navigation zum neuen Plan per ID** [src/app/services/db.service.ts:3913-3918](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/db.service.ts#L3913-L3918)
  Flutter besser: Ionic sucht den neuen Plan nach Namen (db.addShift → shifts().find(name)), bei gleichnamigen Plänen ggf. der falsche / Flutter navigiert zur zurückgegebenen ID.
  Flutter: lib/features/shifts/presentation/pages/shifts_list_page.dart:194-202
- [ ] **niedrig** `settings/general/types/types.page` `x-cacb75d561` **Fehler beim Speichern der Reihenfolge** [src/app/settings/general/types/types.page.ts:31-46](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/types/types.page.ts#L31-L46)
  Flutter besser: Ionic ohne Fehlerbehandlung (Loading bleibt bei Fehler offen) / Flutter: Toast „Fehler beim Speichern. Bitte erneut versuchen.“, Sortiermodus bleibt erhalten.
  Flutter: lib/features/settings/presentation/pages/attendance_types_page.dart:163-173
- [ ] **niedrig** `settings/general/type/type.page` `x-0f8c22baa3` **System-Zurück fragt nach** [src/app/settings/general/type/type.page.ts:148-154](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L148-L154)
  Flutter besser: PopScope fragt auch bei Android-Zurück/iOS-Wischgeste nach ungespeicherten Änderungen / Ionic nur beim Zurück-Button.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:214-218
- [ ] **niedrig** `settings/administration/administration.page` `x-8e4f4f2cf3` **Duplikate nach Hinzufügen einer Gemeinde** [src/app/settings/administration/administration.page.ts:86](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/administration/administration.page.ts#L86)
  Flutter besser: Ionic lädt nach openChurchInput nur this.churches neu, ruft findDuplicates() nicht auf → Duplikat-Hinweis erscheint erst beim nächsten Öffnen / Flutter berechnet findChurchDuplicates bei jedem Build neu.
  Flutter: lib/features/dashboard/presentation/pages/administration_page.dart:216
- [ ] **niedrig** `settings/auto-messages/rule/auto-message-rule.page` `x-039d502fb6` **Verlaufstitel bei ausgeblendeten Termintypen** [src/app/settings/auto-messages/rule/auto-message-rule.page.ts:330](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/auto-messages/rule/auto-message-rule.page.ts#L330)
  Flutter besser: Ionic sucht den Typnamen für Verlaufszeilen ohne typeInfo nur in den sichtbaren Typen (this.types = visible !== false) → bei ausgeblendetem Typ leerer Titel "· 01.02.2026" / Flutter nutzt alle Termintypen und zeigt den Namen.
  Flutter: lib/core/providers/auto_message_providers.dart:136, lib/core/providers/auto_message_providers.dart:149
- [ ] **niedrig** `settings/dashboard/dashboard-settings.page` `x-e0812326f3` **Fehler beim Speichern der Dashboard-Einstellungen** [src/app/services/db.service.ts:801](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/db.service.ts#L801)
  Flutter besser: Ionic wertet das Ergebnis von supabase.auth.updateUser nicht aus (supabase-js wirft nicht; kein Hinweis, Schalter/Reihenfolge bleiben lokal geändert, obwohl nicht gespeichert) / Flutter setzt den Zustand zurück und zeigt roten Toast (dashSettingsFlutterSaveFailed).
  Flutter: lib/features/dashboard/presentation/pages/dashboard_settings_page.dart:38, lib/features/dashboard/presentation/pages/dashboard_settings_page.dart:42, lib/core/providers/dashboard_providers.dart:155
- [ ] **niedrig** `settings/handover-detail/handover-detail.page` `x-c62672af53` **Fehler beim Laden der Zielgruppen** [src/app/services/group/group.service.ts:18-28](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/group/group.service.ts#L18-L28)
  Flutter besser: Ionic ignoriert den Fehler von getGroups (data null → Laufzeitfehler, Zuordnung bleibt leer) / Flutter zeigt einen Fehler-Toast und beendet das Laden.
  Flutter: lib/features/settings/presentation/pages/handover_detail_page.dart:81-85
- [ ] **niedrig** `settings/role-permissions/role-permissions.page` `x-104b424f87` **Rückfrage auch bei Zurück-Geste** [src/app/settings/role-permissions/role-permissions.page.ts:83](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/role-permissions/role-permissions.page.ts#L83)
  Flutter besser: Ionic fragt nur beim eigenen Zurück-Button nach ungespeicherten Änderungen; iOS-Wischgeste bzw. Android-Zurück verlassen die Seite ohne Rückfrage (kein CanDeactivate) / Flutter: PopScope(canPop: !_hasUnsavedChanges) fängt jedes Zurück ab und zeigt den Dialog.
  Flutter: lib/features/settings/presentation/pages/role_permissions_page.dart:146
- [ ] **niedrig** `settings/voice-leader/voice-leader.page` `x-0e53a3f1b7` **Kein eigenes Spielerprofil** [src/app/settings/voice-leader/voice-leader.page.ts:47](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/voice-leader/voice-leader.page.ts#L47)
  Flutter besser: Ionic: getPlayerByAppId wirft → roter Toast "Fehler beim Laden der Gruppenmitglieder.", Seite bleibt mit leerem Gruppennamen, "0 Mitglieder" und "Keine Mitglieder in deiner Stimme gefunden." / Flutter: Seite zeigt Leerzustand "Kein Spielerprofil gefunden." ohne Toast und ohne Zurücknavigation.
  Flutter: lib/features/voice_leader/presentation/pages/voice_leader_page.dart:34, lib/features/voice_leader/presentation/pages/voice_leader_page.dart:73
- [ ] **niedrig** `settings/general/type/type.page` `x-91589b8337` **System-Zurück mit Rückfrage** [src/app/settings/general/type/type.page.ts:148](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L148)
  Flutter besser: Ionic fragt nur beim Zurück-Pfeil (navigateBack) nach ungespeicherten Änderungen, Hardware-/Wisch-Zurück verlässt ohne Rückfrage / Flutter: PopScope fragt auch bei System-Zurück.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:214-218
- [ ] **niedrig** `settings/general/type/type.page` `x-016e794b9a` **Erinnerung über 168 Stunden** [src/app/settings/general/type/type.page.ts:598](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L598)
  Flutter besser: Ionic addReminder akzeptiert jede Zahl ≥ 0 (max=168 nur als Input-Attribut) / Flutter lehnt > 168 mit Toast „Gültige Werte: 0-168 Stunden (max. 1 Woche vorher)“ ab.
  Flutter: lib/features/settings/presentation/widgets/type_reminders_editor.dart:39-41

## Kleinigkeiten (niedrig): 194

- [ ] **niedrig** `settings/administration/administration.page` `toast-4886e3c8` [settings/administration/administration.page.ts:59](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/administration/administration.page.ts#L59)
  Texte gleich ("Speicher: unbegrenzt" / "Speicherlimit: {gb} GB"). Ionic: {gb} = rohe JS-Zahl mit Dezimalpunkt, ungerundet ("2.5") / Flutter: _fmtGb mit Dezimalkomma, auf 2 Stellen gerundet ("2,5").
  Flutter: lib/features/dashboard/presentation/pages/administration_page.dart:79, lib/features/dashboard/presentation/pages/administration_page.dart:83
- [ ] **niedrig** `settings/administration/administration.page` `loading-2cf2d119` [settings/administration/administration.page.ts:81](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/administration/administration.page.ts#L81)
  Ionic: blockierendes Loading-Overlay (ohne Text, max. 3 s) beim Anlegen / Flutter: kein Overlay, keine Sperre.
  Flutter: lib/features/dashboard/presentation/pages/administration_page.dart:104
- [ ] **niedrig** `settings/administration/administration.page` `toast-da425369` [settings/administration/administration.page.ts:89](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/administration/administration.page.ts#L89)
  Ionic: roter Toast mit der rohen Fehlermeldung (error.message), zusätzlich Service-Toast "Fehler beim Erstellen der Kirche" / Flutter: nur roter Toast "Fehler beim Hinzufügen" (adminFlutterAddFailed).
  Flutter: lib/features/dashboard/presentation/pages/administration_page.dart:109
- [ ] **niedrig** `settings/administration/administration.page` `loading-9b43bea8` [settings/administration/administration.page.ts:134](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/administration/administration.page.ts#L134) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay "Gemeinden werden zusammengeführt..." / Flutter: kein Overlay und kein Text, nur Merge-/Umbenennen-Buttons während saving deaktiviert.
  Flutter: lib/features/dashboard/presentation/pages/administration_page.dart:141, lib/features/dashboard/presentation/pages/administration_page.dart:207, lib/features/dashboard/presentation/pages/administration_page.dart:325
- [ ] **niedrig** `settings/administration/administration.page` `loading-cf07fdc8` [settings/administration/administration.page.ts:163](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/administration/administration.page.ts#L163)
  Ionic: blockierendes Overlay "Gemeinden werden zusammengeführt..." / Flutter: kein Overlay, nur Buttons während saving deaktiviert.
  Flutter: lib/features/dashboard/presentation/pages/administration_page.dart:141, lib/features/dashboard/presentation/pages/administration_page.dart:343
- [ ] **niedrig** `settings/administration/administration.page` `toast-32957c22` [settings/administration/administration.page.ts:175](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/administration/administration.page.ts#L175)
  Ionic: "Alle zusammenführen" zeigt immer "{updated} Person(en) aktualisiert, {total} Duplikat(e) entfernt" / Flutter: bei genau 1 Duplikat (pairs.length == 1) stattdessen "Zusammengeführt: {count} Person(en) aktualisiert".
  Flutter: lib/features/dashboard/presentation/pages/administration_page.dart:145, lib/features/dashboard/presentation/pages/administration_page.dart:148, lib/features/dashboard/presentation/pages/administration_page.dart:150, lib/features/dashboard/presentation/pages/administration_page.dart:151
- [ ] **niedrig** `settings/administration/administration.page` `loading-6b2cf021` [settings/administration/administration.page.ts:242](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/administration/administration.page.ts#L242)
  Ionic: blockierendes Overlay "Gemeinden werden zusammengeführt..." / Flutter: kein Overlay, nur Buttons während saving deaktiviert.
  Flutter: lib/features/dashboard/presentation/pages/administration_page.dart:141, lib/features/dashboard/presentation/pages/administration_page.dart:377
- [ ] **niedrig** `settings/administration/administration.page` `text-af90065a` [settings/administration/administration.page.html:46](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/administration/administration.page.html#L46)
  Ionic: number-Pipe ohne LOCALE_ID (en-US) → "1.5 GB" / Flutter: Dezimalkomma "1,5 GB".
  Flutter: lib/features/dashboard/presentation/pages/administration_page.dart:24, lib/features/dashboard/presentation/pages/administration_page.dart:276
- [ ] **niedrig** `settings/auto-messages/rule/auto-message-rule.page` `nav-61929704` [settings/auto-messages/rule/auto-message-rule.page.ts:282](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/auto-messages/rule/auto-message-rule.page.ts#L282) (2. Prüfung: bestätigt)
  Ionic: navigateByUrl('/tabs/settings/auto-messages') → immer zur Regel-Liste / Flutter: context.pop() → zurück zur vorherigen Seite. Gleich beim Aufruf aus der Liste; beim Aufruf aus dem Termin-Panel (?tab=history) landet Flutter wieder auf dem Termin statt auf der Liste.
  Flutter: lib/features/messages/presentation/pages/auto_message_rule_page.dart:264
- [ ] **niedrig** `settings/auto-messages/rule/auto-message-rule.page` `nav-4f4f5283` [settings/auto-messages/rule/auto-message-rule.page.ts:304](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/auto-messages/rule/auto-message-rule.page.ts#L304) (2. Prüfung: bestätigt)
  Ionic: navigateByUrl('/tabs/settings/auto-messages') → immer zur Regel-Liste / Flutter: context.pop() → zurück zur vorherigen Seite. Gleich beim Aufruf aus der Liste; beim Aufruf aus dem Termin-Panel (?tab=history) landet Flutter wieder auf dem Termin statt auf der Liste.
  Flutter: lib/features/messages/presentation/pages/auto_message_rule_page.dart:287, lib/features/messages/presentation/pages/auto_message_rule_page.dart:288
- [ ] **niedrig** `settings/auto-messages/rule/auto-message-rule.page` `action-efce6677` [settings/auto-messages/rule/auto-message-rule.page.html:163](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/auto-messages/rule/auto-message-rule.page.html#L163)
  Editor an gleicher Stelle, Inhalt wird in body_json übernommen. Ionic-Toolbar (app-message-editor): B, I, U, S | H (H2-Umschalter) | Liste, nummerierte Liste | Link, Rückgängig / Flutter (Quill): B, I, U, S, Überschrift-Auswahl (Quill-Header-Dropdown), Listen, Link – kein Rückgängig-Button (showUndo: false).
  Flutter: lib/features/messages/presentation/pages/auto_message_rule_page.dart:613, lib/features/messages/presentation/pages/auto_message_rule_page.dart:617, lib/features/messages/presentation/pages/auto_message_rule_page.dart:653, lib/features/messages/presentation/pages/auto_message_rule_page.dart:133
- [ ] **niedrig** `settings/auto-messages/rule/auto-message-rule.page` `action-5ab0462f` [settings/auto-messages/rule/auto-message-rule.page.html:167](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/auto-messages/rule/auto-message-rule.page.html#L167)
  Gleiche Platzhalter "{vorname}" … "{anzahl}" in gleicher Reihenfolge, Einfügen an der Cursorposition. Ionic: Chips outline (Rahmen primary, transparent) / Flutter: gefüllt hell-primary ohne Rahmen (AutoMessageChip selected:true).
  Flutter: lib/features/messages/presentation/pages/auto_message_rule_page.dart:664, lib/features/messages/presentation/pages/auto_message_rule_page.dart:666, lib/features/messages/presentation/pages/auto_message_rule_page.dart:667, lib/features/messages/presentation/pages/auto_message_rule_page.dart:164, lib/features/messages/presentation/auto_message_texts.dart:156
- [ ] **niedrig** `settings/auto-messages/rule/auto-message-rule.page` `action-cab12068` [settings/auto-messages/rule/auto-message-rule.page.html:223](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/auto-messages/rule/auto-message-rule.page.html#L223)
  Gleicher Text "Vorschau mit den letzten Terminen", outline, volle Breite, während Laden deaktiviert mit Spinner. Ionic: ohne Icon / Flutter: zusätzliches Augen-Icon (visibility_outlined).
  Flutter: lib/features/messages/presentation/pages/auto_message_rule_page.dart:767, lib/features/messages/presentation/pages/auto_message_rule_page.dart:768, lib/features/messages/presentation/pages/auto_message_rule_page.dart:769, lib/features/messages/presentation/pages/auto_message_rule_page.dart:772, lib/features/messages/presentation/pages/auto_message_rule_page.dart:773, lib/features/messages/presentation/pages/auto_message_rule_page.dart:199
- [ ] **niedrig** `settings/delete-account/delete-account.page` `loading-4ca29b26` [settings/delete-account/delete-account.page.ts:55](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/delete-account/delete-account.page.ts#L55) (2. Prüfung: bestätigt)
  Ionic: blockierendes Overlay „Konto wird gelöscht...“ (60 s) / Flutter: Spinner + „Konto wird gelöscht...“ im (gesperrten) Button, Seite bleibt bedienbar (Zurück möglich).
  Flutter: lib/features/settings/presentation/pages/delete_account_page.dart:205-223
- [ ] **niedrig** `settings/delete-account/delete-account.page` `toast-2e5d1ac6` [settings/delete-account/delete-account.page.ts:64](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/delete-account/delete-account.page.ts#L64)
  Text „Fehler beim Löschen: {error}“ gleich, {error} abweichend: Ionic error.message („Edge Function returned a non-2xx status code“) / Flutter toString der FunctionException („FunctionException(status: …, details: …, reasonPhrase: …)“). Dauer 5 s vs Standard.
  Flutter: lib/features/settings/presentation/pages/delete_account_page.dart:89-95, lib/data/repositories/account_repository.dart:27-42
- [ ] **niedrig** `settings/files/files-move-modal/files-move-modal.component` `alert-4779f093` [settings/files/files-move-modal/files-move-modal.component.ts:113](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files-move-modal/files-move-modal.component.ts#L113)
  Titel „Ordner erstellen“, Platzhalter „Ordnername“, Abbrechen/Erstellen gleich. Leerer Name: Ionic lässt den Dialog offen (handler return false) / Flutter schließt ihn ohne Aktion.
  Flutter: lib/features/settings/presentation/widgets/files_move_modal.dart:161-169
- [ ] **niedrig** `settings/files/files.page` `toast-f69d0e8d` [settings/files/files.page.ts:54](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L54)
  Ionic: Toast (danger) „Du hast keinen Zugriff auf Dateien.“ + zurück / Flutter: kein Toast, derselbe Text als Seiteninhalt.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:1128-1134
- [ ] **niedrig** `settings/files/files.page` `nav-c401b9ed` [settings/files/files.page.ts:55](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L55)
  Ionic: navCtrl.back() ohne Zugriff / Flutter bleibt auf der Seite (Hinweistext, Menü ausgeblendet); _init lädt trotzdem die Einträge (ggf. Fehler-Toast).
  Flutter: lib/features/settings/presentation/pages/files_page.dart:1128-1134, lib/features/settings/presentation/pages/files_page.dart:209-210
- [ ] **niedrig** `settings/files/files.page` `toast-767d441c` [settings/files/files.page.ts:106](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L106)
  Ionic: Toast „Link: {url}“ (medium), wenn die Zwischenablage fehlschlägt / Flutter öffnet dann Share.share; Toast (Info) erst, wenn auch das fehlschlägt.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:431-436
- [ ] **niedrig** `settings/files/files.page` `alert-157216a5` [settings/files/files.page.ts:216](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L216)
  Titel, Hinweis, Textfeld „Wie viel Speicher braucht ihr ungefähr? (optional)“, Abbrechen/Senden und Nachrichtentext gleich. DB-Insert questions: Ionic phone '' / Flutter phone null (kein sichtbarer Effekt).
  Flutter: lib/features/settings/presentation/pages/files_page.dart:669-708, lib/data/repositories/feedback_repository.dart:24-35
- [ ] **niedrig** `settings/files/files.page` `toast-d3bd6d1e` [settings/files/files.page.ts:244](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L244)
  Ionic: {error} = error.message (+ Service-Toast „Fehler beim Senden der Frage“) / Flutter: {error} = toString der RepositoryException („RepositoryException: … (operation: sendQuestion…)“), kein Service-Toast.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:712-715
- [ ] **niedrig** `settings/files/files.page` `alert-e8c9b56a` [settings/files/files.page.ts:783](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L783)
  Titel „Ordner erstellen“, Platzhalter „Ordnername“, Abbrechen/Erstellen gleich. Leerer Name: Ionic lässt den Dialog offen / Flutter schließt ihn ohne Aktion.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:446-452
- [ ] **niedrig** `settings/files/files.page` `loading-82305d64` [settings/files/files.page.ts:819](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L819) (2. Prüfung: bestätigt)
  Ionic: blockierendes Lade-Overlay während des Downloads / Flutter: kein Ladeindikator (öffnet die signierte URL über NativeFileService.openUrl).
  Flutter: lib/features/settings/presentation/pages/files_page.dart:403-414
- [ ] **niedrig** `settings/files/files.page` `effect-a54e7eb4` [settings/files/files.page.ts:824](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L824)
  Nativ gleich (Cache + System-Viewer). Web: Ionic lädt den Blob herunter (Desktop <a download>, mobile Browser: Teilen-Dialog mit Datei) / Flutter öffnet die signierte URL mit ?download= im Browser (launchExternal).
  Flutter: lib/features/settings/presentation/pages/files_page.dart:407-410, lib/core/services/native/native_file_service.dart:142-162
- [ ] **niedrig** `settings/files/files.page` `loading-d65a6193` [settings/files/files.page.ts:842](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L842)
  Ionic: blockierendes Overlay „Datei wird per Telegram gesendet...“ / Flutter: nur Info-Toast mit diesem Text, nicht blockierend.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:393
- [ ] **niedrig** `settings/files/files.page` `toast-030d7a9b` [settings/files/files.page.ts:849](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L849) (2. Prüfung: bestätigt)
  Fehler beim Signieren der URL gleich („Telegram-Versand fehlgeschlagen: {error}“). Fehler der Edge Function send-document: Ionic (TelegramService.sendSongPerTelegram) „Fehler beim Senden der Nachricht, versuche es später erneut!“ / Flutter „Telegram-Versand fehlgeschlagen: {error}“.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:386-401, lib/core/services/telegram_service.dart:357-366
- [ ] **niedrig** `settings/files/files.page` `loading-cdff1a47` [settings/files/files.page.ts:906](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L906)
  Ionic: blockierendes Lade-Overlay beim Löschen eines Eintrags / Flutter: kein Ladeindikator.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:659-666
- [ ] **niedrig** `settings/files/files.page` `alert-3b9b2763` [settings/files/files.page.ts:931](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L931)
  Titel „Ordner/Datei umbenennen“, Feld mit aktuellem Namen, Platzhalter „Neuer Name“, Abbrechen/Speichern gleich. Leerer Name: Ionic lässt den Dialog offen / Flutter schließt ihn ohne Aktion.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:464-471
- [ ] **niedrig** `settings/files/files.page` `loading-4e44e24e` [settings/files/files.page.ts:949](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L949)
  Ionic: blockierendes Lade-Overlay beim Umbenennen / Flutter: kein Ladeindikator.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:471-478
- [ ] **niedrig** `settings/files/files.page` `modal-b8bd9613` [settings/files/files.page.ts:1110](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.ts#L1110)
  Übergebene Daten (Einträge, aktueller Ordner, Tenant über gebundenes Repository) gleich. Ionic: Vollbild-Modal (ohne presentingElement) / Flutter iOS: Karten-Modal (per Wischen schließbar); md wie Ionic.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:601-606, lib/features/settings/presentation/widgets/files_move_modal.dart:20-38
- [ ] **niedrig** `settings/files/files.page` `action-42b3d799` [settings/files/files.page.html:67](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.html#L67) (2. Prüfung: bestätigt)
  Eintrag „Name“ mit Icon, sortiert Ordner zuerst – gleich. Ionic: localeCompare(Sprache, sensitivity base) / Flutter: toLowerCase().compareTo (Codepoint: Umlaute/Akzente hinter z). Gilt auch für die Standardsortierung beim Laden.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:135-151, lib/features/settings/presentation/pages/files_page.dart:1074-1077, lib/features/settings/presentation/pages/files_page.dart:955
- [ ] **niedrig** `settings/files/files.page` `action-14d154d9` [settings/files/files.page.html:96](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.html#L96) (2. Prüfung: bestätigt)
  „Root“ führt zur Wurzel. Ionic: openRoot behält den Suchbegriff / Flutter: _navigateTo leert das Suchfeld.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:1151-1170, lib/features/settings/presentation/pages/files_page.dart:317-323
- [ ] **niedrig** `settings/files/files.page` `action-64a83941` [settings/files/files.page.html:99](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.html#L99)
  Ionic: openSegment behält den Suchbegriff / Flutter: _navigateTo leert das Suchfeld.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:1171-1181, lib/features/settings/presentation/pages/files_page.dart:317-323
- [ ] **niedrig** `settings/files/files.page` `field-5bd09165` [settings/files/files.page.html:124](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.html#L124)
  Ionic normalisiert per NFKD und entfernt Akzente (z. B. „cafe“ findet „Café“) / Flutter ersetzt nur ä/ö/ü/ß, Akzente werden nicht ignoriert.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:50-60, lib/features/settings/presentation/pages/files_page.dart:1231-1236
- [ ] **niedrig** `settings/files/files.page` `text-308e6820` [settings/files/files.page.html:143](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.html#L143)
  Text „typ:<wert> · Filtert nach Dateityp oder Art (z. B. typ:pdf, typ:ordner, typ:datei).“ gleich, im Such-Hilfe-Dialog (Dialog statt Popover: siehe popover-f66de769). Ionic: innerHTML mit fetten Beispielen / Flutter: _plainHtml entfernt den Fettdruck. Für alle Rollen wie Ionic.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:869-879, lib/features/settings/presentation/pages/files_page.dart:863-867
- [ ] **niedrig** `settings/files/files.page` `text-4f3365df` [settings/files/files.page.html:144](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.html#L144)
  Text „datum:<wert> · Filtert nach Änderungsdatum (z. B. datum:2026, datum:03.2026, datum:03.03.2026).“ gleich. Ionic: innerHTML mit fetten Beispielen / Flutter: ohne Fettdruck (_plainHtml).
  Flutter: lib/features/settings/presentation/pages/files_page.dart:869-879, lib/features/settings/presentation/pages/files_page.dart:863-867
- [ ] **niedrig** `settings/files/files.page` `text-cd4b6647` [settings/files/files.page.html:145](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.html#L145)
  Text „Filter sind kombinierbar, z. B. protokoll typ:pdf datum:2026.“ gleich. Ionic: Beispiel fett (innerHTML) / Flutter: ohne Fettdruck (_plainHtml).
  Flutter: lib/features/settings/presentation/pages/files_page.dart:869-879, lib/features/settings/presentation/pages/files_page.dart:863-867
- [ ] **niedrig** `settings/files/files.page` `action-37361b16` [settings/files/files.page.html:181](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.html#L181)
  Anzeige (Icon/Vorschaubild, Name, Größe „· Geändert: dd.MM.yyyy, HH:mm“), Tap öffnet/zeigt/spielt bzw. wählt aus – gleich. Ionic behält beim Öffnen eines Ordners den Suchbegriff / Flutter leert ihn.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:1294-1358, lib/features/settings/presentation/pages/files_page.dart:329-343
- [ ] **niedrig** `settings/files/files.page` `action-bdaec002` [settings/files/files.page.html:212](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.html#L212)
  Texte/Icon/Effekt gleich; bei „Ordner öffnen“ behält Ionic den Suchbegriff / Flutter leert ihn.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:888-896, lib/features/settings/presentation/pages/files_page.dart:329-333
- [ ] **niedrig** `settings/general/branding/branding.page` `toast-6b4f5e61` [settings/general/branding/branding.page.ts:42](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/branding/branding.page.ts#L42) (2. Prüfung: bestätigt)
  Text 'Bitte wähle eine Bilddatei aus.' und Farbe gleich, Größenprüfung (2 MB) davor wie Ionic. Ionic: Prüfung über MIME-Typ (image/*) – jedes Bildformat (z. B. TIFF, AVIF, ICO) geht / Flutter: Prüfung über Dateiendung png/jpg/jpeg/gif/webp/svg/bmp/heic/heif – andere Bildformate (v. a. im Web) lösen diesen Toast aus.
  Flutter: lib/features/settings/presentation/pages/branding_page.dart:49-54
- [ ] **niedrig** `settings/general/branding/branding.page` `loading-af506242` [settings/general/branding/branding.page.ts:46](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/branding/branding.page.ts#L46)
  Ionic: blockierendes Loading-Overlay ohne Text (duration 3000) / Flutter: nur LinearProgressIndicator oben, Logo- und Speichern-Aktionen deaktiviert, Textfeld und Zurück bleiben bedienbar
  Flutter: lib/features/settings/presentation/pages/branding_page.dart:56, lib/features/settings/presentation/pages/branding_page.dart:196, lib/features/settings/presentation/pages/branding_page.dart:229
- [ ] **niedrig** `settings/general/branding/branding.page` `loading-f8d4b932` [settings/general/branding/branding.page.ts:59](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/branding/branding.page.ts#L59)
  Ionic: blockierendes Loading-Overlay ohne Text (duration 3000) / Flutter: nur LinearProgressIndicator, Logo- und Speichern-Aktionen deaktiviert, Rest bedienbar
  Flutter: lib/features/settings/presentation/pages/branding_page.dart:73, lib/features/settings/presentation/pages/branding_page.dart:204, lib/features/settings/presentation/pages/branding_page.dart:229
- [ ] **niedrig** `settings/general/branding/branding.page` `loading-73e70629` [settings/general/branding/branding.page.ts:73](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/branding/branding.page.ts#L73)
  Ionic: blockierendes Overlay 'Branding wird gespeichert...' bis zum Ende / Flutter: kein Overlay, kein Text (ARB brandingSaving ungenutzt), nur LinearProgressIndicator und deaktivierte Speichern-Buttons; Seite bleibt bedienbar
  Flutter: lib/features/settings/presentation/pages/branding_page.dart:86-101, lib/features/settings/presentation/pages/branding_page.dart:229
- [ ] **niedrig** `settings/general/branding/branding.page` `action-a79d6f49` [settings/general/branding/branding.page.html:4](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/branding/branding.page.html#L4) (2. Prüfung: bestätigt)
  Pfeil-zurück links gleich. Flutter besser: Ionic navigiert immer nach /tabs/settings/org-settings (auch wenn aus Allgemeine Einstellungen geöffnet, general.page.html:54) / Flutter maybePop → zurück zur aufrufenden Seite (Allgemeine Einstellungen oder Organisation).
  Flutter: lib/features/settings/presentation/pages/branding_page.dart:119-122
- [ ] **niedrig** `settings/general/branding/branding.page` `media-198547cf` [settings/general/branding/branding.page.html:46](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/branding/branding.page.html#L46)
  Logo-Vorschau gleich: nur mit Organisation und vorhandenem Logo, im Abschnitt 'Logo' über 'Logo ersetzen', zentriert, max. 200×120, weißer Hintergrund, Radius 8, Padding 8, contain; Seite nur Admin/Verantwortlich (Route /settings/general). Ionic alt='Logo' fehlt in Flutter (Image.network ohne semanticLabel; Screenreader/Ladefehler zeigt nur Symbol).
  Flutter: lib/features/settings/presentation/pages/branding_page.dart:172, lib/features/settings/presentation/pages/branding_page.dart:183
- [ ] **niedrig** `settings/general/branding/branding.page` `field-339f58a0` [settings/general/branding/branding.page.html:54](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/branding/branding.page.html#L54) (2. Prüfung: bestätigt)
  Ionic: <input type=file accept=image/*> – in der iOS-App Systemmenü Fotomediathek / Foto aufnehmen / Datei auswählen / Flutter: FilePicker FileType.image öffnet auf iOS direkt PHPicker (file_picker 8.3.7, nur Fotomediathek, keine Kamera, keine Dateien-App). Web/Android: Bildauswahl wie Ionic.
  Flutter: lib/features/settings/presentation/pages/branding_page.dart:42
- [ ] **niedrig** `settings/general/extra-fields/extra-fields.page` `nav-599a827b` [settings/general/extra-fields/extra-fields.page.ts:388](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/extra-fields/extra-fields.page.ts#L388)
  Ziel gleich (zurück zu Allgemeine Einstellungen, einziger Aufrufer). Flutter besser: bei ungespeicherten Änderungen Dialog 'Ungespeicherte Änderungen' / 'Du hast ungespeicherte Änderungen. Möchtest du die Seite trotzdem verlassen?' (Abbrechen/Verwerfen); Ionic verwirft still
  Flutter: lib/features/settings/presentation/pages/extra_fields_page.dart:522-527, lib/features/settings/presentation/pages/extra_fields_page.dart:503-515, lib/features/settings/presentation/pages/extra_fields_page.dart:535-538, lib/features/settings/presentation/pages/general_settings_page.dart:704
- [ ] **niedrig** `settings/general/extra-fields/extra-fields.page` `action-a20ffd04` [settings/general/extra-fields/extra-fields.page.html:4](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/extra-fields/extra-fields.page.html#L4)
  Pfeil-zurück vorhanden; wie nav-599a827b: Flutter besser – Rückfrage bei ungespeicherten Änderungen, Ionic verwirft still
  Flutter: lib/features/settings/presentation/pages/extra_fields_page.dart:535-538, lib/features/settings/presentation/pages/extra_fields_page.dart:522-527
- [ ] **niedrig** `settings/general/extra-fields/extra-fields.page` `modal-e091cca3` [settings/general/extra-fields/extra-fields.page.html:33](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/extra-fields/extra-fields.page.html#L33)
  Beides Bottom-Sheet. Ionic: Sheet in voller Höhe (initialBreakpoint 1), ohne Schließen-Button, Entwurf bleibt nach Wegwischen für das nächste Öffnen erhalten / Flutter: Sheet in Inhaltshöhe mit X-Button, Formular bei jedem Öffnen leer
  Flutter: lib/features/settings/presentation/pages/extra_fields_page.dart:113-115, lib/features/settings/presentation/pages/extra_fields_page.dart:214-238, lib/features/settings/presentation/pages/extra_fields_page.dart:344-354
- [ ] **niedrig** `settings/general/extra-fields/extra-fields.page` `field-e584f2a8` [settings/general/extra-fields/extra-fields.page.html:44](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/extra-fields/extra-fields.page.html#L44)
  Optionen Text/Zahl/Ja-Nein/Auswahl in gleicher Reihenfolge, Typwechsel setzt Standard zurück (Zahl → 0). Ionic: 'BFECG Gemeinde' bei db.isBeta() = Instanz 12 ODER Benutzer-E-Mail endet auf developer@attendix.de / Flutter: nur Instanz 12. Ionic speichert beim Wechsel auf BFECG die erste Gemeinde als defaultValue, Flutter null
  Flutter: lib/features/settings/presentation/pages/extra_fields_page.dart:363-380
- [ ] **niedrig** `settings/general/extra-fields/extra-fields.page` `field-1dbe68d1` [settings/general/extra-fields/extra-fields.page.html:104](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/extra-fields/extra-fields.page.html#L104)
  Label 'Standardwert (optional)', Zahlentastatur bei Zahl gleich. Flutter besser: Ionic startet mit defaultValue false (emptyField); bleibt der Typ 'Text' unverändert und das Feld leer, speichert Ionic defaultValue false und befüllt Personen mit false / Flutter speichert ''
  Flutter: lib/features/settings/presentation/pages/extra_fields_page.dart:456-463, lib/features/settings/presentation/pages/extra_fields_page.dart:318, lib/features/settings/presentation/pages/extra_fields_page.dart:494-497
- [ ] **niedrig** `settings/general/extra-fields/extra-fields.page` `action-2279dc11` [settings/general/extra-fields/extra-fields.page.html:216](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/extra-fields/extra-fields.page.html#L216)
  Name, 'Typ: …' (nicht bei bfecg_church), 'Anzeige: …', 'Für Mitglieder sichtbar (bearbeitbar)', Stift/Papierkorb und Sortiergriff ab 2 Feldern gleich. Ionic: Augen-Icon (eye-outline) vor 'Für Mitglieder sichtbar' / Flutter: ohne Icon
  Flutter: lib/features/settings/presentation/pages/extra_fields_page.dart:603-651
- [ ] **niedrig** `settings/general/extra-fields/extra-fields.page` `modal-3b9ec807` [settings/general/extra-fields/extra-fields.page.html:251](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/extra-fields/extra-fields.page.html#L251) (2. Prüfung: bestätigt)
  Beides Bottom-Sheet 'Neues Feld hinzufügen'. Ionic: volle Höhe (initialBreakpoint 1), kein Schließen-Button, Entwurf bleibt nach Wegwischen für das nächste Öffnen / Flutter: Inhaltshöhe mit X-Button, Formular bei jedem Öffnen leer.
  Flutter: lib/features/settings/presentation/pages/extra_fields_page.dart:113-115, lib/features/settings/presentation/pages/extra_fields_page.dart:214-238, lib/features/settings/presentation/pages/extra_fields_page.dart:344-354
- [ ] **niedrig** `settings/general/extra-fields/extra-fields.page` `field-cf72db04` [settings/general/extra-fields/extra-fields.page.html:309](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/extra-fields/extra-fields.page.html#L309) (2. Prüfung: bestätigt)
  Label 'Standardwert (optional)' gleich. Flutter besser: Ionic speichert bei unverändertem Typ 'Text' und leerem Feld defaultValue false (emptyField) und füllt Werke beim Speichern mit false / Flutter speichert ''.
  Flutter: lib/features/settings/presentation/pages/extra_fields_page.dart:456-463, lib/features/settings/presentation/pages/extra_fields_page.dart:318, lib/features/settings/presentation/pages/extra_fields_page.dart:494-497
- [ ] **niedrig** `settings/general/general.page` `loading-c8bf88e0` [settings/general/general.page.ts:305](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.ts#L305)
  Ionic: blockierendes Overlay „Einstellungen werden gespeichert...“ / Flutter: nur Spinner im FAB, kein Overlay, kein Text (generalSettingsSaving ungenutzt).
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:444
- [ ] **niedrig** `settings/general/general.page` `alert-c2833d76` [settings/general/general.page.ts:351](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.ts#L351)
  Dialog, Text und Buttons „Abbrechen“/„Neu laden“ gleich. Ionic: „Neu laden“ lädt Seite/App neu (auch nativ via window.location.reload) / Flutter: Reload nur im Web, nativ ohne Wirkung (Tenant-Provider wird nach dem Speichern ohnehin invalidiert).
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:283, lib/core/utils/page_reload.dart:4
- [ ] **niedrig** `settings/general/general.page` `toast-ae9cf87e` [settings/general/general.page.ts:438](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.ts#L438)
  Gleicher Text. Ionic akzeptiert Dezimalwerte (z. B. 33.5 %) / Flutter nur ganze Zahlen (int.tryParse) – Dezimalwert löst diesen Toast aus.
  Flutter: lib/features/settings/presentation/widgets/critical_rule_sheet.dart:92
- [ ] **niedrig** `settings/general/general.page` `alert-98bdf09a` [settings/general/general.page.ts:460](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.ts#L460)
  Titel „Regel löschen?“ und Buttons gleich. Ionic: „Möchtest du diese Regel wirklich löschen?“ / Flutter: „Möchtest du die Regel "{Name oder Beschreibung}" wirklich löschen?“; danach zusätzlicher Toast „Regel gelöscht“.
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:867, lib/features/settings/presentation/pages/general_settings_page.dart:896
- [ ] **niedrig** `settings/general/general.page` `field-51c6d116` [settings/general/general.page.html:41](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L41)
  Ionic: max = heute (keine Zukunftsdaten), kein Minimum, Wochenstart Montag / Flutter: firstDate 2020, lastDate 2030 – Zukunftsdaten wählbar, Daten vor 2020 nicht. Gespeichert wird 'YYYY-MM-DD' (Ionic: ISO-Wert des Pickers; genaues Ionic-Format ohne @ionic/core im Container nicht prüfbar).
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:320
- [ ] **niedrig** `settings/general/general.page` `field-98648dc9` [settings/general/general.page.html:76](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L76)
  Ionic: Feld bei leerem Wert mit Standardtext „Du bist bei diesem Termin nicht dabei.“ vorbefüllt, mit Lösch-Button (clearInput) / Flutter: Feld leer, Text nur als Platzhalter, kein Lösch-Button. Gespeicherter Wert gleich (leer → Standardtext, aus → null).
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:563
- [ ] **niedrig** `settings/general/general.page` `field-031d9492` [settings/general/general.page.html:180](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L180)
  Ionic: Mehrfach-Select, Reihenfolge Passbild, Vorname, Nachname, Gruppe, Geburtsdatum, Handynummer, Zusatzfelder; Vorname/Nachname/Gruppe deaktiviert; gespeicherte Liste wird unverändert übernommen / Flutter: FilterChips inline, Reihenfolge Vorname, Nachname, Gruppe, Passbild, Geburtsdatum, Handynummer, Zusatzfelder; Pflichtfelder nicht abwählbar und beim Laden immer ergänzt.
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:653, lib/features/settings/presentation/pages/general_settings_page.dart:358, lib/features/settings/presentation/pages/general_settings_page.dart:159
- [ ] **niedrig** `settings/general/general.page` `field-8155f670` [settings/general/general.page.html:240](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L240) (2. Prüfung: bestätigt)
  Nur bei 'Ferien/Feiertage anzeigen', Label 'Bundesland für Ferien/Feiertage', 16 Länder in gleicher Reihenfolge. Flutter: zusätzliche erste Option 'Keine Feiertage' (speichert region = null); Tenant ohne region zeigt diese statt leerer Auswahl.
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:733-749, lib/features/settings/presentation/pages/general_settings_page.dart:32-50
- [ ] **niedrig** `settings/general/general.page` `modal-9a5764bc` [settings/general/general.page.html:255](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L255)
  Bottom-Sheet in voller Höhe wie Ionic. Flutter öffnet es nicht, wenn keine Anwesenheits-Typen existieren (Toast „Keine Terminarten vorhanden“); Ionic öffnet immer.
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:809, lib/features/settings/presentation/pages/general_settings_page.dart:822
- [ ] **niedrig** `settings/general/general.page` `field-cf813d87` [settings/general/general.page.html:293](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L293)
  Ionic: Label je nach Typ „Anzahl“/„Prozent“ / Flutter: Label „Wert“ mit Suffix „x“/„%“; nur ganze Zahlen.
  Flutter: lib/features/settings/presentation/widgets/critical_rule_sheet.dart:257
- [ ] **niedrig** `settings/general/general.page` `field-e64f6a72` [settings/general/general.page.html:317](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L317)
  Ionic: Select „Verknüpfung“ mit Hilfetext „Wie diese Regel mit anderen Regeln kombiniert wird“, Optionen „ODER (eine Regel muss zutreffen)“/„UND (alle Regeln müssen zutreffen)“ / Flutter: Segmented-Button „ODER“/„UND“ mit Hinweis „Person ist kritisch, wenn EINE der Regeln zutrifft“ bzw. „…ALLE Regeln…“; Hilfetext fehlt.
  Flutter: lib/features/settings/presentation/widgets/critical_rule_sheet.dart:315
- [ ] **niedrig** `settings/general/general.page` `action-2a371131` [settings/general/general.page.html:325](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L325) (2. Prüfung: bestätigt)
  Gleicher Button 'Regel hinzufügen' unten im Sheet, gleiche Validierungen (Status, Schwelle > 0, Tage > 0), Sheet schließt, Regel wird angehängt. Flutter zeigt danach zusätzlich Toast 'Regel hinzugefügt'.
  Flutter: lib/features/settings/presentation/widgets/critical_rule_sheet.dart:82-122, lib/features/settings/presentation/widgets/critical_rule_sheet.dart:351-358, lib/features/settings/presentation/pages/general_settings_page.dart:828-834
- [ ] **niedrig** `settings/general/general.page` `action-81c091ba` [settings/general/general.page.html:361](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L361)
  FAB gleich, gleiche Spalten. Unterschiede beim Schreiben: Instanz-Name/-Kürzel getrimmt; seasonStart als 'YYYY-MM-DD'; leerer Regelname weggelassen statt ''; register_id/song_sharing_id: nach Aus-Speichern und erneutem Einschalten ohne Neuladen wird die alte ID wieder geschrieben (Ionic erzeugt dann eine neue).
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:441, lib/features/settings/presentation/pages/general_settings_page.dart:221, lib/features/settings/presentation/pages/general_settings_page.dart:612
- [ ] **niedrig** `settings/general/link-persons/link-persons.page` `action-ab89d664` [settings/general/link-persons/link-persons.page.html:5](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/link-persons/link-persons.page.html#L5)
  Ionic: Schließen-Button (X) rechts im Modal / Flutter: eigene Seite mit Zurück-Pfeil links (AppBar-Standard).
  Flutter: lib/features/settings/presentation/pages/link_persons_page.dart:171
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `toast-0db7cc2f` [settings/general/shifts/shift/shift.page.ts:50](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.ts#L50) (2. Prüfung: bestätigt)
  Ionic: 'Fehler beim Speichern des Schichtplans' (davor Service-Toast 'svc.updateShiftFailed') / Flutter: 'Fehler: {Fehlermeldung}'.
  Flutter: lib/features/shifts/presentation/pages/shift_detail_page.dart:459-463
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `loading-b3201582` [settings/general/shifts/shift/shift.page.ts:105](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.ts#L105)
  Ionic: blockierendes Overlay „Schichtplan wird gelöscht...“ / Flutter: kein Overlay, keine Anzeige während des Löschens.
  Flutter: lib/features/shifts/presentation/pages/shift_detail_page.dart:496
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `toast-4ae23615` [settings/general/shifts/shift/shift.page.ts:142](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.ts#L142)
  Flutter wählt die erste Instanz vor; der Hinweis „Bitte wähle eine Instanz aus.“ entfällt.
  Flutter: lib/features/shifts/presentation/widgets/copy_shift_to_tenant_sheet.dart:91
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `loading-dbd1d573` [settings/general/shifts/shift/shift.page.ts:199](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.ts#L199)
  Ionic: blockierendes Overlay „Schichtplan wird kopiert...“ / Flutter: Fortschrittsbalken im Sheet mit wechselndem Text („Schichtplan wird kopiert...“, „Erstelle Schichtplan...“, …), kein Overlay.
  Flutter: lib/features/shifts/presentation/widgets/copy_shift_to_tenant_sheet.dart:238
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `toast-ee0000ac` [settings/general/shifts/shift/shift.page.ts:256](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.ts#L256)
  Gleicher Text, aber Erfolgsfarbe statt Warnung; erscheint auch, wenn die zugewiesenen Personen keine appId haben (Ionic: dann einfache Meldung „…kopiert.“).
  Flutter: lib/features/shifts/presentation/widgets/copy_shift_to_tenant_sheet.dart:421, lib/features/shifts/presentation/widgets/copy_shift_to_tenant_sheet.dart:428
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `toast-f5a8f9ba` [settings/general/shifts/shift/shift.page.ts:265](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.ts#L265)
  Ionic: „Fehler beim Kopieren des Schichtplans.“ / Flutter: „Fehler beim Kopieren: {Fehler}“.
  Flutter: lib/features/shifts/presentation/widgets/copy_shift_to_tenant_sheet.dart:434
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `action-54992f8a` [settings/general/shifts/shift/shift.page.html:55](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.html#L55)
  Ionic: neuer Abschnitt übernimmt die Dauer des letzten Abschnitts (sonst 8) / Flutter: immer 8 Stunden.
  Flutter: lib/features/shifts/presentation/pages/shift_detail_page.dart:244, lib/features/shifts/presentation/pages/shift_detail_page.dart:371
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `field-5fdbaf8e` [settings/general/shifts/shift/shift.page.html:82](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.html#L82)
  Ionic: Zeitrad mit 5-Minuten-Schritten (0, 5, …, 55), 24h / Flutter: Standard-Zeitauswahl mit jeder Minute.
  Flutter: lib/features/shifts/presentation/pages/shift_detail_page.dart:354
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `field-24d478af` [settings/general/shifts/shift/shift.page.html:99](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.html#L99)
  Label und Hilfetext gleich. Flutter akzeptiert Komma, begrenzt auf 0–24 Stunden und ignoriert ungültige/leere Eingaben (Feld zeigt dann anderen Wert als gespeichert) / Ionic speichert die Zahl unverändert.
  Flutter: lib/features/shifts/presentation/pages/shift_detail_page.dart:320
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `field-f5fdf890` [settings/general/shifts/shift/shift.page.html:108](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.html#L108)
  Label und Hilfetext gleich. Flutter begrenzt auf 1–365 und ignoriert ungültige/leere Eingaben / Ionic speichert unverändert.
  Flutter: lib/features/shifts/presentation/pages/shift_detail_page.dart:333
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `field-3c4c975e` [settings/general/shifts/shift/shift.page.html:146](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.html#L146)
  Ionic: Datumsauswahl ohne feste Grenzen, Wochenstart Montag / Flutter: nur 2020–2030 wählbar.
  Flutter: lib/features/shifts/presentation/pages/shift_detail_page.dart:637
- [ ] **niedrig** `settings/general/shifts/shift/shift.page` `action-e0fdaa55` [settings/general/shifts/shift/shift.page.html:200](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shift/shift.page.html#L200)
  FAB gleich; Flutter speichert Name und Beschreibung getrimmt (Ionic unverändert).
  Flutter: lib/features/shifts/presentation/pages/shift_detail_page.dart:130, lib/features/shifts/presentation/pages/shift_detail_page.dart:443
- [ ] **niedrig** `settings/general/type/type.page` `toast-d7abd52a` [settings/general/type/type.page.ts:229](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L229) (2. Prüfung: bestätigt)
  Ionic: roter Toast „Bitte einen Namen für den Anwesenheitstyp eingeben.“ beim Speichern/Anlegen / Flutter Bearbeiten: gleicher Text als Validierungsfehler unter dem Namensfeld (kein Toast); beim Anlegen (Namensdialog der Typenliste) roter Toast wie Ionic.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:840-869, lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1459, lib/features/settings/presentation/pages/attendance_types_page.dart:209-215
- [ ] **niedrig** `settings/general/type/type.page` `alert-49afdc91` [settings/general/type/type.page.ts:266](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L266) (2. Prüfung: bestätigt)
  Ionic: „X“ im Neu-Modal mit eingegebenem Namen → „Änderungen verwerfen?“ / „Du hast bereits Daten eingegeben …“ (Abbrechen/Verwerfen) / Flutter: kein Neu-Modal; „Abbrechen“ im Namensdialog verwirft nur den Namen ohne Rückfrage. Folge des anderen Anlege-Ablaufs (modal-c0d2c05c), daher niedrig.
- [ ] **niedrig** `settings/general/type/type.page` `toast-0ce227b1` [settings/general/type/type.page.ts:423](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L423) (2. Prüfung: bestätigt)
  Toast „Ein Tagesordnungs-Platzhalter ist bereits vorhanden“ (warning) nur über den Popover-Eintrag „Tagesordnung Platzhalter“ erreichbar, der in Flutter fehlt; „Platzhalter einfügen“ ist bei vorhandenem Marker ausgeblendet (wie Ionic), onInsertPlaceholder prüft still.
- [ ] **niedrig** `settings/general/type/type.page` `toast-995c9d84` [settings/general/type/type.page.ts:611](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L611)
  Ionic: Toast-Farbe warning / Flutter: showError (danger).
  Flutter: lib/features/settings/presentation/widgets/type_reminders_editor.dart:42, lib/features/settings/presentation/widgets/type_reminders_editor.dart:62-66
- [ ] **niedrig** `settings/general/type/type.page` `alert-0ec2acf8` [settings/general/type/type.page.ts:757](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L757) (2. Prüfung: bestätigt)
  Ionic Alert „To-Do bearbeiten“: ein Textfeld (Platzhalter „To-Do Text...“), Abbrechen/Speichern, nur Text änderbar / Flutter Dialog „To-Do bearbeiten“: „Aufgabe“ (z.B. Noten vorbereiten) + „Frist (Stunden vorher, optional)“, Abbrechen/OK; Frist zusätzlich änderbar, leerer Text → OK ohne Wirkung.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1344-1411
- [ ] **niedrig** `settings/general/type/type.page` `field-519cd48e` [settings/general/type/type.page.html:31](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L31) (2. Prüfung: korrigiert)
  iOS gleich (gestapelt, Satzanfang groß). Android/Web: Ionic gestapeltes „Name“ ohne Platzhalter, autocapitalize=sentences / Flutter: schwebendes Label „Name *“ mit Platzhalter „z.B. Probe, Konzert“, ohne Großschreibung am Satzanfang; leerer Name als Feldfehler statt Toast (Toast-Item separat). Rollen wie Ionic.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:840-869
- [ ] **niedrig** `settings/general/type/type.page` `field-02b039dc` [settings/general/type/type.page.html:58](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L58)
  Nur verfügbare Status wie Ionic, aber Enum-Reihenfolge (…, Entschuldigt, Verspätet, Abwesend) und Text „Verspätet“ statt „Verspätet anwesend“.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:308-333
- [ ] **niedrig** `settings/general/type/type.page` `field-4a2fa59b` [settings/general/type/type.page.html:86](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L86) (2. Prüfung: korrigiert)
  Ionic: gestapeltes Label über vollbreitem Zahlenfeld, leer wenn duration_days nicht gesetzt, jeder Wert (auch 0/leer) wird gespeichert / Flutter: Label links, 60 px Feld rechts, zeigt „1“ wenn nicht gesetzt, übernimmt nur Werte > 0 (sonst bleibt still der letzte gültige Wert). Rollen wie Ionic.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:358-385, lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1484
- [ ] **niedrig** `settings/general/type/type.page` `field-ea19d7e9` [settings/general/type/type.page.html:99](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L99)
  Ionic: Minuten nur in 5er-Schritten (minuteValues 0,5,…,55) / Flutter: Zeitwahl ohne 5-Minuten-Raster.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:387-396, lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1196-1213
- [ ] **niedrig** `settings/general/type/type.page` `field-32a15191` [settings/general/type/type.page.html:117](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L117)
  Ionic: Minuten nur in 5er-Schritten / Flutter: Zeitwahl ohne 5-Minuten-Raster.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:397-403, lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1196-1213
- [ ] **niedrig** `settings/general/type/type.page` `field-fe789c4f` [settings/general/type/type.page.html:203](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L203) (2. Prüfung: korrigiert)
  Ionic: Zahlenfeld (rechtsbündig, Platzhalter „1“, frei eintippbar; 0 wird gespeichert, leer → null scheitert am NOT NULL) / Flutter: −/+-Stepper ab 1, kein Eintippen (große Zahlen nur per Mehrfach-Tippen), speichert mind. 1. Rollen wie Ionic.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:944-963, lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1505
- [ ] **niedrig** `settings/general/type/type.page` `text-c8d8274e` [settings/general/type/type.page.html:243](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L243)
  Text identisch, verweist aber auf „Filter“ (Abschnitt heißt in Flutter „Zusatzfeld-Filter“) und auf ein Ja/Nein-Feld, das der Flutter-Filter nicht anbietet (siehe field-1ef7f6fa).
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1014-1020
- [ ] **niedrig** `settings/general/type/type.page` `text-e17651f9` [settings/general/type/type.page.html:281](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L281) (2. Prüfung: bestätigt)
  Sheet-Titel „Erinnerungen“ entfällt (Inline-Editor unter „Terminerinnerungen“).
- [ ] **niedrig** `settings/general/type/type.page` `action-a64534cc` [settings/general/type/type.page.html:283](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L283) (2. Prüfung: bestätigt)
  Häkchen zum Schließen des Sheets entfällt (kein Sheet, Inline-Editor).
- [ ] **niedrig** `settings/general/type/type.page` `text-d7d1c4cd` [settings/general/type/type.page.html:345](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L345)
  Gleicher Text, aber ohne Glocken-Icon (notifications-off) und nicht zentriert.
  Flutter: lib/features/settings/presentation/widgets/type_reminders_editor.dart:113-114
- [ ] **niedrig** `settings/general/type/type.page` `action-6f4dbd15` [settings/general/type/type.page.html:361](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L361) (2. Prüfung: bestätigt)
  Chips 1 Stunde/1 Tag/2 Tage/3 Tage vorher gleich, vorhandene deaktiviert wie Ionic; ohne add-circle-Icon, ohne primary/medium-Färbung.
  Flutter: lib/features/settings/presentation/widgets/type_reminders_editor.dart:132-142
- [ ] **niedrig** `settings/general/type/type.page` `text-eb5120fd` [settings/general/type/type.page.html:373](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L373) (2. Prüfung: bestätigt)
  Überschrift „Benutzerdefiniert“ fehlt; das Feld „Stunden vor Termin“ folgt direkt auf die Schnellauswahl.
- [ ] **niedrig** `settings/general/type/type.page` `action-b683d989` [settings/general/type/type.page.html:383](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L383)
  Ionic: Block-Button „Erinnerung hinzufügen“ mit Icon, disabled bei leerer Eingabe / Flutter: runder „+“-IconButton (Text nur als Tooltip), immer aktiv (leer → Toast „Bitte geben Sie eine positive Ganzzahl ein“). Flutter besser: Werte > 168 werden abgelehnt (Ionic speichert sie).
  Flutter: lib/features/settings/presentation/widgets/type_reminders_editor.dart:161-165, lib/features/settings/presentation/widgets/type_reminders_editor.dart:34-47
- [ ] **niedrig** `settings/general/type/type.page` `popover-31d23755` [settings/general/type/type.page.html:417](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L417) (2. Prüfung: bestätigt)
  Nur Optik (Leon 05.11.2026): Gleiche 9 Farben und Auswahl, nur Dialog statt Popover. – Befund: Ionic: Popover am Farb-Eintrag mit 3er-Raster / Flutter: zentrierter Dialog mit Farb-Raster; 9 Farben, Reihenfolge und graue Markierung der Auswahl gleich, Tippen übernimmt und schließt.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:744-781
- [ ] **niedrig** `settings/general/type/type.page` `field-c6f43718` [settings/general/type/type.page.html:475](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L475)
  Label „Wert“ statt „Option“; Optionen und Vorauswahl (erste Option) gleich.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1152-1171
- [ ] **niedrig** `settings/general/type/type.page` `action-b172177a` [settings/general/type/type.page.html:514](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L514) (2. Prüfung: bestätigt)
  Popover-Eintrag „Tagesordnung Platzhalter“ fehlt; der Marker ist (wie in Ionic auch) über „Platzhalter einfügen“ im Protokoll-Bereich einfügbar.
  Flutter: lib/features/settings/presentation/widgets/type_protocol_settings.dart:156-165
- [ ] **niedrig** `settings/general/type/type.page` `modal-8afdfb0b-4` [settings/general/type/type.page.html:604](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L604) (2. Prüfung: bestätigt)
  Kein (gesperrter) Endzeit-Picker; siehe text-d7a84674-2.
- [ ] **niedrig** `settings/general/type/type.page` `field-076bd829` [settings/general/type/type.page.html:606](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L606) (2. Prüfung: bestätigt)
  Gesperrte Endzeit (ion-datetime disabled) fehlt; Flutter zeigt nur „Gesamt: {n} Min.“.
- [ ] **niedrig** `settings/general/type/type.page` `text-ed93279a` [settings/general/type/type.page.html:626](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L626) (2. Prüfung: bestätigt)
  Titel „Checkliste“ gleich. Ionic: Abschnitt nur bei aktivierter Checkliste, mit Zähler-Badge / Flutter: immer sichtbar, ohne Badge (Schalter fehlt, siehe field-d34df4b8).
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:665-666
- [ ] **niedrig** `settings/general/type/type.page` `text-b7e124ce` [settings/general/type/type.page.html:627](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L627) (2. Prüfung: bestätigt)
  Zähler-Badge (Anzahl To-Dos, medium) im Abschnittskopf „Checkliste“ fehlt.
- [ ] **niedrig** `settings/general/type/type.page` `action-e05c70b9` [settings/general/type/type.page.html:635](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L635)
  Tippen öffnet Dialog mit zusätzlichem Frist-Feld (siehe alert-0ec2acf8).
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:699, lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1344-1352
- [ ] **niedrig** `settings/general/type/type.page` `text-31685302` [settings/general/type/type.page.html:653](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L653)
  Auch ohne aktivierte Checkliste sichtbar; ohne checkbox-Icon, nicht zentriert.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:704-711
- [ ] **niedrig** `settings/general/type/type.page` `field-5ad22e0e` [settings/general/type/type.page.html:679](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L679)
  Stunden-Eingabe immer im Dialog statt nur bei „Benutzerdefiniert...“; Label „Frist (Stunden vorher, optional)“ statt „Stunden vor Termin“.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1377-1384
- [ ] **niedrig** `settings/general/type/type.page` `text-fdfcef92` [settings/general/type/type.page.html:715](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L715) (2. Prüfung: bestätigt)
  Zähler-Badge (Anzahl Anmeldefelder) im Abschnittskopf „Anmeldefelder“ fehlt.
- [ ] **niedrig** `settings/general/type/type.page` `field-96e0108b` [settings/general/type/type.page.html:747](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L747) (2. Prüfung: bestätigt)
  Label „Typ“, Optionen Text, Ja / Nein, Einzelauswahl, Mehrfachauswahl in gleicher Reihenfolge; Flutter mit Vorauswahl „Text“ (Ionic leer, Hinzufügen bis zur Auswahl gesperrt).
  Flutter: lib/features/settings/presentation/widgets/registration_fields_editor.dart:113-127
- [ ] **niedrig** `settings/general/type/type.page` `action-cb1f55e8` [settings/general/type/type.page.html:761](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L761)
  Ionic: disabled ohne Bezeichnung/Typ / Flutter: immer aktiv, leer → Warn-Toast „Bitte eine Feldbezeichnung eingeben“.
  Flutter: lib/features/settings/presentation/widgets/registration_fields_editor.dart:139-144, lib/features/settings/presentation/widgets/registration_fields_editor.dart:46-51
- [ ] **niedrig** `settings/general/type/type.page` `action-fd011cb6` [settings/general/type/type.page.html:772](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L772)
  Flutter-FAB ist erst nach einer Änderung aktiv (Ionic immer).
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:238-242
- [ ] **niedrig** `settings/general/types/types.page` `loading-b4bbe04a` [settings/general/types/types.page.ts:32](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/types/types.page.ts#L32) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading „Speichere Reihenfolge...“ während alle Typen mit index i gespeichert werden / Flutter: kein Overlay, reorderTypes schreibt nur index (mit tenant_id-Filter) ohne Sperre; Erfolgs-Toast „Reihenfolge gespeichert“ gleich.
  Flutter: lib/features/settings/presentation/pages/attendance_types_page.dart:144-174
- [ ] **niedrig** `settings/general/types/types.page` `action-d4d32824` [settings/general/types/types.page.html:63](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/types/types.page.html#L63)
  Ionic: „+“-FAB auch im Sortiermodus sichtbar / Flutter: im Sortiermodus stattdessen grauer „X“-FAB (Sortieren abbrechen); Anlegen-Ablauf siehe modal-c0d2c05c.
  Flutter: lib/features/settings/presentation/pages/attendance_types_page.dart:126-140
- [ ] **niedrig** `settings/handover-detail/handover-detail.page` `alert-3ae53341` [settings/handover-detail/handover-detail.page.ts:63](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/handover-detail/handover-detail.page.ts#L63)
  Ionic: Radio-Alert „Gruppe auswählen“ mit Buttons „Abbrechen“/„OK“, Übernahme erst mit OK / Flutter: Auswahldialog ohne Buttons, Tippen auf eine Gruppe übernimmt sofort (Schließen durch Tippen außerhalb).
  Flutter: lib/features/settings/presentation/pages/handover_detail_page.dart:92-112
- [ ] **niedrig** `settings/handover-detail/handover-detail.page` `alert-0f698f99` [settings/handover-detail/handover-detail.page.ts:93](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/handover-detail/handover-detail.page.ts#L93) (2. Prüfung: bestätigt)
  Titel „Personenübergabe“, Text mit Anzahl/Instanz/Hinweis, „Abbrechen“/„Übertragen“ gleich. Ionic: „Abbrechen“ mit role destructive (iOS rot) / Flutter: „Übertragen“ rot gefüllt wenn die Personen nicht in der Instanz bleiben, „Abbrechen“ neutral.
  Flutter: lib/features/settings/presentation/pages/handover_detail_page.dart:114-127
- [ ] **niedrig** `settings/handover-detail/handover-detail.page` `loading-ce2dc227` [settings/handover-detail/handover-detail.page.ts:114](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/handover-detail/handover-detail.page.ts#L114)
  Ionic: blockierendes Overlay „Personen werden übertragen...“ / Flutter: nur Spinner im FAB, kein Text, Seite bleibt bedienbar.
  Flutter: lib/features/settings/presentation/pages/handover_detail_page.dart:133, lib/features/settings/presentation/pages/handover_detail_page.dart:190-202
- [ ] **niedrig** `settings/handover/handover.page` `text-a96b4575` [settings/handover/handover.page.html:51](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/handover/handover.page.html#L51)
  Text "Filter hinzufügen" gleich. Ionic: Eintrag ohne Icon / Flutter: zusätzliches Filter-Icon (Icons.filter_list) links.
  Flutter: lib/features/settings/presentation/pages/handover_page.dart:218
- [ ] **niedrig** `settings/help/help.page` `text-0fe83dd4` [settings/help/help.page.html:65](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/help/help.page.html#L65)
  Kategorie-Label und Icon gleich. Ionic: ion-accordion-group ohne multiple → beim Öffnen einer Kategorie schließt die vorher offene / Flutter: unabhängige ExpansionTiles, mehrere Kategorien gleichzeitig offen.
  Flutter: lib/features/help/presentation/pages/help_page.dart:143, lib/features/help/presentation/pages/help_page.dart:149
- [ ] **niedrig** `settings/settings/settings.page` `modal-8e265ba0` [settings/settings/settings.page.ts:252](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L252)
  iOS: Karten-Modal wie Ionic (presentingElement). md/Android/Desktop: Ionic Vollbild- bzw. zentriertes Desktop-Modal / Flutter context.push('/history') als normale Seite im Shell.
  Flutter: lib/features/settings/presentation/pages/settings_page.dart:323, lib/features/history/presentation/pages/history_page.dart:32
- [ ] **niedrig** `settings/settings/settings.page` `modal-574f5f7c` [settings/settings/settings.page.ts:279](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L279) (2. Prüfung: bestätigt)
  Nur Optik (Leon 05.11.2026): Ablaufpläne öffnen als Seite statt Modal, gleiche Funktion und Rückkehr. – Befund: Ionic: 'Ablaufpläne' öffnet PlanningPage als Karten-Modal (presentingElement, cssClass planningModal, Schließen-X) / Flutter: context.push('/planning') – normale Seite im Shell mit Zurück-Pfeil (Statistik/Export/Verlauf öffnet Flutter dagegen als Modal).
  Flutter: lib/features/settings/presentation/pages/settings_page.dart:360, lib/core/router/app_router.dart:901
- [ ] **niedrig** `settings/settings/settings.page` `alert-7b4ee94f` [settings/settings/settings.page.ts:355](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L355) (2. Prüfung: bestätigt)
  Titel 'Beobachter entfernen?', Nachricht 'Möchtest du {name} wirklich entfernen?', Buttons Abbrechen/Ja und Löschweg (tenantUsers ohne Admin-Rolle + viewers id/tenantId) gleich. Flutter zusätzlich: Erfolgs-Toast 'Beobachter entfernt' (Flutter-only) und 'Ja' rot hinterlegt; Ionic zeigt nach dem Entfernen keinen Toast.
  Flutter: lib/features/settings/presentation/pages/viewers_page.dart:204, lib/features/settings/presentation/pages/viewers_page.dart:208, lib/features/settings/presentation/pages/viewers_page.dart:209, lib/features/settings/presentation/pages/viewers_page.dart:227, lib/features/settings/presentation/pages/viewers_page.dart:230
- [ ] **niedrig** `settings/settings/settings.page` `alert-1497e709` [settings/settings/settings.page.ts:373](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L373)
  Titel 'Elternteil entfernen?', Nachricht und Buttons gleich. Flutter zusätzlich: Erfolgs-Toast 'Elternteil entfernt' (Flutter-only) und Fehler-Toast; Ionic ohne Toast.
  Flutter: lib/features/settings/presentation/pages/parents_page.dart:204, lib/features/settings/presentation/pages/parents_page.dart:208, lib/features/settings/presentation/pages/parents_page.dart:209, lib/features/settings/presentation/pages/parents_page.dart:230
- [ ] **niedrig** `settings/settings/settings.page` `loading-050c9fa4` [settings/settings/settings.page.ts:395](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L395)
  Ionic: blockierendes Loading (3 s) beim Instanzwechsel / Flutter: kein Ladeoverlay, Wechsel läuft im Hintergrund (Sheet wird sofort geschlossen).
  Flutter: lib/shared/widgets/tenant/tenant_switcher_title.dart:389, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:161
- [ ] **niedrig** `settings/settings/settings.page` `alert-39899a98` [settings/settings/settings.page.ts:418](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L418)
  Titel 'Beobachter hinzufügen', Felder E-Mail-Adresse/Vorname/Nachname, Buttons Abbrechen/Einladen gleich. Ionic: Platzhalter, Prüfung per E-Mail-Regex + Pflichtfelder, bei Fehler Alert-Nachricht 'Bitte gib gültige Werte ein.' / Flutter: Labels mit Icons, Prüfung nur auf '@', feldweise Fehlertexte ('E-Mail ist erforderlich', 'Ungültige E-Mail-Adresse', 'Vorname ist erforderlich' …).
  Flutter: lib/features/settings/presentation/pages/viewers_page.dart:103, lib/features/settings/presentation/pages/viewers_page.dart:112, lib/features/settings/presentation/pages/viewers_page.dart:118, lib/features/settings/presentation/pages/viewers_page.dart:129, lib/features/settings/presentation/pages/viewers_page.dart:169, lib/features/settings/presentation/pages/viewers_page.dart:177
- [ ] **niedrig** `settings/settings/settings.page` `loading-7a0b5d62` [settings/settings/settings.page.ts:437](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L437) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading während createViewer / Flutter: Dialog schließt, kein Ladeindikator bis Toast/Listen-Update.
  Flutter: lib/features/settings/presentation/pages/viewers_page.dart:186
- [ ] **niedrig** `settings/settings/settings.page` `alert-7ca4ade1` [settings/settings/settings.page.ts:460](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L460)
  Titel 'Elternteil hinzufügen', Felder und Buttons gleich. Ionic: E-Mail-Regex + Pflichtfelder, Fehler als Alert-Nachricht 'Bitte gib gültige Werte ein.' / Flutter: Prüfung nur auf '@', feldweise Flutter-only-Fehlertexte.
  Flutter: lib/features/settings/presentation/pages/parents_page.dart:103, lib/features/settings/presentation/pages/parents_page.dart:112, lib/features/settings/presentation/pages/parents_page.dart:125, lib/features/settings/presentation/pages/parents_page.dart:129, lib/features/settings/presentation/pages/parents_page.dart:177
- [ ] **niedrig** `settings/settings/settings.page` `loading-58a1f0f9` [settings/settings/settings.page.ts:479](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L479) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading während createParent / Flutter: Dialog schließt, kein Ladeindikator bis Toast/Listen-Update.
  Flutter: lib/features/settings/presentation/pages/parents_page.dart:186
- [ ] **niedrig** `settings/settings/settings.page` `alert-7157049d` [settings/settings/settings.page.ts:511](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L511)
  Titel, Nachricht, Platzhalter, Abbrechen/Löschen, falscher Name → 'Der eingegebene Name ist nicht korrekt.' (Dialog bleibt offen) gleich. Ionic nach Löschen: setTenant() + Navigation zur Startseite der Rolle auch wenn eine andere als die aktuelle Instanz gelöscht wurde / Flutter: Sheet zu, Toast, nur bei der aktuellen Instanz go('/tenants') (Auto-Auswahl), sonst bleibt die Mehr-Seite offen.
  Flutter: lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:269, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:275, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:283, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:290, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:305, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:311, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:329, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:335
- [ ] **niedrig** `settings/settings/settings.page` `loading-48280d26` [settings/settings/settings.page.ts:525](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L525)
  Ionic: blockierendes Loading 'Instanz wird entfernt...' / Flutter: kein Ladeoverlay während des Löschens.
  Flutter: lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:329
- [ ] **niedrig** `settings/settings/settings.page` `loading-bfd0a3e6` [settings/settings/settings.page.ts:542](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L542)
  Ionic: blockierendes Loading beim Favorit setzen / Flutter: kein Ladeoverlay.
  Flutter: lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:241
- [ ] **niedrig** `settings/settings/settings.page` `alert-7be72d9c` [settings/settings/settings.page.ts:569](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L569) (2. Prüfung: bestätigt)
  Titel 'Gruppen auswählen', Nachricht, alle Gruppen vorausgewählt, Abbrechen/Generieren, Filter (nicht ausgetreten/pausiert/ausstehend) gleich. Ionic: ohne Auswahl bleibt der Alert offen (Warn-Toast); während der Erstellung blockierendes Loading 'settings.creatingCertificates' / Flutter: Dialog schließt, dann Warn-Toast; statt Loading nur Info-Toast.
  Flutter: lib/features/settings/presentation/widgets/vorkurs_certificates.dart:33, lib/features/settings/presentation/widgets/vorkurs_certificates.dart:38, lib/features/settings/presentation/widgets/vorkurs_certificates.dart:43, lib/features/settings/presentation/widgets/vorkurs_certificates.dart:78, lib/features/settings/presentation/widgets/vorkurs_certificates.dart:85, lib/features/settings/presentation/widgets/vorkurs_certificates.dart:119
- [ ] **niedrig** `settings/settings/settings.page` `loading-5eec4aaf` [settings/settings/settings.page.ts:588](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L588)
  Ionic: blockierendes Loading 'Urkunden werden erstellt...' / Flutter: nur Info-Toast mit demselben Text, nicht blockierend.
  Flutter: lib/features/settings/presentation/widgets/vorkurs_certificates.dart:43
- [ ] **niedrig** `settings/settings/settings.page` `effect-19f49e82` [settings/settings/settings.page.ts:600](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L600)
  PDF gleich (eine A4-Seite je Person mit Hintergrund, Name Times fett-kursiv 48→28 pt, 'hat die Vorkursprüfung / erfolgreich bestanden', 'Speyer, den D.M.YYYY'), Dateiname Urkunden_Vorkurs_YYYY-MM-DD.pdf, nativ Cache + Dateiansicht wie Ionic. Ionic mobiles Web (iOS/Android): Teilen-Dialog (navigator.share) / Flutter Web: immer Anker-Download (Printing.sharePdf). Gleicher Befund wie utilities/Utils#effect-c485f21b. Rollen wie toast-d085d424.
  Flutter: lib/features/settings/presentation/widgets/vorkurs_certificates.dart:53, lib/features/settings/presentation/widgets/vorkurs_certificates.dart:57, lib/core/services/certificate_service.dart:29, lib/core/services/native/native_file_service.dart:167
- [ ] **niedrig** `settings/settings/settings.page` `alert-271738b9` [settings/settings/settings.page.ts:614](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L614)
  Titel 'Admin hinzufügen', Platzhalter 'E-Mail-Adresse', Abbrechen/Hinzufügen gleich. Ionic: ungültige/leere E-Mail → Alert bleibt offen mit 'Bitte gib gültige Werte ein.' / Flutter: leer → Dialog schließt still, ungültig → Dialog zu + Toast 'Bitte gib eine gültige E-Mail-Adresse ein.' (Flutter-only).
  Flutter: lib/features/settings/presentation/widgets/settings_admins_sheet.dart:36, lib/features/settings/presentation/widgets/settings_admins_sheet.dart:39, lib/features/settings/presentation/widgets/settings_admins_sheet.dart:40, lib/features/settings/presentation/widgets/settings_admins_sheet.dart:41, lib/features/settings/presentation/widgets/settings_admins_sheet.dart:45, lib/features/settings/presentation/widgets/settings_admins_sheet.dart:46
- [ ] **niedrig** `settings/settings/settings.page` `loading-8befac68` [settings/settings/settings.page.ts:627](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L627) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading während createAdmin / Flutter: nur Spinner im FAB (FAB deaktiviert), Sheet bleibt bedienbar.
  Flutter: lib/features/settings/presentation/widgets/settings_admins_sheet.dart:100, lib/features/settings/presentation/widgets/settings_admins_sheet.dart:106
- [ ] **niedrig** `settings/settings/settings.page` `actionsheet-0d48212e` [settings/settings/settings.page.ts:861](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L861)
  Buttons 'Passbild ersetzen', bei echtem Bild 'Passbild ansehen' + 'Passbild entfernen' (destruktiv), 'Abbrechen' in gleicher Reihenfolge. Flutter zeigt zusätzlich Icons vor den Einträgen.
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:118, lib/features/profile/presentation/widgets/master_data_sheet.dart:121, lib/features/profile/presentation/widgets/master_data_sheet.dart:126, lib/features/profile/presentation/widgets/master_data_sheet.dart:132, lib/features/profile/presentation/widgets/master_data_sheet.dart:137
- [ ] **niedrig** `settings/settings/settings.page` `loading-f3f08e9f` [settings/settings/settings.page.ts:957](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L957)
  Ionic: blockierendes Loading während des Passbild-Uploads / Flutter: kein Ladeindikator beim Upload.
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:160, lib/features/profile/presentation/widgets/master_data_sheet.dart:178
- [ ] **niedrig** `settings/settings/settings.page` `toast-a9658903` [settings/settings/settings.page.ts:979](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L979)
  Ionic: Upload-Fehler zeigt die rohe Fehlermeldung / Flutter: festen Text 'Fehler beim ändern des Passbildes, versuche es später erneut'.
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:188, lib/features/profile/presentation/widgets/master_data_sheet.dart:193
- [ ] **niedrig** `settings/settings/settings.page` `native-ba3cad21` [settings/settings/settings.page.ts:990](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L990)
  Ionic: Browser.open (In-App-Browser) für https://t.me/Eckstaedt / Flutter: launchUrl externalApplication (externe App/Browser).
  Flutter: lib/shared/widgets/sheets/feedback_sheet.dart:180, lib/shared/widgets/sheets/feedback_sheet.dart:275
- [ ] **niedrig** `settings/settings/settings.page` `loading-2f222624` [settings/settings/settings.page.ts:994](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L994)
  Ionic: blockierendes Loading / Flutter: Spinner im Absenden-Button, nicht blockierend.
  Flutter: lib/shared/widgets/sheets/feedback_sheet.dart:86, lib/shared/widgets/sheets/feedback_sheet.dart:390
- [ ] **niedrig** `settings/settings/settings.page` `toast-f39cf2c9` [settings/settings/settings.page.ts:1010](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L1010)
  Ionic: 'Fehler beim Senden der Anfrage: {error}' / Flutter: 'Fehler beim Senden der Frage' ohne Fehlerdetail.
  Flutter: lib/shared/widgets/sheets/feedback_sheet.dart:103
- [ ] **niedrig** `settings/settings/settings.page` `loading-35a4db51` [settings/settings/settings.page.ts:1016](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L1016) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading während sendFeedback / Flutter: Spinner im 'Absenden'-Button (Button deaktiviert), nicht blockierend.
  Flutter: lib/shared/widgets/sheets/feedback_sheet.dart:113, lib/shared/widgets/sheets/feedback_sheet.dart:390
- [ ] **niedrig** `settings/settings/settings.page` `toast-8545be66` [settings/settings/settings.page.ts:1020](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L1020) (2. Prüfung: bestätigt)
  Gleicher Text 'Bitte gib eine Bewertung ab.'; Ionic rot (danger) / Flutter Warnfarbe.
  Flutter: lib/shared/widgets/sheets/feedback_sheet.dart:108, lib/shared/widgets/sheets/feedback_sheet.dart:109
- [ ] **niedrig** `settings/settings/settings.page` `toast-70d8cc00` [settings/settings/settings.page.ts:1041](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L1041) (2. Prüfung: bestätigt)
  Ionic: Service-Toast 'Fehler beim Senden des Feedbacks' plus Seiten-Toast 'Fehler beim Senden des Feedbacks: {error}' / Flutter: nur 'Fehler beim Senden des Feedbacks' ohne Fehlerdetail.
  Flutter: lib/shared/widgets/sheets/feedback_sheet.dart:135
- [ ] **niedrig** `settings/settings/settings.page` `alert-ea6ef480` [settings/settings/settings.page.ts:1056](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L1056)
  Titel 'Passwort ändern', Platzhalter, Abbrechen/Ändern, Prüfungen (gleich, ≥6) gleich. Ionic: bei Server-Fehler schließt der Alert / Flutter: Dialog bleibt offen.
  Flutter: lib/features/profile/presentation/widgets/account_dialogs.dart:13, lib/features/profile/presentation/widgets/account_dialogs.dart:58, lib/features/profile/presentation/widgets/account_dialogs.dart:112, lib/features/profile/presentation/widgets/account_dialogs.dart:121, lib/features/profile/presentation/widgets/account_dialogs.dart:134, lib/features/profile/presentation/widgets/account_dialogs.dart:138
- [ ] **niedrig** `settings/settings/settings.page` `action-f029eaa1` [settings/settings/settings.page.html:12](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L12)
  Ohne Sidepanel Instanz-Langname mit Chevron. Ionic zeigt den Button immer (auch bei nur einer Instanz, Popover mit einem Eintrag) / Flutter zeigt bei ≤1 Instanz nur den Namen als Text ohne Chevron und ohne Popover.
  Flutter: lib/features/settings/presentation/pages/settings_page.dart:144, lib/shared/widgets/tenant/tenant_switcher_title.dart:51, lib/shared/widgets/tenant/tenant_switcher_title.dart:52, lib/shared/widgets/tenant/tenant_switcher_title.dart:61
- [ ] **niedrig** `settings/settings/settings.page` `action-376a8e41` [settings/settings/settings.page.html:39](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L39)
  Pull-to-Refresh vorhanden; lädt aber Profil/Hero-Karte, Zusatzfelder, Gemeinden und Teamorganisation nicht neu (Ionic initialize() lädt alles), siehe extra.
  Flutter: lib/features/settings/presentation/pages/settings_page.dart:162, lib/features/settings/presentation/pages/settings_page.dart:163
- [ ] **niedrig** `settings/settings/settings.page` `action-e089eec6` [settings/settings/settings.page.html:57](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L57)
  Text und Ziel gleich (iOS App Store / Google Play). Icon Android: Ionic logo-google-playstore / Flutter Icons.shop (Einkaufstasche); Button weiß mit tertiary-Text statt Ionic color='light'.
  Flutter: lib/features/settings/presentation/widgets/app_promo_card.dart:113, lib/features/settings/presentation/widgets/app_promo_card.dart:116, lib/features/settings/presentation/widgets/app_promo_card.dart:117
- [ ] **niedrig** `settings/settings/settings.page` `action-87682d7a` [settings/settings/settings.page.html:66](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L66)
  Text und Ziel gleich; Icon Ionic logo-google-playstore / Flutter Icons.shop.
  Flutter: lib/features/settings/presentation/widgets/app_promo_card.dart:129, lib/features/settings/presentation/widgets/app_promo_card.dart:131, lib/features/settings/presentation/widgets/app_promo_card.dart:132, lib/features/settings/presentation/widgets/app_promo_card.dart:133
- [ ] **niedrig** `settings/settings/settings.page` `text-a4f92d9f` [settings/settings/settings.page.html:144](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L144)
  'Name: Wert' für alle für Spieler sichtbaren Zusatzfelder, '—' bei leer, Gemeindename. Abweichend: Feldtyp Datum – Ionic Rohwert (z. B. 2024-05-01) / Flutter dd.MM.yyyy; Ja/Nein-Feld ohne Wert (nicht editierbar) – Ionic 'Nein' / Flutter Default-Wert.
  Flutter: lib/features/profile/presentation/widgets/profile_hero_card.dart:49, lib/features/profile/presentation/widgets/profile_hero_card.dart:53, lib/features/profile/presentation/widgets/profile_helpers.dart:49, lib/features/profile/presentation/widgets/profile_helpers.dart:57, lib/features/profile/presentation/widgets/profile_helpers.dart:67
- [ ] **niedrig** `settings/settings/settings.page` `field-3a03c0eb` [settings/settings/settings.page.html:186](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L186)
  Datums-Button im Format '16. Feb. 2002'. Ohne Geburtsdatum: Ionic ion-datetime-button zeigt das heutige Datum / Flutter 'Auswählen'.
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:326, lib/features/profile/presentation/widgets/master_data_sheet.dart:329, lib/features/profile/presentation/widgets/master_data_sheet.dart:331, lib/features/profile/presentation/widgets/profile_helpers.dart:41
- [ ] **niedrig** `settings/settings/settings.page` `field-b5ead18a` [settings/settings/settings.page.html:205](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L205)
  Auswahl mit Feldname und allen Optionen in Reihenfolge. Ohne Wert: Ionic leer / Flutter Platzhalter 'Bitte auswählen'.
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:377, lib/features/profile/presentation/widgets/master_data_sheet.dart:383, lib/features/profile/presentation/widgets/master_data_sheet.dart:394
- [ ] **niedrig** `settings/settings/settings.page` `modal-b0fe3226` [settings/settings/settings.page.html:215](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L215) (2. Prüfung: bestätigt)
  Ionic: Vollbild-ion-modal (ohne Breakpoints) / Flutter: Bottom-Sheet mit 95 % Höhe; Inhalt (Titel Feldname, Schließen, Suche, 'Nicht gelistet', Häkchen) gleich.
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:505, lib/features/profile/presentation/widgets/church_picker.dart:16, lib/features/profile/presentation/widgets/church_picker.dart:31
- [ ] **niedrig** `settings/settings/settings.page` `text-88aeecc7` [settings/settings/settings.page.html:261](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L261)
  Anzeige nicht editierbarer Felder wie getExtraFieldDisplayValue, außer: Datum – Ionic Rohwert / Flutter dd.MM.yyyy; Ja/Nein ohne Wert – Ionic 'Nein' / Flutter Default-Wert.
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:364, lib/features/profile/presentation/widgets/profile_helpers.dart:49, lib/features/profile/presentation/widgets/profile_helpers.dart:67
- [ ] **niedrig** `settings/settings/settings.page` `action-46a45423` [settings/settings/settings.page.html:282](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L282)
  Ionic setzt nur das HTML-Attribut title='Passbild' (Kopfzeile des Viewers bleibt leer, Tooltip im Web) / Flutter zeigt 'Passbild.jpg' als Titel in der Kopfzeile.
  Flutter: lib/features/profile/presentation/widgets/master_data_sheet.dart:153, lib/shared/widgets/sheets/image_viewer_sheet.dart:276
- [ ] **niedrig** `settings/settings/settings.page` `action-5bb3e6ac` [settings/settings/settings.page.html:463](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L463) (2. Prüfung: korrigiert)
  Rollen/Mandant gleich (Admin/Verantwortliche, tenant.parents); Tippen → Entfernen-Dialog. Erstprüfung übersah: Ionic: ion-item button ohne detail="false" → auf iOS Chevron am Zeilenende; Liste ohne ORDER BY (DB-Reihenfolge) / Flutter: kein Chevron, Liste nach Nachname, Vorname sortiert (die Sortierung ist eher besser).
  Flutter: lib/features/settings/presentation/pages/parents_page.dart:88-92, lib/features/settings/presentation/pages/parents_page.dart:253-259, lib/data/repositories/parent_repository.dart:19-26
- [ ] **niedrig** `settings/settings/settings.page` `action-c5e57298` [settings/settings/settings.page.html:703](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L703)
  Zeile 'Vorname Nachname (Gruppe)' + 'Ausgetreten: dd.MM.yyyy', Tippen öffnet die Person. Flutter zusätzlich: grüner Reaktivieren-Button je Zeile mit eigenem Dialog 'Person wieder aktivieren?' und Toast '{name} wurde reaktiviert' (Flutter-only); in Ionic nur über die Person.
  Flutter: lib/features/settings/presentation/pages/left_players_page.dart:198, lib/features/settings/presentation/pages/left_players_page.dart:200, lib/features/settings/presentation/pages/left_players_page.dart:203, lib/features/settings/presentation/pages/left_players_page.dart:204, lib/features/settings/presentation/pages/left_players_page.dart:141
- [ ] **niedrig** `settings/settings/settings.page` `modal-4c83c19f` [settings/settings/settings.page.html:811](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L811) (2. Prüfung: bestätigt)
  iOS: Sheet in voller Höhe wie Ionic [0,1]. md: Ionic volle Höhe / Flutter ziehbares Sheet initial 70 %, max. 90 %.
  Flutter: lib/features/settings/presentation/pages/settings_page.dart:543, lib/shared/widgets/sheets/feedback_sheet.dart:19, lib/shared/widgets/sheets/feedback_sheet.dart:20, lib/shared/widgets/sheets/feedback_sheet.dart:38, lib/shared/widgets/sheets/feedback_sheet.dart:236
- [ ] **niedrig** `settings/settings/settings.page` `field-a041b4f2` [settings/settings/settings.page.html:832](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L832)
  Segmente 'Hilfe/Frage' / 'Feedback' gleich. Flutter leert beim Wechsel alle Eingaben (Frage, Feedback, Telefon, Bewertung, Anonym) / Ionic behält sie.
  Flutter: lib/shared/widgets/sheets/feedback_sheet.dart:198, lib/shared/widgets/sheets/feedback_sheet.dart:210, lib/shared/widgets/sheets/feedback_sheet.dart:288, lib/shared/widgets/sheets/feedback_sheet.dart:290
- [ ] **niedrig** `settings/settings/settings.page` `action-c7c0892e` [settings/settings/settings.page.html:866](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L866)
  iOS gleich (5 gefüllte Sterne, warning/medium). md: Flutter große Sterne als Outline (star_border) statt grau gefüllt, zentriert unter Flutter-only-Text „Wie gefällt dir die App?“.
  Flutter: lib/shared/widgets/sheets/feedback_sheet.dart:425, lib/shared/widgets/sheets/feedback_sheet.dart:433, lib/shared/widgets/sheets/feedback_sheet.dart:439, lib/shared/widgets/sheets/feedback_sheet.dart:546, lib/shared/widgets/sheets/feedback_sheet.dart:550
- [ ] **niedrig** `settings/settings/settings.page` `field-ace4bcc6` [settings/settings/settings.page.html:876](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L876) (2. Prüfung: bestätigt)
  Schalter 'Anonym' gleich, blendet das Telefonfeld aus; anonym schreibt tenant_id/user_id null wie Ionic. md zusätzlich Flutter-only-Untertitel 'Deine Daten werden nicht mitgesendet'.
  Flutter: lib/shared/widgets/sheets/feedback_sheet.dart:453, lib/shared/widgets/sheets/feedback_sheet.dart:454, lib/shared/widgets/sheets/feedback_sheet.dart:571, lib/shared/widgets/sheets/feedback_sheet.dart:574
- [ ] **niedrig** `settings/settings/settings.page` `action-25aed01a` [settings/settings/settings.page.html:970](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L970) (2. Prüfung: bestätigt)
  Kurzname, Langname, Badge 'Aktuell', Favoriten-Stern, Tippen wechselt (aktuelle: nichts, sonst Sheet zu und Start-URL der Rolle) wie Ionic. Flutter zusätzlich: Info-Button je Instanz → Flutter-only Detailseite (Mitgliederzahl, Rolle, Löschen nur Admin).
  Flutter: lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:537, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:539, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:541, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:549, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:566, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:569, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:168
- [ ] **niedrig** `settings/voice-leader/voice-leader.page` `toast-19ba0043` [settings/voice-leader/voice-leader.page.ts:90](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/voice-leader/voice-leader.page.ts#L90)
  Ionic: roter Toast "Fehler beim Laden der Gruppenmitglieder.", Seite zeigt danach den (leeren) Gruppenkopf / Flutter: kein Toast, stattdessen Fehlerzustand auf der Seite mit demselben Text, der rohen Fehlermeldung (error.toString()) und Button "Erneut versuchen".
  Flutter: lib/features/voice_leader/presentation/pages/voice_leader_page.dart:56, lib/features/voice_leader/presentation/pages/voice_leader_page.dart:61, lib/features/voice_leader/presentation/pages/voice_leader_page.dart:62
- [ ] **niedrig** `settings/voice-leader/voice-leader.page` `text-e0cad10d` [settings/voice-leader/voice-leader.page.html:27](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/voice-leader/voice-leader.page.html#L27)
  Gruppenname gleich. Fallback ohne Gruppe: Ionic "Meine Stimme" (voiceLeader.myVoice) / Flutter "Stimmgruppe" (voiceLeaderFlutterVoiceGroup); Flutter zeigt den Fallback auch kurz, solange der Name noch lädt.
  Flutter: lib/features/voice_leader/presentation/pages/voice_leader_page.dart:84, lib/features/voice_leader/presentation/pages/voice_leader_page.dart:166, lib/features/voice_leader/data/providers/voice_leader_providers.dart:48
- [ ] **niedrig** `settings/voice-leader/voice-leader.page` `text-1fe5d099` [settings/voice-leader/voice-leader.page.html:28](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/voice-leader/voice-leader.page.html#L28)
  Ionic: "1 Mitglied" bei genau einem, sonst "n Mitglieder" / Flutter: immer "{count} Mitglieder" (auch "1 Mitglieder").
  Flutter: lib/features/voice_leader/presentation/pages/voice_leader_page.dart:170
- [ ] **niedrig** `settings/voice-leader/voice-leader.page` `text-cfb6a3f5` [settings/voice-leader/voice-leader.page.html:54](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/voice-leader/voice-leader.page.html#L54)
  Badge mit player.additional_fields.einteilung gleich. Ionic: Feld-Definition aus getPersonExtraFields (Organisation + Instanz) / Flutter: nur Instanz-Felder (currentTenant.additionalFields) → ist "einteilung" nur als Organisationsfeld angelegt, zeigt Flutter kein Badge (Ionic nur bei lokal am Spieler gespeichertem Wert).
  Flutter: lib/features/voice_leader/presentation/pages/voice_leader_page.dart:30, lib/features/voice_leader/presentation/pages/voice_leader_page.dart:232, lib/features/voice_leader/presentation/pages/voice_leader_page.dart:259
- [ ] **niedrig** `settings/voice-leader/voice-leader.page` `text-2c67af35` [settings/voice-leader/voice-leader.page.html:81](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/voice-leader/voice-leader.page.html#L81)
  Datum dd.MM., typeInfo bzw. Typname, Farben (Entschuldigt/Verspätet entschuldigt gelb, Abwesend rot) gleich. Ionic: getPersonAttendances lädt attType ohne hide_name → Typname wird auch bei "Name ausblenden" angezeigt ("12.05. Probe") / Flutter beachtet hide_name und zeigt nur "12.05.".
  Flutter: lib/features/voice_leader/presentation/pages/voice_leader_page.dart:296, lib/features/voice_leader/presentation/pages/voice_leader_page.dart:298, lib/features/voice_leader/data/providers/voice_leader_providers.dart:125
- [ ] **niedrig** `settings/general/branding/branding.page` `x-0bb81f21ff` **Demo-Sperre schon bei Logo-Upload/-Entfernen** [src/app/services/image/image.service.ts:136](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/image/image.service.ts#L136)
  Ionic: updateOrgLogo/removeOrgLogo ohne checkDemoRestriction – das Demo-Konto kann die Datei org-<id> im Bucket branding überschreiben/löschen, nur Speichern ist gesperrt / Flutter besser: uploadLogo/removeLogo rufen ensureNotDemo (Demo-Toast, kein Storage-Zugriff)
  Flutter: lib/data/repositories/organisation_settings_repository.dart:94, lib/data/repositories/organisation_settings_repository.dart:113
- [ ] **niedrig** `settings/general/general.page` `x-d86d0880b8` **Änderungserkennung für Ungespeichert-Dialog** [src/app/settings/general/general.page.ts:160](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.ts#L160)
  Ionic: Vergleich mit Ausgangszustand (JSON); Abwesenheits-/Verspätungsgründe nicht erfasst, Zurückschalten gilt als keine Änderung; Prüfung nur beim Header-Zurück und beforeunload / Flutter: Dirty-Flag bei jeder Eingabe inkl. Gründe, bleibt nach Zurückschalten gesetzt; Dialog auch bei System-Zurück (PopScope).
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:313, lib/features/settings/presentation/pages/general_settings_page.dart:415
- [ ] **niedrig** `settings/general/general.page` `x-42b30dc6ee` **Problemfall-Regel bearbeiten nur in Flutter** [src/app/settings/general/general.page.html:343](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L343)
  Ionic: Regeln nur hinzufügen/löschen / Flutter: Tippen auf eine Regel öffnet Sheet „Regel bearbeiten“ (Button „Speichern“, Toast „Regel aktualisiert“).
  Flutter: lib/features/settings/presentation/widgets/critical_rule_card.dart:31, lib/features/settings/presentation/pages/general_settings_page.dart:839
- [ ] **niedrig** `settings/general/general.page` `x-17553629eb` **Gründe per Drag sortierbar nur in Flutter** [src/app/settings/general/general.page.html:98](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.html#L98)
  Ionic: feste Reihenfolge / Flutter: Drag-Handle zum Umsortieren der Abwesenheits- und Verspätungsgründe.
  Flutter: lib/features/settings/presentation/widgets/reasons_list_editor.dart:122
- [ ] **niedrig** `settings/general/general.page` `x-42634188f9` **Legacy-Regeln ohne period_type** [src/app/settings/general/general.page.ts:146](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/general.page.ts#L146)
  Ionic: ergänzt beim Laden period_type = 'days' und speichert es beim nächsten Speichern mit / Flutter: lässt period_type leer und schreibt die Regel ohne period_type (Auswertung durch evaluate-critical-rules ggf. anders).
  Flutter: lib/features/settings/presentation/pages/general_settings_page.dart:164, lib/features/settings/presentation/pages/general_settings_page.dart:262
- [ ] **niedrig** `settings/general/link-persons/link-persons.page` `x-2fb83d6081` **Ignorier-Liste nicht übernommen** [src/app/settings/general/link-persons/link-persons.page.ts:43](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/link-persons/link-persons.page.ts#L43)
  Ionic: localStorage-Schlüssel 'link-persons-ignored' / Flutter: SharedPreferences (Web: 'flutter.link-persons-ignored', nativ eigener Speicher) – in Ionic ignorierte Vorschläge erscheinen nach dem Umstieg wieder.
  Flutter: lib/features/settings/presentation/pages/link_persons_page.dart:92, lib/features/settings/presentation/pages/link_persons_page.dart:110
- [ ] **niedrig** `settings/general/shifts/shifts.page` `x-22546d78c2` **Erfolgs-Toast nur in Flutter** [src/app/settings/general/shifts/shifts.page.ts:47-50](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shifts.page.ts#L47-L50)
  Ionic: nach dem Anlegen kein Toast, direkt Navigation / Flutter: zusätzlich grüner Toast „Schichtplan "<Name>" erstellt“.
  Flutter: lib/features/shifts/presentation/pages/shifts_list_page.dart:198
- [ ] **niedrig** `settings/general/shifts/shifts.page` `x-f357eb8375` **Name/Beschreibung getrimmt** [src/app/settings/general/shifts/shifts.page.ts:40-45](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/shifts/shifts.page.ts#L40-L45)
  Ionic: speichert name/description ungetrimmt / Flutter: trim() vor dem Insert.
  Flutter: lib/features/shifts/presentation/pages/shifts_list_page.dart:173-178
- [ ] **niedrig** `settings/general/type/type.page` `x-b41f2f171e` **Agenda-Marker-Zeit nicht normalisiert** [src/app/settings/general/type/type.page.ts:113-119](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L113-L119)
  Ionic: setzt beim Laden die Zeit des Tagesordnungs-Markers auf 0 (ältere Pläne: 30 Min.) / Flutter: übernimmt die gespeicherte Zeit, zählt sie in „Gesamt“ mit und speichert sie wieder.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1228-1235
- [ ] **niedrig** `settings/general/type/type.page` `x-f8e7ccbb61` **Speichern schreibt null statt Werte** [src/app/settings/general/type/type.page.ts:189-196](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L189-L196)
  Ionic: schreibt das ganze Typ-Objekt (reminders [], planning_title '', end_time/duration_days bleiben) / Flutter: reminders/checklist/planning_title leer → null, end_time bei ganztägig → null, duration_days bei nicht-ganztägig → null.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1470-1511
- [ ] **niedrig** `settings/general/type/type.page` `x-c9929afd0d` **Änderungserkennung per Flag** [src/app/settings/general/type/type.page.ts:131-143](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L131-L143)
  Ionic: Vergleich mit Original-JSON (Zurückändern = keine Änderung) / Flutter: Flag _hasChanges bleibt nach Zurückändern gesetzt → Rückfrage beim Verlassen trotz unverändertem Stand.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:95, lib/features/settings/presentation/pages/attendance_type_edit_page.dart:245
- [ ] **niedrig** `settings/general/type/type.page` `x-975297fc93` **Nutzungs-Hinweiskarte nur in Flutter** [src/app/settings/general/type/type.page.html:26-34](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L26-L34)
  Ionic: kein Hinweis / Flutter: Karte oben „Wird in {count} Termin(en) verwendet. Änderungen wirken sich auf bestehende Einträge aus.“
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:251-271
- [ ] **niedrig** `settings/general/type/type.page` `x-c81359471b` **Veralteter Zusatzfeld-Filter** [src/app/settings/general/type/type.page.ts:122](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L122)
  Ionic: zeigt „Kein Filter“, wenn der gespeicherte Schlüssel kein aktuelles Personen-Zusatzfeld ist (Filter bleibt gespeichert) / Flutter: übergibt den unbekannten Schlüssel als Dropdown-Wert ohne passenden Eintrag (Debug-Assertion, sonst leere Auswahl).
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1107, lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1122-1124
- [ ] **niedrig** `settings/settings/settings.page` `x-d58dd9dbc3` **Pull-to-Refresh lädt Profil/Team nicht neu** [src/app/settings/settings/settings.page.ts:195](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.ts#L195)
  Ionic: handleRefresh() → initialize() lädt Profil (Hero-Karte/Stammdaten inkl. Org-Feldwerte), Zusatzfelder, Gemeinden, Team-Zugang, Admins, Viewer, Eltern, Archiv, Pending neu / Flutter: invalidiert nur Tenant, Instanzen, Pending, Spieler, Beobachter, Eltern, Admins, Archiv – ownProfileProvider, personExtraFieldsProvider, churchesProvider und Team-Provider bleiben im Cache.
  Flutter: lib/features/settings/presentation/pages/settings_page.dart:162, lib/features/settings/presentation/pages/settings_page.dart:163, lib/core/providers/profile_providers.dart:47
- [ ] **niedrig** `settings/settings/settings.page` `x-0292e79cc1` **Flutter-only Zeile 'Neues Design (Beta)'** [src/app/settings/settings/settings.page.html:741](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/settings/settings.page.html#L741)
  Ionic: System-Block ohne diese Zeile / Flutter: im normalen Design zwischen Sprache und Benachrichtigungen die Zeile 'Neues Design (Beta)' mit Badge 'NEU', Hinweis 'Nur auf diesem Gerät. Jederzeit wieder ausschaltbar.' und Schalter (für alle Rollen).
  Flutter: lib/features/settings/presentation/pages/settings_page.dart:517, lib/features/settings/presentation/widgets/redesign_beta_tile.dart:12
- [ ] **niedrig** `settings/administration/administration.page` `x-cb6fc2f426` **Fehlertoast beim Speichern des Speicherlimits** [src/app/services/tenant/tenant.service.ts:54](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/tenant/tenant.service.ts#L54)
  Ionic: updateTenantData-Fehler zeigt Service-Toast "Fehler beim Aktualisieren der Einstellungen" (svc.updateSettingsFailed) und setzt Feld zurück / Flutter: setzt Feld zurück und zeigt "Fehler beim Speichern" (svcSaveFailed).
  Flutter: lib/features/dashboard/presentation/pages/administration_page.dart:86, lib/features/dashboard/presentation/pages/administration_page.dart:88
- [ ] **niedrig** `settings/auto-messages/list/auto-message-list.page` `x-989ef4722f` **Kein Neuladen beim Wiedereintritt** [src/app/settings/auto-messages/list/auto-message-list.page.ts:35](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/auto-messages/list/auto-message-list.page.ts#L35)
  Ionic: ionViewWillEnter lädt Regeln und "Letzte 7 Tage" bei jedem Zurückkehren/Tabwechsel neu / Flutter: Neuladen nur nach Speichern/Löschen/Umschalten (Invalidierung von autoMessageRulesProvider) oder Pull-to-Refresh; "Letzte 7 Tage" (autoMessageLastWeekProvider) bleibt bis zum Pull-to-Refresh unverändert.
  Flutter: lib/features/messages/presentation/pages/auto_message_list_page.dart:30, lib/core/providers/auto_message_providers.dart:54
- [ ] **niedrig** `settings/auto-messages/rule/auto-message-rule.page` `x-ef1ea07851` **Regel-ID nicht gefunden** [src/app/settings/auto-messages/rule/auto-message-rule.page.ts:51](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/auto-messages/rule/auto-message-rule.page.ts#L51)
  Ionic: getRule liefert null → Formular "Neue Regel" mit leerem Namen und tenantId 0 aus defaultAutoMessageRule(0); Speichern scheitert vermutlich (RLS) / Flutter: Formular "Neue Regel" mit leerem Namen und aktuellem Tenant; Speichern legt eine neue Regel an.
  Flutter: lib/features/messages/presentation/pages/auto_message_rule_page.dart:62, lib/features/messages/presentation/pages/auto_message_rule_page.dart:82, lib/data/repositories/auto_message_repository.dart:87
- [ ] **niedrig** `settings/files/files-move-modal/files-move-modal.component` `x-3718a3ace3` **Sortierung der Ordner im Baum** [src/app/settings/files/files-move-modal/files-move-modal.component.ts:172](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files-move-modal/files-move-modal.component.ts#L172)
  Ionic: a.name.localeCompare(b.name) (sprachabhängig, Umlaute/Groß-Klein einsortiert) / Flutter: a.name.compareTo(b.name) (Codepoint: Großbuchstaben vor Kleinbuchstaben, Umlaute hinter z).
  Flutter: lib/features/settings/presentation/widgets/files_move_modal.dart:103-104
- [ ] **niedrig** `settings/files/files.page` `x-0f583f0feb` **Ladeanzeige beim Ordnerwechsel** [src/app/settings/files/files.page.html:159-163](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/files/files.page.html#L159-L163)
  Ionic: während loadEntries ersetzt ein Spinner die Liste / Flutter: Spinner nur bei leerer Liste; beim Ordnerwechsel bleibt die alte Liste sichtbar (Breadcrumb zeigt schon den neuen Ordner), bis die neue geladen ist.
  Flutter: lib/features/settings/presentation/pages/files_page.dart:1257-1260
- [ ] **niedrig** `settings/help/content/index` `x-ed039cfb84` **Hilfeartikel songs-add bewusst abweichend** [src/app/settings/help/content/articles/songs.articles.ts:11](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/help/content/articles/songs.articles.ts#L11)
  Ionic: "Tippst du auf eine Datei und dann auf \"Datei öffnen\", öffnet sie sich in einem neuen Tab. Nutzt du Attendix als installierte Web-App …, zeigt Attendix PDFs und Bilder direkt in der App an." / Flutter: "… zeigt Attendix PDFs und Bilder direkt in der App an. Andere Dateien öffnen sich in einem neuen Tab bzw. in der passenden App." (Override OVERRIDES_DE/EN in tool/help/build_help.mjs, beschreibt das Flutter-Verhalten).
  Flutter: lib/features/help/data/help_content.dart:268, lib/features/help/data/help_content_en.dart:162
- [ ] **niedrig** `settings/voice-leader/voice-leader.page` `x-9036fc723e` **Archivierte Termine bei Abwesenheiten** [src/app/services/db.service.ts:2721](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/services/db.service.ts#L2721)
  Ionic: getPersonAttendances blendet archivierte Termine für Rollen außer Admin/Verantwortlicher aus (Stimmführer sehen sie nicht) / Flutter: Abfrage lädt archived nicht und filtert nicht. Praktisch ohne Wirkung, da nur vergangene Termine archiviert werden können und die Seite nur Termine ab heute zeigt.
  Flutter: lib/data/repositories/attendance_repository.dart:357
- [ ] **niedrig** `settings/general/type/type.page` `x-4296344228` **Agenda-Marker-Zeit nicht auf 0 gesetzt** [src/app/settings/general/type/type.page.ts:117](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L117)
  Ionic: ngOnInit setzt time des Tagesordnungs-Markers auf '0' (ältere Pläne speicherten 30 min) und speichert es so / Flutter: übernimmt die gespeicherte Zeit unverändert, zeigt z.B. „30 Min.“ und zählt sie in „Gesamt“.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1228-1235
- [ ] **niedrig** `settings/general/type/type.page` `x-698d8902b1` **Speichern schreibt null statt leerer Werte** [src/app/settings/general/type/type.page.ts:195](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L195)
  Ionic: schreibt das ganze Typ-Objekt – reminders [], checklist [] (wenn aktiviert), planning_title '', end_time/duration_days unverändert / Flutter: reminders null wenn leer, checklist null wenn leer, planning_title null wenn leer, end_time null bei ganztägig, duration_days null bei nicht ganztägig.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:1474-1496
- [ ] **niedrig** `settings/general/type/type.page` `x-79fd46d253` **Änderungserkennung und Speichern-FAB** [src/app/settings/general/type/type.page.ts:131](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.ts#L131)
  Ionic: hasUnsavedChanges per JSON-Vergleich mit dem Ladezustand, Speichern-FAB immer aktiv / Flutter: Flag bei jeder Eingabe (Hin- und Zurückschalten zählt als Änderung → Rückfrage), Speichern-FAB ohne Änderung deaktiviert.
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:239, lib/features/settings/presentation/pages/attendance_type_edit_page.dart:245
- [ ] **niedrig** `settings/general/type/type.page` `x-fdbae2f115` **Nutzungshinweis nur in Flutter** [src/app/settings/general/type/type.page.html:26](https://github.com/FECGSpeyer/attendance/blob/1923d203/src/app/settings/general/type/type.page.html#L26)
  Ionic: kein Hinweis / Flutter: Karte oben „Wird in {count} Termin(en) verwendet. Änderungen wirken sich auf bestehende Einträge aus.“ (zusätzliche Abfrage der Termine des Typs).
  Flutter: lib/features/settings/presentation/pages/attendance_type_edit_page.dart:251-271
