import 'dart:math';

import 'package:intl/intl.dart';

import '../../data/models/attendance/attendance.dart';
import '../../data/models/duty/person_unavailability.dart';
import '../../l10n/l10n.dart';
import '../constants/enums.dart';

/// Dienstplan helpers (Termintypen im Dienst-Modus), ported from Ionic
/// `utilities/duty.ts`.
///
/// A person "occupies" a duty when they were assigned (duty_state set) and did
/// not cancel. Persons without duty_state are stand-ins: they stay Neutral, are
/// not expected and do not count towards the attendance average.
class DutyState {
  DutyState._();

  static const requested = 'requested';
  static const confirmed = 'confirmed';
  static const self = 'self';
}

/// full = enough persons and all confirmed, requested = enough persons but
/// some unconfirmed, partial = some persons, open = nobody.
enum DutyFill { full, requested, partial, open }

const _cancelledStatuses = {
  AttendanceStatus.excused,
  AttendanceStatus.lateExcused,
  AttendanceStatus.absent,
};

/// Duty state after a status change. Zugesagt/Verspätet → bestätigt (also for
/// stand-ins), Neutral after a confirmation → angefragt.
String? dutyStateAfterStatus(String? current, AttendanceStatus status) {
  if (status == AttendanceStatus.present || status == AttendanceStatus.late) {
    return (current == null || current == DutyState.requested) ? DutyState.confirmed : current;
  }
  if (status == AttendanceStatus.neutral &&
      (current == DutyState.confirmed || current == DutyState.self)) {
    return DutyState.requested;
  }
  return current;
}

/// Duty fields to write along with a status change of a person_attendances
/// row (Ionic `syncDutyWithStatus`, utilities/db-helpers.ts). Returns an empty
/// map when the Termin is not of a duty type or the duty state is unchanged.
Map<String, dynamic> dutySyncFieldsForStatus({
  required bool isDutyTermin,
  required String? currentDutyState,
  required AttendanceStatus newStatus,
  required String? userId,
  DateTime? now,
}) {
  if (!isDutyTermin) return const {};
  final next = dutyStateAfterStatus(currentDutyState, newStatus);
  if (next == currentDutyState) return const {};
  return {
    'duty_state': next,
    if (next == DutyState.confirmed) 'duty_reminder_sent': true,
    if (next == DutyState.confirmed && currentDutyState == null) ...{
      'duty_assigned_by': userId,
      'duty_assigned_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
    },
  };
}

bool isDutyType(AttendanceType? type) => type?.dutyMode ?? false;

/// Persons needed for a Termin (at least 1).
int dutyRequired(Attendance? att, AttendanceType? type) {
  return max(1, att?.dutyRequired ?? type?.dutyRequired ?? 1);
}

bool isCancelledStatus(AttendanceStatus status) => _cancelledStatuses.contains(status);

bool isCancelled(PersonAttendance pa) => isCancelledStatus(pa.status);

/// Assigned (requested, confirmed or self) and not cancelled.
bool occupiesDutyRaw(String? dutyState, AttendanceStatus status) =>
    dutyState != null && dutyState.isNotEmpty && !isCancelledStatus(status);

bool occupiesDuty(PersonAttendance pa) => occupiesDutyRaw(pa.dutyState, pa.status);

/// Assigned and confirmed (or took the duty themselves), not cancelled.
bool confirmedDuty(PersonAttendance pa) =>
    (pa.dutyState == DutyState.confirmed || pa.dutyState == DutyState.self) && !isCancelled(pa);

int occupiedCount(List<PersonAttendance>? persons) =>
    (persons ?? const []).where(occupiesDuty).length;

DutyFill dutyFill(List<PersonAttendance>? persons, int required) {
  final occupied = (persons ?? const <PersonAttendance>[]).where(occupiesDuty).toList();
  if (occupied.length >= required) {
    return occupied.every(confirmedDuty) ? DutyFill.full : DutyFill.requested;
  }
  return occupied.isNotEmpty ? DutyFill.partial : DutyFill.open;
}

String dutyStateLabel(String? state) {
  switch (state) {
    case DutyState.requested:
      return l10nWithoutContext.attendanceRequested;
    case DutyState.confirmed:
      return l10nWithoutContext.attendanceConfirmed;
    case DutyState.self:
      return l10nWithoutContext.attendanceSelfSignedUp;
    default:
      return '';
  }
}

/// Whether a person attendance counts for the attendance average. For duty
/// types only assigned persons count; stand-ins are left out.
bool countsForAverage(AttendanceType? type, String? dutyState, {bool fallback = false}) {
  if (type == null) return fallback;
  if (!type.includeInAverage) return false;
  return !(type.dutyMode && (dutyState == null || dutyState.isEmpty));
}

/// Persons of a Termin that count for its percentage (all, or only assigned ones for duties).
List<PersonAttendance> averagePersons(List<PersonAttendance>? persons, AttendanceType? type) {
  if (!isDutyType(type)) return persons ?? const [];
  return (persons ?? const <PersonAttendance>[])
      .where((pa) => pa.dutyState != null && pa.dutyState!.isNotEmpty)
      .toList();
}

/// ISO weekday (1 = Monday … 7 = Sunday) of a Termin date, in local time.
int isoWeekday(String date) {
  final d = DateTime.tryParse(date);
  if (d == null) return 1;
  return d.toLocal().weekday;
}

const _weekdayShortNamesDe = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _weekdayLongNamesDe = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];

const _monthNamesDe = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

