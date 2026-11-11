import 'package:flutter/foundation.dart';

/// Period of the attendance rate shown in the people list ("Anwesenheit
/// zählen"). [season] is the classic rate since the season start.
enum RatePeriod { season, thisYear, threeMonths, twelveMonths, custom }

/// What the percentages of the people list count: a period and, optionally,
/// a single Terminart (else the types that count for the average).
@immutable
class AttendanceRateFilter {
  const AttendanceRateFilter({
    this.period = RatePeriod.season,
    this.from,
    this.to,
    this.typeId,
  });

  final RatePeriod period;

  /// Days of [RatePeriod.custom] (inclusive).
  final DateTime? from;
  final DateTime? to;

  /// Only this Terminart; null = all that count for the average.
  final String? typeId;

  /// The classic rate (season, counting types): no extra load needed.
  bool get isDefault => period == RatePeriod.season && typeId == null;

  AttendanceRateFilter withPeriod(RatePeriod period, {DateTime? from, DateTime? to}) =>
      AttendanceRateFilter(period: period, from: from, to: to, typeId: typeId);

  AttendanceRateFilter withType(String? typeId) =>
      AttendanceRateFilter(period: period, from: from, to: to, typeId: typeId);

  @override
  bool operator ==(Object other) =>
      other is AttendanceRateFilter &&
      other.period == period &&
      other.from == from &&
      other.to == to &&
      other.typeId == typeId;

  @override
  int get hashCode => Object.hash(period, from, to, typeId);
}

/// First day counted for [filter] on [today]; null = the season start
/// (resolved where the tenant is known).
DateTime? ratePeriodStart(AttendanceRateFilter filter, DateTime today) => switch (filter.period) {
      RatePeriod.season => null,
      RatePeriod.thisYear => DateTime(today.year, 1, 1),
      RatePeriod.threeMonths => DateTime(today.year, today.month - 3, today.day),
      RatePeriod.twelveMonths => DateTime(today.year - 1, today.month, today.day),
      RatePeriod.custom => filter.from,
    };

/// Last day counted for [filter]; null = today.
DateTime? ratePeriodEnd(AttendanceRateFilter filter) =>
    filter.period == RatePeriod.custom ? filter.to : null;
