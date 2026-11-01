# Attendix

Flutter-App für Anwesenheits-Tracking (Orchester, Chöre, Gruppen) mit Supabase als Backend.
Läuft als PWA im Browser sowie nativ auf iOS, Android und macOS.

## App selbst bauen

### Voraussetzungen (alle Plattformen)

1. **Flutter SDK** (stable, mindestens 3.29, die CI nutzt 3.29.0). `flutter doctor` zeigt, was für die jeweilige Plattform noch fehlt.
2. **Abhängigkeiten holen:**
   ```bash
   flutter pub get
   ```
   Die generierten Freezed/JSON-Dateien sind eingecheckt. `dart run build_runner build --delete-conflicting-outputs` ist nur nach Model-Änderungen nötig.
3. **Supabase-Konfiguration:** `.env.example` nach `.env` kopieren und `SUPABASE_URL` und `SUPABASE_ANON_KEY` eintragen. Danach:
   ```bash
   bash tool/write_app_env.sh
   ```
   Das Skript erzeugt `.env.app`, die einzige Env-Datei, die in die App gepackt wird. Sie enthält nur die Client-Schlüssel (URL, Anon-Key, optional Demo-Zugang). Ohne `.env.app` bricht jeder Build mit „No file or variants found for asset: .env.app“ ab. Beide Dateien sind in `.gitignore` und gehören nicht ins Repo. Server-Schlüssel wie der Service-Role-Key dürfen nie in `.env.app` landen.

### Web (PWA)

```bash
flutter run -d chrome                         # Entwicklung
flutter build web --release --base-href /     # Release nach build/web
```

Master und PRs werden per GitHub Actions automatisch auf Cloudflare Pages deployt (`.github/workflows/deploy-cloudflare.yml`).

### macOS (Desktop)

Voraussetzungen: Mac mit Xcode und CocoaPods.

```bash
flutter build macos --release
cp -r build/macos/Build/Products/Release/attendix.app /Applications/
open /Applications/attendix.app
```

Bekannte Eigenheiten:
- **Xcode 27:** Das Deployment-Target muss mindestens **macOS 12.0** sein. Im Repo steht noch 10.15 (`macos/Podfile` und `MACOSX_DEPLOYMENT_TARGET` in `macos/Runner.xcodeproj`), das muss lokal auf 12.0 angehoben werden.
- **Nur arm64:** Der Universal-Build (x86_64 + arm64) scheitert unter Xcode 27 an der Architektur-Prüfung. Für Apple-Silicon-Macs nur arm64 bauen (z. B. in Xcode unter *Build Settings → Architectures* bzw. `ARCHS = arm64`).
- `macos/Runner/Release.entitlements` braucht `com.apple.security.network.client`, sonst hat die App kein Netzwerk (ist bereits gesetzt).

### iOS

Voraussetzungen: Mac mit Xcode und CocoaPods, Apple-Developer-Account.

1. `ios/Runner.xcworkspace` in Xcode öffnen und unter *Runner → Signing & Capabilities* das eigene **Apple-Team** wählen. Bundle-ID ist `de.attendix.attendix`; mit einem anderen Team muss die Bundle-ID ggf. angepasst werden.
2. Bauen und installieren:
   ```bash
   flutter build ios --release
   flutter devices                               # Device-ID finden
   xcrun devicectl device install app --device <DEVICE-ID> build/ios/iphoneos/Runner.app
   ```
   Alternativ direkt `flutter run --release -d <DEVICE-ID>`.

Hinweise:
- Auf dem iPhone muss der Entwicklermodus an sein (*Einstellungen → Datenschutz & Sicherheit → Entwicklermodus*). Beim ersten Mal das Zertifikat unter *Einstellungen → Allgemein → VPN & Geräteverwaltung* vertrauen.
- Debug-Builds starten nur über Flutter oder Xcode. Für eine App, die eigenständig startet, immer `--release` bauen.
- Mindestversion ist iOS 15.0.
- Push braucht `ios/Runner/GoogleService-Info.plist` aus Firebase (nicht im Repo, siehe [docs/push-setup.md](docs/push-setup.md)). Ohne die Datei läuft die App, nur ohne Push. Live Activities: [docs/live-activity-setup.md](docs/live-activity-setup.md).

### Android

Voraussetzungen: **Java 17** (JDK) und das **Android-SDK** (z. B. über Android Studio), `ANDROID_HOME` gesetzt bzw. `flutter config --android-sdk <pfad>`.

```bash
flutter build apk --release                   # APK nach build/app/outputs/flutter-apk/
flutter install                               # auf ein per USB verbundenes Gerät
```

Hinweise:
- Auf dem Gerät USB-Debugging aktivieren (*Entwickleroptionen*).
- Der Release-Build wird derzeit mit dem Debug-Schlüssel signiert. Das reicht zum Testen, für den Play Store braucht es eine eigene Signing-Konfiguration in `android/app/build.gradle.kts`.
- Push braucht `android/app/google-services.json` aus Firebase (nicht im Repo, siehe [docs/push-setup.md](docs/push-setup.md)). Ohne die Datei baut und läuft die App, nur ohne Push; Gradle gibt dann eine Warnung aus.

### Windows / Linux

Die Projektordner `windows/` und `linux/` existieren (`flutter build windows` bzw. `flutter build linux`), diese Ziele werden aber nicht getestet.

## Entwicklung

```bash
dart analyze lib/     # Code analysieren
flutter test          # Tests
```

Weitere Hinweise für Entwickler stehen in [CLAUDE.md](CLAUDE.md) und unter [docs/](docs/).
