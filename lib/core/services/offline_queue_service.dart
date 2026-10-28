import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/attendance_repository.dart';
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
  });

  final String id;
  final String personAttendanceId;
  final Map<String, dynamic> payload;

  /// Tenant the write belongs to (replayed with this tenant's validation).
  final int tenantId;
  final int? attendanceId;
  final String? userId;
  final String createdAt;

  QueuedWrite copyWith({Map<String, dynamic>? payload}) => QueuedWrite(
        id: id,
        personAttendanceId: personAttendanceId,
        payload: payload ?? this.payload,
        tenantId: tenantId,
        createdAt: createdAt,
        attendanceId: attendanceId,
        userId: userId,
      );

  factory QueuedWrite.fromJson(Map<String, dynamic> json) => QueuedWrite(
        id: json['id'] as String,
        personAttendanceId: json['personAttendanceId'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        tenantId: json['tenantId'] as int,
        createdAt: json['createdAt'] as String,
        attendanceId: json['attendanceId'] as int?,
        userId: json['userId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'personAttendanceId': personAttendanceId,
        'payload': payload,
        'tenantId': tenantId,
        'createdAt': createdAt,
        'attendanceId': attendanceId,
        'userId': userId,
      };
}

/// Persistent storage + merge logic of the offline queue.
class OfflineQueueStore {
  static const String queueKey = 'offline_writes_v1';

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
  /// personAttendanceId, otherwise append.
  static List<QueuedWrite> merge(List<QueuedWrite> queue, QueuedWrite entry) {
    final result = List<QueuedWrite>.of(queue);
    final index = result.indexWhere(
        (e) => e.personAttendanceId == entry.personAttendanceId);
    if (index >= 0) {
      final existing = result[index];
      result[index] = existing.copyWith(
        payload: {...existing.payload, ...entry.payload},
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
  static List<dynamic> overlayPending(
    List<dynamic> rows,
    List<QueuedWrite> queue, {
    required int tenantId,
  }) {
    final pending = <String, Map<String, dynamic>>{};
    for (final e in queue) {
      if (e.tenantId != tenantId) continue;
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

/// Replays one queued write against Supabase.
typedef OfflineFlushFn = Future<void> Function(QueuedWrite entry);

final offlineFlushFnProvider = Provider<OfflineFlushFn>((ref) {
  return (entry) async {
    // Fresh repository instance so the replay uses the tenant of the entry
    // without touching the shared (current tenant) repository.
    final repo = AttendanceRepository(ref)..setTenantId(entry.tenantId);
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

  /// Load the persisted queue and flush it if online (Ionic init()).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final queue = await _store.load();
    state = queue.length;
    if (queue.isNotEmpty && await ref.read(connectivityCheckProvider)()) {
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
    await enqueue(
      personAttendanceId,
      payload,
      tenantId: tenantId,
      attendanceId: attendanceId,
    );
    return true;
  }

  /// Add a write to the queue (last-write-wins per personAttendanceId).
  Future<void> enqueue(
    String personAttendanceId,
    Map<String, dynamic> payload, {
    required int tenantId,
    int? attendanceId,
    String? userId,
  }) async {
    final queue = await _store.load();
    final merged = OfflineQueueStore.merge(
      queue,
      QueuedWrite(
        id: const Uuid().v4(),
        personAttendanceId: personAttendanceId,
        payload: payload,
        tenantId: tenantId,
        attendanceId: attendanceId,
        userId: userId,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    await _store.save(merged);
    state = merged.length;
  }

  /// Replay all queued writes. Failed writes stay in the queue.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final queue = await _store.load();
      if (queue.isEmpty) {
        state = 0;
        return;
      }

      final flushFn = ref.read(offlineFlushFnProvider);
      final failed = <QueuedWrite>[];
      final flushedAttendanceIds = <int>{};
      for (final entry in queue) {
        try {
          await flushFn(entry);
          if (entry.attendanceId != null) {
            flushedAttendanceIds.add(entry.attendanceId!);
          }
        } catch (e) {
          debugPrint('[OfflineQueue] flush failed for ${entry.id}: $e');
          failed.add(entry);
        }
      }

      await _store.save(failed);
      state = failed.length;

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
