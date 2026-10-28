import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_repository.dart';

/// Provider for UserLanguageRepository
final userLanguageRepositoryProvider = Provider<UserLanguageRepository>((ref) {
  return UserLanguageRepository(ref);
});

/// Reads/writes the account language `notifications.language` (Ionic
/// LocaleService.syncWithAccount / saveToAccount). Edge functions use it for
/// push, Telegram and e-mails.
///
/// Multi-Tenant: `notifications` has no tenantId – it holds one row per user,
/// keyed by the auth user id. Every query therefore filters by `id = userId`
/// (RLS restricts it to the signed-in user as well).
class UserLanguageRepository extends BaseRepository {
  UserLanguageRepository(super.ref);

  static const tableName = 'notifications';

  /// Account language. `hasRow` is false when the user has no
  /// notifications row yet (Ionic then never writes the language).
  Future<({bool hasRow, String? language})> getAccountLanguage(
      String userId) async {
    try {
      final row = await supabase
          .from(tableName)
          .select('language')
          .eq('id', userId)
          .maybeSingle();
      return (hasRow: row != null, language: row?['language'] as String?);
    } catch (e, stack) {
      handleError(e, stack, 'getAccountLanguage');
      rethrow;
    }
  }

  /// Stores the language on the account so server messages use it too.
  Future<void> saveAccountLanguage(String userId, String language) async {
    try {
      await supabase
          .from(tableName)
          .update({'language': language}).eq('id', userId);
    } catch (e, stack) {
      handleError(e, stack, 'saveAccountLanguage');
      rethrow;
    }
  }
}
