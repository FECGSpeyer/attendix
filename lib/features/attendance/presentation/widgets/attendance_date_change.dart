import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/utils/attendance_logic_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/player_absence/player_absence.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'attendance_detail/status_chip.dart' show ionicStatusLabel;

/// SOL_FIX35: whole calendar days between the local dates of [from] and
/// [to]. Computed on UTC date values, so a DST change in between (e.g.
/// 29.03.→30.03.2026 in Europe/Berlin, only 23 hours) still counts 1.
int calendarDayDifference(DateTime from, DateTime to) {
  final a = from.isUtc ? from.toLocal() : from;
  final b = to.isUtc ? to.toLocal() : to;
  return DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// SOL_FIX35: moves [value] by [days] calendar days keeping its local wall
/// time across DST changes; a UTC value stays UTC.
DateTime shiftByCalendarDays(DateTime value, int days) {
  final l = value.isUtc ? value.toLocal() : value;
  final moved = DateTime(l.year, l.month, l.day + days, l.hour, l.minute, l.second, l.millisecond, l.microsecond);
  return value.isUtc ? moved.toUtc() : moved;
}

/// Ionic `hasNonDefaultStatus`: someone deviates from the type's default.
bool hasNonDefaultStatus(Iterable<AttendanceStatus> statuses, AttendanceType? type) {
  if (type == null) return false;
  return statuses.any((s) => s != type.defaultStatus);
}

/// Reads an (autoDispose) future provider once and keeps it alive while
/// waiting – callers outside the page (Teamorganisation) do not listen.
Future<T> _readOnce<T>(ProviderContainer container, ProviderListenable<Future<T>> provider) async {
  final sub = container.listen<Future<T>>(provider, (_, __) {});
  try {
    return await sub.read();
  } finally {
    sub.close();
  }
}

/// "Datum ändern" (Ionic `promptAttendanceDateChange` + `changeAttendanceDate`),
/// shared by the attendance detail and the Teamorganisation "Themen" tab:
/// asks for the new day, asks to keep or reset the statuses when somebody
/// deviates from the type's default, moves the Termin (deadline and checklist
/// due dates move along), moves the history dates, re-applies planned
/// absences and the shift computation. All writes go through the tenant
/// repositories (`tenantId` filtered).
///
/// [currentStatuses]: statuses the caller already shows (attendance detail);
/// otherwise they are loaded fresh like Ionic `getAttendanceById`.
/// Returns true when the Termin was moved.
Future<bool> promptAttendanceDateChange(
  BuildContext context,
  WidgetRef ref,
  int attendanceId, {
  Iterable<AttendanceStatus>? currentStatuses,
}) async {
  // UI_TENANT_HOIST / SOL_FIX13: repositories, container and the session of
  // the acting user are captured before the first await.
  final container = ProviderScope.containerOf(context, listen: false);
  final repo = ref.read(attendanceRepositoryWithTenantProvider);
  final offlineQueue = ref.read(offlineQueueNotifierProvider.notifier);
  final writeSession = offlineQueue.captureWriteSession();
  final playerAbsenceRepo = ref.read(playerAbsenceRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return false;

  Attendance? attendance;
  AttendanceType? type;
  try {
    attendance = await _readOnce(container, attendanceDetailProvider(attendanceId).future);
    type = await _readOnce(container, attendanceTypeForAttendanceProvider(attendanceId).future);
  } catch (_) {
    attendance = null;
  }
  if (!context.mounted) return false;
  if (attendance == null) {
    ToastHelper.showError(context, context.l10n.dateDialogLoadFailed);
    return false;
  }

  final current = DateTime.tryParse(attendance.date)?.toLocal() ?? DateTime.now();
  final picked = await showAppDatePicker(
    context: context,
    initialDate: current,
    firstDate: DateTime(current.year - 5),
    lastDate: DateTime(current.year + 5),
    helpText: context.l10n.dateDialogMoveTo,
  );
  if (picked == null || !context.mounted) return false;
  if (DateUtils.isSameDay(picked, current)) return false;

  var statuses = currentStatuses;
  if (statuses == null && type != null) {
    try {
      container.invalidate(personAttendancesForAttendanceProvider(attendanceId));
      final rows = await _readOnce(container, personAttendancesForAttendanceProvider(attendanceId).future);
      statuses = rows.map((r) => r.status);
    } catch (_) {
      if (context.mounted) ToastHelper.showError(context, context.l10n.dateDialogLoadFailed);
      return false;
    }
    if (!context.mounted) return false;
  }

  var reset = false;
  if (hasNonDefaultStatus(statuses ?? const [], type)) {
    final choice = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.dateDialogResetStatus),
        content: Text(
          context.l10n.dateDialogResetStatusMessage(ionicStatusLabel(type!.defaultStatus)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: Text(context.l10n.dateDialogKeep)),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'reset'), child: Text(context.l10n.dateDialogReset)),
        ],
      ),
    );
    if (choice == null || !context.mounted) return false;
    reset = choice == 'reset';
  }

  final l10n = context.l10n;
  try {
    final normalized = DateTime(picked.year, picked.month, picked.day, 12);
    final days = calendarDayDifference(current, normalized);
    final normalizedIso = normalized.toUtc().toIso8601String();

    // Deadline and checklist due dates move along with the Termin.
    String? shift(String? value) {
      if (value == null || value.isEmpty) return value;
      final d = DateTime.tryParse(value);
      return d == null ? value : shiftByCalendarDays(d, days).toIso8601String();
    }

    final checklist = attendance.checklist
        ?.map((item) => item.copyWith(dueDate: shift(item.dueDate)).toJson())
        .toList();
    await repo.updateAttendance(attendanceId, {
      'date': normalizedIso,
      if (attendance.deadline != null) 'deadline': shift(attendance.deadline),
      if (checklist != null) 'checklist': checklist,
    });
    await repo.updateHistoryDatesForAttendance(attendanceId, normalizedIso);
    if (type != null) {
      // LOGIC_ATT: Ionic changeAttendanceDate – absences on the new day
      // excuse persons still on the default status (or everyone when
      // reset), reset the rest, then re-run the shift computation.
      container.invalidate(personAttendancesForAttendanceProvider(attendanceId));
      final rows = await _readOnce(container, personAttendancesForAttendanceProvider(attendanceId).future);
      List<PlayerAbsence> absences;
      try {
        absences = await playerAbsenceRepo.getAbsencesForTenant();
      } catch (_) {
        absences = const []; // non-fatal — proceed without absence check
      }
      final updates = dateChangeStatusUpdates(
        rows: [
          for (final r in rows)
            if (r.id != null && r.personId != null)
              (id: r.id!, personId: r.personId!, status: r.status, notes: r.notes),
        ],
        absences: absences,
        newDay: normalized,
        defaultStatus: type.defaultStatus,
        resetStatuses: reset,
      );
      // LEFTOVERS: like every Ionic updatePersonAttendance, queued while offline
      for (final u in updates) {
        final payload = {'status': u.status.value, 'notes': u.notes};
        if (await offlineQueue.enqueueIfOffline(u.id, payload,
            attendanceId: attendanceId, session: writeSession)) {
          continue;
        }
        // SOL_FIX13: guarded by the session captured when the user acted.
        await repo.updatePersonAttendance(
          u.id,
          payload,
          isSessionCurrent: writeSession.isCurrent,
          actingUserId: writeSession.userId,
        );
      }
      await repo.updateShiftAssignmentsForAttendance(attendanceId);
    }

    container.invalidate(attendanceDetailProvider(attendanceId));
    container.invalidate(personAttendancesForAttendanceProvider(attendanceId));
    if (context.mounted) {
      ToastHelper.showSuccess(
        context,
        l10n.dateDialogMoved(DateFormat('EE, ${dateFmt()}', currentIntlLocale()).format(normalized)),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, l10n.dateDialogChangeFailed);
    return false;
  }
}
