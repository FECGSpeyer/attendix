import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../offline_queue_service.dart';
import 'native_platform.dart';

/// IONIC_QUEUE: the Flutter app replaces the Ionic app as a store update
/// (same app id io.stephanus.attendix). Attendance changes the Ionic app made
/// offline and had not sent yet live in its OfflineQueueService
/// (@ionic/storage-angular → IndexedDB `_ionicstorage`/`_ionickv`, key
/// `offline_writes_v1`). They are taken over once into the Flutter offline
/// queue ([OfflineQueueStore]) and replayed by its normal flush:
///
/// 1. [prepareIonicOfflineQueueTakeover] (before the session takeover):
///    an install that already ran a Flutter version skips the takeover – its
///    Ionic queue is older than changes made since, a replay would overwrite
///    them. On the first Flutter start a marker is stored instead, so a crash
///    between session takeover and queue read does not end the takeover.
/// 2. [startIonicOfflineQueueRead] (after the session takeover, not awaited):
///    the native side reads the raw entries (ios/Runner/AppDelegate.swift
///    IonicOfflineQueueReader, android .../ionic/IonicOfflineQueueReader.kt);
///    they are kept in [ionicQueuePendingKey] until a user is signed in.
/// 3. [importIonicOfflineQueue] (from the offline queue, signed in and
///    online): adds tenant and Termin from the database, only for instances
///    the user belongs to; unresolvable entries are dropped and logged.
///
/// The Ionic data itself is never changed. Web/PWA and desktop: no-op.
const _channel = MethodChannel('de.attendix/ionic_session');

/// Set once the takeover is finished (or not needed): never again.
const ionicQueueDoneKey = 'ionic_offline_queue_takeover_done';
const _readAttemptsKey = 'ionic_offline_queue_takeover_attempts';
const _maxReadAttempts = 3;

/// Ionic entries read natively, waiting for a signed-in user (JSON list of
/// [IonicQueuedWrite]).
const ionicQueuePendingKey = 'ionic_offline_queue_takeover_pending';

/// Keys of the session takeover (ionic_session_takeover.dart): present once a
/// Flutter version has started on this device.
const _sessionTakeoverKeys = [
  'ionic_session_takeover_done',
  'ionic_session_takeover_attempts',
];

/// Prefix of the queue entry ids taken over from Ionic (keeps them apart
/// from Flutter's uuids; the same Ionic entry is never added twice).
const ionicQueueIdPrefix = 'ionic:';

/// person_attendances columns an Ionic replay writes (Ionic db-helpers.ts
/// pickPersonAttendanceFields), without id, changed_by/changed_at (set by the
/// replay) and attendance_id/person_id (a queued write never moves a row).
const _ionicPayloadColumns = {
  'status',
  'notes',
  'registration_answers',
  'duty_state',
  'duty_assigned_by',
  'duty_assigned_at',
  'duty_reminder_sent',
};

/// One entry of the Ionic OfflineQueueService (`QueuedWrite`).
@immutable
class IonicQueuedWrite {
  const IonicQueuedWrite({
    required this.id,
    required this.personAttendanceId,
    required this.payload,
    required this.createdAt,
    this.userId,
  });

  final String id;
  final String personAttendanceId;
  final Map<String, dynamic> payload;
  final String? userId;
  final String createdAt;

  /// Null when the entry has no id, record id or payload.
  static IonicQueuedWrite? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = _idString(json['id']);
    final paId = _idString(json['personAttendanceId']);
    final payload = json['payload'];
    if (id == null || paId == null || payload is! Map) return null;
    final userId = json['userId'];
    final createdAt = json['createdAt'];
    return IonicQueuedWrite(
      id: id,
      personAttendanceId: paId,
      payload: Map<String, dynamic>.from(payload),
      userId: userId is String && userId.isNotEmpty ? userId : null,
      createdAt: createdAt is String && createdAt.isNotEmpty
          ? createdAt
          : DateTime.now().toIso8601String(),
    );
  }

  static String? _idString(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is num) return value.toString();
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'personAttendanceId': personAttendanceId,
        'payload': payload,
        'userId': userId,
        'createdAt': createdAt,
      };
}

