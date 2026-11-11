import 'package:attendix/core/utils/attendance_rate_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 11);

  group('AttendanceRateFilter', () {
    test('default is the season over all counting types', () {
      expect(const AttendanceRateFilter().isDefault, isTrue);
      expect(const AttendanceRateFilter(period: RatePeriod.thisYear).isDefault, isFalse);
      expect(const AttendanceRateFilter(typeId: 't1').isDefault, isFalse);
    });

    test('withPeriod keeps the type, withType keeps the period', () {
      const f = AttendanceRateFilter(typeId: 't1');
      final p = f.withPeriod(RatePeriod.threeMonths);
      expect(p.period, RatePeriod.threeMonths);
      expect(p.typeId, 't1');
      final t = p.withType(null);
      expect(t.period, RatePeriod.threeMonths);
      expect(t.typeId, isNull);
    });

    test('equality', () {
      expect(const AttendanceRateFilter(period: RatePeriod.thisYear, typeId: 'a'),
          const AttendanceRateFilter(period: RatePeriod.thisYear, typeId: 'a'));
      expect(const AttendanceRateFilter(period: RatePeriod.thisYear) == const AttendanceRateFilter(), isFalse);
    });
  });

  group('ratePeriodStart / ratePeriodEnd', () {
    test('season has no own start (tenant season start applies)', () {
      expect(ratePeriodStart(const AttendanceRateFilter(), today), isNull);
      expect(ratePeriodEnd(const AttendanceRateFilter()), isNull);
    });

    test('presets end today', () {
      expect(ratePeriodStart(const AttendanceRateFilter(period: RatePeriod.thisYear), today), DateTime(2026, 1, 1));
      expect(ratePeriodStart(const AttendanceRateFilter(period: RatePeriod.threeMonths), today), DateTime(2026, 8, 11));
      expect(ratePeriodStart(const AttendanceRateFilter(period: RatePeriod.twelveMonths), today), DateTime(2025, 11, 11));
      expect(ratePeriodEnd(const AttendanceRateFilter(period: RatePeriod.thisYear)), isNull);
    });

    test('three months across the year boundary', () {
      expect(ratePeriodStart(const AttendanceRateFilter(period: RatePeriod.threeMonths), DateTime(2026, 2, 10)),
          DateTime(2025, 11, 10));
    });

    test('custom uses its own days', () {
      final f = const AttendanceRateFilter()
          .withPeriod(RatePeriod.custom, from: DateTime(2026, 3, 1), to: DateTime(2026, 4, 30));
      expect(ratePeriodStart(f, today), DateTime(2026, 3, 1));
      expect(ratePeriodEnd(f), DateTime(2026, 4, 30));
    });
  });
}
