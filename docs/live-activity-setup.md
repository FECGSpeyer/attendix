# Live Activity (iOS): manual Xcode setup

The Flutter app ports the Ionic Live Activity / Dynamic Island for running Ablaufpläne.
Everything that can be done without Xcode is in the repo already:

| Part | Where |
|------|-------|
| Dart service (sync loop every 20 s, token registration, deep link) | `lib/core/services/live_activity_service.dart` |
| Schedule / state logic (port of `live-plan-state.ts`) | `lib/core/utils/live_plan.dart` |
| Supabase access (`attendance`, `notifications.live_activity`, `live_activity_tokens`) | `lib/data/repositories/live_activity_repository.dart` |
| Settings toggle "Laufender Ablaufplan" | Einstellungen → Benachrichtigungen (iOS app only) |
| Native MethodChannel `de.attendix/live_activity` | `ios/Runner/LiveActivityPlugin.swift` (already in the Runner target) |
| Plugin registration + token observer at launch | `ios/Runner/AppDelegate.swift` (marked `// LIVE_ACTIVITY`) |
| `NSSupportsLiveActivities`, `NSSupportsLiveActivitiesFrequentUpdates`, URL scheme `attendix` | `ios/Runner/Info.plist` |
| Widget extension sources (copied 1:1 from Ionic) | `ios/AttendixLiveActivity/` |

`ios/AttendixLiveActivity/PlanActivityAttributes.swift` is already compiled into the
**Runner** target. The widget extension target itself is **not** in
`Runner.xcodeproj` yet, because hand-editing a new target into the project file is
error-prone. Until you add it, the app builds and runs, but iOS has no UI to show the
activity, so `Activity.request` produces nothing visible.

## 1. Add the widget extension target

1. Open `ios/Runner.xcworkspace` in Xcode.
2. File → New → Target… → **Widget Extension**.
   - Product Name: `AttendixLiveActivity`
   - Check **Include Live Activity**. Uncheck *Include Configuration App Intent*.
   - Embed in Application: **Runner**.
   - When Xcode asks to activate the scheme, choose *Activate*.
3. Xcode creates a folder `ios/AttendixLiveActivity` with template files. Delete the
   template Swift files Xcode generated (choose *Move to Trash*), but keep the folder.
   Keep the 4 files from the repo: `AttendixLiveActivityBundle.swift`,
   `PlanLiveActivity.swift`, `PlanActivityAttributes.swift`, `Info.plist`.
   If Xcode overwrote `Info.plist`, run `git checkout ios/AttendixLiveActivity/Info.plist`.
4. Make sure these files are in the target (File inspector → Target Membership):
   - `AttendixLiveActivityBundle.swift` → AttendixLiveActivity
   - `PlanLiveActivity.swift` → AttendixLiveActivity
   - `PlanActivityAttributes.swift` → **AttendixLiveActivity and Runner** (both!)
5. Build settings of the **AttendixLiveActivity** target:
   - `PRODUCT_BUNDLE_IDENTIFIER` = `de.attendix.attendix.LiveActivity`
   - `INFOPLIST_FILE` = `AttendixLiveActivity/Info.plist`
   - `IPHONEOS_DEPLOYMENT_TARGET` = `16.2` (same as Ionic)
   - `SWIFT_VERSION` = `5.0`, `TARGETED_DEVICE_FAMILY` = `1,2`
   - `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`: set them to `$(FLUTTER_BUILD_NAME)`
     and `$(FLUTTER_BUILD_NUMBER)` so they match the app (App Store rejects mismatches).
   - Signing: same team as Runner (`WJ62LFJT38`), automatic signing.
6. Frameworks of the extension: `WidgetKit.framework` and `SwiftUI.framework`
   (the template adds them).
7. Build Phases of **Runner**: the *Embed Foundation Extensions* phase must contain
   `AttendixLiveActivity.appex`, and it must come **before** the *Thin Binary* /
   *Run Script* phases. If Flutter complains about a "Cycle inside Runner", drag
   *Embed Foundation Extensions* directly below *Copy Bundle Resources*.

## 2. Capabilities and entitlements (Runner)

Live Activities are updated by the `live-activity-tick` Edge Function via
FCM → APNs (`apns.live_activity_token`). That needs push on the **app** target:

1. Runner → Signing & Capabilities → **+ Capability → Push Notifications**
   (adds `aps-environment` to `Runner.entitlements`; the PUSH lane may already have done this).
2. **No App Group is needed.** Ionic does not use one: the app and the extension only share
   the `PlanActivityAttributes` type, and all data reaches the widget via ActivityKit.
3. There is no separate "liveactivity" push capability in Xcode. The APNs push type
   `liveactivity` is set by the server (FCM `apns.live_activity_token`).
   Requirement: the iOS app `de.attendix.attendix` is registered in the Firebase project
   (`FIREBASE_PROJECT_ID`, default `app-attendix`) with the APNs auth key (.p8) uploaded.
   Ionic's bundle id was `io.stephanus.attendix`; if the Flutter app ships under
   `de.attendix.attendix`, add it as an additional iOS app in Firebase.
4. `Info.plist` keys are already set (`NSSupportsLiveActivities`,
   `NSSupportsLiveActivitiesFrequentUpdates`, URL scheme `attendix` for the tap on the
   activity → `attendix://live-plan?attendance=…&plan=…` → plan viewer in live mode).

## 3. Backend (already deployed for Ionic, nothing new)

- Table `live_activity_tokens`, column `notifications.live_activity`, table
  `live_activity_sent`, cron job `live-activity-tick-job`: `supabase/sql/live_activity.sql`
  in the Ionic repo.
- Edge Functions `live-activity-token` (background token upload from Swift) and
  `live-activity-tick` (push start/update/end every minute).
- The Flutter app writes the same rows as Ionic: `kind` `start`/`update`,
  `platform` `ios`, `onConflict: user_id,kind,attendance_id,plan_key`.

## 4. Test on a device

1. `flutter build ios --release` and install (see CLAUDE.md), iOS 16.2+.
2. iPhone Settings → Attendix → Live Activities on.
3. Create a Termin today with an Ablaufplan starting within the next 15 minutes
   (share the plan if you test as a player).
4. Open the app: the activity appears on the lock screen / in the Dynamic Island and
   counts down. Einstellungen → Benachrichtigungen → "Laufender Ablaufplan" off ends it.
5. Tap the activity: the app opens the plan viewer in live mode.
6. Push-to-start (iOS 17.2+, app closed) needs step 2 above. Check `live_activity_tokens`
   for a `start` row of your user.

## Not ported

- Android "live notification" (Ionic `LiveActivityPlugin.java`): the Flutter service is a
  no-op on Android.
