// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_org.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PersonRef _$PersonRefFromJson(Map<String, dynamic> json) {
  return _PersonRef.fromJson(json);
}

/// @nodoc
mixin _$PersonRef {
  @JsonKey(fromJson: _toInt)
  int? get id => throw _privateConstructorUsedError;
  String? get firstName => throw _privateConstructorUsedError;
  String? get lastName => throw _privateConstructorUsedError;

  /// Serializes this PersonRef to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PersonRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PersonRefCopyWith<PersonRef> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PersonRefCopyWith<$Res> {
  factory $PersonRefCopyWith(PersonRef value, $Res Function(PersonRef) then) =
      _$PersonRefCopyWithImpl<$Res, PersonRef>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _toInt) int? id,
    String? firstName,
    String? lastName,
  });
}

/// @nodoc
class _$PersonRefCopyWithImpl<$Res, $Val extends PersonRef>
    implements $PersonRefCopyWith<$Res> {
  _$PersonRefCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PersonRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? firstName = freezed,
    Object? lastName = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as int?,
            firstName:
                freezed == firstName
                    ? _value.firstName
                    : firstName // ignore: cast_nullable_to_non_nullable
                        as String?,
            lastName:
                freezed == lastName
                    ? _value.lastName
                    : lastName // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PersonRefImplCopyWith<$Res>
    implements $PersonRefCopyWith<$Res> {
  factory _$$PersonRefImplCopyWith(
    _$PersonRefImpl value,
    $Res Function(_$PersonRefImpl) then,
  ) = __$$PersonRefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _toInt) int? id,
    String? firstName,
    String? lastName,
  });
}

/// @nodoc
class __$$PersonRefImplCopyWithImpl<$Res>
    extends _$PersonRefCopyWithImpl<$Res, _$PersonRefImpl>
    implements _$$PersonRefImplCopyWith<$Res> {
  __$$PersonRefImplCopyWithImpl(
    _$PersonRefImpl _value,
    $Res Function(_$PersonRefImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PersonRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? firstName = freezed,
    Object? lastName = freezed,
  }) {
    return _then(
      _$PersonRefImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as int?,
        firstName:
            freezed == firstName
                ? _value.firstName
                : firstName // ignore: cast_nullable_to_non_nullable
                    as String?,
        lastName:
            freezed == lastName
                ? _value.lastName
                : lastName // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PersonRefImpl implements _PersonRef {
  const _$PersonRefImpl({
    @JsonKey(fromJson: _toInt) this.id,
    this.firstName,
    this.lastName,
  });

  factory _$PersonRefImpl.fromJson(Map<String, dynamic> json) =>
      _$$PersonRefImplFromJson(json);

  @override
  @JsonKey(fromJson: _toInt)
  final int? id;
  @override
  final String? firstName;
  @override
  final String? lastName;

  @override
  String toString() {
    return 'PersonRef(id: $id, firstName: $firstName, lastName: $lastName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PersonRefImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, firstName, lastName);

  /// Create a copy of PersonRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PersonRefImplCopyWith<_$PersonRefImpl> get copyWith =>
      __$$PersonRefImplCopyWithImpl<_$PersonRefImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PersonRefImplToJson(this);
  }
}

abstract class _PersonRef implements PersonRef {
  const factory _PersonRef({
    @JsonKey(fromJson: _toInt) final int? id,
    final String? firstName,
    final String? lastName,
  }) = _$PersonRefImpl;

  factory _PersonRef.fromJson(Map<String, dynamic> json) =
      _$PersonRefImpl.fromJson;

  @override
  @JsonKey(fromJson: _toInt)
  int? get id;
  @override
  String? get firstName;
  @override
  String? get lastName;

  /// Create a copy of PersonRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PersonRefImplCopyWith<_$PersonRefImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AgendaItem _$AgendaItemFromJson(Map<String, dynamic> json) {
  return _AgendaItem.fromJson(json);
}

/// @nodoc
mixin _$AgendaItem {
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id', fromJson: _toInt)
  int? get tenantId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;

  /// open | completed | dropped
  String get status => throw _privateConstructorUsedError;

  /// low | medium | high
  String get priority => throw _privateConstructorUsedError;
  @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
  int? get responsiblePersonId => throw _privateConstructorUsedError;
  @JsonKey(name: 'default_duration', fromJson: _toInt)
  int? get defaultDuration => throw _privateConstructorUsedError;
  @JsonKey(name: 'proposed_by', fromJson: _toInt)
  int? get proposedBy => throw _privateConstructorUsedError;

  /// null | pending | accepted | rejected
  @JsonKey(name: 'proposal_status')
  String? get proposalStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'decision_note')
  String? get decisionNote => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at', fromJson: _toStr)
  String? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by')
  String? get createdBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'responsible_person')
  PersonRef? get responsiblePerson => throw _privateConstructorUsedError;
  PersonRef? get proposer => throw _privateConstructorUsedError;

  /// Serializes this AgendaItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AgendaItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgendaItemCopyWith<AgendaItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgendaItemCopyWith<$Res> {
  factory $AgendaItemCopyWith(
    AgendaItem value,
    $Res Function(AgendaItem) then,
  ) = _$AgendaItemCopyWithImpl<$Res, AgendaItem>;
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) int? tenantId,
    String title,
    String? description,
    String status,
    String priority,
    @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
    int? responsiblePersonId,
    @JsonKey(name: 'default_duration', fromJson: _toInt) int? defaultDuration,
    @JsonKey(name: 'proposed_by', fromJson: _toInt) int? proposedBy,
    @JsonKey(name: 'proposal_status') String? proposalStatus,
    @JsonKey(name: 'decision_note') String? decisionNote,
    @JsonKey(name: 'created_at', fromJson: _toStr) String? createdAt,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'responsible_person') PersonRef? responsiblePerson,
    PersonRef? proposer,
  });

  $PersonRefCopyWith<$Res>? get responsiblePerson;
  $PersonRefCopyWith<$Res>? get proposer;
}

/// @nodoc
class _$AgendaItemCopyWithImpl<$Res, $Val extends AgendaItem>
    implements $AgendaItemCopyWith<$Res> {
  _$AgendaItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgendaItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? title = null,
    Object? description = freezed,
    Object? status = null,
    Object? priority = null,
    Object? responsiblePersonId = freezed,
    Object? defaultDuration = freezed,
    Object? proposedBy = freezed,
    Object? proposalStatus = freezed,
    Object? decisionNote = freezed,
    Object? createdAt = freezed,
    Object? createdBy = freezed,
    Object? responsiblePerson = freezed,
    Object? proposer = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String?,
            tenantId:
                freezed == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int?,
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                freezed == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String?,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as String,
            priority:
                null == priority
                    ? _value.priority
                    : priority // ignore: cast_nullable_to_non_nullable
                        as String,
            responsiblePersonId:
                freezed == responsiblePersonId
                    ? _value.responsiblePersonId
                    : responsiblePersonId // ignore: cast_nullable_to_non_nullable
                        as int?,
            defaultDuration:
                freezed == defaultDuration
                    ? _value.defaultDuration
                    : defaultDuration // ignore: cast_nullable_to_non_nullable
                        as int?,
            proposedBy:
                freezed == proposedBy
                    ? _value.proposedBy
                    : proposedBy // ignore: cast_nullable_to_non_nullable
                        as int?,
            proposalStatus:
                freezed == proposalStatus
                    ? _value.proposalStatus
                    : proposalStatus // ignore: cast_nullable_to_non_nullable
                        as String?,
            decisionNote:
                freezed == decisionNote
                    ? _value.decisionNote
                    : decisionNote // ignore: cast_nullable_to_non_nullable
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
            responsiblePerson:
                freezed == responsiblePerson
                    ? _value.responsiblePerson
                    : responsiblePerson // ignore: cast_nullable_to_non_nullable
                        as PersonRef?,
            proposer:
                freezed == proposer
                    ? _value.proposer
                    : proposer // ignore: cast_nullable_to_non_nullable
                        as PersonRef?,
          )
          as $Val,
    );
  }

  /// Create a copy of AgendaItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PersonRefCopyWith<$Res>? get responsiblePerson {
    if (_value.responsiblePerson == null) {
      return null;
    }

    return $PersonRefCopyWith<$Res>(_value.responsiblePerson!, (value) {
      return _then(_value.copyWith(responsiblePerson: value) as $Val);
    });
  }

  /// Create a copy of AgendaItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PersonRefCopyWith<$Res>? get proposer {
    if (_value.proposer == null) {
      return null;
    }

    return $PersonRefCopyWith<$Res>(_value.proposer!, (value) {
      return _then(_value.copyWith(proposer: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AgendaItemImplCopyWith<$Res>
    implements $AgendaItemCopyWith<$Res> {
  factory _$$AgendaItemImplCopyWith(
    _$AgendaItemImpl value,
    $Res Function(_$AgendaItemImpl) then,
  ) = __$$AgendaItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) int? tenantId,
    String title,
    String? description,
    String status,
    String priority,
    @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
    int? responsiblePersonId,
    @JsonKey(name: 'default_duration', fromJson: _toInt) int? defaultDuration,
    @JsonKey(name: 'proposed_by', fromJson: _toInt) int? proposedBy,
    @JsonKey(name: 'proposal_status') String? proposalStatus,
    @JsonKey(name: 'decision_note') String? decisionNote,
    @JsonKey(name: 'created_at', fromJson: _toStr) String? createdAt,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'responsible_person') PersonRef? responsiblePerson,
    PersonRef? proposer,
  });

  @override
  $PersonRefCopyWith<$Res>? get responsiblePerson;
  @override
  $PersonRefCopyWith<$Res>? get proposer;
}

