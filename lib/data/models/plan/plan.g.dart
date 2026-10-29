// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlanFieldImpl _$$PlanFieldImplFromJson(Map<String, dynamic> json) =>
    _$PlanFieldImpl(
      id: const PlanStringConverter().fromJson(json['id']),
      name: const PlanStringConverter().fromJson(json['name']),
      time:
          json['time'] == null
              ? '0'
              : const PlanStringConverter().fromJson(json['time']),
      conductor: json['conductor'] as String?,
      currentTime: json['currentTime'] as String?,
      songId: const PlanIntConverter().fromJson(json['songId']),
      info: json['info'] as String?,
      agendaItemId: json['agendaItemId'] as String?,
      isGroup:
          json['isGroup'] == null
              ? false
              : const PlanBoolConverter().fromJson(json['isGroup']),
      groupId: json['groupId'] as String?,
      isNote:
          json['isNote'] == null
              ? false
              : const PlanBoolConverter().fromJson(json['isNote']),
    );

Map<String, dynamic> _$$PlanFieldImplToJson(_$PlanFieldImpl instance) =>
    <String, dynamic>{
      if (const PlanStringConverter().toJson(instance.id) case final value?)
        'id': value,
      if (const PlanStringConverter().toJson(instance.name) case final value?)
        'name': value,
      if (const PlanStringConverter().toJson(instance.time) case final value?)
        'time': value,
      if (instance.conductor case final value?) 'conductor': value,
      if (instance.currentTime case final value?) 'currentTime': value,
      if (const PlanIntConverter().toJson(instance.songId) case final value?)
        'songId': value,
      if (instance.info case final value?) 'info': value,
      if (instance.agendaItemId case final value?) 'agendaItemId': value,
      if (const PlanBoolConverter().toJson(instance.isGroup) case final value?)
        'isGroup': value,
      if (instance.groupId case final value?) 'groupId': value,
    };

