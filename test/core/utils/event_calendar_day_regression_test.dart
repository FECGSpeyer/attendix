import 'package:attendix/core/utils/event_list_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Run with TZ=Europe/Berlin to exercise both clock changes. These are
  // calendar-day contracts in every zone, including zones without DST.
  test('an autumn multi-day event stays current through its last day', () {
    const date = '2026-10-25T12:00:00';
    expect(EventListUtils.endDate(date, 2), DateTime(2026, 10, 26));
    expect(
      EventListUtils.hasEnded(date, 2, now: DateTime(2026, 10, 26, 23, 59)),
      isFalse,
    );
    expect(
      EventListUtils.isRunning(date, 2, now: DateTime(2026, 10, 26, 10)),
      isTrue,
    );
    expect(
      EventListUtils.hasEnded(date, 2, now: DateTime(2026, 10, 27)),
      isTrue,
    );
  });

  test('the last calendar day starts at midnight after the spring change', () {
    expect(
      EventListUtils.endDate('2026-03-29T12:00:00', 2),
      DateTime(2026, 3, 30),
    );
  });
}
