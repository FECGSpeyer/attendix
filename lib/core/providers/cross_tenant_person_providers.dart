import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/cross_tenant_person_repository.dart';
import 'organisation_providers.dart';
import 'tenant_providers.dart';

/// CrossTenantPersonRepository with the current tenant set
final crossTenantPersonRepositoryWithTenantProvider =
    Provider<CrossTenantPersonRepository>((ref) {
  final repo = ref.watch(crossTenantPersonRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId != null) repo.setTenantId(tenantId);
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