_$PlanImpl _$$PlanImplFromJson(Map<String, dynamic> json) => _$PlanImpl(
  time:
      json['time'] == null
          ? ''
          : const PlanStringConverter().fromJson(json['time']),
  end:
      json['end'] == null
          ? ''
          : const PlanStringConverter().fromJson(json['end']),
  fields:
      (json['fields'] as List<dynamic>?)
          ?.map((e) => PlanField.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PlanField>[],
  title: json['title'] as String?,
  id: json['id'] as String?,
  label: json['label'] as String?,
  day: const PlanIntConverter().fromJson(json['day']),
);

Map<String, dynamic> _$$PlanImplToJson(_$PlanImpl instance) =>
    <String, dynamic>{
      if (const PlanStringConverter().toJson(instance.time) case final value?)
        'time': value,
      if (const PlanStringConverter().toJson(instance.end) case final value?)
        'end': value,
      'fields': instance.fields.map((e) => e.toJson()).toList(),
      if (instance.title case final value?) 'title': value,
      if (instance.id case final value?) 'id': value,
      if (instance.label case final value?) 'label': value,
      if (const PlanIntConverter().toJson(instance.day) case final value?)
        'day': value,
    };

_$PlanBlockTemplateImpl _$$PlanBlockTemplateImplFromJson(
  Map<String, dynamic> json,
) => _$PlanBlockTemplateImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  fields:
      (json['fields'] as List<dynamic>?)
          ?.map((e) => PlanField.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PlanField>[],
);

Map<String, dynamic> _$$PlanBlockTemplateImplToJson(
  _$PlanBlockTemplateImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'fields': instance.fields.map((e) => e.toJson()).toList(),
};

_$SharedPlanImpl _$$SharedPlanImplFromJson(Map<String, dynamic> json) =>
    _$SharedPlanImpl(
      id: json['id'] as String,
      editKey: json['edit_key'] as String,
      planTitle: json['plan_title'] as String?,
      date: json['date'] as String?,
      time: json['time'] as String?,
      endTime: json['end_time'] as String?,
      fields:
          (json['fields'] as List<dynamic>?)
              ?.map((e) => PlanField.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PlanField>[],
      brandingId: json['branding_id'] as String?,
      creatorUserId: json['creator_user_id'] as String?,
      createdAt: json['created_at'] as String?,
      orgId: const PlanIntConverter().fromJson(json['org_id']),
    );

Map<String, dynamic> _$$SharedPlanImplToJson(_$SharedPlanImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'edit_key': instance.editKey,
      if (instance.planTitle case final value?) 'plan_title': value,
      if (instance.date case final value?) 'date': value,
      if (instance.time case final value?) 'time': value,
      if (instance.endTime case final value?) 'end_time': value,
      'fields': instance.fields.map((e) => e.toJson()).toList(),
      if (instance.brandingId case final value?) 'branding_id': value,
      if (instance.creatorUserId case final value?) 'creator_user_id': value,
      if (instance.createdAt case final value?) 'created_at': value,
      if (const PlanIntConverter().toJson(instance.orgId) case final value?)
        'org_id': value,
    };

_$PlanAttendanceImpl _$$PlanAttendanceImplFromJson(Map<String, dynamic> json) =>
    _$PlanAttendanceImpl(
      id: const PlanIntConverter().fromJson(json['id']),
      tenantId: const PlanIntConverter().fromJson(json['tenantId']),
      date: json['date'] as String? ?? '',
      durationDays: const PlanIntConverter().fromJson(json['duration_days']),
      plan:
          json['plan'] == null
              ? null
              : Plan.fromJson(json['plan'] as Map<String, dynamic>),
      extraPlans:
          (json['extra_plans'] as List<dynamic>?)
              ?.map((e) => Plan.fromJson(e as Map<String, dynamic>))
              .toList(),
      typeId: json['type_id'] as String?,
      typeInfo: json['typeInfo'] as String?,
      type: json['type'] as String?,
      startTime: json['start_time'] as String?,
      notes: json['notes'] as String?,
      sharePlan:
          json['share_plan'] == null
              ? false
              : const PlanBoolConverter().fromJson(json['share_plan']),
      isOrgPlan:
          json['is_org_plan'] == null
              ? false
              : const PlanBoolConverter().fromJson(json['is_org_plan']),
      shareKey: json['share_key'] as String?,
      shareEditKey: json['share_edit_key'] as String?,
    );

Map<String, dynamic> _$$PlanAttendanceImplToJson(
  _$PlanAttendanceImpl instance,
) => <String, dynamic>{
  if (const PlanIntConverter().toJson(instance.id) case final value?)
    'id': value,
  if (const PlanIntConverter().toJson(instance.tenantId) case final value?)
    'tenantId': value,
  'date': instance.date,
  if (const PlanIntConverter().toJson(instance.durationDays) case final value?)
    'duration_days': value,
  if (instance.plan?.toJson() case final value?) 'plan': value,
  if (instance.extraPlans?.map((e) => e.toJson()).toList() case final value?)
    'extra_plans': value,
  if (instance.typeId case final value?) 'type_id': value,
  if (instance.typeInfo case final value?) 'typeInfo': value,
  if (instance.type case final value?) 'type': value,
  if (instance.startTime case final value?) 'start_time': value,
  if (instance.notes case final value?) 'notes': value,
  if (const PlanBoolConverter().toJson(instance.sharePlan) case final value?)
    'share_plan': value,
  if (const PlanBoolConverter().toJson(instance.isOrgPlan) case final value?)
    'is_org_plan': value,
  if (instance.shareKey case final value?) 'share_key': value,
  if (instance.shareEditKey case final value?) 'share_edit_key': value,
};

_$PlanAttendanceTypeImpl _$$PlanAttendanceTypeImplFromJson(
  Map<String, dynamic> json,
) => _$PlanAttendanceTypeImpl(
  id: json['id'] as String,
  name: json['name'] as String? ?? '',
  defaultPlan:
      json['default_plan'] == null
          ? null
          : Plan.fromJson(json['default_plan'] as Map<String, dynamic>),
  startTime: json['start_time'] as String?,
  planningTitle: json['planning_title'] as String?,
  planningPrefixInstanceName:
      json['planning_prefix_instance_name'] == null
          ? false
          : const PlanBoolConverter().fromJson(
            json['planning_prefix_instance_name'],
          ),
  isDefaultOrgPlan:
      json['is_default_org_plan'] == null
          ? false
          : const PlanBoolConverter().fromJson(json['is_default_org_plan']),
);

Map<String, dynamic> _$$PlanAttendanceTypeImplToJson(
  _$PlanAttendanceTypeImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  if (instance.defaultPlan?.toJson() case final value?) 'default_plan': value,
  if (instance.startTime case final value?) 'start_time': value,
  if (instance.planningTitle case final value?) 'planning_title': value,
  if (const PlanBoolConverter().toJson(instance.planningPrefixInstanceName)
      case final value?)
    'planning_prefix_instance_name': value,
  if (const PlanBoolConverter().toJson(instance.isDefaultOrgPlan)
      case final value?)
    'is_default_org_plan': value,
};

_$OrgExtraFieldImpl _$$OrgExtraFieldImplFromJson(Map<String, dynamic> json) =>
    _$OrgExtraFieldImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'text',
      defaultValue: json['defaultValue'],
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      visibleToPlayers: json['visibleToPlayers'] as bool? ?? false,
      editableByPlayers: json['editableByPlayers'] as bool? ?? false,
      displayMode: json['displayMode'] as String? ?? 'chip',
    );

Map<String, dynamic> _$$OrgExtraFieldImplToJson(_$OrgExtraFieldImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      if (instance.defaultValue case final value?) 'defaultValue': value,
      'options': instance.options,
      'visibleToPlayers': instance.visibleToPlayers,
      'editableByPlayers': instance.editableByPlayers,
      'displayMode': instance.displayMode,
    };
