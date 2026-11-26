# Xcode Cloud (iOS & macOS TestFlight)

Automatisierte Apple-Builds für **iOS** und **macOS** direkt über Apples Xcode Cloud — inklusive automatischer Signierung und Upload nach TestFlight.

> **Wichtig zu Shorebird (OTA-Patches):**
> Xcode Cloud archiviert direkt mit `xcodebuild` und normalem Flutter (kein `shorebird release`). Auf Builds aus Xcode Cloud kommen daher **keine Shorebird-OTA-Patches** an.
> - **TestFlight / schnelles Testen:** läuft automatisch über Xcode Cloud (iOS + macOS).
> - **Produktive Store-Releases mit OTA-Patch-Fähigkeit:** weiterhin über `scripts/store_build.sh` (`ipa` / `macos-release`, siehe [shorebird.md](shorebird.md)).

## Was bereits im Repo eingerichtet ist

| Datei | Zweck |
|---|---|
| `ios/ci_scripts/ci_post_clone.sh` | Xcode-Cloud-Hook für `ios/Runner.xcworkspace` (ruft das gemeinsame Skript für `ios` auf) |
| `macos/ci_scripts/ci_post_clone.sh` | Xcode-Cloud-Hook für `macos/Runner.xcworkspace` (ruft das gemeinsame Skript für `macos` auf) |
| `scripts/xcode_cloud_post_clone.sh` | Gemeinsames Bootstrap-Skript für beide Plattformen |

Das Skript erledigt nach dem Clone automatisch:
1. Liest die gepinnte **Flutter-Version** aus `.github/workflows/ci.yml` (überschreibbar per Env-Variable `FLUTTER_VERSION`) und klont exakt dieses Tag nach `$HOME/flutter`.
2. Ermittelt `--build-name` (`AppConstants.displayVersion`, z. B. `5.0.0`) und `--build-number` (`pubspec`-Build + 100) über `scripts/store_build.sh --print` und gleicht sie mit `CI_BUILD_NUMBER` ab.
3. Erzeugt `.env.app` ausschließlich aus freigegebenen Client-Variablen (sicher gequotet für `flutter_dotenv`, niemals Service-Role-Keys).
4. Dekodiert optional `GOOGLE_SERVICE_INFO_PLIST_B64` nach `ios/Runner/GoogleService-Info.plist` (ohne Quarantine-xattrs, geprüft per `plutil -lint` — wird sowohl vom iOS- als auch vom macOS-Build eingebunden).
5. Installiert bei Bedarf CocoaPods, führt `flutter precache`, `flutter pub get`, `flutter build <ios|macos> --release --config-only` und (falls nötig) `pod install` aus.
6. Aktiviert bei **macOS** in Xcode Cloud (`CI_XCODE_CLOUD=TRUE`) `macos/Runner/AppStore.entitlements` (Sandbox, Schlüsselbund-Gruppe und Push-Entitlement), ohne lokale ad-hoc-Builds zu beeinflussen.

## Einmalige Einrichtung in Xcode / App Store Connect

### 1. Next Build Number hochsetzen (wichtig vor dem ersten Build)

App Store Connect lehnt Uploads ab, deren Build-Nummer kleiner oder gleich der bisher höchsten hochgeladenen Build-Nummer ist. Xcode Cloud startet standardmäßig bei `1`.

1. **App Store Connect** → App **Attendix** → Tab **Xcode Cloud** → **Settings** → **Build Number**.
2. **Next Build Number** auf einen Wert **oberhalb der aktuell höchsten TestFlight-Build-Nummer** setzen (z. B. `500` bzw. aktuelle Store-Build-Nummer + 1).
3. Falls zwischendurch ein lokaler Shorebird-Release mit höherer Build-Nummer hochgeladen wird, **Next Build Number** danach wieder darüber setzen.

### 2. GitHub-Repository verbinden und zwei Workflows anlegen

Da iOS und macOS eigene Workspaces haben, werden in Xcode / App Store Connect **zwei Workflows** für dieselbe App (`io.stephanus.attendix`) angelegt — einmal aus `ios/Runner.xcworkspace` und einmal aus `macos/Runner.xcworkspace` (oder beide direkt in App Store Connect → **Xcode Cloud** → **Manage Workflows** → **+**):

#### Workflow 1: `iOS TestFlight`
- **Project / Workspace:** `ios/Runner.xcworkspace`
- **Start Conditions:**
  - **Branch Changes:** Branch `master`
  - **Custom Conditions → Files and Folders:** *If changes are made to* → `pubspec.yaml`
    *(Warum: PRs ändern nur `changelog/unreleased/*.json`. Erst der automatische `Version 0.x.y`-Commit von `Deploy to Cloudflare Pages` ändert `pubspec.yaml`. So startet Xcode Cloud genau einmal pro neuer Version und nicht bei Doku- oder Golden-Commits. Manuelles Starten geht jederzeit.)*