// I18N: German keeps the fixed names; other languages use intl.
// 2024-01-01 is a Monday.
List<String> _intlWeekdays(String pattern) => [
      for (var i = 0; i < 7; i++)
        DateFormat(pattern, currentIntlLocale()).format(DateTime(2024, 1, 1 + i)),
    ];

/// Short weekday names, Monday first ("Mo", "Di", …).
List<String> get weekdayShortNames => currentLanguage() == 'de'
    ? _weekdayShortNamesDe
    : _intlWeekdays('EEE').map((n) => n.length > 2 ? n.substring(0, 2) : n).toList();

/// Long weekday names, Monday first.
List<String> get weekdayLongNames =>
    currentLanguage() == 'de' ? _weekdayLongNamesDe : _intlWeekdays('EEEE');

/// Month names, January first.
List<String> get monthNames => currentLanguage() == 'de'
    ? _monthNamesDe
    : [
        for (var m = 1; m <= 12; m++)
          DateFormat('MMMM', currentIntlLocale()).format(DateTime(2024, m)),
      ];

String weekdaysText(List<int> weekdays) {
  final sorted = [...weekdays]..sort();
  return sorted.where((d) => d >= 1 && d <= 7).map((d) => weekdayShortNames[d - 1]).join(', ');
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The first unavailability rule of a person that matches the date and type.
PersonUnavailability? matchingUnavailability(
  List<PersonUnavailability> rules,
  int personId,
  String date,
  String? typeId,
) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return null;
  final day = _dayOnly(parsed.toLocal());
  final weekday = day.weekday;
  for (final rule in rules) {
    if (rule.personId != personId) continue;
    if (!rule.weekdays.contains(weekday)) continue;
    if (rule.typeIds.isNotEmpty && (typeId == null || !rule.typeIds.contains(typeId))) continue;
    if (rule.validUntil != null && rule.validUntil!.isNotEmpty) {
      final until = DateTime.tryParse(rule.validUntil!);
      if (until != null && day.isAfter(_dayOnly(until))) continue;
    }
    return rule;
  }
  return null;
}

String unavailabilityNote(PersonUnavailability rule) {
  final reason = rule.reason.trim();
  return reason.isNotEmpty ? 'Regelmäßig verhindert: $reason' : 'Regelmäßig verhindert';
}

/// One duty Termin with open places, for [distributeDuties].
class DutySlot {
  const DutySlot({
    required this.attendanceId,
    required this.date,
    required this.candidates,
    required this.occupied,
    required this.open,
  });

  final int attendanceId;
  final String date;

  /// Persons that can be picked (in the Termin, not cancelled, not assigned).
  final List<int> candidates;

  /// Persons already occupying the duty.
  final List<int> occupied;
  final int open;
}

String _dayKey(String date) {
  final d = DateTime.tryParse(date)?.toLocal();
  if (d == null) return date;
  return '${d.year}-${d.month}-${d.day}';
}

/// Fair distribution of open duty places. Persons with the fewest duties
/// (existing + already planned in this run) are picked first; ties are broken
/// randomly so repeated runs give different but equally fair plans.
Map<int, List<int>> distributeDuties(
  List<DutySlot> slots,
  Map<int, int> baseCounts, {
  required int maxPerPerson,
  required bool notTwiceSameDay,
  Random? random,
}) {
  final rnd = random ?? Random();
  final counts = Map<int, int>.from(baseCounts);
  final plannedInRun = <int, int>{};
  final busyDays = <int, Set<String>>{};
  final result = <int, List<int>>{};

  void markDay(int personId, String date) {
    busyDays.putIfAbsent(personId, () => <String>{}).add(_dayKey(date));
  }

  for (final slot in slots) {
    for (final personId in slot.occupied) {
      markDay(personId, slot.date);
    }
  }

  final sorted = [...slots]
    ..sort((a, b) => (DateTime.tryParse(a.date) ?? DateTime(0))
        .compareTo(DateTime.tryParse(b.date) ?? DateTime(0)));

  for (final slot in sorted) {
    final picked = <int>[];
    final day = _dayKey(slot.date);
    for (var i = 0; i < slot.open; i++) {
      final pool = slot.candidates
          .where((id) =>
              !picked.contains(id) &&
              (plannedInRun[id] ?? 0) < maxPerPerson &&
              !(notTwiceSameDay && (busyDays[id]?.contains(day) ?? false)))
          .toList();
      if (pool.isEmpty) break;
      // Random order first, then stable sort by count → random tie-breaks.
      final shuffled = pool.map((id) => MapEntry(id, rnd.nextDouble())).toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final ordered = shuffled.map((e) => e.key).toList();
      mergeSortStable(ordered, (a, b) => (counts[a] ?? 0).compareTo(counts[b] ?? 0));
      final personId = ordered.first;
      picked.add(personId);
      counts[personId] = (counts[personId] ?? 0) + 1;
      plannedInRun[personId] = (plannedInRun[personId] ?? 0) + 1;
      markDay(personId, slot.date);
    }
    if (picked.isNotEmpty) result[slot.attendanceId] = picked;
  }
  return result;
}

/// Stable in-place sort (List.sort is not guaranteed to be stable).
void mergeSortStable<T>(List<T> list, int Function(T a, T b) compare) {
  if (list.length < 2) return;
  final copy = [...list];
  copy.asMap().entries.toList()
    ..sort((a, b) {
      final c = compare(a.value, b.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    })
    ..asMap().forEach((i, e) => list[i] = e.value);
}
