import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/cross_tenant_person_repository.dart';
import 'organisation_providers.dart';
import 'tenant_providers.dart';

/// CrossTenantPersonRepository with the current tenant set
final crossTenantPersonRepositoryWithTenantProvider = Provider<CrossTenantPersonRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(crossTenantPersonRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [CrossTenantPersonRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
final crossTenantPersonRepositoryForTenantProvider =
    Provider.family<CrossTenantPersonRepository, int?>((ref, tenantId) {
  final repo = CrossTenantPersonRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});

/// Ids of tenants linked to the current tenant via an organisation
/// (membership is verified by OrganisationRepository.getLinkedTenants).
final linkedTenantIdsProvider = FutureProvider<List<int>>((ref) async {
  try {
    final tenants = await ref.watch(allLinkedTenantsProvider.future);
    return tenants.map((t) => t.id).whereType<int>().toList();
  } catch (_) {
    return const [];
  }
});