- **Environment:**
  - **Xcode Version:** Latest Release (mindestens Xcode 16 / passend zu iOS 15+ SDK)
  - **macOS Version:** Latest Release
  - **Environment Variables:** siehe Tabelle unten
- **Actions → Archive:**
  - **Platform:** `iOS`
  - **Scheme:** `Runner`
  - **Deployment Preparation:** `TestFlight (Internal Testing Only)` oder `TestFlight and App Store`
- **Post-Actions:**
  - **TestFlight Internal Testing** (und bei Bedarf External Testing) hinzufügen.

#### Workflow 2: `macOS TestFlight`
- **Project / Workspace:** `macos/Runner.xcworkspace`
- **Start Conditions:** identisch zu iOS (`master` + Filter auf `pubspec.yaml`)
- **Environment:** identisch zu iOS (dieselben Environment Variables)
- **Actions → Archive:**
  - **Platform:** `macOS`
  - **Scheme:** `Runner`
  - **Deployment Preparation:** `TestFlight (Internal Testing Only)` oder `TestFlight and App Store`
- **Post-Actions:**
  - **TestFlight Internal Testing** hinzufügen.

### 3. Environment Variables (in beiden Workflows hinterlegen)

Alle geheimen Werte in Xcode Cloud mit **Secret** markieren:

| Variable | Pflicht | Secret | Beschreibung |
|---|---|---|---|
| `SUPABASE_ANON_KEY` | Ja | Ja | Öffentlicher Supabase-Anon-Key (wie in `.env.app`) |
| `SUPABASE_URL` | Nein | Nein | Standard: `https://api.attendix.de` |
| `GOOGLE_SERVICE_INFO_PLIST_B64` | Empfohlen | Ja | Base64-kodierte `ios/Runner/GoogleService-Info.plist` (für Push auf iOS & macOS; ohne sie bleibt Push deaktiviert) |
| `DEMO_EMAIL` | Optional | Ja | Demo-Konto E-Mail für „Demo starten“ |
| `DEMO_PASSWORD` | Optional | Ja | Demo-Konto Passwort (Sonderzeichen wie `#`/`$` werden sicher gequotet) |
| `SENTRY_DSN` | Optional | Ja | Sentry-DSN für Fehlerberichte (ohne DSN bleibt Sentry aus) |
| `SENTRY_ENVIRONMENT` | Optional | Nein | Standard: `production` (wenn `SENTRY_DSN` gesetzt ist) |
| `FLUTTER_VERSION` | Optional | Nein | Überschreibt die Flutter-Version aus `.github/workflows/ci.yml` |
| `BUILD_NUMBER_OVERRIDE` | Optional | Nein | Erzwingt eine feste Build-Nummer (nur für Sonderfälle) |

**Base64-Wert für `GOOGLE_SERVICE_INFO_PLIST_B64` lokal erzeugen (macOS):**

```bash
base64 -i ios/Runner/GoogleService-Info.plist | tr -d '\n' | pbcopy
```

Danach direkt in das Secret-Feld in Xcode Cloud einfügen.

## Lokal testen

Die Post-Clone-Skripte lassen sich lokal prüfen (dabei werden bestehende lokale `.env.app`, `GoogleService-Info.plist` und `macos/Runner/Release.entitlements` nicht überschrieben):

```bash
./ios/ci_scripts/ci_post_clone.sh
./macos/ci_scripts/ci_post_clone.sh
```

Danach temporäre Xcode-/SPM-Änderungen wieder zurücksetzen (`git checkout -- ios/ macos/`).

## Typische Fehler & Lösungen

- **`The bundle version must be higher than ...`:** **Next Build Number** in App Store Connect → Xcode Cloud → Settings → Build Number über die letzte TestFlight-Build-Nummer anheben.
- **`ERROR: SUPABASE_ANON_KEY is not set`:** Secret `SUPABASE_ANON_KEY` im Workflow unter *Environment → Environment Variables* ergänzen.
- **Push funktioniert in TestFlight-Builds nicht:** `GOOGLE_SERVICE_INFO_PLIST_B64` im Workflow hinterlegen (im Build-Log erscheint sonst `WARNING: ios/Runner/GoogleService-Info.plist missing`).
- **Xcode Cloud triggert nach Merge nicht:** Prüfen, ob der Merge ein Changelog-Fragment (`changelog/unreleased/*.json`) enthielt, sodass `Deploy to Cloudflare Pages` `pubspec.yaml` aktualisiert hat — oder den Workflow manuell über **Start Build** anstoßen.
