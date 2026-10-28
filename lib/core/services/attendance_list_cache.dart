import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/attendance/attendance.dart';

/// LOGIC_SELF: offline read cache of the attendance list (Ionic att-list
/// `offline_att_list_v1_<tenantId>` in Ionic Storage). The list is stored
/// after every successful load and shown while the device is offline.
class AttendanceListCache {
  const AttendanceListCache();

  static String keyFor(int tenantId) => 'offline_att_list_v1_$tenantId';

  Future<void> save(int tenantId, List<Attendance> attendances) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        keyFor(tenantId),
        jsonEncode({
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
  Future<List<Attendance>?> load(int tenantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(tenantId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['data'] is! List) return null;
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
