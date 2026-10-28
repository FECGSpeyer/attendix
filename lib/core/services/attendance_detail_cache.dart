import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LEFTOVERS: offline read cache of the attendance detail (Ionic
/// AttendanceService.getAttendanceByIdRobust, `offline_att_detail_v1_<id>` in
/// Ionic Storage). Every successful load is stored; while the device is
/// offline the stored copy is shown.
///
/// Ionic caches one combined object (attendance + persons). The Flutter page
/// loads its data through several providers, so each provider stores its raw
/// Supabase JSON under its own part key. Keys carry the tenant id so a copy
/// never shows up in another tenant.
class AttendanceDetailCache {
  const AttendanceDetailCache();

  static String keyFor(int tenantId, int attendanceId, String part) =>
      'offline_att_detail_v1_${tenantId}_${attendanceId}_$part';

  /// Players of the tenant (not tied to one Termin).
  static String playersKeyFor(int tenantId) =>
      'offline_att_detail_v1_${tenantId}_players';

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
  /// A failed fetch falls back to the cached copy (the connectivity check can
  /// report "online" without a working connection), otherwise rethrows.
  Future<T?> fetchWithCache<T extends Object>({
    required String key,
    required Future<bool> Function() isOnline,
    required Future<T?> Function() fetch,
  }) async {
    if (!await isOnline()) {
      final cached = await load(key);
      if (cached is T) return cached;
    }
    final T? fresh;
    try {
      fresh = await fetch();
    } catch (_) {
      final cached = await load(key);
      if (cached is T) return cached;
      rethrow;
    }
    await save(key, fresh);
    return fresh;
  }
}
