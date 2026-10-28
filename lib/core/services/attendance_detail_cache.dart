import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthRetryableFetchException, FunctionException, PostgrestException;

import '../../data/repositories/base_repository.dart' show RepositoryException;
import '../utils/error_message.dart' show isNetworkError;

/// LEFTOVERS: offline read cache of the attendance detail (Ionic
/// AttendanceService.getAttendanceByIdRobust, `offline_att_detail_v1_<id>` in
/// Ionic Storage). Every successful load is stored; while the device is
/// offline the stored copy is shown.
///
/// Ionic caches one combined object (attendance + persons). The Flutter page
/// loads its data through several providers, so each provider stores its raw
/// Supabase JSON under its own part key.
///
/// SOL_FIX7: keys carry the signed-in user id AND the tenant id, so a copy
/// never shows up for another account or in another tenant; all offline read
/// caches are removed on sign-out / account switch
/// ([clearOfflineReadCaches]). Without a signed-in user nothing is cached.
class AttendanceDetailCache {
  const AttendanceDetailCache();

  static const String prefix = 'offline_att_detail_v1_';

  static String keyFor(String userId, int tenantId, int attendanceId, String part) =>
      '$prefix${userId}_${tenantId}_${attendanceId}_$part';

  /// Players of the tenant (not tied to one Termin).
  static String playersKeyFor(String userId, int tenantId) =>
      '$prefix${userId}_${tenantId}_players';

  /// Prefix of every key of [userId] in [tenantId].
  static String tenantPrefixFor(String userId, int tenantId) =>
      '$prefix${userId}_${tenantId}_';

  Future<void> save(String key, Object? json) async {
    if (json == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(json));
    } catch (e) {
      debugPrint('[AttendanceDetailCache] save failed: $e');
    }
  }

  /// The cached JSON, or null when nothing (readable) is cached.
  Future<Object?> load(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw);
    } catch (e) {
      debugPrint('[AttendanceDetailCache] load failed: $e');
      return null;
    }
  }

  /// Offline → cached copy (if any); online → [fetch] and store the result.
  /// A fetch that failed because of the network falls back to the cached
  /// copy (the connectivity check can report "online" without a working
  /// connection). Auth/permission and all other errors are rethrown — a
  /// revoked access must never be hidden behind an old copy (SOL_FIX7).
  ///
  /// [key] is null when no user is signed in: then nothing is cached.
  Future<T?> fetchWithCache<T extends Object>({
    required String? key,
    required Future<bool> Function() isOnline,
    required Future<T?> Function() fetch,
  }) async {
    if (key == null) return fetch();
    if (!await isOnline()) {
      final cached = await load(key);
      if (cached is T) return cached;
    }
    final T? fresh;
    try {
      fresh = await fetch();
    } catch (e) {
      if (!isOfflineFallbackError(e)) rethrow;
      final cached = await load(key);
      if (cached is T) return cached;
      rethrow;
    }
    await save(key, fresh);
    return fresh;
  }
}

/// Key prefixes of all offline read caches (attendance detail + list, songs).
const List<String> offlineReadCachePrefixes = [
  AttendanceDetailCache.prefix,
  'offline_att_list_v1_',
  'offline_songs_v1_',
];

/// SOL_FIX7: removes every offline read cache entry (all users, all
/// tenants). Called on sign-out and account switch. Never throws.
Future<void> clearOfflineReadCaches() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => offlineReadCachePrefixes.any(k.startsWith))
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  } catch (e) {
    debugPrint('[OfflineReadCache] clear failed: $e');
  }
}

/// SOL_FIX7: clear when a signed-in account signs out or is replaced by
/// another one (not on the first sign-in / session restore).
bool shouldClearOfflineReadCaches(String? previousUserId, String? nextUserId) =>
    previousUserId != null && previousUserId != nextUserId;

/// PostgREST / GoTrue codes meaning "not signed in / not allowed".
const Set<String> _authErrorCodes = {
  '401',
  '403',
  '42501', // insufficient_privilege (RLS)
  'PGRST300', // JWT secret missing
  'PGRST301', // JWT invalid / expired
  'PGRST302', // anonymous access disabled
  'PGRST303', // JWT claims invalid
};

/// SOL_FIX7: whether [error] means the user is not (any longer) allowed to
/// read the data — those errors must reach the UI instead of a cached copy.
bool isAuthOrPermissionError(Object? error) {
  if (error == null) return false;
  if (error is RepositoryException) {
    return _authErrorCodes.contains(error.code) ||
        isAuthOrPermissionError(error.originalError);
  }
  if (error is PostgrestException) return _authErrorCodes.contains(error.code);
  if (error is AuthRetryableFetchException) return false; // network
  if (error is AuthException) {
    final status = error.statusCode;
    return status == null || status == '401' || status == '403' || _authErrorCodes.contains(error.code);
  }
  if (error is FunctionException) return error.status == 401 || error.status == 403;
  return false;
}

/// SOL_FIX7: offline read caches may only replace a failed load when the
/// failure is a network problem (never on auth/permission errors).
bool isOfflineFallbackError(Object? error) =>
    !isAuthOrPermissionError(error) && isNetworkError(error);
