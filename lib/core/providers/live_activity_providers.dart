import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;

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
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final liveActivityRepositoryForTenantProvider =
    Provider.family<LiveActivityRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _liveActivityRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _liveActivityRepositoryForAccountProvider =
    Provider.family<LiveActivityRepository, AccountScopeKey>((ref, key) {
  final repo = LiveActivityRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});