/// @nodoc
class __$$AgendaItemImplCopyWithImpl<$Res>
    extends _$AgendaItemCopyWithImpl<$Res, _$AgendaItemImpl>
    implements _$$AgendaItemImplCopyWith<$Res> {
  __$$AgendaItemImplCopyWithImpl(
    _$AgendaItemImpl _value,
    $Res Function(_$AgendaItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AgendaItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? title = null,
    Object? description = freezed,
    Object? status = null,
    Object? priority = null,
    Object? responsiblePersonId = freezed,
    Object? defaultDuration = freezed,
    Object? proposedBy = freezed,
    Object? proposalStatus = freezed,
    Object? decisionNote = freezed,
    Object? createdAt = freezed,
    Object? createdBy = freezed,
    Object? responsiblePerson = freezed,
    Object? proposer = freezed,
  }) {
    return _then(
      _$AgendaItemImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String?,
        tenantId:
            freezed == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int?,
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String?,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as String,
        priority:
            null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                    as String,
        responsiblePersonId:
            freezed == responsiblePersonId
                ? _value.responsiblePersonId
                : responsiblePersonId // ignore: cast_nullable_to_non_nullable
                    as int?,
        defaultDuration:
            freezed == defaultDuration
                ? _value.defaultDuration
                : defaultDuration // ignore: cast_nullable_to_non_nullable
                    as int?,
        proposedBy:
            freezed == proposedBy
                ? _value.proposedBy
                : proposedBy // ignore: cast_nullable_to_non_nullable
                    as int?,
        proposalStatus:
            freezed == proposalStatus
                ? _value.proposalStatus
                : proposalStatus // ignore: cast_nullable_to_non_nullable
                    as String?,
        decisionNote:
            freezed == decisionNote
                ? _value.decisionNote
                : decisionNote // ignore: cast_nullable_to_non_nullable
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
        responsiblePerson:
            freezed == responsiblePerson
                ? _value.responsiblePerson
                : responsiblePerson // ignore: cast_nullable_to_non_nullable
                    as PersonRef?,
        proposer:
            freezed == proposer
                ? _value.proposer
                : proposer // ignore: cast_nullable_to_non_nullable
                    as PersonRef?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AgendaItemImpl implements _AgendaItem {
  const _$AgendaItemImpl({
    this.id,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) this.tenantId,
    this.title = '',
    this.description,
    this.status = 'open',
    this.priority = 'medium',
    @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
    this.responsiblePersonId,
    @JsonKey(name: 'default_duration', fromJson: _toInt) this.defaultDuration,
    @JsonKey(name: 'proposed_by', fromJson: _toInt) this.proposedBy,
    @JsonKey(name: 'proposal_status') this.proposalStatus,
    @JsonKey(name: 'decision_note') this.decisionNote,
    @JsonKey(name: 'created_at', fromJson: _toStr) this.createdAt,
    @JsonKey(name: 'created_by') this.createdBy,
    @JsonKey(name: 'responsible_person') this.responsiblePerson,
    this.proposer,
  });

  factory _$AgendaItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgendaItemImplFromJson(json);

  @override
  final String? id;
  @override
  @JsonKey(name: 'tenant_id', fromJson: _toInt)
  final int? tenantId;
  @override
  @JsonKey()
  final String title;
  @override
  final String? description;

  /// open | completed | dropped
  @override
  @JsonKey()
  final String status;

  /// low | medium | high
  @override
  @JsonKey()
  final String priority;
  @override
  @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
  final int? responsiblePersonId;
  @override
  @JsonKey(name: 'default_duration', fromJson: _toInt)
  final int? defaultDuration;
  @override
  @JsonKey(name: 'proposed_by', fromJson: _toInt)
  final int? proposedBy;

  /// null | pending | accepted | rejected
  @override
  @JsonKey(name: 'proposal_status')
  final String? proposalStatus;
  @override
  @JsonKey(name: 'decision_note')
  final String? decisionNote;
  @override
  @JsonKey(name: 'created_at', fromJson: _toStr)
  final String? createdAt;
  @override
  @JsonKey(name: 'created_by')
  final String? createdBy;
  @override
  @JsonKey(name: 'responsible_person')
  final PersonRef? responsiblePerson;
  @override
  final PersonRef? proposer;

  @override
  String toString() {
    return 'AgendaItem(id: $id, tenantId: $tenantId, title: $title, description: $description, status: $status, priority: $priority, responsiblePersonId: $responsiblePersonId, defaultDuration: $defaultDuration, proposedBy: $proposedBy, proposalStatus: $proposalStatus, decisionNote: $decisionNote, createdAt: $createdAt, createdBy: $createdBy, responsiblePerson: $responsiblePerson, proposer: $proposer)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgendaItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.responsiblePersonId, responsiblePersonId) ||
                other.responsiblePersonId == responsiblePersonId) &&
            (identical(other.defaultDuration, defaultDuration) ||
                other.defaultDuration == defaultDuration) &&
            (identical(other.proposedBy, proposedBy) ||
                other.proposedBy == proposedBy) &&
            (identical(other.proposalStatus, proposalStatus) ||
                other.proposalStatus == proposalStatus) &&
            (identical(other.decisionNote, decisionNote) ||
                other.decisionNote == decisionNote) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.responsiblePerson, responsiblePerson) ||
                other.responsiblePerson == responsiblePerson) &&
            (identical(other.proposer, proposer) ||
                other.proposer == proposer));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tenantId,
    title,
    description,
    status,
    priority,
    responsiblePersonId,
    defaultDuration,
    proposedBy,
    proposalStatus,
    decisionNote,
    createdAt,
    createdBy,
    responsiblePerson,
    proposer,
  );

  /// Create a copy of AgendaItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgendaItemImplCopyWith<_$AgendaItemImpl> get copyWith =>
      __$$AgendaItemImplCopyWithImpl<_$AgendaItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AgendaItemImplToJson(this);
  }
}

abstract class _AgendaItem implements AgendaItem {
  const factory _AgendaItem({
    final String? id,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) final int? tenantId,
    final String title,
    final String? description,
    final String status,
    final String priority,
    @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
    final int? responsiblePersonId,
    @JsonKey(name: 'default_duration', fromJson: _toInt)
    final int? defaultDuration,
    @JsonKey(name: 'proposed_by', fromJson: _toInt) final int? proposedBy,
    @JsonKey(name: 'proposal_status') final String? proposalStatus,
    @JsonKey(name: 'decision_note') final String? decisionNote,
    @JsonKey(name: 'created_at', fromJson: _toStr) final String? createdAt,
    @JsonKey(name: 'created_by') final String? createdBy,
    @JsonKey(name: 'responsible_person') final PersonRef? responsiblePerson,
    final PersonRef? proposer,
  }) = _$AgendaItemImpl;

  factory _AgendaItem.fromJson(Map<String, dynamic> json) =
      _$AgendaItemImpl.fromJson;

  @override
  String? get id;
  @override
  @JsonKey(name: 'tenant_id', fromJson: _toInt)
  int? get tenantId;
  @override
  String get title;
  @override
  String? get description;

  /// open | completed | dropped
  @override
  String get status;

  /// low | medium | high
  @override
  String get priority;
  @override
  @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
  int? get responsiblePersonId;
  @override
  @JsonKey(name: 'default_duration', fromJson: _toInt)
  int? get defaultDuration;
  @override
  @JsonKey(name: 'proposed_by', fromJson: _toInt)
  int? get proposedBy;

  /// null | pending | accepted | rejected
  @override
  @JsonKey(name: 'proposal_status')
  String? get proposalStatus;
  @override
  @JsonKey(name: 'decision_note')
  String? get decisionNote;
  @override
  @JsonKey(name: 'created_at', fromJson: _toStr)
  String? get createdAt;
  @override
  @JsonKey(name: 'created_by')
  String? get createdBy;
  @override
  @JsonKey(name: 'responsible_person')
  PersonRef? get responsiblePerson;
  @override
  PersonRef? get proposer;

  /// Create a copy of AgendaItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgendaItemImplCopyWith<_$AgendaItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AgendaItemHistoryEntry _$AgendaItemHistoryEntryFromJson(
  Map<String, dynamic> json,
) {
  return _AgendaItemHistoryEntry.fromJson(json);
}

