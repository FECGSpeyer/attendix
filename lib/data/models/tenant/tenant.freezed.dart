// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tenant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Tenant _$TenantFromJson(Map<String, dynamic> json) {
  return _Tenant.fromJson(json);
}

/// @nodoc
mixin _$Tenant {
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  String get shortName => throw _privateConstructorUsedError;
  String get longName => throw _privateConstructorUsedError;
  bool get maintainTeachers => throw _privateConstructorUsedError;
  bool get showHolidays => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  bool get withExcuses => throw _privateConstructorUsedError;
  String? get practiceStart => throw _privateConstructorUsedError;
  String? get practiceEnd => throw _privateConstructorUsedError;
  String? get seasonStart => throw _privateConstructorUsedError;
  bool? get parents => throw _privateConstructorUsedError;
  bool get betaProgram => throw _privateConstructorUsedError;
  @JsonKey(name: 'show_members_list')
  bool get showMembersList => throw _privateConstructorUsedError;
  String? get region => throw _privateConstructorUsedError;
  int? get role => throw _privateConstructorUsedError;
  @JsonKey(name: 'song_sharing_id')
  String? get songSharingId => throw _privateConstructorUsedError;
  @JsonKey(name: 'additional_fields')
  List<ExtraField>? get additionalFields => throw _privateConstructorUsedError;
  String? get perc => throw _privateConstructorUsedError;
  String? get percColor => throw _privateConstructorUsedError;
  @JsonKey(name: 'register_id')
  String? get registerId => throw _privateConstructorUsedError;
  @JsonKey(name: 'auto_approve_registrations')
  bool get autoApproveRegistrations => throw _privateConstructorUsedError;
  @JsonKey(name: 'registration_fields')
  List<String>? get registrationFields => throw _privateConstructorUsedError;
  bool? get favorite => throw _privateConstructorUsedError;
  @JsonKey(name: 'critical_rules')
  List<CriticalRule>? get criticalRules => throw _privateConstructorUsedError;
  String get timezone =>
      throw _privateConstructorUsedError; // DUTY: "Meine Termine" als Dienstplan-Ansicht
  @JsonKey(name: 'duty_view')
  bool get dutyView => throw _privateConstructorUsedError;

  /// Serializes this Tenant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Tenant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TenantCopyWith<Tenant> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TenantCopyWith<$Res> {
  factory $TenantCopyWith(Tenant value, $Res Function(Tenant) then) =
      _$TenantCopyWithImpl<$Res, Tenant>;
  @useResult
  $Res call({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    String shortName,
    String longName,
    bool maintainTeachers,
    bool showHolidays,
    String type,
    bool withExcuses,
    String? practiceStart,
    String? practiceEnd,
    String? seasonStart,
    bool? parents,
    bool betaProgram,
    @JsonKey(name: 'show_members_list') bool showMembersList,
    String? region,
    int? role,
    @JsonKey(name: 'song_sharing_id') String? songSharingId,
    @JsonKey(name: 'additional_fields') List<ExtraField>? additionalFields,
    String? perc,
    String? percColor,
    @JsonKey(name: 'register_id') String? registerId,
    @JsonKey(name: 'auto_approve_registrations') bool autoApproveRegistrations,
    @JsonKey(name: 'registration_fields') List<String>? registrationFields,
    bool? favorite,
    @JsonKey(name: 'critical_rules') List<CriticalRule>? criticalRules,
    String timezone,
    @JsonKey(name: 'duty_view') bool dutyView,
  });
}

