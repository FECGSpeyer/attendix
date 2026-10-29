import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;

import '../../data/repositories/admin_repository.dart';
import 'tenant_providers.dart';

/// SETTINGS2: Admin repository with tenant context.
final adminRepositoryWithTenantProvider = Provider<AdminRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(adminRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [AdminRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final adminRepositoryForTenantProvider =
    Provider.family<AdminRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _adminRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _adminRepositoryForAccountProvider =
    Provider.family<AdminRepository, AccountScopeKey>((ref, key) {
  final repo = AdminRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

/// Administrators of the current tenant (Ionic settings `admins`).
final adminsProvider = FutureProvider<List<TenantAdmin>>((ref) async {
  final repo = ref.watch(adminRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getAdmins();
});

/// Mutations for the Administratoren list.
class AdminNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Returns `false` when the admin was added but could not be informed.
  Future<bool> create(String email) async {
    state = const AsyncValue.loading();
    try {
      final informed =
          await ref.read(adminRepositoryWithTenantProvider).createAdmin(email);
      state = const AsyncValue.data(null);
      ref.invalidate(adminsProvider);
      return informed;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> remove(String userId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(adminRepositoryWithTenantProvider).removeAdmin(userId);
      state = const AsyncValue.data(null);
      ref.invalidate(adminsProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final adminNotifierProvider =
    NotifierProvider<AdminNotifier, AsyncValue<void>>(AdminNotifier.new);
