# Fix-Paket „nativ“

Soll: Ionic 4.19.7 (9f9b82af). Ist: Flutter 1aba6be,  (normales Design).
Erzeugt mit `node tool/parity/parity.mjs fixlists` aus `docs/parity/status/`. Item-IDs siehe `ionic-inventory.json`.

## Angleichen (hoch/mittel): 11

- [ ] **hoch** `native/android` [android/app/build.gradle:10](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/app/build.gradle#L10)
  Ionic: versionCode 228 / versionName 4.19.7 fest in build.gradle / Flutter: versionCode = flutter.versionCode aus pubspec 0.38.1+107 → ohne --build-number > 228 lehnt Play den Upload ab (Code muss steigen), Nutzer sähen Version 0.38.1. docs/push-setup.md nennt noch Ionic 4.19.6/227 und empfiehlt --build-number 228 – genau dieser Code ist mit Ionic 4.19.7 bereits vergeben.
  Flutter: pubspec.yaml:4, android/app/build.gradle.kts:40, docs/push-setup.md:23
- [ ] **hoch** `native/config` [src/app/services/base/supabase.ts:8](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/base/supabase.ts#L8)
  Ionic: Supabase-Session (persistSession) und lokale Einstellungen (localStorage/Ionic Storage, z. B. push_prompt_shown, gewählte Gruppe) liegen im WebView-Speicher / Flutter: Session in SharedPreferences/Keychain über supabase_flutter, keine Übernahme aus dem WebView-Speicher → nach dem Store-Update sind alle Nutzer abgemeldet, die Push-Abfrage erscheint erneut, lokale Einstellungen sind weg.
  Flutter: lib/core/config/supabase_config.dart:26
- [ ] **hoch** `native/ios` [ios/App/App.xcodeproj/project.pbxproj:465](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/ios/App/App.xcodeproj/project.pbxproj#L465)
  Ionic: MARKETING_VERSION 4.19.7, CURRENT_PROJECT_VERSION 237 (Release) / Flutter: $(FLUTTER_BUILD_NAME)/$(FLUTTER_BUILD_NUMBER) aus pubspec = 0.38.1 (107) → App Store Connect nimmt keine Version unter der freigegebenen 4.19.7 an; nur per --build-name ≥ 5.0.0 korrigierbar (Build-Nummer gilt je Versionszug).
  Flutter: ios/Runner/Info.plist:37, ios/Runner.xcodeproj/project.pbxproj:615, pubspec.yaml:4
- [ ] **mittel** `native/android` [android/app/src/main/AndroidManifest.xml:17](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/app/src/main/AndroidManifest.xml#L17)
  Ionic: launchMode=singleTask (immer genau eine Instanz im eigenen Task) / Flutter: launchMode=singleTop + taskAffinity="" → App-Links (https://attendix.de) oder attendix://-Links aus Apps, die ohne FLAG_ACTIVITY_NEW_TASK starten, öffnen eine zweite App-Instanz im Task der fremden App (zweite Engine, anderes Zurück-Verhalten).
  Flutter: android/app/src/main/AndroidManifest.xml:14, android/app/src/main/AndroidManifest.xml:15
- [ ] **mittel** `native/android` [android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml#L7)
  Ionic: Vordergrund = komplettes Icon (türkise Fläche + Logo, mipmap ic_launcher_foreground) mit 16,7 % Inset auf weißem Hintergrund → Logo füllt ca. 78 % der sichtbaren Icon-Höhe / Flutter: transparentes Logo (drawable ic_launcher_foreground) mit 16 % Inset auf Farbe #3EA5AE → Logo nur ca. 58 % der Höhe; Türkis gleich, Logo auf dem Homescreen (Android 8+) sichtbar kleiner.
  Flutter: android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml:6, pubspec.yaml:177
- [ ] **mittel** `native/android` [android/app/src/main/res/drawable/splash_screen.xml:5](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/app/src/main/res/drawable/splash_screen.xml#L5)
  Ionic: Launch-Theme AppTheme.NoActionBarLaunch mit windowBackground splash_screen (Weiß + zentriertes App-Logo splash_icon), sichtbar bis die WebView zeichnet / Flutter: Template-launch_background ohne Bild (weiß bzw. ?android:colorBackground, im Nachtmodus dunkel) → vor dem ersten Frame leerer Bildschirm; ab Android 12 nur der System-Splash mit Launcher-Icon.
  Flutter: android/app/src/main/res/drawable-v21/launch_background.xml:4, android/app/src/main/res/values/styles.xml:7
- [ ] **mittel** `native/android` [supabase/functions/_shared/send-push.ts:140](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/supabase/functions/_shared/send-push.ts#L140)
  Ionic: legt keinen Kanal 'default' an und hat kein default_notification_channel_id; send-push.ts sendet channel_id 'default' → FCM nutzt seinen Fallback-Kanal ('Sonstiges', Wichtigkeit Standard, kein Heads-up) / Flutter: MainActivity legt 'default' "Benachrichtigungen" mit IMPORTANCE_HIGH an (+ Manifest-Default) → Pushes erscheinen jetzt als Heads-up-Banner; Nutzer-Einstellungen am alten Kanal (z. B. stumm) gelten nicht mehr.
  Flutter: android/app/src/main/kotlin/io/stephanus/attendix/MainActivity.kt:55, android/app/src/main/AndroidManifest.xml:84
- [ ] **mittel** `native/android` [android/app/src/main/AndroidManifest.xml:56](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/app/src/main/AndroidManifest.xml#L56)
  Ionic: keine CAMERA-Berechtigung, Fotos nur über System-Picker / Flutter: mobile_scanner 7.4.3 (QR-Scan) bringt android.permission.CAMERA über sein Plugin-Manifest mit (Plugin-Quelle nicht im Repo, im gemergten Manifest prüfen); ohne <uses-feature android:name="android.hardware.camera" android:required="false"/> leitet Play eine Pflicht-Kamera ab → Geräte ohne Rückkamera (Tablets, Chromebooks) bekommen das Update nicht mehr; neue Berechtigung im Store-Eintrag.
  Flutter: pubspec.yaml:104, android/app/src/main/AndroidManifest.xml:90
- [ ] **mittel** `native/config` [capacitor.config.json:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/capacitor.config.json#L7)
  Ionic: capacitor.config.json PushNotifications.presentationOptions [badge, sound, alert] → bei offener App System-Banner + Ton + Badge-Zahl, zusätzlich In-App-Alert / Flutter: setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: true) → nur Ton + In-App-Alert, kein Banner, Badge wird im Vordergrund nicht gesetzt (laut Kommentar bewusst).
  Flutter: lib/core/services/push/firebase_push_messaging_client.dart:43
- [ ] **mittel** `native/ios` [ios/App/App/Base.lproj/LaunchScreen.storyboard:15](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/ios/App/App/Base.lproj/LaunchScreen.storyboard#L15)
  Ionic: LaunchScreen.storyboard zeigt Bild 'Splash' (Logo auf Weiß, Dark-Variante auf #1E1E1E) / Flutter: Template-Storyboard mit LaunchImage = 1×1 transparenter Platzhalter auf fest weißem Hintergrund → beim Start leerer weißer Bildschirm, auch im Dark Mode.
  Flutter: ios/Runner/Base.lproj/LaunchScreen.storyboard:19, ios/Runner/Base.lproj/LaunchScreen.storyboard:22, ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json:1
- [ ] **mittel** `native/ios` [ios/App/App/Info.plist:65](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/ios/App/App/Info.plist#L65)
  Ionic: Kamera 'Wird benötigt um ein Passbild aufzunehmen.', Fotos 'Wird benötigt um ein Passbild aus der Fotobibliothek auszuwählen.', Fotos sichern 'Wird benötigt um Fotos zu speichern.' / Flutter: 'Attendix nutzt die Kamera, um Fotos für Anwesenheiten aufzunehmen und QR-Codes von Einladungen zu scannen.', 'Attendix greift auf deine Fotos zu, wenn du ein Bild auswählst, zum Beispiel ein Profilbild.', 'Attendix speichert Fotos nur, wenn du das selbst auslöst.' Inhaltlich begründet (QR-Scan, Anwesenheitsfotos), aber im System-Dialog sichtbar anders.
  Flutter: ios/Runner/Info.plist:9, ios/Runner/Info.plist:13, ios/Runner/Info.plist:15

## Flutter besser – Leon entscheidet: 0


## Kleinigkeiten (niedrig): 18

- [ ] **niedrig** `native/ios` [ios/App/App/Info.plist:65](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/ios/App/App/Info.plist#L65)
  Ionic: kein NSMicrophoneUsageDescription/NSAppleMusicUsageDescription / Flutter: beide vorhanden ('Attendix nimmt keinen Ton auf …', 'Attendix greift nur auf deine Mediathek zu, wenn du selbst eine Audiodatei auswählst.'); erscheinen nur, falls ein Plugin die Berechtigung anfragt.
  Flutter: ios/Runner/Info.plist:7, ios/Runner/Info.plist:11
- [ ] **niedrig** `native/android` [android/app/src/main/AndroidManifest.xml:8](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/app/src/main/AndroidManifest.xml#L8)
  Ionic: android:roundIcon=@mipmap/ic_launcher_round (+ PNGs je Dichte) / Flutter: nur android:icon → Launcher auf Android 7.1, die runde Icons verwenden, zeigen das eckige Icon.
  Flutter: android/app/src/main/AndroidManifest.xml:10
- [ ] **niedrig** `native/android` [android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png:1](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png#L1)
  Ionic: mipmap ic_launcher.png = türkises Quadrat mit weißem Rand und transparenten Ecken / Flutter: randloses türkises Quadrat (flutter_launcher_icons); betrifft nur API 24/25 ohne adaptive Icons.
  Flutter: android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png:1, pubspec.yaml:175
- [ ] **niedrig** `native/ios` [ios/App/App/Assets.xcassets/AppIcon.appiconset/Contents.json:5](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/ios/App/App/Assets.xcassets/AppIcon.appiconset/Contents.json#L5)
  Ionic: AppIcon-512@2x.png (eine 1024er-Datei, mit dünner Linie am oberen Rand) / Flutter: neu gerendertes app_icon.png (1024 + alle Einzelgrößen), gleiches Motiv und Farbe, Logo leicht anders gezeichnet (mittlere Pixeldifferenz ca. 3 %).
  Flutter: ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json:1, pubspec.yaml:175
- [ ] **niedrig** `native/ios` [ios/App/App.xcodeproj/project.pbxproj:454](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/ios/App/App.xcodeproj/project.pbxproj#L454)
  Ionic: nur AppIcon / Flutter: vier alternative Icons (Konzertsaal, Nachtblau, Klar, Bühne) per setAlternateIconName wählbar; nur auf Nutzerwunsch, iOS zeigt dabei einen Systemhinweis.
  Flutter: ios/Runner.xcodeproj/project.pbxproj:611, ios/Runner/AppDelegate.swift:26
- [ ] **niedrig** `native/android` [android/variables.gradle:2](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/variables.gradle#L2)
  Ionic: minSdk 24, compileSdk 36, targetSdk 36 fest (variables.gradle) / Flutter: flutter.minSdkVersion/compileSdkVersion/targetSdkVersion → hängen von der Flutter-Version ab (CI 3.47.9), hier ohne SDK nicht prüfbar; sollten ≥ 24/36/36 sein.
  Flutter: android/app/build.gradle.kts:38, android/app/build.gradle.kts:39
- [ ] **niedrig** `native/android` [android/app/src/main/AndroidManifest.xml:56](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/app/src/main/AndroidManifest.xml#L56)
  Ionic: android.permission.INTERNET explizit im App-Manifest / Flutter: nur im debug-/profile-Manifest; Release erhält sie allein per Manifest-Merge aus Plugin-Bibliotheken (u. a. firebase-messaging).
  Flutter: android/app/src/main/AndroidManifest.xml:4, android/app/src/debug/AndroidManifest.xml:6
- [ ] **niedrig** `native/android` [package.json:47](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/package.json#L47)
  Ionic: @capacitor/haptics bringt android.permission.VIBRATE per Plugin-Manifest mit / Flutter: HapticFeedback braucht keine Berechtigung, VIBRATE fehlt im Store-Eintrag (Wegfall einer normalen Berechtigung, unkritisch).
  Flutter: android/app/src/main/AndroidManifest.xml:4
- [ ] **niedrig** `native/android` [android/app/src/main/AndroidManifest.xml:45](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/app/src/main/AndroidManifest.xml#L45)
  Ionic: androidx FileProvider ${applicationId}.fileprovider (file_paths: external + cache) im App-Manifest / Flutter: keiner im App-Manifest; share_plus, open_filex, image_picker bringen eigene Provider mit anderen Authorities mit. Für Nutzer unsichtbar.
  Flutter: android/app/src/main/AndroidManifest.xml:7
- [ ] **niedrig** `native/android` [package.json:55](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/package.json#L55)
  Ionic: @capgo/capacitor-media-session (Service/Receiver aus dem Plugin) / Flutter: audio_service mit AudioService (exported, MediaBrowserService) + MediaButtonReceiver (exported) und eigenem Kanal 'de.attendix.attendix.audio' "Audio"; Medientasten/Bluetooth können die Wiedergabe fortsetzen.
  Flutter: android/app/src/main/AndroidManifest.xml:63, lib/core/services/audio_player/media_session_native.dart:41
- [ ] **niedrig** `native/android` [capacitor.config.json:6](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/capacitor.config.json#L6)
  Ionic: @capacitor/push-notifications legt wegen presentationOptions 'PushDefaultForegroundChannel' ("Push Notifications Foreground") an, dazu der FCM-Fallback-Kanal / Flutter: löscht sie nicht → nach dem Update stehen die alten (englischen) Kanäle neben 'Benachrichtigungen' in den App-Einstellungen.
  Flutter: android/app/src/main/kotlin/io/stephanus/attendix/MainActivity.kt:50
- [ ] **niedrig** `native/android` [android/app/src/main/java/io/stephanus/attendix/liveplan/LivePlanNotifications.java:55](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/app/src/main/java/io/stephanus/attendix/liveplan/LivePlanNotifications.java#L55)
  Ionic: Kanalname und Texte der Ablaufplan-Benachrichtigung fest deutsch / Flutter: values-en/strings.xml → auf englisch eingestellten Geräten 'Running schedule', 'Next: …', 'Item x of y'; Push-Kanal 'Notifications'.
  Flutter: android/app/src/main/res/values-en/strings.xml:4
- [ ] **niedrig** `native/ios` [ios/App/App/Info.plist:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/ios/App/App/Info.plist#L7)
  Ionic: CFBundleDevelopmentRegion en, keine CFBundleLocalizations → System-Texte im App-Kontext (Kopieren/Einsetzen, Picker-Buttons) englisch, App Store listet Englisch / Flutter: developmentRegion de + CFBundleLocalizations de, en → System-Texte deutsch, App-Store-Sprachen Deutsch und Englisch, iOS-Einstellungen bieten eine App-Sprache an (Verbesserung).
  Flutter: ios/Runner/Info.plist:19, ios/Runner.xcodeproj/project.pbxproj:328
- [ ] **niedrig** `native/config` [capacitor.config.json:13](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/capacitor.config.json#L13)
  Ionic: @capawesome/capacitor-live-update (publicKey, autoDeleteBundles, Kanal 'production' in Info.plist und resValue) liefert Web-Bundles ohne Store-Release / Flutter: keine OTA-Updates, nur Store-Updates (+ in_app_update/Store-Versionscheck). Für Nutzer kaum sichtbar, Fixes brauchen künftig einen Store-Release.
  Flutter: pubspec.yaml:99
- [ ] **niedrig** `native/android` [android/app/src/main/AndroidManifest.xml:13](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/android/app/src/main/AndroidManifest.xml#L13)
  Ionic: configChanges ohne fontScale/density/layoutDirection, supportsRtl=true, windowSoftInputMode nicht gesetzt, kein <queries>, Namespace io.stephanus.attendix, Java 21 / Flutter: configChanges inkl. fontScale/density/layoutDirection (kein Activity-Neustart bei Schriftgröße), kein supportsRtl, windowSoftInputMode=adjustResize, hardwareAccelerated, <queries> PROCESS_TEXT, Kotlin-Namespace de.attendix.attendix, Java 11. Ohne sichtbare Wirkung.
  Flutter: android/app/src/main/AndroidManifest.xml:17, android/app/src/main/AndroidManifest.xml:19, android/app/src/main/AndroidManifest.xml:103
- [ ] **niedrig** `native/ios` [ios/App/App/Info.plist:80](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/ios/App/App/Info.plist#L80)
  Ionic: CFBundleName/Executable 'App', UIRequiredDeviceCapabilities armv7, Scene mit UISceneStoryboardFile Main / Flutter: CFBundleName 'attendix', Executable 'Runner', keine UIRequiredDeviceCapabilities (Entfernen ist bei Updates erlaubt), CADisableMinimumFrameDurationOnPhone (120 Hz), UIApplicationSupportsIndirectInputEvents, Fenster per SceneDelegate im Code. Ohne sichtbare Wirkung.
  Flutter: ios/Runner/Info.plist:32, ios/Runner/Info.plist:78, ios/Runner/AppDelegate.swift:101
- [ ] **niedrig** `native/ios` [ios/App/App/AppRelease.entitlements:9](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/ios/App/App/AppRelease.entitlements#L9)
  Ionic: kein Kommentar, AASA muss MXM3YWAKPL.io.stephanus.attendix listen / Flutter: Kommentar in Runner.entitlements verlangt WJ62LFJT38.de.attendix.attendix in der apple-app-site-association – veraltet (Team MXM3YWAKPL, Bundle io.stephanus.attendix); wer danach die AASA anpasst, bricht die Universal Links. Konfiguration selbst ist korrekt.
  Flutter: ios/Runner/Runner.entitlements:11
- [ ] **niedrig** `native/config` [capacitor.config.json:1](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/capacitor.config.json#L1)
  Android: applicationId io.stephanus.attendix, Launcher-Activity-Klasse io.stephanus.attendix.MainActivity (Homescreen-Verknüpfungen bleiben), App-/Activity-Label 'Attendix', exported=true; App-Links https://attendix.de mit autoVerify (Host ohne Pfadfilter); Intent-Filter attendix://live-plan; LivePlanMessagingService (MESSAGING_EVENT, Priorität 10, exported=false, ersetzt den Plugin-Service per tools:node=remove); Berechtigungen POST_NOTIFICATIONS, POST_PROMOTED_NOTIFICATIONS, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK (WAKE_LOCK kam in Ionic über Firebase); keine Speicher-/Medien-Berechtigungen (in Flutter aktiv entfernt; ob file_picker 8.3.7 auf Android ≤ 12 ohne READ_EXTERNAL_STORAGE auskommt, hier nicht prüfbar); allowBackup=true (Flutter-Default), keine Backup-/Data-Extraction-Regeln, keine network_security_config, kein Cleartext; Ablaufplan-Kanal 'live_plan' 'Laufender Ablaufplan' IMPORTANCE_DEFAULT ohne Ton/Vibration/Badge, Small-Icon ic_stat_live_plan identisch, Farbe aus Termin-Typ, Tap-Intent attendix://live-plan?attendance=&plan= (NEW_TASK|SINGLE_TOP, IMMUTABLE), gleiche Notification-IDs/Tag 'live-plan'/Prefs 'live_plan_titles', Promoted-Ongoing-Extra; Push ohne eigenes Small-Icon/Farbe in beiden; Ausrichtung frei; google-services-Plugin bedingt wie Ionic; App-Links-Prüfung über Play App Signing unverändert. iOS: Bundle-ID, Team MXM3YWAKPL, Anzeigename 'Attendix', Deployment-Target 15.0 (Widget 16.2), iPhone+iPad, Orientierungen je Gerät identisch, URL-Schema attendix (CFBundleURLName io.stephanus.attendix), keine LSApplicationQueriesSchemes (Flutter verzichtet auf canLaunchUrl), UIBackgroundModes audio+remote-notification, NSSupportsLiveActivities + FrequentUpdates, ITSAppUsesNonExemptEncryption=false, kein UIFileSharingEnabled/LSSupportsOpeningDocumentsInPlace, Statusleiste VC-basiert, UIScene-Manifest ohne Mehrfenster; Entitlements aps-environment + applinks:attendix.de, keine App Groups/webcredentials/time-sensitive (beide); Live-Activity-Widget (Attribute, ContentState, Farben, Layout, widgetURL attendix://live-plan, Info.plist 'Attendix Live', Bundle-ID .LiveActivity, eingebettet) byte-identisch, Token-Reporter/Push-to-Start beim App-Start; PrivacyInfo.xcprivacy in Ionic nicht im Target, in Flutter keine – effektiv gleich. Config: Badge persist=false/autoClear=true → app_badge_plus updateBadge(0) bei Start, Tap und Resume; Push-Berechtigung alert/badge/sound; Keyboard ohne Config (iOS native Resize) ≈ Flutter adjustResize/viewInsets; StatusBar/SplashScreen ohne Config bzw. nicht genutzt; Android-Vordergrund-Push in beiden nur In-App-Alert; Audio-Session Playback (Ionic AppDelegate) ≈ Flutter AudioSessionConfiguration.music().
  Flutter: android/app/src/main/AndroidManifest.xml:1, ios/Runner/Info.plist:1
