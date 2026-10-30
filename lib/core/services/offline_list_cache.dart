import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'attendance_detail_cache.dart';
import 'offline_queue_service.dart';

/// Offline read cache for whole lists of a tenant (people, groups), on top of
/// [AttendanceDetailCache.fetchWithCache]: stored after every successful
/// load, returned while the device is offline or the load fails with a
/// network error. Bound to the signed-in user + tenant, removed on sign-out
/// and on 401/403 like the other offline read caches.
class OfflineListCache {
  OfflineListCache._();

  static const String prefix = 'offline_list_v1_';

  static String keyFor(String userId, int tenantId, String part) => '$prefix${userId}_${tenantId}_$part';

  /// Loads [fetch] with the offline fallback. [toJson]/[fromJson] convert one
  /// item for storage. Without a signed-in user nothing is cached.
  static Future<List<T>> read<T>(
    Ref ref, {
    required int tenantId,
    required String part,
    required Future<List<T>> Function() fetch,
    required Object? Function(T item) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    final currentUserId = ref.read(offlineQueueUserIdProvider);
    final userId = currentUserId();
    final rows = await const AttendanceDetailCache().fetchWithCache<List<dynamic>>(
      key: userId == null ? null : keyFor(userId, tenantId, part),
      scope: userId == null ? null : (userId: userId, tenantId: tenantId),
      currentUserId: currentUserId,
      isOnline: ref.read(connectivityCheckProvider),
      fetch: () async => [for (final item in await fetch()) toJson(item)],
    );
    return [
      for (final row in rows ?? const [])
        if (row is Map) fromJson(Map<String, dynamic>.from(row)),
    ];
  }
}
