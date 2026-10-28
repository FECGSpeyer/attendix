// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tenant_role_permission.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TenantRolePermission _$TenantRolePermissionFromJson(Map<String, dynamic> json) {
  return _TenantRolePermission.fromJson(json);
}

/// @nodoc
mixin _$TenantRolePermission {
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  int get tenantId => throw _privateConstructorUsedError;
  int get role => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_all_groups')
  bool get attendanceAllGroups => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_create')
  bool get attendanceCreate => throw _privateConstructorUsedError;
  @JsonKey(name: 'player_notes_view')
  bool get playerNotesView => throw _privateConstructorUsedError;
  @JsonKey(name: 'checklist_view')
  bool get checklistView => throw _privateConstructorUsedError;
  @JsonKey(name: 'player_self_pause')
  bool get playerSelfPause => throw _privateConstructorUsedError;
  @JsonKey(name: 'player_planned_absence')
  bool get playerPlannedAbsence => throw _privateConstructorUsedError;

  /// Serializes this TenantRolePermission to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TenantRolePermission
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TenantRolePermissionCopyWith<TenantRolePermission> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TenantRolePermissionCopyWith<$Res> {
  factory $TenantRolePermissionCopyWith(
    TenantRolePermission value,
    $Res Function(TenantRolePermission) then,
  ) = _$TenantRolePermissionCopyWithImpl<$Res, TenantRolePermission>;
  @useResult
  $Res call({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'tenant_id') int tenantId,
    int role,
    @JsonKey(name: 'attendance_all_groups') bool attendanceAllGroups,
    @JsonKey(name: 'attendance_create') bool attendanceCreate,
    @JsonKey(name: 'player_notes_view') bool playerNotesView,
    @JsonKey(name: 'checklist_view') bool checklistView,
    @JsonKey(name: 'player_self_pause') bool playerSelfPause,
    @JsonKey(name: 'player_planned_absence') bool playerPlannedAbsence,
  });
}

/// @nodoc
class _$TenantRolePermissionCopyWithImpl<
  $Res,
  $Val extends TenantRolePermission
>
    implements $TenantRolePermissionCopyWith<$Res> {
  _$TenantRolePermissionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TenantRolePermission
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? tenantId = null,
    Object? role = null,
    Object? attendanceAllGroups = null,
    Object? attendanceCreate = null,
    Object? playerNotesView = null,
    Object? checklistView = null,
    Object? playerSelfPause = null,
    Object? playerPlannedAbsence = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as int?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            tenantId:
                null == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int,
            role:
                null == role
                    ? _value.role
                    : role // ignore: cast_nullable_to_non_nullable
                        as int,
            attendanceAllGroups:
                null == attendanceAllGroups
                    ? _value.attendanceAllGroups
                    : attendanceAllGroups // ignore: cast_nullable_to_non_nullable
                        as bool,
            attendanceCreate:
                null == attendanceCreate
                    ? _value.attendanceCreate
                    : attendanceCreate // ignore: cast_nullable_to_non_nullable
                        as bool,
            playerNotesView:
                null == playerNotesView
                    ? _value.playerNotesView
                    : playerNotesView // ignore: cast_nullable_to_non_nullable
                        as bool,
            checklistView:
                null == checklistView
                    ? _value.checklistView
                    : checklistView // ignore: cast_nullable_to_non_nullable
                        as bool,
            playerSelfPause:
                null == playerSelfPause
                    ? _value.playerSelfPause
                    : playerSelfPause // ignore: cast_nullable_to_non_nullable
                        as bool,
            playerPlannedAbsence:
                null == playerPlannedAbsence
                    ? _value.playerPlannedAbsence
                    : playerPlannedAbsence // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TenantRolePermissionImplCopyWith<$Res>
    implements $TenantRolePermissionCopyWith<$Res> {
  factory _$$TenantRolePermissionImplCopyWith(
    _$TenantRolePermissionImpl value,
    $Res Function(_$TenantRolePermissionImpl) then,
  ) = __$$TenantRolePermissionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'tenant_id') int tenantId,
    int role,
    @JsonKey(name: 'attendance_all_groups') bool attendanceAllGroups,
    @JsonKey(name: 'attendance_create') bool attendanceCreate,
    @JsonKey(name: 'player_notes_view') bool playerNotesView,
    @JsonKey(name: 'checklist_view') bool checklistView,
    @JsonKey(name: 'player_self_pause') bool playerSelfPause,
    @JsonKey(name: 'player_planned_absence') bool playerPlannedAbsence,
  });
}

