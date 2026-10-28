// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserNotificationImpl _$$UserNotificationImplFromJson(
  Map<String, dynamic> json,
) => _$UserNotificationImpl(
  id: json['id'] as String,
  userId: json['user_id'] as String?,
  tenantId: (json['tenantId'] as num).toInt(),
  type: json['type'] as String? ?? '',
  title: json['title'] as String? ?? '',
  body: json['body'] as String? ?? '',
  channels:
      (json['channels'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  email: json['email'] as String?,
  data: json['data'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  read: json['read'] as bool? ?? false,
  createdAt:
      json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$UserNotificationImplToJson(
  _$UserNotificationImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'tenantId': instance.tenantId,
  'type': instance.type,
  'title': instance.title,
  'body': instance.body,
  'channels': instance.channels,
  'email': instance.email,
  'data': instance.data,
  'read': instance.read,
  'created_at': instance.createdAt?.toIso8601String(),
};
