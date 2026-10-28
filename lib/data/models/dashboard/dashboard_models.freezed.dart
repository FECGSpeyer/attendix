// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DashboardCardConfig _$DashboardCardConfigFromJson(Map<String, dynamic> json) {
  return _DashboardCardConfig.fromJson(json);
}

/// @nodoc
mixin _$DashboardCardConfig {
  String get id => throw _privateConstructorUsedError;
  bool get visible => throw _privateConstructorUsedError;

  /// Serializes this DashboardCardConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DashboardCardConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardCardConfigCopyWith<DashboardCardConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardCardConfigCopyWith<$Res> {
  factory $DashboardCardConfigCopyWith(
    DashboardCardConfig value,
    $Res Function(DashboardCardConfig) then,
  ) = _$DashboardCardConfigCopyWithImpl<$Res, DashboardCardConfig>;
  @useResult
  $Res call({String id, bool visible});
}

/// @nodoc
class _$DashboardCardConfigCopyWithImpl<$Res, $Val extends DashboardCardConfig>
    implements $DashboardCardConfigCopyWith<$Res> {
  _$DashboardCardConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardCardConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? visible = null}) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            visible:
                null == visible
                    ? _value.visible
                    : visible // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DashboardCardConfigImplCopyWith<$Res>
    implements $DashboardCardConfigCopyWith<$Res> {
  factory _$$DashboardCardConfigImplCopyWith(
    _$DashboardCardConfigImpl value,
    $Res Function(_$DashboardCardConfigImpl) then,
  ) = __$$DashboardCardConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, bool visible});
}

/// @nodoc
class __$$DashboardCardConfigImplCopyWithImpl<$Res>
    extends _$DashboardCardConfigCopyWithImpl<$Res, _$DashboardCardConfigImpl>
    implements _$$DashboardCardConfigImplCopyWith<$Res> {
  __$$DashboardCardConfigImplCopyWithImpl(
    _$DashboardCardConfigImpl _value,
    $Res Function(_$DashboardCardConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DashboardCardConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? visible = null}) {
    return _then(
      _$DashboardCardConfigImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        visible:
            null == visible
                ? _value.visible
                : visible // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardCardConfigImpl implements _DashboardCardConfig {
  const _$DashboardCardConfigImpl({required this.id, this.visible = true});

  factory _$DashboardCardConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardCardConfigImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final bool visible;

  @override
  String toString() {
    return 'DashboardCardConfig(id: $id, visible: $visible)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardCardConfigImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.visible, visible) || other.visible == visible));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, visible);

  /// Create a copy of DashboardCardConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardCardConfigImplCopyWith<_$DashboardCardConfigImpl> get copyWith =>
      __$$DashboardCardConfigImplCopyWithImpl<_$DashboardCardConfigImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardCardConfigImplToJson(this);
  }
}

abstract class _DashboardCardConfig implements DashboardCardConfig {
  const factory _DashboardCardConfig({
    required final String id,
    final bool visible,
  }) = _$DashboardCardConfigImpl;

  factory _DashboardCardConfig.fromJson(Map<String, dynamic> json) =
      _$DashboardCardConfigImpl.fromJson;

  @override
  String get id;
  @override
  bool get visible;

  /// Create a copy of DashboardCardConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardCardConfigImplCopyWith<_$DashboardCardConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DashboardAbsence _$DashboardAbsenceFromJson(Map<String, dynamic> json) {
  return _DashboardAbsence.fromJson(json);
}

/// @nodoc
mixin _$DashboardAbsence {
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'person_id')
  int? get personId => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  int? get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'from_date')
  String? get fromDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'until_date')
  String? get untilDate => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;

  /// Serializes this DashboardAbsence to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DashboardAbsence
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardAbsenceCopyWith<DashboardAbsence> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardAbsenceCopyWith<$Res> {
  factory $DashboardAbsenceCopyWith(
    DashboardAbsence value,
    $Res Function(DashboardAbsence) then,
  ) = _$DashboardAbsenceCopyWithImpl<$Res, DashboardAbsence>;
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'person_id') int? personId,
    @JsonKey(name: 'tenant_id') int? tenantId,
    @JsonKey(name: 'from_date') String? fromDate,
    @JsonKey(name: 'until_date') String? untilDate,
    String? reason,
  });
}

