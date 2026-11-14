# Attendix - Claude Instructions

## Projekt-Übersicht

- **App:** Flutter PWA für Anwesenheits-Tracking (Orchester, Chöre, Gruppen)
- **Migriert von:** Ionic/Angular → Flutter-native Patterns bevorzugen
- **Backend:** Supabase (Auth, Database, Realtime)
- **State Management:** Riverpod
- **Routing:** go_router
- **Models:** Freezed (immutable)

## Architektur

```
lib/
├── core/           # Shared: providers, router, theme, utils
├── data/           # Models (Freezed) + Repositories (Supabase)
├── features/       # Feature-Module: presentation/pages/
└── shared/         # Wiederverwendbare Widgets
```

## Kritische Regeln

### 1. Multi-Tenant - IMMER tenantId filtern!

```dart
// ✅ Richtig
.eq('tenantId', currentTenantId)

// ❌ Falsch - Sicherheitslücke!
.select('*')  // ohne tenantId Filter
```

### 2. Riverpod Namenskonventionen

```dart
// Daten laden
final playersProvider = FutureProvider<List<Person>>((ref) {...});

// Mit Parameter
final playerByIdProvider = FutureProvider.family<Person?, int>((ref, id) {...});

// Mutations
final attendanceNotifierProvider = NotifierProvider<AttendanceNotifier, AsyncValue<void>>(...);

// Repository mit Tenant
final playerRepositoryWithTenantProvider = Provider<PlayerRepository>((ref) {...});
```

### 3. Freezed - Nach Model-Änderungen

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. UI-Labels auf Deutsch

Anwesenheitsstatus: `Anwesend`, `Abwesend`, `Entschuldigt`, `Verspätet`

### 5. PWA-Kompatibilität

Native APIs (Haptics etc.) immer in try-catch wrappen.

## Wichtige Dateien

| Bereich | Pfad |
|---------|------|
| Providers | `lib/core/providers/*.dart` |
| Repositories | `lib/data/repositories/*.dart` |
| Enums | `lib/core/constants/*.dart` |
| Router | `lib/core/router/app_router.dart` |
| Theme | `lib/core/theme/` |

## Befehle

```bash
# Freezed/JSON generieren
dart run build_runner build --delete-conflicting-outputs

# Code analysieren
dart analyze lib/

# Tests ausführen
flutter test

# Tests mit Coverage
flutter test --coverage

# Security-Tests ausführen
flutter test --name "Multi-Tenant Security"

# PWA starten
flutter run -d chrome
```

## Testing

### Test-Struktur

```
test/
├── mocks/           # Supabase & Repository Mocks
├── factories/       # Test-Daten Factories
├── helpers/         # Container Setup, Matchers
├── core/providers/  # Provider Tests
├── data/repositories/  # Repository Security Tests
└── features/        # Feature Tests
```

### Security Tests

Repository-Tests validieren Multi-Tenant Security via Source-Code-Analyse:

```dart
// Alle UPDATE-Operationen müssen tenantId filtern
test('all UPDATE operations include tenantId filter', () {
  final updateQueries = RegExp(...)
      .allMatches(playerRepoSource);

  for (final match in updateQueries) {
    expect(query, contains(".eq('tenantId', currentTenantId)"));
  }
});
```

### Test-Factories

```dart
// Person erstellen
final person = TestFactories.createPerson(id: 1, tenantId: 42);

// Liste erstellen
final persons = TestFactories.createPersonList(10, tenantId: 42);

// Spezielle Varianten
final archived = TestFactories.createArchivedPerson();
final paused = TestFactories.createPausedPerson();
```

### Neue Tests schreiben

**Repository-Tests:**
- Source-Code-Analyse für Security
- Verifiziere `tenantId` Filter auf allen Operationen
- Prüfe `id` UND `tenantId` bei Mutations

**Provider-Tests:**
- Teste Tenant-Guard Pattern (`if (!repo.hasTenantId) return ...`)
- Verifiziere Cache-Invalidierung
- Teste Error-Handling

Mehr Details: `test/README.md`

## Vor dem Commit/Push

**WICHTIG:** PRs erhöhen die Version **nicht** selbst (kein Ändern von `version:` in `pubspec.yaml`, `AppConstants.appVersion` oder `assets/version_history.json`). Sonst kollidiert jeder parallele PR nach jedem Merge.

Stattdessen legt jeder PR **eine** Changelog-Datei an:

```json
// changelog/unreleased/<kurzer-name>.json
{"bump": "minor", "changes": ["✨ Neue Feature-Beschreibung", "🐛 Bug-Fix Beschreibung"]}
```

- `bump`: `minor` für Features, `patch` für Fixes (Standard).
- Nach dem Merge auf master macht der Deploy-Workflow daraus automatisch eine Version (`tool/release/release_version.py`): `pubspec.yaml` (inkl. Build-Nummer), `appVersion` und `version_history.json` werden erhöht, die Fragmente gelöscht.
- In PR-Titel und -Beschreibung keine Versionsnummer nennen.
- PRs bauen keine Cloudflare-Vorschau mehr. Wer eine braucht: Label `preview` an den PR hängen (oder „Run workflow“ auf dem Branch); die URL steht dann im Deploy-Run.
- Ein master-Merge in den PR-Branch ohne Konflikt im eigenen Code braucht kein neues Review, nur grüne CI. Ohne Konflikt muss master vor dem Merge gar nicht reingeholt werden.

