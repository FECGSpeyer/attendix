import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;

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
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final importRepositoryForTenantProvider =
    Provider.family<ImportRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _importRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _importRepositoryForAccountProvider =
    Provider.family<ImportRepository, AccountScopeKey>((ref, key) {
  final repo = ImportRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
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