/// Tenant, Termin and last change (`changed_at`, null if unknown) of a
/// person_attendances row.
typedef IonicQueueTarget = ({int tenantId, int attendanceId, String? changedAt});

/// True when the record was changed on the server after the Ionic write was
/// queued: that newer change wins (whichever path made it – a Flutter online
/// write, another device, or the replay of this very Ionic write). Missing or
/// unparsable times keep the Ionic write.
@visibleForTesting
bool ionicServerChangeIsNewer(String? changedAt, String createdAt) {
  if (changedAt == null) return false;
  var server = DateTime.tryParse(changedAt);
  final queued = DateTime.tryParse(createdAt);
  if (server == null || queued == null) return false;
  // changed_at is always written as UTC; a value without offset (timestamp
  // column without time zone) is UTC, not device-local time.
  if (!server.isUtc) {
    server = DateTime.utc(server.year, server.month, server.day, server.hour,
        server.minute, server.second, server.millisecond, server.microsecond);
  }
  return server.isAfter(queued.toUtc());
}

/// Resolves person_attendances ids to their tenant and Termin – only rows of
/// instances the signed-in user belongs to (others are missing).
typedef IonicQueueResolver = Future<Map<String, IonicQueueTarget>> Function(
  List<String> personAttendanceIds,
);

/// Parses the native result `{"value": <stored value>}`. The value is the
/// array localforage stored (or its JSON string from the localStorage
/// driver). Ionic keeps at most one entry per record; duplicates are merged
/// in order (last write wins). Invalid entries are skipped.
@visibleForTesting
List<IonicQueuedWrite> parseIonicOfflineQueue(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    Object? value = decoded is Map ? decoded['value'] : null;
    if (value is String) value = jsonDecode(value);
    if (value is! List) return const [];
    final byRecord = <String, IonicQueuedWrite>{};
    for (final item in value) {
      final entry = IonicQueuedWrite.tryParse(item);
      if (entry == null) {
        debugPrint('[IonicQueue] skipping invalid entry');
        continue;
      }
      final previous = byRecord[entry.personAttendanceId];
      byRecord[entry.personAttendanceId] = previous == null
          ? entry
          : IonicQueuedWrite(
              id: previous.id,
              personAttendanceId: previous.personAttendanceId,
              payload: {...previous.payload, ...entry.payload},
              userId: entry.userId ?? previous.userId,
              createdAt: previous.createdAt,
            );
    }
    return byRecord.values.toList();
  } catch (e) {
    debugPrint('[IonicQueue] could not parse the Ionic queue: $e');
    return const [];
  }
}

/// Step 1, before `takeOverIonicSession` (which writes its keys on the first
/// start): if a Flutter version already ran here, the takeover is skipped.
/// Never throws.
Future<void> prepareIonicOfflineQueueTakeover() async {
  if (!isNativeApp) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(ionicQueueDoneKey) ||
        prefs.containsKey(_readAttemptsKey) ||
        prefs.containsKey(ionicQueuePendingKey)) {
      return;
    }
    if (_sessionTakeoverKeys.any(prefs.containsKey)) {
      await prefs.setBool(ionicQueueDoneKey, true);
      return;
    }
    // First Flutter start: mark the takeover as started before the session
    // takeover writes its keys, so a crash before the queue read does not
    // end it on the next start (the read counts attempts from here).
    if (!await prefs.setInt(_readAttemptsKey, 0)) {
      debugPrint('[IonicQueue] could not persist the start marker');
    }
  } catch (e) {
    debugPrint('[IonicQueue] prepare failed: $e');
  }
}

Future<void>? _readRun;

/// Step 2, after the session takeover; not awaited (the app start never
/// waits for it). Read errors are retried on the next starts (at most
/// [_maxReadAttempts]); an empty Ionic queue ends the takeover.
void startIonicOfflineQueueRead() {
  if (!isNativeApp) return;
  _readRun = _readIonicOfflineQueue();
}