/// @nodoc
mixin _$AgendaItemHistoryEntry {
  @JsonKey(name: 'attendance_id', fromJson: _toInt)
  int? get attendanceId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _toStr)
  String? get date => throw _privateConstructorUsedError;
  @JsonKey(name: 'type_id')
  String? get typeId => throw _privateConstructorUsedError;
  @JsonKey(name: 'type_info')
  String? get typeInfo => throw _privateConstructorUsedError;
  @JsonKey(name: 'field_id')
  String? get fieldId => throw _privateConstructorUsedError;

  /// discussed | decided | postponed
  String? get outcome => throw _privateConstructorUsedError;
  @JsonKey(name: 'protocol_status')
  String? get protocolStatus => throw _privateConstructorUsedError;

  /// Serializes this AgendaItemHistoryEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AgendaItemHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgendaItemHistoryEntryCopyWith<AgendaItemHistoryEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgendaItemHistoryEntryCopyWith<$Res> {
  factory $AgendaItemHistoryEntryCopyWith(
    AgendaItemHistoryEntry value,
    $Res Function(AgendaItemHistoryEntry) then,
  ) = _$AgendaItemHistoryEntryCopyWithImpl<$Res, AgendaItemHistoryEntry>;
  @useResult
  $Res call({
    @JsonKey(name: 'attendance_id', fromJson: _toInt) int? attendanceId,
    @JsonKey(fromJson: _toStr) String? date,
    @JsonKey(name: 'type_id') String? typeId,
    @JsonKey(name: 'type_info') String? typeInfo,
    @JsonKey(name: 'field_id') String? fieldId,
    String? outcome,
    @JsonKey(name: 'protocol_status') String? protocolStatus,
  });
}

/// @nodoc
class _$AgendaItemHistoryEntryCopyWithImpl<
  $Res,
  $Val extends AgendaItemHistoryEntry
>
    implements $AgendaItemHistoryEntryCopyWith<$Res> {
  _$AgendaItemHistoryEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgendaItemHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? attendanceId = freezed,
    Object? date = freezed,
    Object? typeId = freezed,
    Object? typeInfo = freezed,
    Object? fieldId = freezed,
    Object? outcome = freezed,
    Object? protocolStatus = freezed,
  }) {
    return _then(
      _value.copyWith(
            attendanceId:
                freezed == attendanceId
                    ? _value.attendanceId
                    : attendanceId // ignore: cast_nullable_to_non_nullable
                        as int?,
            date:
                freezed == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as String?,
            typeId:
                freezed == typeId
                    ? _value.typeId
                    : typeId // ignore: cast_nullable_to_non_nullable
                        as String?,
            typeInfo:
                freezed == typeInfo
                    ? _value.typeInfo
                    : typeInfo // ignore: cast_nullable_to_non_nullable
                        as String?,
            fieldId:
                freezed == fieldId
                    ? _value.fieldId
                    : fieldId // ignore: cast_nullable_to_non_nullable
                        as String?,
            outcome:
                freezed == outcome
                    ? _value.outcome
                    : outcome // ignore: cast_nullable_to_non_nullable
                        as String?,
            protocolStatus:
                freezed == protocolStatus
                    ? _value.protocolStatus
                    : protocolStatus // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AgendaItemHistoryEntryImplCopyWith<$Res>
    implements $AgendaItemHistoryEntryCopyWith<$Res> {
  factory _$$AgendaItemHistoryEntryImplCopyWith(
    _$AgendaItemHistoryEntryImpl value,
    $Res Function(_$AgendaItemHistoryEntryImpl) then,
  ) = __$$AgendaItemHistoryEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'attendance_id', fromJson: _toInt) int? attendanceId,
    @JsonKey(fromJson: _toStr) String? date,
    @JsonKey(name: 'type_id') String? typeId,
    @JsonKey(name: 'type_info') String? typeInfo,
    @JsonKey(name: 'field_id') String? fieldId,
    String? outcome,
    @JsonKey(name: 'protocol_status') String? protocolStatus,
  });
}

/// @nodoc
class __$$AgendaItemHistoryEntryImplCopyWithImpl<$Res>
    extends
        _$AgendaItemHistoryEntryCopyWithImpl<$Res, _$AgendaItemHistoryEntryImpl>
    implements _$$AgendaItemHistoryEntryImplCopyWith<$Res> {
  __$$AgendaItemHistoryEntryImplCopyWithImpl(
    _$AgendaItemHistoryEntryImpl _value,
    $Res Function(_$AgendaItemHistoryEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AgendaItemHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? attendanceId = freezed,
    Object? date = freezed,
    Object? typeId = freezed,
    Object? typeInfo = freezed,
    Object? fieldId = freezed,
    Object? outcome = freezed,
    Object? protocolStatus = freezed,
  }) {
    return _then(
      _$AgendaItemHistoryEntryImpl(
        attendanceId:
            freezed == attendanceId
                ? _value.attendanceId
                : attendanceId // ignore: cast_nullable_to_non_nullable
                    as int?,
        date:
            freezed == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as String?,
        typeId:
            freezed == typeId
                ? _value.typeId
                : typeId // ignore: cast_nullable_to_non_nullable
                    as String?,
        typeInfo:
            freezed == typeInfo
                ? _value.typeInfo
                : typeInfo // ignore: cast_nullable_to_non_nullable
                    as String?,
        fieldId:
            freezed == fieldId
                ? _value.fieldId
                : fieldId // ignore: cast_nullable_to_non_nullable
                    as String?,
        outcome:
            freezed == outcome
                ? _value.outcome
                : outcome // ignore: cast_nullable_to_non_nullable
                    as String?,
        protocolStatus:
            freezed == protocolStatus
                ? _value.protocolStatus
                : protocolStatus // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AgendaItemHistoryEntryImpl implements _AgendaItemHistoryEntry {
  const _$AgendaItemHistoryEntryImpl({
    @JsonKey(name: 'attendance_id', fromJson: _toInt) this.attendanceId,
    @JsonKey(fromJson: _toStr) this.date,
    @JsonKey(name: 'type_id') this.typeId,
    @JsonKey(name: 'type_info') this.typeInfo,
    @JsonKey(name: 'field_id') this.fieldId,
    this.outcome,
    @JsonKey(name: 'protocol_status') this.protocolStatus,
  });

  factory _$AgendaItemHistoryEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgendaItemHistoryEntryImplFromJson(json);

  @override
  @JsonKey(name: 'attendance_id', fromJson: _toInt)
  final int? attendanceId;
  @override
  @JsonKey(fromJson: _toStr)
  final String? date;
  @override
  @JsonKey(name: 'type_id')
  final String? typeId;
  @override
  @JsonKey(name: 'type_info')
  final String? typeInfo;
  @override
  @JsonKey(name: 'field_id')
  final String? fieldId;

  /// discussed | decided | postponed
  @override
  final String? outcome;
  @override
  @JsonKey(name: 'protocol_status')
  final String? protocolStatus;

  @override
  String toString() {
    return 'AgendaItemHistoryEntry(attendanceId: $attendanceId, date: $date, typeId: $typeId, typeInfo: $typeInfo, fieldId: $fieldId, outcome: $outcome, protocolStatus: $protocolStatus)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgendaItemHistoryEntryImpl &&
            (identical(other.attendanceId, attendanceId) ||
                other.attendanceId == attendanceId) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.typeId, typeId) || other.typeId == typeId) &&
            (identical(other.typeInfo, typeInfo) ||
                other.typeInfo == typeInfo) &&
            (identical(other.fieldId, fieldId) || other.fieldId == fieldId) &&
            (identical(other.outcome, outcome) || other.outcome == outcome) &&
            (identical(other.protocolStatus, protocolStatus) ||
                other.protocolStatus == protocolStatus));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    attendanceId,
    date,
    typeId,
    typeInfo,
    fieldId,
    outcome,
    protocolStatus,
  );

  /// Create a copy of AgendaItemHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgendaItemHistoryEntryImplCopyWith<_$AgendaItemHistoryEntryImpl>
  get copyWith =>
      __$$AgendaItemHistoryEntryImplCopyWithImpl<_$AgendaItemHistoryEntryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AgendaItemHistoryEntryImplToJson(this);
  }
}

abstract class _AgendaItemHistoryEntry implements AgendaItemHistoryEntry {
  const factory _AgendaItemHistoryEntry({
    @JsonKey(name: 'attendance_id', fromJson: _toInt) final int? attendanceId,
    @JsonKey(fromJson: _toStr) final String? date,
    @JsonKey(name: 'type_id') final String? typeId,
    @JsonKey(name: 'type_info') final String? typeInfo,
    @JsonKey(name: 'field_id') final String? fieldId,
    final String? outcome,
    @JsonKey(name: 'protocol_status') final String? protocolStatus,
  }) = _$AgendaItemHistoryEntryImpl;

  factory _AgendaItemHistoryEntry.fromJson(Map<String, dynamic> json) =
      _$AgendaItemHistoryEntryImpl.fromJson;

  @override
  @JsonKey(name: 'attendance_id', fromJson: _toInt)
  int? get attendanceId;
  @override
  @JsonKey(fromJson: _toStr)
  String? get date;
  @override
  @JsonKey(name: 'type_id')
  String? get typeId;
  @override
  @JsonKey(name: 'type_info')
  String? get typeInfo;
  @override
  @JsonKey(name: 'field_id')
  String? get fieldId;

  /// discussed | decided | postponed
  @override
  String? get outcome;
  @override
  @JsonKey(name: 'protocol_status')
  String? get protocolStatus;

