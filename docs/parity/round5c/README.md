# Runde 5c (Nachprüfung nach dem Sol-Review)

Das Sol-Review 6663947239 zu Runde 5 hat gezeigt, dass die zeilengenaue
Flutter-Änderungsprüfung (`181f8a3`) für Aktionen, Felder, Dialoge und Toasts
zu eng war: Eine geänderte Rollenberechnung außerhalb ± 10 Zeilen blieb
unbemerkt, und unter den ausgelassenen `niedrig`-Abweichungen waren auch
funktionale (z. B. Dezimalzahl als Text gespeichert). Seitdem prüft
`parity.mjs` nur noch reine Texte und Medien ohne Bedingung zeilengenau und
markiert ungültige Fundstellen.

Auswahl: `node tool/parity/parity.mjs verify-round 5 <dir> --flutter <master 0f74333>`
gegen master `0f74333` (mit #332) und Ionic 4.19.9 (`1923d203`): 3.154
ausgewählte Punkte; davon sind die 10 offenen hoch/mittel-Abweichungen
ausgeschlossen (sie liegen ohnehin in Fix-PRs), geprüft wurden also 3.144.
Keine `niedrig`-Abweichung wird mehr ausgelassen.

| Gruppe | Inhalt | Punkte | Modell |
|---|---|---|---|
| `opus` | Rollen-, DB-, Logik-, Routen-, Nativ- und Navigationsbezug, ungeprüfte Fixes, Zusatzbefund | 1.200 | Opus |
| `sonnet` | übrige Elemente (Texte, Felder, Aktionen, Dialoge, Toasts …) | 1.944 | Sonnet |

Jedes Paket `input/<name>.json` wird nach `tool/parity/verify-brief.md`
geprüft; das Ergebnis liegt als Runde 6 in `docs/parity/status/zz-verify6-<gruppe>-<nr>.json`
(`"ionic": "1923d203"`, `"flutter": "0f74333"`). Als eigene Runde 6, weil
sie nach den Fix-Dateien mit `afterRound: 5` (Rang 5,6) zählen muss; ein Name
`zz-verify5c-*` würde vom Werkzeug nicht als Runde erkannt. Abgleich der
Schwere-Regeln in `status/zz-r6-korrekturen.json`. Fixes, die nach `0f74333`
gemergt werden, tragen `"afterRound": 6`.

## Ergebnis

50 neue hoch/mittel-Befunde aus den Ergebnisdateien; die Dublette
`x-c19db99cb7` ist zurückgezogen, es bleiben 49. Das Sol-Review 6665834233
hat zwei Fehlbestätigungen gefunden, die `zz-r6-korrekturen.json` korrigiert:
`services/db.service#db-1e5584c0` (Archivieren, gleicher Fehler wie
`people/list/list.page#modal-11a551b4`, hoch) und `services/db.service#db-50229123`
(Übersicht „Aktuelle Werke“, gleicher Fehler wie `x-7ff54f52b2`, mittel).
Die Fixes liegen in den Opus-PRs #342 bis #347.

## Prüfbasis

Die Prüfer hatten den Ionic-Code (FECGSpeyer/attendance @ `1923d203`) und
den Pub-Cache lokal; beides liegt bewusst nicht in diesem Repository
(`{IONIC}` und `{PUB_CACHE}` in `tool/parity/verify-brief.md` sind Platzhalter
für diese lokalen Pfade). Ein Review ohne Zugriff darauf kann nur die
Flutter-Seite eines Urteils nachvollziehen; die Ionic-Seite steht als
Zitat mit Datei:Zeile in jeder Notiz.
