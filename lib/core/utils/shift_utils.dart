import '../../data/models/shift/shift_plan.dart';
import '../constants/enums.dart';

/// Result of shift-based status calculation (Ionic `{ status, note }`).
class ShiftStatusResult {
  final AttendanceStatus status;
  final String note;

  const ShiftStatusResult({
    required this.status,
    this.note = '',
  });

  @override
  String toString() => 'ShiftStatusResult($status, "$note")';
}

/// Thrown by [ShiftUtils.getStatusByShift] when the person's `shift_name`
/// is not part of the plan (Ionic: `throw new Error('Shift name not found
/// in shift plan')`). Callers decide whether to skip (Ionic
/// updateShiftAssignmentsForPerson) or fall back to the default status.
class ShiftNameNotFoundException implements Exception {
  const ShiftNameNotFoundException(this.shiftName);

  final String shiftName;

  @override
  String toString() => 'Shift name not found in shift plan: $shiftName';
}

/// One person_attendances row as seen by
/// [ShiftUtils.shiftUpdatesForAttendance].
class ShiftAttendanceRow {
  const ShiftAttendanceRow({
    required this.id,
    required this.personId,
    required this.status,
    this.notes,
  });

  /// person_attendances.id
  final String id;
  final int personId;
  final AttendanceStatus status;
  final String? notes;
}

/// Shift fields of a person (`player.shift_id/shift_start/shift_name`).
class ShiftPerson {
  const ShiftPerson({this.shiftId, this.shiftStart, this.shiftName});

  final String? shiftId;
  final String? shiftStart;
  final String? shiftName;
}

/// Write produced by [ShiftUtils.shiftUpdatesForAttendance]: set [status]
/// and [notes] on the person_attendances row [id].
class ShiftAssignmentUpdate {
  const ShiftAssignmentUpdate({
    required this.id,
    required this.status,
    required this.notes,
  });

  final String id;
  final AttendanceStatus status;
  final String notes;

  @override
  String toString() => 'ShiftAssignmentUpdate($id, $status, "$notes")';
}

/// Shift-based attendance logic, ported 1:1 from Ionic
/// `Utils.getStatusByShift` and `DbService.updateShiftAssignmentsForAttendance`.
class ShiftUtils {
  ShiftUtils._();

  /// Note written on shift-excused rows (stored DB value, not translated).
  static const String shiftNote = 'Schichtbedingt';

  /// Shift plan with [shiftId] from [shifts] (Ionic `db.shifts().find`).
  static ShiftPlan? findShift(List<ShiftPlan> shifts, String? shiftId) {
    if (shiftId == null || shiftId.isEmpty) return null;
    for (final s in shifts) {
      if (s.id == shiftId) return s;
    }
    return null;
  }