/// @nodoc
class _$DashboardAbsenceCopyWithImpl<$Res, $Val extends DashboardAbsence>
    implements $DashboardAbsenceCopyWith<$Res> {
  _$DashboardAbsenceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardAbsence
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? personId = freezed,
    Object? tenantId = freezed,
    Object? fromDate = freezed,
    Object? untilDate = freezed,
    Object? reason = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String?,
            personId:
                freezed == personId
                    ? _value.personId
                    : personId // ignore: cast_nullable_to_non_nullable
                        as int?,
            tenantId:
                freezed == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int?,
            fromDate:
                freezed == fromDate
                    ? _value.fromDate
                    : fromDate // ignore: cast_nullable_to_non_nullable
                        as String?,
            untilDate:
                freezed == untilDate
                    ? _value.untilDate
                    : untilDate // ignore: cast_nullable_to_non_nullable
                        as String?,
            reason:
                freezed == reason
                    ? _value.reason
                    : reason // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DashboardAbsenceImplCopyWith<$Res>
    implements $DashboardAbsenceCopyWith<$Res> {
  factory _$$DashboardAbsenceImplCopyWith(
    _$DashboardAbsenceImpl value,
    $Res Function(_$DashboardAbsenceImpl) then,
  ) = __$$DashboardAbsenceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'person_id') int? personId,
    @JsonKey(name: 'tenant_id') int? tenantId,
    @JsonKey(name: 'from_date') String? fromDate,
    @JsonKey(name: 'until_date') String? untilDate,
    String? reason,
  });
}