/// @nodoc
class _$TenantCopyWithImpl<$Res, $Val extends Tenant>
    implements $TenantCopyWith<$Res> {
  _$TenantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Tenant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? shortName = null,
    Object? longName = null,
    Object? maintainTeachers = null,
    Object? showHolidays = null,
    Object? type = null,
    Object? withExcuses = null,
    Object? practiceStart = freezed,
    Object? practiceEnd = freezed,
    Object? seasonStart = freezed,
    Object? parents = freezed,
    Object? betaProgram = null,
    Object? showMembersList = null,
    Object? region = freezed,
    Object? role = freezed,
    Object? songSharingId = freezed,
    Object? additionalFields = freezed,
    Object? perc = freezed,
    Object? percColor = freezed,
    Object? registerId = freezed,
    Object? autoApproveRegistrations = null,
    Object? registrationFields = freezed,
    Object? favorite = freezed,
    Object? criticalRules = freezed,
    Object? timezone = null,
    Object? dutyView = null,
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
            shortName:
                null == shortName
                    ? _value.shortName
                    : shortName // ignore: cast_nullable_to_non_nullable
                        as String,
            longName:
                null == longName
                    ? _value.longName
                    : longName // ignore: cast_nullable_to_non_nullable
                        as String,
            maintainTeachers:
                null == maintainTeachers
                    ? _value.maintainTeachers
                    : maintainTeachers // ignore: cast_nullable_to_non_nullable
                        as bool,
            showHolidays:
                null == showHolidays
                    ? _value.showHolidays
                    : showHolidays // ignore: cast_nullable_to_non_nullable
                        as bool,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String,
            withExcuses:
                null == withExcuses
                    ? _value.withExcuses
                    : withExcuses // ignore: cast_nullable_to_non_nullable
                        as bool,
            practiceStart:
                freezed == practiceStart
                    ? _value.practiceStart
                    : practiceStart // ignore: cast_nullable_to_non_nullable
                        as String?,
            practiceEnd:
                freezed == practiceEnd
                    ? _value.practiceEnd
                    : practiceEnd // ignore: cast_nullable_to_non_nullable
                        as String?,
            seasonStart:
                freezed == seasonStart
                    ? _value.seasonStart
                    : seasonStart // ignore: cast_nullable_to_non_nullable
                        as String?,
            parents:
                freezed == parents
                    ? _value.parents
                    : parents // ignore: cast_nullable_to_non_nullable
                        as bool?,
            betaProgram:
                null == betaProgram
                    ? _value.betaProgram
                    : betaProgram // ignore: cast_nullable_to_non_nullable
                        as bool,
            showMembersList:
                null == showMembersList
                    ? _value.showMembersList
                    : showMembersList // ignore: cast_nullable_to_non_nullable
                        as bool,
            region:
                freezed == region
                    ? _value.region
                    : region // ignore: cast_nullable_to_non_nullable
                        as String?,
            role:
                freezed == role
                    ? _value.role
                    : role // ignore: cast_nullable_to_non_nullable
                        as int?,
            songSharingId:
                freezed == songSharingId
                    ? _value.songSharingId
                    : songSharingId // ignore: cast_nullable_to_non_nullable
                        as String?,
            additionalFields:
                freezed == additionalFields
                    ? _value.additionalFields
                    : additionalFields // ignore: cast_nullable_to_non_nullable
                        as List<ExtraField>?,
            perc:
                freezed == perc
                    ? _value.perc
                    : perc // ignore: cast_nullable_to_non_nullable
                        as String?,
            percColor:
                freezed == percColor
                    ? _value.percColor
                    : percColor // ignore: cast_nullable_to_non_nullable
                        as String?,
            registerId:
                freezed == registerId
                    ? _value.registerId
                    : registerId // ignore: cast_nullable_to_non_nullable
                        as String?,
            autoApproveRegistrations:
                null == autoApproveRegistrations
                    ? _value.autoApproveRegistrations
                    : autoApproveRegistrations // ignore: cast_nullable_to_non_nullable
                        as bool,
            registrationFields:
                freezed == registrationFields
                    ? _value.registrationFields
                    : registrationFields // ignore: cast_nullable_to_non_nullable
                        as List<String>?,
            favorite:
                freezed == favorite
                    ? _value.favorite
                    : favorite // ignore: cast_nullable_to_non_nullable
                        as bool?,
            criticalRules:
                freezed == criticalRules
                    ? _value.criticalRules
                    : criticalRules // ignore: cast_nullable_to_non_nullable
                        as List<CriticalRule>?,
            timezone:
                null == timezone
                    ? _value.timezone
                    : timezone // ignore: cast_nullable_to_non_nullable
                        as String,
            dutyView:
                null == dutyView
                    ? _value.dutyView
                    : dutyView // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TenantImplCopyWith<$Res> implements $TenantCopyWith<$Res> {
  factory _$$TenantImplCopyWith(
    _$TenantImpl value,
    $Res Function(_$TenantImpl) then,
  ) = __$$TenantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    String shortName,
    String longName,
    bool maintainTeachers,
    bool showHolidays,
    String type,
    bool withExcuses,
    String? practiceStart,
    String? practiceEnd,
    String? seasonStart,
    bool? parents,
    bool betaProgram,
    @JsonKey(name: 'show_members_list') bool showMembersList,
    String? region,
    int? role,
    @JsonKey(name: 'song_sharing_id') String? songSharingId,
    @JsonKey(name: 'additional_fields') List<ExtraField>? additionalFields,
    String? perc,
    String? percColor,
    @JsonKey(name: 'register_id') String? registerId,
    @JsonKey(name: 'auto_approve_registrations') bool autoApproveRegistrations,
    @JsonKey(name: 'registration_fields') List<String>? registrationFields,
    bool? favorite,
    @JsonKey(name: 'critical_rules') List<CriticalRule>? criticalRules,
    String timezone,
    @JsonKey(name: 'duty_view') bool dutyView,
  });
}

