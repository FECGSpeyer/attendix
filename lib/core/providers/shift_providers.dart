import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;

import '../../data/models/shift/shift_plan.dart';
import '../../data/repositories/repositories.dart';
import 'tenant_providers.dart';

/// Initialized shift repository with tenant context
final shiftRepositoryWithTenantProvider = Provider<ShiftRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(shiftRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [ShiftRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final shiftRepositoryForTenantProvider =
    Provider.family<ShiftRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _shiftRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _shiftRepositoryForAccountProvider =
    Provider.family<ShiftRepository, AccountScopeKey>((ref, key) {
  final repo = ShiftRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

/// Provider for all shift plans
final shiftsProvider = FutureProvider<List<ShiftPlan>>((ref) async {
  final repo = ref.watch(shiftRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return [];

  return repo.getShifts();
});

/// Provider for a single shift plan by ID
final shiftByIdProvider =
    FutureProvider.family<ShiftPlan?, String>((ref, id) async {
  final repo = ref.watch(shiftRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return null;

  return repo.getShiftById(id);
});

/// Provider to check if a shift is used by players
final shiftUsageCountProvider =
    FutureProvider.family<int, String>((ref, id) async {
  final repo = ref.watch(shiftRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return 0;

  return repo.getShiftUsageCount(id);
});

/// Notifier for shift mutations
class ShiftNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  ShiftRepository get _repo => ref.read(shiftRepositoryWithTenantProvider);

  /// Create a new shift plan
  Future<ShiftPlan?> createShift(ShiftPlan plan) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createShift(plan);
      state = const AsyncValue.data(null);
      ref.invalidate(shiftsProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Update an existing shift plan
  Future<ShiftPlan?> updateShift(ShiftPlan plan) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.updateShift(plan);
      state = const AsyncValue.data(null);
      ref.invalidate(shiftsProvider);
      // Also invalidate the specific shift
      if (plan.id != null) {
        ref.invalidate(shiftByIdProvider(plan.id!));
      }
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Delete a shift plan
  Future<bool> deleteShift(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteShift(id);
      state = const AsyncValue.data(null);
      ref.invalidate(shiftsProvider);
      ref.invalidate(shiftByIdProvider(id));
      ref.invalidate(shiftUsageCountProvider(id));
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final shiftNotifierProvider =
    NotifierProvider<ShiftNotifier, AsyncValue<void>>(() {
  return ShiftNotifier();
});
