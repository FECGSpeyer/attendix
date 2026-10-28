// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'player_absence.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PlayerAbsence _$PlayerAbsenceFromJson(Map<String, dynamic> json) {
  return _PlayerAbsence.fromJson(json);
}

/// @nodoc
mixin _$PlayerAbsence {
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by')
  String? get createdBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  int? get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'person_id')
  int get personId => throw _privateConstructorUsedError;
  @JsonKey(name: 'from_date')
  String get fromDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'until_date')
  String get untilDate => throw _privateConstructorUsedError;
  String get reason => throw _privateConstructorUsedError;

  /// Serializes this PlayerAbsence to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlayerAbsence
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlayerAbsenceCopyWith<PlayerAbsence> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlayerAbsenceCopyWith<$Res> {
  factory $PlayerAbsenceCopyWith(
    PlayerAbsence value,
    $Res Function(PlayerAbsence) then,
  ) = _$PlayerAbsenceCopyWithImpl<$Res, PlayerAbsence>;
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'tenant_id') int? tenantId,
    @JsonKey(name: 'person_id') int personId,
    @JsonKey(name: 'from_date') String fromDate,
    @JsonKey(name: 'until_date') String untilDate,
    String reason,
  });
}

/// @nodoc
class _$PlayerAbsenceCopyWithImpl<$Res, $Val extends PlayerAbsence>
    implements $PlayerAbsenceCopyWith<$Res> {
  _$PlayerAbsenceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlayerAbsence
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? createdBy = freezed,
    Object? tenantId = freezed,
    Object? personId = null,
    Object? fromDate = null,
    Object? untilDate = null,
    Object? reason = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            createdBy:
                freezed == createdBy
                    ? _value.createdBy
                    : createdBy // ignore: cast_nullable_to_non_nullable
                        as String?,
            tenantId:
                freezed == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int?,
            personId:
                null == personId
                    ? _value.personId
                    : personId // ignore: cast_nullable_to_non_nullable
                        as int,
            fromDate:
                null == fromDate
                    ? _value.fromDate
                    : fromDate // ignore: cast_nullable_to_non_nullable
                        as String,
            untilDate:
                null == untilDate
                    ? _value.untilDate
                    : untilDate // ignore: cast_nullable_to_non_nullable
                        as String,
            reason:
                null == reason
                    ? _value.reason
                    : reason // ignore: cast_nullable_to_non_nullable
                        as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlayerAbsenceImplCopyWith<$Res>
    implements $PlayerAbsenceCopyWith<$Res> {
  factory _$$PlayerAbsenceImplCopyWith(
    _$PlayerAbsenceImpl value,
    $Res Function(_$PlayerAbsenceImpl) then,
  ) = __$$PlayerAbsenceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'tenant_id') int? tenantId,
    @JsonKey(name: 'person_id') int personId,
    @JsonKey(name: 'from_date') String fromDate,
    @JsonKey(name: 'until_date') String untilDate,
    String reason,
  });
}

