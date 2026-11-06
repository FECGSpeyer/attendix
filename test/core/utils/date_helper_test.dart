import 'package:attendix/core/utils/date_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateHelper.localDayStartUtcIso', () {
    final expected = DateTime(2026, 11, 10).toUtc().toIso8601String();

    test('calendar day → local midnight as UTC ISO', () {
      expect(DateHelper.localDayStartUtcIso('2026-11-10'), expected);
    });

    test('UTC string of local midnight stays on the same local day', () {
      // Archive modal passes local midnight as UTC (e.g. 2026-11-09T23:00Z
      // in Germany) – must not fall back to the previous day.
      final leftDate = DateTime(2026, 11, 10).toUtc().toIso8601String();
      expect(DateHelper.localDayStartUtcIso(leftDate), expected);
    });

    test('later time of the day → start of that local day', () {
      final iso = DateTime(2026, 11, 10, 18, 30).toUtc().toIso8601String();
      expect(DateHelper.localDayStartUtcIso(iso), expected);
    });

    test('unparsable value → null', () {
      expect(DateHelper.localDayStartUtcIso('kein Datum'), isNull);
    });
  });
}
