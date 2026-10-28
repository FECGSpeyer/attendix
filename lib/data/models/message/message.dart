import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// Mitteilung - a general message sent by tenant admins/responsibles to the
/// members of a tenant (table `messages`, see Ionic supabase/sql/add_messages.sql).
///
/// Rows are created exclusively by the `send-message` Edge Function. Clients
/// only read them, delete them (admins) and mark their own copy read.
@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required int tenantId,
    @JsonKey(name: 'sender_id') String? senderId,
    @JsonKey(name: 'sender_name') String? senderName,
    @Default('') String title,
    @JsonKey(name: 'body_json') Map<String, dynamic>? bodyJson,
    @JsonKey(name: 'body_html') @Default('') String bodyHtml,
    @JsonKey(name: 'body_text') @Default('') String bodyText,
    @Default(<String>[]) List<String> channels,
    @JsonKey(name: 'group_ids') List<int>? groupIds,
    @JsonKey(name: 'recipient_count') @Default(0) int recipientCount,
    @Default('sent') String status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'sent_at') DateTime? sentAt,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}

extension MessageX on Message {
  bool get isSending => status == 'sending';
}

/// Per-recipient delivery/read state of a message (table `message_recipients`).
@freezed
class MessageRecipient with _$MessageRecipient {
  const factory MessageRecipient({
    required String id,
    @JsonKey(name: 'message_id') required String messageId,
    int? tenantId,
    @JsonKey(name: 'player_id') int? playerId,
    @JsonKey(name: 'user_id') String? userId,
    @Default('') String name,
    @JsonKey(name: 'group_id') int? groupId,
    String? email,
    @JsonKey(name: 'push_enabled') @Default(false) bool pushEnabled,
    @JsonKey(name: 'push_sent_at') DateTime? pushSentAt,
    @JsonKey(name: 'telegram_sent_at') DateTime? telegramSentAt,
    @JsonKey(name: 'push_failed') @Default(false) bool pushFailed,
    @JsonKey(name: 'email_sent_at') DateTime? emailSentAt,
    @JsonKey(name: 'email_delivered_at') DateTime? emailDeliveredAt,
    @JsonKey(name: 'email_opened_at') DateTime? emailOpenedAt,
    @JsonKey(name: 'email_bounced_at') DateTime? emailBouncedAt,
    @JsonKey(name: 'email_failed') @Default(false) bool emailFailed,
    @JsonKey(name: 'read_at') DateTime? readAt,
  }) = _MessageRecipient;

  factory MessageRecipient.fromJson(Map<String, dynamic> json) => _$MessageRecipientFromJson(json);
}

extension MessageRecipientX on MessageRecipient {
  /// Read in the app or (approximately) opened by email.
  bool get isRead => readAt != null || emailOpenedAt != null;

  /// Neither push/Telegram nor email reached this person.
  bool get isUnreachable => !pushEnabled && email == null;

  bool get hasProblem => pushFailed || emailFailed || isUnreachable;
}

/// Recipient counts returned by the `send-message` dry run.
@freezed
class MessageRecipientCounts with _$MessageRecipientCounts {
  const factory MessageRecipientCounts({
    @Default(0) int recipients,
    @Default(0) int push,
    @Default(0) int email,
    @Default(0) int unreachable,
  }) = _MessageRecipientCounts;

  factory MessageRecipientCounts.fromJson(Map<String, dynamic> json) =>
      _$MessageRecipientCountsFromJson(json);
}

/// Read / problem counts of one message, aggregated for the list page.
class MessageStats {
  const MessageStats({this.read = 0, this.problems = 0});

  final int read;
  final int problems;
}

/// A sent message together with its aggregated read/problem stats.
class MessageWithStats {
  const MessageWithStats({required this.message, this.stats = const MessageStats()});

  final Message message;
  final MessageStats stats;

  int get readPercent =>
      message.recipientCount > 0 ? ((stats.read / message.recipientCount) * 100).round() : 0;
}