/// @nodoc
class __$$PlayerAbsenceImplCopyWithImpl<$Res>
    extends _$PlayerAbsenceCopyWithImpl<$Res, _$PlayerAbsenceImpl>
    implements _$$PlayerAbsenceImplCopyWith<$Res> {
  __$$PlayerAbsenceImplCopyWithImpl(
    _$PlayerAbsenceImpl _value,
    $Res Function(_$PlayerAbsenceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlayerAbsence
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? createdBy = freezed,
    Object? tenantId = freezed,
    Object? personId = null,
    Object? fromDate = null,
    Object? untilDate = null,
    Object? reason = null,
  }) {
    return _then(
      _$PlayerAbsenceImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        createdBy:
            freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                    as String?,
        tenantId:
            freezed == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int?,
        personId:
            null == personId
                ? _value.personId
                : personId // ignore: cast_nullable_to_non_nullable
                    as int,
        fromDate:
            null == fromDate
                ? _value.fromDate
                : fromDate // ignore: cast_nullable_to_non_nullable
                    as String,
        untilDate:
            null == untilDate
                ? _value.untilDate
                : untilDate // ignore: cast_nullable_to_non_nullable
                    as String,
        reason:
            null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                    as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PlayerAbsenceImpl implements _PlayerAbsence {
  const _$PlayerAbsenceImpl({
    this.id,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'created_by') this.createdBy,
    @JsonKey(name: 'tenant_id') this.tenantId,
    @JsonKey(name: 'person_id') required this.personId,
    @JsonKey(name: 'from_date') required this.fromDate,
    @JsonKey(name: 'until_date') required this.untilDate,
    this.reason = '',
  });

  factory _$PlayerAbsenceImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlayerAbsenceImplFromJson(json);

  @override
  final String? id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'created_by')
  final String? createdBy;
  @override
  @JsonKey(name: 'tenant_id')
  final int? tenantId;
  @override
  @JsonKey(name: 'person_id')
  final int personId;
  @override
  @JsonKey(name: 'from_date')
  final String fromDate;
  @override
  @JsonKey(name: 'until_date')
  final String untilDate;
  @override
  @JsonKey()
  final String reason;

  @override
  String toString() {
    return 'PlayerAbsence(id: $id, createdAt: $createdAt, createdBy: $createdBy, tenantId: $tenantId, personId: $personId, fromDate: $fromDate, untilDate: $untilDate, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlayerAbsenceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.personId, personId) ||
                other.personId == personId) &&
            (identical(other.fromDate, fromDate) ||
                other.fromDate == fromDate) &&
            (identical(other.untilDate, untilDate) ||
                other.untilDate == untilDate) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    createdAt,
    createdBy,
    tenantId,
    personId,
    fromDate,
    untilDate,
    reason,
  );

  /// Create a copy of PlayerAbsence
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlayerAbsenceImplCopyWith<_$PlayerAbsenceImpl> get copyWith =>
      __$$PlayerAbsenceImplCopyWithImpl<_$PlayerAbsenceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlayerAbsenceImplToJson(this);
  }
}

abstract class _PlayerAbsence implements PlayerAbsence {
  const factory _PlayerAbsence({
    final String? id,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'created_by') final String? createdBy,
    @JsonKey(name: 'tenant_id') final int? tenantId,
    @JsonKey(name: 'person_id') required final int personId,
    @JsonKey(name: 'from_date') required final String fromDate,
    @JsonKey(name: 'until_date') required final String untilDate,
    final String reason,
  }) = _$PlayerAbsenceImpl;

  factory _PlayerAbsence.fromJson(Map<String, dynamic> json) =
      _$PlayerAbsenceImpl.fromJson;

  @override
  String? get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'created_by')
  String? get createdBy;
  @override
  @JsonKey(name: 'tenant_id')
  int? get tenantId;
  @override
  @JsonKey(name: 'person_id')
  int get personId;
  @override
  @JsonKey(name: 'from_date')
  String get fromDate;
  @override
  @JsonKey(name: 'until_date')
  String get untilDate;
  @override
  String get reason;

  /// Create a copy of PlayerAbsence
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlayerAbsenceImplCopyWith<_$PlayerAbsenceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RoleAbsencePermissions _$RoleAbsencePermissionsFromJson(
  Map<String, dynamic> json,
) {
  return _RoleAbsencePermissions.fromJson(json);
}

/// @nodoc
mixin _$RoleAbsencePermissions {
  @JsonKey(name: 'player_self_pause')
  bool get playerSelfPause => throw _privateConstructorUsedError;
  @JsonKey(name: 'player_planned_absence')
  bool get playerPlannedAbsence => throw _privateConstructorUsedError;

  /// Serializes this RoleAbsencePermissions to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RoleAbsencePermissions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RoleAbsencePermissionsCopyWith<RoleAbsencePermissions> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoleAbsencePermissionsCopyWith<$Res> {
  factory $RoleAbsencePermissionsCopyWith(
    RoleAbsencePermissions value,
    $Res Function(RoleAbsencePermissions) then,
  ) = _$RoleAbsencePermissionsCopyWithImpl<$Res, RoleAbsencePermissions>;
  @useResult
  $Res call({
    @JsonKey(name: 'player_self_pause') bool playerSelfPause,
    @JsonKey(name: 'player_planned_absence') bool playerPlannedAbsence,
  });
}

