// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Message _$MessageFromJson(Map<String, dynamic> json) {
  return _Message.fromJson(json);
}

/// @nodoc
mixin _$Message {
  String get id => throw _privateConstructorUsedError;
  int get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'sender_id')
  String? get senderId => throw _privateConstructorUsedError;
  @JsonKey(name: 'sender_name')
  String? get senderName => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  @JsonKey(name: 'body_json')
  Map<String, dynamic>? get bodyJson => throw _privateConstructorUsedError;
  @JsonKey(name: 'body_html')
  String get bodyHtml => throw _privateConstructorUsedError;
  @JsonKey(name: 'body_text')
  String get bodyText => throw _privateConstructorUsedError;
  List<String> get channels => throw _privateConstructorUsedError;
  @JsonKey(name: 'group_ids')
  List<int>? get groupIds => throw _privateConstructorUsedError;
  @JsonKey(name: 'recipient_count')
  int get recipientCount => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'sent_at')
  DateTime? get sentAt => throw _privateConstructorUsedError;

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessageCopyWith<Message> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageCopyWith<$Res> {
  factory $MessageCopyWith(Message value, $Res Function(Message) then) =
      _$MessageCopyWithImpl<$Res, Message>;
  @useResult
  $Res call({
    String id,
    int tenantId,
    @JsonKey(name: 'sender_id') String? senderId,
    @JsonKey(name: 'sender_name') String? senderName,
    String title,
    @JsonKey(name: 'body_json') Map<String, dynamic>? bodyJson,
    @JsonKey(name: 'body_html') String bodyHtml,
    @JsonKey(name: 'body_text') String bodyText,
    List<String> channels,
    @JsonKey(name: 'group_ids') List<int>? groupIds,
    @JsonKey(name: 'recipient_count') int recipientCount,
    String status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'sent_at') DateTime? sentAt,
  });
}

/// @nodoc
class _$MessageCopyWithImpl<$Res, $Val extends Message>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? senderId = freezed,
    Object? senderName = freezed,
    Object? title = null,
    Object? bodyJson = freezed,
    Object? bodyHtml = null,
    Object? bodyText = null,
    Object? channels = null,
    Object? groupIds = freezed,
    Object? recipientCount = null,
    Object? status = null,
    Object? createdAt = freezed,
    Object? sentAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            tenantId:
                null == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int,
            senderId:
                freezed == senderId
                    ? _value.senderId
                    : senderId // ignore: cast_nullable_to_non_nullable
                        as String?,
            senderName:
                freezed == senderName
                    ? _value.senderName
                    : senderName // ignore: cast_nullable_to_non_nullable
                        as String?,
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            bodyJson:
                freezed == bodyJson
                    ? _value.bodyJson
                    : bodyJson // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
            bodyHtml:
                null == bodyHtml
                    ? _value.bodyHtml
                    : bodyHtml // ignore: cast_nullable_to_non_nullable
                        as String,
            bodyText:
                null == bodyText
                    ? _value.bodyText
                    : bodyText // ignore: cast_nullable_to_non_nullable
                        as String,
            channels:
                null == channels
                    ? _value.channels
                    : channels // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            groupIds:
                freezed == groupIds
                    ? _value.groupIds
                    : groupIds // ignore: cast_nullable_to_non_nullable
                        as List<int>?,
            recipientCount:
                null == recipientCount
                    ? _value.recipientCount
                    : recipientCount // ignore: cast_nullable_to_non_nullable
                        as int,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as String,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            sentAt:
                freezed == sentAt
                    ? _value.sentAt
                    : sentAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MessageImplCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$$MessageImplCopyWith(
    _$MessageImpl value,
    $Res Function(_$MessageImpl) then,
  ) = __$$MessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    int tenantId,
    @JsonKey(name: 'sender_id') String? senderId,
    @JsonKey(name: 'sender_name') String? senderName,
    String title,
    @JsonKey(name: 'body_json') Map<String, dynamic>? bodyJson,
    @JsonKey(name: 'body_html') String bodyHtml,
    @JsonKey(name: 'body_text') String bodyText,
    List<String> channels,
    @JsonKey(name: 'group_ids') List<int>? groupIds,
    @JsonKey(name: 'recipient_count') int recipientCount,
    String status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'sent_at') DateTime? sentAt,
  });
}

