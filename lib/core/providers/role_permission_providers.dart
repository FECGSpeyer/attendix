import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/role_permission/tenant_role_permission.dart';
import '../../data/repositories/role_permission_repository.dart';
import '../constants/enums.dart';
import 'debug_providers.dart';
import 'self_service_providers.dart';
import 'tenant_providers.dart';
import '../../l10n/l10n.dart';

/// Repository mit Tenant-Kontext
final rolePermissionRepositoryWithTenantProvider = Provider<RolePermissionRepository>((ref) {
  final repo = ref.watch(rolePermissionRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId != null) repo.setTenantId(tenantId);
  return repo;
});

/// Alle Rollenberechtigungen der aktuellen Instanz
final rolePermissionsProvider = FutureProvider<List<TenantRolePermission>>((ref) async {
  final repo = ref.watch(rolePermissionRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getPermissions();
});

/// Berechtigung für eine bestimmte Rolle (wie DbService.getPermissionForRole)
final rolePermissionByRoleProvider = Provider.family<TenantRolePermission?, Role>((ref, role) {
  final permissions = ref.watch(rolePermissionsProvider).valueOrNull ?? const [];
  for (final p in permissions) {
    if (p.role == role.value) return p;
  }
  return null;
});

/// Berechtigung der aktuellen Rolle des Users
final currentRolePermissionProvider = Provider<TenantRolePermission?>((ref) {
  final role = ref.watch(effectiveRoleProvider);
  return ref.watch(rolePermissionByRoleProvider(role));
});

// -----------------------------------------------------------------------------
// Abgeleitete Berechtigungen (wie in den Ionic-Seiten)
// -----------------------------------------------------------------------------

/// Pure Logik: Darf die Rolle neue Anwesenheiten anlegen? (att-list.page.ts)
bool canCreateAttendanceFor(Role role, TenantRolePermission? perm) {
  if (role.isAdmin || role.isResponsible) return true;
  if (role.isHelperRole) return perm?.attendanceCreate != false;
  return false;
}

/// Pure Logik: Darf die Rolle Spielernotizen in der Anwesenheit sehen?
bool canViewAttendanceNotesFor(Role role, TenantRolePermission? perm) {
  if (!role.isHelperRole) return true;
  return perm?.playerNotesView ?? false;
}

/// Pure Logik: Darf die Rolle die Checkliste in der Anwesenheit sehen?
bool canViewAttendanceChecklistFor(Role role, TenantRolePermission? perm) {
  if (!role.isHelperRole) return true;
  return perm?.checklistView ?? false;
}

/// Pure Logik: Muss die Personenliste auf die eigene Gruppe eingeschränkt werden?
bool restrictToOwnGroupFor(Role role, TenantRolePermission? perm) {
  return role.isHelperRole && perm != null && !perm.attendanceAllGroups;
}

/// Pure Logik: Dateiablage lesen (DbService.canAccessFiles / files_bucket_policies.sql)
bool canAccessFilesFor(Role role, {required bool filesShared}) {
  if (role == Role.none) return false;
  if (filesShared) return role != Role.applicant && role != Role.none;
  return role.isAdmin || role.isResponsible || role.isHelper || role.isVoiceLeaderHelper;
}

/// Pure Logik: Dateiablage bearbeiten (nur Admin/Verantwortliche)
bool canEditFilesFor(Role role) => role.isAdmin || role.isResponsible;

/// Darf neue Anwesenheiten anlegen (Helfer abhängig von attendance_create)
final canCreateAttendanceProvider = Provider<bool>((ref) {
  final role = ref.watch(effectiveRoleProvider);
  return canCreateAttendanceFor(role, ref.watch(currentRolePermissionProvider));
});

/// Darf Spielernotizen in der Anwesenheitsansicht sehen
final canViewAttendanceNotesProvider = Provider<bool>((ref) {
  final role = ref.watch(effectiveRoleProvider);
  return canViewAttendanceNotesFor(role, ref.watch(currentRolePermissionProvider));
});

/// Darf die Checkliste in der Anwesenheitsansicht sehen
final canViewAttendanceChecklistProvider = Provider<bool>((ref) {
  final role = ref.watch(effectiveRoleProvider);
  return canViewAttendanceChecklistFor(role, ref.watch(currentRolePermissionProvider));
});

/// Gruppe (instrument), auf die ein Helfer ohne "Alle Gruppen pflegen"
/// eingeschränkt ist. null = keine Einschränkung.
final helperGroupFilterProvider = FutureProvider<int?>((ref) async {
  final role = ref.watch(effectiveRoleProvider);
  final perm = ref.watch(currentRolePermissionProvider);
  if (!restrictToOwnGroupFor(role, perm)) return null;
  final profile = await ref.watch(currentSelfServicePlayerProvider.future);
  return profile?.instrument;
});

/// Spieler dürfen sich selbst pausieren (player_self_pause der Spieler-Rolle)
final canSelfPauseProvider = Provider<bool>((ref) {
  return ref.watch(rolePermissionByRoleProvider(Role.player))?.playerSelfPause ?? false;
});

/// Geplante Abwesenheiten für sich selbst eintragen (player_planned_absence)
final canPlannedAbsenceProvider = Provider<bool>((ref) {
  return ref.watch(currentRolePermissionProvider)?.playerPlannedAbsence ?? false;
});

/// Dateiablage lesen
final canAccessFilesProvider = Provider<bool>((ref) {
  final role = ref.watch(effectiveRoleProvider);
  final tenant = ref.watch(currentTenantProvider);
  return canAccessFilesFor(role, filesShared: tenant?.filesShared ?? false);
});

/// Dateiablage bearbeiten
final canEditFilesProvider = Provider<bool>((ref) {
  return canEditFilesFor(ref.watch(effectiveRoleProvider));
});

/// Mutations für die Seite "Rollen & Berechtigungen"
class RolePermissionNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Speichert geänderte Berechtigungen und optional files_shared.
  Future<bool> save(List<TenantRolePermission> permissions, {bool? filesShared}) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(rolePermissionRepositoryWithTenantProvider);
      if (!repo.hasTenantId) throw StateError(l10nWithoutContext.coreFlutterNoTenantSelected);

      for (final p in permissions) {
        if (p.id != null) await repo.updatePermission(p);
      }

      if (filesShared != null) {
        await repo.updateFilesShared(filesShared);
        final tenant = ref.read(currentTenantProvider);
        if (tenant != null) {
          await ref
              .read(currentTenantProvider.notifier)
              .setTenantLocal(tenant.copyWith(filesShared: filesShared));
        }
      }

      state = const AsyncValue.data(null);
      ref.invalidate(rolePermissionsProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final rolePermissionNotifierProvider = NotifierProvider<RolePermissionNotifier, AsyncValue<void>>(
  RolePermissionNotifier.new,
);
