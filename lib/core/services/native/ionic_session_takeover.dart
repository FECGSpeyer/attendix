import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../constants/enums.dart';
import '../offline_queue_service.dart' show OfflineQueueStore, QueuedWrite;
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

/// Group of the Ionic app (its localStorage `currentTenantId`). Ionic
/// preferred it over `user_metadata`, so `CurrentTenantNotifier` restores it
/// first and keeps the key until the group is synced (tenant_providers.dart).
const ionicTakeoverTenantKey = 'ionic_session_takeover_tenant';

typedef IonicSession = ({String refreshToken, int? tenantId});

/// Runs once, before `runApp`, so the router already sees the session.
/// Every failure falls back to the normal login. Read and network errors are
/// retried on the next starts (at most [_maxAttempts]); an empty Ionic
/// storage or a rejected token ends the takeover for good.
///
/// The refresh runs on a separate client without storage: a late answer
/// after the timeout can never change the app's session (Sol #285). Only a
/// fresh session that arrives in time is handed to the app's client
/// (supabase_flutter persists it on that event).
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
    final session =
        (await refresher
            .setSession(ionic.refreshToken)
            .timeout(const Duration(seconds: 10))).session;
    // Not after a timeout: the pending refresh may still finish.
    refresher.dispose();
    if (session == null || client.auth.currentSession != null) return;
    // Like a session restored at app start (initialSession, not
    // tokenRefreshed): the push bootstrap registers this device's token on
    // that event, which listeners added after runApp get replayed.
    await client.auth.setInitialSession(jsonEncode(session.toJson()));
    // Before the done flag: a start that ends in between finds the session
    // (done, no second import). Never blocks the takeover.
    await _importIonicOfflineWrites(
      raw,
      userId: session.user.id,
      tenantId: ionic.tenantId,
    );
    await prefs.setBool(_doneKey, true);

    // Restored (and synced) by CurrentTenantNotifier; kept until then.
    final tenantId = ionic.tenantId;
    if (tenantId != null) await prefs.setInt(ionicTakeoverTenantKey, tenantId);
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

/// Ends the takeover for good once the user signed in in this app (called on
/// every `signedIn`). Otherwise a later logout would let the next start take
/// over the old Ionic session again.
Future<void> markIonicSessionTakeoverDone() async {
  if (!isNativeApp) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
  } catch (e) {
    debugPrint('Ionic session takeover: could not mark done ($e)');
  }
}

/// IONIC_QUEUE: attendances the Ionic app recorded offline and had not
/// uploaded yet (its OfflineQueueService, @ionic/storage key
/// `offline_writes_v1`). The native side adds them to the `read` result as a
/// JSON string under this key; they go into the Flutter offline queue, which
/// uploads them once online. Errors only lose the Ionic queue.
const ionicOfflineWritesKey = 'offline_writes_v1';

Future<void> _importIonicOfflineWrites(
  String? raw, {
  required String userId,
  required int? tenantId,
}) async {
  // Ionic queue entries carry no tenant: without the Ionic group they
  // cannot be replayed (the replay validates the row's tenant).
  if (tenantId == null) return;
  try {
    final writes = parseIonicOfflineWrites(
      raw,
      userId: userId,
      tenantId: tenantId,
    );
    if (writes.isEmpty) return;
    var added = 0;
    await OfflineQueueStore().update((current) {
      var next = current;
      for (final write in writes) {
        // A newer Flutter write for the same row wins (never a duplicate).
        if (OfflineQueueStore.hasPendingFor(
          current,
          write.personAttendanceId,
          userId: userId,
          tenantId: tenantId,
        )) {
          continue;
        }
        next = OfflineQueueStore.merge(next, write);
        added++;
      }
      return next;
    });
    debugPrint('Ionic session takeover: $added offline writes queued');
  } catch (e) {
    debugPrint('Ionic session takeover: offline writes not taken over ($e)');
  }
}

/// IONIC_QUEUE: the Ionic queue entries (`{id, personAttendanceId, payload,
/// userId?, createdAt}`) of [userId] as Flutter [QueuedWrite]s of
/// [tenantId], in Ionic order. Only the person_attendances columns Ionic
/// writes are kept (`status` as a valid int, `notes`); `attendance_id` only
/// names the Termin. Entries of another user or without a usable field are
/// skipped.
@visibleForTesting
List<QueuedWrite> parseIonicOfflineWrites(
  String? raw, {
  required String userId,
  required int tenantId,
}) {
  if (raw == null || raw.isEmpty) return const [];
  final List<Object?> entries;
  try {
    final storage = jsonDecode(raw);
    final value = storage is Map ? storage[ionicOfflineWritesKey] : null;
    if (value is! String || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    entries = decoded;
  } catch (_) {
    return const [];
  }
  final validStatus = {for (final s in AttendanceStatus.values) s.value};
  final writes = <QueuedWrite>[];
  for (final entry in entries) {
    if (entry is! Map) continue;
    final rowId = entry['personAttendanceId'];
    final personAttendanceId = rowId is String
        ? rowId.trim()
        : rowId is num
        ? rowId.toString()
        : '';
    if (personAttendanceId.isEmpty) continue;
    final author = entry['userId'];
    if (author is String && author.isNotEmpty && author != userId) continue;
    if (author != null && author is! String) continue;
    final source = entry['payload'];
    if (source is! Map) continue;

    final payload = <String, dynamic>{};
    final rawStatus = source['status'];
    final status = rawStatus is num
        ? rawStatus.toInt()
        : rawStatus is String
        ? int.tryParse(rawStatus.trim())
        : null;
    if (status != null && validStatus.contains(status)) {
      payload['status'] = status;
    }
    if (source.containsKey('notes')) {
      final notes = source['notes'];
      if (notes == null || notes is String) payload['notes'] = notes;
    }
    if (payload.isEmpty) continue;

    final rawAttendance = source['attendance_id'];
    final id = entry['id'];
    final createdAt = entry['createdAt'];
    writes.add(
      QueuedWrite(
        id: id is String && id.isNotEmpty ? id : const Uuid().v4(),
        personAttendanceId: personAttendanceId,
        payload: payload,
        tenantId: tenantId,
        createdAt: createdAt is String && createdAt.isNotEmpty
            ? createdAt
            : DateTime.now().toIso8601String(),
        attendanceId: rawAttendance is num ? rawAttendance.toInt() : null,
        userId: userId,
      ),
    );
  }
  return writes;
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
        (k) => k != ownKey && k.startsWith('sb-') && k.endsWith('-auth-token'),
      ),
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
