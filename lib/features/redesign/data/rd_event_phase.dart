/// REDESIGN (concept "Termin-Bereich neu", Schritt 2): the phase of a
/// Termin. The card at the top of the Termin (Jetzt-Karte) and the pill in
/// its head follow it, for the Leitung and for members.
library;

import 'rd_dates.dart';

enum RdEventPhase {
  /// Before the Termin day.
  before,

  /// Termin day, before the start (single-day Termine without a start
  /// time: the whole day).
  today,

  /// From the start until the end.
  running,

  /// After the end.
  after,

  /// Archived (Ionic `archived`), whatever the date.
  archived,
}

/// Start and end of a Termin as local times. [start] carries the start time
/// when [hasTime]; [end] is the end time on the last day, or the end of the
/// last day without an end time.
({DateTime start, DateTime end, bool hasTime})? rdEventSpan({
  required DateTime? day,
  String? startTime,
  String? endTime,
  int? durationDays,
}) {
  if (day == null) return null;
  final first = DateTime(day.year, day.month, day.day);
  final last = rdAddDays(first, (durationDays ?? 1).clamp(1, 366) - 1);
  final s = _time(startTime);
  final e = _time(endTime);
  final start = s == null ? first : DateTime(first.year, first.month, first.day, s.$1, s.$2);
  var end = e == null ? rdAddDays(last, 1) : DateTime(last.year, last.month, last.day, e.$1, e.$2);
  // "22:00–01:00" ends the next morning.
  if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
  return (start: start, end: end, hasTime: s != null);
}

(int, int)? _time(String? value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value ?? '');
  if (match == null) return null;
  return (int.parse(match.group(1)!), int.parse(match.group(2)!));
}

/// Phase of a Termin with [span] (see [rdEventSpan]) at [now].
RdEventPhase rdEventPhase(
  ({DateTime start, DateTime end, bool hasTime})? span, {
  bool archived = false,
  DateTime? now,
}) {
  if (archived) return RdEventPhase.archived;
  if (span == null) return RdEventPhase.before;
  final current = now ?? DateTime.now();
  if (!current.isBefore(span.end)) return RdEventPhase.after;
  final firstDay = DateTime(span.start.year, span.start.month, span.start.day);
  final multiDay = rdAddDays(firstDay, 1).isBefore(span.end) && !span.hasTime;
  if (span.hasTime || multiDay) {
    if (!current.isBefore(span.start)) return RdEventPhase.running;
  }
  final today = DateTime(current.year, current.month, current.day);
  return today == firstDay ? RdEventPhase.today : RdEventPhase.before;
}
