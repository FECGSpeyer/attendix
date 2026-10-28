import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../features/tenant_selection/tenant_defaults.dart';
import '../models/tenant/tenant.dart';
import 'base_repository.dart';

final tenantCreateRepositoryProvider = Provider<TenantCreateRepository>((ref) {
  return TenantCreateRepository(ref);
});

/// Creates a new tenant (Ionic db.service createInstance).
///
/// Multi-tenant note: there is no current tenant to filter by yet. Every
/// write after the `tenants` insert is scoped to the id of the tenant that
/// was just created (`tenantId` / `tenant_id` = new id); nothing reads or
/// writes rows of other tenants.
class TenantCreateRepository extends BaseRepository {
  TenantCreateRepository(super.ref);

  Future<Tenant> createTenant({
    required String shortName,
    required String longName,
    required String type,
    required String mainGroupName,
  }) async {
    ensureNotDemo('createTenant'); // DEMO_GUARD
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw RepositoryException(
          message: 'Nicht angemeldet',
          operation: 'createTenant',
        );
      }

      final tenantRow = await supabase
          .from('tenants')
          .insert(buildNewTenantPayload(
            shortName: shortName,
            longName: longName,
            type: type,
          ))
          .select()
          .single();
      final tenantId = tenantRow['id'] as int;

      await supabase.from('tenantUsers').insert({
        'tenantId': tenantId,
        'userId': user.id,
        'role': Role.admin.value,
        'email': user.email,
      });

      await supabase
          .from('instruments')
          .insert(buildMainGroupPayload(tenantId: tenantId, name: mainGroupName));

      await supabase
          .from('attendance_types')
          .insert(buildDefaultAttendanceTypes(tenantId: tenantId, type: type));

      return Tenant.fromJson(tenantRow);
    } catch (e, stack) {
      handleError(e, stack, 'createTenant');
      rethrow;
    }
  }
}
