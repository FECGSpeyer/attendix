import '../../core/constants/enums.dart';
import '../../data/models/tenant/tenant.dart';

/// Start date of the attendance window shown on the person page (Ionic
/// db.getPersonAttendances / getCurrentAttDate): the tenant's season start
/// (fallback 2023-01-01); archived persons (`hasLeft`) see everything since
/// 2020-01-01.
DateTime personAttendanceWindowStart({String? seasonStart, bool hasLeft = false}) {
  if (hasLeft) return DateTime(2020, 1, 1);
  return (seasonStart != null ? DateTime.tryParse(seasonStart) : null) ??
      DateTime(2023, 1, 1);
}

/// Ionic person.page `lateThreshold`: threshold of the first critical rule
/// that counts "Verspätet"; 999 (= never) without such a rule.
int lateWarningThreshold(List<CriticalRule>? rules) {
  for (final rule in rules ?? const <CriticalRule>[]) {
    if (rule.statuses.contains(AttendanceStatus.late.value)) {
      return rule.thresholdValue;
    }
  }
  return 999;
}

/// Ionic person.page getHistoryInfo statistics from `person_attendances`
/// rows (`status`, `notes`, `duty_state`, `attendance: {date, attType:
/// {include_in_average, duty_mode}}`):
/// - `percentage`: attended / counted, only attendances whose type has
///   `include_in_average` (duties only when the person was assigned),
/// - `lateCount` / `lateCountExcused`: "Verspätet" / "Verspätet
///   (entschuldigt)" after `lastSolve` (reset by "Gespräch geführt").
Map<String, int> computePersonAttendanceStats(
  List<Map<String, dynamic>> rows, {
  required DateTime now,
  required DateTime windowStart,
  String? lastSolve,
  bool shiftExcusedAsPresent = false,
}) {
  final solvedAt = lastSolve != null ? DateTime.tryParse(lastSolve) : null;
  var total = 0;
  var attended = 0;
  var counted = 0;
  var lateCount = 0;
  var lateCountExcused = 0;

  for (final row in rows) {
    final attendance = row['attendance'];
    if (attendance is! Map) continue;
    final date = DateTime.tryParse(attendance['date']?.toString() ?? '');
    if (date == null || !date.isAfter(windowStart) || !date.isBefore(now)) {
      continue;
    }
    total++;
    final rawStatus = row['status'];
    final status = rawStatus is int
        ? rawStatus
        : int.tryParse(rawStatus?.toString() ?? '') ?? 0;
    final isAttended = AttendanceStatus.fromValue(status).countsAsAttended(
      notes: row['notes'] as String?,
      shiftExcusedAsPresent: shiftExcusedAsPresent,
    );

    final attType = attendance['attType'];
    final includeInAverage = attType is Map &&
        attType['include_in_average'] == true &&
        !(attType['duty_mode'] == true && row['duty_state'] == null);
    if (includeInAverage) {
      counted++;
      if (isAttended) attended++;
    }

    if (solvedAt == null || date.isAfter(solvedAt)) {
      if (status == AttendanceStatus.late.value) lateCount++;
      if (status == AttendanceStatus.lateExcused.value) lateCountExcused++;
    }
  }

  return {
    'total': total,
    'counted': counted,
    'attended': attended,
    'percentage': counted > 0 ? (attended / counted * 100).round() : 0,
    'lateCount': lateCount,
    'lateCountExcused': lateCountExcused,
  };
}

/// Player history types a non-admin sees on the person page (Ionic
/// getHistoryInfo: INSTRUMENT_CHANGE, PAUSED, UNPAUSED).
const visibleHistoryTypesForMembers = <int>{7, 1, 6};
