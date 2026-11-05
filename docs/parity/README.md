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
als Hash) sowie geänderte Übersetzungen. Verglichen werden je Art nur die
Felder, die beide Listen kennen: Felder, die ein neuerer Extraktor ergänzt,
entfernt oder umbenennt, zählen nicht als Änderung (Reihenfolge der Felder
egal; `attrs` und `bodies` werden als Ganzes verglichen, ihre Schlüssel sind
Daten). Die Methodennamen eines `logic`-Eintrags werden immer vollständig
verglichen, eine neue oder entfernte Methode ist also eine Änderung; die
Rumpf-Hashes zählen, wenn beide Listen `bodies` haben. Mit `--stale`
kommt ein Schritt `{from, to, ids}` in das fortlaufende Änderungsprotokoll
`changes.json`: Ein Urteil, das an einer Ionic-Version vor einem Schritt
gefällt wurde, der sein Element nennt, gilt nicht mehr, und das Element
steht wieder als offen im Bericht; das gilt über beliebig viele
Ionic-Versionen hinweg. Zusätzliche Befunde und ihre Rücknahmen auf einer
seither geänderten Seite werden wieder geöffnet und als „Ionic geändert“
markiert. Bilder (`media`) und alle gebundenen Attribute (`bindings`, z. B.
`[src]`, `[buttons]`) sind Teil der Soll-Liste; bei eingebetteten
Komponenten (`embed`) stehen die Ausdrücke der Eingaben in `bindingExprs`
(`[editable]="isAdmin"`), so dass ein Wechsel des Ausdrucks auffällt.
Datenbankaufrufe, deren
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
auflösbare Datenbankaufruf, jeder behobene Punkt, den seit dem Fix keine
Runde gesehen hat (`behoben-ungeprueft`, siehe 4b), und jedes `ok`/`na`, das
von Rolle oder Mandanten-Einstellung abhängt (`rolle-mandant`): Bedingung im
Template oder Ausdruck eines gebundenen Attributs (`[disabled]="readOnly"`,
`[isOpen]`, `[class.x]`, Eingaben in `bindings`/`bindingExprs`; ohne
Text in Anführungszeichen) mit einem Rollen- oder Mandantennamen (dieselbe
Liste wie im Extraktor, `tool/parity/roles.mjs`, plus `readOnly`, `can…`,
`enable_…` u. a.) oder mit einer Klassen-Eigenschaft oder -Methode, die Rolle
oder Mandant liest (`unit.roleMembers`), eine Rollenprüfung in der
TypeScript-Methode um das Element (`roleGuarded`), oder ein Inline-Modal bzw.
-Popover, dessen Auslöser (setzt sein `[isOpen]` auf `true`, trägt die
`trigger`-ID oder ruft `<ref>.present()`) davon abhängt: Modal und Inhalt
erben den Bezug (`via: "ausloeser"` im Eintrag). Zusätzliche Befunde haben
eine stabile ID (`x-<sha1(Baustein|Titel)>`); eine Prüfung schreibt ihr
Urteil unter dieser ID (`s` ok/na nimmt den Befund zurück).

Zuletzt prüft `verify-round` per `git`, ob sich eine im Urteil referenzierte
Flutter-Datei (`f`, Zeilenangaben abgeschnitten) seit dem Flutter-Commit des
Urteils (`flutterAt`) bis `HEAD` geändert hat (geändert, umbenannt oder
gelöscht; ein `git diff --name-status` je Commit). Solche Elemente (jeder
Status, auch `ok`/`na`) und offene Zusatzbefunde kommen mit dem Grund
`flutter-geaendert` dazu, sofern kein anderer Grund greift; jeder
ausgewählte Eintrag nennt die geänderten Dateien in `flutterChanged`.
`--flutter <pfad>` wählt den Flutter-Checkout (Standard `.`),
`--no-flutter-check` schaltet die Prüfung ab. Commits, die der Checkout
nicht kennt, werden einmal gemeldet und nicht markiert. Grenze: Wandert das
Verhalten in eine Datei, die das Urteil nicht nennt (neues Widget, anderer
Provider), oder ändert sich nur eine von dort benutzte Datei, wird das nicht
erkannt.

