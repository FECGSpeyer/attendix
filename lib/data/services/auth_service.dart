import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/enums.dart';

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthService(supabase);
});

/// Service for authentication-related operations
class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  // AUTH: account creation moved to UserRegistrationRepository
  // (server-side via the `attendix-user` Edge Function, like Ionic).

  /// Update a user's role in a tenant
  Future<void> updateUserRole({
    required String userId,
    required int tenantId,
    required Role newRole,
  }) async {
    try {
      await _supabase
          .from('tenantUsers')
          .update({'role': newRole.value})
          .eq('userId', userId)
          .eq('tenantId', tenantId);
    } catch (e) {
      throw AuthException('Fehler beim Ändern der Rolle: $e');
    }
  }

  /// Get a user's role in a tenant
  Future<Role?> getUserRole({
    required String userId,
    required int tenantId,
  }) async {
    try {
      final response = await _supabase
          .from('tenantUsers')
          .select('role')
          .eq('userId', userId)
          .eq('tenantId', tenantId)
          .maybeSingle();

      if (response == null) return null;
      // RT-004: Safe type cast with fallback to Role.none (99)
      return Role.fromValue(response['role'] as int? ?? 99);
    } catch (e) {
      return null;
    }
  }

  /// Remove a user's account connection from a person
  Future<void> unlinkAccount({
    required int personId,
    required int tenantId,
    required String userId,
  }) async {
    try {
      // Remove appId from player
      await _supabase
          .from('player')
          .update({'appId': null})
          .eq('id', personId)
          .eq('tenantId', tenantId);

      // Remove tenantUsers entry
      await _supabase
          .from('tenantUsers')
          .delete()
          .eq('userId', userId)
          .eq('tenantId', tenantId);
    } catch (e) {
      throw AuthException('Fehler beim Entfernen der Account-Verknüpfung: $e');
    }
  }
}

/// Exception for auth-related errors
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
