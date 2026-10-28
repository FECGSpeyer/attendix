import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tenant/tenant.dart';
import '../../data/repositories/import_repository.dart';
import 'tenant_providers.dart';

/// ImportRepository with tenant context
final importRepositoryWithTenantProvider = Provider<ImportRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(importRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [ImportRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
final importRepositoryForTenantProvider =
    Provider.family<ImportRepository, int?>((ref, tenantId) {
  final repo = ImportRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});

/// Additional song fields of the current tenant (`tenants.song_additional_fields`)
final songAdditionalFieldsProvider = FutureProvider<List<ExtraField>>((ref) async {
  final repo = ref.watch(importRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  try {
    return await repo.getSongAdditionalFields();
  } catch (_) {
    // Column may not exist on older backends.
    return [];
  }
});
