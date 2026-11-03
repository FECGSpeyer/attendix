import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'native_platform.dart';

/// IONIC_SESSION: the Flutter app replaces the Ionic app as a store update
/// (same app id io.stephanus.attendix). The Ionic login lives in the
/// WebView localStorage (`sb-<ref>-auth-token`, `currentTenantId`), which the
/// native side reads once (ios/Runner/AppDelegate.swift IonicSessionPlugin,
/// android .../ionic/IonicSessionPlugin.kt). Its refresh token signs the user
/// in here, so nobody has to log in again after the update.
const _channel = MethodChannel('de.attendix/ionic_session');
const _doneKey = 'ionic_session_takeover_done';
const _attemptsKey = 'ionic_session_takeover_attempts';
const _maxAttempts = 3;

/// Same key as `CurrentTenantNotifier` (tenant_providers.dart).
const _tenantIdKey = 'current_tenant_id';

typedef IonicSession = ({String refreshToken, int? tenantId});

/// Runs once, before `runApp`, so the router already sees the session.
/// Every failure falls back to the normal login. Network errors are retried
/// on the next starts (at most [_maxAttempts]); a missing or rejected Ionic
/// session ends the takeover for good.
Future<void> takeOverIonicSession({required String supabaseUrl}) async {
  if (!isNativeApp) return;
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey) ?? false) return;
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) {
      await prefs.setBool(_doneKey, true);
      return;
    }
    final attempts = (prefs.getInt(_attemptsKey) ?? 0) + 1;
    await prefs.setInt(_attemptsKey, attempts);
    if (attempts > _maxAttempts) {
      await prefs.setBool(_doneKey, true);
      return;
    }

    final raw = await _channel
        .invokeMethod<String>('read')
        .timeout(const Duration(seconds: 6));
    final session = parseIonicStorage(raw, supabaseUrl: supabaseUrl);
    if (session == null) {
      await prefs.setBool(_doneKey, true);
      return;
    }

    await auth
        .setSession(session.refreshToken)
        .timeout(const Duration(seconds: 10));
    final tenantId = session.tenantId;
    if (tenantId != null) await prefs.setInt(_tenantIdKey, tenantId);
    await prefs.setBool(_doneKey, true);
  } on AuthRetryableFetchException catch (e) {
    debugPrint('Ionic session takeover: offline, retry next start ($e)');
  } on AuthException catch (e) {
    // Refresh token expired or already used: normal login.
    debugPrint('Ionic session takeover: token rejected ($e)');
    await prefs?.setBool(_doneKey, true);
  } catch (e) {
    debugPrint('Ionic session takeover failed: $e');
  }
}

/// Reads the refresh token and tenant from the Ionic localStorage keys the
/// native side returns as JSON. Prefers the key of this Supabase project
/// (`sb-<project ref>-auth-token`, supabase-js default storage key).
@visibleForTesting
IonicSession? parseIonicStorage(String? raw, {required String supabaseUrl}) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final storage = jsonDecode(raw);
    if (storage is! Map) return null;
    final host = Uri.tryParse(supabaseUrl)?.host ?? '';
    final ownKey = 'sb-${host.split('.').first}-auth-token';
    final keys = [
      if (storage.containsKey(ownKey)) ownKey,
      ...storage.keys.whereType<String>().where(
          (k) => k != ownKey && k.startsWith('sb-') && k.endsWith('-auth-token')),
    ];
    for (final key in keys) {
      final value = storage[key];
      if (value is! String) continue;
      var session = jsonDecode(value);
      // supabase-js < 2.0 wrapped the session in `currentSession`.
      if (session is Map && session['currentSession'] is Map) {
        session = session['currentSession'];
      }
      final token = session is Map ? session['refresh_token'] : null;
      if (token is String && token.isNotEmpty) {
        final tenant = storage['currentTenantId'];
        return (
          refreshToken: token,
          tenantId: tenant is String ? int.tryParse(tenant.trim()) : null,
        );
      }
    }
  } catch (_) {}
  return null;
}
