# Shorebird Code Push (OTA-Updates) für iOS und Android

Ersatz für die Ionic-Live-Updates: Die Store-Apps (`io.stephanus.attendix`)
werden mit Shorebird gebaut. Danach lassen sich reine Dart-Änderungen ohne
Store-Review als **Patch** ausliefern. Web ist nicht betroffen (die PWA
aktualisiert sich selbst).

**Verhalten in der App:** `auto_update: true` in `shorebird.yaml`. Ein Patch
wird beim App-Start still im Hintergrund geladen und gilt ab dem nächsten
Start. Zusätzlich prüft die App beim Zurückkommen aus dem Hintergrund
(höchstens alle 30 Minuten) und lädt einen neuen Patch ebenfalls still
(`checkShorebirdPatchOnResume`), sodass meist ein Neustart reicht.
Kein Hinweis, kein Neustart während der Nutzung. Die laufende
Patch-Nummer steht in den Einstellungen bei „Was ist neu“ (z. B.
`5.0.0 (Patch 2)`) und als Sentry-Tag `shorebird_patch`.

## Einrichtung (erledigt)

- Shorebird-CLI 1.6.137 auf Leons Mac unter `~/.shorebird/bin`.
- Anmeldung per `SHOREBIRD_TOKEN` in `~/.zshrc`.
- App in der Shorebird-Konsole angelegt, `app_id` siehe `shorebird.yaml`
  (nicht geheim). `shorebird.yaml` ist als Asset in `pubspec.yaml` eingetragen
  (Pflicht).
- Ein normaler `flutter build` ignoriert Shorebird; die App läuft dann
  einfach ohne Patches.

## Frischer Clone

Vor dem ersten `shorebird release` erst `flutter pub get` und einen normalen
Android-Build laufen lassen (z. B. `flutter build apk --debug`): `gradlew`
und `android/local.properties` sind gitignored und werden dabei erzeugt.

## Store-Release bauen

Der Store-Build **muss** mit `shorebird release` gebaut sein, sonst kommen
keine Patches an. Immer über `scripts/store_build.sh` bauen: Das Skript setzt
die Store-Nummern (`--build-name` = `displayVersion`, `--build-number` =
pubspec-Build + 100, siehe `docs/push-setup.md`) und ruft `shorebird release`
mit der Flutter-Version aus `.github/workflows/ci.yml` auf (überschreibbar per
`SHOREBIRD_FLUTTER_VERSION`). Weitere Argumente und Dart-Defines werden nach
`--` an `flutter build` durchgereicht.

```bash
# Android → AAB (build/app/outputs/bundle/release/app-release.aab)
scripts/store_build.sh appbundle <Dart-Defines …>
#   = shorebird release android --flutter-version=3.47.9 -- --build-name 5.0.0 --build-number 241 …

# iOS → IPA (build/ios/ipa/)
scripts/store_build.sh ipa <Dart-Defines …>
#   = shorebird release ios --flutter-version=3.47.9 -- --build-name 5.0.0 --build-number 241 …

# Android → APK (nur für Tests außerhalb des Play Store)
scripts/store_build.sh apk <Dart-Defines …>
```

### macOS (Mac App Store / TestFlight)

Die Mac-App hat dieselbe ID `io.stephanus.attendix` wie iOS (Plattform macOS
im App-Store-Connect-Eintrag „Attendix“, Universal Purchase). Ohne eigene
Mac-Version starten Apple-Silicon-Macs die iPad-App.

```bash
scripts/store_build.sh macos-release <Dart-Defines …>
#   = shorebird release macos --flutter-version=3.47.9 -- --build-name 5.0.0 --build-number 330 …
#   → build/macos/Build/Products/Release/Attendix.app
```

