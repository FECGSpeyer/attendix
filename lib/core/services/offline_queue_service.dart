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
import 'native/ionic_offline_queue_takeover.dart'
    show ionicOfflineQueueImportProvider;
import '../providers/attendance_providers.dart';
import '../providers/connectivity_provider.dart';
import '../providers/tenant_providers.dart';
import '../../l10n/l10n.dart';
import '../utils/toast_helper.dart';

part 'offline_queue_store.dart';
part 'offline_write_session.dart';

/// Root messenger so services can show toasts without a BuildContext.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final offlineQueueStoreProvider =
    Provider<OfflineQueueStore>((ref) => OfflineQueueStore());

/// Offline queue for attendance status changes (Ionic OfflineQueueService).
///
/// State = number of pending writes.
class OfflineQueueNotifier extends Notifier<int> {
  bool _initialized = false;
  bool _flushing = false;

  /// SOL_FIX9: a flush was requested while one was running (e.g. account
  /// switch aborted the replay) → run again afterwards for the new session.
  bool _flushRequested = false;

  /// SOL_FIX9: auth session generation. Bumped on sign-out and on every
  /// user change; a replay started in an older generation stops.
  int _sessionGeneration = 0;

  OfflineQueueStore get _store => ref.read(offlineQueueStoreProvider);

  @override
  int build() {
    // SOL_FIX9: a sign-out ends a running replay immediately.
    final authSub = ref.read(offlineQueueAuthEventsProvider).listen(
      (event) {
        if (event == AuthChangeEvent.signedOut) _sessionGeneration++;
      },
      onError: (Object _) {},
    );
    ref.onDispose(authSub.cancel);
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
      userId == null
          ? const []
          : [for (final e in queue) if (e.userId == userId) e];

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
    // SOL_FIX9: (synchronously) end a replay of the previous session.
    _sessionGeneration++;
    await _importIonicQueue();
    final List<QueuedWrite> stored;
    try {
      stored = await _store.load();
    } on OfflineQueueLoadException catch (e) {
      // SOL_FIX13: unreadable queue – keep it stored, nothing to replay.
      debugPrint('[OfflineQueue] queue unreadable: $e');
      return;
    }
    final own = ownedBy(stored, _currentUserId);
    state = own.length;
    if (own.isNotEmpty && await ref.read(connectivityCheckProvider)()) {
      await flush();
    }
  }

  /// IONIC_QUEUE: takes over the Ionic app's unsent offline writes once
  /// (native app, signed in, online); they are replayed like own writes.
  Future<void> _importIonicQueue() async {
    try {
      await ref.read(ionicOfflineQueueImportProvider)();
    } catch (e) {
      debugPrint('[OfflineQueue] Ionic queue import failed: $e');
    }
  }

  /// Queue the write if the device is offline.
  ///
  /// Returns true when the write was queued (caller must not write to the
  /// database), false when online (caller writes directly).
  ///
  /// SOL_FIX12: online, a write for a record that still has a pending queued
  /// write of the same user + tenant goes through the queue as well (merged
  /// into that entry, last write wins, then replayed): a direct write would
  /// otherwise be overwritten later by the older queued value. Writes per
  /// record stay in order (the queue serializes them).
  ///
  /// Throws [OfflineQueuePersistException] when the write could not be
  /// persisted in the queue (it is then NOT queued — show an error).
  ///
  /// SOL_FIX13: [session] (from [captureWriteSession], taken when the user
  /// acted) binds the write to its author; without it the session is
  /// captured on entry. The session is re-checked after EVERY await; when it
  /// changed and the write was not queued for its author,
  /// [OfflineSessionChangedException] is thrown (never `false`, so the
  /// caller cannot write directly under the new account). Callers pass the
  /// same session to the direct write (`isSessionCurrent`/`actingUserId`).
  Future<bool> enqueueIfOffline(
    String personAttendanceId,
    Map<String, dynamic> payload, {
    int? attendanceId,
    OfflineWriteSession? session,
  }) async {
    // SOL_FIX12: capture author, tenant and session BEFORE the first await,
    // so an account / tenant switch during the connectivity check can never
    // attribute A's action to B (and never falls back to a direct write).
    final captured = session ?? captureWriteSession();
    final tenantId = captured.tenantId;
    // SOL_FIX4: record the author so the write is only replayed for them.
    final userId = captured.userId;
    captured.ensureCurrent();
    final online = await ref.read(connectivityCheckProvider)();
    captured.ensureCurrent();
    if (tenantId == null || userId == null) return false;
    if (online) {
      final routed = await _mergeIntoPending(
        personAttendanceId,
        payload,
        tenantId: tenantId,
        attendanceId: attendanceId,
        userId: userId,
      );
      if (routed) {
        // Queued for its author (the flush is bound to the current session).
        await flush();
        return true;
      }
      // SOL_FIX13: the caller writes directly next – only while the
      // captured session is still active.
      captured.ensureCurrent();
      return false;
    }
    await enqueue(
      personAttendanceId,
      payload,
      tenantId: tenantId,
      attendanceId: attendanceId,
      userId: userId,
    );
    return true;
  }

