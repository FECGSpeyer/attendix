# Native push setup (iOS / Android)

The Flutter app ports the Ionic `PushService`
(`src/app/services/push/push.service.ts`). It uses the **same Firebase project
as Ionic** (`app-attendix`, the FCM v1 sender in Ionic
`supabase/functions/_shared/send-push.ts`), so the existing Edge Functions,
`device_tokens` and `notifications.push_enabled` keep working unchanged.

Push is **native only**. In the PWA every push call is a no-op, same as Ionic
(`Capacitor.isNativePlatform()`).

Without the Firebase config the app builds and runs normally. Push is then
unavailable, and in debug builds the log shows
`[push] Firebase not configured, push disabled`.

## What Leon has to provide

### 1. Register the Flutter app IDs in Firebase (project `app-attendix`)

Since November 2026 the app uses the Ionic ID **`io.stephanus.attendix`** on iOS and
Android, so it reuses the existing Ionic apps in Firebase (and the iOS APNs key). It
replaces the Ionic app on a device and ships as an update of the store app "Attendix".
Store versions must be higher than Ionic's (4.19.6, Android versionCode 227), e.g.
`--build-name 5.0.0 --build-number 228`.

**Android signing:** Play App Signing is active, so Play only needs our *upload* key.
Put it in `android/key.properties` (gitignored, never commit):

```properties
storeFile=/absolute/path/to/upload.jks
storePassword=...
keyAlias=...
keyPassword=...
```

Without that file the release build is signed with the debug key. Such an APK
cannot replace the Play Store Ionic app on a device (uninstall it first) and
App Links to attendix.de are not verified.

### 2. Config files (not committed, both are in `.gitignore` like in Ionic)

| File | Where | Source |
|------|-------|--------|
| `google-services.json` | `android/app/google-services.json` | Firebase → Android app → download |
| `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` | Firebase → iOS app → download |

- **Android:** placing the file is enough. `android/app/build.gradle.kts`
  applies the `com.google.gms.google-services` plugin only when the file
  exists, which is the same conditional as Ionic's `build.gradle`.
- **iOS:** placing the file is enough. The Runner build phase
  *Copy GoogleService-Info.plist* copies it into the app bundle when it exists.

**Alternative without files (CI):** pass the options with `--dart-define`.
They are read by `lib/core/config/firebase_options.dart`:

```bash
flutter build ipa \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_IOS_APP_ID=1:...:ios:... \
  --dart-define=FIREBASE_ANDROID_APP_ID=1:...:android:...
# optional: FIREBASE_PROJECT_ID (default app-attendix), FIREBASE_IOS_BUNDLE_ID,
#           FIREBASE_STORAGE_BUCKET
```

Android still needs `google-services.json` for the default FCM sender
resources. Prefer the files.

### 3. APNs key in Firebase (iOS)

Firebase stores the APNs key per iOS app. The existing Ionic iOS app
`io.stephanus.attendix` already has it, so nothing is needed for iOS. An APNs key
belongs to the whole team, so a new app ID could reuse it.

Apple Developer → *Keys* → use the existing key, or create one with **Apple
Push Notifications service (APNs)** → download the `.p8`. Then in Firebase →
*Project settings → Cloud Messaging → Apple app configuration*, upload the
APNs auth key with its Key ID and Team ID for the iOS app.

### 4. Xcode capability (iOS)

The repo already contains:
- `ios/Runner/Runner.entitlements` with `aps-environment` (as in Ionic
  `AppRelease.entitlements`). It is referenced via `CODE_SIGN_ENTITLEMENTS`
  for Debug, Release and Profile.
- `Info.plist` → `UIBackgroundModes` → `remote-notification` (as in Ionic).
- iOS deployment target 15.0 (Podfile, a post_install override for all pods,
  and the project). Firebase iOS SDK 11 needs 13.0, and current Xcode only
  accepts 15.0 or higher.

In Xcode, open *Runner → Signing & Capabilities* and check that **Push
Notifications** is listed. With automatic signing Xcode enables it on the App
ID. A free personal team cannot sign push ("Personal development teams …
do not support the Push Notifications capability"). To build with one, remove
the three `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` lines from
`ios/Runner.xcodeproj/project.pbxproj` locally (don't commit that).

If `pod install` fails with `Encoding::CompatibilityError`, set a UTF-8 locale
first: `export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`.

Then run `cd ios && pod install`, or just `flutter build ios`.

### 5. Android

Nothing else is needed. The manifest has `POST_NOTIFICATIONS` (Android 13+ runtime
permission, asked by the in-app prompt) and the default channel `default`.
`send-push.ts` sends `channel_id: 'default'`. `MainActivity` creates that channel
under the name "Benachrichtigungen" ("Notifications" in English).

## Behaviour (Ionic parity)

| Ionic | Flutter |
|-------|---------|
| `SIGNED_IN` → `promptAndEnable()` | `pushBootstrapProvider` (auth `signedIn` + restored `initialSession`) |
| Alert "Push-Benachrichtigungen" / "Möchtest du Push-Benachrichtigungen aktivieren? …" (Später / Aktivieren), `localStorage push_prompt_shown` | Same dialog (`svc.*` keys), SharedPreferences `push_prompt_shown`, shown once inside the app shell |
| `saveToken`: delete token of other users, delete other tokens of this user, upsert `{user_id, token, platform, updated_at}` | `DeviceTokenRepository.saveToken` (same three queries) |
| Logout → `removeToken()` (+ FCM `deleteToken` on iOS) | `removePushTokenBeforeSignOut(ref)` before `auth.signOut()` (settings + tenant selection), plus a fallback on `signedOut` |
| Tenant switch | No token change, because tokens are per user (same as Ionic) |
| Foreground push → alert (title / body, OK / Anzeigen), `push_received` | Same dialog, `TrackingEvent.pushReceived`. `live_plan` pushes stay silent |
| Tap → clear badge, `push_opened`, wait for startup redirect, tenant switch, mark matching feed entries read, navigate by `type` / `route` | `PushService.onNotificationTapped` → `RiverpodPushHost.navigateFromData` + `resolvePushTarget` |
| `navigateToAttendance`: conductors/helpers → Termin, parents → portal, others → Meine Termine (`pendingAttendanceId`) | `attendancePushTarget` + `pendingAttendanceIdProvider` |
| `@capawesome/capacitor-badge`: `Badge.clear()` on init and on tap, `autoClear` on resume | `app_badge_plus` `updateBadge(0)` on init, on tap and on app resume |
| Settings → Benachrichtigungen → "Push-Benachrichtigungen" toggle (native only) | Same toggle in `NotificationsPage` (native only) → `togglePush` |

Not ported: the Live Activity / live plan notifications (native Swift/Java
code in Ionic). The iOS foreground system banner is suppressed. Only the
in-app alert is shown, together with the sound.
