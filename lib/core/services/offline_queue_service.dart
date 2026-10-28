import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/attendance_repository.dart';
import 'attendance_detail_cache.dart';
import '../providers/attendance_providers.dart';
import '../providers/connectivity_provider.dart';
import '../providers/tenant_providers.dart';
import '../../l10n/l10n.dart';

/// Root messenger so services can show toasts without a BuildContext.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// A person_attendances write that was made while offline
/// (Ionic OfflineQueueService `QueuedWrite`).
@immutable
class QueuedWrite {
  const QueuedWrite({
    required this.id,
    required this.personAttendanceId,
    required this.payload,
    required this.tenantId,
    required this.createdAt,
    this.attendanceId,
    this.userId,
    this.revision = 0,
  });

  final String id;

  /// SOL_FIX2: bumped on every merge into this entry. flush() only removes
  /// entries whose id AND revision were replayed, so a write merged in while
  /// the flush was running is kept.
  final int revision;
  final String personAttendanceId;
  final Map<String, dynamic> payload;

  /// Tenant the write belongs to (replayed with this tenant's validation).
  final int tenantId;
  final int? attendanceId;

  /// SOL_FIX4: auth user that made the write. Entries are only replayed
  /// (and overlaid) for this user; entries without a user (written by an
  /// older app version) cannot be attributed and are dropped on flush.
  final String? userId;
  final String createdAt;

  QueuedWrite copyWith({Map<String, dynamic>? payload, int? revision}) => QueuedWrite(
        id: id,
        personAttendanceId: personAttendanceId,
        payload: payload ?? this.payload,
        tenantId: tenantId,
        createdAt: createdAt,
        attendanceId: attendanceId,
        userId: userId,
        revision: revision ?? this.revision,
      );