/// @nodoc
class __$$MessageImplCopyWithImpl<$Res>
    extends _$MessageCopyWithImpl<$Res, _$MessageImpl>
    implements _$$MessageImplCopyWith<$Res> {
  __$$MessageImplCopyWithImpl(
    _$MessageImpl _value,
    $Res Function(_$MessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? senderId = freezed,
    Object? senderName = freezed,
    Object? title = null,
    Object? bodyJson = freezed,
    Object? bodyHtml = null,
    Object? bodyText = null,
    Object? channels = null,
    Object? groupIds = freezed,
    Object? recipientCount = null,
    Object? status = null,
    Object? createdAt = freezed,
    Object? sentAt = freezed,
  }) {
    return _then(
      _$MessageImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        tenantId:
            null == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int,
        senderId:
            freezed == senderId
                ? _value.senderId
                : senderId // ignore: cast_nullable_to_non_nullable
                    as String?,
        senderName:
            freezed == senderName
                ? _value.senderName
                : senderName // ignore: cast_nullable_to_non_nullable
                    as String?,
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        bodyJson:
            freezed == bodyJson
                ? _value._bodyJson
                : bodyJson // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
        bodyHtml:
            null == bodyHtml
                ? _value.bodyHtml
                : bodyHtml // ignore: cast_nullable_to_non_nullable
                    as String,
        bodyText:
            null == bodyText
                ? _value.bodyText
                : bodyText // ignore: cast_nullable_to_non_nullable
                    as String,
        channels:
            null == channels
                ? _value._channels
                : channels // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        groupIds:
            freezed == groupIds
                ? _value._groupIds
                : groupIds // ignore: cast_nullable_to_non_nullable
                    as List<int>?,
        recipientCount:
            null == recipientCount
                ? _value.recipientCount
                : recipientCount // ignore: cast_nullable_to_non_nullable
                    as int,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as String,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        sentAt:
            freezed == sentAt
                ? _value.sentAt
                : sentAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MessageImpl implements _Message {
  const _$MessageImpl({
    required this.id,
    required this.tenantId,
    @JsonKey(name: 'sender_id') this.senderId,
    @JsonKey(name: 'sender_name') this.senderName,
    this.title = '',
    @JsonKey(name: 'body_json') final Map<String, dynamic>? bodyJson,
    @JsonKey(name: 'body_html') this.bodyHtml = '',
    @JsonKey(name: 'body_text') this.bodyText = '',
    final List<String> channels = const <String>[],
    @JsonKey(name: 'group_ids') final List<int>? groupIds,
    @JsonKey(name: 'recipient_count') this.recipientCount = 0,
    this.status = 'sent',
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'sent_at') this.sentAt,
  }) : _bodyJson = bodyJson,
       _channels = channels,
       _groupIds = groupIds;

  factory _$MessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessageImplFromJson(json);

  @override
  final String id;
  @override
  final int tenantId;
  @override
  @JsonKey(name: 'sender_id')
  final String? senderId;
  @override
  @JsonKey(name: 'sender_name')
  final String? senderName;
  @override
  @JsonKey()
  final String title;
  final Map<String, dynamic>? _bodyJson;
  @override
  @JsonKey(name: 'body_json')
  Map<String, dynamic>? get bodyJson {
    final value = _bodyJson;
    if (value == null) return null;
    if (_bodyJson is EqualUnmodifiableMapView) return _bodyJson;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'body_html')
  final String bodyHtml;
  @override
  @JsonKey(name: 'body_text')
  final String bodyText;
  final List<String> _channels;
  @override
  @JsonKey()
  List<String> get channels {
    if (_channels is EqualUnmodifiableListView) return _channels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_channels);
  }

  final List<int>? _groupIds;
  @override
  @JsonKey(name: 'group_ids')
  List<int>? get groupIds {
    final value = _groupIds;
    if (value == null) return null;
    if (_groupIds is EqualUnmodifiableListView) return _groupIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'recipient_count')
  final int recipientCount;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'sent_at')
  final DateTime? sentAt;

  @override
  String toString() {
    return 'Message(id: $id, tenantId: $tenantId, senderId: $senderId, senderName: $senderName, title: $title, bodyJson: $bodyJson, bodyHtml: $bodyHtml, bodyText: $bodyText, channels: $channels, groupIds: $groupIds, recipientCount: $recipientCount, status: $status, createdAt: $createdAt, sentAt: $sentAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName) &&
            (identical(other.title, title) || other.title == title) &&
            const DeepCollectionEquality().equals(other._bodyJson, _bodyJson) &&
            (identical(other.bodyHtml, bodyHtml) ||
                other.bodyHtml == bodyHtml) &&
            (identical(other.bodyText, bodyText) ||
                other.bodyText == bodyText) &&
            const DeepCollectionEquality().equals(other._channels, _channels) &&
            const DeepCollectionEquality().equals(other._groupIds, _groupIds) &&
            (identical(other.recipientCount, recipientCount) ||
                other.recipientCount == recipientCount) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.sentAt, sentAt) || other.sentAt == sentAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tenantId,
    senderId,
    senderName,
    title,
    const DeepCollectionEquality().hash(_bodyJson),
    bodyHtml,
    bodyText,
    const DeepCollectionEquality().hash(_channels),
    const DeepCollectionEquality().hash(_groupIds),
    recipientCount,
    status,
    createdAt,
    sentAt,
  );

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageImplCopyWith<_$MessageImpl> get copyWith =>
      __$$MessageImplCopyWithImpl<_$MessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MessageImplToJson(this);
  }
}

