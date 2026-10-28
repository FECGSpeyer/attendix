// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tenant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TenantImpl _$$TenantImplFromJson(Map<String, dynamic> json) => _$TenantImpl(
  id: (json['id'] as num?)?.toInt(),
  createdAt:
      json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
  shortName: json['shortName'] as String,
  longName: json['longName'] as String,
  maintainTeachers: json['maintainTeachers'] as bool? ?? false,
  showHolidays: json['showHolidays'] as bool? ?? false,
  type: json['type'] as String? ?? '',
  withExcuses: json['withExcuses'] as bool? ?? true,
  practiceStart: json['practiceStart'] as String?,
  practiceEnd: json['practiceEnd'] as String?,
  seasonStart: json['seasonStart'] as String?,
  parents: json['parents'] as bool? ?? false,
  betaProgram: json['betaProgram'] as bool? ?? false,
  showMembersList: json['show_members_list'] as bool? ?? false,
  region: json['region'] as String?,
  role: (json['role'] as num?)?.toInt(),
  songSharingId: json['song_sharing_id'] as String?,
  additionalFields:
      (json['additional_fields'] as List<dynamic>?)
          ?.map((e) => ExtraField.fromJson(e as Map<String, dynamic>))
          .toList(),
  perc: json['perc'] as String?,
  percColor: json['percColor'] as String?,
  registerId: json['register_id'] as String?,
  autoApproveRegistrations:
      json['auto_approve_registrations'] as bool? ?? false,
  registrationFields:
      (json['registration_fields'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
  favorite: json['favorite'] as bool? ?? false,
  criticalRules:
      (json['critical_rules'] as List<dynamic>?)
          ?.map((e) => CriticalRule.fromJson(e as Map<String, dynamic>))
          .toList(),
  timezone: json['timezone'] as String? ?? 'Europe/Berlin',
  dutyView: json['duty_view'] as bool? ?? false,
);

Map<String, dynamic> _$$TenantImplToJson(_$TenantImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt?.toIso8601String(),
      'shortName': instance.shortName,
      'longName': instance.longName,
      'maintainTeachers': instance.maintainTeachers,
      'showHolidays': instance.showHolidays,
      'type': instance.type,
      'withExcuses': instance.withExcuses,
      'practiceStart': instance.practiceStart,
      'practiceEnd': instance.practiceEnd,
      'seasonStart': instance.seasonStart,
      'parents': instance.parents,
      'betaProgram': instance.betaProgram,
      'show_members_list': instance.showMembersList,
      'region': instance.region,
      'role': instance.role,
      'song_sharing_id': instance.songSharingId,
      'additional_fields': instance.additionalFields,
      'perc': instance.perc,
      'percColor': instance.percColor,
      'register_id': instance.registerId,
      'auto_approve_registrations': instance.autoApproveRegistrations,
      'registration_fields': instance.registrationFields,
      'favorite': instance.favorite,
      'critical_rules': instance.criticalRules,
      'timezone': instance.timezone,
      'duty_view': instance.dutyView,
    };

_$ExtraFieldImpl _$$ExtraFieldImplFromJson(Map<String, dynamic> json) =>
    _$ExtraFieldImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      defaultValue: json['defaultValue'],
      options:
          (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$$ExtraFieldImplToJson(_$ExtraFieldImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'defaultValue': instance.defaultValue,
      'options': instance.options,
    };

_$CriticalRuleImpl _$$CriticalRuleImplFromJson(Map<String, dynamic> json) =>
    _$CriticalRuleImpl(
      id: json['id'] as String,
      name: json['name'] as String?,
      attendanceTypeIds:
          (json['attendance_type_ids'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      statuses:
          (json['statuses'] as List<dynamic>)
              .map((e) => (e as num).toInt())
              .toList(),
      thresholdType: $enumDecode(
        _$CriticalRuleThresholdTypeEnumMap,
        json['threshold_type'],
      ),
      thresholdValue: (json['threshold_value'] as num).toInt(),
      periodType: $enumDecodeNullable(
        _$CriticalRulePeriodTypeEnumMap,
        json['period_type'],
      ),
      periodDays: (json['period_days'] as num?)?.toInt(),
      operator: $enumDecode(_$CriticalRuleOperatorEnumMap, json['operator']),
      enabled: json['enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$$CriticalRuleImplToJson(
  _$CriticalRuleImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'attendance_type_ids': instance.attendanceTypeIds,
  'statuses': instance.statuses,
  'threshold_type': _$CriticalRuleThresholdTypeEnumMap[instance.thresholdType]!,
  'threshold_value': instance.thresholdValue,
  'period_type': _$CriticalRulePeriodTypeEnumMap[instance.periodType],
  'period_days': instance.periodDays,
  'operator': _$CriticalRuleOperatorEnumMap[instance.operator]!,
  'enabled': instance.enabled,
};

const _$CriticalRuleThresholdTypeEnumMap = {
  CriticalRuleThresholdType.count: 'count',
  CriticalRuleThresholdType.percentage: 'percentage',
};

const _$CriticalRulePeriodTypeEnumMap = {
  CriticalRulePeriodType.days: 'days',
  CriticalRulePeriodType.season: 'season',
  CriticalRulePeriodType.allTime: 'all',
};

const _$CriticalRuleOperatorEnumMap = {
  CriticalRuleOperator.and: 'AND',
  CriticalRuleOperator.or: 'OR',
};

_$TenantUserImpl _$$TenantUserImplFromJson(Map<String, dynamic> json) =>
    _$TenantUserImpl(
      id: (json['id'] as num?)?.toInt(),
      createdAt:
          json['created_at'] == null
              ? null
              : DateTime.parse(json['created_at'] as String),
      tenantId: (json['tenantId'] as num).toInt(),
      userId: json['userId'] as String,
      role: (json['role'] as num).toInt(),
      email: json['email'] as String?,
      telegramChatId: json['telegram_chat_id'] as String?,
      favorite: json['favorite'] as bool? ?? false,
      parentId: (json['parent_id'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$TenantUserImplToJson(_$TenantUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt?.toIso8601String(),
      'tenantId': instance.tenantId,
      'userId': instance.userId,
      'role': instance.role,
      'email': instance.email,
      'telegram_chat_id': instance.telegramChatId,
      'favorite': instance.favorite,
      'parent_id': instance.parentId,
    };
