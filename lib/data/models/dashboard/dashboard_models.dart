import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_models.freezed.dart';
part 'dashboard_models.g.dart';

/// Card ids of the home dashboard (Ionic `DashboardCardId`).
///
/// Wire values are stored in Supabase `user_metadata['dashboardCards_<tenantId>']`
/// and MUST match Ionic exactly so both apps share the same configuration.
abstract class DashboardCardIds {
  static const String birthdays = 'birthdays';
  static const String nextEvent = 'next-event';
  static const String memberChanges = 'member-changes';
  static const String absences = 'absences';
  static const String criticalPersons = 'critical-persons';
  static const String currentSongs = 'current-songs';
  static const String currentPlan = 'current-plan';
  static const String myTasks = 'my-tasks';

  /// Default order (Ionic `DEFAULT_DASHBOARD_CARDS`).
  static const List<String> all = [
    birthdays,
    nextEvent,
    memberChanges,
    absences,
    criticalPersons,
    currentSongs,
    currentPlan,
    myTasks,
  ];
}

/// Visibility/order entry of one dashboard card (Ionic `DashboardCardConfig`).
@freezed
class DashboardCardConfig with _$DashboardCardConfig {
  const factory DashboardCardConfig({
    required String id,
    @Default(true) bool visible,
  }) = _DashboardCardConfig;

  factory DashboardCardConfig.fromJson(Map<String, dynamic> json) =>
      _$DashboardCardConfigFromJson(json);
}

/// Row of `player_absences` (Ionic `PlayerAbsence`), used by the absences card.
@freezed
class DashboardAbsence with _$DashboardAbsence {
  const factory DashboardAbsence({
    String? id,
    @JsonKey(name: 'person_id') int? personId,
    @JsonKey(name: 'tenant_id') int? tenantId,
    @JsonKey(name: 'from_date') String? fromDate,
    @JsonKey(name: 'until_date') String? untilDate,
    String? reason,
  }) = _DashboardAbsence;

  factory DashboardAbsence.fromJson(Map<String, dynamic> json) =>
      _$DashboardAbsenceFromJson(json);
}

/// Planned song for the "Aktuelle Werke" card (one entry per song).
@freezed
class DashboardSongEntry with _$DashboardSongEntry {
  const factory DashboardSongEntry({
    required int songId,
    required String name,
    int? number,
    String? prefix,
    String? conductorName,
    required String dateLabel,
    String? date,
    String? typeLabel,
  }) = _DashboardSongEntry;
}

/// Aggregated KPIs of the super-developer usage dashboard (RPC `usage_kpis`).
@freezed
class UsageKpis with _$UsageKpis {
  const factory UsageKpis({
    @Default(0) int totalEvents,
    @Default(0) int distinctTenants,
    @Default(0) int activeTenants7d,
  }) = _UsageKpis;
}

/// One row of a `usage_events_*` aggregation RPC (label + count).
@freezed
class UsageCount with _$UsageCount {
  const factory UsageCount({
    required String label,
    required int count,
  }) = _UsageCount;
}

/// Complete data set for the usage dashboard page.
@freezed
class UsageDashboardData with _$UsageDashboardData {
  const factory UsageDashboardData({
    @Default(UsageKpis()) UsageKpis kpis,
    @Default([]) List<UsageCount> perDay,
    @Default([]) List<UsageCount> byName,
    @Default([]) List<UsageCount> byTenant,
    @Default([]) List<UsageCount> byDevice,
  }) = _UsageDashboardData;
}
