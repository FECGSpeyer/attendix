// PUSH: Firebase Messaging implementation of [PushMessagingClient].
//
// Every plugin call is wrapped in try/catch (CLAUDE.md rule 5): a missing
// Firebase config, an unsupported platform or a plugin error must never
// crash the app – push is then simply unavailable.

import 'dart:async';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../config/firebase_options.dart';
import 'push_messaging_client.dart';

class FirebasePushMessagingClient implements PushMessagingClient {
  bool _ready = false;

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  void _log(String message, [Object? error]) {
    if (kDebugMode) debugPrint('[push] $message${error != null ? ': $error' : ''}');
  }

  @override
  Future<bool> initialize() async {
    if (_ready) return true;
    if (kIsWeb) return false; // Ionic: push is native only
    try {
      if (Firebase.apps.isEmpty) {
        final options = DefaultFirebaseOptions.currentPlatform;
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          // Reads google-services.json / GoogleService-Info.plist.
          await Firebase.initializeApp();
        }
      }
      if (_isIos) {
        // In-app alert like Ionic; the system banner is not shown on top of
        // it while the app is open, only the sound is played.
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: true,
        );
      }
      _ready = true;
      return true;
    } catch (e) {
      _log('Firebase not configured, push disabled (see docs/push-setup.md)', e);
      return false;
    }
  }

  PushPermission _map(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return PushPermission.granted;
      case AuthorizationStatus.denied:
        return PushPermission.denied;
      case AuthorizationStatus.notDetermined:
        return PushPermission.prompt;
    }
  }

  @override
  Future<PushPermission> checkPermission() async {
    if (!_ready) return PushPermission.denied;
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return _map(settings.authorizationStatus);
    } catch (e) {
      _log('checkPermission failed', e);
      return PushPermission.denied;
    }
  }

  @override
  Future<PushPermission> requestPermission() async {
    if (!_ready) return PushPermission.denied;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return _map(settings.authorizationStatus);
    } catch (e) {
      _log('requestPermission failed', e);
      return PushPermission.denied;
    }
  }

  @override
  Future<String?> getToken() async {
    if (!_ready) return null;
    try {
      if (_isIos) {
        // Ionic waits (max 10 s) for the APNs registration before asking
        // Firebase for the FCM token.
        String? apns = await FirebaseMessaging.instance.getAPNSToken();
        for (var i = 0; apns == null && i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          apns = await FirebaseMessaging.instance.getAPNSToken();
        }
        if (apns == null) {
          _log('iOS Push Error: Registration timeout (no APNs token)');
          return null;
        }
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      _log('getToken failed', e);
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      _log('Failed to delete FCM token', e);
    }
  }

  PushMessage _toPush(RemoteMessage m) => PushMessage(
        title: m.notification?.title,
        body: m.notification?.body,
        data: Map<String, dynamic>.of(m.data),
      );

  @override
  Stream<String> get onTokenRefresh {
    if (!_ready) return const Stream.empty();
    try {
      return FirebaseMessaging.instance.onTokenRefresh;
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Stream<PushMessage> get onForegroundMessage {
    if (!_ready) return const Stream.empty();
    try {
      return FirebaseMessaging.onMessage.map(_toPush);
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Stream<PushMessage> get onMessageOpened {
    if (!_ready) return const Stream.empty();
    try {
      return FirebaseMessaging.onMessageOpenedApp.map(_toPush);
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<PushMessage?> getInitialMessage() async {
    if (!_ready) return null;
    try {
      final m = await FirebaseMessaging.instance.getInitialMessage();
      return m == null ? null : _toPush(m);
    } catch (e) {
      _log('getInitialMessage failed', e);
      return null;
    }
  }

  @override
  Future<void> clearBadge() async {
    if (kIsWeb) return;
    try {
      // Badge API not available on all platforms / launchers.
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(0);
      }
    } catch (e) {
      _log('Could not clear badge', e);
    }
  }
}
