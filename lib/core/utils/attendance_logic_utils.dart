import 'package:intl/intl.dart';

import '../../data/models/attendance/attendance.dart' show AttendanceType; // P10_ATTENDANCE
import '../../data/models/player_absence/player_absence.dart';
import '../constants/enums.dart';

/// Planned absence (`player_absences`) of [personId] that covers the local
/// calendar day of [day] (Ionic attendance-create: `!day.isBefore(from_date,
/// 'day') && !day.isAfter(until_date, 'day')`), or null.
PlayerAbsence? absenceOnDay(List<PlayerAbsence> absences, int personId, DateTime day) {
  final local = day.isUtc ? day.toLocal() : day;
  final key = DateFormat('yyyy-MM-dd').format(local);
  for (final a in absences) {
    if (a.personId != personId) continue;
    if (a.fromDate.length < 10 || a.untilDate.length < 10) continue;
    if (a.fromDate.substring(0, 10).compareTo(key) <= 0 &&
        a.untilDate.substring(0, 10).compareTo(key) >= 0) {
      return a;
    }
  }
  return null;
}

/// Status/notes write on one person_attendances row.
typedef PersonStatusUpdate = ({String id, AttendanceStatus status, String notes});

/// Row of a Termin as needed by [dateChangeStatusUpdates].
typedef PersonStatusRow = ({String id, int personId, AttendanceStatus status, String? notes});

/// Ionic `changeAttendanceDate` (after the date moved to [newDay]):
///  - a planned absence on the new day excuses the person (reason as note)
///    when the row is still on [defaultStatus] or [resetStatuses] is set,
///  - with [resetStatuses] every other row with a non-default status or a
///    note goes back to [defaultStatus] with an empty note.
List<PersonStatusUpdate> dateChangeStatusUpdates({
  required List<PersonStatusRow> rows,
  required List<PlayerAbsence> absences,
  required DateTime newDay,
  required AttendanceStatus defaultStatus,
  required bool resetStatuses,
}) {
  final updates = <PersonStatusUpdate>[];
  for (final pa in rows) {
    final absence = absenceOnDay(absences, pa.personId, newDay);
    final isDefault = resetStatuses || pa.status == defaultStatus;
    if (absence != null && isDefault) {
      updates.add((id: pa.id, status: AttendanceStatus.excused, notes: absence.reason));
    } else if (resetStatuses && (pa.status != defaultStatus || (pa.notes?.isNotEmpty ?? false))) {
      updates.add((id: pa.id, status: defaultStatus, notes: ''));
    }
  }
  return updates;
}

/// Ionic `onDeadlineToggleChanged`: the day before the Termin at
/// (type start hour + 2):00 (19:00 without a start time); when that is
/// already past, the Termin day itself at that hour. Local time.
DateTime defaultDeadline(DateTime attendanceDate, String? typeStartTime, {DateTime? now}) {
  final local = attendanceDate.toLocal();
  final startHour = (typeStartTime != null && typeStartTime.length >= 2)
      ? int.tryParse(typeStartTime.substring(0, 2))
      : null;
  final hour = startHour != null ? startHour + 2 : 19;
  final dayBefore = DateTime(local.year, local.month, local.day - 1, hour);
  if (dayBefore.isBefore(now ?? DateTime.now())) {
    return DateTime(local.year, local.month, local.day, hour);
  }
  return dayBefore;
}

/// Song history row of a Termin (`history`).
typedef HistoryRowKey = ({int id, int songId, int? personId, String? otherConductor});

/// Wanted song history entry of a Termin.
typedef HistoryEntryKey = ({int songId, int? personId, String? otherConductor});

/// Plan to bring the stored history rows of a Termin to [wanted] with
/// Ionic's single-row operations (addSongsToHistory / updateHistoryEntry
/// conductor change / removeHistoryEntry) instead of delete + re-insert, so
/// ids, created_at and `visible` of unchanged rows are kept.
({List<int> delete, List<({int id, HistoryEntryKey entry})> update, List<HistoryEntryKey> insert})
    planHistorySync(List<HistoryRowKey> existing, List<HistoryEntryKey> wanted) {
  String? norm(String? v) => (v == null || v.isEmpty) ? null : v;
  bool same(HistoryRowKey r, HistoryEntryKey e) =>
      r.songId == e.songId &&
      norm(r.otherConductor) == norm(e.otherConductor) &&
      (norm(e.otherConductor) != null || r.personId == e.personId);

  final rest = List.of(existing);
  final unmatched = <HistoryEntryKey>[];
  for (final e in wanted) {
    final i = rest.indexWhere((r) => same(r, e));
    if (i >= 0) {
      rest.removeAt(i);
    } else {
      unmatched.add(e);
    }
  }
  final update = <({int id, HistoryEntryKey entry})>[];
  final insert = <HistoryEntryKey>[];
  for (final e in unmatched) {
    // Same song with another conductor -> conductor change on that row.
    final i = rest.indexWhere((r) => r.songId == e.songId);
    if (i >= 0) {
      update.add((id: rest.removeAt(i).id, entry: e));
    } else {
      insert.add(e);
    }
  }
  return (delete: [for (final r in rest) r.id], update: update, insert: insert);
}

/// P10_ATTENDANCE: Ionic `showSongsSelection()` / `manageSongs && !isGeneral`:
/// the Werke section only for types with `manage_songs`, never for
/// "general" tenants.
bool showSongsForType(AttendanceType? type, String? tenantType) =>
    (type?.manageSongs ?? false) && tenantType != 'general';
