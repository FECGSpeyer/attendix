import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;

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
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final parentRepositoryForTenantProvider =
    Provider.family<ParentRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _parentRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _parentRepositoryForAccountProvider =
    Provider.family<ParentRepository, AccountScopeKey>((ref, key) {
  final repo = ParentRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

/// Provider for all parents of the current tenant
final parentsProvider = FutureProvider<List<ParentModel>>((ref) async {
  final repo = ref.watch(parentRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return [];

  return repo.getParents();
});

/// ACCOUNT_SWITCH: the signed-in account's own parent entry in the current
/// tenant (`tenantUsers.parent_id`), e.g. for its name in the account
/// switcher. Null for accounts that are not parents.
final ownParentProvider = FutureProvider<ParentModel?>((ref) async {
  final repo = ref.watch(parentRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  final tenantUser = await ref.watch(currentTenantUserProvider.future);
  final parentId = tenantUser?.parentId;
  if (parentId == null) return null;
  return repo.getParentById(parentId);
});

/// Notifier for parent mutations
class ParentNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  ParentRepository get _repo => ref.read(parentRepositoryWithTenantProvider);

  /// Create a new parent
  Future<ParentModel?> createParent(ParentModel parent) => _createParentWith(_repo, parent);

  /// SOL_FIX7: inserts through a repository bound by the caller before its
  /// first await (see [invite]), so a tenant switch mid-flow cannot create
  /// the row in another tenant.
  Future<ParentModel?> _createParentWith(ParentRepository repo, ParentModel parent) async {
    state = const AsyncValue.loading();
    try {
      final result = await repo.createParent(parent);
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
    // SOL_FIX7: bind both tenant repositories before the first await.
    final repo = _repo;
    final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
    final appId = await registration.registerUser(
      email: trimmedEmail,
      name: firstName.trim(),
      role: Role.parent,
    );
    final created = await _createParentWith(repo, ParentModel(
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