  factory QueuedWrite.fromJson(Map<String, dynamic> json) => QueuedWrite(
        id: json['id'] as String,
        personAttendanceId: json['personAttendanceId'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        tenantId: json['tenantId'] as int,
        createdAt: json['createdAt'] as String,
        attendanceId: json['attendanceId'] as int?,
        userId: json['userId'] as String?,
        revision: json['revision'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'personAttendanceId': personAttendanceId,
        'payload': payload,
        'tenantId': tenantId,
        'createdAt': createdAt,
        'attendanceId': attendanceId,
        'userId': userId,
        'revision': revision,
      };
}

/// Persistent storage + merge logic of the offline queue.
class OfflineQueueStore {
  static const String queueKey = 'offline_writes_v1';

  /// SOL_FIX2: async mutex (lock chain) around every read-modify-write of the
  /// persisted queue. Static because all store instances share one
  /// SharedPreferences key.
  static Future<void> _lockTail = Future<void>.value();

  /// Runs [action] after all previously scheduled actions have finished.
  static Future<T> synchronized<T>(Future<T> Function() action) {
    final previous = _lockTail;
    final done = Completer<void>();
    _lockTail = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }

  /// Atomically loads the queue, applies [change] and saves the result.
  Future<List<QueuedWrite>> update(
    List<QueuedWrite> Function(List<QueuedWrite> current) change,
  ) {
    return synchronized(() async {
      final next = change(await load());
      await save(next);
      return next;
    });
  }

  /// Removes exactly the replayed entries (same id AND revision). Entries
  /// added or merged after the snapshot was taken stay in the queue.
  static List<QueuedWrite> removeConfirmed(
    List<QueuedWrite> current,
    Iterable<QueuedWrite> confirmed,
  ) {
    final done = {for (final e in confirmed) '${e.id}#${e.revision}'};
    return [
      for (final e in current)
        if (!done.contains('${e.id}#${e.revision}')) e,
    ];
  }

  Future<List<QueuedWrite>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(queueKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => QueuedWrite.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('[OfflineQueue] load failed: $e');
      return [];
    }
  }

  Future<void> save(List<QueuedWrite> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        queueKey,
        jsonEncode(queue.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[OfflineQueue] save failed: $e');
    }
  }

  /// Last-write-wins: merge into an existing entry for the same
  /// personAttendanceId (SOL_FIX4: of the same user and tenant — a write of
  /// user B never merges into a pending write of user A), otherwise append.
  static List<QueuedWrite> merge(List<QueuedWrite> queue, QueuedWrite entry) {
    final result = List<QueuedWrite>.of(queue);
    final index = result.indexWhere((e) =>
        e.personAttendanceId == entry.personAttendanceId &&
        e.userId == entry.userId &&
        e.tenantId == entry.tenantId);
    if (index >= 0) {
      final existing = result[index];
      result[index] = existing.copyWith(
        payload: {...existing.payload, ...entry.payload},
        revision: existing.revision + 1,
      );
    } else {
      result.add(entry);
    }
    return result;
  }

  /// SOL_FIX1: overlays pending (not yet replayed) writes of [tenantId] on
  /// person_attendances rows (e.g. from the offline detail cache), so a
  /// change made offline does not revert to the cached status/notes when
  /// the Termin is reopened. Matches by tenant + record id; entries of other
  /// tenants are ignored. Rows are copied, never mutated.
  ///
  /// SOL_FIX4: only writes of [userId] are overlaid; without a signed-in
  /// user nothing is overlaid (another account's pending writes stay
  /// invisible).
  static List<dynamic> overlayPending(
    List<dynamic> rows,
    List<QueuedWrite> queue, {
    required int tenantId,
    required String? userId,
  }) {
    if (userId == null) return rows;
    final pending = <String, Map<String, dynamic>>{};
    for (final e in queue) {
      if (e.tenantId != tenantId || e.userId != userId) continue;
      pending[e.personAttendanceId] = {
        ...?pending[e.personAttendanceId],
        ...e.payload,
      };
    }
    if (pending.isEmpty) return rows;
    return [
      for (final row in rows)
        if (row is Map && pending.containsKey(row['id']?.toString()))
          <String, dynamic>{
            ...Map<String, dynamic>.from(row),
            ...pending[row['id'].toString()]!,
          }
        else
          row,
    ];
  }
}

/// SOL_FIX2: writes replayed by the queue are applied to the offline detail
/// cache (`persons` part, matched by tenant + person_attendances id), so a
/// Termin opened offline later does not show the stale cached status again.
/// Entries without attendanceId update every cached Termin of their tenant.
Future<void> applyConfirmedWritesToDetailCache(
  List<QueuedWrite> confirmed, {
  AttendanceDetailCache cache = const AttendanceDetailCache(),
}) async {
  if (confirmed.isEmpty) return;
  try {
    // cache key → (tenant, user) of the confirmed writes
    final keys = <String, ({int tenantId, String? userId})>{};
    List<String>? allKeys;
    for (final e in confirmed) {
      final owner = (tenantId: e.tenantId, userId: e.userId);
      if (e.attendanceId != null) {
        keys[AttendanceDetailCache.keyFor(e.tenantId, e.attendanceId!, 'persons')] = owner;
      } else {
        allKeys ??= (await SharedPreferences.getInstance()).getKeys().toList();
        final prefix = 'offline_att_detail_v1_${e.tenantId}_';
        for (final k in allKeys) {
          if (k.startsWith(prefix) && k.endsWith('_persons')) keys[k] = owner;
        }
      }
    }
    for (final entry in keys.entries) {
      final cached = await cache.load(entry.key);
      if (cached is! List) continue;
      final updated = OfflineQueueStore.overlayPending(
        cached,
        confirmed,
        tenantId: entry.value.tenantId,
        userId: entry.value.userId,
      );
      if (!identical(updated, cached)) await cache.save(entry.key, updated);
    }
  } catch (e) {
    debugPrint('[OfflineQueue] detail cache update failed: $e');
  }
}

final offlineQueueStoreProvider =
    Provider<OfflineQueueStore>((ref) => OfflineQueueStore());

/// Checks the current network state (navigator.onLine on web).
final connectivityCheckProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // Unknown -> assume online, write directly
    }
  };
});

/// SOL_FIX4: id of the signed-in auth user (null when signed out or when
/// Supabase is not initialised, e.g. in tests). Read at call time.
final offlineQueueUserIdProvider = Provider<String? Function()>((ref) {
  return () {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  };
});

/// Replays one queued write against Supabase.
typedef OfflineFlushFn = Future<void> Function(QueuedWrite entry);

final offlineFlushFnProvider = Provider<OfflineFlushFn>((ref) {
  return (entry) async {
    // Fresh repository instance so the replay uses the tenant of the entry
    // without touching the shared (current tenant) repository.
    final repo = AttendanceRepository(ref)..bindTenantId(entry.tenantId);
    await repo.updatePersonAttendance(
      entry.personAttendanceId,
      Map<String, dynamic>.from(entry.payload),
    );
  };
});

/// Offline queue for attendance status changes (Ionic OfflineQueueService).
///
/// State = number of pending writes.
class OfflineQueueNotifier extends Notifier<int> {
  bool _initialized = false;
  bool _flushing = false;

  OfflineQueueStore get _store => ref.read(offlineQueueStoreProvider);

