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
      logoUrl: json['logo_url'] as String?,
      brandingText: json['branding_text'] as String?,
    );

Map<String, dynamic> _$$OrganisationImplToJson(_$OrganisationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt?.toIso8601String(),
      'name': instance.name,
      'logo_url': instance.logoUrl,
      'branding_text': instance.brandingText,
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
