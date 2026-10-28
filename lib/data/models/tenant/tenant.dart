import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/constants/enums.dart';
import '../../../l10n/l10n.dart';

part 'tenant.freezed.dart';
part 'tenant.g.dart';

/// Tenant model - represents an organization/group in the system
@freezed
class Tenant with _$Tenant {
  const factory Tenant({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    required String shortName,
    required String longName,
    @Default(false) bool maintainTeachers,
    @Default(false) bool showHolidays,
    @Default('') String type,
    @Default(true) bool withExcuses,
    String? practiceStart,
    String? practiceEnd,
    String? seasonStart,
    @Default(false) bool? parents,
    @Default(false) bool betaProgram,
    @Default(false) bool showMembersList, // DB_FIX: column "showMembersList"
    String? region,
    int? role,
    @JsonKey(name: 'song_sharing_id') String? songSharingId,
    @JsonKey(name: 'additional_fields') List<ExtraField>? additionalFields,
    String? perc,
    String? percColor,
    @JsonKey(name: 'register_id') String? registerId,
    @JsonKey(name: 'auto_approve_registrations') @Default(false) bool autoApproveRegistrations,
    @JsonKey(name: 'registration_fields') List<String>? registrationFields,
    @Default(false) bool? favorite,
    @JsonKey(name: 'critical_rules') List<CriticalRule>? criticalRules,
    @Default('Europe/Berlin') String timezone,
    // SETTINGS_EXT: Zusatzfelder für Werke + Dateiablage (files bucket)
    @JsonKey(name: 'song_additional_fields') List<ExtraField>? songAdditionalFields,
    @JsonKey(name: 'files_enabled') @Default(false) bool filesEnabled,
    @JsonKey(name: 'files_shared') @Default(false) bool filesShared,
    /// Speicherlimit der Dateiablage in Bytes, null = unbegrenzt.
    @JsonKey(name: 'files_max_bytes') int? filesMaxBytes,
    // ATTENDANCE_SIGNOUT: show all Termine on the signout page, excuse reasons
    @JsonKey(name: 'show_all_attendances') @Default(false) bool showAllAttendances,
    @JsonKey(name: 'show_all_attendances_info_text') String? showAllAttendancesInfoText,
    @JsonKey(name: 'absence_reasons') List<String>? absenceReasons,
    @JsonKey(name: 'late_reasons') List<String>? lateReasons,
    // DUTY: "Meine Termine" als Dienstplan-Ansicht
    @JsonKey(name: 'duty_view') @Default(false) bool dutyView,
    // SETTINGS2: schicht-/arbeitsbedingt entschuldigt zählt als anwesend
    @JsonKey(name: 'shift_excused_as_present') @Default(false) bool shiftExcusedAsPresent,
  }) = _Tenant;

  factory Tenant.fromJson(Map<String, dynamic> json) => _$TenantFromJson(json);
}

/// Helper extension for Tenant
extension TenantExtension on Tenant {
  /// Get display name (shortName or longName)
  String get name => shortName.isNotEmpty ? shortName : longName;
  
  /// Get description
  String? get description => longName.isNotEmpty && longName != shortName ? longName : null;
  
  /// Get image URL (placeholder for now)
  String? get imageUrl => null;
}

/// Extra field configuration for dynamic forms
@freezed
class ExtraField with _$ExtraField {
  const factory ExtraField({
    required String id,
    required String name,
    required String type,
    dynamic defaultValue,
    List<String>? options,
    // SETTINGS_EXT: Sichtbarkeit/Bearbeitbarkeit für Mitglieder + Anzeige
    bool? visibleToPlayers,
    bool? editableByPlayers,
    /// 'chip' | 'underneath'
    String? displayMode,
  }) = _ExtraField;

  factory ExtraField.fromJson(Map<String, dynamic> json) =>
      _$ExtraFieldFromJson(json);
}

/// Critical rule operator
enum CriticalRuleOperator {
  @JsonValue('AND')
  and,
  @JsonValue('OR')
  or,
}

/// Critical rule threshold type
enum CriticalRuleThresholdType {
  @JsonValue('count')
  count,
  @JsonValue('percentage')
  percentage,
}

/// Critical rule period type
enum CriticalRulePeriodType {
  @JsonValue('days')
  days,
  @JsonValue('season')
  season,
  @JsonValue('all')
  allTime,
}

/// Critical rule for attendance monitoring
@freezed
class CriticalRule with _$CriticalRule {
  const factory CriticalRule({
    required String id,
    String? name,
    @JsonKey(name: 'attendance_type_ids') required List<String> attendanceTypeIds,
    required List<int> statuses,
    @JsonKey(name: 'threshold_type') required CriticalRuleThresholdType thresholdType,
    @JsonKey(name: 'threshold_value') required int thresholdValue,
    @JsonKey(name: 'period_type') CriticalRulePeriodType? periodType,
    @JsonKey(name: 'period_days') int? periodDays,
    required CriticalRuleOperator operator,
    @Default(true) bool enabled,
  }) = _CriticalRule;

  factory CriticalRule.fromJson(Map<String, dynamic> json) =>
      _$CriticalRuleFromJson(json);
}

/// Extension for CriticalRule
extension CriticalRuleExtension on CriticalRule {
  /// Build a human-readable description of the rule
  String get description {
    final threshold = thresholdType == CriticalRuleThresholdType.count
        ? '${thresholdValue}x'
        : '$thresholdValue%';

    final l10n = l10nWithoutContext;
    final statusLabels = statuses.map((s) {
      return switch (s) {
        4 => l10n.commonStatusAbsent,
        3 => l10n.commonStatusLateShort,
        5 => l10n.attendanceLateExcusedParen,
        _ => l10n.coreFlutterRuleStatusN(s),
      };
    }).join(' / ');

    final period = switch (periodType) {
      CriticalRulePeriodType.days => l10n.homeDashboardInDays(periodDays ?? 30),
      CriticalRulePeriodType.season => l10n.coreFlutterRuleSinceSeasonStart,
      _ => l10n.coreFlutterRuleOverall,
    };

    return '$threshold $statusLabels $period';
  }

  /// Display name (name or auto-generated description)
  String get displayName => name ?? description;
}

/// Tenant user association
@freezed
class TenantUser with _$TenantUser {
  const factory TenantUser({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    required int tenantId,
    required String userId,
    required int role,
    String? email,
    @JsonKey(name: 'telegram_chat_id') String? telegramChatId,
    @Default(false) bool favorite,
    @JsonKey(name: 'parent_id') int? parentId,
  }) = _TenantUser;

  factory TenantUser.fromJson(Map<String, dynamic> json) =>
      _$TenantUserFromJson(json);
}

/// Extension for TenantUser
extension TenantUserExtension on TenantUser {
  Role get roleEnum => Role.fromValue(role);
  bool get isAdmin => roleEnum.isAdmin;
  bool get canEdit => roleEnum.canEdit;
}