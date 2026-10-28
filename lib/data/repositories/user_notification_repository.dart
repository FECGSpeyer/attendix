import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_notification/user_notification.dart';
import 'base_repository.dart';

/// Provider for UserNotificationRepository
final userNotificationRepositoryProvider = Provider<UserNotificationRepository>((ref) {
  return UserNotificationRepository(ref);
});

/// Repository for the in-app notification feed (table `user_notifications`).
///
/// Port of Ionic `UserNotificationService`. Rows are written server-side by
/// Edge Functions; the client reads them, marks them (un)read and deletes them.
///
/// SECURITY: every query is scoped to the signed-in user (`user_id`) AND a
/// tenant: `.eq('tenantId', currentTenantId)` for the current instance, or
/// `.eq('tenantId', n.tenantId)` / `.inFilter('tenantId', tenantIds)` for the
/// cross-instance ("Alle") view, where [tenantIds] are the user's own tenants.
class UserNotificationRepository extends BaseRepository with TenantAwareRepository {
  UserNotificationRepository(super.ref);

  String get _userId {
    final id = supabase.auth.currentUser?.id;
    if (id == null) {
      throw const RepositoryException(message: 'Not signed in', operation: 'userId');
    }
    return id;
  }

  /// Feed of the current tenant (newest first).
  Future<List<UserNotification>> getNotifications({int limit = 50}) async {
    try {
      final response = await supabase
          .from('user_notifications')
          .select('*')
          .eq('user_id', _userId)
          .eq('tenantId', currentTenantId)
          .order('created_at', ascending: false)
          .limit(limit);
      return _parse(response);
    } catch (e, stack) {
      handleError(e, stack, 'getNotifications');
      rethrow;
    }
  }

  /// Feed across all tenants of the user (newest first), including
  /// instances the user has left (Ionic getAllNotifications).
  /// Cross-tenant by design: the feed rows belong to the user, so this query
  /// is keyed on `user_id` only (RLS: own rows).
  ///
  /// MULTI-TENANT EXCEPTION (CLAUDE.md rule 1, REVIEW_FIX3): no tenantId
  /// filter on purpose. Safe because RLS on `user_notifications` restricts
  /// select/update/delete to `user_id = auth.uid()` (Ionic
  /// supabase/sql/user_notifications.sql "owner can … notifications").
  /// Listed in the allow-list of user_notification_repository_test.dart.
  Future<List<UserNotification>> getAllNotifications({int limit = 50}) async {
    try {
      final response = await supabase
          .from('user_notifications')
          .select('*')
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return _parse(response);
    } catch (e, stack) {
      handleError(e, stack, 'getAllNotifications');
      rethrow;
    }
  }

  /// Unread count of the current tenant (bell badge).
  Future<int> getUnreadCount() async {
    try {
      final response = await supabase
          .from('user_notifications')
          .select('id')
          .eq('user_id', _userId)
          .eq('tenantId', currentTenantId)
          .eq('read', false)
          .count(CountOption.exact);
      return response.count;
    } catch (e, stack) {
      handleError(e, stack, 'getUnreadCount');
      rethrow;
    }
  }

  /// Sets the read flag of one entry (scoped to its own tenant + user).
  Future<void> setRead(UserNotification n, bool read) async {
    try {
      await supabase
          .from('user_notifications')
          .update({'read': read})
          .eq('id', n.id)
          .eq('user_id', _userId)
          .eq('tenantId', n.tenantId);
    } catch (e, stack) {
      handleError(e, stack, 'setRead');
      rethrow;
    }
  }

  /// Deletes one entry (scoped to its own tenant + user).
  Future<void> deleteOne(UserNotification n) async {
    try {
      await supabase
          .from('user_notifications')
          .delete()
          .eq('id', n.id)
          .eq('user_id', _userId)
          .eq('tenantId', n.tenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteOne');
      rethrow;
    }
  }

  /// Marks all unread entries of the current tenant read.
  Future<void> markAllRead() async {
    try {
      await supabase
          .from('user_notifications')
          .update({'read': true})
          .eq('user_id', _userId)
          .eq('tenantId', currentTenantId)
          .eq('read', false);
    } catch (e, stack) {
      handleError(e, stack, 'markAllRead');
      rethrow;
    }
  }

  /// INTEGRATION: marks the unread entries of one Termin read (Ionic
  /// markReadByAttendance, used by the /open-attendance deep link).
  Future<void> markReadByAttendance(int attendanceId) async {
    try {
      await supabase
          .from('user_notifications')
          .update({'read': true})
          .eq('user_id', _userId)
          .eq('tenantId', currentTenantId)
          .eq('read', false)
          .eq('data->>attendanceId', '$attendanceId');
    } catch (e, stack) {
      handleError(e, stack, 'markReadByAttendance');
      rethrow;
    }
  }

  /// Marks all unread entries in all of the user's tenants read.
  /// Cross-tenant by design (Ionic markAllReadAllTenants): keyed on
  /// `user_id` only, so rows of left instances are included.
  ///
  /// MULTI-TENANT EXCEPTION (CLAUDE.md rule 1, REVIEW_FIX3): no tenantId
  /// filter on purpose. Safe because RLS on `user_notifications` restricts
  /// select/update/delete to `user_id = auth.uid()` (Ionic
  /// supabase/sql/user_notifications.sql "owner can … notifications").
  /// Listed in the allow-list of user_notification_repository_test.dart.
  Future<void> markAllReadAllTenants() async {
    try {
      await supabase
          .from('user_notifications')
          .update({'read': true})
          .eq('user_id', _userId)
          .eq('read', false);
    } catch (e, stack) {
      handleError(e, stack, 'markAllReadAllTenants');
      rethrow;
    }
  }

  /// Deletes all entries of the current tenant.
  Future<void> deleteAll() async {
    try {
      await supabase
          .from('user_notifications')
          .delete()
          .eq('user_id', _userId)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteAll');
      rethrow;
    }
  }

  /// Deletes all entries in all of the user's tenants.
  /// Cross-tenant by design (Ionic deleteAllAllTenants): keyed on
  /// `user_id` only, so rows of left instances are included.
  ///
  /// MULTI-TENANT EXCEPTION (CLAUDE.md rule 1, REVIEW_FIX3): no tenantId
  /// filter on purpose. Safe because RLS on `user_notifications` restricts
  /// select/update/delete to `user_id = auth.uid()` (Ionic
  /// supabase/sql/user_notifications.sql "owner can … notifications").
  /// Listed in the allow-list of user_notification_repository_test.dart.
  Future<void> deleteAllAllTenants() async {
    try {
      await supabase
          .from('user_notifications')
          .delete()
          .eq('user_id', _userId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteAllAllTenants');
      rethrow;
    }
  }

  List<UserNotification> _parse(dynamic response) =>
      (response as List).map((e) => UserNotification.fromJson(e as Map<String, dynamic>)).toList();
}
