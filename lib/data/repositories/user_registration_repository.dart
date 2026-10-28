import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../models/person/person.dart';
import 'base_repository.dart';
import '../../l10n/l10n.dart';

/// Provider for [UserRegistrationRepository].
final userRegistrationRepositoryProvider =
    Provider<UserRegistrationRepository>((ref) {
  return UserRegistrationRepository(ref);
});

/// Thrown when an account flow fails; [message] is a German user-facing text.
class AccountFlowException implements Exception {
  const AccountFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// AUTH: Server-side account flows exactly like Ionic
/// (`services/user-registration`, `db.service.ts#registerUser/createAccount`).
///
/// New accounts are created by the `attendix-user` Edge Function (service
/// role, sends the "set password" mail); the client never calls
/// `auth.signUp` for other people, so the admin session is never replaced.
///
/// Edge Function actions (POST body):
/// * `register { email, name, role, roleId, tenantId }` → creates the auth
///   user + mail, returns `{ user: { id }, created, mailSent }`
/// * `inform   { email, name, role, roleId, tenantId }` → "added to instance"
/// * `approve  { email, name, role, roleId, tenantId }` → "approved"
/// * `reject   { email, name, tenantId }`               → "rejected"
class UserRegistrationRepository extends BaseRepository
    with TenantAwareRepository {
  UserRegistrationRepository(super.ref);

  /// Name of the Edge Function (Ionic).
  static const String functionName = 'attendix-user';

  /// Ionic `Utils.getRoleText` (label sent to the Edge Function).
  static String roleText(Role role) => switch (role) {
        Role.admin => l10nWithoutContext.commonRolesAdmin,
        Role.player => l10nWithoutContext.commonRolesMember,
        Role.viewer => l10nWithoutContext.commonRolesViewer,
        Role.helper => l10nWithoutContext.commonRolesHelper,
        Role.responsible => l10nWithoutContext.commonRolesResponsible,
        Role.parent => l10nWithoutContext.commonRolesParent,
        Role.voiceLeader => l10nWithoutContext.commonRolesVoiceLeader,
        Role.voiceLeaderHelper => l10nWithoutContext.commonRolesVoiceLeaderHelper,
        Role.none => l10nWithoutContext.commonRolesMember,
        Role.applicant => l10nWithoutContext.commonUnknown,
      };

  /// Builds the Edge Function body (pure, testable).
  static Map<String, dynamic> buildFunctionBody({
    required String action,
    required String email,
    required String name,
    required int tenantId,
    Role? role,
  }) {
    return {
      'action': action,
      'email': email,
      'name': name,
      if (role != null) 'role': roleText(role),
      if (role != null) 'roleId': role.value,
      'tenantId': tenantId,
    };
  }

  /// Role for a person account (Ionic createAccount): members of the main
  /// group become RESPONSIBLE, everybody else PLAYER.
  static Role accountRoleFor({int? instrumentId, int? mainGroupId}) =>
      mainGroupId != null && instrumentId == mainGroupId
          ? Role.responsible
          : Role.player;

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response =
        await supabase.functions.invoke(functionName, body: body);
    if (response.status >= 400) {
      throw AccountFlowException('Edge Function ${response.status}');
    }
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  /// Ionic `registerUser`: links an existing account to the tenant (and
  /// informs the user) or creates a new account server-side.
  ///
  /// Returns the auth user id (appId).
  Future<String> registerUser({
    required String email,
    required String name,
    required Role role,
    int? tenantId,
    bool selfRegister = false,
  }) async {
    ensureNotDemo('registerUser'); // DEMO_GUARD
    final normalizedEmail = email.toLowerCase().trim();
    final targetTenantId = tenantId ?? currentTenantId;

    final existing =
        await getAppIdByEmail(normalizedEmail, targetTenantId, role: role);

    if (existing != null) {
      final (userId, alreadyThere) = existing;
      if (alreadyThere) {
        if (role == Role.admin) {
          try {
            await updateTenantUserRole(userId, Role.admin,
                tenantId: targetTenantId);
          } catch (_) {
            throw AccountFlowException(l10nWithoutContext.dbUpdateRoleFailed);
          }
        }
        return userId;
      }
      await addUserToTenant(userId, role, normalizedEmail,
          tenantId: targetTenantId);
      if (!selfRegister) {
        await _inform(normalizedEmail, name, role, targetTenantId);
      }
      return userId;
    }

    // Account exists but is in no tenant yet (Ionic db.service fallback).
    try {
      final rows = await supabase
          .rpc('get_user_id_by_email', params: {'email': normalizedEmail});
      if (rows is List && rows.isNotEmpty && rows.first['id'] != null) {
        final userId = rows.first['id'] as String;
        await addUserToTenant(userId, role, normalizedEmail,
            tenantId: targetTenantId);
        if (!selfRegister) {
          await _inform(normalizedEmail, name, role, targetTenantId);
        }
        return userId;
      }
    } on AccountFlowException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('get_user_id_by_email failed: $e');
    }

    // New account → created server-side by the Edge Function.
    Map<String, dynamic> data;
    try {
      data = await _invoke(buildFunctionBody(
        action: 'register',
        email: normalizedEmail,
        name: name,
        role: role,
        tenantId: targetTenantId,
      ));
    } catch (_) {
      throw AccountFlowException(l10nWithoutContext.dbCreateAccountFailed);
    }
    final user = data['user'];
    final userId = user is Map ? user['id'] as String? : null;
    if (userId == null) {
      throw AccountFlowException(
        data['error'] is String
            ? l10nWithoutContext.dbCreateAccountFailedWith(data['error'] as String)
            : l10nWithoutContext.dbCreateAccountFailed,
      );
    }
    await addUserToTenant(userId, role, normalizedEmail,
        tenantId: targetTenantId);
    return userId;
  }

