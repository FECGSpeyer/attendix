# Attendix im neuen Design (Beta)

Diese Dokumentation beschreibt Attendix so, wie die App mit eingeschaltetem
**Neuen Design (Beta)** aussieht und funktioniert. Das klassische Design, das
der früheren Ionic-App entspricht, ist hier nicht beschrieben.

Stand: 14.11.2026. Die Doku ist im Aufbau, die Tabelle unten zeigt, was schon
da ist.

## Für wen ist was?

| Teil | Für wen | Inhalt | Stand |
|------|---------|--------|-------|
| [Überblick](ueberblick.md) | alle | Aufbau der App, Reiter, Begriffe, Geräte | fertig |
| [Rollen](rollen.md) | Leitung, Entwickler | Wer sieht was, wer darf was, welche Schalter es gibt | fertig |
| [Szenarien](szenarien/README.md) | alle, Tester | Aufgaben je Rolle: „Ich möchte …“ mit Schritten und Ergebnis | Mitglied fertig, übrige Rollen folgen |
| Nachschlagen je Bereich | Leitung | Was jede Seite zeigt und welche Einstellungen es gibt | folgt |
| Für Entwickler | Entwickler | Wie die Beta im Code aufgebaut ist, Bausteine, Regeln | folgt |

## So liest du die Doku

- **Du willst wissen, wie etwas geht:** Such in den [Szenarien](szenarien/README.md)
  deine Rolle und dort die Aufgabe.
- **Du willst wissen, warum jemand etwas nicht sieht:** Schau in die
  [Rollen](rollen.md). Fast immer liegt es an der Rolle oder an einem Schalter
  der Gruppe.
- **Du testest die App:** Die Szenarien sind zugleich die Prüfliste. Jedes hat
  eine feste Nummer (zum Beispiel `M-02`), auf die Fehlerberichte, Tests und
  PRs verweisen können.

## Wie ein Szenario aufgebaut ist

Jedes Szenario beschreibt eine Aufgabe aus Sicht einer Person, nicht eine Seite
der App.

```markdown
### M-02 Sich von einem Termin abmelden

- **Wo:** Heute
- **Voraussetzung:** was erfüllt sein muss, damit die Aufgabe möglich ist
- **Schritte:** nummeriert, mit den Texten, die in der App stehen
- **Ergebnis:** was danach zu sehen ist
- **Gut zu wissen:** Grenzen, Schalter der Gruppe, Sonderfälle (optional)
```

Regeln für die Liste:

- Eine Aufgabe, ein Szenario. Jede denkbare Kombination steht hier bewusst
  nicht. Sonderfälle gehören in Tests.
- Texte aus der App stehen in „Anführungszeichen“ und genau so wie in der App.
  Wege durch die App stehen mit `›`, zum Beispiel „Ich“ › „Darstellung“.
- Die Nummer eines Szenarios bleibt für immer. Fällt eine Aufgabe weg, bleibt
  die Nummer frei. Neue Aufgaben bekommen die nächste freie Nummer.
- Höhere Rollen wiederholen nicht, was niedrigere schon können. Ein Helfer kann
  alles, was ein Mitglied kann, seine Datei beschreibt nur das Zusätzliche.

## Aktuell halten

Die Beta ändert sich oft. Damit die Doku nicht veraltet:

- Ändert ein PR, wie eine Aufgabe in der Beta abläuft, passt er das betroffene
  Szenario im selben PR an.
- Kommt eine neue Aufgabe dazu, bekommt sie ein neues Szenario.
- Texte der App werden nicht aus dem Kopf geschrieben, sondern aus
  `lib/l10n/app_de.arb` übernommen.
- Ein Prüfskript vergleicht alle Texte in „Anführungszeichen“ mit den Texten
  der App und meldet, was es dort nicht mehr gibt. So fällt auf, wenn ein Knopf
  umbenannt wurde und die Doku noch den alten Namen nennt:

  ```bash
  python3 tool/docs/check_app_texts.py
  ```

  Die CI führt es bei jedem PR aus. Zitate, die nur Beispiele sind und keine
  Texte der App, stehen in `docs/beta/.app-texts-ignore`.

## Was hier nicht steht

Das Repository ist öffentlich. In diese Doku gehören keine Zugangsdaten, keine
internen Details zum Betrieb und keine Sicherheitsbefunde.