  /// Create a copy of AgendaItemHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgendaItemHistoryEntryImplCopyWith<_$AgendaItemHistoryEntryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AgendaItemRef _$AgendaItemRefFromJson(Map<String, dynamic> json) {
  return _AgendaItemRef.fromJson(json);
}

/// @nodoc
mixin _$AgendaItemRef {
  String? get id => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;

  /// Serializes this AgendaItemRef to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AgendaItemRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgendaItemRefCopyWith<AgendaItemRef> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgendaItemRefCopyWith<$Res> {
  factory $AgendaItemRefCopyWith(
    AgendaItemRef value,
    $Res Function(AgendaItemRef) then,
  ) = _$AgendaItemRefCopyWithImpl<$Res, AgendaItemRef>;
  @useResult
  $Res call({String? id, String? title});
}

/// @nodoc
class _$AgendaItemRefCopyWithImpl<$Res, $Val extends AgendaItemRef>
    implements $AgendaItemRefCopyWith<$Res> {
  _$AgendaItemRefCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgendaItemRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = freezed, Object? title = freezed}) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String?,
            title:
                freezed == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AgendaItemRefImplCopyWith<$Res>
    implements $AgendaItemRefCopyWith<$Res> {
  factory _$$AgendaItemRefImplCopyWith(
    _$AgendaItemRefImpl value,
    $Res Function(_$AgendaItemRefImpl) then,
  ) = __$$AgendaItemRefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? id, String? title});
}

/// @nodoc
class __$$AgendaItemRefImplCopyWithImpl<$Res>
    extends _$AgendaItemRefCopyWithImpl<$Res, _$AgendaItemRefImpl>
    implements _$$AgendaItemRefImplCopyWith<$Res> {
  __$$AgendaItemRefImplCopyWithImpl(
    _$AgendaItemRefImpl _value,
    $Res Function(_$AgendaItemRefImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AgendaItemRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = freezed, Object? title = freezed}) {
    return _then(
      _$AgendaItemRefImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String?,
        title:
            freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AgendaItemRefImpl implements _AgendaItemRef {
  const _$AgendaItemRefImpl({this.id, this.title});

  factory _$AgendaItemRefImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgendaItemRefImplFromJson(json);

  @override
  final String? id;
  @override
  final String? title;

  @override
  String toString() {
    return 'AgendaItemRef(id: $id, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgendaItemRefImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title);

  /// Create a copy of AgendaItemRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgendaItemRefImplCopyWith<_$AgendaItemRefImpl> get copyWith =>
      __$$AgendaItemRefImplCopyWithImpl<_$AgendaItemRefImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AgendaItemRefImplToJson(this);
  }
}

abstract class _AgendaItemRef implements AgendaItemRef {
  const factory _AgendaItemRef({final String? id, final String? title}) =
      _$AgendaItemRefImpl;

  factory _AgendaItemRef.fromJson(Map<String, dynamic> json) =
      _$AgendaItemRefImpl.fromJson;

  @override
  String? get id;
  @override
  String? get title;

  /// Create a copy of AgendaItemRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgendaItemRefImplCopyWith<_$AgendaItemRefImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AttendanceRef _$AttendanceRefFromJson(Map<String, dynamic> json) {
  return _AttendanceRef.fromJson(json);
}

/// @nodoc
mixin _$AttendanceRef {
  @JsonKey(fromJson: _toInt)
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _toStr)
  String? get date => throw _privateConstructorUsedError;
  String? get typeInfo => throw _privateConstructorUsedError;
  @JsonKey(name: 'type_id')
  String? get typeId => throw _privateConstructorUsedError;

  /// Serializes this AttendanceRef to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AttendanceRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttendanceRefCopyWith<AttendanceRef> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceRefCopyWith<$Res> {
  factory $AttendanceRefCopyWith(
    AttendanceRef value,
    $Res Function(AttendanceRef) then,
  ) = _$AttendanceRefCopyWithImpl<$Res, AttendanceRef>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _toInt) int? id,
    @JsonKey(fromJson: _toStr) String? date,
    String? typeInfo,
    @JsonKey(name: 'type_id') String? typeId,
  });
}

/// @nodoc
class _$AttendanceRefCopyWithImpl<$Res, $Val extends AttendanceRef>
    implements $AttendanceRefCopyWith<$Res> {
  _$AttendanceRefCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttendanceRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? date = freezed,
    Object? typeInfo = freezed,
    Object? typeId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as int?,
            date:
                freezed == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as String?,
            typeInfo:
                freezed == typeInfo
                    ? _value.typeInfo
                    : typeInfo // ignore: cast_nullable_to_non_nullable
                        as String?,
            typeId:
                freezed == typeId
                    ? _value.typeId
                    : typeId // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AttendanceRefImplCopyWith<$Res>
    implements $AttendanceRefCopyWith<$Res> {
  factory _$$AttendanceRefImplCopyWith(
    _$AttendanceRefImpl value,
    $Res Function(_$AttendanceRefImpl) then,
  ) = __$$AttendanceRefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _toInt) int? id,
    @JsonKey(fromJson: _toStr) String? date,
    String? typeInfo,
    @JsonKey(name: 'type_id') String? typeId,
  });
}

/// @nodoc
class __$$AttendanceRefImplCopyWithImpl<$Res>
    extends _$AttendanceRefCopyWithImpl<$Res, _$AttendanceRefImpl>
    implements _$$AttendanceRefImplCopyWith<$Res> {
  __$$AttendanceRefImplCopyWithImpl(
    _$AttendanceRefImpl _value,
    $Res Function(_$AttendanceRefImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AttendanceRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? date = freezed,
    Object? typeInfo = freezed,
    Object? typeId = freezed,
  }) {
    return _then(
      _$AttendanceRefImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as int?,
        date:
            freezed == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as String?,
        typeInfo:
            freezed == typeInfo
                ? _value.typeInfo
                : typeInfo // ignore: cast_nullable_to_non_nullable
                    as String?,
        typeId:
            freezed == typeId
                ? _value.typeId
                : typeId // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AttendanceRefImpl implements _AttendanceRef {
  const _$AttendanceRefImpl({
    @JsonKey(fromJson: _toInt) this.id,
    @JsonKey(fromJson: _toStr) this.date,
    this.typeInfo,
    @JsonKey(name: 'type_id') this.typeId,
  });

  factory _$AttendanceRefImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttendanceRefImplFromJson(json);

  @override
  @JsonKey(fromJson: _toInt)
  final int? id;
  @override
  @JsonKey(fromJson: _toStr)
  final String? date;
  @override
  final String? typeInfo;
  @override
  @JsonKey(name: 'type_id')
  final String? typeId;

  @override
  String toString() {
    return 'AttendanceRef(id: $id, date: $date, typeInfo: $typeInfo, typeId: $typeId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceRefImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.typeInfo, typeInfo) ||
                other.typeInfo == typeInfo) &&
            (identical(other.typeId, typeId) || other.typeId == typeId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, date, typeInfo, typeId);

  /// Create a copy of AttendanceRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendanceRefImplCopyWith<_$AttendanceRefImpl> get copyWith =>
      __$$AttendanceRefImplCopyWithImpl<_$AttendanceRefImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttendanceRefImplToJson(this);
  }
}

abstract class _AttendanceRef implements AttendanceRef {
  const factory _AttendanceRef({
    @JsonKey(fromJson: _toInt) final int? id,
    @JsonKey(fromJson: _toStr) final String? date,
    final String? typeInfo,
    @JsonKey(name: 'type_id') final String? typeId,
  }) = _$AttendanceRefImpl;

  factory _AttendanceRef.fromJson(Map<String, dynamic> json) =
      _$AttendanceRefImpl.fromJson;

  @override
  @JsonKey(fromJson: _toInt)
  int? get id;
  @override
  @JsonKey(fromJson: _toStr)
  String? get date;
  @override
  String? get typeInfo;
  @override
  @JsonKey(name: 'type_id')
  String? get typeId;

  /// Create a copy of AttendanceRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendanceRefImplCopyWith<_$AttendanceRefImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TeamTask _$TeamTaskFromJson(Map<String, dynamic> json) {
  return _TeamTask.fromJson(json);
}

/// @nodoc
mixin _$TeamTask {
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id', fromJson: _toInt)
  int? get tenantId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
  int? get responsiblePersonId => throw _privateConstructorUsedError;

  /// low | medium | high
  String get priority => throw _privateConstructorUsedError;

  /// YYYY-MM-DD
  @JsonKey(name: 'due_date')
  String? get dueDate => throw _privateConstructorUsedError;

  /// open | in_progress | completed
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'agenda_item_id')
  String? get agendaItemId => throw _privateConstructorUsedError;
  @JsonKey(name: 'protocol_id')
  String? get protocolId => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_id', fromJson: _toInt)
  int? get attendanceId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at', fromJson: _toStr)
  String? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at', fromJson: _toStr)
  String? get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'completed_at', fromJson: _toStr)
  String? get completedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'responsible_person')
  PersonRef? get responsiblePerson => throw _privateConstructorUsedError;
  @JsonKey(name: 'agenda_item')
  AgendaItemRef? get agendaItem => throw _privateConstructorUsedError;
  AttendanceRef? get attendance => throw _privateConstructorUsedError;

  /// Serializes this TeamTask to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TeamTask
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeamTaskCopyWith<TeamTask> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeamTaskCopyWith<$Res> {
  factory $TeamTaskCopyWith(TeamTask value, $Res Function(TeamTask) then) =
      _$TeamTaskCopyWithImpl<$Res, TeamTask>;
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) int? tenantId,
    String title,
    String? description,
    @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
    int? responsiblePersonId,
    String priority,
    @JsonKey(name: 'due_date') String? dueDate,
    String status,
    @JsonKey(name: 'agenda_item_id') String? agendaItemId,
    @JsonKey(name: 'protocol_id') String? protocolId,
    @JsonKey(name: 'attendance_id', fromJson: _toInt) int? attendanceId,
    @JsonKey(name: 'created_at', fromJson: _toStr) String? createdAt,
    @JsonKey(name: 'updated_at', fromJson: _toStr) String? updatedAt,
    @JsonKey(name: 'completed_at', fromJson: _toStr) String? completedAt,
    @JsonKey(name: 'responsible_person') PersonRef? responsiblePerson,
    @JsonKey(name: 'agenda_item') AgendaItemRef? agendaItem,
    AttendanceRef? attendance,
  });

  $PersonRefCopyWith<$Res>? get responsiblePerson;
  $AgendaItemRefCopyWith<$Res>? get agendaItem;
  $AttendanceRefCopyWith<$Res>? get attendance;
}