  Future<void> _inform(String email, String name, Role role, int tenantId) async {
    Map<String, dynamic> data;
    try {
      data = await _invoke(buildFunctionBody(
        action: 'inform',
        email: email,
        name: name,
        role: role,
        tenantId: tenantId,
      ));
    } catch (_) {
      throw AccountFlowException(l10nWithoutContext.dbNotifyUserFailed);
    }
    if (data['mailSent'] != true) {
      throw AccountFlowException(l10nWithoutContext.dbNotifyUserFailed);
    }
  }

  /// Ionic `informUserAboutApproval` ("Registrierung genehmigt"-Mail).
  Future<void> informUserAboutApproval(String email, String name, Role role) async {
    Map<String, dynamic> data;
    try {
      data = await _invoke(buildFunctionBody(
        action: 'approve',
        email: email,
        name: name,
        role: role,
        tenantId: currentTenantId,
      ));
    } catch (_) {
      throw AccountFlowException(l10nWithoutContext.dbNotifyUserFailed);
    }
    if (data['mailSent'] != true) {
      throw AccountFlowException(l10nWithoutContext.dbNotifyUserFailed);
    }
  }

  /// Ionic `informUserAboutReject` ("Registrierung abgelehnt"-Mail).
  Future<void> informUserAboutReject(String email, String name) async {
    Map<String, dynamic> data;
    try {
      data = await _invoke(buildFunctionBody(
        action: 'reject',
        email: email,
        name: name,
        tenantId: currentTenantId,
      ));
    } catch (_) {
      throw AccountFlowException(l10nWithoutContext.dbNotifyUserFailed);
    }
    if (data['mailSent'] != true) {
      throw AccountFlowException(l10nWithoutContext.dbNotifyUserFailed);
    }
  }

  /// Ionic `addUserToTenant`.
  Future<void> addUserToTenant(String userId, Role role, String email,
      {int? tenantId}) async {
    try {
      await supabase.from('tenantUsers').insert({
        'userId': userId,
        'role': role.value,
        'tenantId': tenantId ?? currentTenantId,
        'email': email,
      });
    } catch (e, stack) {
      if (kDebugMode) debugPrint('addUserToTenant failed: $e\n$stack');
      throw AccountFlowException(l10nWithoutContext.svcAddUserToTenantFailed);
    }
  }

  /// Ionic `updateTenantUser({ role })`.
  Future<void> updateTenantUserRole(String userId, Role role,
      {int? tenantId}) async {
    try {
      await supabase
          .from('tenantUsers')
          .update({'role': role.value})
          .eq('tenantId', tenantId ?? currentTenantId)
          .eq('userId', userId);
    } catch (e, stack) {
      handleError(e, stack, 'updateTenantUserRole');
      rethrow;
    }
  }

