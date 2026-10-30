import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/sign_in_out_repository.dart'
    show CrossTenantPersonAttendance;
import '../../../../l10n/l10n.dart';
import '../rd_dates.dart';

/// REDESIGN: data of "Heute". Only reads through the existing
/// `…RepositoryWithTenantProvider`s (no new queries, no writes).

/// The own Termine as "Meine Termine" lists them (Ionic `applyDutyView`):
/// duty Termine without an own assignment are left out, they are taken over
/// through the duty process (`duty_take`), never answered with "Dabei".
/// Refresh by invalidating [signoutDataProvider].
final rdSignoutDataProvider = FutureProvider<SignoutData>((ref) async {
  final data = await ref.watch(signoutDataProvider.future);
  return applySignoutDutyView(data, useDutyView: false);
});

/// The Termin of the "Nächster Termin" card on "Heute": the next one the
/// person is part of. With `show_all_attendances` the list also holds Termine
/// of the instance without the person (e.g. an info entry for those not
/// invited on the same day); those only lead when no own Termin is upcoming.
CrossTenantPersonAttendance? rdTodayFocus(SignoutData data) {
  final all = data.allUpcoming;
  for (final att in all) {
    if (att.isMember) return att;
  }
  return all.isEmpty ? null : all.first;
}

/// Answers for one Termin, split like the "Heute" card
/// ("24 zugesagt · 3 entschuldigt · 2 später · 5 offen").
@immutable
class RdStatusCounts {
  const RdStatusCounts({
    this.present = 0,
    this.lateAnnounced = 0,
    this.excused = 0,
    this.absent = 0,
    this.open = 0,
  });

  /// Zugesagt / anwesend (incl. "verspätet" once recorded).
  final int present;

  /// "Kommt später" (Verspätung angekündigt).
  final int lateAnnounced;

  /// Entschuldigt / abgemeldet.
  final int excused;

  /// Unentschuldigt gefehlt.
  final int absent;

  /// No answer yet.
  final int open;

  int get total => present + lateAnnounced + excused + absent + open;

  factory RdStatusCounts.fromStatuses(Iterable<AttendanceStatus> statuses) {
    var present = 0, late = 0, excused = 0, absent = 0, open = 0;
    for (final s in statuses) {
      switch (s) {
        case AttendanceStatus.present:
        case AttendanceStatus.late:
          present++;
        case AttendanceStatus.lateExcused:
          late++;
        case AttendanceStatus.excused:
          excused++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.neutral:
          open++;
      }
    }
    return RdStatusCounts(
      present: present,
      lateAnnounced: late,
      excused: excused,
      absent: absent,
      open: open,
    );
  }
}

/// Answers of one Termin; reloads on realtime changes of the attendances.
final rdAttendanceCountsProvider =
    FutureProvider.autoDispose.family<RdStatusCounts, int>((ref, attendanceId) async {
  ref.watch(attendanceRefetchCounter);
  final repo = ref.watch(attendanceRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return const RdStatusCounts();
  final rows = await repo.getPersonAttendancesForAttendances([attendanceId]);
  return RdStatusCounts.fromStatuses(rows.map((r) => r.status));
});

/// Title, time and place of a Termin for the cards of "Heute".
@immutable
class RdEventInfo {
  const RdEventInfo({
    required this.title,
    required this.start,
    this.timeRange = '',
    this.place = '',
  });

  final String title;

  /// Start (date plus start time when known).
  final DateTime? start;

  /// "19:30–21:30" or ''.
  final String timeRange;
  final String place;
}

/// Card data of [attendance]: typeInfo, else the type name (also for types
/// that hide their name in lists), else "Termin".
RdEventInfo rdEventInfo(Attendance attendance, AttendanceType? type) {
  final info = attendance.typeInfo;
  final title = info != null && info.isNotEmpty
      ? info
      : (type?.name.isNotEmpty == true
          ? type!.name
          : l10nWithoutContext.attendanceEventFallback);
  final startTime = attendance.startTime ?? type?.startTime;
  return RdEventInfo(
    title: title,
    start: rdStartOf(attendance.date, startTime),
    timeRange: EventListUtils.timeRange(startTime, attendance.endTime ?? type?.endTime),
    place: attendance.place ?? '',
  );
}

/// Ionic `show_all_attendances_info_text` (with its default): hint below
/// Termine the person is not part of.
String rdNotMemberInfo(Tenant? tenant) {
  final text = tenant?.showAllAttendancesInfoText;
  return text != null && text.isNotEmpty ? text : EventListUtils.defaultShowAllInfoText;
}

/// [date] plus "HH:mm" [time] in local time.
DateTime? rdStartOf(String? date, String? time) {
  final day = EventListUtils.parse(date);
  if (day == null) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time ?? '');
  if (match == null) return DateTime(day.year, day.month, day.day);
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
  );
}

/// Type of [attendance] from the loaded types.
final rdAttendanceTypeProvider =
    Provider.autoDispose.family<AttendanceType?, String?>((ref, typeId) {
  if (typeId == null) return null;
  final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const [];
  return types.where((t) => t.id == typeId).firstOrNull;
});

/// Termine of the coming 7 days after [current] (at most [limit]).
List<Attendance> rdThisWeek(
  List<Attendance> upcoming, {
  DateTime? now,
  int limit = 3,
}) {
  final today = now ?? DateTime.now();
  final end = rdAddDays(today, 8);
  return upcoming
      .where((a) {
        final d = EventListUtils.parse(a.date);
        return d != null && d.isBefore(end);
      })
      .take(limit)
      .toList();
}
