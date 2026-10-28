import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import 'base_repository.dart';

/// Provider for AdminRepository (SETTINGS2)
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref);
});

/// Ionic `SUPER_DEVELOPER_EMAIL` — never listed as an admin.
const String _superDeveloperEmail = 'developer@attendix.de';

/// An administrator of the current tenant (Ionic `Admin`).
class TenantAdmin {
  const TenantAdmin({required this.userId, this.email, this.createdAt});

  final String userId;
  final String? email;
  final DateTime? createdAt;

  factory TenantAdmin.fromJson(Map<String, dynamic> json) => TenantAdmin(
        userId: json['userId'] as String,
        email: json['email'] as String?,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

/// Thrown with a user-facing German message.
class AdminException implements Exception {
  const AdminException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// SETTINGS2: Ionic settings "Administratoren" (admin.service + db.registerUser
/// for Role.ADMIN). Only super admins (Role.admin) use it.
class AdminRepository extends BaseRepository with TenantAwareRepository {
  AdminRepository(super.ref);

  /// Ionic `getAdmins`.
  Future<List<TenantAdmin>> getAdmins() async {
    try {
      final response = await supabase
          .from('tenantUsers')
          .select('email, userId, created_at')
          .eq('role', Role.admin.value)
          .eq('tenantId', currentTenantId);

      return (response as List)
          .map((e) => TenantAdmin.fromJson(e as Map<String, dynamic>))
          .where((a) => a.email != _superDeveloperEmail)
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAdmins');
      rethrow;
    }
  }

  /// Ionic `createAdmin` → `registerUser(email, '', Role.ADMIN)`.
  ///
  /// Returns `false` when the admin was added but the inform mail could not
  /// be sent (non-blocking, the admin row already exists).
  Future<bool> createAdmin(String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();
    try {
      // 1. Already in this tenant? Promote to admin (Ionic getAppIdByEmail).
      final existing = await supabase
          .from('tenantUsers')
          .select('userId, role')
          .eq('tenantId', currentTenantId)
          .eq('email', email)
          .maybeSingle();
      if (existing != null) {
        if (existing['role'] == Role.admin.value) {
          throw const AdminException('Diese Person ist bereits Admin.');
        }
        await supabase
            .from('tenantUsers')
            .update({'role': Role.admin.value})
            .eq('tenantId', currentTenantId)
            .eq('userId', existing['userId'] as String);
        return true;
      }

      // 2. Existing account: add to tenant and inform by mail.
      final found = await supabase.rpc('get_user_id_by_email', params: {'email': email});
      final foundId = (found is List && found.isNotEmpty) ? found.first['id'] as String? : null;
      if (foundId != null) {
        await _addAdminToTenant(foundId, email);
        return _informAdmin(email);
      }

      // 3. New account via the attendix-user Edge Function.
      final res = await supabase.functions.invoke('attendix-user', body: {
        'action': 'register',
        'email': email,
        'name': '',
        'role': 'Admin',
        'roleId': Role.admin.value,
        'tenantId': currentTenantId,
      });
      final data = res.data;
      final String? userId =
          data is Map ? ((data['user'] as Map?)?['id'] as String?) : null;
      if (userId == null) {
        throw const AdminException('Der Account konnte nicht erstellt werden.');
      }
      await _addAdminToTenant(userId, email);
      return true;
    } on AdminException {
      rethrow;
    } catch (e, stack) {
      handleError(e, stack, 'createAdmin');
      rethrow;
    }
  }

  /// Inform mail for an existing account; failures are reported, not thrown.
  Future<bool> _informAdmin(String email) async {
    try {
      final res = await supabase.functions.invoke('attendix-user', body: {
        'action': 'inform',
        'email': email,
        'name': '',
        'role': 'Admin',
        'roleId': Role.admin.value,
        'tenantId': currentTenantId,
      });
      final data = res.data;
      return data is Map && data['mailSent'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _addAdminToTenant(String userId, String email) async {
    await supabase.from('tenantUsers').insert({
      'userId': userId,
      'role': Role.admin.value,
      'tenantId': currentTenantId,
      'email': email,
    });
  }

  /// Ionic `removeUserFromTenant(appId, tenantId, deleteAdmin: true)`.
  Future<void> removeAdmin(String userId) async {
    try {
      await supabase
          .from('tenantUsers')
          .delete()
          .eq('tenantId', currentTenantId)
          .eq('role', Role.admin.value)
          .eq('userId', userId);
    } catch (e, stack) {
      handleError(e, stack, 'removeAdmin');
      rethrow;
    }
  }
}
