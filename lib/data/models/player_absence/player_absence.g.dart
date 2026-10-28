// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_absence.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlayerAbsenceImpl _$$PlayerAbsenceImplFromJson(Map<String, dynamic> json) =>
    _$PlayerAbsenceImpl(
      id: json['id'] as String?,
      createdAt:
          json['created_at'] == null
              ? null
              : DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      tenantId: (json['tenant_id'] as num?)?.toInt(),
      personId: (json['person_id'] as num).toInt(),
      fromDate: json['from_date'] as String,
      untilDate: json['until_date'] as String,
      reason: json['reason'] as String? ?? '',
    );

Map<String, dynamic> _$$PlayerAbsenceImplToJson(_$PlayerAbsenceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt?.toIso8601String(),
      'created_by': instance.createdBy,
      'tenant_id': instance.tenantId,
      'person_id': instance.personId,
      'from_date': instance.fromDate,
      'until_date': instance.untilDate,
      'reason': instance.reason,
    };

_$RoleAbsencePermissionsImpl _$$RoleAbsencePermissionsImplFromJson(
  Map<String, dynamic> json,
) => _$RoleAbsencePermissionsImpl(
  playerSelfPause: json['player_self_pause'] as bool? ?? false,
  playerPlannedAbsence: json['player_planned_absence'] as bool? ?? false,
);

Map<String, dynamic> _$$RoleAbsencePermissionsImplToJson(
  _$RoleAbsencePermissionsImpl instance,
) => <String, dynamic>{
  'player_self_pause': instance.playerSelfPause,
  'player_planned_absence': instance.playerPlannedAbsence,
};