/// @nodoc
class __$$TenantImplCopyWithImpl<$Res>
    extends _$TenantCopyWithImpl<$Res, _$TenantImpl>
    implements _$$TenantImplCopyWith<$Res> {
  __$$TenantImplCopyWithImpl(
    _$TenantImpl _value,
    $Res Function(_$TenantImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Tenant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? shortName = null,
    Object? longName = null,
    Object? maintainTeachers = null,
    Object? showHolidays = null,
    Object? type = null,
    Object? withExcuses = null,
    Object? practiceStart = freezed,
    Object? practiceEnd = freezed,
    Object? seasonStart = freezed,
    Object? parents = freezed,
    Object? betaProgram = null,
    Object? showMembersList = null,
    Object? region = freezed,
    Object? role = freezed,
    Object? songSharingId = freezed,
    Object? additionalFields = freezed,
    Object? perc = freezed,
    Object? percColor = freezed,
    Object? registerId = freezed,
    Object? autoApproveRegistrations = null,
    Object? registrationFields = freezed,
    Object? favorite = freezed,
    Object? criticalRules = freezed,
    Object? timezone = null,
    Object? dutyView = null,
  }) {
    return _then(
      _$TenantImpl(
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
        shortName:
            null == shortName
                ? _value.shortName
                : shortName // ignore: cast_nullable_to_non_nullable
                    as String,
        longName:
            null == longName
                ? _value.longName
                : longName // ignore: cast_nullable_to_non_nullable
                    as String,
        maintainTeachers:
            null == maintainTeachers
                ? _value.maintainTeachers
                : maintainTeachers // ignore: cast_nullable_to_non_nullable
                    as bool,
        showHolidays:
            null == showHolidays
                ? _value.showHolidays
                : showHolidays // ignore: cast_nullable_to_non_nullable
                    as bool,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String,
        withExcuses:
            null == withExcuses
                ? _value.withExcuses
                : withExcuses // ignore: cast_nullable_to_non_nullable
                    as bool,
        practiceStart:
            freezed == practiceStart
                ? _value.practiceStart
                : practiceStart // ignore: cast_nullable_to_non_nullable
                    as String?,
        practiceEnd:
            freezed == practiceEnd
                ? _value.practiceEnd
                : practiceEnd // ignore: cast_nullable_to_non_nullable
                    as String?,
        seasonStart:
            freezed == seasonStart
                ? _value.seasonStart
                : seasonStart // ignore: cast_nullable_to_non_nullable
                    as String?,
        parents:
            freezed == parents
                ? _value.parents
                : parents // ignore: cast_nullable_to_non_nullable
                    as bool?,
        betaProgram:
            null == betaProgram
                ? _value.betaProgram
                : betaProgram // ignore: cast_nullable_to_non_nullable
                    as bool,
        showMembersList:
            null == showMembersList
                ? _value.showMembersList
                : showMembersList // ignore: cast_nullable_to_non_nullable
                    as bool,
        region:
            freezed == region
                ? _value.region
                : region // ignore: cast_nullable_to_non_nullable
                    as String?,
        role:
            freezed == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                    as int?,
        songSharingId:
            freezed == songSharingId
                ? _value.songSharingId
                : songSharingId // ignore: cast_nullable_to_non_nullable
                    as String?,
        additionalFields:
            freezed == additionalFields
                ? _value._additionalFields
                : additionalFields // ignore: cast_nullable_to_non_nullable
                    as List<ExtraField>?,
        perc:
            freezed == perc
                ? _value.perc
                : perc // ignore: cast_nullable_to_non_nullable
                    as String?,
        percColor:
            freezed == percColor
                ? _value.percColor
                : percColor // ignore: cast_nullable_to_non_nullable
                    as String?,
        registerId:
            freezed == registerId
                ? _value.registerId
                : registerId // ignore: cast_nullable_to_non_nullable
                    as String?,
        autoApproveRegistrations:
            null == autoApproveRegistrations
                ? _value.autoApproveRegistrations
                : autoApproveRegistrations // ignore: cast_nullable_to_non_nullable
                    as bool,
        registrationFields:
            freezed == registrationFields
                ? _value._registrationFields
                : registrationFields // ignore: cast_nullable_to_non_nullable
                    as List<String>?,
        favorite:
            freezed == favorite
                ? _value.favorite
                : favorite // ignore: cast_nullable_to_non_nullable
                    as bool?,
        criticalRules:
            freezed == criticalRules
                ? _value._criticalRules
                : criticalRules // ignore: cast_nullable_to_non_nullable
                    as List<CriticalRule>?,
        timezone:
            null == timezone
                ? _value.timezone
                : timezone // ignore: cast_nullable_to_non_nullable
                    as String,
        dutyView:
            null == dutyView
                ? _value.dutyView
                : dutyView // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TenantImpl implements _Tenant {
  const _$TenantImpl({
    this.id,
    @JsonKey(name: 'created_at') this.createdAt,
    required this.shortName,
    required this.longName,
    this.maintainTeachers = false,
    this.showHolidays = false,
    this.type = '',
    this.withExcuses = true,
    this.practiceStart,
    this.practiceEnd,
    this.seasonStart,
    this.parents = false,
    this.betaProgram = false,
    @JsonKey(name: 'show_members_list') this.showMembersList = false,
    this.region,
    this.role,
    @JsonKey(name: 'song_sharing_id') this.songSharingId,
    @JsonKey(name: 'additional_fields')
    final List<ExtraField>? additionalFields,
    this.perc,
    this.percColor,
    @JsonKey(name: 'register_id') this.registerId,
    @JsonKey(name: 'auto_approve_registrations')
    this.autoApproveRegistrations = false,
    @JsonKey(name: 'registration_fields')
    final List<String>? registrationFields,
    this.favorite = false,
    @JsonKey(name: 'critical_rules') final List<CriticalRule>? criticalRules,
    this.timezone = 'Europe/Berlin',
    @JsonKey(name: 'duty_view') this.dutyView = false,
  }) : _additionalFields = additionalFields,
       _registrationFields = registrationFields,
       _criticalRules = criticalRules;

  factory _$TenantImpl.fromJson(Map<String, dynamic> json) =>
      _$$TenantImplFromJson(json);

  @override
  final int? id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  final String shortName;
  @override
  final String longName;
  @override
  @JsonKey()
  final bool maintainTeachers;
  @override
  @JsonKey()
  final bool showHolidays;
  @override
  @JsonKey()
  final String type;
  @override
  @JsonKey()
  final bool withExcuses;
  @override
  final String? practiceStart;
  @override
  final String? practiceEnd;
  @override
  final String? seasonStart;
  @override
  @JsonKey()
  final bool? parents;
  @override
  @JsonKey()
  final bool betaProgram;
  @override
  @JsonKey(name: 'show_members_list')
  final bool showMembersList;
  @override
  final String? region;
  @override
  final int? role;
  @override
  @JsonKey(name: 'song_sharing_id')
  final String? songSharingId;
  final List<ExtraField>? _additionalFields;
  @override
  @JsonKey(name: 'additional_fields')
  List<ExtraField>? get additionalFields {
    final value = _additionalFields;
    if (value == null) return null;
    if (_additionalFields is EqualUnmodifiableListView)
      return _additionalFields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? perc;
  @override
  final String? percColor;
  @override
  @JsonKey(name: 'register_id')
  final String? registerId;
  @override
  @JsonKey(name: 'auto_approve_registrations')
  final bool autoApproveRegistrations;
  final List<String>? _registrationFields;
  @override
  @JsonKey(name: 'registration_fields')
  List<String>? get registrationFields {
    final value = _registrationFields;
    if (value == null) return null;
    if (_registrationFields is EqualUnmodifiableListView)
      return _registrationFields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final bool? favorite;
  final List<CriticalRule>? _criticalRules;
  @override
  @JsonKey(name: 'critical_rules')
  List<CriticalRule>? get criticalRules {
    final value = _criticalRules;
    if (value == null) return null;
    if (_criticalRules is EqualUnmodifiableListView) return _criticalRules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final String timezone;
  // DUTY: "Meine Termine" als Dienstplan-Ansicht
  @override
  @JsonKey(name: 'duty_view')
  final bool dutyView;

  @override
  String toString() {
    return 'Tenant(id: $id, createdAt: $createdAt, shortName: $shortName, longName: $longName, maintainTeachers: $maintainTeachers, showHolidays: $showHolidays, type: $type, withExcuses: $withExcuses, practiceStart: $practiceStart, practiceEnd: $practiceEnd, seasonStart: $seasonStart, parents: $parents, betaProgram: $betaProgram, showMembersList: $showMembersList, region: $region, role: $role, songSharingId: $songSharingId, additionalFields: $additionalFields, perc: $perc, percColor: $percColor, registerId: $registerId, autoApproveRegistrations: $autoApproveRegistrations, registrationFields: $registrationFields, favorite: $favorite, criticalRules: $criticalRules, timezone: $timezone, dutyView: $dutyView)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TenantImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.shortName, shortName) ||
                other.shortName == shortName) &&
            (identical(other.longName, longName) ||
                other.longName == longName) &&
            (identical(other.maintainTeachers, maintainTeachers) ||
                other.maintainTeachers == maintainTeachers) &&
            (identical(other.showHolidays, showHolidays) ||
                other.showHolidays == showHolidays) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.withExcuses, withExcuses) ||
                other.withExcuses == withExcuses) &&
            (identical(other.practiceStart, practiceStart) ||
                other.practiceStart == practiceStart) &&
            (identical(other.practiceEnd, practiceEnd) ||
                other.practiceEnd == practiceEnd) &&
            (identical(other.seasonStart, seasonStart) ||
                other.seasonStart == seasonStart) &&
            (identical(other.parents, parents) || other.parents == parents) &&
            (identical(other.betaProgram, betaProgram) ||
                other.betaProgram == betaProgram) &&
            (identical(other.showMembersList, showMembersList) ||
                other.showMembersList == showMembersList) &&
            (identical(other.region, region) || other.region == region) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.songSharingId, songSharingId) ||
                other.songSharingId == songSharingId) &&
            const DeepCollectionEquality().equals(
              other._additionalFields,
              _additionalFields,
            ) &&
            (identical(other.perc, perc) || other.perc == perc) &&
            (identical(other.percColor, percColor) ||
                other.percColor == percColor) &&
            (identical(other.registerId, registerId) ||
                other.registerId == registerId) &&
            (identical(
                  other.autoApproveRegistrations,
                  autoApproveRegistrations,
                ) ||
                other.autoApproveRegistrations == autoApproveRegistrations) &&
            const DeepCollectionEquality().equals(
              other._registrationFields,
              _registrationFields,
            ) &&
            (identical(other.favorite, favorite) ||
                other.favorite == favorite) &&
            const DeepCollectionEquality().equals(
              other._criticalRules,
              _criticalRules,
            ) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.dutyView, dutyView) ||
                other.dutyView == dutyView));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    createdAt,
    shortName,
    longName,
    maintainTeachers,
    showHolidays,
    type,
    withExcuses,
    practiceStart,
    practiceEnd,
    seasonStart,
    parents,
    betaProgram,
    showMembersList,
    region,
    role,
    songSharingId,
    const DeepCollectionEquality().hash(_additionalFields),
    perc,
    percColor,
    registerId,
    autoApproveRegistrations,
    const DeepCollectionEquality().hash(_registrationFields),
    favorite,
    const DeepCollectionEquality().hash(_criticalRules),
    timezone,
    dutyView,
  ]);

  /// Create a copy of Tenant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TenantImplCopyWith<_$TenantImpl> get copyWith =>
      __$$TenantImplCopyWithImpl<_$TenantImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TenantImplToJson(this);
  }
}