  /// Ionic createParent: `updateTenantUser({ parent_id })`.
  Future<void> linkParentToTenantUser(String userId, int parentId) async {
    try {
      await supabase
          .from('tenantUsers')
          .update({'parent_id': parentId})
          .eq('tenantId', currentTenantId)
          .eq('userId', userId);
    } catch (e, stack) {
      handleError(e, stack, 'linkParentToTenantUser');
      rethrow;
    }
  }

  /// Ionic `getAppIdByEmail` → (userId, alreadyThere) or null.
  ///
  /// NOTE (Multi-Tenant): the `tenantUsers` lookup by e-mail is intentionally
  /// cross-tenant (like Ionic) — it detects whether the person already has an
  /// account in ANY instance. Only the user id / role is used; all writes are
  /// scoped to [tenantId].
  Future<(String, bool)?> getAppIdByEmail(String email, int tenantId,
      {Role? role}) async {
    final List rows;
    try {
      rows = await supabase
          .from('tenantUsers')
          .select('userId, tenantId, role')
          .eq('email', email.toLowerCase().trim());
    } catch (_) {
      throw AccountFlowException(l10nWithoutContext.dbLoadUserFailed);
    }

    final found = rows.cast<Map<String, dynamic>>().where(
          (row) => row['tenantId'] == tenantId,
        );
    final foundTenantUser = found.isEmpty ? null : found.first;

    if (foundTenantUser != null) {
      final userId = foundTenantUser['userId'] as String;
      final foundRole = Role.fromValue(foundTenantUser['role'] as int? ?? 99);
      if (foundRole == Role.admin || role == Role.admin) {
        return (userId, true);
      }

      final table = switch (foundRole) {
        Role.player ||
        Role.responsible ||
        Role.applicant ||
        Role.helper ||
        Role.voiceLeader ||
        Role.voiceLeaderHelper =>
          'player',
        Role.parent => 'parents',
        Role.viewer => 'viewers',
        _ => null,
      };
      if (table == null) {
        throw AccountFlowException(l10nWithoutContext.dbUserAlreadyInTenant);
      }

      final List linked;
      try {
        linked = await supabase
            .from(table)
            .select('firstName, lastName')
            .eq('tenantId', tenantId)
            .eq('appId', userId);
      } catch (_) {
        throw AccountFlowException(l10nWithoutContext.dbLoadUserFailed);
      }

      if (linked.isNotEmpty) {
        final p = linked.first as Map<String, dynamic>;
        final label = switch (foundRole) {
          Role.parent => l10nWithoutContext.commonRolesParent,
          Role.viewer => l10nWithoutContext.commonRolesViewer,
          _ => roleText(foundRole),
        };
        final name = '${p['firstName']} ${p['lastName']}';
        throw AccountFlowException(
          foundRole == Role.parent
              ? l10nWithoutContext.dbUserAlreadyInInstanceAs(name, label)
              : l10nWithoutContext.dbUserAlreadyInTenantAs(name, label),
        );
      }

      // Orphaned tenantUsers row (no person linked) → clean up (Ionic).
      await supabase
          .from('tenantUsers')
          .delete()
          .eq('tenantId', tenantId)
          .eq('userId', userId);
      return null;
    }

    if (rows.isEmpty) return null;
    return ((rows.first as Map<String, dynamic>)['userId'] as String, false);
  }

  /// Ionic `createAccount(player)`: account for a person + link `appId`.
  Future<String> createPlayerAccount(Person person, {int? mainGroupId}) async {
    ensureNotDemo('createPlayerAccount'); // DEMO_GUARD
    final email = person.email?.trim() ?? '';
    if (email.isEmpty) {
      throw AccountFlowException(l10nWithoutContext.coreFlutterNoEmailAddress);
    }
    if (person.id == null) {
      throw AccountFlowException(l10nWithoutContext.coreFlutterPersonHasNoId);
    }
    final role = accountRoleFor(
        instrumentId: person.instrument, mainGroupId: mainGroupId);

    final appId = await registerUser(
      email: email,
      name: person.firstName,
      role: role,
    );

    try {
      await supabase
          .from('player')
          .update({'appId': appId})
          .eq('id', person.id!)
          .eq('tenantId', currentTenantId);
    } catch (_) {
      throw AccountFlowException(l10nWithoutContext.dbUpdateUserFailed2);
    }
    return appId;
  }
}