/// @nodoc
class __$$TenantRolePermissionImplCopyWithImpl<$Res>
    extends _$TenantRolePermissionCopyWithImpl<$Res, _$TenantRolePermissionImpl>
    implements _$$TenantRolePermissionImplCopyWith<$Res> {
  __$$TenantRolePermissionImplCopyWithImpl(
    _$TenantRolePermissionImpl _value,
    $Res Function(_$TenantRolePermissionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TenantRolePermission
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? tenantId = null,
    Object? role = null,
    Object? attendanceAllGroups = null,
    Object? attendanceCreate = null,
    Object? playerNotesView = null,
    Object? checklistView = null,
    Object? playerSelfPause = null,
    Object? playerPlannedAbsence = null,
  }) {
    return _then(
      _$TenantRolePermissionImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as int?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        tenantId:
            null == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int,
        role:
            null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                    as int,
        attendanceAllGroups:
            null == attendanceAllGroups
                ? _value.attendanceAllGroups
                : attendanceAllGroups // ignore: cast_nullable_to_non_nullable
                    as bool,
        attendanceCreate:
            null == attendanceCreate
                ? _value.attendanceCreate
                : attendanceCreate // ignore: cast_nullable_to_non_nullable
                    as bool,
        playerNotesView:
            null == playerNotesView
                ? _value.playerNotesView
                : playerNotesView // ignore: cast_nullable_to_non_nullable
                    as bool,
        checklistView:
            null == checklistView
                ? _value.checklistView
                : checklistView // ignore: cast_nullable_to_non_nullable
                    as bool,
        playerSelfPause:
            null == playerSelfPause
                ? _value.playerSelfPause
                : playerSelfPause // ignore: cast_nullable_to_non_nullable
                    as bool,
        playerPlannedAbsence:
            null == playerPlannedAbsence
                ? _value.playerPlannedAbsence
                : playerPlannedAbsence // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TenantRolePermissionImpl implements _TenantRolePermission {
  const _$TenantRolePermissionImpl({
    this.id,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'tenant_id') required this.tenantId,
    required this.role,
    @JsonKey(name: 'attendance_all_groups') this.attendanceAllGroups = true,
    @JsonKey(name: 'attendance_create') this.attendanceCreate = true,
    @JsonKey(name: 'player_notes_view') this.playerNotesView = false,
    @JsonKey(name: 'checklist_view') this.checklistView = false,
    @JsonKey(name: 'player_self_pause') this.playerSelfPause = false,
    @JsonKey(name: 'player_planned_absence') this.playerPlannedAbsence = false,
  });

  factory _$TenantRolePermissionImpl.fromJson(Map<String, dynamic> json) =>
      _$$TenantRolePermissionImplFromJson(json);

  @override
  final int? id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'tenant_id')
  final int tenantId;
  @override
  final int role;
  @override
  @JsonKey(name: 'attendance_all_groups')
  final bool attendanceAllGroups;
  @override
  @JsonKey(name: 'attendance_create')
  final bool attendanceCreate;
  @override
  @JsonKey(name: 'player_notes_view')
  final bool playerNotesView;
  @override
  @JsonKey(name: 'checklist_view')
  final bool checklistView;
  @override
  @JsonKey(name: 'player_self_pause')
  final bool playerSelfPause;
  @override
  @JsonKey(name: 'player_planned_absence')
  final bool playerPlannedAbsence;

  @override
  String toString() {
    return 'TenantRolePermission(id: $id, createdAt: $createdAt, tenantId: $tenantId, role: $role, attendanceAllGroups: $attendanceAllGroups, attendanceCreate: $attendanceCreate, playerNotesView: $playerNotesView, checklistView: $checklistView, playerSelfPause: $playerSelfPause, playerPlannedAbsence: $playerPlannedAbsence)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TenantRolePermissionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.attendanceAllGroups, attendanceAllGroups) ||
                other.attendanceAllGroups == attendanceAllGroups) &&
            (identical(other.attendanceCreate, attendanceCreate) ||
                other.attendanceCreate == attendanceCreate) &&
            (identical(other.playerNotesView, playerNotesView) ||
                other.playerNotesView == playerNotesView) &&
            (identical(other.checklistView, checklistView) ||
                other.checklistView == checklistView) &&
            (identical(other.playerSelfPause, playerSelfPause) ||
                other.playerSelfPause == playerSelfPause) &&
            (identical(other.playerPlannedAbsence, playerPlannedAbsence) ||
                other.playerPlannedAbsence == playerPlannedAbsence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    createdAt,
    tenantId,
    role,
    attendanceAllGroups,
    attendanceCreate,
    playerNotesView,
    checklistView,
    playerSelfPause,
    playerPlannedAbsence,
  );

  /// Create a copy of TenantRolePermission
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TenantRolePermissionImplCopyWith<_$TenantRolePermissionImpl>
  get copyWith =>
      __$$TenantRolePermissionImplCopyWithImpl<_$TenantRolePermissionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TenantRolePermissionImplToJson(this);
  }
}

abstract class _TenantRolePermission implements TenantRolePermission {
  const factory _TenantRolePermission({
    final int? id,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'tenant_id') required final int tenantId,
    required final int role,
    @JsonKey(name: 'attendance_all_groups') final bool attendanceAllGroups,
    @JsonKey(name: 'attendance_create') final bool attendanceCreate,
    @JsonKey(name: 'player_notes_view') final bool playerNotesView,
    @JsonKey(name: 'checklist_view') final bool checklistView,
    @JsonKey(name: 'player_self_pause') final bool playerSelfPause,
    @JsonKey(name: 'player_planned_absence') final bool playerPlannedAbsence,
  }) = _$TenantRolePermissionImpl;

  factory _TenantRolePermission.fromJson(Map<String, dynamic> json) =
      _$TenantRolePermissionImpl.fromJson;

  @override
  int? get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'tenant_id')
  int get tenantId;
  @override
  int get role;
  @override
  @JsonKey(name: 'attendance_all_groups')
  bool get attendanceAllGroups;
  @override
  @JsonKey(name: 'attendance_create')
  bool get attendanceCreate;
  @override
  @JsonKey(name: 'player_notes_view')
  bool get playerNotesView;
  @override
  @JsonKey(name: 'checklist_view')
  bool get checklistView;
  @override
  @JsonKey(name: 'player_self_pause')
  bool get playerSelfPause;
  @override
  @JsonKey(name: 'player_planned_absence')
  bool get playerPlannedAbsence;

  /// Create a copy of TenantRolePermission
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TenantRolePermissionImplCopyWith<_$TenantRolePermissionImpl>
  get copyWith => throw _privateConstructorUsedError;
}
