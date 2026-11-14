# Für Entwickler: So ist die Beta gebaut

[Zurück zur Übersicht](README.md)

Diese Seite erklärt, wie das neue Design (Beta) im Code aufgebaut ist und
welche Regeln für Änderungen gelten. Wie die App aus Sicht der Nutzer
funktioniert, steht im [Überblick](ueberblick.md), bei den
[Rollen](rollen.md) und in den [Szenarien](szenarien/README.md).

- [Zwei Designs, eine App](#zwei-designs-eine-app)
- [Der Schalter](#der-schalter)
- [Wo der Code liegt](#wo-der-code-liegt)
- [Routen und Weiterleitungen](#routen-und-weiterleitungen)
- [Rahmen, Reiter und Breiten](#rahmen-reiter-und-breiten)
- [Rollen und Rechte im Code](#rollen-und-rechte-im-code)
- [Bausteine des Designs](#bausteine-des-designs)
- [Texte](#texte)
- [Logik und Daten](#logik-und-daten)
- [Tests](#tests)
- [Prüfliste für einen Beta-PR](#prüfliste-für-einen-beta-pr)
- [Weitere technische Doku](#weitere-technische-doku)

---

## Zwei Designs, eine App

Attendix hat zwei Oberflächen über denselben Daten:

- **Klassisch:** sieht aus und bedient sich wie die frühere Ionic-App. Es ist
  der Standard und bleibt so, wie es ist.
- **Neues Design (Beta):** wird am Gerät eingeschaltet. Jede neue Bedienung
  entsteht hier, für alle Rollen.

Beide teilen sich Models (`lib/data/models`), Repositories
(`lib/data/repositories`), Provider (`lib/core/providers`) und die Rechte der
Rollen. Die Beta ist eine zweite Darstellung, keine zweite App. Deshalb gilt:

- Eine Änderung an der Beta darf das klassische Design nicht verändern.
- Die Beta zeigt keiner Rolle mehr als das klassische Design.
- Was die Beta speichert, muss die klassische Ansicht und die Ionic-App lesen
  können. Beispiel: `rd_type_flags.dart` schaltet an der Terminart Ort und
  Werke ein, sobald ein Termin sie in der Beta bekommt.

## Der Schalter

`lib/core/providers/redesign_providers.dart`

- Der Schalter liegt nur auf dem Gerät (SharedPreferences, Schlüssel
  `redesign.enabled`), nie in der Datenbank. Farbwelt, Hell/Dunkel und das
  App-Icon liegen daneben.
- `loadInitialRedesignSettings()` läuft in `main()` vor `runApp`, damit schon
  das erste Bild den richtigen Rahmen und die richtigen Farben hat.
- `redesignEnabledProvider` sagt Widgets, ob die Beta an ist.
- `RedesignRoutes.active` spiegelt den Wert für reine Funktionen ohne Riverpod,
  zum Beispiel für die Wahl der Startseite.

## Wo der Code liegt

```
lib/
├── core/
│   ├── providers/redesign_providers.dart   # Schalter, Farbwelt, Hell/Dunkel
│   ├── router/redesign_routes.dart         # Routen und Rollenprüfung der Beta
│   └── theme/redesign/                     # rd_palette.dart, rd_theme.dart
├── features/redesign/
│   ├── data/                               # rd_*_logic.dart, rd_words.dart, …
│   │   └── providers/                      # Provider nur für die Beta
│   └── presentation/
│       ├── shell/                          # Rahmen, Reiter, Seitenleiste
│       ├── pages/                          # eine Datei je Seite: rd_*_page.dart
│       └── widgets/                        # rd_widgets.dart und Bausteine je Bereich
└── l10n/fragments/                         # Texte, eine Datei je Bereich
```

Alles, was nur zur Beta gehört, trägt die Vorsilbe `rd_` (Dateien) und `Rd`
(Klassen). Seiten anderer Features, die es noch nicht neu gibt, öffnet die Beta
weiter (zum Beispiel die Elternseite). Sie bekommen dort den
[Beta-Skin](#bausteine-des-designs).

## Routen und Weiterleitungen

`lib/core/router/redesign_routes.dart`, eingehängt in
`lib/core/router/app_router.dart`.

- Die Beta hat eigene, deutsche Pfade: `/heute`, `/termine`, `/mitglieder`,
  `/werke`, `/ich`, darunter `/ich/verwaltung/…`. Pfade werden nie von Hand
  zusammengesetzt, sondern über `RedesignRoutes` gebaut
  (`RedesignRoutes.event(id)`, `RedesignRoutes.person(id)`).
- `_AppShell` wählt den Rahmen: `RdShell` in der Beta, sonst `MainShell`.
- `_BetaOr(beta: …, classic: …)` zeigt auf derselben Route die Beta-Seite oder
  die klassische. So bleiben Links, Pushes und Rollenprüfungen gleich.
- `betaTarget()` und `legacyTarget()` leiten alte Ziele um, solange die Beta an
  ist: `/attendance/:id` wird zum Termin der Beta, `/people` zu `/mitglieder`,
  `/settings` zu `/ich`. Benachrichtigungen und Pushes landen dadurch im
  richtigen Design.
- `roleRedirect(location, role)` prüft jede Beta-Route gegen die Rolle. Wer
  eine neue Seite anlegt, die nicht jede Rolle sehen darf, trägt sie dort ein.
  Ein ausgeblendeter Knopf allein reicht nicht, weil Links und die Adresszeile
  im Browser die Seite sonst trotzdem öffnen.

## Rahmen, Reiter und Breiten

`lib/features/redesign/presentation/shell/`

- `rdDestinationsFor(role, …)` in `rd_destinations.dart` ist die eine Stelle,
  die festlegt, welche Reiter eine Rolle sieht. Die Tabelle dazu steht unter
  [Rollen](rollen.md#welche-reiter-sieht-wer).
- `rdShownLocation()` in `rd_shell.dart` liefert die Seite, die gerade oben
  liegt. Reiter und Seitenleiste markieren danach den richtigen Bereich, auch
  wenn die Seite aus einem anderen Bereich geöffnet wurde.

| Breite | Verhalten | Konstante |
|--------|-----------|-----------|
| schmal | Reiter unten | |
| ab 840 | Seitenleiste links statt der Reiter | `rdSidebarBreakpoint` |
| ab 1000 Inhaltsbreite | „Heute“ in zwei Spalten | `rdTodayColumnsMinWidth` |
| ab 1024 | Liste links, Detail rechts (zum Beispiel Termine und Mitglieder) | `rdSplitBreakpoint` |

Regeln für breite Fenster (`rd_desktop.dart`): Listen mit Detail behalten die
Liste links, die rechte Seite ist nie leer (`rd_overview.dart`), und je Bereich
gibt es ein Plus im Kopf der Liste.

## Rollen und Rechte im Code

Rechte kommen aus den vorhandenen Abfragen in
`lib/core/constants/enums.dart`. Die Beta erfindet keine eigenen.

| Abfrage | Trifft zu auf |
|---------|---------------|
| `role.isAdmin \|\| role.isResponsible` | die Leitung |
| `role.isAdmin` | nur Administratoren |
| `role.isConductor` | Leitung und Beobachter |
| `role.isHelperRole` | Helfer und Stimmführer-Helfer |
| `role.canAddAttendance` | wer Termine öffnet und Anwesenheit erfasst |
| `role.canSeePeopleTab` | wer den Reiter „Mitglieder“ der Beta sieht |
| `role.canSeeSelfServiceTab` | wer eine eigene Zusage hat |
| `role.isParent`, `role.isApplicant` | Eltern, Bewerber |

Dazu kommen die Schalter der Gruppe aus
`lib/core/providers/role_permission_providers.dart` (zum Beispiel, ob Helfer
Termine anlegen dürfen). Welche Einträge die Verwaltung zeigt, entscheidet
`rdManageVisible()` in `data/rd_manage_logic.dart`.

Die Rechte in der App sind Komfort. Die Datenbank setzt sie mit ihren eigenen
Regeln durch, und jede Abfrage filtert nach `tenantId` (siehe `CLAUDE.md`).

## Bausteine des Designs

- **Farben:** `context.rd` liefert die `RdPalette` der gewählten Farbwelt
  (`RdFarbwelt`: Petrol, Konzertsaal, Nachtblau, Klar, Bühne) in Hell oder
  Dunkel. Farben werden nie fest in eine Seite geschrieben.
- **Schrift:** `RdType` hat die Textstufen (`largeTitle`, `title`,
  `cardTitle`, `section`, `body`, `meta`, `eyebrow`).
- **Widgets:** `presentation/widgets/rd_widgets.dart` enthält die Bausteine,
  aus denen jede Seite besteht: `RdPage`, `RdCard`, `RdGroupedList`,
  `RdListRow`, `RdSwitchRow`, `RdGroupLabel`, `RdSectionHeader`,
  `RdPrimaryButton`, `RdOutlineButton`, `RdPill`, `RdSegmented`,
  `RdChoiceChip`, `RdChipScroller`, `RdBackLink`, `RdHintBox` und weitere.
- **Seitenvorlagen:** Listen der Verwaltung nutzen
  `widgets/manage/rd_manage_list.dart` (Rücklink zur Verwaltung, großer Titel,
  ein Satz Erklärung, gruppierte Liste, Plus, •••). Die Vorlage zeigt nur. Laden,
  Speichern und Rechte bleiben bei der Seite.
- **Beta-Skin:** `context.rdSkin` ist gesetzt, solange das Beta-Theme aktiv
  ist. Die alten Bausteine zeichnen sich dann im neuen Design. So sehen auch
  alte Seiten, Blätter und Dialoge, die aus der Beta erreichbar sind, wie die
  Beta aus.
- **Icons:** Die Beta nutzt Material-Icons, das klassische Design Ionicons.

Leitlinien für neue Seiten:

- Eine Hauptaktion je Seite.
- Erst ein vorhandenes Muster suchen, dann bauen. Eine neue Liste der
  Verwaltung nimmt die Vorlage, ein neues Formular sieht aus wie „Werk
  bearbeiten“.
- Jede Seite hat ihre Zustände für Laden, leer und Fehler, mit „Erneut
  versuchen“.
- Seiten zum Bearbeiten speichern jede Änderung sofort und zeigen das an.
  Seiten zum Anlegen haben einen Knopf „Anlegen“.

## Texte

- Alle Texte kommen aus `lib/l10n`. Die ARB-Dateien sind **erzeugt** und werden
  nicht von Hand geändert. Neue Texte kommen in eine Datei unter
  `lib/l10n/fragments/` (deutsch und englisch), dann:

  ```bash
  dart run tool/i18n/build_arb.dart
  flutter gen-l10n
  ```

- **Wörter je Art der Gruppe:** In der Beta ist „Gruppe“ immer die ganze
  Gruppe. Ihre Teile heißen je nach Art Instrument, Stimme oder Untergruppe,
  die Ebene darüber Register oder Kategorie. Kein Text wählt sein Wort selbst:
  Er nimmt die Art aus `rdGroupKindProvider` (`data/rd_words.dart`) und einen
  `rdWords…`-Text, zum Beispiel `l10n.rdWordsCategory(kind)`.
- **Anrede:** Die Beta duzt.
- **Doku:** Texte, die diese Doku zitiert, prüft die CI gegen `app_de.arb`
  (siehe [unten](#prüfliste-für-einen-beta-pr)).

## Logik und Daten

- Was sich ohne Oberfläche entscheiden lässt, liegt als reine Funktion in
  `features/redesign/data/rd_*_logic.dart` (zum Beispiel
  `rd_manage_logic.dart`, `rd_event_logic.dart`, `rd_critical_logic.dart`).
  Diese Dateien haben keine Widgets und lassen sich direkt testen.
- Provider nur für die Beta liegen in `features/redesign/data/providers/`. Sie
  bauen auf den Repositories mit Tenant auf
  (`…RepositoryWithTenantProvider`), nicht auf eigenen Abfragen.
- `rd_event_phase.dart` bestimmt die Phase eines Termins (davor, am Tag,
  läuft, danach, archiviert). Die Karte oben im Termin und „Heute“ richten sich danach.
- `rd_write_queue.dart` ordnet das Schreiben der Anwesenheit: Änderungen an
  einer Zeile laufen nacheinander, und eine ältere Antwort überschreibt nie
  eine neuere. Wer Status oder Notiz einer Person im Termin speichert, geht
  über diese Warteschlange.

## Tests

- Tests der Beta liegen in `test/features/redesign/`.
- Ein Widget-Test schaltet die Beta ein, indem er
  `initialRedesignSettingsProvider` mit
  `RedesignSettings(enabled: true)` überschreibt und die App mit
  `buildRdTheme(…)` aufbaut (Beispiel: `rd_pages_test.dart`).
- Logik-Dateien bekommen Unit-Tests, Seiten nur dort Widget-Tests, wo ein
  Fehler wahrscheinlich und teuer ist. Nicht jede Zeile braucht einen Test.
- Lokal reichen die Tests zu dem, was geändert wurde. Die ganze Suite läuft in
  der CI (vier Teile).
- Die Szenarien dieser Doku sind die Prüfliste für Tests am Gerät. Testnamen
  und Fehlerberichte können die Nummer nennen (`M-02`).

Mehr zur Test-Infrastruktur: [`test/README.md`](../../test/README.md).

## Prüfliste für einen Beta-PR

1. Das klassische Design ist unverändert. Neue Bedienung steht hinter
   `redesignEnabledProvider` oder in `features/redesign/`.
2. Neue Routen stehen in `RedesignRoutes` und, wenn nicht jede Rolle sie sehen
   darf, in `roleRedirect`.
3. Rechte kommen aus den vorhandenen Abfragen. Keine Rolle sieht mehr als
   vorher.
4. Texte stehen in `lib/l10n/fragments/`, die ARB-Dateien sind neu erzeugt.
   Wörter für Teile der Gruppe kommen aus `rdWords…`.
5. Die Seite funktioniert schmal und breit, hell und dunkel.
6. Ändert sich, wie eine Aufgabe abläuft, ist das Szenario in `docs/beta/`
   angepasst. Neue Aufgaben haben ein neues Szenario mit der nächsten freien
   Nummer.
7. Das Prüfskript ist grün:

   ```bash
   python3 tool/docs/check_app_texts.py --strict
   ```

   Es meldet zitierte Texte, die es in der App nicht mehr gibt, Nummern von
   Szenarien ohne Überschrift und Links ins Leere.
8. Der PR hat eine Datei unter `changelog/unreleased/` und erhöht keine
   Version (siehe `CLAUDE.md`).

## Weitere technische Doku

| Thema | Datei |
|-------|-------|
| Regeln für Code, Tests, Versionen | [`CLAUDE.md`](../../CLAUDE.md) |
| App bauen (Web, iOS, Android, macOS) | [`README.md`](../../README.md) |
| Tests | [`test/README.md`](../../test/README.md) |
| Push einrichten | [`docs/push-setup.md`](../push-setup.md) |
| Live Activities | [`docs/live-activity-setup.md`](../live-activity-setup.md) |
| Fehler-Überwachung | [`docs/error-monitoring.md`](../error-monitoring.md) |
| Noten-Import | [`docs/werke-import.md`](../werke-import.md) |
| Updates ohne Store | [`docs/release/shorebird.md`](../release/shorebird.md) |
| Hilfe in der App erzeugen | `tool/help/build_help.mjs` |
