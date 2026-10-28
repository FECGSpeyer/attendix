import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_repository.dart';

/// PUSH: provider for [DeviceTokenRepository].
final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  return DeviceTokenRepository(ref);
});

/// Storage of the device push token and the push switch (Ionic PushService
/// `saveToken` / `removeToken` / `togglePush` / `enablePushInDb`).
abstract class DeviceTokenStore {
  Future<void> saveToken(String token, String platform);
  Future<void> removeToken(String token);
  Future<void> setPushEnabled(bool enabled);
}

/// Push device tokens (table `device_tokens`) and the `push_enabled` flag of
/// the user's notification settings (table `notifications`).
///
/// MULTI-TENANT EXCEPTION (CLAUDE.md rule 1): neither table has a `tenantId`.
/// A device token belongs to the signed-in USER across all instances (the
/// Edge Function `send-push` looks tokens up by `user_id`), and
/// `notifications` has one row per user (`id = auth.uid()`). Every query is
/// therefore scoped by `user_id` / `id` of the signed-in user or by the
/// device's own token, exactly like Ionic; RLS restricts `device_tokens` to
/// the owner (MIGRATION_push_notifications.sql) and `notifications` to
/// `id = auth.uid()`. Tenant switches do not touch the token (Ionic).
///
/// No demo guard: Ionic PushService has none (push setup is per device).
class DeviceTokenRepository extends BaseRepository implements DeviceTokenStore {
  DeviceTokenRepository(super.ref);

  String? get _userId => supabase.auth.currentUser?.id;

  /// Ionic saveToken: one token per user, one user per token, then upsert.
  @override
  Future<void> saveToken(String token, String platform) async {
    final userId = _userId;
    // Ionic: "Save Token Error: no authenticated user found" → nothing saved
    if (userId == null) return;
    try {
      // Remove this token from other users (a token belongs to one user)
      await supabase
          .from('device_tokens')
          .delete()
          .eq('token', token)
          .neq('user_id', userId);

      // Remove other tokens of this user (one token per user)
      await supabase
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .neq('token', token);

      // Upsert the current token (insert or update)
      await supabase.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        // DB_REVIEW_REST (M8): UNIQUE(user_id, token)
        // (Ionic MIGRATION_push_notifications.sql) – without onConflict the
        // second save fails with 23505.
      }, onConflict: 'user_id,token');
    } catch (e, stack) {
      handleError(e, stack, 'saveToken');
      rethrow;
    }
  }

  /// Ionic removeToken: deletes this device's token (on logout).
  @override
  Future<void> removeToken(String token) async {
    try {
      await supabase.from('device_tokens').delete().eq('token', token);
    } catch (e, stack) {
      handleError(e, stack, 'removeToken');
      rethrow;
    }
  }

  /// Ionic togglePush / enablePushInDb: `notifications.push_enabled`.
  @override
  Future<void> setPushEnabled(bool enabled) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await supabase
          .from('notifications')
          .update({'push_enabled': enabled})
          .eq('id', userId);
    } catch (e, stack) {
      handleError(e, stack, 'setPushEnabled');
      rethrow;
    }
  }
}
