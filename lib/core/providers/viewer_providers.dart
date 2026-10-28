import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;

import '../constants/enums.dart' show Role;
import '../../data/models/viewer/viewer.dart';
import '../../data/repositories/user_registration_repository.dart'
    show AccountFlowException;
import '../../data/repositories/viewer_repository.dart';
import '../../l10n/l10n.dart';
import 'tenant_providers.dart';
import 'user_registration_providers.dart';

/// Provider for ViewerRepository with tenant context
final viewerRepositoryWithTenantProvider = Provider<ViewerRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(viewerRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [ViewerRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final viewerRepositoryForTenantProvider =
    Provider.family<ViewerRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _viewerRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _viewerRepositoryForAccountProvider =
    Provider.family<ViewerRepository, AccountScopeKey>((ref, key) {
  final repo = ViewerRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
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
  Future<Viewer?> createViewer(Viewer viewer) => _createViewerWith(_repo, viewer);

  /// SOL_FIX7: inserts through a repository bound by the caller before its
  /// first await (see [invite]), so a tenant switch mid-flow cannot create
  /// the row in another tenant.
  Future<Viewer?> _createViewerWith(ViewerRepository repo, Viewer viewer) async {
    state = const AsyncValue.loading();
    try {
      final result = await repo.createViewer(viewer);
      state = const AsyncValue.data(null);
      ref.invalidate(viewersProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// REVIEW_FIX3: Ionic db.createViewer — the single invite flow used by the
  /// viewers page and the user management page.
  ///
  /// registerUser (links an existing account or creates one via the
  /// attendix-user Edge Function) → insert the `viewers` row. Like Ionic, a
  /// failed insert is not rolled back (the account may have existed before);
  /// it throws [AccountFlowException] with `db.addViewerFailed` so the page
  /// reports it instead of leaving a silent orphan. Other errors
  /// (registerUser, demo guard) are rethrown unchanged.
  Future<Viewer> invite({
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    final trimmedEmail = email.trim();
    // SOL_FIX7: bind both tenant repositories before the first await.
    final repo = _repo;
    final appId = await ref
        .read(userRegistrationRepositoryWithTenantProvider)
        .registerUser(
          email: trimmedEmail,
          name: firstName.trim(),
          role: Role.viewer,
        );
    final created = await _createViewerWith(repo, Viewer(
      appId: appId,
      email: trimmedEmail,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
    ));
    if (created == null) {
      throw AccountFlowException(l10nWithoutContext.dbAddViewerFailed);
    }
    return created;
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
