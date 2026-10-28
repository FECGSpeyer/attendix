import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_absence.freezed.dart';
part 'player_absence.g.dart';

/// Planned absence of a person (Ionic: PlayerAbsence, table `player_absences`).
///
/// Columns (see supabase/sql/add_player_absences.sql):
/// id uuid, created_at, created_by, tenant_id, person_id, from_date (date),
/// until_date (date), reason.
@freezed
class PlayerAbsence with _$PlayerAbsence {
  const factory PlayerAbsence({
    String? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'tenant_id') int? tenantId,
    @JsonKey(name: 'person_id') required int personId,
    @JsonKey(name: 'from_date') required String fromDate,
    @JsonKey(name: 'until_date') required String untilDate,
    @Default('') String reason,
  }) = _PlayerAbsence;

  factory PlayerAbsence.fromJson(Map<String, dynamic> json) =>
      _$PlayerAbsenceFromJson(json);
}

/// Subset of `tenant_role_permissions` relevant for absences / self pause.
@freezed
class RoleAbsencePermissions with _$RoleAbsencePermissions {
  const factory RoleAbsencePermissions({
    @JsonKey(name: 'player_self_pause') @Default(false) bool playerSelfPause,
    @JsonKey(name: 'player_planned_absence')
    @Default(false)
    bool playerPlannedAbsence,
  }) = _RoleAbsencePermissions;

  factory RoleAbsencePermissions.fromJson(Map<String, dynamic> json) =>
      _$RoleAbsencePermissionsFromJson(json);
}
