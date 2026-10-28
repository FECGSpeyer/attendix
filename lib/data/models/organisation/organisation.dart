import 'package:freezed_annotation/freezed_annotation.dart';

import '../plan/plan.dart';
import '../tenant/tenant.dart';

part 'organisation.freezed.dart';
part 'organisation.g.dart';

/// Organisation model - represents a tenant group
/// Tabelle: tenant_groups
@freezed
class Organisation with _$Organisation {
  @JsonSerializable(explicitToJson: true)
  const factory Organisation({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    required String name,
    // ORG_PLANS: Ablaufpläne / Org-Einstellungen (tenant_groups columns)
    @JsonKey(name: 'public_plan_key') String? publicPlanKey,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'branding_text') String? brandingText,
    @JsonKey(name: 'additional_fields') List<OrgExtraField>? additionalFields,
    @JsonKey(name: 'planning_templates') List<Plan>? planningTemplates,
    @JsonKey(name: 'default_fields') List<PlanField>? defaultFields,
  }) = _Organisation;

  factory Organisation.fromJson(Map<String, dynamic> json) =>
      _$OrganisationFromJson(json);
}

/// Extension for Organisation
extension OrganisationExtension on Organisation {
  String get displayName => name;
}

/// TenantGroupTenant model - links tenants to organisations
/// Tabelle: tenant_group_tenants
@freezed
class TenantGroupTenant with _$TenantGroupTenant {
  const factory TenantGroupTenant({
    int? id,
    @JsonKey(name: 'tenant_id') required int tenantId,
    @JsonKey(name: 'tenant_group') required int tenantGroup,
    @JsonKey(name: 'tenant_group_data') Organisation? tenantGroupData,
    Tenant? tenant,
  }) = _TenantGroupTenant;

  factory TenantGroupTenant.fromJson(Map<String, dynamic> json) =>
      _$TenantGroupTenantFromJson(json);
}