abstract class _Tenant implements Tenant {
  const factory _Tenant({
    final int? id,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    required final String shortName,
    required final String longName,
    final bool maintainTeachers,
    final bool showHolidays,
    final String type,
    final bool withExcuses,
    final String? practiceStart,
    final String? practiceEnd,
    final String? seasonStart,
    final bool? parents,
    final bool betaProgram,
    @JsonKey(name: 'show_members_list') final bool showMembersList,
    final String? region,
    final int? role,
    @JsonKey(name: 'song_sharing_id') final String? songSharingId,
    @JsonKey(name: 'additional_fields')
    final List<ExtraField>? additionalFields,
    final String? perc,
    final String? percColor,
    @JsonKey(name: 'register_id') final String? registerId,
    @JsonKey(name: 'auto_approve_registrations')
    final bool autoApproveRegistrations,
    @JsonKey(name: 'registration_fields')
    final List<String>? registrationFields,
    final bool? favorite,
    @JsonKey(name: 'critical_rules') final List<CriticalRule>? criticalRules,
    final String timezone,
    @JsonKey(name: 'duty_view') final bool dutyView,
  }) = _$TenantImpl;

  factory _Tenant.fromJson(Map<String, dynamic> json) = _$TenantImpl.fromJson;

  @override
  int? get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  String get shortName;
  @override
  String get longName;
  @override
  bool get maintainTeachers;
  @override
  bool get showHolidays;
  @override
  String get type;
  @override
  bool get withExcuses;
  @override
  String? get practiceStart;
  @override
  String? get practiceEnd;
  @override
  String? get seasonStart;
  @override
  bool? get parents;
  @override
  bool get betaProgram;
  @override
  @JsonKey(name: 'show_members_list')
  bool get showMembersList;
  @override
  String? get region;
  @override
  int? get role;
  @override
  @JsonKey(name: 'song_sharing_id')
  String? get songSharingId;
  @override
  @JsonKey(name: 'additional_fields')
  List<ExtraField>? get additionalFields;
  @override
  String? get perc;
  @override
  String? get percColor;
  @override
  @JsonKey(name: 'register_id')
  String? get registerId;
  @override
  @JsonKey(name: 'auto_approve_registrations')
  bool get autoApproveRegistrations;
  @override
  @JsonKey(name: 'registration_fields')
  List<String>? get registrationFields;
  @override
  bool? get favorite;
  @override
  @JsonKey(name: 'critical_rules')
  List<CriticalRule>? get criticalRules;
  @override
  String get timezone; // DUTY: "Meine Termine" als Dienstplan-Ansicht
  @override
  @JsonKey(name: 'duty_view')
  bool get dutyView;

