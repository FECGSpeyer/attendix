import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/enums.dart' show Role;
import '../../data/models/parent/parent_model.dart';
import '../../data/repositories/parent_repository.dart';
import '../../data/repositories/user_registration_repository.dart'
    show AccountFlowException;
import '../../l10n/l10n.dart';
import 'tenant_providers.dart';
import 'user_registration_providers.dart';

/// Provider for ParentRepository with tenant context
final parentRepositoryWithTenantProvider = Provider<ParentRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(parentRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [ParentRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
final parentRepositoryForTenantProvider =
    Provider.family<ParentRepository, int?>((ref, tenantId) {
  final repo = ParentRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
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

  /// REVIEW_FIX3: Ionic db.createParent — the single invite flow used by the
  /// parents page and the user management page.
  ///
  /// registerUser → insert the `parents` row → set `tenantUsers.parent_id`
  /// (linkParentToTenantUser) so the parents portal works. Like Ionic, a
  /// failed insert is not rolled back (the account may have existed before);
  /// it throws [AccountFlowException] with `db.addParentFailed` so the page
  /// reports it instead of leaving a silent orphan. Other errors are
  /// rethrown unchanged.
  Future<ParentModel> invite({
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    final trimmedEmail = email.trim();
    final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
    final appId = await registration.registerUser(
      email: trimmedEmail,
      name: firstName.trim(),
      role: Role.parent,
    );
    final created = await createParent(ParentModel(
      appId: appId,
      email: trimmedEmail,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
    ));
    final parentId = created?.id;
    if (parentId == null) {
      throw AccountFlowException(l10nWithoutContext.dbAddParentFailed);
    }
    await registration.linkParentToTenantUser(appId, parentId);
    return created!;
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
