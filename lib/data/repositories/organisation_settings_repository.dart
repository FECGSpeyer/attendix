import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/organisation/organisation.dart';
import 'base_repository.dart';

/// Provider (ohne Tenant – nutze organisationSettingsRepositoryWithTenantProvider)
final organisationSettingsRepositoryProvider = Provider<OrganisationSettingsRepository>((ref) {
  return OrganisationSettingsRepository(ref);
});

/// Organisations-Einstellungen, die von einer Instanz aus gepflegt werden:
/// Branding (Logo/Text in `tenant_groups`) und "Personen verknüpfen"
/// (`player.global_person_id` über Instanzen der Organisation hinweg).
///
/// Multi-Tenant: `tenant_groups` hat keine tenantId. Die Organisation wird
/// daher IMMER über `tenant_group_tenants.tenant_id = currentTenantId`
/// aufgelöst – nie aus einer vom Aufrufer übergebenen ID.
class OrganisationSettingsRepository extends BaseRepository with TenantAwareRepository {
  OrganisationSettingsRepository(super.ref);

  static const String brandingBucket = 'branding';

  /// Organisation der aktuellen Instanz (oder null).
  Future<Organisation?> getCurrentOrganisation() async {
    try {
      final response = await supabase
          .from('tenant_group_tenants')
          .select('tenant_group, tenant_group_data:tenant_group(*)')
          .eq('tenant_id', currentTenantId)
          .limit(1)
          .maybeSingle();
      final data = response?['tenant_group_data'];
      if (data == null) return null;
      return Organisation.fromJson(data as Map<String, dynamic>);
    } catch (e, stack) {
      handleError(e, stack, 'getCurrentOrganisation');
      rethrow;
    }
  }

  Future<int> _requireOrganisationId(String operation) async {
    final org = await getCurrentOrganisation();
    final id = org?.id;
    if (id == null) {
      throw RepositoryException(
        message: 'Diese Instanz ist keiner Organisation zugeordnet.',
        operation: operation,
      );
    }
    return id;
  }

  /// Tenant-IDs aller Instanzen der Organisation der aktuellen Instanz.
  Future<List<int>> _organisationTenantIds(int organisationId) async {
    final response = await supabase
        .from('tenant_group_tenants')
        .select('tenant_id')
        .eq('tenant_group', organisationId);
    return (response as List).map((e) => e['tenant_id'] as int).toList();
  }

  /// Lädt ein Logo in den öffentlichen Bucket `branding` (Key `org-<orgId>`)
  /// und gibt die öffentliche URL (mit Cache-Buster) zurück.
  /// Die Tabelle wird NICHT geschrieben – dafür [updateBranding] aufrufen.
  Future<String> uploadLogo(Uint8List bytes, {String? contentType}) async {
    try {
      final orgId = await _requireOrganisationId('uploadLogo');
      final fileName = 'org-$orgId';
      await supabase.storage.from(brandingBucket).uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );
      final url = supabase.storage.from(brandingBucket).getPublicUrl(fileName);
      return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e, stack) {
      handleError(e, stack, 'uploadLogo');
      rethrow;
    }
  }

  /// Entfernt das Logo der Organisation aus dem Bucket.
  Future<void> removeLogo() async {
    try {
      final orgId = await _requireOrganisationId('removeLogo');
      await supabase.storage.from(brandingBucket).remove(['org-$orgId']);
    } catch (e, stack) {
      handleError(e, stack, 'removeLogo');
      rethrow;
    }
  }

  /// Speichert Logo-URL und Branding-Text der Organisation.
  Future<Organisation> updateBranding({String? logoUrl, String? brandingText}) async {
    try {
      final orgId = await _requireOrganisationId('updateBranding');
      final response = await supabase
          .from('tenant_groups')
          .update({
            'logo_url': (logoUrl?.isNotEmpty ?? false) ? logoUrl : null,
            'branding_text': (brandingText?.trim().isNotEmpty ?? false) ? brandingText!.trim() : null,
          })
          .eq('id', orgId)
          .select()
          .single();
      return Organisation.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateBranding');
      rethrow;
    }
  }

  /// Verknüpft Personen über Instanzen der Organisation (global_person_id).
  /// Es werden nur Personen aus Instanzen der eigenen Organisation geändert.
  Future<void> setGlobalPersonId(List<int> playerIds, String globalPersonId) async {
    if (playerIds.isEmpty) return;
    try {
      final orgId = await _requireOrganisationId('setGlobalPersonId');
      final tenantIds = await _organisationTenantIds(orgId);
      if (!tenantIds.contains(currentTenantId)) {
        throw const RepositoryException(
          message: 'Zugriff verweigert',
          operation: 'setGlobalPersonId',
        );
      }
      await supabase
          .from('player')
          .update({'global_person_id': globalPersonId})
          .inFilter('id', playerIds)
          .inFilter('tenantId', tenantIds);
    } catch (e, stack) {
      handleError(e, stack, 'setGlobalPersonId');
      rethrow;
    }
  }
}
