import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers/attendance_detail_providers.dart';
import '../../../core/providers/attendance_providers.dart';
import '../../../core/providers/realtime_providers.dart';
import '../../../core/services/offline_queue_service.dart';
import '../../../data/repositories/attendance_repository.dart';

/// Outcome of [writePersonAttendance].
enum PersonAttendanceWrite {
  /// Written to the database.
  saved,

  /// Offline: stored in the offline queue, sent once online again.
  queued,

  /// The row does not belong to the current tenant (nothing written).
  notAllowed,
}

/// The one write path for a person's row of a Termin (`status`, `notes`),
/// shared by the Termin page and the new design's recording view:
///
/// 1. PROFILE_OFFLINE / SOL_FIX12: offline the change goes to the offline
///    queue (Ionic OfflineQueueService); a change that cannot be queued
///    throws and is never treated as saved.
/// 2. The row must belong to the current tenant.
/// 3. SOL_FIX13: the write session captured when the user acted also guards
///    the direct write.
///
/// [beforeWrite] runs right before the direct database write (callers mark
/// the person as "saving" there). Throws when queueing or writing failed.
Future<PersonAttendanceWrite> writePersonAttendance(
  WidgetRef ref, {
  required int attendanceId,
  required String personAttendanceId,
  required Map<String, dynamic> updates,
  VoidCallback? beforeWrite,
}) =>
    PersonAttendanceWriter(ref).write(
      attendanceId: attendanceId,
      personAttendanceId: personAttendanceId,
      updates: updates,
      beforeWrite: beforeWrite,
    );

/// Writes a person's [status] for Termin [attendanceId] via
/// [writePersonAttendance]; after a direct write [refreshAfterStatusWrite]
/// runs unless [refresh] is false (several writes in a row refresh once).
Future<PersonAttendanceWrite> writePersonStatus(
  WidgetRef ref, {
  required int attendanceId,
  required String personAttendanceId,
  required AttendanceStatus status,
  VoidCallback? beforeWrite,
  bool refresh = true,
}) =>
    PersonAttendanceWriter(ref).status(
      attendanceId: attendanceId,
      personAttendanceId: personAttendanceId,
      status: status,
      beforeWrite: beforeWrite,
      refresh: refresh,
    );

/// [writePersonAttendance] split in two: the repository, the offline queue,
/// the write session and the provider container are bound when the user
/// acts (synchronously, from a mounted widget); the writes can run later,
/// also after the page was left (queued writes of the new design's
/// recording view, e.g. "Rückgängig" behind a slow write).
class PersonAttendanceWriter {
  PersonAttendanceWriter(WidgetRef ref)
      // UI_TENANT_HOIST: bind the repository before the first await.
      : _repo = ref.read(attendanceRepositoryWithTenantProvider),
        _offlineQueue = ref.read(offlineQueueNotifierProvider.notifier),
        _container = ProviderScope.containerOf(ref.context, listen: false) {
    _writeSession = _offlineQueue.captureWriteSession();
  }

  final AttendanceRepository _repo;
  final OfflineQueueNotifier _offlineQueue;
  final ProviderContainer _container;
  late final OfflineWriteSession _writeSession;

  /// See [writePersonAttendance].
  Future<PersonAttendanceWrite> write({
    required int attendanceId,
    required String personAttendanceId,
    required Map<String, dynamic> updates,
    VoidCallback? beforeWrite,
  }) async {
    final repo = _repo;
    final offlineQueue = _offlineQueue;
    final writeSession = _writeSession;
    if (await offlineQueue.enqueueIfOffline(
      personAttendanceId,
      updates,
      attendanceId: attendanceId,
      session: writeSession,
    )) {
      return PersonAttendanceWrite.queued;
    }

    if (!repo.hasTenantId || !await repo.validatePersonAttendanceTenant(personAttendanceId)) {
      return PersonAttendanceWrite.notAllowed;
    }

    beforeWrite?.call();
    await repo.updatePersonAttendance(
      personAttendanceId,
      updates,
      isSessionCurrent: writeSession.isCurrent,
      actingUserId: writeSession.userId,
    );
    return PersonAttendanceWrite.saved;
  }

  /// See [writePersonStatus].
  Future<PersonAttendanceWrite> status({
    required int attendanceId,
    required String personAttendanceId,
    required AttendanceStatus status,
    VoidCallback? beforeWrite,
    bool refresh = true,
  }) async {
    final result = await write(
      attendanceId: attendanceId,
      personAttendanceId: personAttendanceId,
      updates: {'status': status.value},
      beforeWrite: beforeWrite,
    );
    if (refresh && result == PersonAttendanceWrite.saved) {
      refreshStatuses(attendanceId);
    }
    return result;
  }

  /// [refreshAfterStatusWrite] without the widget.
  void refreshStatuses(int attendanceId) {
    _container.invalidate(realtimeAttendanceListProvider);
    if (_container.read(attendanceTypeForAttendanceProvider(attendanceId)).valueOrNull?.dutyMode ?? false) {
      _container.invalidate(personAttendancesForAttendanceProvider(attendanceId));
    }
  }
}

/// Refreshes what depends on the statuses of Termin [attendanceId]: the
/// Termin list (percentages update when navigating back) and, for duty
/// Termine, the rows (status changes also change the assignment, synced in
/// the repository).
void refreshAfterStatusWrite(WidgetRef ref, int attendanceId) {
  ref.invalidate(realtimeAttendanceListProvider);
  if (ref.read(attendanceTypeForAttendanceProvider(attendanceId)).valueOrNull?.dutyMode ?? false) {
    ref.invalidate(personAttendancesForAttendanceProvider(attendanceId));
  }
}
