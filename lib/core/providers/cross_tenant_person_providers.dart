import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/cross_tenant_person_repository.dart';
import 'organisation_providers.dart';
import 'tenant_providers.dart';

/// CrossTenantPersonRepository with the current tenant set
///
/// SOL_FIX3: per-tenant bound instance so a running multi-step flow
/// (e.g. pausing a person in all linked tenants) keeps its tenant.
final crossTenantPersonRepositoryWithTenantProvider =
    Provider<CrossTenantPersonRepository>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  return ref.watch(crossTenantPersonRepositoryForTenantProvider(tenantId));
});

/// SOL_FIX3: one immutable [CrossTenantPersonRepository] per tenant.
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
