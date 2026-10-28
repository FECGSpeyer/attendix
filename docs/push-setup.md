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

The Flutter app currently uses the bundle ID / package name
**`de.attendix.attendix`**. Ionic uses `io.stephanus.attendix`.

- **Option A (new apps):** In the Firebase console, open *Project settings → Your apps*
  and add an **iOS app** and an **Android app** with `de.attendix.attendix`.
- **Option B (replace the store apps):** Change the Flutter IDs to
  `io.stephanus.attendix` (`PRODUCT_BUNDLE_IDENTIFIER` in
  `ios/Runner.xcodeproj`, plus `applicationId`/`namespace` in
  `android/app/build.gradle.kts`) and reuse the existing Firebase apps.

### 2. Config files (not committed, both are in `.gitignore` like in Ionic)

| File | Where | Source |
|------|-------|--------|
| `google-services.json` | `android/app/google-services.json` | Firebase → Android app → download |
| `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` | Firebase → iOS app → download |

- **Android:** placing the file is enough. `android/app/build.gradle.kts`
  applies the `com.google.gms.google-services` plugin only when the file
  exists, which is the same conditional as Ionic's `build.gradle`.
- **iOS:** open `ios/Runner.xcworkspace` in Xcode and drag
  `GoogleService-Info.plist` into the *Runner* group. Tick
  *Copy items if needed* and target *Runner*. Without that step the file is
  not in the app bundle.

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

Firebase stores the APNs key per iOS app. With option B, the existing Ionic
iOS app already has it. With option A, the new `de.attendix.attendix` app
needs it too. The team-wide `.p8` key of the Ionic app can be reused.

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
- iOS deployment target 13.0, which Firebase iOS SDK 11 requires (Podfile and
  project).

In Xcode, open *Runner → Signing & Capabilities* and check that **Push
Notifications** is listed. With automatic signing Xcode enables it on the App
ID. A free personal team cannot sign push. To build with one, temporarily
remove the `aps-environment` key.

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