/// @nodoc
class _$TeamTaskCopyWithImpl<$Res, $Val extends TeamTask>
    implements $TeamTaskCopyWith<$Res> {
  _$TeamTaskCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeamTask
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? title = null,
    Object? description = freezed,
    Object? responsiblePersonId = freezed,
    Object? priority = null,
    Object? dueDate = freezed,
    Object? status = null,
    Object? agendaItemId = freezed,
    Object? protocolId = freezed,
    Object? attendanceId = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? completedAt = freezed,
    Object? responsiblePerson = freezed,
    Object? agendaItem = freezed,
    Object? attendance = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String?,
            tenantId:
                freezed == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int?,
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                freezed == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String?,
            responsiblePersonId:
                freezed == responsiblePersonId
                    ? _value.responsiblePersonId
                    : responsiblePersonId // ignore: cast_nullable_to_non_nullable
                        as int?,
            priority:
                null == priority
                    ? _value.priority
                    : priority // ignore: cast_nullable_to_non_nullable
                        as String,
            dueDate:
                freezed == dueDate
                    ? _value.dueDate
                    : dueDate // ignore: cast_nullable_to_non_nullable
                        as String?,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as String,
            agendaItemId:
                freezed == agendaItemId
                    ? _value.agendaItemId
                    : agendaItemId // ignore: cast_nullable_to_non_nullable
                        as String?,
            protocolId:
                freezed == protocolId
                    ? _value.protocolId
                    : protocolId // ignore: cast_nullable_to_non_nullable
                        as String?,
            attendanceId:
                freezed == attendanceId
                    ? _value.attendanceId
                    : attendanceId // ignore: cast_nullable_to_non_nullable
                        as int?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as String?,
            updatedAt:
                freezed == updatedAt
                    ? _value.updatedAt
                    : updatedAt // ignore: cast_nullable_to_non_nullable
                        as String?,
            completedAt:
                freezed == completedAt
                    ? _value.completedAt
                    : completedAt // ignore: cast_nullable_to_non_nullable
                        as String?,
            responsiblePerson:
                freezed == responsiblePerson
                    ? _value.responsiblePerson
                    : responsiblePerson // ignore: cast_nullable_to_non_nullable
                        as PersonRef?,
            agendaItem:
                freezed == agendaItem
                    ? _value.agendaItem
                    : agendaItem // ignore: cast_nullable_to_non_nullable
                        as AgendaItemRef?,
            attendance:
                freezed == attendance
                    ? _value.attendance
                    : attendance // ignore: cast_nullable_to_non_nullable
                        as AttendanceRef?,
          )
          as $Val,
    );
  }

  /// Create a copy of TeamTask
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PersonRefCopyWith<$Res>? get responsiblePerson {
    if (_value.responsiblePerson == null) {
      return null;
    }

    return $PersonRefCopyWith<$Res>(_value.responsiblePerson!, (value) {
      return _then(_value.copyWith(responsiblePerson: value) as $Val);
    });
  }

  /// Create a copy of TeamTask
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AgendaItemRefCopyWith<$Res>? get agendaItem {
    if (_value.agendaItem == null) {
      return null;
    }

    return $AgendaItemRefCopyWith<$Res>(_value.agendaItem!, (value) {
      return _then(_value.copyWith(agendaItem: value) as $Val);
    });
  }

  /// Create a copy of TeamTask
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AttendanceRefCopyWith<$Res>? get attendance {
    if (_value.attendance == null) {
      return null;
    }

    return $AttendanceRefCopyWith<$Res>(_value.attendance!, (value) {
      return _then(_value.copyWith(attendance: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TeamTaskImplCopyWith<$Res>
    implements $TeamTaskCopyWith<$Res> {
  factory _$$TeamTaskImplCopyWith(
    _$TeamTaskImpl value,
    $Res Function(_$TeamTaskImpl) then,
  ) = __$$TeamTaskImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) int? tenantId,
    String title,
    String? description,
    @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
    int? responsiblePersonId,
    String priority,
    @JsonKey(name: 'due_date') String? dueDate,
    String status,
    @JsonKey(name: 'agenda_item_id') String? agendaItemId,
    @JsonKey(name: 'protocol_id') String? protocolId,
    @JsonKey(name: 'attendance_id', fromJson: _toInt) int? attendanceId,
    @JsonKey(name: 'created_at', fromJson: _toStr) String? createdAt,
    @JsonKey(name: 'updated_at', fromJson: _toStr) String? updatedAt,
    @JsonKey(name: 'completed_at', fromJson: _toStr) String? completedAt,
    @JsonKey(name: 'responsible_person') PersonRef? responsiblePerson,
    @JsonKey(name: 'agenda_item') AgendaItemRef? agendaItem,
    AttendanceRef? attendance,
  });

  @override
  $PersonRefCopyWith<$Res>? get responsiblePerson;
  @override
  $AgendaItemRefCopyWith<$Res>? get agendaItem;
  @override
  $AttendanceRefCopyWith<$Res>? get attendance;
}

/// @nodoc
class __$$TeamTaskImplCopyWithImpl<$Res>
    extends _$TeamTaskCopyWithImpl<$Res, _$TeamTaskImpl>
    implements _$$TeamTaskImplCopyWith<$Res> {
  __$$TeamTaskImplCopyWithImpl(
    _$TeamTaskImpl _value,
    $Res Function(_$TeamTaskImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TeamTask
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? title = null,
    Object? description = freezed,
    Object? responsiblePersonId = freezed,
    Object? priority = null,
    Object? dueDate = freezed,
    Object? status = null,
    Object? agendaItemId = freezed,
    Object? protocolId = freezed,
    Object? attendanceId = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? completedAt = freezed,
    Object? responsiblePerson = freezed,
    Object? agendaItem = freezed,
    Object? attendance = freezed,
  }) {
    return _then(
      _$TeamTaskImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String?,
        tenantId:
            freezed == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int?,
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String?,
        responsiblePersonId:
            freezed == responsiblePersonId
                ? _value.responsiblePersonId
                : responsiblePersonId // ignore: cast_nullable_to_non_nullable
                    as int?,
        priority:
            null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                    as String,
        dueDate:
            freezed == dueDate
                ? _value.dueDate
                : dueDate // ignore: cast_nullable_to_non_nullable
                    as String?,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as String,
        agendaItemId:
            freezed == agendaItemId
                ? _value.agendaItemId
                : agendaItemId // ignore: cast_nullable_to_non_nullable
                    as String?,
        protocolId:
            freezed == protocolId
                ? _value.protocolId
                : protocolId // ignore: cast_nullable_to_non_nullable
                    as String?,
        attendanceId:
            freezed == attendanceId
                ? _value.attendanceId
                : attendanceId // ignore: cast_nullable_to_non_nullable
                    as int?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as String?,
        updatedAt:
            freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                    as String?,
        completedAt:
            freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                    as String?,
        responsiblePerson:
            freezed == responsiblePerson
                ? _value.responsiblePerson
                : responsiblePerson // ignore: cast_nullable_to_non_nullable
                    as PersonRef?,
        agendaItem:
            freezed == agendaItem
                ? _value.agendaItem
                : agendaItem // ignore: cast_nullable_to_non_nullable
                    as AgendaItemRef?,
        attendance:
            freezed == attendance
                ? _value.attendance
                : attendance // ignore: cast_nullable_to_non_nullable
                    as AttendanceRef?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TeamTaskImpl implements _TeamTask {
  const _$TeamTaskImpl({
    this.id,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) this.tenantId,
    this.title = '',
    this.description,
    @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
    this.responsiblePersonId,
    this.priority = 'medium',
    @JsonKey(name: 'due_date') this.dueDate,
    this.status = 'open',
    @JsonKey(name: 'agenda_item_id') this.agendaItemId,
    @JsonKey(name: 'protocol_id') this.protocolId,
    @JsonKey(name: 'attendance_id', fromJson: _toInt) this.attendanceId,
    @JsonKey(name: 'created_at', fromJson: _toStr) this.createdAt,
    @JsonKey(name: 'updated_at', fromJson: _toStr) this.updatedAt,
    @JsonKey(name: 'completed_at', fromJson: _toStr) this.completedAt,
    @JsonKey(name: 'responsible_person') this.responsiblePerson,
    @JsonKey(name: 'agenda_item') this.agendaItem,
    this.attendance,
  });

  factory _$TeamTaskImpl.fromJson(Map<String, dynamic> json) =>
      _$$TeamTaskImplFromJson(json);

  @override
  final String? id;
  @override
  @JsonKey(name: 'tenant_id', fromJson: _toInt)
  final int? tenantId;
  @override
  @JsonKey()
  final String title;
  @override
  final String? description;
  @override
  @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
  final int? responsiblePersonId;

  /// low | medium | high
  @override
  @JsonKey()
  final String priority;

  /// YYYY-MM-DD
  @override
  @JsonKey(name: 'due_date')
  final String? dueDate;

  /// open | in_progress | completed
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey(name: 'agenda_item_id')
  final String? agendaItemId;
  @override
  @JsonKey(name: 'protocol_id')
  final String? protocolId;
  @override
  @JsonKey(name: 'attendance_id', fromJson: _toInt)
  final int? attendanceId;
  @override
  @JsonKey(name: 'created_at', fromJson: _toStr)
  final String? createdAt;
  @override
  @JsonKey(name: 'updated_at', fromJson: _toStr)
  final String? updatedAt;
  @override
  @JsonKey(name: 'completed_at', fromJson: _toStr)
  final String? completedAt;
  @override
  @JsonKey(name: 'responsible_person')
  final PersonRef? responsiblePerson;
  @override
  @JsonKey(name: 'agenda_item')
  final AgendaItemRef? agendaItem;
  @override
  final AttendanceRef? attendance;

  @override
  String toString() {
    return 'TeamTask(id: $id, tenantId: $tenantId, title: $title, description: $description, responsiblePersonId: $responsiblePersonId, priority: $priority, dueDate: $dueDate, status: $status, agendaItemId: $agendaItemId, protocolId: $protocolId, attendanceId: $attendanceId, createdAt: $createdAt, updatedAt: $updatedAt, completedAt: $completedAt, responsiblePerson: $responsiblePerson, agendaItem: $agendaItem, attendance: $attendance)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeamTaskImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.responsiblePersonId, responsiblePersonId) ||
                other.responsiblePersonId == responsiblePersonId) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.agendaItemId, agendaItemId) ||
                other.agendaItemId == agendaItemId) &&
            (identical(other.protocolId, protocolId) ||
                other.protocolId == protocolId) &&
            (identical(other.attendanceId, attendanceId) ||
                other.attendanceId == attendanceId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.responsiblePerson, responsiblePerson) ||
                other.responsiblePerson == responsiblePerson) &&
            (identical(other.agendaItem, agendaItem) ||
                other.agendaItem == agendaItem) &&
            (identical(other.attendance, attendance) ||
                other.attendance == attendance));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tenantId,
    title,
    description,
    responsiblePersonId,
    priority,
    dueDate,
    status,
    agendaItemId,
    protocolId,
    attendanceId,
    createdAt,
    updatedAt,
    completedAt,
    responsiblePerson,
    agendaItem,
    attendance,
  );

  /// Create a copy of TeamTask
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeamTaskImplCopyWith<_$TeamTaskImpl> get copyWith =>
      __$$TeamTaskImplCopyWithImpl<_$TeamTaskImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TeamTaskImplToJson(this);
  }
}

