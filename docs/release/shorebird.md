# Shorebird Code Push (OTA-Updates) für iOS und Android

Ersatz für die Ionic-Live-Updates: Die Store-Apps (`io.stephanus.attendix`)
werden mit Shorebird gebaut. Danach lassen sich reine Dart-Änderungen ohne
Store-Review als **Patch** ausliefern. Web ist nicht betroffen (die PWA
aktualisiert sich selbst).

**Verhalten in der App:** `auto_update: true` in `shorebird.yaml`. Ein Patch
wird beim App-Start still im Hintergrund geladen und gilt ab dem nächsten
Start. Kein Hinweis, kein Neustart während der Nutzung. Die laufende
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
keine Patches an. Build-Argumente und Dart-Defines wie bisher beim
`flutter build` mitgeben (nach `--`).

```bash
# Android → AAB (build/app/outputs/bundle/release/app-release.aab)
shorebird release android --flutter-version=3.47.9 -- <bisherige Build-Argumente>

# iOS → IPA (build/ios/ipa/)
shorebird release ios --flutter-version=3.47.9 -- <bisherige Build-Argumente>
```

Danach AAB bzw. IPA wie gewohnt in Play Console / App Store Connect hochladen.

## Patch ausliefern

Nur für Änderungen an Dart-Code und Assets (siehe Grenzen).

```bash
shorebird patch android
shorebird patch ios
# gezielt für einen bestimmten Release-Build:
shorebird patch android --release-version=5.0.0+<build>
shorebird patch ios --release-version=5.0.0+<build>
```

Gleiche Build-Argumente/Dart-Defines wie beim Release verwenden. Version und
Build-Nummer in `pubspec.yaml` nicht ändern, sonst passt der Patch nicht zum
Release.

## Grenzen

- Patches können nur **Dart-Code und Assets** ändern.
- Ein **Store-Update** brauchen: native Änderungen (Swift/Kotlin, Gradle,
  Xcode-Projekt), neue oder aktualisierte Plugins bzw. Pubspec-Pakete mit
  nativem Code, `Info.plist`, `AndroidManifest.xml`, Berechtigungen,
  Entitlements, App-Icon/Splash.
- Ein Patch gilt nur für den **exakt passenden Release-Build**
  (Version + Build-Nummer). Für jeden neuen Store-Build erneut
  `shorebird release` ausführen.

## Rollback

In der Shorebird-Konsole den Patch zurückziehen (Rollback) oder per CLI
(`shorebird patches …`, siehe `shorebird patches --help`). Geräte mit dem
zurückgezogenen Patch fallen beim nächsten Update-Check auf den vorherigen
Stand zurück.
