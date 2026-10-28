import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/player_absence/player_absence.dart';
import '../../data/repositories/player_absence_repository.dart';
import '../constants/enums.dart';
import 'role_permission_providers.dart';
import 'tenant_providers.dart';

/// PlayerAbsenceRepository with tenant context
final playerAbsenceRepositoryWithTenantProvider = Provider<PlayerAbsenceRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(playerAbsenceRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [PlayerAbsenceRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
final playerAbsenceRepositoryForTenantProvider =
    Provider.family<PlayerAbsenceRepository, int?>((ref, tenantId) {
  final repo = PlayerAbsenceRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});

/// Planned absences of one person (sorted by from_date)
final playerAbsencesByPersonIdProvider =
    FutureProvider.family<List<PlayerAbsence>, int>((ref, personId) async {
  final repo = ref.watch(playerAbsenceRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getAbsencesForPerson(personId);
});

/// All planned absences of the current tenant
final playerAbsencesProvider = FutureProvider<List<PlayerAbsence>>((ref) async {
  final repo = ref.watch(playerAbsenceRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getAbsencesForTenant();
});

// INTEGRATION: the role flags come from role_permission_providers
// (tenant_role_permissions, Ionic db.getPermissionForRole) – one source.

/// Ionic person page: `canManagePlannedAbsences = isAdmin || perm.player_planned_absence`
/// (isAdmin = Admin or Responsible; perm of the user's real role).
final canManagePlannedAbsencesProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  if (role == Role.admin || role == Role.responsible) return true;
  return ref.watch(rolePermissionByRoleProvider(role))?.playerPlannedAbsence ??
      false;
});

/// Self-service: may the current user report planned absences?
/// (Ionic signout page: permission of the user's own role)
final canSelfReportAbsenceProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return ref.watch(rolePermissionByRoleProvider(role))?.playerPlannedAbsence ??
      false;
});

/// Mutations for planned absences
class PlayerAbsenceNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  PlayerAbsenceRepository get _repo =>
      ref.read(playerAbsenceRepositoryWithTenantProvider);

  /// Adds the absence and excuses all upcoming attendances in range.
  /// Returns the number of excused attendances, or null on error.
  Future<int?> addAbsence({
    required int personId,
    required String fromDate,
    required String untilDate,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addAbsence(
        personId: personId,
        fromDate: fromDate,
        untilDate: untilDate,
        reason: reason,
      );
      final count = await _repo.excuseUpcomingAttendances(
        personId: personId,
        fromDate: fromDate,
        untilDate: untilDate,
        reason: reason,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(playerAbsencesByPersonIdProvider(personId));
      ref.invalidate(playerAbsencesProvider);
      return count;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Deletes the absence and resets the attendances it excused.
  Future<bool> deleteAbsence(PlayerAbsence absence) async {
    if (absence.id == null) return false;
    state = const AsyncValue.loading();
    try {
      await _repo.deleteAbsence(absence.id!);
      await _repo.resetExcusedAttendances(absence: absence);
      state = const AsyncValue.data(null);
      ref.invalidate(playerAbsencesByPersonIdProvider(absence.personId));
      ref.invalidate(playerAbsencesProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final playerAbsenceNotifierProvider =
    NotifierProvider<PlayerAbsenceNotifier, AsyncValue<void>>(
  PlayerAbsenceNotifier.new,
);
