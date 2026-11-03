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
/// Every failure falls back to the normal login. Read and network errors are
/// retried on the next starts (at most [_maxAttempts]); an empty Ionic
/// storage or a rejected token ends the takeover for good.
///
/// The refresh runs on a separate client without storage: a late answer
/// after the timeout can never change the app's session (Sol #285). Only a
/// fresh session that arrives in time is handed to the app's client.
Future<void> takeOverIonicSession({
  required String supabaseUrl,
  required String anonKey,
}) async {
  if (!isNativeApp) return;
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey) ?? false) return;
    final client = Supabase.instance.client;
    if (client.auth.currentSession != null) {
      await prefs.setBool(_doneKey, true);
      return;
    }
    final attempts = (prefs.getInt(_attemptsKey) ?? 0) + 1;
    await prefs.setInt(_attemptsKey, attempts);
    if (attempts > _maxAttempts) {
      await prefs.setBool(_doneKey, true);
      return;
    }

    // PlatformException (read error, timeout) -> retry on the next start.
    final raw = await _channel
        .invokeMethod<String>('read')
        .timeout(const Duration(seconds: 6));
    final ionic = parseIonicStorage(raw, supabaseUrl: supabaseUrl);
    if (ionic == null) {
      await prefs.setBool(_doneKey, true);
      return;
    }

    final refresher = GoTrueClient(
      url: '$supabaseUrl/auth/v1',
      headers: {'apikey': anonKey, 'Authorization': 'Bearer $anonKey'},
      autoRefreshToken: false,
    );
    final session = (await refresher
            .setSession(ionic.refreshToken)
            .timeout(const Duration(seconds: 10)))
        .session;
    // Not after a timeout: the pending refresh may still finish.
    refresher.dispose();
    if (session == null || client.auth.currentSession != null) return;
    await client.auth.recoverSession(jsonEncode(session.toJson()));
    await prefs.setBool(_doneKey, true);

    final tenantId = ionic.tenantId;
    if (tenantId != null) await _adoptIonicTenant(client, tenantId, prefs);
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

/// Ionic preferred its local `currentTenantId` over `user_metadata`; the
/// Flutter tenant restore prefers the metadata. So a group the user still
/// belongs to is written to both (like Ionic's setTenant). Best effort.
Future<void> _adoptIonicTenant(
  SupabaseClient client,
  int tenantId,
  SharedPreferences prefs,
) async {
  try {
    await prefs.setInt(_tenantIdKey, tenantId);
    final user = client.auth.currentUser;
    if (user == null || user.userMetadata?['currentTenantId'] == tenantId) {
      return;
    }
    final member = await client
        .from('tenantUsers')
        .select('tenantId')
        .eq('tenantId', tenantId)
        .eq('userId', user.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 5));
    if (member == null) return;
    await client.auth
        .updateUser(UserAttributes(data: {'currentTenantId': tenantId}))
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Ionic session takeover: tenant not synced ($e)');
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
