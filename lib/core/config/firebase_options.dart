// PUSH: Firebase configuration for native push (iOS/Android).
//
// Attendix uses the same Firebase project as the Ionic app
// (project id `app-attendix`, see Ionic supabase/functions/_shared/send-push.ts).
// The Firebase config files are secrets-adjacent and NOT in the repo
// (Ionic gitignores them as well). Two ways to provide them, see
// docs/push-setup.md:
//
// 1. Native config files (recommended):
//    android/app/google-services.json and ios/Runner/GoogleService-Info.plist.
//    Then [DefaultFirebaseOptions.currentPlatform] returns null and
//    `Firebase.initializeApp()` reads the native files.
// 2. --dart-define values (CI / no files):
//    FIREBASE_API_KEY, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_ANDROID_APP_ID,
//    FIREBASE_IOS_APP_ID (and optionally FIREBASE_PROJECT_ID,
//    FIREBASE_IOS_BUNDLE_ID, FIREBASE_STORAGE_BUCKET).
//
// When neither is present, push initialisation fails softly: the app runs,
// push is simply unavailable (logged in debug mode).

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  /// Firebase project of the Ionic app (FCM v1 sender in send-push.ts).
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'app-attendix',
  );

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const String _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'de.attendix.attendix',
  );
  static const String _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  /// Options from `--dart-define`, or `null` to use the native config files
  /// (google-services.json / GoogleService-Info.plist).
  static FirebaseOptions? get currentPlatform =>
      optionsFor(defaultTargetPlatform);

  @visibleForTesting
  static FirebaseOptions? optionsFor(
    TargetPlatform platform, {
    String apiKey = _apiKey,
    String senderId = _senderId,
    String androidAppId = _androidAppId,
    String iosAppId = _iosAppId,
  }) {
    if (kIsWeb) return null;
    if (apiKey.isEmpty || senderId.isEmpty) return null;
    switch (platform) {
      case TargetPlatform.android:
        if (androidAppId.isEmpty) return null;
        return FirebaseOptions(
          apiKey: apiKey,
          appId: androidAppId,
          messagingSenderId: senderId,
          projectId: projectId,
          storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        );
      case TargetPlatform.iOS:
        if (iosAppId.isEmpty) return null;
        return FirebaseOptions(
          apiKey: apiKey,
          appId: iosAppId,
          messagingSenderId: senderId,
          projectId: projectId,
          storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
          iosBundleId: _iosBundleId,
        );
      default:
        return null;
    }
  }
}
