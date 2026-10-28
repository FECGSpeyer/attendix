import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_repository.dart';
import 'tenant_providers.dart';

/// SETTINGS2: Admin repository with tenant context.
final adminRepositoryWithTenantProvider = Provider<AdminRepository>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId != null) repo.setTenantId(tenantId);
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

  Future<void> create(String email) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(adminRepositoryWithTenantProvider).createAdmin(email);
      state = const AsyncValue.data(null);
      ref.invalidate(adminsProvider);
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
