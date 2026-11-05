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
Punkte, ohne die 10 offenen hoch/mittel-Abweichungen (die liegen ohnehin in
Fix-PRs). Keine `niedrig`-Abweichung wird mehr ausgelassen.

| Gruppe | Inhalt | Punkte | Modell |
|---|---|---|---|
| `opus` | Rollen-, DB-, Logik-, Routen-, Nativ- und Navigationsbezug, ungeprüfte Fixes, Zusatzbefund | 1.200 | Opus |
| `sonnet` | übrige Elemente (Texte, Felder, Aktionen, Dialoge, Toasts …) | 1.944 | Sonnet |

Jedes Paket `input/<name>.json` wird nach `tool/parity/verify-brief.md`
geprüft; das Ergebnis kommt nach `docs/parity/status/<name>.json`
(`"ionic": "1923d203"`, `"flutter": "0f74333"`).