abstract class _Message implements Message {
  const factory _Message({
    required final String id,
    required final int tenantId,
    @JsonKey(name: 'sender_id') final String? senderId,
    @JsonKey(name: 'sender_name') final String? senderName,
    final String title,
    @JsonKey(name: 'body_json') final Map<String, dynamic>? bodyJson,
    @JsonKey(name: 'body_html') final String bodyHtml,
    @JsonKey(name: 'body_text') final String bodyText,
    final List<String> channels,
    @JsonKey(name: 'group_ids') final List<int>? groupIds,
    @JsonKey(name: 'recipient_count') final int recipientCount,
    final String status,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'sent_at') final DateTime? sentAt,
  }) = _$MessageImpl;

  factory _Message.fromJson(Map<String, dynamic> json) = _$MessageImpl.fromJson;

  @override
  String get id;
  @override
  int get tenantId;
  @override
  @JsonKey(name: 'sender_id')
  String? get senderId;
  @override
  @JsonKey(name: 'sender_name')
  String? get senderName;
  @override
  String get title;
  @override
  @JsonKey(name: 'body_json')
  Map<String, dynamic>? get bodyJson;
  @override
  @JsonKey(name: 'body_html')
  String get bodyHtml;
  @override
  @JsonKey(name: 'body_text')
  String get bodyText;
  @override
  List<String> get channels;
  @override
  @JsonKey(name: 'group_ids')
  List<int>? get groupIds;
  @override
  @JsonKey(name: 'recipient_count')
  int get recipientCount;
  @override
  String get status;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'sent_at')
  DateTime? get sentAt;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageImplCopyWith<_$MessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MessageRecipient _$MessageRecipientFromJson(Map<String, dynamic> json) {
  return _MessageRecipient.fromJson(json);
}

