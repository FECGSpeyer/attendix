import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tenant/tenant.dart';
import '../../data/repositories/import_repository.dart';
import 'tenant_providers.dart';

/// ImportRepository with tenant context
final importRepositoryWithTenantProvider = Provider<ImportRepository>((ref) {
  final repo = ref.watch(importRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId != null) repo.setTenantId(tenantId);
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
