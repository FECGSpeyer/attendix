# Parität Ionic → Flutter

Ziel: Bevor die Flutter-App die Ionic-App im Store ersetzt (5.0.0), ist für
jedes Element der Ionic-App nachgewiesen, dass es im **normalen Design** der
Flutter-App gleich vorhanden ist, oder Leon hat die Abweichung abgenommen.
Beta-Seiten zählen nicht.

## Bausteine

| Schritt | Werkzeug | Ergebnis |
|---|---|---|
| 1. Soll-Liste | `tool/parity/extract_ionic.mjs` | `ionic-inventory.json` |
| 2. Prüfpakete | `tool/parity/parity.mjs batches` | `batches.json` |
| 3. Nachweis je Punkt | Review nach `tool/parity/review-brief.md` | `status/<paket>.json` |
| 4. Gegenprüfung | `parity.mjs verify-slices`, `verify-round <N>` + `tool/parity/verify-brief.md` | `status/zz-verify*-*.json` |
| 5. Bericht | `tool/parity/parity.mjs report` | `summary.md`, `tracker-data.json`, Tracker-Seite |
| 5b. Arbeitslisten | `tool/parity/parity.mjs fixlists` | `fixes/<bereich>.md` |
| 6. Bildvergleich | `tool/parity/screens/compare.mjs` (Mac) | Bildpaare je Rolle und Seite |
| 7. Gerätetests | `device-checklist.md` | von Hand auf iPhone/Android |

### 1. Soll-Liste aus dem Ionic-Code

```bash
cd tool/parity && npm ci && cd ../..
node tool/parity/extract_ionic.mjs <ionic-repo> --out docs/parity/ionic-inventory.json --flutter .
```

Das Skript liest den Quellcode (Angular-Templates mit dem Angular-Compiler,
TypeScript mit dem TypeScript-Compiler) und listet jedes Element mit stabiler
ID: Routen, Aktionen (alles Antippbare), Eingabefelder mit Optionen, Texte
und angezeigte Daten, eingebettete Komponenten, Alerts, Aktionsblätter,
Modals, Toasts, Ladeanzeigen, Navigation, jeden Datenbankzugriff (Tabelle,
Operation, Spalten, Filter, RPC, Edge Function, Storage), native Aufrufe und
je Klasse die Liste aller Methoden (`logic`). Zu jedem Element stehen die
Sichtbarkeitsbedingungen (`@if`, `*ngIf`, `@for`, `@switch`), die deutschen
Texte und wo der normale Flutter-Code denselben Übersetzungsschlüssel nutzt.

Eine Zeile je Element: Ein `git diff` nach einem neuen Lauf zeigt genau, was
sich in Ionic geändert hat. `node tool/parity/parity.mjs diff <alt.json>`
listet neue, entfernte und **geänderte** Elemente (gleiche ID, aber anderer
Inhalt: Texte, Bedingungen, Bindungen, DB-Spalten und -Filter, Methodenrümpfe
als Hash) sowie geänderte Übersetzungen. Felder, die erst ein neuerer
Extraktor liefert, zählen nicht als Änderung (Vergleich nur über die Felder,
die die alte Liste je Art kennt; Reihenfolge der Felder egal). Mit `--stale`
kommt ein Schritt `{from, to, ids}` in das fortlaufende Änderungsprotokoll
`changes.json`: Ein Urteil, das an einer Ionic-Version vor einem Schritt
gefällt wurde, der sein Element nennt, gilt nicht mehr, und das Element
steht wieder als offen im Bericht; das gilt über beliebig viele
Ionic-Versionen hinweg. Zusätzliche Befunde und ihre Rücknahmen auf einer
seither geänderten Seite werden wieder geöffnet und als „Ionic geändert“
markiert. Bilder (`media`) und alle gebundenen Attribute (`bindings`, z. B.
`[src]`, `[buttons]`) sind Teil der Soll-Liste. Datenbankaufrufe, deren
Tabelle oder Operation nicht auflösbar ist, tragen `unresolved` und gelten
nie als `ok` (Bericht: `unclear`).

### 3. Nachweis je Punkt

Jedes Paket wird nach `tool/parity/review-brief.md` geprüft. Für jedes
Element entsteht ein Eintrag mit Status (`ok`, `diff`, `missing`, `na`,
`unclear`), Flutter-Fundstelle (Datei:Zeile), Notiz und Schwere (`hoch`,
`mittel`, `niedrig`). Abweichungen außerhalb der Elemente (Logik, Sortierung,
Berechnungen) stehen unter `extra`.

