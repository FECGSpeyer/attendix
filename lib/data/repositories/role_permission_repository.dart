import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/role_permission/tenant_role_permission.dart';
import 'base_repository.dart';
import '../../l10n/l10n.dart';

/// Provider for RolePermissionRepository (ohne Tenant – nutze rolePermissionRepositoryWithTenantProvider)
final rolePermissionRepositoryProvider = Provider<RolePermissionRepository>((ref) {
  return RolePermissionRepository(ref);
});

/// Repository für konfigurierbare Rollenberechtigungen.
///
/// Tabelle `tenant_role_permissions` nutzt die Spalte `tenant_id` (snake_case)
/// statt `tenantId` – gefiltert wird trotzdem IMMER nach [currentTenantId].
class RolePermissionRepository extends BaseRepository with TenantAwareRepository {
  RolePermissionRepository(super.ref);

  static const String table = 'tenant_role_permissions';

  /// Alle Rollenberechtigungen der aktuellen Instanz.
  Future<List<TenantRolePermission>> getPermissions() async {
    try {
      final response = await supabase
          .from(table)
          .select('*')
          .eq('tenant_id', currentTenantId);

      return (response as List)
          .map((e) => TenantRolePermission.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPermissions');
      rethrow;
    }
  }

  /// Aktualisiert die Flags einer Rollenberechtigung (id UND tenant_id gefiltert).
  Future<TenantRolePermission> updatePermission(TenantRolePermission permission) async {
    final id = permission.id;
    if (id == null) {
      throw RepositoryException(
        message: l10nWithoutContext.coreFlutterRolePermissionWithoutId,
        operation: 'updatePermission',
      );
    }
    try {
      final response = await supabase
          .from(table)
          .update(permission.toUpdatePayload())
          .eq('id', id)
          .eq('tenant_id', currentTenantId)
          .select()
          .single();

      return TenantRolePermission.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updatePermission');
      rethrow;
    }
  }

  /// "Dateiablage für alle Mitglieder" (tenants.files_shared). Nur Admins
  /// (DB-Trigger protect_tenant_files_flags prüft das zusätzlich).
  Future<void> updateFilesShared(bool filesShared) async {
    try {
      await supabase
          .from('tenants')
          .update({'files_shared': filesShared})
          .eq('id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateFilesShared');
      rethrow;
    }
  }
}
