import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/organisation/organisation.dart';
import '../../data/models/person/person.dart';
import '../../data/models/tenant/tenant.dart';
import '../../data/repositories/organisation_repository.dart';
import '../config/supabase_config.dart';
import 'tenant_providers.dart';

/// Provider for the current tenant's organisation
final currentOrganisationProvider = FutureProvider<Organisation?>((ref) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return null;

  final repo = ref.watch(organisationRepositoryProvider);
  return repo.getOrganisationFromTenant(tenantId);
});

/// Provider for all organisations the current user has access to
final userOrganisationsProvider = FutureProvider<List<Organisation>>((ref) async {
  // SOL_FIX14: per-user data – reload when the account changes.
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return [];

  final repo = ref.watch(organisationRepositoryProvider);
  return repo.getOrganisationsFromUser(userId);
});

/// Provider for all tenants of a specific organisation
final organisationTenantsProvider =
    FutureProvider.family<List<Tenant>, int>((ref, organisationId) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account
  final repo = ref.watch(organisationRepositoryProvider);
  return repo.getInstancesOfOrganisation(organisationId);
});

/// Provider for other tenants from the same organisation as the current tenant
final linkedTenantsProvider = FutureProvider<List<Tenant>>((ref) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return [];

  final repo = ref.watch(organisationRepositoryProvider);
  return repo.getTenantsFromOrganisation(tenantId);
});

/// Provider for all linked tenants (from all organisations)
final allLinkedTenantsProvider = FutureProvider<List<Tenant>>((ref) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return [];

  final repo = ref.watch(organisationRepositoryProvider);
  return repo.getLinkedTenants(tenantId);
});

/// Provider for all persons from an organisation's tenants
final organisationPersonsProvider =
    FutureProvider.family<List<Person>, List<Tenant>>((ref, tenants) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account
  if (tenants.isEmpty) return [];

  final repo = ref.watch(organisationRepositoryProvider);
  return repo.getAllPersonsFromOrganisation(tenants);
});

/// Notifier for organisation mutations
class OrganisationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  OrganisationRepository get _repo => ref.read(organisationRepositoryProvider);

  /// Create a new organisation
  Future<Organisation?> create(String name) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.create(name);
      state = const AsyncValue.data(null);
      ref.invalidate(userOrganisationsProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Link current tenant to an organisation
  Future<bool> linkCurrentTenant(int organisationId) async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return false;

    state = const AsyncValue.loading();
    try {
      await _repo.linkTenantToOrganisation(tenantId, organisationId);
      state = const AsyncValue.data(null);
      ref.invalidate(currentOrganisationProvider);
      ref.invalidate(linkedTenantsProvider);
      ref.invalidate(allLinkedTenantsProvider);
      ref.invalidate(organisationTenantsProvider(organisationId));
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Unlink current tenant from an organisation
  Future<bool> unlinkCurrentTenant(int organisationId) async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return false;

    state = const AsyncValue.loading();
    try {
      await _repo.unlinkTenantFromOrganisation(tenantId, organisationId);
      state = const AsyncValue.data(null);
      ref.invalidate(currentOrganisationProvider);
      ref.invalidate(linkedTenantsProvider);
      ref.invalidate(allLinkedTenantsProvider);
      ref.invalidate(userOrganisationsProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final organisationNotifierProvider =
    NotifierProvider<OrganisationNotifier, AsyncValue<void>>(() {
  return OrganisationNotifier();
});
