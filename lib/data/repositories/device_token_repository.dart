import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_repository.dart';

/// PUSH: provider for [DeviceTokenRepository].
final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  return DeviceTokenRepository(ref);
});

/// Storage of the device push token and the push switch (Ionic PushService
/// `saveToken` / `removeToken` / `togglePush` / `enablePushInDb`).
abstract class DeviceTokenStore {
  /// SOL_FIX17: [isCurrent] is re-checked before every write; once it
  /// returns false (logout started meanwhile) the save stops, so a late
  /// upsert never recreates the row that the logout deletes.
  Future<void> saveToken(String token, String platform, {bool Function()? isCurrent});

  /// SOL_FIX19: the signed-in user, read by the logout cleanup at its start.
  String? get currentUserId;

  /// SOL_FIX19: deletes [token]'s row of [userId] – the user captured when
  /// the logout started, never whoever is signed in once the delete runs.
  Future<void> removeToken(String token, {required String userId});
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

  @override
  String? get currentUserId => _userId;

  /// Ionic saveToken: one token per user, one user per token, then upsert.
  @override
  Future<void> saveToken(
    String token,
    String platform, {
    bool Function()? isCurrent,
  }) async {
    bool stale() => isCurrent != null && !isCurrent();
    final userId = _userId;
    // Ionic: "Save Token Error: no authenticated user found" → nothing saved
    if (userId == null) return;
    try {
      if (stale()) return;
      // Remove this token from other users (a token belongs to one user)
      await supabase
          .from('device_tokens')
          .delete()
          .eq('token', token)
          .neq('user_id', userId);

      if (stale()) return;
      // Remove other tokens of this user (one token per user)
      await supabase
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .neq('token', token);

      // SOL_FIX17: last check right before the upsert.
      if (stale()) return;
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
  ///
  /// SOL_FIX18: scoped by the token value AND the signed-in user, so the
  /// logout only ever removes the own account's row of this device. Without
  /// a user (already signed out) RLS would reject it anyway – nothing to do.
  ///
  /// SOL_FIX19: [userId] is the account captured when the logout started
  /// (PushService.removeToken), not the one signed in when this runs.
  @override
  Future<void> removeToken(String token, {required String userId}) async {
    if (userId.isEmpty) return;
    try {
      await supabase
          .from('device_tokens')
          .delete()
          .eq('token', token)
          .eq('user_id', userId);
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