### 4. Gegenprüfung

`node tool/parity/parity.mjs verify-slices <dir> [n] [pakete]` zieht je
fertigem Paket die Stichprobe für einen zweiten, unabhängigen Durchgang nach
`tool/parity/verify-brief.md`: jeder Datenbank-Schreibzugriff, jedes
`missing`/`unclear`, jedes `diff` mit Schwere hoch/mittel, 20 % der
`niedrig`-Abweichungen, 10 % der `na` und 5 % der `ok`. Die Auswahl hängt nur
an der Element-ID (Hash) und ist damit wiederholbar. Die Ergebnisse heißen
`zz-verify-*.json`, tragen `v: bestätigt|korrigiert` und überschreiben beim
Bericht die Erstbewertung. Zusätzliche Befunde, die sich als Duplikat oder
widerlegt herausstellen, werden in `zz-zz-overrides.json` (`extraOverride`)
zurückgenommen oder umgestuft.

Weitere Runden (`parity.mjs verify-round <N> <dir> [n] [--since <alt.json>]`,
Ergebnisse `zz-verify<N>-*.json`), vollständig statt Stichprobe: jedes neue
Element und jedes seit `--since` geänderte, jede hoch/mittel-Abweichung ohne
zweite Prüfung, jeder zusätzliche Befund mit Schwere hoch/mittel ohne
zweites Urteil oder auf einer seither geänderten Ionic-Seite, jeder nicht
auflösbare Datenbankaufruf und jedes `ok`/`na`, das von Rolle oder
Mandanten-Einstellung abhängt: Bedingung im Template, eine Klassen-Eigenschaft
oder -Methode, die Rolle oder Mandant liest (`unit.roleMembers`), oder eine
Rollenprüfung in der TypeScript-Methode um das Element (`roleGuarded`). Zusätzliche Befunde haben eine stabile ID
(`x-<sha1(Baustein|Titel)>`); gleiche Befunde aus mehreren Dateien werden
zusammengeführt, und eine Prüfung schreibt ihr Urteil unter dieser ID
(`s` ok/na nimmt den Befund zurück).

Lesereihenfolge der Urteile: Erstprüfung (`b*`), dann die Runden
(`zz-verify-*` = 1, `zz-verifyN-*` = N), Korrekturdateien nach der Runde in
ihrem Feld `afterRound`, zuletzt `zz-fixed-*`. Ein späteres Urteil mit Status
ersetzt das frühere ganz (Fundstelle und Notiz bleiben nur, wenn der Status
gleich bleibt und keine neuen kommen).

### 4b. Behobene Punkte

Ein Fix-PR trägt behobene Punkte in `status/zz-fixed-<bereich>.json` ein
(Element-ID oder Befund-ID `x-…` mit `s: "ok"` und Verweis auf den PR). Diese
Dateien werden immer zuletzt gelesen und gelten damit vor jedem früheren
Urteil.

### 5. Bericht, Tracker und Arbeitslisten

`node tool/parity/parity.mjs report` schreibt `summary.md` und die kompakte
`tracker-data.json` (nicht versioniert, wird mit veröffentlicht) für die Tracker-Seite (`tracker/index.html`, als
Artifact veröffentlicht; dort entscheidet Leon je Abweichung „Angleichen“,
„So lassen“ oder „Später klären“). `node tool/parity/parity.mjs fixlists`
schreibt je Bereich eine Arbeitsliste `fixes/<bereich>.md`: hoch/mittel zum
Angleichen, „Flutter besser“-Fälle zur Entscheidung, Kleinigkeiten.

### 6. Bildvergleich (auf dem Mac)

```bash
cd tool/parity/screens && npm install
ATTX_PASSWORD=… node compare.mjs --env ../../../.env.app --out ~/privateRepos/parity-shots
```

Meldet sich mit den Testkonten (`leonjaeger00+attx-<rolle>@gmail.com`,
Gruppe „Attendix Test“) in beiden Web-Apps an, öffnet jede Route der
Soll-Liste im iPhone-Look und am Desktop und speichert Bildpaare plus
`index.html`. Abweichende Ziel-URLs (andere Weiterleitung/Rechte) sind rot
markiert. Nur lesend.
