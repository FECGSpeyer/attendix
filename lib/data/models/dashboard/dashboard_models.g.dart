// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DashboardCardConfigImpl _$$DashboardCardConfigImplFromJson(
  Map<String, dynamic> json,
) => _$DashboardCardConfigImpl(
  id: json['id'] as String,
  visible: json['visible'] as bool? ?? true,
);

Map<String, dynamic> _$$DashboardCardConfigImplToJson(
  _$DashboardCardConfigImpl instance,
) => <String, dynamic>{'id': instance.id, 'visible': instance.visible};

_$DashboardAbsenceImpl _$$DashboardAbsenceImplFromJson(
  Map<String, dynamic> json,
) => _$DashboardAbsenceImpl(
  id: json['id'] as String?,
  personId: (json['person_id'] as num?)?.toInt(),
  tenantId: (json['tenant_id'] as num?)?.toInt(),
  fromDate: json['from_date'] as String?,
  untilDate: json['until_date'] as String?,
  reason: json['reason'] as String?,
);

Map<String, dynamic> _$$DashboardAbsenceImplToJson(
  _$DashboardAbsenceImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'person_id': instance.personId,
  'tenant_id': instance.tenantId,
  'from_date': instance.fromDate,
  'until_date': instance.untilDate,
  'reason': instance.reason,
};