/// @nodoc
class __$$DashboardAbsenceImplCopyWithImpl<$Res>
    extends _$DashboardAbsenceCopyWithImpl<$Res, _$DashboardAbsenceImpl>
    implements _$$DashboardAbsenceImplCopyWith<$Res> {
  __$$DashboardAbsenceImplCopyWithImpl(
    _$DashboardAbsenceImpl _value,
    $Res Function(_$DashboardAbsenceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DashboardAbsence
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? personId = freezed,
    Object? tenantId = freezed,
    Object? fromDate = freezed,
    Object? untilDate = freezed,
    Object? reason = freezed,
  }) {
    return _then(
      _$DashboardAbsenceImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String?,
        personId:
            freezed == personId
                ? _value.personId
                : personId // ignore: cast_nullable_to_non_nullable
                    as int?,
        tenantId:
            freezed == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int?,
        fromDate:
            freezed == fromDate
                ? _value.fromDate
                : fromDate // ignore: cast_nullable_to_non_nullable
                    as String?,
        untilDate:
            freezed == untilDate
                ? _value.untilDate
                : untilDate // ignore: cast_nullable_to_non_nullable
                    as String?,
        reason:
            freezed == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardAbsenceImpl implements _DashboardAbsence {
  const _$DashboardAbsenceImpl({
    this.id,
    @JsonKey(name: 'person_id') this.personId,
    @JsonKey(name: 'tenant_id') this.tenantId,
    @JsonKey(name: 'from_date') this.fromDate,
    @JsonKey(name: 'until_date') this.untilDate,
    this.reason,
  });

  factory _$DashboardAbsenceImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardAbsenceImplFromJson(json);

  @override
  final String? id;
  @override
  @JsonKey(name: 'person_id')
  final int? personId;
  @override
  @JsonKey(name: 'tenant_id')
  final int? tenantId;
  @override
  @JsonKey(name: 'from_date')
  final String? fromDate;
  @override
  @JsonKey(name: 'until_date')
  final String? untilDate;
  @override
  final String? reason;

  @override
  String toString() {
    return 'DashboardAbsence(id: $id, personId: $personId, tenantId: $tenantId, fromDate: $fromDate, untilDate: $untilDate, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardAbsenceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.personId, personId) ||
                other.personId == personId) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
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
    personId,
    tenantId,
    fromDate,
    untilDate,
    reason,
  );

  /// Create a copy of DashboardAbsence
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardAbsenceImplCopyWith<_$DashboardAbsenceImpl> get copyWith =>
      __$$DashboardAbsenceImplCopyWithImpl<_$DashboardAbsenceImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardAbsenceImplToJson(this);
  }
}

abstract class _DashboardAbsence implements DashboardAbsence {
  const factory _DashboardAbsence({
    final String? id,
    @JsonKey(name: 'person_id') final int? personId,
    @JsonKey(name: 'tenant_id') final int? tenantId,
    @JsonKey(name: 'from_date') final String? fromDate,
    @JsonKey(name: 'until_date') final String? untilDate,
    final String? reason,
  }) = _$DashboardAbsenceImpl;

  factory _DashboardAbsence.fromJson(Map<String, dynamic> json) =
      _$DashboardAbsenceImpl.fromJson;

  @override
  String? get id;
  @override
  @JsonKey(name: 'person_id')
  int? get personId;
  @override
  @JsonKey(name: 'tenant_id')
  int? get tenantId;
  @override
  @JsonKey(name: 'from_date')
  String? get fromDate;
  @override
  @JsonKey(name: 'until_date')
  String? get untilDate;
  @override
  String? get reason;

  /// Create a copy of DashboardAbsence
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardAbsenceImplCopyWith<_$DashboardAbsenceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DashboardSongEntry {
  int get songId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int? get number => throw _privateConstructorUsedError;
  String? get prefix => throw _privateConstructorUsedError;
  String? get conductorName => throw _privateConstructorUsedError;
  String get dateLabel => throw _privateConstructorUsedError;
  String? get date => throw _privateConstructorUsedError;
  String? get typeLabel => throw _privateConstructorUsedError;

  /// Create a copy of DashboardSongEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardSongEntryCopyWith<DashboardSongEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardSongEntryCopyWith<$Res> {
  factory $DashboardSongEntryCopyWith(
    DashboardSongEntry value,
    $Res Function(DashboardSongEntry) then,
  ) = _$DashboardSongEntryCopyWithImpl<$Res, DashboardSongEntry>;
  @useResult
  $Res call({
    int songId,
    String name,
    int? number,
    String? prefix,
    String? conductorName,
    String dateLabel,
    String? date,
    String? typeLabel,
  });
}

/// @nodoc
class _$DashboardSongEntryCopyWithImpl<$Res, $Val extends DashboardSongEntry>
    implements $DashboardSongEntryCopyWith<$Res> {
  _$DashboardSongEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardSongEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? songId = null,
    Object? name = null,
    Object? number = freezed,
    Object? prefix = freezed,
    Object? conductorName = freezed,
    Object? dateLabel = null,
    Object? date = freezed,
    Object? typeLabel = freezed,
  }) {
    return _then(
      _value.copyWith(
            songId:
                null == songId
                    ? _value.songId
                    : songId // ignore: cast_nullable_to_non_nullable
                        as int,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            number:
                freezed == number
                    ? _value.number
                    : number // ignore: cast_nullable_to_non_nullable
                        as int?,
            prefix:
                freezed == prefix
                    ? _value.prefix
                    : prefix // ignore: cast_nullable_to_non_nullable
                        as String?,
            conductorName:
                freezed == conductorName
                    ? _value.conductorName
                    : conductorName // ignore: cast_nullable_to_non_nullable
                        as String?,
            dateLabel:
                null == dateLabel
                    ? _value.dateLabel
                    : dateLabel // ignore: cast_nullable_to_non_nullable
                        as String,
            date:
                freezed == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as String?,
            typeLabel:
                freezed == typeLabel
                    ? _value.typeLabel
                    : typeLabel // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DashboardSongEntryImplCopyWith<$Res>
    implements $DashboardSongEntryCopyWith<$Res> {
  factory _$$DashboardSongEntryImplCopyWith(
    _$DashboardSongEntryImpl value,
    $Res Function(_$DashboardSongEntryImpl) then,
  ) = __$$DashboardSongEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int songId,
    String name,
    int? number,
    String? prefix,
    String? conductorName,
    String dateLabel,
    String? date,
    String? typeLabel,
  });
}

/// @nodoc
class __$$DashboardSongEntryImplCopyWithImpl<$Res>
    extends _$DashboardSongEntryCopyWithImpl<$Res, _$DashboardSongEntryImpl>
    implements _$$DashboardSongEntryImplCopyWith<$Res> {
  __$$DashboardSongEntryImplCopyWithImpl(
    _$DashboardSongEntryImpl _value,
    $Res Function(_$DashboardSongEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DashboardSongEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? songId = null,
    Object? name = null,
    Object? number = freezed,
    Object? prefix = freezed,
    Object? conductorName = freezed,
    Object? dateLabel = null,
    Object? date = freezed,
    Object? typeLabel = freezed,
  }) {
    return _then(
      _$DashboardSongEntryImpl(
        songId:
            null == songId
                ? _value.songId
                : songId // ignore: cast_nullable_to_non_nullable
                    as int,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        number:
            freezed == number
                ? _value.number
                : number // ignore: cast_nullable_to_non_nullable
                    as int?,
        prefix:
            freezed == prefix
                ? _value.prefix
                : prefix // ignore: cast_nullable_to_non_nullable
                    as String?,
        conductorName:
            freezed == conductorName
                ? _value.conductorName
                : conductorName // ignore: cast_nullable_to_non_nullable
                    as String?,
        dateLabel:
            null == dateLabel
                ? _value.dateLabel
                : dateLabel // ignore: cast_nullable_to_non_nullable
                    as String,
        date:
            freezed == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as String?,
        typeLabel:
            freezed == typeLabel
                ? _value.typeLabel
                : typeLabel // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc

class _$DashboardSongEntryImpl implements _DashboardSongEntry {
  const _$DashboardSongEntryImpl({
    required this.songId,
    required this.name,
    this.number,
    this.prefix,
    this.conductorName,
    required this.dateLabel,
    this.date,
    this.typeLabel,
  });

  @override
  final int songId;
  @override
  final String name;
  @override
  final int? number;
  @override
  final String? prefix;
  @override
  final String? conductorName;
  @override
  final String dateLabel;
  @override
  final String? date;
  @override
  final String? typeLabel;

  @override
  String toString() {
    return 'DashboardSongEntry(songId: $songId, name: $name, number: $number, prefix: $prefix, conductorName: $conductorName, dateLabel: $dateLabel, date: $date, typeLabel: $typeLabel)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardSongEntryImpl &&
            (identical(other.songId, songId) || other.songId == songId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.number, number) || other.number == number) &&
            (identical(other.prefix, prefix) || other.prefix == prefix) &&
            (identical(other.conductorName, conductorName) ||
                other.conductorName == conductorName) &&
            (identical(other.dateLabel, dateLabel) ||
                other.dateLabel == dateLabel) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.typeLabel, typeLabel) ||
                other.typeLabel == typeLabel));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    songId,
    name,
    number,
    prefix,
    conductorName,
    dateLabel,
    date,
    typeLabel,
  );

  /// Create a copy of DashboardSongEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardSongEntryImplCopyWith<_$DashboardSongEntryImpl> get copyWith =>
      __$$DashboardSongEntryImplCopyWithImpl<_$DashboardSongEntryImpl>(
        this,
        _$identity,
      );
}

abstract class _DashboardSongEntry implements DashboardSongEntry {
  const factory _DashboardSongEntry({
    required final int songId,
    required final String name,
    final int? number,
    final String? prefix,
    final String? conductorName,
    required final String dateLabel,
    final String? date,
    final String? typeLabel,
  }) = _$DashboardSongEntryImpl;

  @override
  int get songId;
  @override
  String get name;
  @override
  int? get number;
  @override
  String? get prefix;
  @override
  String? get conductorName;
  @override
  String get dateLabel;
  @override
  String? get date;
  @override
  String? get typeLabel;

  /// Create a copy of DashboardSongEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardSongEntryImplCopyWith<_$DashboardSongEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$UsageKpis {
  int get totalEvents => throw _privateConstructorUsedError;
  int get distinctTenants => throw _privateConstructorUsedError;
  int get activeTenants7d => throw _privateConstructorUsedError;

  /// Create a copy of UsageKpis
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UsageKpisCopyWith<UsageKpis> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UsageKpisCopyWith<$Res> {
  factory $UsageKpisCopyWith(UsageKpis value, $Res Function(UsageKpis) then) =
      _$UsageKpisCopyWithImpl<$Res, UsageKpis>;
  @useResult
  $Res call({int totalEvents, int distinctTenants, int activeTenants7d});
}

/// @nodoc
class _$UsageKpisCopyWithImpl<$Res, $Val extends UsageKpis>
    implements $UsageKpisCopyWith<$Res> {
  _$UsageKpisCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UsageKpis
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalEvents = null,
    Object? distinctTenants = null,
    Object? activeTenants7d = null,
  }) {
    return _then(
      _value.copyWith(
            totalEvents:
                null == totalEvents
                    ? _value.totalEvents
                    : totalEvents // ignore: cast_nullable_to_non_nullable
                        as int,
            distinctTenants:
                null == distinctTenants
                    ? _value.distinctTenants
                    : distinctTenants // ignore: cast_nullable_to_non_nullable
                        as int,
            activeTenants7d:
                null == activeTenants7d
                    ? _value.activeTenants7d
                    : activeTenants7d // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UsageKpisImplCopyWith<$Res>
    implements $UsageKpisCopyWith<$Res> {
  factory _$$UsageKpisImplCopyWith(
    _$UsageKpisImpl value,
    $Res Function(_$UsageKpisImpl) then,
  ) = __$$UsageKpisImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int totalEvents, int distinctTenants, int activeTenants7d});
}

/// @nodoc
class __$$UsageKpisImplCopyWithImpl<$Res>
    extends _$UsageKpisCopyWithImpl<$Res, _$UsageKpisImpl>
    implements _$$UsageKpisImplCopyWith<$Res> {
  __$$UsageKpisImplCopyWithImpl(
    _$UsageKpisImpl _value,
    $Res Function(_$UsageKpisImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UsageKpis
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalEvents = null,
    Object? distinctTenants = null,
    Object? activeTenants7d = null,
  }) {
    return _then(
      _$UsageKpisImpl(
        totalEvents:
            null == totalEvents
                ? _value.totalEvents
                : totalEvents // ignore: cast_nullable_to_non_nullable
                    as int,
        distinctTenants:
            null == distinctTenants
                ? _value.distinctTenants
                : distinctTenants // ignore: cast_nullable_to_non_nullable
                    as int,
        activeTenants7d:
            null == activeTenants7d
                ? _value.activeTenants7d
                : activeTenants7d // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc

class _$UsageKpisImpl implements _UsageKpis {
  const _$UsageKpisImpl({
    this.totalEvents = 0,
    this.distinctTenants = 0,
    this.activeTenants7d = 0,
  });

  @override
  @JsonKey()
  final int totalEvents;
  @override
  @JsonKey()
  final int distinctTenants;
  @override
  @JsonKey()
  final int activeTenants7d;

  @override
  String toString() {
    return 'UsageKpis(totalEvents: $totalEvents, distinctTenants: $distinctTenants, activeTenants7d: $activeTenants7d)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UsageKpisImpl &&
            (identical(other.totalEvents, totalEvents) ||
                other.totalEvents == totalEvents) &&
            (identical(other.distinctTenants, distinctTenants) ||
                other.distinctTenants == distinctTenants) &&
            (identical(other.activeTenants7d, activeTenants7d) ||
                other.activeTenants7d == activeTenants7d));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, totalEvents, distinctTenants, activeTenants7d);

  /// Create a copy of UsageKpis
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UsageKpisImplCopyWith<_$UsageKpisImpl> get copyWith =>
      __$$UsageKpisImplCopyWithImpl<_$UsageKpisImpl>(this, _$identity);
}

abstract class _UsageKpis implements UsageKpis {
  const factory _UsageKpis({
    final int totalEvents,
    final int distinctTenants,
    final int activeTenants7d,
  }) = _$UsageKpisImpl;

  @override
  int get totalEvents;
  @override
  int get distinctTenants;
  @override
  int get activeTenants7d;

  /// Create a copy of UsageKpis
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UsageKpisImplCopyWith<_$UsageKpisImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$UsageCount {
  String get label => throw _privateConstructorUsedError;
  int get count => throw _privateConstructorUsedError;

  /// Create a copy of UsageCount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UsageCountCopyWith<UsageCount> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UsageCountCopyWith<$Res> {
  factory $UsageCountCopyWith(
    UsageCount value,
    $Res Function(UsageCount) then,
  ) = _$UsageCountCopyWithImpl<$Res, UsageCount>;
  @useResult
  $Res call({String label, int count});
}

/// @nodoc
class _$UsageCountCopyWithImpl<$Res, $Val extends UsageCount>
    implements $UsageCountCopyWith<$Res> {
  _$UsageCountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UsageCount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? label = null, Object? count = null}) {
    return _then(
      _value.copyWith(
            label:
                null == label
                    ? _value.label
                    : label // ignore: cast_nullable_to_non_nullable
                        as String,
            count:
                null == count
                    ? _value.count
                    : count // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UsageCountImplCopyWith<$Res>
    implements $UsageCountCopyWith<$Res> {
  factory _$$UsageCountImplCopyWith(
    _$UsageCountImpl value,
    $Res Function(_$UsageCountImpl) then,
  ) = __$$UsageCountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String label, int count});
}

/// @nodoc
class __$$UsageCountImplCopyWithImpl<$Res>
    extends _$UsageCountCopyWithImpl<$Res, _$UsageCountImpl>
    implements _$$UsageCountImplCopyWith<$Res> {
  __$$UsageCountImplCopyWithImpl(
    _$UsageCountImpl _value,
    $Res Function(_$UsageCountImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UsageCount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? label = null, Object? count = null}) {
    return _then(
      _$UsageCountImpl(
        label:
            null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                    as String,
        count:
            null == count
                ? _value.count
                : count // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc

class _$UsageCountImpl implements _UsageCount {
  const _$UsageCountImpl({required this.label, required this.count});

  @override
  final String label;
  @override
  final int count;

  @override
  String toString() {
    return 'UsageCount(label: $label, count: $count)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UsageCountImpl &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.count, count) || other.count == count));
  }

  @override
  int get hashCode => Object.hash(runtimeType, label, count);

  /// Create a copy of UsageCount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UsageCountImplCopyWith<_$UsageCountImpl> get copyWith =>
      __$$UsageCountImplCopyWithImpl<_$UsageCountImpl>(this, _$identity);
}

abstract class _UsageCount implements UsageCount {
  const factory _UsageCount({
    required final String label,
    required final int count,
  }) = _$UsageCountImpl;

  @override
  String get label;
  @override
  int get count;

  /// Create a copy of UsageCount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UsageCountImplCopyWith<_$UsageCountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$UsageDashboardData {
  UsageKpis get kpis => throw _privateConstructorUsedError;
  List<UsageCount> get perDay => throw _privateConstructorUsedError;
  List<UsageCount> get byName => throw _privateConstructorUsedError;
  List<UsageCount> get byTenant => throw _privateConstructorUsedError;
  List<UsageCount> get byDevice => throw _privateConstructorUsedError;

  /// Create a copy of UsageDashboardData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UsageDashboardDataCopyWith<UsageDashboardData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UsageDashboardDataCopyWith<$Res> {
  factory $UsageDashboardDataCopyWith(
    UsageDashboardData value,
    $Res Function(UsageDashboardData) then,
  ) = _$UsageDashboardDataCopyWithImpl<$Res, UsageDashboardData>;
  @useResult
  $Res call({
    UsageKpis kpis,
    List<UsageCount> perDay,
    List<UsageCount> byName,
    List<UsageCount> byTenant,
    List<UsageCount> byDevice,
  });

  $UsageKpisCopyWith<$Res> get kpis;
}

/// @nodoc
class _$UsageDashboardDataCopyWithImpl<$Res, $Val extends UsageDashboardData>
    implements $UsageDashboardDataCopyWith<$Res> {
  _$UsageDashboardDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UsageDashboardData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kpis = null,
    Object? perDay = null,
    Object? byName = null,
    Object? byTenant = null,
    Object? byDevice = null,
  }) {
    return _then(
      _value.copyWith(
            kpis:
                null == kpis
                    ? _value.kpis
                    : kpis // ignore: cast_nullable_to_non_nullable
                        as UsageKpis,
            perDay:
                null == perDay
                    ? _value.perDay
                    : perDay // ignore: cast_nullable_to_non_nullable
                        as List<UsageCount>,
            byName:
                null == byName
                    ? _value.byName
                    : byName // ignore: cast_nullable_to_non_nullable
                        as List<UsageCount>,
            byTenant:
                null == byTenant
                    ? _value.byTenant
                    : byTenant // ignore: cast_nullable_to_non_nullable
                        as List<UsageCount>,
            byDevice:
                null == byDevice
                    ? _value.byDevice
                    : byDevice // ignore: cast_nullable_to_non_nullable
                        as List<UsageCount>,
          )
          as $Val,
    );
  }

  /// Create a copy of UsageDashboardData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UsageKpisCopyWith<$Res> get kpis {
    return $UsageKpisCopyWith<$Res>(_value.kpis, (value) {
      return _then(_value.copyWith(kpis: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UsageDashboardDataImplCopyWith<$Res>
    implements $UsageDashboardDataCopyWith<$Res> {
  factory _$$UsageDashboardDataImplCopyWith(
    _$UsageDashboardDataImpl value,
    $Res Function(_$UsageDashboardDataImpl) then,
  ) = __$$UsageDashboardDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    UsageKpis kpis,
    List<UsageCount> perDay,
    List<UsageCount> byName,
    List<UsageCount> byTenant,
    List<UsageCount> byDevice,
  });

  @override
  $UsageKpisCopyWith<$Res> get kpis;
}

/// @nodoc
class __$$UsageDashboardDataImplCopyWithImpl<$Res>
    extends _$UsageDashboardDataCopyWithImpl<$Res, _$UsageDashboardDataImpl>
    implements _$$UsageDashboardDataImplCopyWith<$Res> {
  __$$UsageDashboardDataImplCopyWithImpl(
    _$UsageDashboardDataImpl _value,
    $Res Function(_$UsageDashboardDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UsageDashboardData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kpis = null,
    Object? perDay = null,
    Object? byName = null,
    Object? byTenant = null,
    Object? byDevice = null,
  }) {
    return _then(
      _$UsageDashboardDataImpl(
        kpis:
            null == kpis
                ? _value.kpis
                : kpis // ignore: cast_nullable_to_non_nullable
                    as UsageKpis,
        perDay:
            null == perDay
                ? _value._perDay
                : perDay // ignore: cast_nullable_to_non_nullable
                    as List<UsageCount>,
        byName:
            null == byName
                ? _value._byName
                : byName // ignore: cast_nullable_to_non_nullable
                    as List<UsageCount>,
        byTenant:
            null == byTenant
                ? _value._byTenant
                : byTenant // ignore: cast_nullable_to_non_nullable
                    as List<UsageCount>,
        byDevice:
            null == byDevice
                ? _value._byDevice
                : byDevice // ignore: cast_nullable_to_non_nullable
                    as List<UsageCount>,
      ),
    );
  }
}

/// @nodoc

class _$UsageDashboardDataImpl implements _UsageDashboardData {
  const _$UsageDashboardDataImpl({
    this.kpis = const UsageKpis(),
    final List<UsageCount> perDay = const [],
    final List<UsageCount> byName = const [],
    final List<UsageCount> byTenant = const [],
    final List<UsageCount> byDevice = const [],
  }) : _perDay = perDay,
       _byName = byName,
       _byTenant = byTenant,
       _byDevice = byDevice;

  @override
  @JsonKey()
  final UsageKpis kpis;
  final List<UsageCount> _perDay;
  @override
  @JsonKey()
  List<UsageCount> get perDay {
    if (_perDay is EqualUnmodifiableListView) return _perDay;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_perDay);
  }

  final List<UsageCount> _byName;
  @override
  @JsonKey()
  List<UsageCount> get byName {
    if (_byName is EqualUnmodifiableListView) return _byName;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_byName);
  }

  final List<UsageCount> _byTenant;
  @override
  @JsonKey()
  List<UsageCount> get byTenant {
    if (_byTenant is EqualUnmodifiableListView) return _byTenant;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_byTenant);
  }

  final List<UsageCount> _byDevice;
  @override
  @JsonKey()
  List<UsageCount> get byDevice {
    if (_byDevice is EqualUnmodifiableListView) return _byDevice;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_byDevice);
  }

  @override
  String toString() {
    return 'UsageDashboardData(kpis: $kpis, perDay: $perDay, byName: $byName, byTenant: $byTenant, byDevice: $byDevice)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UsageDashboardDataImpl &&
            (identical(other.kpis, kpis) || other.kpis == kpis) &&
            const DeepCollectionEquality().equals(other._perDay, _perDay) &&
            const DeepCollectionEquality().equals(other._byName, _byName) &&
            const DeepCollectionEquality().equals(other._byTenant, _byTenant) &&
            const DeepCollectionEquality().equals(other._byDevice, _byDevice));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    kpis,
    const DeepCollectionEquality().hash(_perDay),
    const DeepCollectionEquality().hash(_byName),
    const DeepCollectionEquality().hash(_byTenant),
    const DeepCollectionEquality().hash(_byDevice),
  );

  /// Create a copy of UsageDashboardData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UsageDashboardDataImplCopyWith<_$UsageDashboardDataImpl> get copyWith =>
      __$$UsageDashboardDataImplCopyWithImpl<_$UsageDashboardDataImpl>(
        this,
        _$identity,
      );
}

abstract class _UsageDashboardData implements UsageDashboardData {
  const factory _UsageDashboardData({
    final UsageKpis kpis,
    final List<UsageCount> perDay,
    final List<UsageCount> byName,
    final List<UsageCount> byTenant,
    final List<UsageCount> byDevice,
  }) = _$UsageDashboardDataImpl;

  @override
  UsageKpis get kpis;
  @override
  List<UsageCount> get perDay;
  @override
  List<UsageCount> get byName;
  @override
  List<UsageCount> get byTenant;
  @override
  List<UsageCount> get byDevice;

  /// Create a copy of UsageDashboardData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UsageDashboardDataImplCopyWith<_$UsageDashboardDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