abstract class _TeamTask implements TeamTask {
  const factory _TeamTask({
    final String? id,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) final int? tenantId,
    final String title,
    final String? description,
    @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
    final int? responsiblePersonId,
    final String priority,
    @JsonKey(name: 'due_date') final String? dueDate,
    final String status,
    @JsonKey(name: 'agenda_item_id') final String? agendaItemId,
    @JsonKey(name: 'protocol_id') final String? protocolId,
    @JsonKey(name: 'attendance_id', fromJson: _toInt) final int? attendanceId,
    @JsonKey(name: 'created_at', fromJson: _toStr) final String? createdAt,
    @JsonKey(name: 'updated_at', fromJson: _toStr) final String? updatedAt,
    @JsonKey(name: 'completed_at', fromJson: _toStr) final String? completedAt,
    @JsonKey(name: 'responsible_person') final PersonRef? responsiblePerson,
    @JsonKey(name: 'agenda_item') final AgendaItemRef? agendaItem,
    final AttendanceRef? attendance,
  }) = _$TeamTaskImpl;

  factory _TeamTask.fromJson(Map<String, dynamic> json) =
      _$TeamTaskImpl.fromJson;

  @override
  String? get id;
  @override
  @JsonKey(name: 'tenant_id', fromJson: _toInt)
  int? get tenantId;
  @override
  String get title;
  @override
  String? get description;
  @override
  @JsonKey(name: 'responsible_person_id', fromJson: _toInt)
  int? get responsiblePersonId;

  /// low | medium | high
  @override
  String get priority;

  /// YYYY-MM-DD
  @override
  @JsonKey(name: 'due_date')
  String? get dueDate;

  /// open | in_progress | completed
  @override
  String get status;
  @override
  @JsonKey(name: 'agenda_item_id')
  String? get agendaItemId;
  @override
  @JsonKey(name: 'protocol_id')
  String? get protocolId;
  @override
  @JsonKey(name: 'attendance_id', fromJson: _toInt)
  int? get attendanceId;
  @override
  @JsonKey(name: 'created_at', fromJson: _toStr)
  String? get createdAt;
  @override
  @JsonKey(name: 'updated_at', fromJson: _toStr)
  String? get updatedAt;
  @override
  @JsonKey(name: 'completed_at', fromJson: _toStr)
  String? get completedAt;
  @override
  @JsonKey(name: 'responsible_person')
  PersonRef? get responsiblePerson;
  @override
  @JsonKey(name: 'agenda_item')
  AgendaItemRef? get agendaItem;
  @override
  AttendanceRef? get attendance;

  /// Create a copy of TeamTask
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeamTaskImplCopyWith<_$TeamTaskImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Protocol _$ProtocolFromJson(Map<String, dynamic> json) {
  return _Protocol.fromJson(json);
}

/// @nodoc
mixin _$Protocol {
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_id', fromJson: _toInt)
  int? get attendanceId => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id', fromJson: _toInt)
  int? get tenantId => throw _privateConstructorUsedError;

  /// Tiptap JSON doc per plan field id (+ `__general__`).
  Map<String, dynamic> get content => throw _privateConstructorUsedError;

  /// Outcome per field id: discussed | decided | postponed
  Map<String, dynamic> get outcomes => throw _privateConstructorUsedError;

  /// draft | published
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at', fromJson: _toStr)
  String? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at', fromJson: _toStr)
  String? get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'published_at', fromJson: _toStr)
  String? get publishedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'published_by')
  String? get publishedBy => throw _privateConstructorUsedError;
  AttendanceRef? get attendance => throw _privateConstructorUsedError;

  /// Serializes this Protocol to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Protocol
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProtocolCopyWith<Protocol> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProtocolCopyWith<$Res> {
  factory $ProtocolCopyWith(Protocol value, $Res Function(Protocol) then) =
      _$ProtocolCopyWithImpl<$Res, Protocol>;
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'attendance_id', fromJson: _toInt) int? attendanceId,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) int? tenantId,
    Map<String, dynamic> content,
    Map<String, dynamic> outcomes,
    String status,
    @JsonKey(name: 'created_at', fromJson: _toStr) String? createdAt,
    @JsonKey(name: 'updated_at', fromJson: _toStr) String? updatedAt,
    @JsonKey(name: 'published_at', fromJson: _toStr) String? publishedAt,
    @JsonKey(name: 'published_by') String? publishedBy,
    AttendanceRef? attendance,
  });

  $AttendanceRefCopyWith<$Res>? get attendance;
}

