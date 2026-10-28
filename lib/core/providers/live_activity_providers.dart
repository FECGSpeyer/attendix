import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/live_activity_repository.dart';
import 'tenant_providers.dart';

// LIVE_ACTIVITY: the service itself lives in
// core/services/live_activity_service.dart (liveActivityServiceProvider).

/// LiveActivityRepository with tenant set
final liveActivityRepositoryWithTenantProvider = Provider<LiveActivityRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(liveActivityRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [LiveActivityRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
final liveActivityRepositoryForTenantProvider =
    Provider.family<LiveActivityRepository, int?>((ref, tenantId) {
  final repo = LiveActivityRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});
