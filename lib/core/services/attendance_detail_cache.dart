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

  /// Stores [json] under [key]. SOL_FIX9: with a [guard], nothing is written
  /// once the session it was captured in has ended (sign-out, account
  /// switch, [clearOfflineReadCaches]) — the check runs right before the
  /// synchronous in-memory write, so a concurrent clear cannot be undone.
  Future<void> save(String key, Object? json, {OfflineReadCacheGuard? guard}) async {
    if (json == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (guard != null && !guard.isCurrent) return;
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

  /// Removes one cached entry. Never throws.
  Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      debugPrint('[AttendanceDetailCache] remove failed: $e');
    }
  }

  /// Offline → cached copy (if any); online → [fetch] and store the result.
  /// A fetch that failed because of the network falls back to the cached
  /// copy (the connectivity check can report "online" without a working
  /// connection). Auth/permission and all other errors are rethrown — a
  /// revoked access must never be hidden behind an old copy (SOL_FIX7).
  ///
  /// SOL_FIX8: an auth/permission error also deletes [key] and — when
  /// [scope] is given — every offline read cache entry of that user in that
  /// tenant, so a later offline read cannot show the revoked data. A fetch
  /// that returns null (row deleted / no longer visible) removes [key].
  ///
  /// [key] is null when no user is signed in: then nothing is cached.
  ///
  /// SOL_FIX9: the cache session (generation + [scope] user, re-read via
  /// [currentUserId]) is captured BEFORE the fetch; a result that arrives
  /// after sign-out / account switch / [clearOfflineReadCaches] is returned
  /// but not stored, so a cleared cache is never recreated.
  Future<T?> fetchWithCache<T extends Object>({
    required String? key,
    required Future<bool> Function() isOnline,
    required Future<T?> Function() fetch,
    OfflineCacheScope? scope,
    String? Function()? currentUserId,
  }) async {
    if (key == null) return fetch();
    final guard = OfflineReadCacheGuard.capture(
      userId: scope?.userId,
      currentUserId: currentUserId,
    );
    if (!await isOnline()) {
      final cached = await load(key);
      if (cached is T) return cached;
    }
    final T? fresh;
    try {
      fresh = await fetch();
    } catch (e) {
      if (isAuthOrPermissionError(e)) {
        // SOL_FIX8: access revoked → drop the copies before reporting.
        await remove(key);
        if (scope != null) {
          await purgeOfflineReadCachesFor(scope.userId, scope.tenantId);
        }
        rethrow;
      }
      if (!isOfflineFallbackError(e)) rethrow;
      final cached = await load(key);
      if (cached is T) return cached;
      rethrow;
    }
    if (fresh == null) {
      // SOL_FIX8: not found (any more) → no stale offline copy.
      await remove(key);
      return null;
    }
    await save(key, fresh, guard: guard);
    return fresh;
  }
}

/// SOL_FIX9: session generation of the offline read caches. Bumped
/// (synchronously) by [clearOfflineReadCaches] / [bumpOfflineReadCacheGeneration]
/// on sign-out and account switch; a load captured in an older generation
/// must not write its result into the cache any more.
int _offlineReadCacheGeneration = 0;

/// Current offline read cache session generation (see [OfflineReadCacheGuard]).
int get offlineReadCacheGeneration => _offlineReadCacheGeneration;

/// Ends the current offline read cache session: every in-flight load stops
/// being allowed to write its result into the cache.
void bumpOfflineReadCacheGeneration() => _offlineReadCacheGeneration++;

/// SOL_FIX9: the offline read cache session a load started in. Captured
/// before the fetch; [isCurrent] is checked right before the cache write.
///
/// The tenant is part of every cache key, so a result is always stored for
/// the tenant it was loaded for; a tenant switch does not end the session.
class OfflineReadCacheGuard {
  /// [userId]: signed-in user at capture time; [currentUserId] re-reads the
  /// signed-in user at write time (both optional: then only the generation
  /// is checked).
  OfflineReadCacheGuard.capture({this.userId, String? Function()? currentUserId})
      : generation = _offlineReadCacheGeneration,
        _currentUserId = currentUserId;

  final int generation;
  final String? userId;
  final String? Function()? _currentUserId;

  /// Whether the session is unchanged: same generation and (when known)
  /// still the same signed-in user.
  bool get isCurrent {
    if (generation != _offlineReadCacheGeneration) return false;
    final read = _currentUserId;
    if (userId == null || read == null) return true;
    try {
      return read() == userId;
    } catch (_) {
      return false;
    }
  }
}

/// SOL_FIX8: signed-in user + tenant an offline read cache entry belongs to.
typedef OfflineCacheScope = ({String userId, int tenantId});

/// Key prefixes of all offline read caches (attendance detail + list, songs).
const List<String> offlineReadCachePrefixes = [
  AttendanceDetailCache.prefix,
  'offline_att_list_v1_',
  'offline_songs_v1_',
];

/// SOL_FIX7: removes every offline read cache entry (all users, all
/// tenants). Called on sign-out and account switch. Never throws.
///
/// SOL_FIX9: first (synchronously) ends the cache session, so loads still in
/// flight cannot recreate entries after the clear.
Future<void> clearOfflineReadCaches() async {
  bumpOfflineReadCacheGeneration();
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

/// SOL_FIX8: removes every offline read cache entry (attendance detail +
/// list, songs) of [userId] in [tenantId] — called when a load fails with an
/// auth/permission error. Entries of other users/tenants stay. Never throws.
Future<void> purgeOfflineReadCachesFor(String userId, int tenantId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final bases = [
      for (final p in offlineReadCachePrefixes) '$p${userId}_$tenantId',
    ];
    final keys = prefs
        .getKeys()
        .where((k) => bases.any((b) => k == b || k.startsWith('${b}_')))
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  } catch (e) {
    debugPrint('[OfflineReadCache] purge failed: $e');
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
