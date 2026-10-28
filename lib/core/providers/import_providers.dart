import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tenant/tenant.dart';
import '../../data/repositories/import_repository.dart';
import 'tenant_providers.dart';

/// ImportRepository with tenant context
///
/// SOL_FIX3: per-tenant bound instance (see [importRepositoryForTenantProvider])
/// so a running import loop keeps its tenant after a tenant switch.
final importRepositoryWithTenantProvider = Provider<ImportRepository>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  return ref.watch(importRepositoryForTenantProvider(tenantId));
});

/// SOL_FIX3: one immutable [ImportRepository] per tenant.
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