/// @nodoc
class _$ProtocolCopyWithImpl<$Res, $Val extends Protocol>
    implements $ProtocolCopyWith<$Res> {
  _$ProtocolCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Protocol
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? attendanceId = freezed,
    Object? tenantId = freezed,
    Object? content = null,
    Object? outcomes = null,
    Object? status = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? publishedAt = freezed,
    Object? publishedBy = freezed,
    Object? attendance = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String?,
            attendanceId:
                freezed == attendanceId
                    ? _value.attendanceId
                    : attendanceId // ignore: cast_nullable_to_non_nullable
                        as int?,
            tenantId:
                freezed == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int?,
            content:
                null == content
                    ? _value.content
                    : content // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
            outcomes:
                null == outcomes
                    ? _value.outcomes
                    : outcomes // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as String,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as String?,
            updatedAt:
                freezed == updatedAt
                    ? _value.updatedAt
                    : updatedAt // ignore: cast_nullable_to_non_nullable
                        as String?,
            publishedAt:
                freezed == publishedAt
                    ? _value.publishedAt
                    : publishedAt // ignore: cast_nullable_to_non_nullable
                        as String?,
            publishedBy:
                freezed == publishedBy
                    ? _value.publishedBy
                    : publishedBy // ignore: cast_nullable_to_non_nullable
                        as String?,
            attendance:
                freezed == attendance
                    ? _value.attendance
                    : attendance // ignore: cast_nullable_to_non_nullable
                        as AttendanceRef?,
          )
          as $Val,
    );
  }

  /// Create a copy of Protocol
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AttendanceRefCopyWith<$Res>? get attendance {
    if (_value.attendance == null) {
      return null;
    }

    return $AttendanceRefCopyWith<$Res>(_value.attendance!, (value) {
      return _then(_value.copyWith(attendance: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ProtocolImplCopyWith<$Res>
    implements $ProtocolCopyWith<$Res> {
  factory _$$ProtocolImplCopyWith(
    _$ProtocolImpl value,
    $Res Function(_$ProtocolImpl) then,
  ) = __$$ProtocolImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'attendance_id', fromJson: _toInt) int? attendanceId,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) int? tenantId,
    Map<String, dynamic> content,
    Map<String, dynamic> outcomes,
    String status,
    @JsonKey(name: 'created_at', fromJson: _toStr) String? createdAt,
    @JsonKey(name: 'updated_at', fromJson: _toStr) String? updatedAt,
    @JsonKey(name: 'published_at', fromJson: _toStr) String? publishedAt,
    @JsonKey(name: 'published_by') String? publishedBy,
    AttendanceRef? attendance,
  });

  @override
  $AttendanceRefCopyWith<$Res>? get attendance;
}

/// @nodoc
class __$$ProtocolImplCopyWithImpl<$Res>
    extends _$ProtocolCopyWithImpl<$Res, _$ProtocolImpl>
    implements _$$ProtocolImplCopyWith<$Res> {
  __$$ProtocolImplCopyWithImpl(
    _$ProtocolImpl _value,
    $Res Function(_$ProtocolImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Protocol
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? attendanceId = freezed,
    Object? tenantId = freezed,
    Object? content = null,
    Object? outcomes = null,
    Object? status = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? publishedAt = freezed,
    Object? publishedBy = freezed,
    Object? attendance = freezed,
  }) {
    return _then(
      _$ProtocolImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String?,
        attendanceId:
            freezed == attendanceId
                ? _value.attendanceId
                : attendanceId // ignore: cast_nullable_to_non_nullable
                    as int?,
        tenantId:
            freezed == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int?,
        content:
            null == content
                ? _value._content
                : content // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>,
        outcomes:
            null == outcomes
                ? _value._outcomes
                : outcomes // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as String,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as String?,
        updatedAt:
            freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                    as String?,
        publishedAt:
            freezed == publishedAt
                ? _value.publishedAt
                : publishedAt // ignore: cast_nullable_to_non_nullable
                    as String?,
        publishedBy:
            freezed == publishedBy
                ? _value.publishedBy
                : publishedBy // ignore: cast_nullable_to_non_nullable
                    as String?,
        attendance:
            freezed == attendance
                ? _value.attendance
                : attendance // ignore: cast_nullable_to_non_nullable
                    as AttendanceRef?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProtocolImpl implements _Protocol {
  const _$ProtocolImpl({
    this.id,
    @JsonKey(name: 'attendance_id', fromJson: _toInt) this.attendanceId,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) this.tenantId,
    final Map<String, dynamic> content = const <String, dynamic>{},
    final Map<String, dynamic> outcomes = const <String, dynamic>{},
    this.status = 'draft',
    @JsonKey(name: 'created_at', fromJson: _toStr) this.createdAt,
    @JsonKey(name: 'updated_at', fromJson: _toStr) this.updatedAt,
    @JsonKey(name: 'published_at', fromJson: _toStr) this.publishedAt,
    @JsonKey(name: 'published_by') this.publishedBy,
    this.attendance,
  }) : _content = content,
       _outcomes = outcomes;

  factory _$ProtocolImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProtocolImplFromJson(json);

  @override
  final String? id;
  @override
  @JsonKey(name: 'attendance_id', fromJson: _toInt)
  final int? attendanceId;
  @override
  @JsonKey(name: 'tenant_id', fromJson: _toInt)
  final int? tenantId;

  /// Tiptap JSON doc per plan field id (+ `__general__`).
  final Map<String, dynamic> _content;

  /// Tiptap JSON doc per plan field id (+ `__general__`).
  @override
  @JsonKey()
  Map<String, dynamic> get content {
    if (_content is EqualUnmodifiableMapView) return _content;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_content);
  }

  /// Outcome per field id: discussed | decided | postponed
  final Map<String, dynamic> _outcomes;

  /// Outcome per field id: discussed | decided | postponed
  @override
  @JsonKey()
  Map<String, dynamic> get outcomes {
    if (_outcomes is EqualUnmodifiableMapView) return _outcomes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_outcomes);
  }

  /// draft | published
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey(name: 'created_at', fromJson: _toStr)
  final String? createdAt;
  @override
  @JsonKey(name: 'updated_at', fromJson: _toStr)
  final String? updatedAt;
  @override
  @JsonKey(name: 'published_at', fromJson: _toStr)
  final String? publishedAt;
  @override
  @JsonKey(name: 'published_by')
  final String? publishedBy;
  @override
  final AttendanceRef? attendance;

  @override
  String toString() {
    return 'Protocol(id: $id, attendanceId: $attendanceId, tenantId: $tenantId, content: $content, outcomes: $outcomes, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, publishedAt: $publishedAt, publishedBy: $publishedBy, attendance: $attendance)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProtocolImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.attendanceId, attendanceId) ||
                other.attendanceId == attendanceId) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            const DeepCollectionEquality().equals(other._content, _content) &&
            const DeepCollectionEquality().equals(other._outcomes, _outcomes) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            (identical(other.publishedBy, publishedBy) ||
                other.publishedBy == publishedBy) &&
            (identical(other.attendance, attendance) ||
                other.attendance == attendance));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    attendanceId,
    tenantId,
    const DeepCollectionEquality().hash(_content),
    const DeepCollectionEquality().hash(_outcomes),
    status,
    createdAt,
    updatedAt,
    publishedAt,
    publishedBy,
    attendance,
  );

  /// Create a copy of Protocol
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProtocolImplCopyWith<_$ProtocolImpl> get copyWith =>
      __$$ProtocolImplCopyWithImpl<_$ProtocolImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProtocolImplToJson(this);
  }
}

abstract class _Protocol implements Protocol {
  const factory _Protocol({
    final String? id,
    @JsonKey(name: 'attendance_id', fromJson: _toInt) final int? attendanceId,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) final int? tenantId,
    final Map<String, dynamic> content,
    final Map<String, dynamic> outcomes,
    final String status,
    @JsonKey(name: 'created_at', fromJson: _toStr) final String? createdAt,
    @JsonKey(name: 'updated_at', fromJson: _toStr) final String? updatedAt,
    @JsonKey(name: 'published_at', fromJson: _toStr) final String? publishedAt,
    @JsonKey(name: 'published_by') final String? publishedBy,
    final AttendanceRef? attendance,
  }) = _$ProtocolImpl;

  factory _Protocol.fromJson(Map<String, dynamic> json) =
      _$ProtocolImpl.fromJson;

  @override
  String? get id;
  @override
  @JsonKey(name: 'attendance_id', fromJson: _toInt)
  int? get attendanceId;
  @override
  @JsonKey(name: 'tenant_id', fromJson: _toInt)
  int? get tenantId;

  /// Tiptap JSON doc per plan field id (+ `__general__`).
  @override
  Map<String, dynamic> get content;

  /// Outcome per field id: discussed | decided | postponed
  @override
  Map<String, dynamic> get outcomes;

  /// draft | published
  @override
  String get status;
  @override
  @JsonKey(name: 'created_at', fromJson: _toStr)
  String? get createdAt;
  @override
  @JsonKey(name: 'updated_at', fromJson: _toStr)
  String? get updatedAt;
  @override
  @JsonKey(name: 'published_at', fromJson: _toStr)
  String? get publishedAt;
  @override
  @JsonKey(name: 'published_by')
  String? get publishedBy;
  @override
  AttendanceRef? get attendance;

  /// Create a copy of Protocol
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProtocolImplCopyWith<_$ProtocolImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ProtocolType _$ProtocolTypeFromJson(Map<String, dynamic> json) {
  return _ProtocolType.fromJson(json);
}