  @override
  int build() {
    // Replay when the connection comes back
    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      final wasOnline = previous?.valueOrNull;
      final isOnline = next.valueOrNull;
      if (isOnline == true && wasOnline != true) {
        unawaited(flush());
      }
    });
    return 0;
  }

  String? get _currentUserId => ref.read(offlineQueueUserIdProvider)();

  /// SOL_FIX4: pending writes of [userId] (none without a signed-in user).
  static List<QueuedWrite> ownedBy(List<QueuedWrite> queue, String? userId) =>
      userId == null ? const [] : [for (final e in queue) if (e.userId == userId) e];

  /// Load the persisted queue and flush it if online (Ionic init()).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await onUserChanged();
  }

  /// SOL_FIX4: recount for the now signed-in user and replay their writes
  /// (login, logout, account switch). Other users' writes stay persisted
  /// but are never replayed or shown under this account.
  Future<void> onUserChanged() async {
    final own = ownedBy(await _store.load(), _currentUserId);
    state = own.length;
    if (own.isNotEmpty && await ref.read(connectivityCheckProvider)()) {
      await flush();
    }
  }

  /// Queue the write if the device is offline.
  ///
  /// Returns true when the write was queued (caller must not write to the
  /// database), false when online (caller writes directly).
  Future<bool> enqueueIfOffline(
    String personAttendanceId,
    Map<String, dynamic> payload, {
    int? attendanceId,
  }) async {
    final online = await ref.read(connectivityCheckProvider)();
    if (online) return false;
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return false;
    // SOL_FIX4: record the author so the write is only replayed for them.
    final userId = _currentUserId;
    if (userId == null) return false;
    await enqueue(
      personAttendanceId,
      payload,
      tenantId: tenantId,
      attendanceId: attendanceId,
      userId: userId,
    );
    return true;
  }

  /// Add a write to the queue (last-write-wins per personAttendanceId).
  Future<void> enqueue(
    String personAttendanceId,
    Map<String, dynamic> payload, {
    required int tenantId,
    required String userId,
    int? attendanceId,
  }) async {
    final entry = QueuedWrite(
      id: const Uuid().v4(),
      personAttendanceId: personAttendanceId,
      payload: payload,
      tenantId: tenantId,
      attendanceId: attendanceId,
      userId: userId,
      createdAt: DateTime.now().toIso8601String(),
    );
    // SOL_FIX2: serialized read-modify-write (concurrent enqueues no longer
    // overwrite each other).
    final merged = await _store.update((queue) => OfflineQueueStore.merge(queue, entry));
    state = ownedBy(merged, _currentUserId).length;
  }

  /// Replay the queued writes of the signed-in user. Failed writes stay in
  /// the queue.
  ///
  /// SOL_FIX4: writes of other users are kept but never replayed under this
  /// session; legacy entries without a user cannot be attributed and are
  /// dropped.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final userId = _currentUserId;
      if (userId == null) {
        state = 0;
        return;
      }
      final all = await OfflineQueueStore.synchronized(_store.load);
      final legacy = [for (final e in all) if (e.userId == null) e];
      if (legacy.isNotEmpty) {
        debugPrint('[OfflineQueue] dropping ${legacy.length} unattributed writes');
        await _store.update(
          (current) => OfflineQueueStore.removeConfirmed(current, legacy),
        );
      }
      final queue = ownedBy(all, userId);
      if (queue.isEmpty) {
        state = 0;
        return;
      }

      final flushFn = ref.read(offlineFlushFnProvider);
      final failed = <QueuedWrite>[];
      final confirmed = <QueuedWrite>[];
      final flushedAttendanceIds = <int>{};
      for (final entry in queue) {
        try {
          await flushFn(entry);
          confirmed.add(entry);
          if (entry.attendanceId != null) {
            flushedAttendanceIds.add(entry.attendanceId!);
          }
        } catch (e) {
          debugPrint('[OfflineQueue] flush failed for ${entry.id}: $e');
          failed.add(entry);
        }
      }

      // SOL_FIX2: bring the offline detail cache up to date first, then
      // remove only the confirmed entries from the CURRENT queue
      // (never overwrite it with the stale failure set).
      await applyConfirmedWritesToDetailCache(confirmed);
      final remaining = await _store.update(
        (current) => OfflineQueueStore.removeConfirmed(current, confirmed),
      );
      state = ownedBy(remaining, userId).length;

      if (failed.length < queue.length) {
        // Only refresh providers that are alive (avoid triggering fetches)
        for (final id in flushedAttendanceIds) {
          if (ref.exists(attendanceByIdProvider(id))) {
            ref.invalidate(attendanceByIdProvider(id));
          }
        }
        if (ref.exists(attendancesProvider)) ref.invalidate(attendancesProvider);
        if (ref.exists(playerAttendancePercentagesProvider)) {
          ref.invalidate(playerAttendancePercentagesProvider);
        }
      }

      if (failed.isEmpty) {
        try {
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(l10nWithoutContext.svcOfflineSaved),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (_) {
          // No messenger available (e.g. tests)
        }
      }
    } finally {
      _flushing = false;
    }
  }
}

final offlineQueueNotifierProvider =
    NotifierProvider<OfflineQueueNotifier, int>(OfflineQueueNotifier.new);

/// Number of pending offline writes (for "{count} ausstehend" badges).
final offlinePendingCountProvider = Provider<int>((ref) {
  return ref.watch(offlineQueueNotifierProvider);
});