/// @nodoc
class _$RoleAbsencePermissionsCopyWithImpl<
  $Res,
  $Val extends RoleAbsencePermissions
>
    implements $RoleAbsencePermissionsCopyWith<$Res> {
  _$RoleAbsencePermissionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RoleAbsencePermissions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? playerSelfPause = null,
    Object? playerPlannedAbsence = null,
  }) {
    return _then(
      _value.copyWith(
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
abstract class _$$RoleAbsencePermissionsImplCopyWith<$Res>
    implements $RoleAbsencePermissionsCopyWith<$Res> {
  factory _$$RoleAbsencePermissionsImplCopyWith(
    _$RoleAbsencePermissionsImpl value,
    $Res Function(_$RoleAbsencePermissionsImpl) then,
  ) = __$$RoleAbsencePermissionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'player_self_pause') bool playerSelfPause,
    @JsonKey(name: 'player_planned_absence') bool playerPlannedAbsence,
  });
}

/// @nodoc
class __$$RoleAbsencePermissionsImplCopyWithImpl<$Res>
    extends
        _$RoleAbsencePermissionsCopyWithImpl<$Res, _$RoleAbsencePermissionsImpl>
    implements _$$RoleAbsencePermissionsImplCopyWith<$Res> {
  __$$RoleAbsencePermissionsImplCopyWithImpl(
    _$RoleAbsencePermissionsImpl _value,
    $Res Function(_$RoleAbsencePermissionsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RoleAbsencePermissions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? playerSelfPause = null,
    Object? playerPlannedAbsence = null,
  }) {
    return _then(
      _$RoleAbsencePermissionsImpl(
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
class _$RoleAbsencePermissionsImpl implements _RoleAbsencePermissions {
  const _$RoleAbsencePermissionsImpl({
    @JsonKey(name: 'player_self_pause') this.playerSelfPause = false,
    @JsonKey(name: 'player_planned_absence') this.playerPlannedAbsence = false,
  });

  factory _$RoleAbsencePermissionsImpl.fromJson(Map<String, dynamic> json) =>
      _$$RoleAbsencePermissionsImplFromJson(json);

  @override
  @JsonKey(name: 'player_self_pause')
  final bool playerSelfPause;
  @override
  @JsonKey(name: 'player_planned_absence')
  final bool playerPlannedAbsence;

  @override
  String toString() {
    return 'RoleAbsencePermissions(playerSelfPause: $playerSelfPause, playerPlannedAbsence: $playerPlannedAbsence)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoleAbsencePermissionsImpl &&
            (identical(other.playerSelfPause, playerSelfPause) ||
                other.playerSelfPause == playerSelfPause) &&
            (identical(other.playerPlannedAbsence, playerPlannedAbsence) ||
                other.playerPlannedAbsence == playerPlannedAbsence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, playerSelfPause, playerPlannedAbsence);

  /// Create a copy of RoleAbsencePermissions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RoleAbsencePermissionsImplCopyWith<_$RoleAbsencePermissionsImpl>
  get copyWith =>
      __$$RoleAbsencePermissionsImplCopyWithImpl<_$RoleAbsencePermissionsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RoleAbsencePermissionsImplToJson(this);
  }
}

abstract class _RoleAbsencePermissions implements RoleAbsencePermissions {
  const factory _RoleAbsencePermissions({
    @JsonKey(name: 'player_self_pause') final bool playerSelfPause,
    @JsonKey(name: 'player_planned_absence') final bool playerPlannedAbsence,
  }) = _$RoleAbsencePermissionsImpl;

  factory _RoleAbsencePermissions.fromJson(Map<String, dynamic> json) =
      _$RoleAbsencePermissionsImpl.fromJson;

  @override
  @JsonKey(name: 'player_self_pause')
  bool get playerSelfPause;
  @override
  @JsonKey(name: 'player_planned_absence')
  bool get playerPlannedAbsence;

  /// Create a copy of RoleAbsencePermissions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RoleAbsencePermissionsImplCopyWith<_$RoleAbsencePermissionsImpl>
  get copyWith => throw _privateConstructorUsedError;
}
