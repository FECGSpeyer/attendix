// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'person_unavailability.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PersonUnavailability _$PersonUnavailabilityFromJson(Map<String, dynamic> json) {
  return _PersonUnavailability.fromJson(json);
}

/// @nodoc
mixin _$PersonUnavailability {
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by')
  String? get createdBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  int get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'person_id')
  int get personId => throw _privateConstructorUsedError;

  /// ISO weekdays 1 = Monday … 7 = Sunday
  List<int> get weekdays => throw _privateConstructorUsedError;

  /// Empty = rule applies to all attendance types
  @JsonKey(name: 'type_ids')
  List<String> get typeIds => throw _privateConstructorUsedError;
  String get reason => throw _privateConstructorUsedError;

  /// yyyy-MM-dd, null = unlimited
  @JsonKey(name: 'valid_until')
  String? get validUntil => throw _privateConstructorUsedError;

  /// Serializes this PersonUnavailability to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PersonUnavailability
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PersonUnavailabilityCopyWith<PersonUnavailability> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PersonUnavailabilityCopyWith<$Res> {
  factory $PersonUnavailabilityCopyWith(
    PersonUnavailability value,
    $Res Function(PersonUnavailability) then,
  ) = _$PersonUnavailabilityCopyWithImpl<$Res, PersonUnavailability>;
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'tenant_id') int tenantId,
    @JsonKey(name: 'person_id') int personId,
    List<int> weekdays,
    @JsonKey(name: 'type_ids') List<String> typeIds,
    String reason,
    @JsonKey(name: 'valid_until') String? validUntil,
  });
}

/// @nodoc
class _$PersonUnavailabilityCopyWithImpl<
  $Res,
  $Val extends PersonUnavailability
>
    implements $PersonUnavailabilityCopyWith<$Res> {
  _$PersonUnavailabilityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PersonUnavailability
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? createdBy = freezed,
    Object? tenantId = null,
    Object? personId = null,
    Object? weekdays = null,
    Object? typeIds = null,
    Object? reason = null,
    Object? validUntil = freezed,
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
                        as String?,
            createdBy:
                freezed == createdBy
                    ? _value.createdBy
                    : createdBy // ignore: cast_nullable_to_non_nullable
                        as String?,
            tenantId:
                null == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int,
            personId:
                null == personId
                    ? _value.personId
                    : personId // ignore: cast_nullable_to_non_nullable
                        as int,
            weekdays:
                null == weekdays
                    ? _value.weekdays
                    : weekdays // ignore: cast_nullable_to_non_nullable
                        as List<int>,
            typeIds:
                null == typeIds
                    ? _value.typeIds
                    : typeIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            reason:
                null == reason
                    ? _value.reason
                    : reason // ignore: cast_nullable_to_non_nullable
                        as String,
            validUntil:
                freezed == validUntil
                    ? _value.validUntil
                    : validUntil // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PersonUnavailabilityImplCopyWith<$Res>
    implements $PersonUnavailabilityCopyWith<$Res> {
  factory _$$PersonUnavailabilityImplCopyWith(
    _$PersonUnavailabilityImpl value,
    $Res Function(_$PersonUnavailabilityImpl) then,
  ) = __$$PersonUnavailabilityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'tenant_id') int tenantId,
    @JsonKey(name: 'person_id') int personId,
    List<int> weekdays,
    @JsonKey(name: 'type_ids') List<String> typeIds,
    String reason,
    @JsonKey(name: 'valid_until') String? validUntil,
  });
}