  /// Local calendar day of a stored attendance date. Accepts ISO timestamps
  /// (`2026-01-05T11:00:00+00:00`, converted to local time like dayjs) and
  /// plain dates (`2026-01-05`, local midnight).
  static DateTime? localDay(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _startOfDay(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// `${day}T${time}` like dayjs: "HH:mm" or "HH:mm:ss" on the local [day].
  static DateTime? _at(DateTime day, String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null) return null;
    final s = parts.length > 2 ? (int.tryParse(parts[2].trim().split('.').first) ?? 0) : 0;
    return DateTime(day.year, day.month, day.day, h, m, s);
  }

  /// Ionic `Utils.getStatusByShift`.
  ///
  /// Walks the shift rotation from the person's start ([shiftStart], or the
  /// date of the named shift [shiftName] in `shift.shifts`) up to two days
  /// after the attendance and returns Entschuldigt with the note
  /// "Schichtbedingt" when a working (non-free) shift of the day before, the
  /// day itself or the day after overlaps the attendance time window.
  /// Otherwise [defaultStatus] with an empty note.
  ///
  /// Throws [ShiftNameNotFoundException] when [shiftName] is set but not in
  /// the plan (like Ionic).
  static ShiftStatusResult getStatusByShift({
    required ShiftPlan? shift,
    required DateTime attendanceDate,
    required String attendanceStart,
    required String attendanceEnd,
    required AttendanceStatus defaultStatus,
    String? shiftStart,
    String? shiftName,
  }) {
    final none = ShiftStatusResult(status: defaultStatus);
    if (shift == null || shift.definition.isEmpty) return none;

    final attDay = _startOfDay(attendanceDate);
    final attStart = _at(attDay, attendanceStart);
    final attEnd = _at(attDay, attendanceEnd);
    if (attStart == null || attEnd == null) return none;

    DateTime current;
    if (shiftName != null && shiftName.isNotEmpty) {
      final matching = shift.shifts.where((s) => s.name == shiftName).firstOrNull;
      if (matching == null) throw ShiftNameNotFoundException(shiftName);
      final d = localDay(matching.date);
      if (d == null) return none;
      current = d;
    } else {
      // dayjs(undefined) = now
      current = (shiftStart == null || shiftStart.isEmpty)
          ? _startOfDay(DateTime.now())
          : (localDay(shiftStart) ?? _startOfDay(DateTime.now()));
    }

    // Guard against a rotation that never advances (Ionic would loop forever).
    final cycle = shift.definition.fold<int>(0, (sum, d) => sum + (d.repeatCount > 0 ? d.repeatCount : 0));
    if (cycle <= 0) return none;

    final endDate = DateTime(attDay.year, attDay.month, attDay.day + 2);
    final checkFrom = DateTime(attDay.year, attDay.month, attDay.day - 2);

    while (current.isBefore(endDate)) {
      for (final def in shift.definition) {
        for (var i = 0; i < def.repeatCount; i++) {
          if (current.isAfter(checkFrom)) {
            final shiftStartTime = _at(current, def.startTime);
            if (shiftStartTime != null) {
              final shiftEndTime = shiftStartTime.add(
                Duration(milliseconds: (def.duration * Duration.millisecondsPerHour).round()),
              );
              if (!def.free && attStart.isBefore(shiftEndTime) && attEnd.isAfter(shiftStartTime)) {
                return const ShiftStatusResult(status: AttendanceStatus.excused, note: shiftNote);
              }
            }
          }
          current = DateTime(current.year, current.month, current.day + 1);
        }
      }
    }

    return none;
  }

  /// [getStatusByShift] for creating rows (Ionic attendance-create / add
  /// persons): an unknown shift name keeps [defaultStatus] instead of
  /// aborting the whole creation.
  static ShiftStatusResult statusByShiftOrDefault({
    required ShiftPlan? shift,
    required DateTime attendanceDate,
    required String attendanceStart,
    required String attendanceEnd,
    required AttendanceStatus defaultStatus,
    String? shiftStart,
    String? shiftName,
  }) {
    try {
      return getStatusByShift(
        shift: shift,
        attendanceDate: attendanceDate,
        attendanceStart: attendanceStart,
        attendanceEnd: attendanceEnd,
        defaultStatus: defaultStatus,
        shiftStart: shiftStart,
        shiftName: shiftName,
      );
    } on ShiftNameNotFoundException {
      return ShiftStatusResult(status: defaultStatus);
    }
  }

  /// Pure part of Ionic `updateShiftAssignmentsForAttendance`: recomputes the
  /// shift status of every row of one Termin after its date or time window
  /// changed. A manually set status is never overwritten:
  ///  - set → Entschuldigt/"Schichtbedingt" only when the row still has the
  ///    type default status,
  ///  - reset → default status + empty note only when the row is still a
  ///    shift-caused Entschuldigt that no longer overlaps (or the person lost
  ///    the shift).
  ///
  /// Returns no updates for past Termine (before today) and all-day types.
  static List<ShiftAssignmentUpdate> shiftUpdatesForAttendance({
    required String attendanceDate,
    required String? attendanceStart,
    required String? attendanceEnd,
    required String? typeStart,
    required String? typeEnd,
    required bool typeAllDay,
    required AttendanceStatus defaultStatus,
    required List<ShiftAttendanceRow> rows,
    required Map<int, ShiftPerson> persons,
    required List<ShiftPlan> shifts,
    DateTime? now,
  }) {
    final day = localDay(attendanceDate);
    if (day == null) return const [];
    final today = _startOfDay(now ?? DateTime.now());
    if (day.isBefore(today)) return const [];
    if (typeAllDay) return const [];

    final start = attendanceStart ?? typeStart;
    final end = attendanceEnd ?? typeEnd;
    final updates = <ShiftAssignmentUpdate>[];

    for (final pa in rows) {
      final person = persons[pa.personId];
      final shift = findShift(shifts, person?.shiftId);
      final shiftExcused = isWorkExcusedNote(pa.notes) && pa.status == AttendanceStatus.excused;

      if (shift != null) {
        // Ionic passes undefined times to dayjs (invalid → no overlap).
        ShiftStatusResult result;
        if (start == null || end == null) {
          result = ShiftStatusResult(status: defaultStatus);
        } else {
          try {
            result = getStatusByShift(
              shift: shift,
              attendanceDate: day,
              attendanceStart: start,
              attendanceEnd: end,
              defaultStatus: defaultStatus,
              shiftStart: person?.shiftStart,
              shiftName: person?.shiftName,
            );
          } on ShiftNameNotFoundException {
            // Ionic aborts here; skipping the row keeps the others correct.
            continue;
          }
        }

        if (result.status == AttendanceStatus.excused && pa.status == defaultStatus) {
          updates.add(ShiftAssignmentUpdate(id: pa.id, status: result.status, notes: result.note));
        } else if (result.status != AttendanceStatus.excused && shiftExcused) {
          // Previously shift-excused, but the new time no longer overlaps.
          updates.add(ShiftAssignmentUpdate(id: pa.id, status: defaultStatus, notes: ''));
        }
      } else if (shiftExcused) {
        // Person no longer has a shift but the row is still shift-excused.
        updates.add(ShiftAssignmentUpdate(id: pa.id, status: defaultStatus, notes: ''));
      }
    }
    return updates;
  }

  /// Parse time string (HH:mm) to DateTime on a specific date
  static DateTime? parseTimeOnDate(String time, DateTime date) => _at(date, time);

  /// Check if two time ranges overlap
  static bool timesOverlap(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  ) {
    return start1.isBefore(end2) && end1.isAfter(start2);
  }
}
