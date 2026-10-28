import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message/message.dart';
import 'base_repository.dart';

/// Provider for MessageRepository
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref);
});

/// Repository for Mitteilungen (tables `messages` / `message_recipients`).
///
/// Port of Ionic `MessageService`. Sending and all delivery tracking happen in
/// the `send-message` / `resend-webhook` Edge Functions; the client reads
/// messages and recipient rows (RLS limits members to their own copy), deletes
/// whole messages (admins) and marks its own copy read.
///
/// SECURITY: every table query filters `.eq('tenantId', currentTenantId)` –
/// both tables carry a tenantId column.
class MessageRepository extends BaseRepository with TenantAwareRepository {
  MessageRepository(super.ref);

  static const _listColumns =
      'id, tenantId, sender_id, sender_name, title, body_text, channels, '
      'group_ids, recipient_count, status, created_at, sent_at';

  String? get _currentUserId => supabase.auth.currentUser?.id;

  /// All messages of the current tenant (newest first, max. 100).
  Future<List<Message>> getMessages() async {
    try {
      final response = await supabase
          .from('messages')
          .select(_listColumns)
          .eq('tenantId', currentTenantId)
          .order('created_at', ascending: false)
          .limit(100);

      return (response as List).map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e, stack) {
      handleError(e, stack, 'getMessages');
      rethrow;
    }
  }

  /// A single message of the current tenant, or null if not visible.
  Future<Message?> getMessageById(String id, {Iterable<int> userTenantIds = const []}) async {
    // Ionic message-detail: push/email links may point to another instance
    // of the user, so the message is looked up in all of the user's tenants
    // (always including the current one) and the page switches to it.
    final tenantIds = {currentTenantId, ...userTenantIds}.toList();
    try {
      final response =
          await supabase
              .from('messages')
              .select('*')
              .eq('id', id)
              .inFilter('tenantId', tenantIds)
              .maybeSingle();

      if (response == null) return null;
      return Message.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getMessageById');
      rethrow;
    }
  }

  /// Recipient rows of one message. Admins get all rows, members only their own (RLS).
  Future<List<MessageRecipient>> getRecipients(String messageId) async {
    try {
      final response = await supabase
          .from('message_recipients')
          .select('*')
          .eq('message_id', messageId)
          .eq('tenantId', currentTenantId)
          .order('name', ascending: true)
          .range(0, 4999);

      return (response as List)
          .map((e) => MessageRecipient.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getRecipients');
      rethrow;
    }
  }

  /// Read/problem counts per message for the list page (aggregated client-side).
  Future<Map<String, MessageStats>> getStats(List<String> messageIds) async {
    if (messageIds.isEmpty) return {};
    try {
      final response = await supabase
          .from('message_recipients')
          .select('message_id, read_at, email_opened_at, push_failed, email_failed')
          .inFilter('message_id', messageIds)
          .eq('tenantId', currentTenantId)
          .range(0, 49999);

      return aggregateStats((response as List).cast<Map<String, dynamic>>());
    } catch (e, stack) {
      handleError(e, stack, 'getStats');
      rethrow;
    }
  }

  /// Pure aggregation helper (exposed for tests).
  static Map<String, MessageStats> aggregateStats(List<Map<String, dynamic>> rows) {
    final read = <String, int>{};
    final problems = <String, int>{};
    for (final row in rows) {
      final id = row['message_id'] as String;
      read.putIfAbsent(id, () => 0);
      problems.putIfAbsent(id, () => 0);
      if (row['read_at'] != null || row['email_opened_at'] != null) {
        read[id] = read[id]! + 1;
      }
      if (row['push_failed'] == true || row['email_failed'] == true) {
        problems[id] = problems[id]! + 1;
      }
    }
    return {for (final id in read.keys) id: MessageStats(read: read[id]!, problems: problems[id]!)};
  }

  /// Messages the current user received in the current tenant (newest first).
  Future<List<Message>> getReceivedMessages({int limit = 20}) async {
    final userId = _currentUserId;
    if (userId == null) return [];
    try {
      final rows = await supabase
          .from('message_recipients')
          .select('message_id')
          .eq('user_id', userId)
          .eq('tenantId', currentTenantId)
          .order('created_at', ascending: false)
          .limit(limit);

      final ids =
          (rows as List).map((r) => (r as Map<String, dynamic>)['message_id'] as String).toList();
      if (ids.isEmpty) return [];

      final response = await supabase
          .from('messages')
          .select('id, tenantId, title, sender_name, created_at')
          .inFilter('id', ids)
          .eq('tenantId', currentTenantId)
          .order('created_at', ascending: false);

      return (response as List).map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e, stack) {
      handleError(e, stack, 'getReceivedMessages');
      rethrow;
    }
  }

  /// Recipient counts for the compose screen (send-message dry run).
  Future<MessageRecipientCounts> getRecipientCounts({
    required List<int>? groupIds,
    required bool push,
    required bool email,
  }) async {
    try {
      final response = await supabase.functions.invoke(
        'send-message',
        body: {
          'tenantId': currentTenantId,
          'groupIds': groupIds,
          'channels': {'push': push, 'email': email},
          'dryRun': true,
        },
      );
      return MessageRecipientCounts.fromJson(Map<String, dynamic>.from(response.data as Map));
    } catch (e, stack) {
      handleError(e, stack, 'getRecipientCounts');
      rethrow;
    }
  }

  /// Sends a message via the send-message Edge Function. Returns the new message id.
  ///
  /// [content] is a Tiptap document (`{type: 'doc', content: [...]}`); the
  /// server renders the allowlisted HTML/plain text from it.
  Future<String> send({
    required String title,
    required Map<String, dynamic> content,
    required List<int>? groupIds,
    required bool push,
    required bool email,
  }) async {
    try {
      final response = await supabase.functions.invoke(
        'send-message',
        body: {
          'tenantId': currentTenantId,
          'title': title,
          'content': content,
          'groupIds': groupIds,
          'channels': {'push': push, 'email': email},
        },
      );
      final data = response.data;
      final messageId = data is Map ? data['messageId'] as String? : null;
      if (messageId == null) {
        throw const RepositoryException(message: 'send-message failed', operation: 'send');
      }
      return messageId;
    } catch (e, stack) {
      handleError(e, stack, 'send');
      rethrow;
    }
  }

  /// Marks the caller's copy read. The RPC is scoped server-side to
  /// auth.uid() (security definer), so no tenant parameter is needed.
  Future<void> markRead(String messageId) async {
    try {
      await supabase.rpc('mark_message_read', params: {'p_message_id': messageId});
    } catch (e, stack) {
      handleError(e, stack, 'markRead');
      rethrow;
    }
  }

  /// Deletes a whole message (admins/responsibles; recipients cascade).
  Future<void> deleteMessage(String messageId) async {
    try {
      await supabase.from('messages').delete().eq('id', messageId).eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteMessage');
      rethrow;
    }
  }
}
