import 'package:freezed_annotation/freezed_annotation.dart';

import '../tenant/tenant.dart';

part 'organisation.freezed.dart';
part 'organisation.g.dart';

/// Organisation model - represents a tenant group
/// Tabelle: tenant_groups
@freezed
class Organisation with _$Organisation {
  const factory Organisation({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    required String name,
    // SETTINGS_EXT: Branding (Logo + Text) auf Organisationsebene
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'branding_text') String? brandingText,
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
