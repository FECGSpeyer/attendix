import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/parent/parent_model.dart';
import '../../data/repositories/parent_repository.dart';
import 'tenant_providers.dart';

/// Provider for ParentRepository with tenant context
final parentRepositoryWithTenantProvider = Provider<ParentRepository>((ref) {
  final repo = ref.watch(parentRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);

  if (tenantId != null) {
    repo.setTenantId(tenantId);
  }

  return repo;
});

/// Provider for all parents of the current tenant
final parentsProvider = FutureProvider<List<ParentModel>>((ref) async {
  final repo = ref.watch(parentRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return [];

  return repo.getParents();
});

/// Notifier for parent mutations
class ParentNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  ParentRepository get _repo => ref.read(parentRepositoryWithTenantProvider);

  /// Create a new parent
  Future<ParentModel?> createParent(ParentModel parent) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createParent(parent);
      state = const AsyncValue.data(null);
      ref.invalidate(parentsProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Delete a parent
  /// Throws on failure (LOGIC_PEOPLE: pages must not show success toasts).
  Future<bool> deleteParent(int id, {String? appId}) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteParent(id, appId: appId);
      state = const AsyncValue.data(null);
      ref.invalidate(parentsProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final parentNotifierProvider =
    NotifierProvider<ParentNotifier, AsyncValue<void>>(() {
  return ParentNotifier();
});