**Interne vs. Nutzer-Version:** `appVersion` und `assets/version_history.json` sind die interne Entwicklerhistorie (0.x, Sentry-Release) und werden Nutzern nicht gezeigt. Nutzer sehen `AppConstants.displayVersion` und `assets/version_history_user.json` (weitergeführte Ionic-Historie). Diese beiden nur bei Store-Releases pflegen: `displayVersion` erhöhen und einen Eintrag obendrauf in `assets/version_history_user.json` setzen (oberster Eintrag = `displayVersion`).

## Beta-Dokumentation aktuell halten

`docs/beta/` beschreibt das neue Design (Beta): Überblick, Rollen, Szenarien je Rolle („Ich möchte …“ mit festen Nummern wie `M-02`), Nachschlagen und `entwickler.md` (Aufbau der Beta im Code, Prüfliste für PRs).

- Ändert ein PR, wie eine Aufgabe in der Beta abläuft, passt er das betroffene Szenario im selben PR an. Neue Aufgaben bekommen ein neues Szenario mit der nächsten freien Nummer.
- Texte der App stehen dort in „Anführungszeichen“ und genau wie in `lib/l10n/app_de.arb`. Die CI prüft das (`python3 tool/docs/check_app_texts.py --strict`), dazu Nummern und Links innerhalb der Doku: Wer einen zitierten Text umbenennt, passt die Doku an.
- Das Repo ist öffentlich: keine Zugangsdaten, keine internen Betriebsdetails, keine Sicherheitsbefunde in die Doku.

## Rollen-System

- **Dirigent (conductor):** Vollzugriff
- **Helfer (helper):** Eingeschränkt
- **Spieler (player):** Nur eigene Daten

Prüfung via `role.isConductor`, `role.canSeePeopleTab`, etc.

## App auf Geräte deployen

### iPhone (iOS)

```bash
# 1. Release-Build erstellen
flutter build ios --release

# 2. Auf iPhone installieren und starten (Device-ID anpassen).
#    App-ID ist io.stephanus.attendix auf iOS und Android (ersetzt die Ionic-App)
xcrun devicectl device install app --device 00008120-000C4D5C0205A01E build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device 00008120-000C4D5C0205A01E io.stephanus.attendix
```

**Voraussetzungen:**
- iPhone per USB verbunden
- Entwicklermodus auf iPhone aktiviert (Einstellungen → Datenschutz & Sicherheit → Entwicklermodus)
- Code Signing in Xcode konfiguriert (Team ausgewählt)
- Beim ersten Mal: Zertifikat auf iPhone vertrauen (Einstellungen → Allgemein → VPN & Geräteverwaltung)

**Wichtig:** Debug-Builds funktionieren nur über Flutter CLI oder Xcode direkt. Für standalone: immer `--release` verwenden.

**Device-ID finden:**
```bash
flutter devices
```

### macOS

```bash
# 1. Release-Build erstellen
flutter build macos --release

# 2. In Applications installieren und starten
cp -r build/macos/Build/Products/Release/Attendix.app /Applications/
open /Applications/Attendix.app
```

**Wichtig:** Die Datei `macos/Runner/Release.entitlements` muss `com.apple.security.network.client` enthalten für Netzwerkzugriff:
```xml
<key>com.apple.security.network.client</key>
<true/>
```

## Migration (Ionic → Flutter)

Für Migrationen nutze: `/ionic-migrate [feature]`

Der Skill orchestriert automatisch:
- Worktree-Setup (optional)
- Analyse mit `migration-analyzer` und `Explore` Agents
- Task-Planung
- Code Review mit `flutter-reviewer`
- Commit und Status-Update

Status: `.claude/migration-status.md`

## Code Review

**WICHTIG:** Bei Code Reviews IMMER beide Reviewer parallel starten:

```
1. flutter-reviewer (Custom Agent)
   - Flutter-spezifisch: Riverpod, Freezed, Multi-Tenant Security
   - Kennt Attendix-Patterns und Repository-Struktur

2. pr-review-toolkit:code-reviewer (Plugin)
   - Allgemein: Style Guide, Best Practices, CLAUDE.md Regeln
   - Prüft gegen Projekt-Guidelines
```

Beide Agents parallel starten für umfassende Review-Abdeckung:
- `flutter-reviewer` findet Security-Issues (tenantId-Filter, Repository-Patterns)
- `pr-review-toolkit:code-reviewer` findet Style/Convention-Issues

## Weiterführende Dokumentation

Für ausführliche Patterns, Ionic→Flutter Mappings und Code-Beispiele:
→ [.github/copilot-instructions.md](.github/copilot-instructions.md)