/// @nodoc
mixin _$MessageRecipient {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'message_id')
  String get messageId => throw _privateConstructorUsedError;
  int? get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'player_id')
  int? get playerId => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String? get userId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'group_id')
  int? get groupId => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  @JsonKey(name: 'push_enabled')
  bool get pushEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'push_sent_at')
  DateTime? get pushSentAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'telegram_sent_at')
  DateTime? get telegramSentAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'push_failed')
  bool get pushFailed => throw _privateConstructorUsedError;
  @JsonKey(name: 'email_sent_at')
  DateTime? get emailSentAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'email_delivered_at')
  DateTime? get emailDeliveredAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'email_opened_at')
  DateTime? get emailOpenedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'email_bounced_at')
  DateTime? get emailBouncedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'email_failed')
  bool get emailFailed => throw _privateConstructorUsedError;
  @JsonKey(name: 'read_at')
  DateTime? get readAt => throw _privateConstructorUsedError;

  /// Serializes this MessageRecipient to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MessageRecipient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessageRecipientCopyWith<MessageRecipient> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageRecipientCopyWith<$Res> {
  factory $MessageRecipientCopyWith(
    MessageRecipient value,
    $Res Function(MessageRecipient) then,
  ) = _$MessageRecipientCopyWithImpl<$Res, MessageRecipient>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'message_id') String messageId,
    int? tenantId,
    @JsonKey(name: 'player_id') int? playerId,
    @JsonKey(name: 'user_id') String? userId,
    String name,
    @JsonKey(name: 'group_id') int? groupId,
    String? email,
    @JsonKey(name: 'push_enabled') bool pushEnabled,
    @JsonKey(name: 'push_sent_at') DateTime? pushSentAt,
    @JsonKey(name: 'telegram_sent_at') DateTime? telegramSentAt,
    @JsonKey(name: 'push_failed') bool pushFailed,
    @JsonKey(name: 'email_sent_at') DateTime? emailSentAt,
    @JsonKey(name: 'email_delivered_at') DateTime? emailDeliveredAt,
    @JsonKey(name: 'email_opened_at') DateTime? emailOpenedAt,
    @JsonKey(name: 'email_bounced_at') DateTime? emailBouncedAt,
    @JsonKey(name: 'email_failed') bool emailFailed,
    @JsonKey(name: 'read_at') DateTime? readAt,
  });
}

/// @nodoc
class _$MessageRecipientCopyWithImpl<$Res, $Val extends MessageRecipient>
    implements $MessageRecipientCopyWith<$Res> {
  _$MessageRecipientCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MessageRecipient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? messageId = null,
    Object? tenantId = freezed,
    Object? playerId = freezed,
    Object? userId = freezed,
    Object? name = null,
    Object? groupId = freezed,
    Object? email = freezed,
    Object? pushEnabled = null,
    Object? pushSentAt = freezed,
    Object? telegramSentAt = freezed,
    Object? pushFailed = null,
    Object? emailSentAt = freezed,
    Object? emailDeliveredAt = freezed,
    Object? emailOpenedAt = freezed,
    Object? emailBouncedAt = freezed,
    Object? emailFailed = null,
    Object? readAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            messageId:
                null == messageId
                    ? _value.messageId
                    : messageId // ignore: cast_nullable_to_non_nullable
                        as String,
            tenantId:
                freezed == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int?,
            playerId:
                freezed == playerId
                    ? _value.playerId
                    : playerId // ignore: cast_nullable_to_non_nullable
                        as int?,
            userId:
                freezed == userId
                    ? _value.userId
                    : userId // ignore: cast_nullable_to_non_nullable
                        as String?,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            groupId:
                freezed == groupId
                    ? _value.groupId
                    : groupId // ignore: cast_nullable_to_non_nullable
                        as int?,
            email:
                freezed == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as String?,
            pushEnabled:
                null == pushEnabled
                    ? _value.pushEnabled
                    : pushEnabled // ignore: cast_nullable_to_non_nullable
                        as bool,
            pushSentAt:
                freezed == pushSentAt
                    ? _value.pushSentAt
                    : pushSentAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            telegramSentAt:
                freezed == telegramSentAt
                    ? _value.telegramSentAt
                    : telegramSentAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            pushFailed:
                null == pushFailed
                    ? _value.pushFailed
                    : pushFailed // ignore: cast_nullable_to_non_nullable
                        as bool,
            emailSentAt:
                freezed == emailSentAt
                    ? _value.emailSentAt
                    : emailSentAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            emailDeliveredAt:
                freezed == emailDeliveredAt
                    ? _value.emailDeliveredAt
                    : emailDeliveredAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            emailOpenedAt:
                freezed == emailOpenedAt
                    ? _value.emailOpenedAt
                    : emailOpenedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            emailBouncedAt:
                freezed == emailBouncedAt
                    ? _value.emailBouncedAt
                    : emailBouncedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            emailFailed:
                null == emailFailed
                    ? _value.emailFailed
                    : emailFailed // ignore: cast_nullable_to_non_nullable
                        as bool,
            readAt:
                freezed == readAt
                    ? _value.readAt
                    : readAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MessageRecipientImplCopyWith<$Res>
    implements $MessageRecipientCopyWith<$Res> {
  factory _$$MessageRecipientImplCopyWith(
    _$MessageRecipientImpl value,
    $Res Function(_$MessageRecipientImpl) then,
  ) = __$$MessageRecipientImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'message_id') String messageId,
    int? tenantId,
    @JsonKey(name: 'player_id') int? playerId,
    @JsonKey(name: 'user_id') String? userId,
    String name,
    @JsonKey(name: 'group_id') int? groupId,
    String? email,
    @JsonKey(name: 'push_enabled') bool pushEnabled,
    @JsonKey(name: 'push_sent_at') DateTime? pushSentAt,
    @JsonKey(name: 'telegram_sent_at') DateTime? telegramSentAt,
    @JsonKey(name: 'push_failed') bool pushFailed,
    @JsonKey(name: 'email_sent_at') DateTime? emailSentAt,
    @JsonKey(name: 'email_delivered_at') DateTime? emailDeliveredAt,
    @JsonKey(name: 'email_opened_at') DateTime? emailOpenedAt,
    @JsonKey(name: 'email_bounced_at') DateTime? emailBouncedAt,
    @JsonKey(name: 'email_failed') bool emailFailed,
    @JsonKey(name: 'read_at') DateTime? readAt,
  });
}

