import 'package:attendix/features/redesign/data/rd_dates.dart';
import 'package:flutter_test/flutter_test.dart';

/// Day arithmetic across the daylight saving switches (25.10.2026 and
/// 28.3.2027 in Germany). Run with TZ=Europe/Berlin to see the old bugs.
void main() {
  test('days between ignore the time of day and DST', () {
    expect(rdDaysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
    expect(rdDaysBetween(DateTime(2026, 10, 29, 23, 30), DateTime(2026, 10, 30, 0, 10)), 1);
    expect(rdDaysBetween(DateTime(2026, 10, 29), DateTime(2027, 10, 28)), 364);
    expect(rdDaysBetween(DateTime(2027, 3, 27), DateTime(2027, 3, 29)), 2);
    expect(rdDaysBetween(DateTime(2026, 10, 30), DateTime(2026, 10, 29)), -1);
  });

  test('adding days lands on local midnight of the right day', () {
    expect(rdAddDays(DateTime(2026, 10, 24), 2), DateTime(2026, 10, 26));
    expect(rdAddDays(DateTime(2026, 10, 19, 19, 30), 7), DateTime(2026, 10, 26));
    expect(rdAddDays(DateTime(2027, 3, 26), 3), DateTime(2027, 3, 29));
    expect(rdAddDays(DateTime(2026, 12, 30), 3), DateTime(2027, 1, 2));
  });
}
