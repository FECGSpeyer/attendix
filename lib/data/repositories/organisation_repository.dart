import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/organisation/organisation.dart';
import '../models/person/person.dart';
import '../models/tenant/tenant.dart';
import 'base_repository.dart';

/// Provider for OrganisationRepository
final organisationRepositoryProvider = Provider<OrganisationRepository>((ref) {
  return OrganisationRepository(ref);
});

/// Repository for organisation (tenant_groups) operations
/// NOTE: This repository does NOT use TenantAwareRepository as tenant_groups are global
class OrganisationRepository extends BaseRepository {
  OrganisationRepository(super.ref);

  /// Create a new organisation
  Future<Organisation> create(String name) async {
    ensureNotDemo('create'); // DEMO_GUARD
    try {
      final response = await supabase
          .from('tenant_groups')
          .insert({'name': name})
          .select()
          .single();

      return Organisation.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'create');
      rethrow;
    }
  }

  /// Link a tenant to an organisation
  /// SEC-004: Added authorization check - user must be admin of the tenant
  Future<void> linkTenantToOrganisation(int tenantId, int organisationId) async {
    ensureNotDemo('linkTenantToOrganisation'); // DEMO_GUARD
    try {
      // Validate user has admin permission for this tenant
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw RepositoryException(
          message: 'User not authenticated',
          operation: 'linkTenantToOrganisation',
        );
      }

      // Check if user is admin (role=1) or responsible (role=5) for this tenant
      final userAccess = await supabase
          .from('tenantUsers')
          .select('role')
          .eq('userId', userId)
          .eq('tenantId', tenantId)
          .or('role.eq.1,role.eq.5')
          .maybeSingle();

      if (userAccess == null) {
        throw RepositoryException(
          message: 'Access denied: User is not admin of this tenant',
          operation: 'linkTenantToOrganisation',
        );
      }

      // Check for duplicate link
      final existing = await supabase
          .from('tenant_group_tenants')
          .select('id')
          .eq('tenant_id', tenantId)
          .eq('tenant_group', organisationId)
          .maybeSingle();

      if (existing != null) {
        // Already linked - silently return
        return;
      }

      await supabase.from('tenant_group_tenants').insert({
        'tenant_id': tenantId,
        'tenant_group': organisationId,
      });
    } catch (e, stack) {
      handleError(e, stack, 'linkTenantToOrganisation');
      rethrow;
    }
  }

  /// Unlink a tenant from an organisation
  /// If no tenants remain in the organisation, the organisation is deleted
  /// SEC-004: Added authorization check - user must be admin of the tenant
  Future<void> unlinkTenantFromOrganisation(int tenantId, int organisationId) async {
    ensureNotDemo('unlinkTenantFromOrganisation'); // DEMO_GUARD
    try {
      // Validate user has admin permission for this tenant
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw RepositoryException(
          message: 'User not authenticated',
          operation: 'unlinkTenantFromOrganisation',
        );
      }

      // Check if user is admin (role=1) or responsible (role=5) for this tenant
      final userAccess = await supabase
          .from('tenantUsers')
          .select('role')
          .eq('userId', userId)
          .eq('tenantId', tenantId)
          .or('role.eq.1,role.eq.5')
          .maybeSingle();

      if (userAccess == null) {
        throw RepositoryException(
          message: 'Access denied: User is not admin of this tenant',
          operation: 'unlinkTenantFromOrganisation',
        );
      }

      // Remove the link
      await supabase
          .from('tenant_group_tenants')
          .delete()
          .eq('tenant_id', tenantId)
          .eq('tenant_group', organisationId);

      // Check if there are still tenants in the organisation
      final remaining = await supabase
          .from('tenant_group_tenants')
          .select('id')
          .eq('tenant_group', organisationId);

      // If no tenants remain, delete the organisation
      if ((remaining as List).isEmpty) {
        await supabase.from('tenant_groups').delete().eq('id', organisationId);
      }
    } catch (e, stack) {
      handleError(e, stack, 'unlinkTenantFromOrganisation');
      rethrow;
    }
  }

  /// Get the organisation for a specific tenant
  Future<Organisation?> getOrganisationFromTenant(int tenantId) async {
    try {
      final response = await supabase
          .from('tenant_group_tenants')
          .select('tenant_group, tenant_group_data:tenant_group(*)')
          .eq('tenant_id', tenantId)
          .limit(1) // DB_REVIEW_REST: no PGRST116 on duplicate links
          .maybeSingle();

      if (response == null || response['tenant_group_data'] == null) {
        return null;
      }

      return Organisation.fromJson(
          response['tenant_group_data'] as Map<String, dynamic>);
    } catch (e, stack) {
      handleError(e, stack, 'getOrganisationFromTenant');
      rethrow;
    }
  }

  /// Get all tenants of an organisation
  /// SEC-005: Added authorization check - user must be member of at least one tenant in the organisation
  Future<List<Tenant>> getInstancesOfOrganisation(int organisationId) async {
    try {
      // First verify user has access to at least one tenant in this organisation
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw RepositoryException(
          message: 'User not authenticated',
          operation: 'getInstancesOfOrganisation',
        );
      }

      // Get all tenants in this organisation
      final orgTenantsResponse = await supabase
          .from('tenant_group_tenants')
          .select('tenant_id')
          .eq('tenant_group', organisationId);

      final orgTenantIds = (orgTenantsResponse as List)
          .map((e) => e['tenant_id'] as int)
          .toList();

      if (orgTenantIds.isEmpty) return [];

      // Check if user is member of any tenant in this organisation
      final userAccessResponse = await supabase
          .from('tenantUsers')
          .select('tenantId')
          .eq('userId', userId)
          .inFilter('tenantId', orgTenantIds)
          .limit(1)
          .maybeSingle();

      if (userAccessResponse == null) {
        throw RepositoryException(
          message: 'Access denied: User is not member of this organisation',
          operation: 'getInstancesOfOrganisation',
        );
      }

      // User has access, now load all tenants
      final response = await supabase
          .from('tenant_group_tenants')
          .select('tenant:tenant_id(*)')
          .eq('tenant_group', organisationId);

      return (response as List)
          .where((e) => e['tenant'] != null)
          .map((e) => Tenant.fromJson(e['tenant'] as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getInstancesOfOrganisation');
      rethrow;
    }
  }

  /// Get all persons from all tenants of an organisation
  /// SEC-006: Added authorization check - user must be member of at least one of the requested tenants
  Future<List<Person>> getAllPersonsFromOrganisation(List<Tenant> tenants) async {
    try {
      final tenantIds = tenants.map((t) => t.id).whereType<int>().toList();
      if (tenantIds.isEmpty) return [];

      // Verify user has access to at least one of the requested tenants
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw RepositoryException(
          message: 'User not authenticated',
          operation: 'getAllPersonsFromOrganisation',
        );
      }

      final userAccessResponse = await supabase
          .from('tenantUsers')
          .select('tenantId')
          .eq('userId', userId)
          .inFilter('tenantId', tenantIds)
          .limit(1)
          .maybeSingle();

      if (userAccessResponse == null) {
        throw RepositoryException(
          message: 'Access denied: User is not member of any requested tenant',
          operation: 'getAllPersonsFromOrganisation',
        );
      }

      final response = await supabase
          .from('player')
          .select('*')
          .inFilter('tenantId', tenantIds)
          .eq('pending', false)
          .isFilter('left', null)
          .order('lastName')
          .order('firstName');

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAllPersonsFromOrganisation');
      rethrow;
    }
  }

  /// Get all organisations that a user has access to
  Future<List<Organisation>> getOrganisationsFromUser(String userId) async {
    try {
      // First get all tenants the user has access to (as admin or responsible)
      final tenantsResponse = await supabase
          .from('tenantUsers')
          .select('tenantId')
          .eq('userId', userId)
          .or('role.eq.1,role.eq.5'); // Admin or Responsible

      final tenantIds = (tenantsResponse as List)
          .map((e) => e['tenantId'] as int)
          .toList();

      if (tenantIds.isEmpty) return [];

      // Get all organisations for these tenants
      final response = await supabase
          .from('tenant_group_tenants')
          .select('tenant_group_data:tenant_group(*)')
          .inFilter('tenant_id', tenantIds);

      // Remove duplicates
      final Map<int, Organisation> uniqueOrgs = {};
      for (final item in response as List) {
        final orgData = item['tenant_group_data'];
        if (orgData != null) {
          final org = Organisation.fromJson(orgData as Map<String, dynamic>);
          if (org.id != null) {
            uniqueOrgs[org.id!] = org;
          }
        }
      }

      return uniqueOrgs.values.toList();
    } catch (e, stack) {
      handleError(e, stack, 'getOrganisationsFromUser');
      rethrow;
    }
  }

  /// Get other tenants from the same organisation (excluding current tenant)
  Future<List<Tenant>> getTenantsFromOrganisation(int tenantId) async {
    try {
      final organisation = await getOrganisationFromTenant(tenantId);
      if (organisation?.id == null) return [];

      final response = await supabase
          .from('tenant_group_tenants')
          .select('tenant:tenant_id(*)')
          .eq('tenant_group', organisation!.id!);

      return (response as List)
          .where((e) => e['tenant'] != null)
          .map((e) => Tenant.fromJson(e['tenant'] as Map<String, dynamic>))
          .where((t) => t.id != tenantId) // Exclude current tenant
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getTenantsFromOrganisation');
      rethrow;
    }
  }

  /// Get all linked tenants (from all organisations the tenant belongs to)
  /// SEC-007: Fixed to only load tenant_groups that user has access to
  Future<List<Tenant>> getLinkedTenants(int tenantId) async {
    try {
      // First verify user has access to this tenant
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw RepositoryException(
          message: 'User not authenticated',
          operation: 'getLinkedTenants',
        );
      }

      final userAccessResponse = await supabase
          .from('tenantUsers')
          .select('tenantId')
          .eq('userId', userId)
          .eq('tenantId', tenantId)
          .maybeSingle();

      if (userAccessResponse == null) {
        throw RepositoryException(
          message: 'Access denied: User is not member of this tenant',
          operation: 'getLinkedTenants',
        );
      }

      // Get all groups this tenant belongs to
      final myGroupsResponse = await supabase
          .from('tenant_group_tenants')
          .select('tenant_group')
          .eq('tenant_id', tenantId);

      final myGroupIds = (myGroupsResponse as List)
          .map((e) => e['tenant_group'] as int)
          .toList();

      if (myGroupIds.isEmpty) return [];

      // Get all tenants in those groups (server-side filtered)
      final response = await supabase
          .from('tenant_group_tenants')
          .select('tenant_id, tenant:tenant_id(*)')
          .inFilter('tenant_group', myGroupIds)
          .neq('tenant_id', tenantId); // Exclude current tenant

      return (response as List)
          .where((link) => link['tenant'] != null)
          .map((link) => Tenant.fromJson(link['tenant'] as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getLinkedTenants');
      rethrow;
    }
  }
}