/// @nodoc
class __$$MessageRecipientImplCopyWithImpl<$Res>
    extends _$MessageRecipientCopyWithImpl<$Res, _$MessageRecipientImpl>
    implements _$$MessageRecipientImplCopyWith<$Res> {
  __$$MessageRecipientImplCopyWithImpl(
    _$MessageRecipientImpl _value,
    $Res Function(_$MessageRecipientImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageRecipient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? messageId = null,
    Object? tenantId = freezed,
    Object? playerId = freezed,
    Object? userId = freezed,
    Object? name = null,
    Object? groupId = freezed,
    Object? email = freezed,
    Object? pushEnabled = null,
    Object? pushSentAt = freezed,
    Object? telegramSentAt = freezed,
    Object? pushFailed = null,
    Object? emailSentAt = freezed,
    Object? emailDeliveredAt = freezed,
    Object? emailOpenedAt = freezed,
    Object? emailBouncedAt = freezed,
    Object? emailFailed = null,
    Object? readAt = freezed,
  }) {
    return _then(
      _$MessageRecipientImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        messageId:
            null == messageId
                ? _value.messageId
                : messageId // ignore: cast_nullable_to_non_nullable
                    as String,
        tenantId:
            freezed == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int?,
        playerId:
            freezed == playerId
                ? _value.playerId
                : playerId // ignore: cast_nullable_to_non_nullable
                    as int?,
        userId:
            freezed == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                    as String?,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        groupId:
            freezed == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                    as int?,
        email:
            freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as String?,
        pushEnabled:
            null == pushEnabled
                ? _value.pushEnabled
                : pushEnabled // ignore: cast_nullable_to_non_nullable
                    as bool,
        pushSentAt:
            freezed == pushSentAt
                ? _value.pushSentAt
                : pushSentAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        telegramSentAt:
            freezed == telegramSentAt
                ? _value.telegramSentAt
                : telegramSentAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        pushFailed:
            null == pushFailed
                ? _value.pushFailed
                : pushFailed // ignore: cast_nullable_to_non_nullable
                    as bool,
        emailSentAt:
            freezed == emailSentAt
                ? _value.emailSentAt
                : emailSentAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        emailDeliveredAt:
            freezed == emailDeliveredAt
                ? _value.emailDeliveredAt
                : emailDeliveredAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        emailOpenedAt:
            freezed == emailOpenedAt
                ? _value.emailOpenedAt
                : emailOpenedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        emailBouncedAt:
            freezed == emailBouncedAt
                ? _value.emailBouncedAt
                : emailBouncedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        emailFailed:
            null == emailFailed
                ? _value.emailFailed
                : emailFailed // ignore: cast_nullable_to_non_nullable
                    as bool,
        readAt:
            freezed == readAt
                ? _value.readAt
                : readAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MessageRecipientImpl implements _MessageRecipient {
  const _$MessageRecipientImpl({
    required this.id,
    @JsonKey(name: 'message_id') required this.messageId,
    this.tenantId,
    @JsonKey(name: 'player_id') this.playerId,
    @JsonKey(name: 'user_id') this.userId,
    this.name = '',
    @JsonKey(name: 'group_id') this.groupId,
    this.email,
    @JsonKey(name: 'push_enabled') this.pushEnabled = false,
    @JsonKey(name: 'push_sent_at') this.pushSentAt,
    @JsonKey(name: 'telegram_sent_at') this.telegramSentAt,
    @JsonKey(name: 'push_failed') this.pushFailed = false,
    @JsonKey(name: 'email_sent_at') this.emailSentAt,
    @JsonKey(name: 'email_delivered_at') this.emailDeliveredAt,
    @JsonKey(name: 'email_opened_at') this.emailOpenedAt,
    @JsonKey(name: 'email_bounced_at') this.emailBouncedAt,
    @JsonKey(name: 'email_failed') this.emailFailed = false,
    @JsonKey(name: 'read_at') this.readAt,
  });

  factory _$MessageRecipientImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessageRecipientImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'message_id')
  final String messageId;
  @override
  final int? tenantId;
  @override
  @JsonKey(name: 'player_id')
  final int? playerId;
  @override
  @JsonKey(name: 'user_id')
  final String? userId;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey(name: 'group_id')
  final int? groupId;
  @override
  final String? email;
  @override
  @JsonKey(name: 'push_enabled')
  final bool pushEnabled;
  @override
  @JsonKey(name: 'push_sent_at')
  final DateTime? pushSentAt;
  @override
  @JsonKey(name: 'telegram_sent_at')
  final DateTime? telegramSentAt;
  @override
  @JsonKey(name: 'push_failed')
  final bool pushFailed;
  @override
  @JsonKey(name: 'email_sent_at')
  final DateTime? emailSentAt;
  @override
  @JsonKey(name: 'email_delivered_at')
  final DateTime? emailDeliveredAt;
  @override
  @JsonKey(name: 'email_opened_at')
  final DateTime? emailOpenedAt;
  @override
  @JsonKey(name: 'email_bounced_at')
  final DateTime? emailBouncedAt;
  @override
  @JsonKey(name: 'email_failed')
  final bool emailFailed;
  @override
  @JsonKey(name: 'read_at')
  final DateTime? readAt;

  @override
  String toString() {
    return 'MessageRecipient(id: $id, messageId: $messageId, tenantId: $tenantId, playerId: $playerId, userId: $userId, name: $name, groupId: $groupId, email: $email, pushEnabled: $pushEnabled, pushSentAt: $pushSentAt, telegramSentAt: $telegramSentAt, pushFailed: $pushFailed, emailSentAt: $emailSentAt, emailDeliveredAt: $emailDeliveredAt, emailOpenedAt: $emailOpenedAt, emailBouncedAt: $emailBouncedAt, emailFailed: $emailFailed, readAt: $readAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageRecipientImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.messageId, messageId) ||
                other.messageId == messageId) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.playerId, playerId) ||
                other.playerId == playerId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.pushEnabled, pushEnabled) ||
                other.pushEnabled == pushEnabled) &&
            (identical(other.pushSentAt, pushSentAt) ||
                other.pushSentAt == pushSentAt) &&
            (identical(other.telegramSentAt, telegramSentAt) ||
                other.telegramSentAt == telegramSentAt) &&
            (identical(other.pushFailed, pushFailed) ||
                other.pushFailed == pushFailed) &&
            (identical(other.emailSentAt, emailSentAt) ||
                other.emailSentAt == emailSentAt) &&
            (identical(other.emailDeliveredAt, emailDeliveredAt) ||
                other.emailDeliveredAt == emailDeliveredAt) &&
            (identical(other.emailOpenedAt, emailOpenedAt) ||
                other.emailOpenedAt == emailOpenedAt) &&
            (identical(other.emailBouncedAt, emailBouncedAt) ||
                other.emailBouncedAt == emailBouncedAt) &&
            (identical(other.emailFailed, emailFailed) ||
                other.emailFailed == emailFailed) &&
            (identical(other.readAt, readAt) || other.readAt == readAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    messageId,
    tenantId,
    playerId,
    userId,
    name,
    groupId,
    email,
    pushEnabled,
    pushSentAt,
    telegramSentAt,
    pushFailed,
    emailSentAt,
    emailDeliveredAt,
    emailOpenedAt,
    emailBouncedAt,
    emailFailed,
    readAt,
  );

  /// Create a copy of MessageRecipient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageRecipientImplCopyWith<_$MessageRecipientImpl> get copyWith =>
      __$$MessageRecipientImplCopyWithImpl<_$MessageRecipientImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MessageRecipientImplToJson(this);
  }
}

