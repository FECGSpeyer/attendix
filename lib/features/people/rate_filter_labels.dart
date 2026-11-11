import 'package:intl/intl.dart';

import '../../core/utils/attendance_rate_filter.dart';
import '../../data/models/attendance/attendance.dart' show AttendanceType;
import '../../l10n/l10n.dart';

/// Label of a period of "Anwesenheit zählen"; a custom period shows its days.
String ratePeriodLabel(AppLocalizations l10n, RatePeriod period, {AttendanceRateFilter? filter}) {
  if (period == RatePeriod.custom && filter?.period == RatePeriod.custom && filter?.from != null && filter?.to != null) {
    final fmt = DateFormat(dateFmt(DateFmtKind.short));
    return '${fmt.format(filter!.from!)} – ${fmt.format(filter.to!)}';
  }
  return switch (period) {
    RatePeriod.season => l10n.peopleRateSeason,
    RatePeriod.thisYear => l10n.peopleRateThisYear,
    RatePeriod.threeMonths => l10n.peopleRateThreeMonths,
    RatePeriod.twelveMonths => l10n.peopleRateTwelveMonths,
    RatePeriod.custom => l10n.peopleRateCustom,
  };
}

/// Name of the chosen Terminart, or "Alle, die zählen".
String rateTypeLabel(AppLocalizations l10n, String? typeId, List<AttendanceType> types) {
  if (typeId == null) return l10n.peopleRateAllTypes;
  return types.where((t) => t.id == typeId).map((t) => t.name).firstOrNull ?? l10n.peopleRateAllTypes;
}

/// Chip text of a non-default filter: "Quote: Dieses Jahr · Probe".
String rateFilterChip(AppLocalizations l10n, AttendanceRateFilter filter, List<AttendanceType> types) {
  final parts = [
    if (filter.period != RatePeriod.season || filter.typeId == null) ratePeriodLabel(l10n, filter.period, filter: filter),
    if (filter.typeId != null) rateTypeLabel(l10n, filter.typeId, types),
  ];
  return l10n.peopleRateChip(parts.join(' · '));
}
