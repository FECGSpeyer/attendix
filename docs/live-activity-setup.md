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

The widget extension target `AttendixLiveActivity` is in `Runner.xcodeproj`
(added with the `xcodeproj` gem, November 2026). `PlanActivityAttributes.swift` is
compiled into both targets.

## 1. Widget extension target (done, for reference)

- Sources: `AttendixLiveActivityBundle.swift`, `PlanLiveActivity.swift`,
  `PlanActivityAttributes.swift` (also in Runner), `Info.plist`.
- `PRODUCT_BUNDLE_IDENTIFIER` = `de.attendix.attendix.LiveActivity`,
  `IPHONEOS_DEPLOYMENT_TARGET` = `16.2`, `SWIFT_VERSION` = `5.0`, `TARGETED_DEVICE_FAMILY` = `1,2`.
- `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` = `$(FLUTTER_BUILD_NAME)` /
  `$(FLUTTER_BUILD_NUMBER)`. The base configuration is `Flutter/Generated.xcconfig`, so the
  values match the app (App Store rejects mismatches).
- Signing: team `MXM3YWAKPL`, automatic. Frameworks: `WidgetKit`, `SwiftUI`.
- Runner build phases: *Embed Foundation Extensions* sits directly after *Resources*,
  before *Thin Binary* (otherwise Flutter reports a "Cycle inside Runner").

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

## Android

The Android live notification (Ionic `LiveActivityPlugin.java`) is ported:
`android/app/src/main/kotlin/de/attendix/attendix/liveplan/*` plus the Android branch of
`lib/core/services/live_activity_service.dart` (updates via `live_plan` data pushes).