abstract class _MessageRecipient implements MessageRecipient {
  const factory _MessageRecipient({
    required final String id,
    @JsonKey(name: 'message_id') required final String messageId,
    final int? tenantId,
    @JsonKey(name: 'player_id') final int? playerId,
    @JsonKey(name: 'user_id') final String? userId,
    final String name,
    @JsonKey(name: 'group_id') final int? groupId,
    final String? email,
    @JsonKey(name: 'push_enabled') final bool pushEnabled,
    @JsonKey(name: 'push_sent_at') final DateTime? pushSentAt,
    @JsonKey(name: 'telegram_sent_at') final DateTime? telegramSentAt,
    @JsonKey(name: 'push_failed') final bool pushFailed,
    @JsonKey(name: 'email_sent_at') final DateTime? emailSentAt,
    @JsonKey(name: 'email_delivered_at') final DateTime? emailDeliveredAt,
    @JsonKey(name: 'email_opened_at') final DateTime? emailOpenedAt,
    @JsonKey(name: 'email_bounced_at') final DateTime? emailBouncedAt,
    @JsonKey(name: 'email_failed') final bool emailFailed,
    @JsonKey(name: 'read_at') final DateTime? readAt,
  }) = _$MessageRecipientImpl;

  factory _MessageRecipient.fromJson(Map<String, dynamic> json) =
      _$MessageRecipientImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'message_id')
  String get messageId;
  @override
  int? get tenantId;
  @override
  @JsonKey(name: 'player_id')
  int? get playerId;
  @override
  @JsonKey(name: 'user_id')
  String? get userId;
  @override
  String get name;
  @override
  @JsonKey(name: 'group_id')
  int? get groupId;
  @override
  String? get email;
  @override
  @JsonKey(name: 'push_enabled')
  bool get pushEnabled;
  @override
  @JsonKey(name: 'push_sent_at')
  DateTime? get pushSentAt;
  @override
  @JsonKey(name: 'telegram_sent_at')
  DateTime? get telegramSentAt;
  @override
  @JsonKey(name: 'push_failed')
  bool get pushFailed;
  @override
  @JsonKey(name: 'email_sent_at')
  DateTime? get emailSentAt;
  @override
  @JsonKey(name: 'email_delivered_at')
  DateTime? get emailDeliveredAt;
  @override
  @JsonKey(name: 'email_opened_at')
  DateTime? get emailOpenedAt;
  @override
  @JsonKey(name: 'email_bounced_at')
  DateTime? get emailBouncedAt;
  @override
  @JsonKey(name: 'email_failed')
  bool get emailFailed;
  @override
  @JsonKey(name: 'read_at')
  DateTime? get readAt;

  /// Create a copy of MessageRecipient
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageRecipientImplCopyWith<_$MessageRecipientImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MessageRecipientCounts _$MessageRecipientCountsFromJson(
  Map<String, dynamic> json,
) {
  return _MessageRecipientCounts.fromJson(json);
}