  /// SOL_FIX13: captures the signed-in user, auth session, session
  /// generation and current tenant (synchronously, no await).
  OfflineWriteSession captureWriteSession() {
    final tenantId = ref.read(currentTenantIdProvider);
    final userIdFn = ref.read(offlineQueueUserIdProvider);
    final sessionIdFn = ref.read(offlineQueueSessionIdProvider);
    final userId = userIdFn();
    final sessionId = sessionIdFn();
    final generation = _sessionGeneration;
    return OfflineWriteSession._(
      userId: userId,
      tenantId: tenantId,
      isCurrent: () =>
          _sessionGeneration == generation &&
          userIdFn() == userId &&
          sessionIdFn() == sessionId &&
          ref.read(currentTenantIdProvider) == tenantId,
    );
  }

  /// SOL_FIX12: merges the write into a pending entry of the same record
  /// (same user + tenant) in one atomic queue update. Returns false (and
  /// writes nothing) when there is no such entry.
  Future<bool> _mergeIntoPending(
    String personAttendanceId,
    Map<String, dynamic> payload, {
    required int tenantId,
    required String userId,
    int? attendanceId,
  }) async {
    var merged = false;
    final entry = _newQueuedWrite(
      personAttendanceId,
      payload,
      tenantId: tenantId,
      userId: userId,
      attendanceId: attendanceId,
    );
    final next = await _store.update((queue) {
      if (!OfflineQueueStore.hasPendingFor(
        queue,
        personAttendanceId,
        userId: userId,
        tenantId: tenantId,
      )) {
        return queue;
      }
      merged = true;
      return OfflineQueueStore.merge(queue, entry);
    });
    if (merged) state = ownedBy(next, _currentUserId).length;
    return merged;
  }

  /// Add a write to the queue (last-write-wins per personAttendanceId).
  ///
  /// SOL_FIX12: throws [OfflineQueuePersistException] when it could not be
  /// persisted.
  Future<void> enqueue(
    String personAttendanceId,
    Map<String, dynamic> payload, {
    required int tenantId,
    required String userId,
    int? attendanceId,
  }) async {
    final entry = _newQueuedWrite(
      personAttendanceId,
      payload,
      tenantId: tenantId,
      userId: userId,
      attendanceId: attendanceId,
    );
    // SOL_FIX2: serialized read-modify-write (concurrent enqueues no longer
    // overwrite each other).
    final merged = await _store.update(
      (queue) => OfflineQueueStore.merge(queue, entry),
    );
    state = ownedBy(merged, _currentUserId).length;
  }

  QueuedWrite _newQueuedWrite(
    String personAttendanceId,
    Map<String, dynamic> payload, {
    required int tenantId,
    required String userId,
    int? attendanceId,
  }) =>
      QueuedWrite(
        id: const Uuid().v4(),
        personAttendanceId: personAttendanceId,
        payload: payload,
        tenantId: tenantId,
        attendanceId: attendanceId,
        userId: userId,
        createdAt: DateTime.now().toIso8601String(),
      );

  /// Replay the queued writes of the signed-in user. Failed writes stay in
  /// the queue.
  ///
  /// SOL_FIX4: writes of other users are kept but never replayed under this
  /// session; legacy entries without a user cannot be attributed and are
  /// dropped.
  ///
  /// SOL_FIX9: a flush requested while one is running runs again right
  /// after it (so a new account's writes are replayed after an aborted
  /// replay of the previous one).
  Future<void> flush() async {
    if (_flushing) {
      _flushRequested = true;
      return;
    }
    _flushing = true;
    try {
      // IONIC_QUEUE: e.g. back online after a start without connection.
      await _importIonicQueue();
      do {
        _flushRequested = false;
        await _flushOnce();
      } while (_flushRequested);
    } finally {
      _flushing = false;
    }
  }

