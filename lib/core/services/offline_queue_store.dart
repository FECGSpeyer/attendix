part of 'offline_queue_service.dart';

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

  QueuedWrite copyWith({Map<String, dynamic>? payload, int? revision}) =>
      QueuedWrite(
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
      if (raw == null || raw.isEmpty) {
        return (valid: <QueuedWrite>[], invalidRaw: const <Object?>[]);
      }
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
        keys[AttendanceDetailCache.keyFor(
            userId, e.tenantId, e.attendanceId!, 'persons')] = owner;
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