/// @nodoc
mixin _$MessageRecipientCounts {
  int get recipients => throw _privateConstructorUsedError;
  int get push => throw _privateConstructorUsedError;
  int get email => throw _privateConstructorUsedError;
  int get unreachable => throw _privateConstructorUsedError;

  /// Serializes this MessageRecipientCounts to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MessageRecipientCounts
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessageRecipientCountsCopyWith<MessageRecipientCounts> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageRecipientCountsCopyWith<$Res> {
  factory $MessageRecipientCountsCopyWith(
    MessageRecipientCounts value,
    $Res Function(MessageRecipientCounts) then,
  ) = _$MessageRecipientCountsCopyWithImpl<$Res, MessageRecipientCounts>;
  @useResult
  $Res call({int recipients, int push, int email, int unreachable});
}

/// @nodoc
class _$MessageRecipientCountsCopyWithImpl<
  $Res,
  $Val extends MessageRecipientCounts
>
    implements $MessageRecipientCountsCopyWith<$Res> {
  _$MessageRecipientCountsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MessageRecipientCounts
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? recipients = null,
    Object? push = null,
    Object? email = null,
    Object? unreachable = null,
  }) {
    return _then(
      _value.copyWith(
            recipients:
                null == recipients
                    ? _value.recipients
                    : recipients // ignore: cast_nullable_to_non_nullable
                        as int,
            push:
                null == push
                    ? _value.push
                    : push // ignore: cast_nullable_to_non_nullable
                        as int,
            email:
                null == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as int,
            unreachable:
                null == unreachable
                    ? _value.unreachable
                    : unreachable // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MessageRecipientCountsImplCopyWith<$Res>
    implements $MessageRecipientCountsCopyWith<$Res> {
  factory _$$MessageRecipientCountsImplCopyWith(
    _$MessageRecipientCountsImpl value,
    $Res Function(_$MessageRecipientCountsImpl) then,
  ) = __$$MessageRecipientCountsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int recipients, int push, int email, int unreachable});
}

/// @nodoc
class __$$MessageRecipientCountsImplCopyWithImpl<$Res>
    extends
        _$MessageRecipientCountsCopyWithImpl<$Res, _$MessageRecipientCountsImpl>
    implements _$$MessageRecipientCountsImplCopyWith<$Res> {
  __$$MessageRecipientCountsImplCopyWithImpl(
    _$MessageRecipientCountsImpl _value,
    $Res Function(_$MessageRecipientCountsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageRecipientCounts
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? recipients = null,
    Object? push = null,
    Object? email = null,
    Object? unreachable = null,
  }) {
    return _then(
      _$MessageRecipientCountsImpl(
        recipients:
            null == recipients
                ? _value.recipients
                : recipients // ignore: cast_nullable_to_non_nullable
                    as int,
        push:
            null == push
                ? _value.push
                : push // ignore: cast_nullable_to_non_nullable
                    as int,
        email:
            null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as int,
        unreachable:
            null == unreachable
                ? _value.unreachable
                : unreachable // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MessageRecipientCountsImpl implements _MessageRecipientCounts {
  const _$MessageRecipientCountsImpl({
    this.recipients = 0,
    this.push = 0,
    this.email = 0,
    this.unreachable = 0,
  });

  factory _$MessageRecipientCountsImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessageRecipientCountsImplFromJson(json);

  @override
  @JsonKey()
  final int recipients;
  @override
  @JsonKey()
  final int push;
  @override
  @JsonKey()
  final int email;
  @override
  @JsonKey()
  final int unreachable;

  @override
  String toString() {
    return 'MessageRecipientCounts(recipients: $recipients, push: $push, email: $email, unreachable: $unreachable)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageRecipientCountsImpl &&
            (identical(other.recipients, recipients) ||
                other.recipients == recipients) &&
            (identical(other.push, push) || other.push == push) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.unreachable, unreachable) ||
                other.unreachable == unreachable));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, recipients, push, email, unreachable);

  /// Create a copy of MessageRecipientCounts
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageRecipientCountsImplCopyWith<_$MessageRecipientCountsImpl>
  get copyWith =>
      __$$MessageRecipientCountsImplCopyWithImpl<_$MessageRecipientCountsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MessageRecipientCountsImplToJson(this);
  }
}

abstract class _MessageRecipientCounts implements MessageRecipientCounts {
  const factory _MessageRecipientCounts({
    final int recipients,
    final int push,
    final int email,
    final int unreachable,
  }) = _$MessageRecipientCountsImpl;

  factory _MessageRecipientCounts.fromJson(Map<String, dynamic> json) =
      _$MessageRecipientCountsImpl.fromJson;

  @override
  int get recipients;
  @override
  int get push;
  @override
  int get email;
  @override
  int get unreachable;

  /// Create a copy of MessageRecipientCounts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageRecipientCountsImplCopyWith<_$MessageRecipientCountsImpl>
  get copyWith => throw _privateConstructorUsedError;
}
