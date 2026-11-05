# Runde 5 (Schlussrunde)

Gegen master 57bb011 (alle Paritäts-Fix-PRs gemergt) und Ionic 4.19.9
(1923d203). Auswahl: `node tool/parity/parity.mjs verify-round 5 <dir>`
(1.976 Punkte), daraus ohne die `niedrig`-Abweichungen, deren Flutter-Code
sich geändert hat (616, rein kosmetisch, nicht im Fix-Umfang), 1.360 Punkte
in 36 Paketen:

| Gruppe | Inhalt | Punkte | Modell |
|---|---|---|---|
| `a-opus` | ungeprüfte Fixes und offene hoch/mittel mit Rollen-, DB-, Logik-, Routen- oder Nativ-Bezug, Zusatzbefunde | 198 | Opus |
| `a-sonnet` | ungeprüfte Fixes einfacher Elemente (Text, Feld, Aktion, Dialog …) | 168 | Sonnet |
| `b-opus` | `ok`-Urteile mit geändertem Flutter-Code, Rollen-, DB-, Logik-, Routen- oder Nativ-Bezug | 539 | Opus |
| `b-sonnet` | `ok`-Urteile mit geänderten Flutter-Zeilen, einfache Elemente | 455 | Sonnet |

Jedes Paket `input/<name>.json` wird nach `tool/parity/verify-brief.md`
geprüft; das Ergebnis kommt nach `docs/parity/status/<name>.json`
(`"ionic": "1923d203"`, `"flutter": "57bb011"`).
