// REDESIGN: calendar-day arithmetic that ignores daylight saving time.
//
// Local midnights are 23 or 25 hours apart on the switch days, so
// `add(Duration(days: n))` can land at 23:00 of the day before and
// `difference(...).inDays` can come out one short.

/// Whole calendar days from [from] to [to]; the time of day is ignored.
int rdDaysBetween(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day)
    .difference(DateTime.utc(from.year, from.month, from.day))
    .inDays;

/// The calendar day [days] after [day], at local midnight.
DateTime rdAddDays(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);