  /// Create a copy of Tenant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TenantImplCopyWith<_$TenantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ExtraField _$ExtraFieldFromJson(Map<String, dynamic> json) {
  return _ExtraField.fromJson(json);
}

/// @nodoc
mixin _$ExtraField {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  dynamic get defaultValue => throw _privateConstructorUsedError;
  List<String>? get options => throw _privateConstructorUsedError;

  /// Serializes this ExtraField to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExtraField
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExtraFieldCopyWith<ExtraField> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExtraFieldCopyWith<$Res> {
  factory $ExtraFieldCopyWith(
    ExtraField value,
    $Res Function(ExtraField) then,
  ) = _$ExtraFieldCopyWithImpl<$Res, ExtraField>;
  @useResult
  $Res call({
    String id,
    String name,
    String type,
    dynamic defaultValue,
    List<String>? options,
  });
}

/// @nodoc
class _$ExtraFieldCopyWithImpl<$Res, $Val extends ExtraField>
    implements $ExtraFieldCopyWith<$Res> {
  _$ExtraFieldCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExtraField
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? defaultValue = freezed,
    Object? options = freezed,
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
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String,
            defaultValue:
                freezed == defaultValue
                    ? _value.defaultValue
                    : defaultValue // ignore: cast_nullable_to_non_nullable
                        as dynamic,
            options:
                freezed == options
                    ? _value.options
                    : options // ignore: cast_nullable_to_non_nullable
                        as List<String>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ExtraFieldImplCopyWith<$Res>
    implements $ExtraFieldCopyWith<$Res> {
  factory _$$ExtraFieldImplCopyWith(
    _$ExtraFieldImpl value,
    $Res Function(_$ExtraFieldImpl) then,
  ) = __$$ExtraFieldImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String type,
    dynamic defaultValue,
    List<String>? options,
  });
}

