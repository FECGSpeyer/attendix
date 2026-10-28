import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'base_repository.dart';

/// Account-level (user-scoped, cross-tenant) operations of the signed-in user.
///
/// NOTE (Multi-Tenant): these operations act on the authenticated user
/// (`auth.users` + `user_metadata`), not on tenant data, so there is no
/// `tenantId` filter. The `delete-account` edge function derives the user from
/// the caller's JWT, so a user can only ever delete themselves.
class AccountRepository extends BaseRepository {
  AccountRepository(super.ref);

  /// Edge function name, identical to Ionic `db.service.ts#deleteAccount`.
  static const String deleteAccountFunction = 'delete-account';

  /// user_metadata key stamped when the user accepts the terms (Ionic).
  static const String termsAcceptedAtKey = 'terms_accepted_at';

  /// Permanently deletes the calling user's account (DSGVO): removes all
  /// tenant memberships, player rows linked via appId, device tokens,
  /// notification config and the auth user itself (server side).
  ///
  /// Signs out afterwards.
  Future<void> deleteAccount() async {
    try {
      final response = await supabase.functions.invoke(deleteAccountFunction);
      if (response.status >= 400) {
        throw RepositoryException(
          message: 'Fehler beim Löschen des Kontos',
          operation: 'deleteAccount',
          code: '${response.status}',
        );
      }
    } catch (e, stack) {
      handleError(e, stack, 'deleteAccount');
      rethrow;
    }
    await supabase.auth.signOut();
  }

  /// Whether the current user has accepted the terms (Ionic `TermsGuard`).
  bool get hasAcceptedTerms {
    final metadata = supabase.auth.currentUser?.userMetadata;
    return metadata?[termsAcceptedAtKey] != null;
  }

  /// Stamps `terms_accepted_at` into the user's metadata.
  ///
  /// Like Ionic, refreshes the session first; if that fails the user is
  /// signed out and a [SessionExpiredException] is thrown.
  Future<void> acceptTerms() async {
    try {
      await supabase.auth.refreshSession();
    } catch (_) {
      await supabase.auth.signOut();
      throw const SessionExpiredException();
    }
    try {
      await supabase.auth.updateUser(
        UserAttributes(data: {
          termsAcceptedAtKey: DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (e, stack) {
      handleError(e, stack, 'acceptTerms');
      rethrow;
    }
  }
}

/// Thrown by [AccountRepository.acceptTerms] when the session can't be
/// refreshed.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref);
});