Lesereihenfolge der Urteile (Rang): Erstprüfung (`b*`) 0, dann die Runden
(`zz-verify-*` = 1, `zz-verifyN-*` = N), Korrekturdateien mit `"afterRound": N`
N + 0,5, behobene Punkte `zz-fixed-*` N + 0,6 (siehe 4b); bei gleichem Rang
nach Dateinamen. Dabei gilt:

- Ein späteres Urteil **mit** Status `s` ersetzt das frühere ganz
  (Fundstelle und Notiz bleiben nur, wenn der Status gleich bleibt und keine
  neuen kommen) und setzt den Prüfstand neu: Ionic- und Flutter-Commit der
  Datei. Das gilt auch für Zusatzbefunde unter ihrer `x-`-ID.
- Ein Nachtrag **ohne** `s` (nur `sev`, `n`, `f`, `v`) ändert nur diese
  Felder: Status, Prüfstand und eine Rücknahme bleiben, ein zurückgenommener
  Befund wird nicht wieder geöffnet. Ein Nachtrag zu einem Element ohne
  Urteil wird ignoriert (Warnung bei `report`).
- Eine Neudefinition eines Zusatzbefunds (gleiche ID in `extra` einer
  späteren Datei) ersetzt die alte ganz: offen, ohne altes `v`.
- Ob ein Urteil nach `changes.json` veraltet ist, richtet sich nach dem
  Prüfstand des letzten Urteils mit Status (bzw. der letzten Definition).

### 4b. Behobene Punkte

Ein Fix-PR trägt behobene Punkte in `status/zz-fixed-<bereich>.json` ein
(Element-ID oder Befund-ID `x-…` mit `s: "ok"` und Verweis auf den PR in `n`).
Pflichtfeld ist `"afterRound": N`, die letzte Prüfrunde vor dem Fix: Die
Datei gilt nach Runde N (und deren Korrekturdateien), aber vor Runde N + 1;
ein Urteil einer späteren Runde ersetzt den Fix also. Ohne `afterRound`
bricht das Werkzeug ab.

```json
{ "batch": "zz-fixed-termine", "afterRound": 3, "ionic": "9f9b82af", "flutter": "<commit>",
  "items": { "<element-id>": { "s": "ok", "n": "PR #123" } } }
```

`verify-round` wählt behobene Punkte (Elemente und Zusatzbefunde), die seit
dem Fix noch keine Runde gesehen hat (weder Urteil noch Nachtrag in einer
`zz-verify*`-Datei), mit dem Grund `behoben-ungeprueft` aus.

### 5. Bericht, Tracker und Arbeitslisten

`node tool/parity/parity.mjs report` schreibt `summary.md` und die kompakte
`tracker-data.json` (nicht versioniert, wird mit veröffentlicht) für die Tracker-Seite (`tracker/index.html`, als
Artifact veröffentlicht; dort entscheidet Leon je Abweichung „Angleichen“,
„So lassen“ oder „Später klären“). In `summary.md` trägt jede Zeile die
Element-ID (Teil nach `#`) bzw. die Befund-ID `x-…`; `logic`-Einträge, deren
Befunde einzeln als Zusatzbefunde stehen, zählen in der Status-Tabelle in
der eigenen Zeile `zusammenfassend` statt unter `diff`/`missing`. Oben steht,
wie viele Urteile seit ihrem Flutter-Commit geänderte Dateien referenzieren
(„Flutter seit Urteil geändert“, gleiche Prüfung wie `flutter-geaendert`,
ebenfalls mit `--flutter`/`--no-flutter-check`); der Tracker zeigt sie mit
dem Tag „Flutter geändert“. Urteile zu
IDs, die das Inventar nicht kennt, und Urteile zu unbekannten
Zusatzbefunden meldet `report` als Warnung. `node tool/parity/parity.mjs fixlists`
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
