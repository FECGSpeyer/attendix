// PUSH: platform abstraction over Firebase Messaging + app icon badge.
//
// Keeps PushService free of plugin calls so its logic can be unit tested
// with a fake (see test/core/services/push/).

/// Ionic `PushNotifications.checkPermissions().receive`.
enum PushPermission { granted, denied, prompt }

/// A received / tapped push (Ionic FirebaseMessaging `Notification`).
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;

  /// FCM data payload (all values are strings on the wire).
  final Map<String, dynamic> data;
}

/// Native push operations used by PushService.
abstract class PushMessagingClient {
  /// Initialises Firebase. Returns false (never throws) when the Firebase
  /// configuration is missing or the platform has no native push.
  Future<bool> initialize();

  Future<PushPermission> checkPermission();

  Future<PushPermission> requestPermission();

  /// FCM registration token (iOS: waits for the APNs token first).
  Future<String?> getToken();

  Future<void> deleteToken();

  /// Token refreshes (Ionic iOS `tokenReceived`, Android `registration`).
  Stream<String> get onTokenRefresh;

  /// Pushes received while the app is in the foreground
  /// (Ionic FirebaseMessaging `notificationReceived`).
  Stream<PushMessage> get onForegroundMessage;

  /// Taps on a notification while the app was in the background
  /// (Ionic `notificationActionPerformed`).
  Stream<PushMessage> get onMessageOpened;

  /// The notification that launched the app from terminated state.
  Future<PushMessage?> getInitialMessage();

  /// Removes the app icon badge (Ionic `Badge.clear()`).
  Future<void> clearBadge();
}
