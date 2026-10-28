import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_notification.freezed.dart';
part 'user_notification.g.dart';

/// Entry of the per-user notification feed ("notification center"),
/// table `user_notifications` (see Ionic supabase/sql/user_notifications.sql).
///
/// Rows are written by Edge Functions; the client reads them, marks them
/// read/unread and deletes them.
@freezed
class UserNotification with _$UserNotification {
  const factory UserNotification({
    required String id,
    @JsonKey(name: 'user_id') String? userId,
    required int tenantId,
    @Default('') String type,
    @Default('') String title,
    @Default('') String body,
    @Default(<String>[]) List<String> channels,
    String? email,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
    @Default(false) bool read,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _UserNotification;

  factory UserNotification.fromJson(Map<String, dynamic> json) => _$UserNotificationFromJson(json);
}

extension UserNotificationX on UserNotification {
  String? _str(String key) {
    final v = data[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// Id of the Mitteilung for `type == 'message'` entries.
  String? get messageId => _str('messageId');

  int? get attendanceId => int.tryParse(_str('attendanceId') ?? '');

  /// Tenant the notification's target belongs to (falls back to the row's tenant).
  int get targetTenantId => int.tryParse(_str('tenantId') ?? '') ?? tenantId;

  /// Explicit in-app route (Teamorganisation entries).
  String? get route => _str('route');

  /// Whether tapping the entry navigates somewhere.
  bool get isNavigable => messageId != null || attendanceId != null || route != null;
}
