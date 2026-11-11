// Chat assistant: the pure part of answering a command (dates, names,
// rates, rights). No Supabase, no Riverpod, so it is tested directly
// (test/features/assistant/assistant_logic_test.dart).
//
// The model only says WHAT is asked; every date, name and number is worked
// out here from the data the app loads with the person's own rights.

import '../../../core/constants/enums.dart';
import '../../../core/utils/person_matcher.dart' show normalizeName, levenshtein;
import 'assistant_command.dart';

/// Inclusive day range (times are ignored).
typedef DayRange = ({DateTime from, DateTime to});

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addMonths(DateTime d, int months) {
  final m = d.month - 1 + months;
  final year = d.year + (m >= 0 ? m ~/ 12 : (m - 11) ~/ 12);
  final month = m % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

DateTime _shift(DateTime d, PeriodUnit unit, int n) => switch (unit) {
      PeriodUnit.day => DateTime(d.year, d.month, d.day + n),
      PeriodUnit.week => DateTime(d.year, d.month, d.day + 7 * n),
      PeriodUnit.month => _addMonths(d, n),
      PeriodUnit.year => _addMonths(d, 12 * n),
    };

DayRange _unitAround(DateTime day, PeriodUnit unit) => switch (unit) {
      PeriodUnit.day => (from: day, to: day),
      PeriodUnit.week => (
          from: DateTime(day.year, day.month, day.day - (day.weekday - 1)),
          to: DateTime(day.year, day.month, day.day + (7 - day.weekday)),
        ),
      PeriodUnit.month => (from: DateTime(day.year, day.month, 1), to: DateTime(day.year, day.month + 1, 0)),
      PeriodUnit.year => (from: DateTime(day.year, 1, 1), to: DateTime(day.year, 12, 31)),
    };

/// The days of [period], seen from [today]. "Letzte 3 Monate" on 11.11. is
/// 11.8. to 11.11.; "diesen Monat" the whole month.
DayRange resolvePeriod(AssistantPeriod period, DateTime today, DateTime seasonStart) {
  final t = dayOf(today);
  return switch (period) {
    LastPeriod(:final unit, :final count) => (from: _shift(t, unit, -count), to: t),
    ThisPeriod(:final unit) => _unitAround(t, unit),
    PreviousPeriod(:final unit) => _unitAround(_shift(t, unit, -1), unit),
    NextPeriod(:final unit, :final count) => (from: t, to: _shift(t, unit, count)),
    SeasonPeriod() => (from: dayOf(seasonStart).isAfter(t) ? t : dayOf(seasonStart), to: t),
    RangePeriod(:final from, :final to) => (from: dayOf(from), to: dayOf(to)),
  };
}

/// The day an [EventRef] points at; null for "der nächste Termin".
/// A weekday is the next such day, today included.
DateTime? resolveEventDay(EventRef ref, DateTime today) {
  final t = dayOf(today);
  return switch (ref) {
    NextEventRef() => null,
    TodayEventRef() => t,
    TomorrowEventRef() => DateTime(t.year, t.month, t.day + 1),
    WeekdayEventRef(:final day) =>
      DateTime(t.year, t.month, t.day + ((day.index + 1 - t.weekday) % 7)),
    DateEventRef(:final date) => dayOf(date),
  };
}

/// How well [query] fits one of [names] (0 = not at all).
double nameScore(String query, Iterable<String> names) {
  final q = normalizeName(query);
  if (q.isEmpty) return 0;
  var best = 0.0;
  for (final raw in names) {
    final n = normalizeName(raw);
    if (n.isEmpty) continue;
    double s;
    if (n == q) {
      s = 1;
    } else if (n.startsWith(q) && q.length >= 3) {
      s = 0.8;
    } else if (q.length >= 4 && levenshtein(q, n) <= (q.length >= 7 ? 2 : 1)) {
      s = 0.7;
    } else {
      s = 0;
    }
    if (s > best) best = s;
  }
  return best;
}

/// The best fitting items for [query]: all items with the highest score
/// (more than one = ambiguous, the app asks), empty when none fits.
List<T> bestMatches<T>(String query, Iterable<T> items, Iterable<String> Function(T) namesOf) {
  var best = 0.0;
  var result = <T>[];
  for (final item in items) {
    final s = nameScore(query, namesOf(item));
    if (s <= 0) continue;
    if (s > best) {
      best = s;
      result = [item];
    } else if (s == best) {
      result.add(item);
    }
  }
  return result;
}

/// Names a person can be called by: first name, last name, both in either
/// order. "Jonas", "Müller", "Jonas Müller", "Müller Jonas".
Iterable<String> personNames(String firstName, String lastName) sync* {
  yield '$firstName $lastName';
  yield '$lastName $firstName';
  yield firstName;
  yield lastName;
}

/// One person_attendances row as the rate needs it.
typedef RateRow = ({
  int personId,
  DateTime date,
  String? typeId,
  AttendanceStatus status,
  String? notes,
  String? dutyState,
});

typedef RateResult = ({int attended, int total, int? percent});

/// Attendance rate like the people list (`playerAttendancePercentagesProvider`):
/// only Termine up to today, only types that count for the average (or the
/// asked type), duty Termine only where the person was assigned.
RateResult computeRate(
  Iterable<RateRow> rows, {
  required DayRange range,
  required DateTime today,
  required Set<String> countedTypeIds,
  required Set<String> dutyTypeIds,
  bool shiftExcusedAsPresent = false,
}) {
  final last = dayOf(today).isBefore(range.to) ? dayOf(today) : range.to;
  var total = 0;
  var attended = 0;
  for (final r in rows) {
    final d = dayOf(r.date);
    if (d.isBefore(range.from) || d.isAfter(last)) continue;
    if (r.typeId == null || !countedTypeIds.contains(r.typeId)) continue;
    if (dutyTypeIds.contains(r.typeId) && (r.dutyState == null || r.dutyState!.isEmpty)) continue;
    total++;
    if (r.status.countsAsAttended(notes: r.notes, shiftExcusedAsPresent: shiftExcusedAsPresent)) {
      attended++;
    }
  }
  return (attended: attended, total: total, percent: total == 0 ? null : (attended / total * 100).round());
}

/// Rate per person, lowest first (for a group: who comes least).
List<({int personId, RateResult rate})> ratesPerPerson(
  Iterable<RateRow> rows, {
  required DayRange range,
  required DateTime today,
  required Set<String> countedTypeIds,
  required Set<String> dutyTypeIds,
  bool shiftExcusedAsPresent = false,
}) {
  final byPerson = <int, List<RateRow>>{};
  for (final r in rows) {
    byPerson.putIfAbsent(r.personId, () => []).add(r);
  }
  final result = [
    for (final e in byPerson.entries)
      (
        personId: e.key,
        rate: computeRate(e.value,
            range: range,
            today: today,
            countedTypeIds: countedTypeIds,
            dutyTypeIds: dutyTypeIds,
            shiftExcusedAsPresent: shiftExcusedAsPresent),
      ),
  ].where((e) => e.rate.total > 0).toList()
    ..sort((a, b) => a.rate.percent!.compareTo(b.rate.percent!));
  return result;
}

/// The next birthday of [birthday] inside [range], or null.
DateTime? birthdayIn(String? birthday, DayRange range) {
  final b = birthday == null ? null : DateTime.tryParse(birthday);
  if (b == null) return null;
  for (var year = range.from.year; year <= range.to.year; year++) {
    // 29.2. in a common year: 28.2.
    final lastDay = DateTime(year, b.month + 1, 0).day;
    final d = DateTime(year, b.month, b.day > lastDay ? lastDay : b.day);
    if (!d.isBefore(range.from) && !d.isAfter(range.to)) return d;
  }
  return null;
}

/// Age reached on [day].
int ageOn(String birthday, DateTime day) {
  final b = DateTime.parse(birthday);
  var age = day.year - b.year;
  if (day.month < b.month || (day.month == b.month && day.day < b.day)) age--;
  return age;
}

/// What a role may ask the assistant. Same rules as the screens it stands
/// for: other people's rates, who comes, birthdays only for those who see
/// the people or manage the attendance; the own rate only with an own
/// person; everything else for every member.
class AssistantAccess {
  const AssistantAccess({required this.role, required this.hasOwnPerson});

  final Role role;
  final bool hasOwnPerson;

  bool get seesOthers => role.isConductor || role.isHelperRole;

  bool get canUse => role.canView;

  bool allows(AssistantCommand command) {
    if (!canUse) return false;
    return switch (command) {
      AttendanceRateCommand(subject: MeSubject()) => hasOwnPerson,
      AttendanceRateCommand() => seesOthers,
      EventOverviewCommand() => seesOthers,
      BirthdaysCommand() => seesOthers,
      NextEventCommand() => true,
      SongLastSungCommand() => true,
      HelpCommand() => true,
      UnsupportedCommand() => true,
    };
  }
}
