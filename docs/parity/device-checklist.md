# Gerätetest-Liste (nur nativ prüfbar)

Stand Ionic 4.19.9 (1923d203). Abgeleitet aus den `native`-, `effect`- und
`media`-Punkten der Soll-Liste (`ionic-inventory.json`), den offenen
Gerätebefunden in `summary.md` und `fixes/*.md` (besonders `fixes/nativ.md`,
`fixes/querschnitt.md`) und der nativen Projektkonfiguration (`android/`,
`ios/` beider Apps).

Ziel: Leon prüft vor dem Store-Wechsel (Flutter ersetzt Ionic als
`io.stephanus.attendix` 5.0.0) in einem Durchgang alles, was nur auf echten
Geräten prüfbar ist. Jeder Punkt wird erst in der Ionic-App, dann in der
Flutter-App geprüft. Ein Ergebnis wird über die ID in Klammern zurück in den
Tracker getragen.

Testgruppe: „Attendix Test“. Konten: `leonjaeger00+attx-<rolle>@gmail.com`
(`<rolle>` = `admin`, `verantwortlich`, `beobachter`, `helfer`, `stimmfuehrer`,
`stimmhelfer`, `spieler`, `eltern`, `bewerber`). Das Passwort steht nicht
in dieser Datei. Es kommt nur über die Umgebungsvariable `ATTX_PASSWORD`.

Legende: ☐ offen · ✓ gleich · ✗ abweichend (Notiz dazu) · – nicht zutreffend

IDs in Klammern: Befund-ID (`x-…`) oder Element-ID aus der Soll-Liste ohne
Bausteinnamen (zum Beispiel `native-7521b3d9`, vollständig
`services/push/push.service#native-7521b3d9`). Spalte „Web“ meint die PWA im
Browser, ausgeführt auf dem Handy oder am Rechner.

## Vor dem Upload

Diese Punkte entscheiden, ob Play und App Store den Build überhaupt annehmen.

- ☐ Android: mit `scripts/store_build.sh appbundle` bauen. Das ist ein Shorebird-Release (sonst kommen keine OTA-Patches an, siehe `docs/release/shorebird.md`) und setzt `versionName` = 5.0.0 und `versionCode` = pubspec-Build + 100 (bricht ab, wenn ≤ Ionic 230). Nach dem Build in „App-Info“ bzw. in der Play Console prüfen. (x-4beeb3b857, x-6fc37335ce)
- ☐ iOS: mit `scripts/store_build.sh ipa` bauen (Shorebird-Release), **kein** Xcode-Archiv für den Store, das wäre ohne Shorebird. In App Store Connect Version 5.0.0 und Build ≥ 241 prüfen (Ionic 4.19.9 steht bei 239). (x-cb1c5c9d93, x-6fc37335ce)
- ☐ Der erste Store-Build mit `scripts/store_build.sh ipa` und `appbundle` läuft ohne Compile-Fehler: Swift und Kotlin aus PR #358 (Ionic-Offline-Warteschlange) wurden in der CI nicht gebaut. (x-6d9a24bfe2)
- ☐ Die Versionsanzeige in der App (Einstellungen-Badge, Anmeldeseite) zeigt dieselbe Version wie der Store. Sie kommt aus `AppConstants.displayVersion`, nicht aus dem Build-Flag. (x-4beeb3b857)
- ☐ Bundle-ID `io.stephanus.attendix` auf iOS und Android, iOS-Team `MXM3YWAKPL`. Die `apple-app-site-association` darf nicht nach dem veralteten Kommentar in `Runner.entitlements` geändert werden. (x-49efd91be0)
- ☐ Android: Release-Bundle (nicht Debug) meldet sich an und lädt Daten. `INTERNET` steht im Release-Manifest nur über Plugin-Manifeste. (x-5da3efae62)
- ☐ Android: `minSdk` ≥ 24, `compileSdk` ≥ 36, `targetSdk` ≥ 36 im gebauten Bundle. (x-83706089fb)

## Start, Anmeldung, Update

