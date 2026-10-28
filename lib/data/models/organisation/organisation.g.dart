// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organisation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrganisationImpl _$$OrganisationImplFromJson(Map<String, dynamic> json) =>
    _$OrganisationImpl(
      id: (json['id'] as num?)?.toInt(),
      createdAt:
          json['created_at'] == null
              ? null
              : DateTime.parse(json['created_at'] as String),
      name: json['name'] as String,
      publicPlanKey: json['public_plan_key'] as String?,
      logoUrl: json['logo_url'] as String?,
      brandingText: json['branding_text'] as String?,
      additionalFields:
          (json['additional_fields'] as List<dynamic>?)
              ?.map((e) => OrgExtraField.fromJson(e as Map<String, dynamic>))
              .toList(),
      planningTemplates:
          (json['planning_templates'] as List<dynamic>?)
              ?.map((e) => Plan.fromJson(e as Map<String, dynamic>))
              .toList(),
      defaultFields:
          (json['default_fields'] as List<dynamic>?)
              ?.map((e) => PlanField.fromJson(e as Map<String, dynamic>))
              .toList(),
    );

Map<String, dynamic> _$$OrganisationImplToJson(_$OrganisationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt?.toIso8601String(),
      'name': instance.name,
      'public_plan_key': instance.publicPlanKey,
      'logo_url': instance.logoUrl,
      'branding_text': instance.brandingText,
      'additional_fields':
          instance.additionalFields?.map((e) => e.toJson()).toList(),
      'planning_templates':
          instance.planningTemplates?.map((e) => e.toJson()).toList(),
      'default_fields': instance.defaultFields?.map((e) => e.toJson()).toList(),
    };

_$TenantGroupTenantImpl _$$TenantGroupTenantImplFromJson(
  Map<String, dynamic> json,
) => _$TenantGroupTenantImpl(
  id: (json['id'] as num?)?.toInt(),
  tenantId: (json['tenant_id'] as num).toInt(),
  tenantGroup: (json['tenant_group'] as num).toInt(),
  tenantGroupData:
      json['tenant_group_data'] == null
          ? null
          : Organisation.fromJson(
            json['tenant_group_data'] as Map<String, dynamic>,
          ),
  tenant:
      json['tenant'] == null
          ? null
          : Tenant.fromJson(json['tenant'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$TenantGroupTenantImplToJson(
  _$TenantGroupTenantImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'tenant_group': instance.tenantGroup,
  'tenant_group_data': instance.tenantGroupData,
  'tenant': instance.tenant,
};