Future<void> _readIonicOfflineQueue() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool(ionicQueueDoneKey) ?? false) ||
        prefs.containsKey(ionicQueuePendingKey)) {
      return;
    }
    final attempts = (prefs.getInt(_readAttemptsKey) ?? 0) + 1;
    await prefs.setInt(_readAttemptsKey, attempts);
    if (attempts > _maxReadAttempts) {
      await prefs.setBool(ionicQueueDoneKey, true);
      return;
    }
    final raw = await _channel
        .invokeMethod<String>('readOfflineQueue')
        .timeout(const Duration(seconds: 6));
    final entries = parseIonicOfflineQueue(raw);
    if (entries.isEmpty) {
      await prefs.setBool(ionicQueueDoneKey, true);
      return;
    }
    debugPrint('[IonicQueue] ${entries.length} unsent Ionic writes found');
    await prefs.setString(
      ionicQueuePendingKey,
      jsonEncode([for (final e in entries) e.toJson()]),
    );
  } catch (e) {
    debugPrint('[IonicQueue] read failed, retry next start: $e');
  }
}

/// Imports run one after another (never two at once).
Future<void> _importTail = Future<void>.value();

/// Step 3: adds the pending Ionic entries of [userId] to [store] and ends the
/// takeover. Entries of another Ionic user and entries [resolve] cannot map
/// to an instance of [userId] are dropped (logged); entries without a user
/// belong to [userId] (Ionic replayed them for whoever was signed in). An
/// entry is never added twice (id `ionic:<Ionic id>`), and a record that
/// already has a pending Flutter write of the user, or whose `changed_at` on
/// the server is later than the Ionic write, keeps that newer change.
///
/// Network, storage or session changes ([isCurrent] false) keep the pending
/// entries for the next try. Returns the number of added writes.
Future<int> importIonicOfflineQueue({
  required OfflineQueueStore store,
  required String userId,
  required IonicQueueResolver resolve,
  bool Function()? isCurrent,
  Future<SharedPreferences> Function()? prefs,
}) {
  final run = _importTail.then(
    (_) => _import(
      store: store,
      userId: userId,
      resolve: resolve,
      isCurrent: isCurrent ?? () => true,
      prefs: prefs ?? SharedPreferences.getInstance,
    ),
  );
  _importTail = run.then((_) {}, onError: (Object _) {});
  return run;
}

Future<int> _import({
  required OfflineQueueStore store,
  required String userId,
  required IonicQueueResolver resolve,
  required bool Function() isCurrent,
  required Future<SharedPreferences> Function() prefs,
}) async {
  try {
    final p = await prefs();
    if (p.getBool(ionicQueueDoneKey) ?? false) return 0;
    final raw = p.getString(ionicQueuePendingKey);
    if (raw == null) return 0;

    final entries = <IonicQueuedWrite>[];
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      for (final item in decoded) {
        final entry = IonicQueuedWrite.tryParse(item);
        if (entry != null) entries.add(entry);
      }
    }
    final own = [
      for (final e in entries)
        if (e.userId == null || e.userId == userId) e,
    ];
    if (own.length != entries.length) {
      debugPrint('[IonicQueue] dropping ${entries.length - own.length} '
          'writes of another Ionic user');
    }

    final targets = own.isEmpty
        ? const <String, IonicQueueTarget>{}
        : await resolve([for (final e in own) e.personAttendanceId]);
    if (!isCurrent()) return 0;

    final writes = <QueuedWrite>[];
    for (final e in own) {
      final target = targets[e.personAttendanceId];
      if (target == null) {
        debugPrint('[IonicQueue] dropping write ${e.id}: record '
            '${e.personAttendanceId} not found in an instance of the user');
        continue;
      }
      if (ionicServerChangeIsNewer(target.changedAt, e.createdAt)) {
        debugPrint('[IonicQueue] dropping write ${e.id}: record '
            '${e.personAttendanceId} changed on the server since '
            '(${target.changedAt} > ${e.createdAt})');
        continue;
      }
      final payload = {
        for (final MapEntry(:key, :value) in e.payload.entries)
          if (_ionicPayloadColumns.contains(key)) key: value,
      };
      if (payload.isEmpty) continue;
      writes.add(QueuedWrite(
        id: '$ionicQueueIdPrefix${e.id}',
        personAttendanceId: e.personAttendanceId,
        payload: payload,
        tenantId: target.tenantId,
        attendanceId: target.attendanceId,
        userId: userId,
        createdAt: e.createdAt,
      ));
    }

    var added = 0;
    if (writes.isNotEmpty) {
      await store.update((current) {
        final ids = {for (final c in current) c.id};
        final next = List<QueuedWrite>.of(current);
        for (final w in writes) {
          if (ids.contains(w.id) ||
              OfflineQueueStore.hasPendingFor(next, w.personAttendanceId,
                  userId: userId, tenantId: w.tenantId)) {
            continue;
          }
          next.add(w);
          added++;
        }
        return added == 0 ? current : next;
      });
    }
    debugPrint('[IonicQueue] took over $added unsent Ionic writes');
    // Only drop the pending copy once "done" is stored; otherwise a later run
    // retries (the ionic:<id> dedup and the changed_at check stop repeats).
    if (!await p.setBool(ionicQueueDoneKey, true)) {
      debugPrint('[IonicQueue] could not store done, keeping the entries');
      return added;
    }
    await p.remove(ionicQueuePendingKey);
    return added;
  } catch (e) {
    debugPrint('[IonicQueue] import failed, retry later: $e');
    return 0;
  }
}

