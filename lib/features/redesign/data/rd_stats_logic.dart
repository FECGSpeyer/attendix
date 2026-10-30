import '../../../core/constants/enums.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/person/person.dart';

/// Time ranges of the Auswertung (canvas "Statistik").
enum RdStatsRange { season, threeMonths, twelveMonths }

/// Start of [range] on [today]; the season starts at the tenant's
/// `seasonStart` (Ionic stats default), else on 1 Jan 2023 like Ionic.
DateTime rdStatsRangeStart(RdStatsRange range, DateTime today, {String? seasonStart}) =>
    switch (range) {
      RdStatsRange.season =>
        (seasonStart == null ? null : DateTime.tryParse(seasonStart)) ?? DateTime(2023, 1, 1),
      RdStatsRange.threeMonths => DateTime(today.year, today.month - 3, today.day),
      RdStatsRange.twelveMonths => DateTime(today.year - 1, today.month, today.day),
    };

/// One person below the threshold.
class RdLowAttendance {
  const RdLowAttendance(this.person, this.percent);

  final Person person;
  final int percent;
}

/// Active people whose attendance in [personAttendances] is below
/// [threshold] percent, lowest first. Neutral entries (not expected) do not
/// count; people with fewer than [minEvents] counted Termine are left out,
/// one missed rehearsal is no trend.
List<RdLowAttendance> rdLowAttendance(
  List<PersonAttendance> personAttendances,
  List<Person> players, {
  int threshold = 50,
  int minEvents = 3,
}) {
  final present = <int, int>{};
  final total = <int, int>{};
  for (final pa in personAttendances) {
    final id = pa.personId;
    if (id == null || pa.status == AttendanceStatus.neutral) continue;
    total[id] = (total[id] ?? 0) + 1;
    if (pa.status.countsAsPresent) present[id] = (present[id] ?? 0) + 1;
  }
  final result = <RdLowAttendance>[];
  for (final player in players) {
    final id = player.id;
    if (id == null || player.paused || player.left != null) continue;
    final count = total[id] ?? 0;
    if (count < minEvents) continue;
    final percent = ((present[id] ?? 0) * 100 / count).round();
    if (percent < threshold) result.add(RdLowAttendance(player, percent));
  }
  result.sort((a, b) => a.percent.compareTo(b.percent));
  return result;
}