/// @nodoc
mixin _$ProtocolType {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'enable_protocol')
  bool get enableProtocol => throw _privateConstructorUsedError;
  @JsonKey(name: 'relevant_groups')
  List<int>? get relevantGroups => throw _privateConstructorUsedError;
  @JsonKey(name: 'agenda_default_duration', fromJson: _toInt)
  int? get agendaDefaultDuration => throw _privateConstructorUsedError;
  @JsonKey(name: 'suggest_postponed')
  bool get suggestPostponed => throw _privateConstructorUsedError;
  @JsonKey(name: 'default_plan')
  Map<String, dynamic>? get defaultPlan => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_time')
  String? get startTime => throw _privateConstructorUsedError;

  /// Serializes this ProtocolType to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProtocolType
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProtocolTypeCopyWith<ProtocolType> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProtocolTypeCopyWith<$Res> {
  factory $ProtocolTypeCopyWith(
    ProtocolType value,
    $Res Function(ProtocolType) then,
  ) = _$ProtocolTypeCopyWithImpl<$Res, ProtocolType>;
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'enable_protocol') bool enableProtocol,
    @JsonKey(name: 'relevant_groups') List<int>? relevantGroups,
    @JsonKey(name: 'agenda_default_duration', fromJson: _toInt)
    int? agendaDefaultDuration,
    @JsonKey(name: 'suggest_postponed') bool suggestPostponed,
    @JsonKey(name: 'default_plan') Map<String, dynamic>? defaultPlan,
    @JsonKey(name: 'start_time') String? startTime,
  });
}

/// @nodoc
class _$ProtocolTypeCopyWithImpl<$Res, $Val extends ProtocolType>
    implements $ProtocolTypeCopyWith<$Res> {
  _$ProtocolTypeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProtocolType
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? enableProtocol = null,
    Object? relevantGroups = freezed,
    Object? agendaDefaultDuration = freezed,
    Object? suggestPostponed = null,
    Object? defaultPlan = freezed,
    Object? startTime = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            enableProtocol:
                null == enableProtocol
                    ? _value.enableProtocol
                    : enableProtocol // ignore: cast_nullable_to_non_nullable
                        as bool,
            relevantGroups:
                freezed == relevantGroups
                    ? _value.relevantGroups
                    : relevantGroups // ignore: cast_nullable_to_non_nullable
                        as List<int>?,
            agendaDefaultDuration:
                freezed == agendaDefaultDuration
                    ? _value.agendaDefaultDuration
                    : agendaDefaultDuration // ignore: cast_nullable_to_non_nullable
                        as int?,
            suggestPostponed:
                null == suggestPostponed
                    ? _value.suggestPostponed
                    : suggestPostponed // ignore: cast_nullable_to_non_nullable
                        as bool,
            defaultPlan:
                freezed == defaultPlan
                    ? _value.defaultPlan
                    : defaultPlan // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
            startTime:
                freezed == startTime
                    ? _value.startTime
                    : startTime // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProtocolTypeImplCopyWith<$Res>
    implements $ProtocolTypeCopyWith<$Res> {
  factory _$$ProtocolTypeImplCopyWith(
    _$ProtocolTypeImpl value,
    $Res Function(_$ProtocolTypeImpl) then,
  ) = __$$ProtocolTypeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'enable_protocol') bool enableProtocol,
    @JsonKey(name: 'relevant_groups') List<int>? relevantGroups,
    @JsonKey(name: 'agenda_default_duration', fromJson: _toInt)
    int? agendaDefaultDuration,
    @JsonKey(name: 'suggest_postponed') bool suggestPostponed,
    @JsonKey(name: 'default_plan') Map<String, dynamic>? defaultPlan,
    @JsonKey(name: 'start_time') String? startTime,
  });
}

/// @nodoc
class __$$ProtocolTypeImplCopyWithImpl<$Res>
    extends _$ProtocolTypeCopyWithImpl<$Res, _$ProtocolTypeImpl>
    implements _$$ProtocolTypeImplCopyWith<$Res> {
  __$$ProtocolTypeImplCopyWithImpl(
    _$ProtocolTypeImpl _value,
    $Res Function(_$ProtocolTypeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProtocolType
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? enableProtocol = null,
    Object? relevantGroups = freezed,
    Object? agendaDefaultDuration = freezed,
    Object? suggestPostponed = null,
    Object? defaultPlan = freezed,
    Object? startTime = freezed,
  }) {
    return _then(
      _$ProtocolTypeImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        enableProtocol:
            null == enableProtocol
                ? _value.enableProtocol
                : enableProtocol // ignore: cast_nullable_to_non_nullable
                    as bool,
        relevantGroups:
            freezed == relevantGroups
                ? _value._relevantGroups
                : relevantGroups // ignore: cast_nullable_to_non_nullable
                    as List<int>?,
        agendaDefaultDuration:
            freezed == agendaDefaultDuration
                ? _value.agendaDefaultDuration
                : agendaDefaultDuration // ignore: cast_nullable_to_non_nullable
                    as int?,
        suggestPostponed:
            null == suggestPostponed
                ? _value.suggestPostponed
                : suggestPostponed // ignore: cast_nullable_to_non_nullable
                    as bool,
        defaultPlan:
            freezed == defaultPlan
                ? _value._defaultPlan
                : defaultPlan // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
        startTime:
            freezed == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProtocolTypeImpl implements _ProtocolType {
  const _$ProtocolTypeImpl({
    required this.id,
    this.name = '',
    @JsonKey(name: 'enable_protocol') this.enableProtocol = false,
    @JsonKey(name: 'relevant_groups') final List<int>? relevantGroups,
    @JsonKey(name: 'agenda_default_duration', fromJson: _toInt)
    this.agendaDefaultDuration,
    @JsonKey(name: 'suggest_postponed') this.suggestPostponed = true,
    @JsonKey(name: 'default_plan') final Map<String, dynamic>? defaultPlan,
    @JsonKey(name: 'start_time') this.startTime,
  }) : _relevantGroups = relevantGroups,
       _defaultPlan = defaultPlan;

  factory _$ProtocolTypeImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProtocolTypeImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey(name: 'enable_protocol')
  final bool enableProtocol;
  final List<int>? _relevantGroups;
  @override
  @JsonKey(name: 'relevant_groups')
  List<int>? get relevantGroups {
    final value = _relevantGroups;
    if (value == null) return null;
    if (_relevantGroups is EqualUnmodifiableListView) return _relevantGroups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'agenda_default_duration', fromJson: _toInt)
  final int? agendaDefaultDuration;
  @override
  @JsonKey(name: 'suggest_postponed')
  final bool suggestPostponed;
  final Map<String, dynamic>? _defaultPlan;
  @override
  @JsonKey(name: 'default_plan')
  Map<String, dynamic>? get defaultPlan {
    final value = _defaultPlan;
    if (value == null) return null;
    if (_defaultPlan is EqualUnmodifiableMapView) return _defaultPlan;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'start_time')
  final String? startTime;

  @override
  String toString() {
    return 'ProtocolType(id: $id, name: $name, enableProtocol: $enableProtocol, relevantGroups: $relevantGroups, agendaDefaultDuration: $agendaDefaultDuration, suggestPostponed: $suggestPostponed, defaultPlan: $defaultPlan, startTime: $startTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProtocolTypeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.enableProtocol, enableProtocol) ||
                other.enableProtocol == enableProtocol) &&
            const DeepCollectionEquality().equals(
              other._relevantGroups,
              _relevantGroups,
            ) &&
            (identical(other.agendaDefaultDuration, agendaDefaultDuration) ||
                other.agendaDefaultDuration == agendaDefaultDuration) &&
            (identical(other.suggestPostponed, suggestPostponed) ||
                other.suggestPostponed == suggestPostponed) &&
            const DeepCollectionEquality().equals(
              other._defaultPlan,
              _defaultPlan,
            ) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    enableProtocol,
    const DeepCollectionEquality().hash(_relevantGroups),
    agendaDefaultDuration,
    suggestPostponed,
    const DeepCollectionEquality().hash(_defaultPlan),
    startTime,
  );

  /// Create a copy of ProtocolType
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProtocolTypeImplCopyWith<_$ProtocolTypeImpl> get copyWith =>
      __$$ProtocolTypeImplCopyWithImpl<_$ProtocolTypeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProtocolTypeImplToJson(this);
  }
}

abstract class _ProtocolType implements ProtocolType {
  const factory _ProtocolType({
    required final String id,
    final String name,
    @JsonKey(name: 'enable_protocol') final bool enableProtocol,
    @JsonKey(name: 'relevant_groups') final List<int>? relevantGroups,
    @JsonKey(name: 'agenda_default_duration', fromJson: _toInt)
    final int? agendaDefaultDuration,
    @JsonKey(name: 'suggest_postponed') final bool suggestPostponed,
    @JsonKey(name: 'default_plan') final Map<String, dynamic>? defaultPlan,
    @JsonKey(name: 'start_time') final String? startTime,
  }) = _$ProtocolTypeImpl;

  factory _ProtocolType.fromJson(Map<String, dynamic> json) =
      _$ProtocolTypeImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'enable_protocol')
  bool get enableProtocol;
  @override
  @JsonKey(name: 'relevant_groups')
  List<int>? get relevantGroups;
  @override
  @JsonKey(name: 'agenda_default_duration', fromJson: _toInt)
  int? get agendaDefaultDuration;
  @override
  @JsonKey(name: 'suggest_postponed')
  bool get suggestPostponed;
  @override
  @JsonKey(name: 'default_plan')
  Map<String, dynamic>? get defaultPlan;
  @override
  @JsonKey(name: 'start_time')
  String? get startTime;

  /// Create a copy of ProtocolType
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProtocolTypeImplCopyWith<_$ProtocolTypeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