Shorebird liefert nur die `.app`. Für den Upload muss sie mit dem
„Apple Distribution“-Zertifikat und einem Mac-App-Store-Profil signiert und
mit dem „Mac Installer Distribution“-Zertifikat als `.pkg` verpackt werden
(`productbuild --component Attendix.app /Applications --sign "3rd Party Mac
Developer Installer: …" Attendix.pkg`), dann Upload per Transporter oder
`xcrun altool --upload-package`. **Build-Nummer nicht ändern**, sonst greifen
keine Patches. Patches für den Mac App Store gehen erst ab Shorebird 1.6.128
mit Flutter 3.47.7 (wir nutzen 3.47.9). Push und Live Activity sind auf dem
Mac aus (`hostIsNativeMobile`).

Danach AAB bzw. IPA wie gewohnt in Play Console / App Store Connect hochladen.
**Kein Xcode-Archiv** für den Store: Das wäre kein Shorebird-Release.
`scripts/store_build.sh ios|macos` baut weiter mit `flutter build` (z. B.
`ios --config-only`) und warnt, dass daraus kein Shorebird-Release entsteht.

## Patch ausliefern

Nur für Änderungen an Dart-Code und Assets (siehe Grenzen).

```bash
scripts/store_build.sh patch-android <Dart-Defines wie beim Release>
#   = shorebird patch android --release-version=5.0.0+241 -- --build-name 5.0.0 --build-number 241 …
scripts/store_build.sh patch-ios <Dart-Defines wie beim Release>
#   = shorebird patch ios --release-version=5.0.0+241 -- --build-name 5.0.0 --build-number 241 …
```

Ohne Angabe patcht das Skript den Release mit den aktuellen Store-Nummern
(`scripts/store_build.sh --print`). Sobald `pubspec.yaml` oder `displayVersion`
seit dem Store-Release erhöht wurden (bei jeder Feature-Änderung), den
Release ausdrücklich angeben, sonst findet Shorebird ihn nicht:

```bash
RELEASE_VERSION=5.0.0+241 scripts/store_build.sh patch-ios <Dart-Defines wie beim Release>
```

Gleiche Dart-Defines wie beim Release verwenden.

## Grenzen

- Patches können nur **Dart-Code und Assets** ändern.
- Ein **Store-Update** brauchen: native Änderungen (Swift/Kotlin, Gradle,
  Xcode-Projekt), neue oder aktualisierte Plugins bzw. Pubspec-Pakete mit
  nativem Code, `Info.plist`, `AndroidManifest.xml`, Berechtigungen,
  Entitlements, App-Icon/Splash.
- Ein Patch gilt nur für den **exakt passenden Release-Build**
  (Version + Build-Nummer). Für jeden neuen Store-Build erneut
  `shorebird release` ausführen.

### Wann lieber kein Patch (vor allem iOS)

Auf iOS läuft geänderter Dart-Code interpretiert, unveränderter bleibt
kompiliert. `shorebird patch ios` zeigt an, wie viel Code noch kompiliert
(„linked“) läuft; bei kleinen Fixes sind das fast 100 %.

- **Patchen:** Bugfixes, Texte, Logik einzelner Seiten, kleine UI-Anpassungen.
- **Store-Release:** Flutter-/Paket-Updates, neu generierte Freezed-Modelle,
  Umbauten an zentralem Code (Theme, Router, Basis-Widgets, Repositories),
  Änderungen in heißen Pfaden (lange Listen, Animationen, Parser) und größere
  neue Funktionen (gehören laut Apple durch das Review).
- Sinkt der „linked“-Anteil deutlich oder wirkt die App danach träger: als
  Store-Release ausliefern. Shorebird-Warnungen zu nativen Änderungen nie
  einfach bestätigen.

## Rollback

In der Shorebird-Konsole den Patch zurückziehen (Rollback) oder per CLI
(`shorebird patches …`, siehe `shorebird patches --help`). Geräte mit dem
zurückgezogenen Patch fallen beim nächsten Update-Check auf den vorherigen
Stand zurück.
