# Für Entwickler: Aufbau der Oberfläche

[Zurück zur Übersicht](README.md)

Diese Seite erklärt, wie die Oberfläche im Code aufgebaut ist und welche
Regeln für Änderungen gelten. Wie die App aus Sicht der Nutzer funktioniert,
steht im [Überblick](ueberblick.md), bei den [Rollen](rollen.md) und in den
[Szenarien](szenarien/README.md).

- [Design und Architektur](#design-und-architektur)
- [Einstellungen zur Darstellung](#einstellungen-zur-darstellung)
- [Wo der Code liegt](#wo-der-code-liegt)
- [Routen und Weiterleitungen](#routen-und-weiterleitungen)
- [Rahmen, Reiter und Breiten](#rahmen-reiter-und-breiten)
- [Rollen und Rechte im Code](#rollen-und-rechte-im-code)
- [Bausteine des Designs](#bausteine-des-designs)
- [Texte](#texte)
- [Logik und Daten](#logik-und-daten)
- [Tests](#tests)
- [Prüfliste für einen PR](#prüfliste-für-einen-pr)
- [Weitere technische Doku](#weitere-technische-doku)

---

## Design und Architektur

Das Redesign ist das einzige und standardmäßige Design der App.

Alle Seiten teilen sich Models (`lib/data/models`), Repositories
(`lib/data/repositories`), Provider (`lib/core/providers`) und die Rechte der
Rollen. Beim Speichern gilt: Was die App speichert (z. B. über
`rd_type_flags.dart`), bleibt mit der bestehenden Datenbankstruktur kompatibel.

## Einstellungen zur Darstellung

`lib/core/providers/redesign_providers.dart`

- Farbwelt, Hell/Dunkel und App-Icon liegen nur auf dem Gerät
  (SharedPreferences), nie in der Datenbank.
- `loadInitialRedesignSettings()` läuft in `main()` vor `runApp`, damit schon
  das erste Bild den richtigen Rahmen und die richtigen Farben hat.

## Wo der Code liegt

```
lib/
├── core/
│   ├── providers/redesign_providers.dart   # Farbwelt, Hell/Dunkel, App-Icon
│   ├── redesign/                           # rd_words.dart, rd_dates.dart, rd_roles_logic.dart, …
│   ├── router/redesign_routes.dart         # Routen und Rollenprüfung
│   └── theme/redesign/                     # rd_palette.dart, rd_theme.dart
├── shared/
│   ├── shell/                              # Rahmen, Reiter, Seitenleiste (RdShell)
│   └── widgets/redesign/                   # rd_widgets.dart, primitives/, Split-View, Übersicht
├── features/<domäne>/                      # Feature-First: today/, attendance/, people/, songs/,
│   ├── data/                               # rd_*_logic.dart & Bereichs-Provider (data/providers/)
│   └── presentation/
│       ├── pages/                          # eine Datei je Seite: rd_*_page.dart
│       └── widgets/                        # Bereichs-Widgets
└── l10n/fragments/                         # Texte, eine Datei je Bereich
```

Seiten und Bausteine des aktuellen Designs tragen weiterhin die Vorsilbe `rd_`
(Dateien) und `Rd` (Klassen), liegen aber direkt in ihrer jeweiligen Fachdomäne
(z. B. `features/today/`, `features/attendance/`, `features/people/`,
`features/songs/`, `features/settings/`, `features/profile/`, `features/statistics/`).

## Routen und Weiterleitungen

`lib/core/router/redesign_routes.dart`, eingehängt in
`lib/core/router/app_router.dart`.

- Die Hauptpfade sind deutsch: `/heute`, `/termine`, `/mitglieder`, `/werke`,
  `/ich`, darunter `/ich/verwaltung/…`. Pfade werden nie von Hand
  zusammengesetzt, sondern über `RedesignRoutes` gebaut
  (`RedesignRoutes.event(id)`, `RedesignRoutes.person(id)`).
- `RdShell` ist der einzige App-Rahmen.
- `betaTarget()` und `legacyTarget()` leiten alte Links und Pushes
  (`/attendance/:id`, `/people`, `/settings` …) automatisch auf die neuen
  Ziele um. Benachrichtigungen und Pushes landen dadurch immer auf der
  richtigen Seite.
- `roleRedirect(location, role)` prüft jede Route gegen die Rolle. Wer
  eine neue Seite anlegt, die nicht jede Rolle sehen darf, trägt sie dort ein.
  Ein ausgeblendeter Knopf allein reicht nicht, weil Links und die Adresszeile
  im Browser die Seite sonst trotzdem öffnen.

## Rahmen, Reiter und Breiten

`lib/shared/shell/`

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
`rdManageVisible()` in `lib/features/settings/data/rd_manage_logic.dart`.

Die Rechte in der App sind Komfort. Die Datenbank setzt sie mit ihren eigenen
Regeln durch, und jede Abfrage filtert nach `tenantId` (siehe `CLAUDE.md`).

## Bausteine des Designs

- **Farben:** `context.rd` liefert die `RdPalette` der gewählten Farbwelt
  (`RdFarbwelt`: Petrol, Konzertsaal, Nachtblau, Klar, Bühne) in Hell oder
  Dunkel. Farben werden nie fest in eine Seite geschrieben.
- **Schrift:** `RdType` hat die Textstufen (`largeTitle`, `title`,
  `cardTitle`, `section`, `body`, `meta`, `eyebrow`).
- **Widgets:** `lib/shared/widgets/redesign/rd_widgets.dart` (mit `primitives/`) enthält die Bausteine,
  aus denen jede Seite besteht: `RdPage`, `RdCard`, `RdGroupedList`,
  `RdListRow`, `RdSwitchRow`, `RdGroupLabel`, `RdSectionHeader`,
  `RdPrimaryButton`, `RdOutlineButton`, `RdPill`, `RdSegmented`,
  `RdChoiceChip`, `RdChipScroller`, `RdBackLink`, `RdHintBox` und weitere.
- **Seitenvorlagen:** Listen der Verwaltung nutzen
  `lib/features/settings/presentation/widgets/manage/rd_manage_list.dart` (Rücklink zur Verwaltung, großer Titel,
  ein Satz Erklärung, gruppierte Liste, Plus, •••). Die Vorlage zeigt nur. Laden,
  Speichern und Rechte bleiben bei der Seite.
- **Theme & Tokens:** `context.rd` liefert die `RdPalette`, `buildRdTheme(...)`
  konfiguriert das gesamte Material-Theme inklusive der mitgenutzten Feature-Seiten.
- **Icons:** Die App nutzt Material-Icons.

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
  (siehe [unten](#prüfliste-für-einen-pr)).

## Logik und Daten

- Was sich ohne Oberfläche entscheiden lässt, liegt als reine Funktion in
  `features/<domäne>/data/rd_*_logic.dart` (zum Beispiel
  `settings/data/rd_manage_logic.dart`, `attendance/data/rd_event_logic.dart`,
  `people/data/rd_critical_logic.dart`) bzw. bereichsübergreifend in
  `lib/core/redesign/`. Diese Dateien haben keine Widgets und lassen sich direkt testen.
- Bereichs-Provider liegen in `features/<domäne>/data/providers/`. Sie
  bauen auf den Repositories mit Tenant auf
  (`…RepositoryWithTenantProvider`), nicht auf eigenen Abfragen.
- `rd_event_phase.dart` bestimmt die Phase eines Termins (davor, am Tag,
  läuft, danach, archiviert). Die Karte oben im Termin und „Heute“ richten sich danach.
- `rd_write_queue.dart` ordnet das Schreiben der Anwesenheit: Änderungen an
  einer Zeile laufen nacheinander, und eine ältere Antwort überschreibt nie
  eine neuere. Wer Status oder Notiz einer Person im Termin speichert, geht
  über diese Warteschlange.

## Tests

- Tests der Oberfläche liegen passend zur Code-Struktur in `test/features/<domäne>/`, `test/shared/` und `test/core/`.
- Ein Widget-Test baut die App mit `buildRdTheme(…)` auf.
- Logik-Dateien bekommen Unit-Tests, Seiten nur dort Widget-Tests, wo ein
  Fehler wahrscheinlich und teuer ist. Nicht jede Zeile braucht einen Test.
- Lokal reichen die Tests zu dem, was geändert wurde. Die ganze Suite läuft in
  der CI (vier Teile).
- Die Szenarien dieser Doku sind die Prüfliste für Tests am Gerät. Testnamen
  und Fehlerberichte können die Nummer nennen (`M-02`).
- Für rund 25 Szenarien gibt es einen Ablauf in `patrol_test/`, der die
  echte App im Browser bedient und die Nummer im Namen trägt. Bei jedem PR
  laufen die wichtigsten, jede Nacht alle
  ([`docs/testing.md`](../testing.md)).

Mehr zur Test-Infrastruktur: [`test/README.md`](../../test/README.md).

## Prüfliste für einen PR

1. Neue Routen stehen in `RedesignRoutes` und, wenn nicht jede Rolle sie sehen
   darf, in `roleRedirect`.
2. Rechte kommen aus den vorhandenen Abfragen. Keine Rolle sieht mehr als
   vorher.
3. Texte stehen in `lib/l10n/fragments/`, die ARB-Dateien sind neu erzeugt.
   Wörter für Teile der Gruppe kommen aus `rdWords…`.
4. Die Seite funktioniert schmal und breit, hell und dunkel.
5. Ändert sich, wie eine Aufgabe abläuft, ist das Szenario in `docs/beta/`
   angepasst. Neue Aufgaben haben ein neues Szenario mit der nächsten freien
   Nummer. Gibt es zu dem Szenario einen Ablauf in `patrol_test/` (die Nummer
   steht im Namen), ist er mit angepasst.
6. Das Prüfskript ist grün:

   ```bash
   python3 tool/docs/check_app_texts.py --strict
   ```

   Es meldet zitierte Texte, die es in der App nicht mehr gibt, Nummern von
   Szenarien ohne Überschrift und Links ins Leere.
7. Der PR hat eine Datei unter `changelog/unreleased/` und erhöht keine
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