/// @nodoc
class __$$ExtraFieldImplCopyWithImpl<$Res>
    extends _$ExtraFieldCopyWithImpl<$Res, _$ExtraFieldImpl>
    implements _$$ExtraFieldImplCopyWith<$Res> {
  __$$ExtraFieldImplCopyWithImpl(
    _$ExtraFieldImpl _value,
    $Res Function(_$ExtraFieldImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ExtraField
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? defaultValue = freezed,
    Object? options = freezed,
  }) {
    return _then(
      _$ExtraFieldImpl(
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
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String,
        defaultValue:
            freezed == defaultValue
                ? _value.defaultValue
                : defaultValue // ignore: cast_nullable_to_non_nullable
                    as dynamic,
        options:
            freezed == options
                ? _value._options
                : options // ignore: cast_nullable_to_non_nullable
                    as List<String>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ExtraFieldImpl implements _ExtraField {
  const _$ExtraFieldImpl({
    required this.id,
    required this.name,
    required this.type,
    this.defaultValue,
    final List<String>? options,
  }) : _options = options;

  factory _$ExtraFieldImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExtraFieldImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String type;
  @override
  final dynamic defaultValue;
  final List<String>? _options;
  @override
  List<String>? get options {
    final value = _options;
    if (value == null) return null;
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'ExtraField(id: $id, name: $name, type: $type, defaultValue: $defaultValue, options: $options)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExtraFieldImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(
              other.defaultValue,
              defaultValue,
            ) &&
            const DeepCollectionEquality().equals(other._options, _options));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    type,
    const DeepCollectionEquality().hash(defaultValue),
    const DeepCollectionEquality().hash(_options),
  );

  /// Create a copy of ExtraField
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExtraFieldImplCopyWith<_$ExtraFieldImpl> get copyWith =>
      __$$ExtraFieldImplCopyWithImpl<_$ExtraFieldImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExtraFieldImplToJson(this);
  }
}

abstract class _ExtraField implements ExtraField {
  const factory _ExtraField({
    required final String id,
    required final String name,
    required final String type,
    final dynamic defaultValue,
    final List<String>? options,
  }) = _$ExtraFieldImpl;

  factory _ExtraField.fromJson(Map<String, dynamic> json) =
      _$ExtraFieldImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get type;
  @override
  dynamic get defaultValue;
  @override
  List<String>? get options;

  /// Create a copy of ExtraField
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExtraFieldImplCopyWith<_$ExtraFieldImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CriticalRule _$CriticalRuleFromJson(Map<String, dynamic> json) {
  return _CriticalRule.fromJson(json);
}

/// @nodoc
mixin _$CriticalRule {
  String get id => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_type_ids')
  List<String> get attendanceTypeIds => throw _privateConstructorUsedError;
  List<int> get statuses => throw _privateConstructorUsedError;
  @JsonKey(name: 'threshold_type')
  CriticalRuleThresholdType get thresholdType =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'threshold_value')
  int get thresholdValue => throw _privateConstructorUsedError;
  @JsonKey(name: 'period_type')
  CriticalRulePeriodType? get periodType => throw _privateConstructorUsedError;
  @JsonKey(name: 'period_days')
  int? get periodDays => throw _privateConstructorUsedError;
  CriticalRuleOperator get operator => throw _privateConstructorUsedError;
  bool get enabled => throw _privateConstructorUsedError;

  /// Serializes this CriticalRule to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CriticalRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CriticalRuleCopyWith<CriticalRule> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CriticalRuleCopyWith<$Res> {
  factory $CriticalRuleCopyWith(
    CriticalRule value,
    $Res Function(CriticalRule) then,
  ) = _$CriticalRuleCopyWithImpl<$Res, CriticalRule>;
  @useResult
  $Res call({
    String id,
    String? name,
    @JsonKey(name: 'attendance_type_ids') List<String> attendanceTypeIds,
    List<int> statuses,
    @JsonKey(name: 'threshold_type') CriticalRuleThresholdType thresholdType,
    @JsonKey(name: 'threshold_value') int thresholdValue,
    @JsonKey(name: 'period_type') CriticalRulePeriodType? periodType,
    @JsonKey(name: 'period_days') int? periodDays,
    CriticalRuleOperator operator,
    bool enabled,
  });
}

/// @nodoc
class _$CriticalRuleCopyWithImpl<$Res, $Val extends CriticalRule>
    implements $CriticalRuleCopyWith<$Res> {
  _$CriticalRuleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CriticalRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? attendanceTypeIds = null,
    Object? statuses = null,
    Object? thresholdType = null,
    Object? thresholdValue = null,
    Object? periodType = freezed,
    Object? periodDays = freezed,
    Object? operator = null,
    Object? enabled = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                freezed == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String?,
            attendanceTypeIds:
                null == attendanceTypeIds
                    ? _value.attendanceTypeIds
                    : attendanceTypeIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            statuses:
                null == statuses
                    ? _value.statuses
                    : statuses // ignore: cast_nullable_to_non_nullable
                        as List<int>,
            thresholdType:
                null == thresholdType
                    ? _value.thresholdType
                    : thresholdType // ignore: cast_nullable_to_non_nullable
                        as CriticalRuleThresholdType,
            thresholdValue:
                null == thresholdValue
                    ? _value.thresholdValue
                    : thresholdValue // ignore: cast_nullable_to_non_nullable
                        as int,
            periodType:
                freezed == periodType
                    ? _value.periodType
                    : periodType // ignore: cast_nullable_to_non_nullable
                        as CriticalRulePeriodType?,
            periodDays:
                freezed == periodDays
                    ? _value.periodDays
                    : periodDays // ignore: cast_nullable_to_non_nullable
                        as int?,
            operator:
                null == operator
                    ? _value.operator
                    : operator // ignore: cast_nullable_to_non_nullable
                        as CriticalRuleOperator,
            enabled:
                null == enabled
                    ? _value.enabled
                    : enabled // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CriticalRuleImplCopyWith<$Res>
    implements $CriticalRuleCopyWith<$Res> {
  factory _$$CriticalRuleImplCopyWith(
    _$CriticalRuleImpl value,
    $Res Function(_$CriticalRuleImpl) then,
  ) = __$$CriticalRuleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? name,
    @JsonKey(name: 'attendance_type_ids') List<String> attendanceTypeIds,
    List<int> statuses,
    @JsonKey(name: 'threshold_type') CriticalRuleThresholdType thresholdType,
    @JsonKey(name: 'threshold_value') int thresholdValue,
    @JsonKey(name: 'period_type') CriticalRulePeriodType? periodType,
    @JsonKey(name: 'period_days') int? periodDays,
    CriticalRuleOperator operator,
    bool enabled,
  });
}

