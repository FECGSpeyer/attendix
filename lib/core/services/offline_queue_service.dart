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

/// SOL_FIX12: the offline queue could not be persisted (storage error or
/// `setString` returned false). The write is NOT queued; callers must show
/// an error instead of treating the change as saved.
class OfflineQueuePersistException implements Exception {
  const OfflineQueuePersistException([this.cause]);
  final Object? cause;

  /// User-facing text (shown via friendlyErrorMessage); the cause is logged.
  @override
  String toString() => l10nWithoutContext.coreFlutterOfflineQueueSaveFailed;
}

/// SOL_FIX13: the persisted offline queue could not be read (storage error,
/// undecodable JSON or not a list). It is never treated as empty: nothing is
/// written over it, so the pending writes stay stored.
class OfflineQueueLoadException extends OfflineQueuePersistException {
  const OfflineQueueLoadException([super.cause]);
}

/// SOL_FIX13: result of reading the persisted queue: the valid entries plus
/// the raw JSON of entries that could not be parsed (kept verbatim on the
/// next save, never dropped).
typedef _LoadedQueue = ({List<QueuedWrite> valid, List<Object?> invalidRaw});

/// Persistent storage + merge logic of the offline queue.
class OfflineQueueStore {
  /// [prefs]: storage access (tests inject failing storages).
  OfflineQueueStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

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
  ///
  /// SOL_FIX12: nothing is written when [change] returns the loaded list
  /// unchanged (identical). Throws [OfflineQueuePersistException] when the
  /// result could not be persisted.
  ///
  /// SOL_FIX13: throws [OfflineQueueLoadException] (and writes nothing) when
  /// the stored queue could not be read; entries that could not be parsed
  /// are written back unchanged.
  Future<List<QueuedWrite>> update(
    List<QueuedWrite> Function(List<QueuedWrite> current) change,
  ) {
    return synchronized(() async {
      final loaded = await _loadRaw();
      final current = loaded.valid;
      final next = change(current);
      if (!identical(next, current)) {
        await save(next, preserveRaw: loaded.invalidRaw);
      }
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

  /// The valid queued writes.
  ///
  /// SOL_FIX13: throws [OfflineQueueLoadException] when the stored queue
  /// cannot be read (it is never reported as empty — a following save would
  /// otherwise overwrite the pending writes). Single invalid entries are
  /// skipped here but kept in storage (see [update]).
  Future<List<QueuedWrite>> load() async => (await _loadRaw()).valid;

  Future<_LoadedQueue> _loadRaw() async {
    final Object? decoded;
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(queueKey);
      if (raw == null || raw.isEmpty) return (valid: <QueuedWrite>[], invalidRaw: const <Object?>[]);
      decoded = jsonDecode(raw);
    } catch (e) {
      debugPrint('[OfflineQueue] load failed: $e');
      throw OfflineQueueLoadException(e);
    }
    if (decoded is! List) {
      debugPrint('[OfflineQueue] load failed: stored queue is not a list');
      throw const OfflineQueueLoadException('stored queue is not a list');
    }
    final valid = <QueuedWrite>[];
    final invalid = <Object?>[];
    for (final e in decoded) {
      try {
        valid.add(QueuedWrite.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (error) {
        debugPrint('[OfflineQueue] skipping invalid entry: $error');
        invalid.add(e);
      }
    }
    return (valid: valid, invalidRaw: invalid);
  }

  /// SOL_FIX12: throws [OfflineQueuePersistException] when the queue could
  /// not be persisted (never reports a write as queued that is not stored).
  ///
  /// SOL_FIX13: [preserveRaw] = raw entries that could not be parsed; they
  /// are written back unchanged.
  Future<void> save(
    List<QueuedWrite> queue, {
    List<Object?> preserveRaw = const [],
  }) async {
    bool stored;
    try {
      final prefs = await _prefs();
      stored = await prefs.setString(
        queueKey,
        jsonEncode([...queue.map((e) => e.toJson()), ...preserveRaw]),
      );
    } catch (e) {
      debugPrint('[OfflineQueue] save failed: $e');
      throw OfflineQueuePersistException(e);
    }
    if (!stored) {
      debugPrint('[OfflineQueue] save failed: setString returned false');
      throw const OfflineQueuePersistException('setString returned false');
    }
  }

  /// SOL_FIX12: whether [queue] holds a pending write of [userId] in
  /// [tenantId] for the person_attendances row [personAttendanceId].
  static bool hasPendingFor(
    List<QueuedWrite> queue,
    String personAttendanceId, {
    required String userId,
    required int tenantId,
  }) =>
      queue.any((e) =>
          e.personAttendanceId == personAttendanceId &&
          e.userId == userId &&
          e.tenantId == tenantId);

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
///
/// SOL_FIX9: with a [guard], nothing is written once its session has ended
/// (the cache was cleared on sign-out / account switch in the meantime).
Future<void> applyConfirmedWritesToDetailCache(
  List<QueuedWrite> confirmed, {
  AttendanceDetailCache cache = const AttendanceDetailCache(),
  OfflineReadCacheGuard? guard,
}) async {
  if (confirmed.isEmpty) return;
  if (guard != null && !guard.isCurrent) return;
  try {
    // cache key → (tenant, user) of the confirmed writes
    final keys = <String, ({int tenantId, String? userId})>{};
    List<String>? allKeys;
    for (final e in confirmed) {
      final owner = (tenantId: e.tenantId, userId: e.userId);
      // SOL_FIX7: the detail cache is per user; legacy writes without an
      // author have no cache to update.
      final userId = e.userId;
      if (userId == null) continue;
      if (e.attendanceId != null) {
        keys[AttendanceDetailCache.keyFor(userId, e.tenantId, e.attendanceId!, 'persons')] = owner;
      } else {
        allKeys ??= (await SharedPreferences.getInstance()).getKeys().toList();
        final prefix = AttendanceDetailCache.tenantPrefixFor(userId, e.tenantId);
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
      if (!identical(updated, cached)) {
        await cache.save(entry.key, updated, guard: guard);
      }
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

/// SOL_FIX9: identity of the current auth session (null when signed out).
/// Taken from the access token's `session_id` claim, which stays the same
/// across token refreshes but changes on every new sign-in; falls back to
/// the user id when the token carries no such claim. Read at call time.
final offlineQueueSessionIdProvider = Provider<String? Function()>((ref) {
  return () {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return null;
      return authSessionIdentity(session.accessToken) ?? 'user:${session.user.id}';
    } catch (_) {
      return null;
    }
  };
});

/// SOL_FIX9: `session_id` claim of a Supabase access token (JWT), or null
/// when the token cannot be decoded or has no such claim.
String? authSessionIdentity(String accessToken) {
  try {
    final parts = accessToken.split('.');
    if (parts.length != 3) return null;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return null;
    final id = payload['session_id'];
    return id is String && id.isNotEmpty ? id : null;
  } catch (_) {
    return null;
  }
}

/// SOL_FIX9: auth events (sign-out ends a running replay). Empty stream
/// when Supabase is not initialised (tests).
final offlineQueueAuthEventsProvider = Provider<Stream<AuthChangeEvent>>((ref) {
  try {
    return Supabase.instance.client.auth.onAuthStateChange.map((s) => s.event);
  } catch (_) {
    return const Stream<AuthChangeEvent>.empty();
  }
});

/// Replays one queued write against Supabase.
///
/// SOL_FIX11: [isSessionCurrent] must be checked again right before the
/// mutation (after any async validation). When it returns false the write
/// must not run; throw [OfflineSessionChangedException] so the entry stays
/// queued for its author.
typedef OfflineFlushFn = Future<void> Function(
  QueuedWrite entry,
  bool Function() isSessionCurrent,
);

final offlineFlushFnProvider = Provider<OfflineFlushFn>((ref) {
  return (entry, isSessionCurrent) async {
    // Fresh repository instance so the replay uses the tenant of the entry
    // without touching the shared (current tenant) repository.
    final repo = AttendanceRepository(ref)..bindTenantId(entry.tenantId);
    await repo.updatePersonAttendance(
      entry.personAttendanceId,
      Map<String, dynamic>.from(entry.payload),
      isSessionCurrent: isSessionCurrent,
      // changed_by = author of the queued write (the guard ensures it is
      // still the signed-in user), never a user re-read later.
      actingUserId: entry.userId,
    );
  };
});

/// SOL_FIX13: author, tenant and auth session of one person_attendances
/// write, captured synchronously when the user acts. [OfflineQueueNotifier.enqueueIfOffline]
/// binds the write to it; on the online path the caller passes [isCurrent]
/// and [userId] to the repository, which checks the session again right
/// before the mutation (an account / tenant switch in between never writes
/// under the new account).
class OfflineWriteSession {
  OfflineWriteSession._({
    required this.userId,
    required this.tenantId,
    required bool Function() isCurrent,
  }) : _isCurrent = isCurrent;

  /// SOL_FIX15: session of a direct (non-queued) write flow, e.g. the own
  /// master data: signed-in user, auth session and tenant, captured
  /// synchronously before the flow's first await. [isCurrent] is false
  /// once any of them changed – or when nobody was signed in.
  factory OfflineWriteSession.capture(Ref ref) {
    final userIdFn = ref.read(offlineQueueUserIdProvider);
    final sessionIdFn = ref.read(offlineQueueSessionIdProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    final userId = userIdFn();
    final sessionId = sessionIdFn();
    return OfflineWriteSession._(
      userId: userId,
      tenantId: tenantId,
      isCurrent: () =>
          userId != null &&
          userIdFn() == userId &&
          sessionIdFn() == sessionId &&
          ref.read(currentTenantIdProvider) == tenantId,
    );
  }

  /// Signed-in user at capture time (null = signed out).
  final String? userId;

  /// Current tenant at capture time.
  final int? tenantId;
  final bool Function() _isCurrent;

  /// Whether the captured user, auth session and tenant are still active.
  bool isCurrent() {
    try {
      return _isCurrent();
    } catch (_) {
      return false;
    }
  }

  /// Throws [OfflineSessionChangedException] when the session changed.
  void ensureCurrent() {
    if (!isCurrent()) throw const OfflineSessionChangedException();
  }
}

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
    // SOL_FIX9: (synchronously) end a replay of the previous session.
    _sessionGeneration++;
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
    final entry = QueuedWrite(
      id: const Uuid().v4(),
      personAttendanceId: personAttendanceId,
      payload: payload,
      tenantId: tenantId,
      attendanceId: attendanceId,
      userId: userId,
      createdAt: DateTime.now().toIso8601String(),
    );
    final next = await _store.update((queue) {
      if (!OfflineQueueStore.hasPendingFor(queue, personAttendanceId,
          userId: userId, tenantId: tenantId)) {
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

    // Offline detail cache updates belong to the same session.
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
    final legacy = [for (final e in all) if (e.userId == null) e];
    if (legacy.isNotEmpty) {
      debugPrint('[OfflineQueue] dropping ${legacy.length} unattributed writes');
      try {
        await _store.update(
          (current) => OfflineQueueStore.removeConfirmed(current, legacy),
        );
      } on OfflineQueuePersistException catch (e) {
        debugPrint('[OfflineQueue] dropping unattributed writes failed: $e');
      }
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
    var aborted = false;
    for (final entry in queue) {
      // SOL_FIX9: re-check the session right before every write.
      if (!sessionUnchanged()) {
        aborted = true;
        debugPrint('[OfflineQueue] session changed – replay stopped');
        break;
      }
      try {
        // SOL_FIX11: the repository re-checks the session after its async
        // validation, immediately before the mutation.
        await flushFn(entry, sessionUnchanged);
        confirmed.add(entry);
        if (entry.attendanceId != null) {
          flushedAttendanceIds.add(entry.attendanceId!);
        }
      } on OfflineSessionChangedException {
        // Session changed during the write's validation: nothing was
        // written; keep this and the remaining entries queued.
        aborted = true;
        debugPrint('[OfflineQueue] session changed – replay stopped');
        break;
      } catch (e) {
        debugPrint('[OfflineQueue] flush failed for ${entry.id}: $e');
        failed.add(entry);
      }
    }

    // SOL_FIX2: bring the offline detail cache up to date first, then
    // remove only the confirmed entries from the CURRENT queue
    // (never overwrite it with the stale failure set).
    await applyConfirmedWritesToDetailCache(confirmed, guard: cacheGuard);
    List<QueuedWrite> remaining;
    try {
      remaining = await _store.update(
        (current) => OfflineQueueStore.removeConfirmed(current, confirmed),
      );
    } on OfflineQueuePersistException catch (e) {
      // SOL_FIX12: the replayed entries stay queued (replayed again later).
      debugPrint('[OfflineQueue] removing replayed writes failed: $e');
      try {
        remaining = await OfflineQueueStore.synchronized(_store.load);
      } on OfflineQueueLoadException {
        remaining = queue; // SOL_FIX13: unreadable – count stays as before
      }
    }
    // SOL_FIX9: count for whoever is signed in now.
    state = ownedBy(remaining, aborted ? userIdFn() : userId).length;

    if (confirmed.isNotEmpty) {
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

    if (failed.isEmpty && !aborted) {
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
  }
}

final offlineQueueNotifierProvider =
    NotifierProvider<OfflineQueueNotifier, int>(OfflineQueueNotifier.new);

/// Number of pending offline writes (for "{count} ausstehend" badges).
final offlinePendingCountProvider = Provider<int>((ref) {
  return ref.watch(offlineQueueNotifierProvider);
});
