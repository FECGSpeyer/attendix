// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessageImpl _$$MessageImplFromJson(Map<String, dynamic> json) =>
    _$MessageImpl(
      id: json['id'] as String,
      tenantId: (json['tenantId'] as num).toInt(),
      senderId: json['sender_id'] as String?,
      senderName: json['sender_name'] as String?,
      title: json['title'] as String? ?? '',
      bodyJson: json['body_json'] as Map<String, dynamic>?,
      bodyHtml: json['body_html'] as String? ?? '',
      bodyText: json['body_text'] as String? ?? '',
      channels:
          (json['channels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      groupIds:
          (json['group_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList(),
      recipientCount: (json['recipient_count'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'sent',
      createdAt:
          json['created_at'] == null
              ? null
              : DateTime.parse(json['created_at'] as String),
      sentAt:
          json['sent_at'] == null
              ? null
              : DateTime.parse(json['sent_at'] as String),
    );

Map<String, dynamic> _$$MessageImplToJson(_$MessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'sender_id': instance.senderId,
      'sender_name': instance.senderName,
      'title': instance.title,
      'body_json': instance.bodyJson,
      'body_html': instance.bodyHtml,
      'body_text': instance.bodyText,
      'channels': instance.channels,
      'group_ids': instance.groupIds,
      'recipient_count': instance.recipientCount,
      'status': instance.status,
      'created_at': instance.createdAt?.toIso8601String(),
      'sent_at': instance.sentAt?.toIso8601String(),
    };

_$MessageRecipientImpl _$$MessageRecipientImplFromJson(
  Map<String, dynamic> json,
) => _$MessageRecipientImpl(
  id: json['id'] as String,
  messageId: json['message_id'] as String,
  tenantId: (json['tenantId'] as num?)?.toInt(),
  playerId: (json['player_id'] as num?)?.toInt(),
  userId: json['user_id'] as String?,
  name: json['name'] as String? ?? '',
  groupId: (json['group_id'] as num?)?.toInt(),
  email: json['email'] as String?,
  pushEnabled: json['push_enabled'] as bool? ?? false,
  pushSentAt:
      json['push_sent_at'] == null
          ? null
          : DateTime.parse(json['push_sent_at'] as String),
  telegramSentAt:
      json['telegram_sent_at'] == null
          ? null
          : DateTime.parse(json['telegram_sent_at'] as String),
  pushFailed: json['push_failed'] as bool? ?? false,
  emailSentAt:
      json['email_sent_at'] == null
          ? null
          : DateTime.parse(json['email_sent_at'] as String),
  emailDeliveredAt:
      json['email_delivered_at'] == null
          ? null
          : DateTime.parse(json['email_delivered_at'] as String),
  emailOpenedAt:
      json['email_opened_at'] == null
          ? null
          : DateTime.parse(json['email_opened_at'] as String),
  emailBouncedAt:
      json['email_bounced_at'] == null
          ? null
          : DateTime.parse(json['email_bounced_at'] as String),
  emailFailed: json['email_failed'] as bool? ?? false,
  readAt:
      json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
);

Map<String, dynamic> _$$MessageRecipientImplToJson(
  _$MessageRecipientImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'message_id': instance.messageId,
  'tenantId': instance.tenantId,
  'player_id': instance.playerId,
  'user_id': instance.userId,
  'name': instance.name,
  'group_id': instance.groupId,
  'email': instance.email,
  'push_enabled': instance.pushEnabled,
  'push_sent_at': instance.pushSentAt?.toIso8601String(),
  'telegram_sent_at': instance.telegramSentAt?.toIso8601String(),
  'push_failed': instance.pushFailed,
  'email_sent_at': instance.emailSentAt?.toIso8601String(),
  'email_delivered_at': instance.emailDeliveredAt?.toIso8601String(),
  'email_opened_at': instance.emailOpenedAt?.toIso8601String(),
  'email_bounced_at': instance.emailBouncedAt?.toIso8601String(),
  'email_failed': instance.emailFailed,
  'read_at': instance.readAt?.toIso8601String(),
};

_$MessageRecipientCountsImpl _$$MessageRecipientCountsImplFromJson(
  Map<String, dynamic> json,
) => _$MessageRecipientCountsImpl(
  recipients: (json['recipients'] as num?)?.toInt() ?? 0,
  push: (json['push'] as num?)?.toInt() ?? 0,
  email: (json['email'] as num?)?.toInt() ?? 0,
  unreachable: (json['unreachable'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$MessageRecipientCountsImplToJson(
  _$MessageRecipientCountsImpl instance,
) => <String, dynamic>{
  'recipients': instance.recipients,
  'push': instance.push,
  'email': instance.email,
  'unreachable': instance.unreachable,
};