/// @nodoc
class __$$CriticalRuleImplCopyWithImpl<$Res>
    extends _$CriticalRuleCopyWithImpl<$Res, _$CriticalRuleImpl>
    implements _$$CriticalRuleImplCopyWith<$Res> {
  __$$CriticalRuleImplCopyWithImpl(
    _$CriticalRuleImpl _value,
    $Res Function(_$CriticalRuleImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CriticalRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? attendanceTypeIds = null,
    Object? statuses = null,
    Object? thresholdType = null,
    Object? thresholdValue = null,
    Object? periodType = freezed,
    Object? periodDays = freezed,
    Object? operator = null,
    Object? enabled = null,
  }) {
    return _then(
      _$CriticalRuleImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            freezed == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String?,
        attendanceTypeIds:
            null == attendanceTypeIds
                ? _value._attendanceTypeIds
                : attendanceTypeIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        statuses:
            null == statuses
                ? _value._statuses
                : statuses // ignore: cast_nullable_to_non_nullable
                    as List<int>,
        thresholdType:
            null == thresholdType
                ? _value.thresholdType
                : thresholdType // ignore: cast_nullable_to_non_nullable
                    as CriticalRuleThresholdType,
        thresholdValue:
            null == thresholdValue
                ? _value.thresholdValue
                : thresholdValue // ignore: cast_nullable_to_non_nullable
                    as int,
        periodType:
            freezed == periodType
                ? _value.periodType
                : periodType // ignore: cast_nullable_to_non_nullable
                    as CriticalRulePeriodType?,
        periodDays:
            freezed == periodDays
                ? _value.periodDays
                : periodDays // ignore: cast_nullable_to_non_nullable
                    as int?,
        operator:
            null == operator
                ? _value.operator
                : operator // ignore: cast_nullable_to_non_nullable
                    as CriticalRuleOperator,
        enabled:
            null == enabled
                ? _value.enabled
                : enabled // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CriticalRuleImpl implements _CriticalRule {
  const _$CriticalRuleImpl({
    required this.id,
    this.name,
    @JsonKey(name: 'attendance_type_ids')
    required final List<String> attendanceTypeIds,
    required final List<int> statuses,
    @JsonKey(name: 'threshold_type') required this.thresholdType,
    @JsonKey(name: 'threshold_value') required this.thresholdValue,
    @JsonKey(name: 'period_type') this.periodType,
    @JsonKey(name: 'period_days') this.periodDays,
    required this.operator,
    this.enabled = true,
  }) : _attendanceTypeIds = attendanceTypeIds,
       _statuses = statuses;

  factory _$CriticalRuleImpl.fromJson(Map<String, dynamic> json) =>
      _$$CriticalRuleImplFromJson(json);

  @override
  final String id;
  @override
  final String? name;
  final List<String> _attendanceTypeIds;
  @override
  @JsonKey(name: 'attendance_type_ids')
  List<String> get attendanceTypeIds {
    if (_attendanceTypeIds is EqualUnmodifiableListView)
      return _attendanceTypeIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attendanceTypeIds);
  }

  final List<int> _statuses;
  @override
  List<int> get statuses {
    if (_statuses is EqualUnmodifiableListView) return _statuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_statuses);
  }

  @override
  @JsonKey(name: 'threshold_type')
  final CriticalRuleThresholdType thresholdType;
  @override
  @JsonKey(name: 'threshold_value')
  final int thresholdValue;
  @override
  @JsonKey(name: 'period_type')
  final CriticalRulePeriodType? periodType;
  @override
  @JsonKey(name: 'period_days')
  final int? periodDays;
  @override
  final CriticalRuleOperator operator;
  @override
  @JsonKey()
  final bool enabled;

  @override
  String toString() {
    return 'CriticalRule(id: $id, name: $name, attendanceTypeIds: $attendanceTypeIds, statuses: $statuses, thresholdType: $thresholdType, thresholdValue: $thresholdValue, periodType: $periodType, periodDays: $periodDays, operator: $operator, enabled: $enabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CriticalRuleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(
              other._attendanceTypeIds,
              _attendanceTypeIds,
            ) &&
            const DeepCollectionEquality().equals(other._statuses, _statuses) &&
            (identical(other.thresholdType, thresholdType) ||
                other.thresholdType == thresholdType) &&
            (identical(other.thresholdValue, thresholdValue) ||
                other.thresholdValue == thresholdValue) &&
            (identical(other.periodType, periodType) ||
                other.periodType == periodType) &&
            (identical(other.periodDays, periodDays) ||
                other.periodDays == periodDays) &&
            (identical(other.operator, operator) ||
                other.operator == operator) &&
            (identical(other.enabled, enabled) || other.enabled == enabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    const DeepCollectionEquality().hash(_attendanceTypeIds),
    const DeepCollectionEquality().hash(_statuses),
    thresholdType,
    thresholdValue,
    periodType,
    periodDays,
    operator,
    enabled,
  );

  /// Create a copy of CriticalRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CriticalRuleImplCopyWith<_$CriticalRuleImpl> get copyWith =>
      __$$CriticalRuleImplCopyWithImpl<_$CriticalRuleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CriticalRuleImplToJson(this);
  }
}

abstract class _CriticalRule implements CriticalRule {
  const factory _CriticalRule({
    required final String id,
    final String? name,
    @JsonKey(name: 'attendance_type_ids')
    required final List<String> attendanceTypeIds,
    required final List<int> statuses,
    @JsonKey(name: 'threshold_type')
    required final CriticalRuleThresholdType thresholdType,
    @JsonKey(name: 'threshold_value') required final int thresholdValue,
    @JsonKey(name: 'period_type') final CriticalRulePeriodType? periodType,
    @JsonKey(name: 'period_days') final int? periodDays,
    required final CriticalRuleOperator operator,
    final bool enabled,
  }) = _$CriticalRuleImpl;

  factory _CriticalRule.fromJson(Map<String, dynamic> json) =
      _$CriticalRuleImpl.fromJson;

  @override
  String get id;
  @override
  String? get name;
  @override
  @JsonKey(name: 'attendance_type_ids')
  List<String> get attendanceTypeIds;
  @override
  List<int> get statuses;
  @override
  @JsonKey(name: 'threshold_type')
  CriticalRuleThresholdType get thresholdType;
  @override
  @JsonKey(name: 'threshold_value')
  int get thresholdValue;
  @override
  @JsonKey(name: 'period_type')
  CriticalRulePeriodType? get periodType;
  @override
  @JsonKey(name: 'period_days')
  int? get periodDays;
  @override
  CriticalRuleOperator get operator;
  @override
  bool get enabled;

  /// Create a copy of CriticalRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CriticalRuleImplCopyWith<_$CriticalRuleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TenantUser _$TenantUserFromJson(Map<String, dynamic> json) {
  return _TenantUser.fromJson(json);
}

/// @nodoc
mixin _$TenantUser {
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  int get tenantId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  int get role => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  @JsonKey(name: 'telegram_chat_id')
  String? get telegramChatId => throw _privateConstructorUsedError;
  bool get favorite => throw _privateConstructorUsedError;
  @JsonKey(name: 'parent_id')
  int? get parentId => throw _privateConstructorUsedError;

  /// Serializes this TenantUser to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TenantUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TenantUserCopyWith<TenantUser> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TenantUserCopyWith<$Res> {
  factory $TenantUserCopyWith(
    TenantUser value,
    $Res Function(TenantUser) then,
  ) = _$TenantUserCopyWithImpl<$Res, TenantUser>;
  @useResult
  $Res call({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    int tenantId,
    String userId,
    int role,
    String? email,
    @JsonKey(name: 'telegram_chat_id') String? telegramChatId,
    bool favorite,
    @JsonKey(name: 'parent_id') int? parentId,
  });
}

