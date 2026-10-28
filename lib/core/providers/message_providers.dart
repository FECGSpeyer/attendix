import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/message/message.dart';
import '../../data/models/user_notification/user_notification.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/repositories/user_notification_repository.dart';
import '../config/supabase_config.dart';
import 'tenant_providers.dart';

// ---------------------------------------------------------------------------
// Mitteilungen (messages)
// ---------------------------------------------------------------------------

/// Message repository with tenant context
final messageRepositoryWithTenantProvider = Provider<MessageRepository>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId != null) repo.setTenantId(tenantId);
  return repo;
});

/// All sent messages of the current tenant with read/problem stats (admin list).
final messagesProvider = FutureProvider.autoDispose<List<MessageWithStats>>((ref) async {
  final repo = ref.watch(messageRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];

  final messages = await repo.getMessages();
  final stats = await repo.getStats(messages.map((m) => m.id).toList());
  return messages
      .map((m) => MessageWithStats(message: m, stats: stats[m.id] ?? const MessageStats()))
      .toList();
});

/// Single message by id (current tenant only).
final messageByIdProvider = FutureProvider.autoDispose.family<Message?, String>((ref, id) async {
  final repo = ref.watch(messageRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  return repo.getMessageById(id);
});

/// Recipient rows of a message (admins: all, members: own row).
final messageRecipientsProvider = FutureProvider.autoDispose.family<List<MessageRecipient>, String>(
  (ref, id) async {
    final repo = ref.watch(messageRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return [];
    return repo.getRecipients(id);
  },
);

/// Messages the current user received in the current tenant ("Frühere Mitteilungen").
final receivedMessagesProvider = FutureProvider.autoDispose<List<Message>>((ref) async {
  final repo = ref.watch(messageRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getReceivedMessages(limit: 6);
});

/// Mutations for messages
class MessageNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  MessageRepository get _repo => ref.read(messageRepositoryWithTenantProvider);

  /// Sends a message and returns its id (null on error, see [state]).
  Future<String?> send({
    required String title,
    required Map<String, dynamic> content,
    required List<int>? groupIds,
    required bool push,
    required bool email,
  }) async {
    state = const AsyncValue.loading();
    try {
      final id = await _repo.send(
        title: title,
        content: content,
        groupIds: groupIds,
        push: push,
        email: email,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(messagesProvider);
      return id;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<bool> delete(String messageId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteMessage(messageId);
      state = const AsyncValue.data(null);
      ref.invalidate(messagesProvider);
      ref.invalidate(messageByIdProvider(messageId));
      ref.invalidate(userNotificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Marks the user's copy read; failures are ignored (as in Ionic).
  Future<void> markRead(String messageId) async {
    try {
      await _repo.markRead(messageId);
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(userNotificationsProvider);
    } catch (_) {
      // Non-critical.
    }
  }
}

final messageNotifierProvider = NotifierProvider<MessageNotifier, AsyncValue<void>>(
  MessageNotifier.new,
);

// ---------------------------------------------------------------------------
// In-app notification feed (user_notifications)
// ---------------------------------------------------------------------------

/// User notification repository with tenant context
final userNotificationRepositoryWithTenantProvider = Provider<UserNotificationRepository>((ref) {
  final repo = ref.watch(userNotificationRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId != null) repo.setTenantId(tenantId);
  return repo;
});

/// Ids of all tenants the user belongs to (for the "Alle" feed).
final _userTenantIdsProvider = FutureProvider<List<int>>((ref) async {
  final tenants = await ref.watch(userTenantsProvider.future);
  return tenants.map((t) => t.id).whereType<int>().toList();
});

/// Notification feed. `allTenants == false`: current instance only.
final userNotificationsProvider = FutureProvider.autoDispose.family<List<UserNotification>, bool>((
  ref,
  allTenants,
) async {
  final repo = ref.watch(userNotificationRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  if (allTenants) {
    final tenantIds = await ref.watch(_userTenantIdsProvider.future);
    return repo.getAllNotifications(tenantIds);
  }
  return repo.getNotifications();
});

/// Unread count of the current tenant (bell badge).
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(userNotificationRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return 0;
  try {
    return await repo.getUnreadCount();
  } catch (_) {
    return 0; // the badge is non-critical (table may be missing on old DBs)
  }
});

/// Realtime subscription on the user's feed; refreshes badge + lists on change.
/// Watched by the notification bell while it is mounted.
final userNotificationsRealtimeProvider = Provider.autoDispose<void>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null || tenantId == null) return;

  final channel =
      supabase
          .channel('user-notif-$userId-${DateTime.now().microsecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) {
              ref.invalidate(unreadNotificationCountProvider);
              ref.invalidate(userNotificationsProvider);
            },
          )
          .subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
  });
});

/// Mutations for the notification feed
class UserNotificationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  UserNotificationRepository get _repo => ref.read(userNotificationRepositoryWithTenantProvider);

  void _refresh() {
    ref.invalidate(userNotificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    } finally {
      _refresh();
    }
  }

  Future<void> setRead(UserNotification n, bool read) => _run(() => _repo.setRead(n, read));

  Future<void> deleteOne(UserNotification n) => _run(() => _repo.deleteOne(n));

  Future<void> markAllRead({required bool allTenants}) => _run(() async {
    if (allTenants) {
      await _repo.markAllReadAllTenants(await ref.read(_userTenantIdsProvider.future));
    } else {
      await _repo.markAllRead();
    }
  });

  Future<void> deleteAll({required bool allTenants}) => _run(() async {
    if (allTenants) {
      await _repo.deleteAllAllTenants(await ref.read(_userTenantIdsProvider.future));
    } else {
      await _repo.deleteAll();
    }
  });
}

final userNotificationNotifierProvider =
    NotifierProvider<UserNotificationNotifier, AsyncValue<void>>(UserNotificationNotifier.new);
