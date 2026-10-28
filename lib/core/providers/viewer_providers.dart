import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/viewer/viewer.dart';
import '../../data/repositories/viewer_repository.dart';
import 'tenant_providers.dart';

/// Provider for ViewerRepository with tenant context
final viewerRepositoryWithTenantProvider = Provider<ViewerRepository>((ref) {
  final repo = ref.watch(viewerRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);

  if (tenantId != null) {
    repo.setTenantId(tenantId);
  }

  return repo;
});

/// Provider for all viewers of the current tenant
final viewersProvider = FutureProvider<List<Viewer>>((ref) async {
  final repo = ref.watch(viewerRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return [];

  return repo.getViewers();
});

/// Notifier for viewer mutations
class ViewerNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  ViewerRepository get _repo => ref.read(viewerRepositoryWithTenantProvider);

  /// Create a new viewer
  Future<Viewer?> createViewer(Viewer viewer) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createViewer(viewer);
      state = const AsyncValue.data(null);
      ref.invalidate(viewersProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Delete a viewer
  /// Throws on failure (LOGIC_PEOPLE: pages must not show success toasts).
  Future<bool> deleteViewer(int id, {String? appId}) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteViewer(id, appId: appId);
      state = const AsyncValue.data(null);
      ref.invalidate(viewersProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final viewerNotifierProvider =
    NotifierProvider<ViewerNotifier, AsyncValue<void>>(() {
  return ViewerNotifier();
});
