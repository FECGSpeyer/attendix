import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/attendance/attendance.dart';

/// LOGIC_SELF: offline read cache of the attendance list (Ionic att-list
/// `offline_att_list_v1_<tenantId>` in Ionic Storage). The list is stored
/// after every successful load and shown while the device is offline.
///
/// SOL_FIX7: bound to the signed-in user + tenant (key and payload) and
/// removed on sign-out (`clearOfflineReadCaches`).
class AttendanceListCache {
  const AttendanceListCache();

  static String keyFor(String userId, int tenantId) =>
      'offline_att_list_v1_${userId}_$tenantId';

  Future<void> save(String userId, int tenantId, List<Attendance> attendances) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        keyFor(userId, tenantId),
        jsonEncode({
          'userId': userId,
          'tenantId': tenantId,
          'data': attendances.map((a) => a.toJson()).toList(),
          'cachedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('[AttendanceListCache] save failed: $e');
    }
  }

  /// The cached list, or null when nothing (readable) is cached.
  Future<List<Attendance>?> load(String userId, int tenantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(userId, tenantId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['data'] is! List) return null;
      if (decoded['userId'] != userId || decoded['tenantId'] != tenantId) return null;
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Attendance.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('[AttendanceListCache] load failed: $e');
      return null;
    }
  }
}
