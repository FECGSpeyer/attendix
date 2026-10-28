// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tenant_role_permission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TenantRolePermissionImpl _$$TenantRolePermissionImplFromJson(
  Map<String, dynamic> json,
) => _$TenantRolePermissionImpl(
  id: (json['id'] as num?)?.toInt(),
  createdAt:
      json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
  tenantId: (json['tenant_id'] as num).toInt(),
  role: (json['role'] as num).toInt(),
  attendanceAllGroups: json['attendance_all_groups'] as bool? ?? true,
  attendanceCreate: json['attendance_create'] as bool? ?? true,
  playerNotesView: json['player_notes_view'] as bool? ?? false,
  checklistView: json['checklist_view'] as bool? ?? false,
  playerSelfPause: json['player_self_pause'] as bool? ?? false,
  playerPlannedAbsence: json['player_planned_absence'] as bool? ?? false,
);

Map<String, dynamic> _$$TenantRolePermissionImplToJson(
  _$TenantRolePermissionImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'created_at': instance.createdAt?.toIso8601String(),
  'tenant_id': instance.tenantId,
  'role': instance.role,
  'attendance_all_groups': instance.attendanceAllGroups,
  'attendance_create': instance.attendanceCreate,
  'player_notes_view': instance.playerNotesView,
  'checklist_view': instance.checklistView,
  'player_self_pause': instance.playerSelfPause,
  'player_planned_absence': instance.playerPlannedAbsence,
};
