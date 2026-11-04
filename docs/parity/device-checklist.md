# Gerätetest-Liste (nur nativ prüfbar)

Abgeleitet aus den `native`- und `effect`-Punkten der Soll-Liste
(`ionic-inventory.json`, Ionic 4.19.7) und der nativen Projektkonfiguration
(`android/`, `ios/` beider Apps). Jeder Punkt wird auf iPhone und Android
geprüft, jeweils erst in der Ionic-App, dann in der Flutter-App.
Testgruppe: „Attendix Test“, Konten `leonjaeger00+attx-<rolle>@gmail.com`.

Legende: ☐ offen · ✓ gleich · ✗ abweichend (Notiz dazu)

## Start, Anmeldung, Update

| # | Prüfung | iPhone | Android |
|---|---|---|---|
| 1 | Store-Update über installierte Ionic-App: kein erneutes Anmelden, gleiche Gruppe (PR #285) | ☐ | ☐ |
| 2 | App-Name „Attendix“, Icon, Startbildschirm, Statusleiste hell/dunkel | ☐ | ☐ |
| 3 | Android-Zurück-Taste: schließt Dialog/Sheet, dann Seite zurück, auf Startseite App verlassen (Ionic `App.exitApp`) | – | ☐ |
| 4 | Tastatur: Eingabefeld bleibt sichtbar, „Fertig“ schließt, Antippen außerhalb schließt | ☐ | ☐ |
| 5 | Hinweis auf neue Store-Version (Flutter) bzw. Live-Update (Ionic, entfällt in Flutter) | ☐ | ☐ |
| 6 | Offline: Termin öffnen und Status setzen ohne Netz, nach Wiederverbindung gespeichert (Ionic `Network`, Offline-Warteschlange) | ☐ | ☐ |

## Push und Live Activity

| # | Prüfung | iPhone | Android |
|---|---|---|---|
| 7 | Push-Berechtigung: Abfrage zum gleichen Zeitpunkt und mit gleichem Text | ☐ | ☐ |
| 8 | Push empfangen (Erinnerung, Nachricht, Dienst) mit Ton und Badge | ☐ | ☐ |
| 9 | Push antippen öffnet die richtige Seite (Termin, Nachricht, Aufgabe, Protokoll) | ☐ | ☐ |
| 10 | Badge wird beim Öffnen gelöscht | ☐ | ☐ |
| 11 | Abmelden löscht den Push-Token (keine Pushs mehr für dieses Gerät) | ☐ | ☐ |
| 12 | Live Activity (iPhone) bzw. laufende Benachrichtigung (Android) für den Ablaufplan: Start, Aktualisierung, Ende, Antippen öffnet den Plan | ☐ | ☐ |

## Links und Teilen

| # | Prüfung | iPhone | Android |
|---|---|---|---|
| 13 | attendix.de-Link aus Mail/Telegram öffnet die App auf der richtigen Seite (Universal/App Links) | ☐ | ☐ |
| 14 | Passwort-zurücksetzen- und Bestätigungslink aus der Mail funktioniert (auch auf einem anderen Gerät) | ☐ | ☐ |
| 15 | Teilen (Plan, Datei, Werk-Link) öffnet das System-Teilen-Menü | ☐ | ☐ |
| 16 | Link kopieren (Plan, Kalender-Abo) landet in der Zwischenablage | ☐ | ☐ |
| 17 | Externe Links (Hilfe, Datenschutz, Nachrichten-Links) öffnen im In-App-Browser | ☐ | ☐ |
| 18 | Adresse antippen öffnet die Navigation (Karten-App) | ☐ | ☐ |
| 19 | Telefon/Mail antippen öffnet Telefon bzw. Mail | ☐ | ☐ |
| 20 | Kalender abonnieren (webcal) | ☐ | ☐ |

## Dateien, Drucken, Medien

| # | Prüfung | iPhone | Android |
|---|---|---|---|
| 21 | Export PDF/Excel (Termine, Personen, Plan, Protokoll) wird gespeichert und geöffnet | ☐ | ☐ |
| 22 | Noten/Datei öffnen (PDF-Viewer), mehrere Stimmen drucken | ☐ | ☐ |
| 23 | Drucken (Plan, Noten) über den System-Druckdialog | ☐ | ☐ |
| 24 | Passbild/Bild hinzufügen: Kamera und Mediathek | ☐ | ☐ |
| 25 | Datei-Upload in der Dateiablage und bei Werken | ☐ | ☐ |
| 26 | Audio-Player: Wiedergabe im Hintergrund, Steuerung auf dem Sperrbildschirm (Media Session) | ☐ | ☐ |
| 27 | Haptisches Feedback beim Setzen des Anwesenheitsstatus und beim Ziehen zum Aktualisieren | ☐ | ☐ |

## Konto

| # | Prüfung | iPhone | Android |
|---|---|---|---|
| 28 | Konto löschen (Einstellungen) inkl. Bestätigung | ☐ | ☐ |
| 29 | Abmelden und mit Anmelde-Code per E-Mail wieder anmelden | ☐ | ☐ |
| 30 | Gruppe wechseln bei mehreren Gruppen | ☐ | ☐ |