/// @nodoc
class _$TenantUserCopyWithImpl<$Res, $Val extends TenantUser>
    implements $TenantUserCopyWith<$Res> {
  _$TenantUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TenantUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? tenantId = null,
    Object? userId = null,
    Object? role = null,
    Object? email = freezed,
    Object? telegramChatId = freezed,
    Object? favorite = null,
    Object? parentId = freezed,
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
            userId:
                null == userId
                    ? _value.userId
                    : userId // ignore: cast_nullable_to_non_nullable
                        as String,
            role:
                null == role
                    ? _value.role
                    : role // ignore: cast_nullable_to_non_nullable
                        as int,
            email:
                freezed == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as String?,
            telegramChatId:
                freezed == telegramChatId
                    ? _value.telegramChatId
                    : telegramChatId // ignore: cast_nullable_to_non_nullable
                        as String?,
            favorite:
                null == favorite
                    ? _value.favorite
                    : favorite // ignore: cast_nullable_to_non_nullable
                        as bool,
            parentId:
                freezed == parentId
                    ? _value.parentId
                    : parentId // ignore: cast_nullable_to_non_nullable
                        as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TenantUserImplCopyWith<$Res>
    implements $TenantUserCopyWith<$Res> {
  factory _$$TenantUserImplCopyWith(
    _$TenantUserImpl value,
    $Res Function(_$TenantUserImpl) then,
  ) = __$$TenantUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    int tenantId,
    String userId,
    int role,
    String? email,
    @JsonKey(name: 'telegram_chat_id') String? telegramChatId,
    bool favorite,
    @JsonKey(name: 'parent_id') int? parentId,
  });
}

/// @nodoc
class __$$TenantUserImplCopyWithImpl<$Res>
    extends _$TenantUserCopyWithImpl<$Res, _$TenantUserImpl>
    implements _$$TenantUserImplCopyWith<$Res> {
  __$$TenantUserImplCopyWithImpl(
    _$TenantUserImpl _value,
    $Res Function(_$TenantUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TenantUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? tenantId = null,
    Object? userId = null,
    Object? role = null,
    Object? email = freezed,
    Object? telegramChatId = freezed,
    Object? favorite = null,
    Object? parentId = freezed,
  }) {
    return _then(
      _$TenantUserImpl(
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
        userId:
            null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                    as String,
        role:
            null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                    as int,
        email:
            freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as String?,
        telegramChatId:
            freezed == telegramChatId
                ? _value.telegramChatId
                : telegramChatId // ignore: cast_nullable_to_non_nullable
                    as String?,
        favorite:
            null == favorite
                ? _value.favorite
                : favorite // ignore: cast_nullable_to_non_nullable
                    as bool,
        parentId:
            freezed == parentId
                ? _value.parentId
                : parentId // ignore: cast_nullable_to_non_nullable
                    as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TenantUserImpl implements _TenantUser {
  const _$TenantUserImpl({
    this.id,
    @JsonKey(name: 'created_at') this.createdAt,
    required this.tenantId,
    required this.userId,
    required this.role,
    this.email,
    @JsonKey(name: 'telegram_chat_id') this.telegramChatId,
    this.favorite = false,
    @JsonKey(name: 'parent_id') this.parentId,
  });

  factory _$TenantUserImpl.fromJson(Map<String, dynamic> json) =>
      _$$TenantUserImplFromJson(json);

  @override
  final int? id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  final int tenantId;
  @override
  final String userId;
  @override
  final int role;
  @override
  final String? email;
  @override
  @JsonKey(name: 'telegram_chat_id')
  final String? telegramChatId;
  @override
  @JsonKey()
  final bool favorite;
  @override
  @JsonKey(name: 'parent_id')
  final int? parentId;

  @override
  String toString() {
    return 'TenantUser(id: $id, createdAt: $createdAt, tenantId: $tenantId, userId: $userId, role: $role, email: $email, telegramChatId: $telegramChatId, favorite: $favorite, parentId: $parentId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TenantUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.telegramChatId, telegramChatId) ||
                other.telegramChatId == telegramChatId) &&
            (identical(other.favorite, favorite) ||
                other.favorite == favorite) &&
            (identical(other.parentId, parentId) ||
                other.parentId == parentId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    createdAt,
    tenantId,
    userId,
    role,
    email,
    telegramChatId,
    favorite,
    parentId,
  );

  /// Create a copy of TenantUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TenantUserImplCopyWith<_$TenantUserImpl> get copyWith =>
      __$$TenantUserImplCopyWithImpl<_$TenantUserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TenantUserImplToJson(this);
  }
}

abstract class _TenantUser implements TenantUser {
  const factory _TenantUser({
    final int? id,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    required final int tenantId,
    required final String userId,
    required final int role,
    final String? email,
    @JsonKey(name: 'telegram_chat_id') final String? telegramChatId,
    final bool favorite,
    @JsonKey(name: 'parent_id') final int? parentId,
  }) = _$TenantUserImpl;

  factory _TenantUser.fromJson(Map<String, dynamic> json) =
      _$TenantUserImpl.fromJson;

  @override
  int? get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  int get tenantId;
  @override
  String get userId;
  @override
  int get role;
  @override
  String? get email;
  @override
  @JsonKey(name: 'telegram_chat_id')
  String? get telegramChatId;
  @override
  bool get favorite;
  @override
  @JsonKey(name: 'parent_id')
  int? get parentId;

  /// Create a copy of TenantUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TenantUserImplCopyWith<_$TenantUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
