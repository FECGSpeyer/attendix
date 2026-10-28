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

/// SOL_FIX2: true nur, wenn die Rollenberechtigungen der aktuellen Instanz
/// vollständig geladen sind (nicht loading, nicht error, kein Wert einer
/// vorherigen Instanz während eines Reloads). Solange das nicht bestätigt
/// ist, werden Helfer-Rechte verweigert statt "kein Eintrag = erlaubt".
final rolePermissionsConfirmedProvider = Provider<bool>((ref) {
  final async = ref.watch(rolePermissionsProvider);
  return permissionsConfirmed(async);
});

/// Pure Logik zu [rolePermissionsConfirmedProvider].
bool permissionsConfirmed(AsyncValue<List<TenantRolePermission>> async) =>
    async.hasValue && !async.isLoading && !async.hasError;

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
///
/// Ionic: `perm?.attendance_create !== false` – eine fehlende Zeile entspricht
/// dem DB-Default (true). [permissionsConfirmed] = false (Berechtigungen noch
/// nicht geladen oder Ladefehler) verweigert Helfern das Anlegen (SOL_FIX2).
bool canCreateAttendanceFor(Role role, TenantRolePermission? perm, {bool permissionsConfirmed = true}) {
  if (role.isAdmin || role.isResponsible) return true;
  if (role.isHelperRole) return permissionsConfirmed && perm?.attendanceCreate != false;
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

/// Darf neue Anwesenheiten anlegen (Helfer abhängig von attendance_create).
/// Synchron für UI/Router: Helfer erst nach bestätigt geladenen Berechtigungen.
final canCreateAttendanceProvider = Provider<bool>((ref) {
  final role = ref.watch(effectiveRoleProvider);
  return canCreateAttendanceFor(
    role,
    ref.watch(currentRolePermissionProvider),
    permissionsConfirmed: ref.watch(rolePermissionsConfirmedProvider),
  );
});

/// SOL_FIX2: Schreibpfad – wartet auf die frisch geladenen Berechtigungen der
/// aktuellen Instanz. Ladefehler → Fehlerzustand (Aufrufer verweigert).
final canCreateAttendanceConfirmedProvider = FutureProvider<bool>((ref) async {
  final role = ref.watch(effectiveRoleProvider);
  if (role.isAdmin || role.isResponsible) return true;
  if (!role.isHelperRole) return false;
  final permissions = await ref.watch(rolePermissionsProvider.future);
  final perm = permissions.where((p) => p.role == role.value).firstOrNull;
  return canCreateAttendanceFor(role, perm);
});

/// Liest [canCreateAttendanceConfirmedProvider]; jeder Fehler = verweigert.
Future<bool> confirmCanCreateAttendance(Future<bool> Function() read) async {
  try {
    return await read();
  } catch (_) {
    return false;
  }
}

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

/// Welche Personen eine Rolle in der Anwesenheit sehen und deren Status
/// setzen darf (SOL_FIX2: ersetzt das frühere `int?`, bei dem null sowohl
/// "alle Gruppen" als auch "unbekannt" bedeutete).
class AttendanceGroupScope {
  const AttendanceGroupScope.all()
      : groupId = null,
        denied = false;
  const AttendanceGroupScope.group(int this.groupId) : denied = false;

  /// Berechtigung nicht bestätigt (lädt/Fehler) oder Helfer ohne eigene Gruppe.
  const AttendanceGroupScope.denied()
      : groupId = null,
        denied = true;

  /// Eigene Gruppe eines eingeschränkten Helfers.
  final int? groupId;
  final bool denied;

  bool get isAll => !denied && groupId == null;

  bool allowsGroup(int? instrument) {
    if (denied) return false;
    if (groupId == null) return true;
    return instrument == groupId;
  }

  @override
  bool operator ==(Object other) =>
      other is AttendanceGroupScope && other.groupId == groupId && other.denied == denied;

  @override
  int get hashCode => Object.hash(groupId, denied);
}

/// Pure Logik zu [attendanceGroupScopeProvider].
///
/// Ionic attendance.page.ts: Helfer ohne `attendance_all_groups` sehen nur
/// ihre Gruppe (`profile.instrument`). Abweichung (SOL_FIX2): fehlt das
/// Profil/die Gruppe, sieht der Helfer niemanden statt alle.
AttendanceGroupScope attendanceGroupScopeFor(Role role, TenantRolePermission? perm, int? profileGroup) {
  if (!restrictToOwnGroupFor(role, perm)) return const AttendanceGroupScope.all();
  if (profileGroup == null) return const AttendanceGroupScope.denied();
  return AttendanceGroupScope.group(profileGroup);
}

/// Gruppen-Scope des aktuellen Users in der Anwesenheit. Lädt/Fehler →
/// Aufrufer behandeln den Zustand als [AttendanceGroupScope.denied].
final attendanceGroupScopeProvider = FutureProvider<AttendanceGroupScope>((ref) async {
  final role = ref.watch(effectiveRoleProvider);
  if (!role.isHelperRole) return const AttendanceGroupScope.all();
  final permissions = await ref.watch(rolePermissionsProvider.future);
  final perm = permissions.where((p) => p.role == role.value).firstOrNull;
  if (!restrictToOwnGroupFor(role, perm)) return const AttendanceGroupScope.all();
  final profile = await ref.watch(currentSelfServicePlayerProvider.future);
  return attendanceGroupScopeFor(role, perm, profile?.instrument);
});

/// Synchroner Zugriff: alles außer einem geladenen Wert = verweigert.
AttendanceGroupScope resolvedGroupScope(AsyncValue<AttendanceGroupScope> async) {
  if (async.isLoading || async.hasError || !async.hasValue) return const AttendanceGroupScope.denied();
  return async.requireValue;
}

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