/// @nodoc
class __$$PersonUnavailabilityImplCopyWithImpl<$Res>
    extends _$PersonUnavailabilityCopyWithImpl<$Res, _$PersonUnavailabilityImpl>
    implements _$$PersonUnavailabilityImplCopyWith<$Res> {
  __$$PersonUnavailabilityImplCopyWithImpl(
    _$PersonUnavailabilityImpl _value,
    $Res Function(_$PersonUnavailabilityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PersonUnavailability
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? createdBy = freezed,
    Object? tenantId = null,
    Object? personId = null,
    Object? weekdays = null,
    Object? typeIds = null,
    Object? reason = null,
    Object? validUntil = freezed,
  }) {
    return _then(
      _$PersonUnavailabilityImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdBy:
            freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                    as String?,
        tenantId:
            null == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int,
        personId:
            null == personId
                ? _value.personId
                : personId // ignore: cast_nullable_to_non_nullable
                    as int,
        weekdays:
            null == weekdays
                ? _value._weekdays
                : weekdays // ignore: cast_nullable_to_non_nullable
                    as List<int>,
        typeIds:
            null == typeIds
                ? _value._typeIds
                : typeIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        reason:
            null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                    as String,
        validUntil:
            freezed == validUntil
                ? _value.validUntil
                : validUntil // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PersonUnavailabilityImpl implements _PersonUnavailability {
  const _$PersonUnavailabilityImpl({
    this.id,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'created_by') this.createdBy,
    @JsonKey(name: 'tenant_id') required this.tenantId,
    @JsonKey(name: 'person_id') required this.personId,
    final List<int> weekdays = const <int>[],
    @JsonKey(name: 'type_ids') final List<String> typeIds = const <String>[],
    this.reason = '',
    @JsonKey(name: 'valid_until') this.validUntil,
  }) : _weekdays = weekdays,
       _typeIds = typeIds;

  factory _$PersonUnavailabilityImpl.fromJson(Map<String, dynamic> json) =>
      _$$PersonUnavailabilityImplFromJson(json);

  @override
  final String? id;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @override
  @JsonKey(name: 'created_by')
  final String? createdBy;
  @override
  @JsonKey(name: 'tenant_id')
  final int tenantId;
  @override
  @JsonKey(name: 'person_id')
  final int personId;

  /// ISO weekdays 1 = Monday … 7 = Sunday
  final List<int> _weekdays;

  /// ISO weekdays 1 = Monday … 7 = Sunday
  @override
  @JsonKey()
  List<int> get weekdays {
    if (_weekdays is EqualUnmodifiableListView) return _weekdays;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weekdays);
  }

  /// Empty = rule applies to all attendance types
  final List<String> _typeIds;

  /// Empty = rule applies to all attendance types
  @override
  @JsonKey(name: 'type_ids')
  List<String> get typeIds {
    if (_typeIds is EqualUnmodifiableListView) return _typeIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_typeIds);
  }

  @override
  @JsonKey()
  final String reason;

  /// yyyy-MM-dd, null = unlimited
  @override
  @JsonKey(name: 'valid_until')
  final String? validUntil;

  @override
  String toString() {
    return 'PersonUnavailability(id: $id, createdAt: $createdAt, createdBy: $createdBy, tenantId: $tenantId, personId: $personId, weekdays: $weekdays, typeIds: $typeIds, reason: $reason, validUntil: $validUntil)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PersonUnavailabilityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.personId, personId) ||
                other.personId == personId) &&
            const DeepCollectionEquality().equals(other._weekdays, _weekdays) &&
            const DeepCollectionEquality().equals(other._typeIds, _typeIds) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.validUntil, validUntil) ||
                other.validUntil == validUntil));
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
    const DeepCollectionEquality().hash(_weekdays),
    const DeepCollectionEquality().hash(_typeIds),
    reason,
    validUntil,
  );

  /// Create a copy of PersonUnavailability
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PersonUnavailabilityImplCopyWith<_$PersonUnavailabilityImpl>
  get copyWith =>
      __$$PersonUnavailabilityImplCopyWithImpl<_$PersonUnavailabilityImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PersonUnavailabilityImplToJson(this);
  }
}

abstract class _PersonUnavailability implements PersonUnavailability {
  const factory _PersonUnavailability({
    final String? id,
    @JsonKey(name: 'created_at') final String? createdAt,
    @JsonKey(name: 'created_by') final String? createdBy,
    @JsonKey(name: 'tenant_id') required final int tenantId,
    @JsonKey(name: 'person_id') required final int personId,
    final List<int> weekdays,
    @JsonKey(name: 'type_ids') final List<String> typeIds,
    final String reason,
    @JsonKey(name: 'valid_until') final String? validUntil,
  }) = _$PersonUnavailabilityImpl;

  factory _PersonUnavailability.fromJson(Map<String, dynamic> json) =
      _$PersonUnavailabilityImpl.fromJson;

  @override
  String? get id;
  @override
  @JsonKey(name: 'created_at')
  String? get createdAt;
  @override
  @JsonKey(name: 'created_by')
  String? get createdBy;
  @override
  @JsonKey(name: 'tenant_id')
  int get tenantId;
  @override
  @JsonKey(name: 'person_id')
  int get personId;

  /// ISO weekdays 1 = Monday … 7 = Sunday
  @override
  List<int> get weekdays;

  /// Empty = rule applies to all attendance types
  @override
  @JsonKey(name: 'type_ids')
  List<String> get typeIds;
  @override
  String get reason;

  /// yyyy-MM-dd, null = unlimited
  @override
  @JsonKey(name: 'valid_until')
  String? get validUntil;

  /// Create a copy of PersonUnavailability
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PersonUnavailabilityImplCopyWith<_$PersonUnavailabilityImpl>
  get copyWith => throw _privateConstructorUsedError;
}