  /// SOL_FIX9: the replay is bound to the auth session it started in (user
  /// id, auth session identity and [_sessionGeneration]). Before EACH write
  /// the session is checked again; on sign-out or account switch the replay
  /// stops at once and the not yet replayed writes stay queued for their
  /// user — they never run with another session's rights / changed_by.
  Future<void> _flushOnce() async {
    final userIdFn = ref.read(offlineQueueUserIdProvider);
    final sessionIdFn = ref.read(offlineQueueSessionIdProvider);
    final userId = userIdFn();
    if (userId == null) {
      state = 0;
      return;
    }
    final sessionId = sessionIdFn();
    final generation = _sessionGeneration;
    bool sessionUnchanged() {
      if (_sessionGeneration != generation) return false;
      try {
        return userIdFn() == userId && sessionIdFn() == sessionId;
      } catch (_) {
        return false;
      }
    }

    final cacheGuard = OfflineReadCacheGuard.capture(
      userId: userId,
      currentUserId: userIdFn,
    );

    final List<QueuedWrite> all;
    try {
      all = await OfflineQueueStore.synchronized(_store.load);
    } on OfflineQueueLoadException catch (e) {
      // SOL_FIX13: unreadable queue – replay nothing, overwrite nothing.
      debugPrint('[OfflineQueue] queue unreadable, replay skipped: $e');
      return;
    }
    await _dropUnattributedWrites(all);
    final queue = ownedBy(all, userId);
    if (queue.isEmpty) {
      state = 0;
      return;
    }

    final replay = await _replayEntries(queue, sessionUnchanged);

    // SOL_FIX2: bring the offline detail cache up to date first, then
    // remove only the confirmed entries from the CURRENT queue.
    await applyConfirmedWritesToDetailCache(
      replay.confirmed,
      guard: cacheGuard,
    );
    final remaining = await _removeConfirmedEntries(replay.confirmed, queue);
    // SOL_FIX9: count for whoever is signed in now.
    state = ownedBy(remaining, replay.aborted ? userIdFn() : userId).length;

    _invalidateFlushedProviders(replay.flushedAttendanceIds);

    if (replay.failed.isEmpty && !replay.aborted) {
      _showOfflineSavedToast();
    }
  }

  Future<void> _dropUnattributedWrites(List<QueuedWrite> all) async {
    final legacy = [for (final e in all) if (e.userId == null) e];
    if (legacy.isEmpty) return;
    debugPrint('[OfflineQueue] dropping ${legacy.length} unattributed writes');
    try {
      await _store.update(
        (current) => OfflineQueueStore.removeConfirmed(current, legacy),
      );
    } on OfflineQueuePersistException catch (e) {
      debugPrint('[OfflineQueue] dropping unattributed writes failed: $e');
    }
  }

  Future<({
    List<QueuedWrite> confirmed,
    List<QueuedWrite> failed,
    Set<int> flushedAttendanceIds,
    bool aborted,
  })> _replayEntries(
    List<QueuedWrite> queue,
    bool Function() sessionUnchanged,
  ) async {
    final flushFn = ref.read(offlineFlushFnProvider);
    final failed = <QueuedWrite>[];
    final confirmed = <QueuedWrite>[];
    final flushedAttendanceIds = <int>{};
    var aborted = false;
    for (final entry in queue) {
      if (!sessionUnchanged()) {
        aborted = true;
        debugPrint('[OfflineQueue] session changed – replay stopped');
        break;
      }
      try {
        await flushFn(entry, sessionUnchanged);
        confirmed.add(entry);
        if (entry.attendanceId != null) {
          flushedAttendanceIds.add(entry.attendanceId!);
        }
      } on OfflineSessionChangedException {
        aborted = true;
        debugPrint('[OfflineQueue] session changed – replay stopped');
        break;
      } catch (e) {
        debugPrint('[OfflineQueue] flush failed for ${entry.id}: $e');
        failed.add(entry);
      }
    }
    return (
      confirmed: confirmed,
      failed: failed,
      flushedAttendanceIds: flushedAttendanceIds,
      aborted: aborted,
    );
  }

  Future<List<QueuedWrite>> _removeConfirmedEntries(
    List<QueuedWrite> confirmed,
    List<QueuedWrite> fallbackQueue,
  ) async {
    try {
      return await _store.update(
        (current) => OfflineQueueStore.removeConfirmed(current, confirmed),
      );
    } on OfflineQueuePersistException catch (e) {
      debugPrint('[OfflineQueue] removing replayed writes failed: $e');
      try {
        return await OfflineQueueStore.synchronized(_store.load);
      } on OfflineQueueLoadException {
        return fallbackQueue;
      }
    }
  }

  void _invalidateFlushedProviders(Set<int> flushedAttendanceIds) {
    if (flushedAttendanceIds.isEmpty &&
        !ref.exists(attendancesProvider) &&
        !ref.exists(playerAttendancePercentagesProvider)) {
      return;
    }
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

  void _showOfflineSavedToast() {
    try {
      // Ionic: Utils.showToast(translate('svc.offlineSaved'), 'success')
      final toastContext = rootScaffoldMessengerKey.currentContext;
      if (toastContext != null && toastContext.mounted) {
        ToastHelper.showSuccess(
          toastContext,
          l10nWithoutContext.svcOfflineSaved,
          beta: const LegacySnackBar(color: Colors.green, floating: true),
        );
      }
    } catch (_) {
      // No messenger available (e.g. tests)
    }
  }
}

final offlineQueueNotifierProvider =
    NotifierProvider<OfflineQueueNotifier, int>(OfflineQueueNotifier.new);

/// Number of pending offline writes (for "{count} ausstehend" badges).
final offlinePendingCountProvider = Provider<int>((ref) {
  return ref.watch(offlineQueueNotifierProvider);
});
