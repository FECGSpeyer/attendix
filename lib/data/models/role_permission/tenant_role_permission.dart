import 'package:freezed_annotation/freezed_annotation.dart';

part 'tenant_role_permission.freezed.dart';
part 'tenant_role_permission.g.dart';

/// Konfigurierbare Berechtigungen je Rolle einer Instanz.
/// Tabelle: tenant_role_permissions (Spalte `tenant_id`, nicht `tenantId`!)
@freezed
class TenantRolePermission with _$TenantRolePermission {
  const factory TenantRolePermission({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'tenant_id') required int tenantId,
    required int role,
    @JsonKey(name: 'attendance_all_groups') @Default(true) bool attendanceAllGroups,
    @JsonKey(name: 'attendance_create') @Default(true) bool attendanceCreate,
    @JsonKey(name: 'player_notes_view') @Default(false) bool playerNotesView,
    @JsonKey(name: 'checklist_view') @Default(false) bool checklistView,
    @JsonKey(name: 'player_self_pause') @Default(false) bool playerSelfPause,
    @JsonKey(name: 'player_planned_absence') @Default(false) bool playerPlannedAbsence,
  }) = _TenantRolePermission;

  factory TenantRolePermission.fromJson(Map<String, dynamic> json) =>
      _$TenantRolePermissionFromJson(json);
}

/// Hilfsfunktionen für Rollenberechtigungen
extension TenantRolePermissionX on TenantRolePermission {
  /// Nur die editierbaren Flags (für UPDATE-Payloads)
  Map<String, dynamic> toUpdatePayload() => {
        'attendance_all_groups': attendanceAllGroups,
        'attendance_create': attendanceCreate,
        'player_notes_view': playerNotesView,
        'checklist_view': checklistView,
        'player_self_pause': playerSelfPause,
        'player_planned_absence': playerPlannedAbsence,
      };
}