| # | Prüfung | iPhone | iPad | Android | Web |
|---|---|---|---|---|---|
| 1 | Ionic-App installiert, angemeldet, Gruppe gewählt. Store-Update auf 5.0.0 einspielen. Ionic: bleibt angemeldet, kein erneutes Anmelden, gleiche Gruppe (x-6d9a24bfe2, PR #285) | ☐ | ☐ | ☐ | – |
| 2 | Nach dem Update: Sortierung und Ansichtsoptionen (Personen, Werke, Termine) stehen auf Standard (werden bewusst nicht übernommen, niedrig), einmal neu einstellen bleibt erhalten (x-6d9a24bfe2) | ☐ | ☐ | ☐ | – |
| 3 | Dasselbe Konto auf zwei Geräten mit verschiedenen Gruppen. App neu starten. Ionic: jedes Gerät öffnet seine eigene Gruppe (x-48f72edd36) | ☐ | ☐ | ☐ | ☐ |
| 4 | App-Name „Attendix“ (groß geschrieben) unter dem Icon, im App-Drawer, in der Benachrichtigungs-Kopfzeile und in Berechtigungsdialogen (x-c131a10604) | ☐ | ☐ | ☐ | – |
| 5 | Icon auf dem Homescreen: gleiche Größe und Farbe des Logos wie Ionic, auch als rundes Icon (Android 7.1) und adaptives Icon (x-bc26763c9d, x-a1c35481e4, x-2f444d5285, x-02f00abb78) | ☐ | ☐ | ☐ | – |
| 6 | Kaltstart im hellen und im dunklen Modus. Ionic: Logo auf Weiß bzw. Dunkelgrau, kein weißer Blitz (x-faf61c6382, x-876683295e). Statusleiste lesbar | ☐ | ☐ | ☐ | – |
| 7 | iOS: App-Icon wechseln (Einstellungen). Ionic hat nur ein Icon, Flutter bietet vier. Systemhinweis erscheint, Icon wechselt (x-5df7b898da) | ☐ | ☐ | – | – |
| 8 | iOS: Kopieren/Einsetzen-Menü und Picker-Knöpfe in der App sind deutsch (Ionic englisch) (x-9900bda82b) | ☐ | ☐ | – | – |
| 9 | Hinweis auf neue Store-Version erscheint, wenn eine neuere Version im Store liegt. Ionic nutzt Live-Updates ohne Store-Release, die entfallen (x-ab62bd7676, native-8495540e) | ☐ | ☐ | ☐ | – |
| 10 | Einstellungen › „Im App Store/Play Store öffnen“ öffnet die richtige Store-Seite (effect-eea7b9c6). Im mobilen Browser: Falls der Hinweis auf die native App erscheint, öffnet er den Store-Link (effect-330e1045) | ☐ | ☐ | ☐ | ☐ |
| 11 | Android-Zurück-Taste bzw. iOS-Wischgeste: schließt erst Dialog oder Sheet, dann eine Seite zurück, auf der Startseite verlässt die Taste die App. Ionic `App.exitApp` (native-a707e12b) | – | – | ☐ | – |
| 12 | Einstellungen › Typ, Rollenrechte, Instanz bearbeiten: etwas ändern, dann Systemzurück bzw. Wischgeste. Ionic verlässt ohne Rückfrage, Flutter fragt nach (Flutter besser, Leon entscheidet) (x-0f8c22baa3, x-91589b8337, x-104b424f87) | ☐ | ☐ | ☐ | – |
| 13 | Werke-Import läuft: Android-Zurück bzw. Wischgeste. Ionic sperrt die ganze Seite. Flutter darf den Import nicht ohne Ergebnis abbrechen (loading-656de8cd) | ☐ | ☐ | ☐ | – |
| 14 | Protokoll über Push öffnen, dann Zurück. Ionic: Leitung landet im Termin, Mitglieder in Teamorganisation › Protokolle (action-48d91b74) | ☐ | ☐ | ☐ | – |
| 15 | Tastatur: Eingabefeld bleibt sichtbar, „Fertig“ schließt, Antippen außerhalb schließt. Auf Android mit Gestennavigation und mit Dreitasten-Navigation | ☐ | ☐ | ☐ | ☐ |
| 16 | Abmeldung mit „Sonstiger Grund“: Die Tastatur öffnet. Ionic scrollt das Feld in Sicht, öffnet die Tastatur aber erst beim Antippen (native-c4a31197, field-432c437c) | ☐ | ☐ | ☐ | ☐ |
| 17 | Systemschrift auf „sehr groß“ stellen, App öffnen und Formular ausfüllen: Layout bricht nicht und die Seite startet bei Änderung der Schriftgröße nicht neu (x-17b8eb5c2b) | ☐ | ☐ | ☐ | – |

## Push und Live Activity

| # | Prüfung | iPhone | iPad | Android | Web |
|---|---|---|---|---|---|
| 18 | Neu installiert, anmelden. Ionic: Dialog „Push-Benachrichtigungen“, „Aktivieren“ zeigt die Systemabfrage, danach Token in `device_tokens`. Auf Android 13+ muss die Abfrage `POST_NOTIFICATIONS` erscheinen (native-7521b3d9, alert-a499f987, native-c30ca494) | ☐ | ☐ | ☐ | – |
| 19 | Benachrichtigungen › Push einschalten ohne erteilte Berechtigung. Ionic: Systemabfrage erscheint, Token wird gespeichert (native-9bb3502f, native-c30ca494) | ☐ | ☐ | ☐ | – |
| 20 | Im Push-Dialog „Später“ wählen, danach außerhalb tippen oder Zurück drücken, App neu starten. Ionic: gilt als „Später“, keine erneute Frage (alert-a499f987) | ☐ | ☐ | ☐ | – |
| 21 | Nach dem Update aus Ionic: erteilte oder abgelehnte Systemberechtigung bleibt erhalten, nur wer „Später“ gewählt hatte, wird erneut gefragt (x-6d9a24bfe2) | ☐ | ☐ | ☐ | – |
| 22 | Push empfangen (Erinnerung, Nachricht, Dienst) bei geschlossener App und im Hintergrund, mit Ton und Badge | ☐ | ☐ | ☐ | – |
| 23 | Push bei offener App. Ionic iOS: Systembanner, Ton, Badge und In-App-Hinweis, Eintrag in der Mitteilungszentrale. Android: nur In-App-Hinweis (x-8e475b1344, native-eaa8c988) | ☐ | ☐ | ☐ | – |
| 24 | Android: Push bei App im Hintergrund. Ionic zeigt ihn still in der Leiste, Flutter als Heads-up-Banner (Entscheidung Leon) (x-8140fe9e0d) | – | – | ☐ | – |
| 25 | Android: App-Einstellungen › Benachrichtigungen. Keine doppelten alten englischen Kanäle („Push Notifications Foreground“), eine frühere Stummschaltung bleibt wirksam (x-409941f468) | – | – | ☐ | – |
| 26 | Push antippen öffnet die richtige Seite (Termin, Nachricht, Aufgabe, Protokoll), jeweils bei App im Hintergrund und bei beendeter App (native-eaa8c988, native-d16c5044) | ☐ | ☐ | ☐ | – |
| 27 | Badge wird beim Öffnen und beim Antippen eines Pushs gelöscht (native-bb512112) | ☐ | ☐ | – | – |
| 28 | Abmelden löscht den Push-Token. Danach kommt kein Push mehr auf dieses Gerät (native-11e34032) | ☐ | ☐ | ☐ | – |
| 29 | Live Activity (iPhone, iPad) bzw. laufende Benachrichtigung (Android) für einen Ablaufplan am Termintag: Start, Aktualisierung bei Wechsel des Programmpunkts, Ende (native-aeb702b8, native-0534809b, native-09b70352) | ☐ | ☐ | ☐ | – |
| 30 | iOS: Live Activity startet auch bei geschlossener App, Ionic hinterlegt dafür den Push-to-Start-Token (native-f31c300f, native-13900c1d) | ☐ | ☐ | – | – |
| 31 | Antippen von Live Activity bzw. Benachrichtigung öffnet den Plan. Ionic auch für einen Termin einer anderen Gruppe (modal-9b4e9fd5, native-f45e9256) | ☐ | ☐ | ☐ | – |
| 32 | Benachrichtigungen › Live-Aktivität ausschalten beendet laufende Aktivitäten sofort. App in den Hintergrund und zurück: Aktualisierung läuft weiter (native-c934f51c, native-3a9fbadc) | ☐ | ☐ | ☐ | – |
| 33 | Hinweistext zur Live-Aktivität. Ionic: iOS „…Sperrbildschirm und in der Dynamic Island“, Android nur „…Sperrbildschirm“ (field-05b9f833) | ☐ | ☐ | ☐ | – |
| 34 | Android mit Gerätesprache Englisch: Kanalname und Texte der laufenden Benachrichtigung sind in Ionic immer deutsch (x-b4cad26225) | – | – | ☐ | – |

## Links und Teilen

| # | Prüfung | iPhone | iPad | Android | Web |
|---|---|---|---|---|---|
| 35 | attendix.de-Link aus Mail/Telegram öffnet die App auf der richtigen Seite (Universal/App Links). Auch bei laufender App in dieselbe Instanz (native-f45e9256, x-49efd91be0) | ☐ | ☐ | ☐ | – |
| 36 | Android: Link in Gmail, WhatsApp und SMS antippen (App war beendet und im Hintergrund), danach das Homescreen-Icon tippen. Kein leerer Bildschirm. Beide nutzen `singleTask` (seit PR #285) (x-3340d46ef9) | – | – | ☐ | – |
| 37 | Passwort-zurücksetzen- und Bestätigungslink aus der Mail funktioniert, auch auf einem anderen Gerät als dem, das ihn angefordert hat | ☐ | ☐ | ☐ | ☐ |
| 38 | Ablaufplan-Link teilen. Ionic öffnet das System-Teilen-Menü (auch iPad als Popover), sonst Zwischenablage. Flutter fällt auf dem iPad auf „Link kopiert“ zurück (effect-cc0f301b, effect-af3bb049, effect-9082e8f4) | ☐ | ☐ | ☐ | ☐ |
| 39 | Werk-Datei oder ZIP teilen bzw. herunterladen. Auf dem iPad darf kein Fehler erscheinen (share_plus ohne `sharePositionOrigin`) (x-562b23ba0c, effect-8cf392b2) | ☐ | ☐ | ☐ | ☐ |
| 40 | Personen-Import-Vorlage herunterladen. Ionic iPad: Datei im Systemviewer. Flutter darf nicht „Fehler: …“ zeigen (effect-31a0aedd, effect-cdbbd276) | ☐ | ☐ | ☐ | ☐ |
| 41 | Dateiablage: Datei-Link teilen. Ionic öffnet das Teilen-Menü, sonst Zwischenablage (effect-c39ff4df, effect-c48b9ee3) | ☐ | ☐ | ☐ | ☐ |
| 42 | Link kopieren: Kalender-Abo-Link und öffentlicher Plan-Link landen in der Zwischenablage, Toast „Link kopiert“ (effect-c4281c2a, effect-35b5f6e6, effect-bb4d0f68) | ☐ | ☐ | ☐ | ☐ |
| 43 | Externe Links (Nachrichten-Link, Werk-Link, Anhang, Telegram) öffnen im In-App-Browser, im Web in einem neuen Tab (native-886951c6, native-51a26cad, native-d6a03777, native-1f2aa2b5, effect-3284e3a8) | ☐ | ☐ | ☐ | ☐ |
| 44 | Telegram verbinden (Benachrichtigungen) und Telegram-Support (Einstellungen) öffnen `t.me`, mit Telegram-App, wenn installiert (native-1f2aa2b5, native-ba3cad21) | ☐ | ☐ | ☐ | ☐ |
| 45 | Adresse im Termin antippen (Termin, „Meine Termine“, Abmelde-Seite, Eltern) öffnet die Karten-App (effect-70a83fa3, effect-209410e2, effect-11be3cc2, effect-d259dd3f, effect-c9b53196) | ☐ | ☐ | ☐ | ☐ |
| 46 | Telefonnummer und E-Mail-Adresse antippen öffnet Telefon bzw. Mail | ☐ | ☐ | ☐ | ☐ |
| 47 | Kalender abonnieren (webcal): Link kopieren, im Kalender einfügen. „Anleitung öffnen“ führt auf iOS zur Apple-Hilfe, sonst zur Google-Hilfe. Auf der öffentlichen Org-Plan-Seite fehlt der Knopf in Flutter (alert-c3af9876, native-c9096ded, native-1a59de28, native-d27820c1) | ☐ | ☐ | ☐ | ☐ |

## Dateien, Drucken, Medien

| # | Prüfung | iPhone | iPad | Android | Web |
|---|---|---|---|---|---|
| 48 | Export Excel (Spielerliste, Anwesenheit) wird gespeichert und geöffnet. Ionic nativ: Cache + Systemviewer, mobiler Browser: Teilen-Menü, Desktop: Download (effect-6347ac25, effect-7662bf5a, effect-ac49a0f3) | ☐ | ☐ | ☐ | ☐ |
| 49 | Export PDF (Spielerliste, Anwesenheit, Werkeliste, Protokoll, Ablaufplan, Vorkurs-Zeugnisse) wird gespeichert und geöffnet (effect-b5cfc616, effect-b206f4b4, effect-97c69a71, effect-9302ed46, effect-d8aa5cb2, effect-c485f21b) | ☐ | ☐ | ☐ | ☐ |
| 50 | Plan-PDF mit kyrillischem Namen, „ “, – und €: alle Zeichen gedruckt, keine Platzhalter (x-5195e84084) | ☐ | ☐ | ☐ | ☐ |
| 51 | Noten/Datei öffnen (Werk, Werkeliste). Ionic: System-Dateiviewer, im Web neuer Tab. Flutter öffnet PDFs und Bilder im In-App-Viewer (effect-be55c6e1, effect-d5df5767, effect-14d924bb) | ☐ | ☐ | ☐ | ☐ |
| 52 | Noten herunterladen (einzeln, mehrere Stimmen, ZIP). Ionic iOS blendet den Knopf aus, Web-App lädt per Teilen-Menü, Flutter-PWA per Download (effect-a62dbd79, effect-8a9efedf, effect-8cf392b2) | ☐ | ☐ | ☐ | ☐ |
| 53 | Drucken (Plan, Noten) über den System-Druckdialog. Mobiles Web: Ionic Teilen-Menü bzw. Download, Flutter öffnet die PDF in neuem Tab (native-b17912ff, native-534b5f7a, effect-e0430543, effect-e0430543-2) | ☐ | ☐ | ☐ | ☐ |
| 54 | Profilbild in „Meine Daten“ und bei einer Person setzen. Ionic bietet Mediathek, Foto aufnehmen und Datei, Flutter nur Galerie (field-f65b81d3, field-a9ab8c88) | ☐ | ☐ | ☐ | ☐ |
| 55 | Foto mit Kamera zu einem Termin hinzufügen. Kamera-Berechtigungsdialog mit passendem Text. Im Store-Eintrag steht neu die Berechtigung `CAMERA` (x-6afce27e8e, x-eaaab39ad0) | ☐ | ☐ | ☐ | – |
| 56 | Bild über 2 MB wählen. Ionic lehnt ab („Das Bild darf maximal 2MB groß sein.“), Flutter verkleinert und lädt hoch (toast-453ee9ac) | ☐ | ☐ | ☐ | ☐ |
| 57 | Datei-Upload in der Dateiablage und bei Werken, Fortschrittsbalken läuft (media-250650fa) | ☐ | ☐ | ☐ | ☐ |
| 58 | Audio-Player: Wiedergabe im Hintergrund, Steuerung auf dem Sperrbildschirm (Media Session). Android: Medientasten und Bluetooth setzen die Wiedergabe fort (x-839700db13) | ☐ | ☐ | ☐ | ☐ |
| 59 | iOS: Beim Wählen einer Audiodatei erscheint höchstens der Mediathek-Text, keine Mikrofonabfrage (x-f37b2c16d5) | ☐ | ☐ | – | – |
| 60 | Statistik und Dashboard: alle Diagramme erscheinen, Antippen zeigt Werte (media-ac43f03a, media-542fed8c, media-57ebfc11, media-315d630a, media-42266499, media-c58a7f02, media-9766bdb9, media-50089e70) | ☐ | ☐ | ☐ | ☐ |
| 61 | Bilder laden: Teilnehmerbild im Dienst, Gruppen-Logo in der Seitenleiste, Logo auf der Anmeldeseite (media-5cb3848f, media-8fae1184, media-5a220f2e) | ☐ | ☐ | ☐ | ☐ |
| 62 | Haptik beim Setzen des Anwesenheitsstatus (leicht), beim Pausieren (leicht) und beim Löschen in Terminliste, Verlauf, Personenliste (mittel). Im Web kein Fehler (native-7fcba5d1, native-fae6edc2, native-e5abdba5, native-74e8de75, native-79bc7764) | ☐ | ☐ | ☐ | – |

## Offline

| # | Prüfung | iPhone | iPad | Android | Web |
|---|---|---|---|---|---|
| 63 | Flugmodus an, Termin öffnen und Status setzen. Flugmodus aus: Änderung wird gespeichert (Ionic `Network`, Offline-Warteschlange) (native-584a56f5, native-77b25811, native-66b35f3e) | ☐ | ☐ | ☐ | ☐ |
| 64 | Termin offen, WLAN zu Mobilfunk wechseln. Kein falscher Offline-Hinweis, nichts geht verloren (native-7db6296b, native-1dcfca94) | ☐ | ☐ | ☐ | – |
| 65 | Flugmodus an: Personen, Werke, Gruppen und Termine zeigen die zuletzt geladenen Daten (native-20d780b6, native-2dd86017, native-d88b5602, native-81587c7a) | ☐ | ☐ | ☐ | ☐ |
| 66 | In Ionic offline einen Status setzen, App schließen, nicht synchronisieren. Dann auf 5.0.0 updaten und online starten: die Änderung kommt genau einmal an, zwei Änderungen an derselben Person ergeben den letzten Stand, Daten anderer Konten bleiben unberührt (x-6d9a24bfe2, PR #358) | ☐ | ☐ | ☐ | – |
| 67 | Offline Status setzen, abmelden, mit anderem Konto anmelden, online gehen. Flutter hängt die Warteschlange an den Benutzer, Ionic nicht (Flutter besser) (x-138490bdaf) | ☐ | ☐ | ☐ | ☐ |

## Konto

| # | Prüfung | iPhone | iPad | Android | Web |
|---|---|---|---|---|---|
| 68 | Konto löschen (Einstellungen) inkl. Bestätigung. Nur mit einem Wegwerf-Konto | ☐ | ☐ | ☐ | ☐ |
| 69 | Abmelden und mit Anmelde-Code per E-Mail wieder anmelden. Der Code kommt per E-Mail an und die Anmeldung gelingt wie in Ionic | ☐ | ☐ | ☐ | ☐ |
| 70 | Gruppe wechseln bei mehreren Gruppen. Ionic zeigt kurz ein Lade-Overlay und öffnet die Startseite der Rolle. Bei nur einer Gruppe zeigt Ionic trotzdem den Knopf (effect-bbc763c2, loading-a2fa55fe, action-f029eaa1) | ☐ | ☐ | ☐ | ☐ |
| 71 | Eine Gruppe löschen (Wegwerf-Gruppe). Ionic lädt danach die Instanz neu und öffnet die Startseite der Rolle, Flutter bleibt auf der Seite (nav-51ad9728, effect-3e8f334d) | ☐ | ☐ | ☐ | ☐ |

## Ergebnisse zurück in den Tracker

1. Abweichung in der Zeile mit ✗ markieren und eine Notiz anhängen (Gerät, Android-/iOS-Version, was zu sehen war).
2. Die IDs in Klammern in `docs/parity/tracker/` über die Entscheidung der Abweichung eintragen. „Flutter besser“ entscheidet Leon.
3. Bestätigte Fixes kommen nach `docs/parity/status/zz-fixed-<bereich>.json` mit `afterRound`, damit die nächste Gegenprüfung sie erfasst.