/// person_attendances id → tenant + Termin, restricted to the instances
/// [userId] belongs to (tenantUsers) via the attendance join.
Future<Map<String, IonicQueueTarget>> resolveIonicQueueTargets(
  SupabaseClient supabase,
  String userId,
  List<String> personAttendanceIds,
) async {
  if (personAttendanceIds.isEmpty) return const {};
  final memberships =
      await supabase.from('tenantUsers').select('tenantId').eq('userId', userId);
  final tenantIds = {
    for (final m in memberships as List)
      if (m['tenantId'] is num) (m['tenantId'] as num).toInt(),
  }.toList();
  if (tenantIds.isEmpty) return const {};
  final result = <String, IonicQueueTarget>{};
  // Chunks keep the request URL short.
  for (var i = 0; i < personAttendanceIds.length; i += 100) {
    final chunk = personAttendanceIds.sublist(
        i, i + 100 > personAttendanceIds.length ? personAttendanceIds.length : i + 100);
    final rows = await supabase
        .from('person_attendances')
        .select(
            'id, attendance_id, changed_at, attendance:attendance_id!inner(tenantId)')
        .inFilter('id', chunk)
        .inFilter('attendance.tenantId', tenantIds);
    for (final row in rows as List) {
      final tenantId = row['attendance']?['tenantId'];
      final attendanceId = row['attendance_id'];
      if (tenantId is! num || attendanceId is! num) continue;
      if (!tenantIds.contains(tenantId.toInt())) continue;
      final changedAt = row['changed_at'];
      result[row['id'].toString()] = (
        tenantId: tenantId.toInt(),
        attendanceId: attendanceId.toInt(),
        changedAt: changedAt is String && changedAt.isNotEmpty ? changedAt : null,
      );
    }
  }
  return result;
}

/// Runs step 3 for the signed-in user when online (waits for a running
/// native read first). No-op on web/desktop, without a user and once done;
/// never throws. Called by [OfflineQueueNotifier] before it loads/replays.
final ionicOfflineQueueImportProvider = Provider<Future<int> Function()>((ref) {
  return () async {
    if (!isNativeApp) return 0;
    try {
      await _readRun;
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getBool(ionicQueueDoneKey) ?? false) ||
          !prefs.containsKey(ionicQueuePendingKey)) {
        return 0;
      }
      final userIdFn = ref.read(offlineQueueUserIdProvider);
      final userId = userIdFn();
      if (userId == null) return 0;
      if (!await ref.read(connectivityCheckProvider)()) return 0;
      return await importIonicOfflineQueue(
        store: ref.read(offlineQueueStoreProvider),
        userId: userId,
        isCurrent: () => userIdFn() == userId,
        resolve: (ids) =>
            resolveIonicQueueTargets(Supabase.instance.client, userId, ids),
      );
    } catch (e) {
      debugPrint('[IonicQueue] import skipped: $e');
      return 0;
    }
  };
});
