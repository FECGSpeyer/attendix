// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'person.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Person _$PersonFromJson(Map<String, dynamic> json) {
  return _Person.fromJson(json);
}

/// @nodoc
mixin _$Person {
  // Base Person fields
  @_FlexibleIntConverter()
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  String get firstName => throw _privateConstructorUsedError;
  String get lastName => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get birthday => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get joined => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get left => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get email => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get appId => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get notes => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get img => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get telegramId => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get paused => throw _privateConstructorUsedError;
  @JsonKey(name: 'paused_until')
  @_FlexibleStringConverter()
  String? get pausedUntil => throw _privateConstructorUsedError;
  @_FlexibleIntConverter()
  int? get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'additional_fields')
  Map<String, dynamic>? get additionalFields =>
      throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get phone => throw _privateConstructorUsedError;
  @JsonKey(name: 'shift_id')
  @_FlexibleStringConverter()
  String? get shiftId => throw _privateConstructorUsedError;
  @JsonKey(name: 'shift_start')
  @_FlexibleStringConverter()
  String? get shiftStart => throw _privateConstructorUsedError;
  @JsonKey(name: 'shift_name')
  @_FlexibleStringConverter()
  String? get shiftName => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get pending => throw _privateConstructorUsedError;
  @JsonKey(name: 'self_register')
  @_FlexibleBoolConverter()
  bool get selfRegister => throw _privateConstructorUsedError; // Player extension fields
  @_FlexibleIntConverter()
  int? get instrument => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get hasTeacher => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get playsSince => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get isLeader => throw _privateConstructorUsedError;
  @_FlexibleIntConverter()
  int? get teacher => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get isCritical => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get criticalReason => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get lastSolve => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get correctBirthday => throw _privateConstructorUsedError;
  @_HistoryListConverter()
  List<PlayerHistoryEntry> get history => throw _privateConstructorUsedError;
  @_FlexibleStringListConverter()
  List<String>? get otherOrchestras => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get otherExercise => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get testResult => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get examinee => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get range => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get instruments => throw _privateConstructorUsedError;
  @JsonKey(name: 'parent_id')
  @_FlexibleIntConverter()
  int? get parentId => throw _privateConstructorUsedError;
  @_FlexibleIntConverter()
  int? get legacyId => throw _privateConstructorUsedError;
  @_FlexibleIntConverter()
  int? get legacyConductorId => throw _privateConstructorUsedError; // SETTINGS_EXT: Verknüpfung über Instanzen hinweg (Personen verknüpfen).
  // Nicht in toJson, damit generische Updates den Wert nie überschreiben.
  @JsonKey(name: 'global_person_id', includeToJson: false)
  @_FlexibleStringConverter()
  String? get globalPersonId => throw _privateConstructorUsedError; // Computed/transient fields (not in DB, used for display)
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleStringConverter()
  String? get groupName => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleStringConverter()
  String? get teacherName => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleStringConverter()
  String? get criticalReasonText => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleIntConverter()
  int? get percentage => throw _privateConstructorUsedError;

  /// Serializes this Person to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Person
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PersonCopyWith<Person> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PersonCopyWith<$Res> {
  factory $PersonCopyWith(Person value, $Res Function(Person) then) =
      _$PersonCopyWithImpl<$Res, Person>;
  @useResult
  $Res call({
    @_FlexibleIntConverter() int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    String firstName,
    String lastName,
    @_FlexibleStringConverter() String? birthday,
    @_FlexibleStringConverter() String? joined,
    @_FlexibleStringConverter() String? left,
    @_FlexibleStringConverter() String? email,
    @_FlexibleStringConverter() String? appId,
    @_FlexibleStringConverter() String? notes,
    @_FlexibleStringConverter() String? img,
    @_FlexibleStringConverter() String? telegramId,
    @_FlexibleBoolConverter() bool paused,
    @JsonKey(name: 'paused_until')
    @_FlexibleStringConverter()
    String? pausedUntil,
    @_FlexibleIntConverter() int? tenantId,
    @JsonKey(name: 'additional_fields') Map<String, dynamic>? additionalFields,
    @_FlexibleStringConverter() String? phone,
    @JsonKey(name: 'shift_id') @_FlexibleStringConverter() String? shiftId,
    @JsonKey(name: 'shift_start')
    @_FlexibleStringConverter()
    String? shiftStart,
    @JsonKey(name: 'shift_name') @_FlexibleStringConverter() String? shiftName,
    @_FlexibleBoolConverter() bool pending,
    @JsonKey(name: 'self_register') @_FlexibleBoolConverter() bool selfRegister,
    @_FlexibleIntConverter() int? instrument,
    @_FlexibleBoolConverter() bool hasTeacher,
    @_FlexibleStringConverter() String? playsSince,
    @_FlexibleBoolConverter() bool isLeader,
    @_FlexibleIntConverter() int? teacher,
    @_FlexibleBoolConverter() bool isCritical,
    @_FlexibleStringConverter() String? criticalReason,
    @_FlexibleStringConverter() String? lastSolve,
    @_FlexibleBoolConverter() bool correctBirthday,
    @_HistoryListConverter() List<PlayerHistoryEntry> history,
    @_FlexibleStringListConverter() List<String>? otherOrchestras,
    @_FlexibleStringConverter() String? otherExercise,
    @_FlexibleStringConverter() String? testResult,
    @_FlexibleBoolConverter() bool examinee,
    @_FlexibleStringConverter() String? range,
    @_FlexibleStringConverter() String? instruments,
    @JsonKey(name: 'parent_id') @_FlexibleIntConverter() int? parentId,
    @_FlexibleIntConverter() int? legacyId,
    @_FlexibleIntConverter() int? legacyConductorId,
    @JsonKey(name: 'global_person_id', includeToJson: false)
    @_FlexibleStringConverter()
    String? globalPersonId,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    String? groupName,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    String? teacherName,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    String? criticalReasonText,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleIntConverter()
    int? percentage,
  });
}

/// @nodoc
class _$PersonCopyWithImpl<$Res, $Val extends Person>
    implements $PersonCopyWith<$Res> {
  _$PersonCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Person
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? firstName = null,
    Object? lastName = null,
    Object? birthday = freezed,
    Object? joined = freezed,
    Object? left = freezed,
    Object? email = freezed,
    Object? appId = freezed,
    Object? notes = freezed,
    Object? img = freezed,
    Object? telegramId = freezed,
    Object? paused = null,
    Object? pausedUntil = freezed,
    Object? tenantId = freezed,
    Object? additionalFields = freezed,
    Object? phone = freezed,
    Object? shiftId = freezed,
    Object? shiftStart = freezed,
    Object? shiftName = freezed,
    Object? pending = null,
    Object? selfRegister = null,
    Object? instrument = freezed,
    Object? hasTeacher = null,
    Object? playsSince = freezed,
    Object? isLeader = null,
    Object? teacher = freezed,
    Object? isCritical = null,
    Object? criticalReason = freezed,
    Object? lastSolve = freezed,
    Object? correctBirthday = null,
    Object? history = null,
    Object? otherOrchestras = freezed,
    Object? otherExercise = freezed,
    Object? testResult = freezed,
    Object? examinee = null,
    Object? range = freezed,
    Object? instruments = freezed,
    Object? parentId = freezed,
    Object? legacyId = freezed,
    Object? legacyConductorId = freezed,
    Object? globalPersonId = freezed,
    Object? groupName = freezed,
    Object? teacherName = freezed,
    Object? criticalReasonText = freezed,
    Object? percentage = freezed,
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
            firstName:
                null == firstName
                    ? _value.firstName
                    : firstName // ignore: cast_nullable_to_non_nullable
                        as String,
            lastName:
                null == lastName
                    ? _value.lastName
                    : lastName // ignore: cast_nullable_to_non_nullable
                        as String,
            birthday:
                freezed == birthday
                    ? _value.birthday
                    : birthday // ignore: cast_nullable_to_non_nullable
                        as String?,
            joined:
                freezed == joined
                    ? _value.joined
                    : joined // ignore: cast_nullable_to_non_nullable
                        as String?,
            left:
                freezed == left
                    ? _value.left
                    : left // ignore: cast_nullable_to_non_nullable
                        as String?,
            email:
                freezed == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as String?,
            appId:
                freezed == appId
                    ? _value.appId
                    : appId // ignore: cast_nullable_to_non_nullable
                        as String?,
            notes:
                freezed == notes
                    ? _value.notes
                    : notes // ignore: cast_nullable_to_non_nullable
                        as String?,
            img:
                freezed == img
                    ? _value.img
                    : img // ignore: cast_nullable_to_non_nullable
                        as String?,
            telegramId:
                freezed == telegramId
                    ? _value.telegramId
                    : telegramId // ignore: cast_nullable_to_non_nullable
                        as String?,
            paused:
                null == paused
                    ? _value.paused
                    : paused // ignore: cast_nullable_to_non_nullable
                        as bool,
            pausedUntil:
                freezed == pausedUntil
                    ? _value.pausedUntil
                    : pausedUntil // ignore: cast_nullable_to_non_nullable
                        as String?,
            tenantId:
                freezed == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int?,
            additionalFields:
                freezed == additionalFields
                    ? _value.additionalFields
                    : additionalFields // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
            phone:
                freezed == phone
                    ? _value.phone
                    : phone // ignore: cast_nullable_to_non_nullable
                        as String?,
            shiftId:
                freezed == shiftId
                    ? _value.shiftId
                    : shiftId // ignore: cast_nullable_to_non_nullable
                        as String?,
            shiftStart:
                freezed == shiftStart
                    ? _value.shiftStart
                    : shiftStart // ignore: cast_nullable_to_non_nullable
                        as String?,
            shiftName:
                freezed == shiftName
                    ? _value.shiftName
                    : shiftName // ignore: cast_nullable_to_non_nullable
                        as String?,
            pending:
                null == pending
                    ? _value.pending
                    : pending // ignore: cast_nullable_to_non_nullable
                        as bool,
            selfRegister:
                null == selfRegister
                    ? _value.selfRegister
                    : selfRegister // ignore: cast_nullable_to_non_nullable
                        as bool,
            instrument:
                freezed == instrument
                    ? _value.instrument
                    : instrument // ignore: cast_nullable_to_non_nullable
                        as int?,
            hasTeacher:
                null == hasTeacher
                    ? _value.hasTeacher
                    : hasTeacher // ignore: cast_nullable_to_non_nullable
                        as bool,
            playsSince:
                freezed == playsSince
                    ? _value.playsSince
                    : playsSince // ignore: cast_nullable_to_non_nullable
                        as String?,
            isLeader:
                null == isLeader
                    ? _value.isLeader
                    : isLeader // ignore: cast_nullable_to_non_nullable
                        as bool,
            teacher:
                freezed == teacher
                    ? _value.teacher
                    : teacher // ignore: cast_nullable_to_non_nullable
                        as int?,
            isCritical:
                null == isCritical
                    ? _value.isCritical
                    : isCritical // ignore: cast_nullable_to_non_nullable
                        as bool,
            criticalReason:
                freezed == criticalReason
                    ? _value.criticalReason
                    : criticalReason // ignore: cast_nullable_to_non_nullable
                        as String?,
            lastSolve:
                freezed == lastSolve
                    ? _value.lastSolve
                    : lastSolve // ignore: cast_nullable_to_non_nullable
                        as String?,
            correctBirthday:
                null == correctBirthday
                    ? _value.correctBirthday
                    : correctBirthday // ignore: cast_nullable_to_non_nullable
                        as bool,
            history:
                null == history
                    ? _value.history
                    : history // ignore: cast_nullable_to_non_nullable
                        as List<PlayerHistoryEntry>,
            otherOrchestras:
                freezed == otherOrchestras
                    ? _value.otherOrchestras
                    : otherOrchestras // ignore: cast_nullable_to_non_nullable
                        as List<String>?,
            otherExercise:
                freezed == otherExercise
                    ? _value.otherExercise
                    : otherExercise // ignore: cast_nullable_to_non_nullable
                        as String?,
            testResult:
                freezed == testResult
                    ? _value.testResult
                    : testResult // ignore: cast_nullable_to_non_nullable
                        as String?,
            examinee:
                null == examinee
                    ? _value.examinee
                    : examinee // ignore: cast_nullable_to_non_nullable
                        as bool,
            range:
                freezed == range
                    ? _value.range
                    : range // ignore: cast_nullable_to_non_nullable
                        as String?,
            instruments:
                freezed == instruments
                    ? _value.instruments
                    : instruments // ignore: cast_nullable_to_non_nullable
                        as String?,
            parentId:
                freezed == parentId
                    ? _value.parentId
                    : parentId // ignore: cast_nullable_to_non_nullable
                        as int?,
            legacyId:
                freezed == legacyId
                    ? _value.legacyId
                    : legacyId // ignore: cast_nullable_to_non_nullable
                        as int?,
            legacyConductorId:
                freezed == legacyConductorId
                    ? _value.legacyConductorId
                    : legacyConductorId // ignore: cast_nullable_to_non_nullable
                        as int?,
            globalPersonId:
                freezed == globalPersonId
                    ? _value.globalPersonId
                    : globalPersonId // ignore: cast_nullable_to_non_nullable
                        as String?,
            groupName:
                freezed == groupName
                    ? _value.groupName
                    : groupName // ignore: cast_nullable_to_non_nullable
                        as String?,
            teacherName:
                freezed == teacherName
                    ? _value.teacherName
                    : teacherName // ignore: cast_nullable_to_non_nullable
                        as String?,
            criticalReasonText:
                freezed == criticalReasonText
                    ? _value.criticalReasonText
                    : criticalReasonText // ignore: cast_nullable_to_non_nullable
                        as String?,
            percentage:
                freezed == percentage
                    ? _value.percentage
                    : percentage // ignore: cast_nullable_to_non_nullable
                        as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PersonImplCopyWith<$Res> implements $PersonCopyWith<$Res> {
  factory _$$PersonImplCopyWith(
    _$PersonImpl value,
    $Res Function(_$PersonImpl) then,
  ) = __$$PersonImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @_FlexibleIntConverter() int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    String firstName,
    String lastName,
    @_FlexibleStringConverter() String? birthday,
    @_FlexibleStringConverter() String? joined,
    @_FlexibleStringConverter() String? left,
    @_FlexibleStringConverter() String? email,
    @_FlexibleStringConverter() String? appId,
    @_FlexibleStringConverter() String? notes,
    @_FlexibleStringConverter() String? img,
    @_FlexibleStringConverter() String? telegramId,
    @_FlexibleBoolConverter() bool paused,
    @JsonKey(name: 'paused_until')
    @_FlexibleStringConverter()
    String? pausedUntil,
    @_FlexibleIntConverter() int? tenantId,
    @JsonKey(name: 'additional_fields') Map<String, dynamic>? additionalFields,
    @_FlexibleStringConverter() String? phone,
    @JsonKey(name: 'shift_id') @_FlexibleStringConverter() String? shiftId,
    @JsonKey(name: 'shift_start')
    @_FlexibleStringConverter()
    String? shiftStart,
    @JsonKey(name: 'shift_name') @_FlexibleStringConverter() String? shiftName,
    @_FlexibleBoolConverter() bool pending,
    @JsonKey(name: 'self_register') @_FlexibleBoolConverter() bool selfRegister,
    @_FlexibleIntConverter() int? instrument,
    @_FlexibleBoolConverter() bool hasTeacher,
    @_FlexibleStringConverter() String? playsSince,
    @_FlexibleBoolConverter() bool isLeader,
    @_FlexibleIntConverter() int? teacher,
    @_FlexibleBoolConverter() bool isCritical,
    @_FlexibleStringConverter() String? criticalReason,
    @_FlexibleStringConverter() String? lastSolve,
    @_FlexibleBoolConverter() bool correctBirthday,
    @_HistoryListConverter() List<PlayerHistoryEntry> history,
    @_FlexibleStringListConverter() List<String>? otherOrchestras,
    @_FlexibleStringConverter() String? otherExercise,
    @_FlexibleStringConverter() String? testResult,
    @_FlexibleBoolConverter() bool examinee,
    @_FlexibleStringConverter() String? range,
    @_FlexibleStringConverter() String? instruments,
    @JsonKey(name: 'parent_id') @_FlexibleIntConverter() int? parentId,
    @_FlexibleIntConverter() int? legacyId,
    @_FlexibleIntConverter() int? legacyConductorId,
    @JsonKey(name: 'global_person_id', includeToJson: false)
    @_FlexibleStringConverter()
    String? globalPersonId,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    String? groupName,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    String? teacherName,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    String? criticalReasonText,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleIntConverter()
    int? percentage,
  });
}

/// @nodoc
class __$$PersonImplCopyWithImpl<$Res>
    extends _$PersonCopyWithImpl<$Res, _$PersonImpl>
    implements _$$PersonImplCopyWith<$Res> {
  __$$PersonImplCopyWithImpl(
    _$PersonImpl _value,
    $Res Function(_$PersonImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Person
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? firstName = null,
    Object? lastName = null,
    Object? birthday = freezed,
    Object? joined = freezed,
    Object? left = freezed,
    Object? email = freezed,
    Object? appId = freezed,
    Object? notes = freezed,
    Object? img = freezed,
    Object? telegramId = freezed,
    Object? paused = null,
    Object? pausedUntil = freezed,
    Object? tenantId = freezed,
    Object? additionalFields = freezed,
    Object? phone = freezed,
    Object? shiftId = freezed,
    Object? shiftStart = freezed,
    Object? shiftName = freezed,
    Object? pending = null,
    Object? selfRegister = null,
    Object? instrument = freezed,
    Object? hasTeacher = null,
    Object? playsSince = freezed,
    Object? isLeader = null,
    Object? teacher = freezed,
    Object? isCritical = null,
    Object? criticalReason = freezed,
    Object? lastSolve = freezed,
    Object? correctBirthday = null,
    Object? history = null,
    Object? otherOrchestras = freezed,
    Object? otherExercise = freezed,
    Object? testResult = freezed,
    Object? examinee = null,
    Object? range = freezed,
    Object? instruments = freezed,
    Object? parentId = freezed,
    Object? legacyId = freezed,
    Object? legacyConductorId = freezed,
    Object? globalPersonId = freezed,
    Object? groupName = freezed,
    Object? teacherName = freezed,
    Object? criticalReasonText = freezed,
    Object? percentage = freezed,
  }) {
    return _then(
      _$PersonImpl(
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
        firstName:
            null == firstName
                ? _value.firstName
                : firstName // ignore: cast_nullable_to_non_nullable
                    as String,
        lastName:
            null == lastName
                ? _value.lastName
                : lastName // ignore: cast_nullable_to_non_nullable
                    as String,
        birthday:
            freezed == birthday
                ? _value.birthday
                : birthday // ignore: cast_nullable_to_non_nullable
                    as String?,
        joined:
            freezed == joined
                ? _value.joined
                : joined // ignore: cast_nullable_to_non_nullable
                    as String?,
        left:
            freezed == left
                ? _value.left
                : left // ignore: cast_nullable_to_non_nullable
                    as String?,
        email:
            freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as String?,
        appId:
            freezed == appId
                ? _value.appId
                : appId // ignore: cast_nullable_to_non_nullable
                    as String?,
        notes:
            freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                    as String?,
        img:
            freezed == img
                ? _value.img
                : img // ignore: cast_nullable_to_non_nullable
                    as String?,
        telegramId:
            freezed == telegramId
                ? _value.telegramId
                : telegramId // ignore: cast_nullable_to_non_nullable
                    as String?,
        paused:
            null == paused
                ? _value.paused
                : paused // ignore: cast_nullable_to_non_nullable
                    as bool,
        pausedUntil:
            freezed == pausedUntil
                ? _value.pausedUntil
                : pausedUntil // ignore: cast_nullable_to_non_nullable
                    as String?,
        tenantId:
            freezed == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int?,
        additionalFields:
            freezed == additionalFields
                ? _value._additionalFields
                : additionalFields // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
        phone:
            freezed == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                    as String?,
        shiftId:
            freezed == shiftId
                ? _value.shiftId
                : shiftId // ignore: cast_nullable_to_non_nullable
                    as String?,
        shiftStart:
            freezed == shiftStart
                ? _value.shiftStart
                : shiftStart // ignore: cast_nullable_to_non_nullable
                    as String?,
        shiftName:
            freezed == shiftName
                ? _value.shiftName
                : shiftName // ignore: cast_nullable_to_non_nullable
                    as String?,
        pending:
            null == pending
                ? _value.pending
                : pending // ignore: cast_nullable_to_non_nullable
                    as bool,
        selfRegister:
            null == selfRegister
                ? _value.selfRegister
                : selfRegister // ignore: cast_nullable_to_non_nullable
                    as bool,
        instrument:
            freezed == instrument
                ? _value.instrument
                : instrument // ignore: cast_nullable_to_non_nullable
                    as int?,
        hasTeacher:
            null == hasTeacher
                ? _value.hasTeacher
                : hasTeacher // ignore: cast_nullable_to_non_nullable
                    as bool,
        playsSince:
            freezed == playsSince
                ? _value.playsSince
                : playsSince // ignore: cast_nullable_to_non_nullable
                    as String?,
        isLeader:
            null == isLeader
                ? _value.isLeader
                : isLeader // ignore: cast_nullable_to_non_nullable
                    as bool,
        teacher:
            freezed == teacher
                ? _value.teacher
                : teacher // ignore: cast_nullable_to_non_nullable
                    as int?,
        isCritical:
            null == isCritical
                ? _value.isCritical
                : isCritical // ignore: cast_nullable_to_non_nullable
                    as bool,
        criticalReason:
            freezed == criticalReason
                ? _value.criticalReason
                : criticalReason // ignore: cast_nullable_to_non_nullable
                    as String?,
        lastSolve:
            freezed == lastSolve
                ? _value.lastSolve
                : lastSolve // ignore: cast_nullable_to_non_nullable
                    as String?,
        correctBirthday:
            null == correctBirthday
                ? _value.correctBirthday
                : correctBirthday // ignore: cast_nullable_to_non_nullable
                    as bool,
        history:
            null == history
                ? _value._history
                : history // ignore: cast_nullable_to_non_nullable
                    as List<PlayerHistoryEntry>,
        otherOrchestras:
            freezed == otherOrchestras
                ? _value._otherOrchestras
                : otherOrchestras // ignore: cast_nullable_to_non_nullable
                    as List<String>?,
        otherExercise:
            freezed == otherExercise
                ? _value.otherExercise
                : otherExercise // ignore: cast_nullable_to_non_nullable
                    as String?,
        testResult:
            freezed == testResult
                ? _value.testResult
                : testResult // ignore: cast_nullable_to_non_nullable
                    as String?,
        examinee:
            null == examinee
                ? _value.examinee
                : examinee // ignore: cast_nullable_to_non_nullable
                    as bool,
        range:
            freezed == range
                ? _value.range
                : range // ignore: cast_nullable_to_non_nullable
                    as String?,
        instruments:
            freezed == instruments
                ? _value.instruments
                : instruments // ignore: cast_nullable_to_non_nullable
                    as String?,
        parentId:
            freezed == parentId
                ? _value.parentId
                : parentId // ignore: cast_nullable_to_non_nullable
                    as int?,
        legacyId:
            freezed == legacyId
                ? _value.legacyId
                : legacyId // ignore: cast_nullable_to_non_nullable
                    as int?,
        legacyConductorId:
            freezed == legacyConductorId
                ? _value.legacyConductorId
                : legacyConductorId // ignore: cast_nullable_to_non_nullable
                    as int?,
        globalPersonId:
            freezed == globalPersonId
                ? _value.globalPersonId
                : globalPersonId // ignore: cast_nullable_to_non_nullable
                    as String?,
        groupName:
            freezed == groupName
                ? _value.groupName
                : groupName // ignore: cast_nullable_to_non_nullable
                    as String?,
        teacherName:
            freezed == teacherName
                ? _value.teacherName
                : teacherName // ignore: cast_nullable_to_non_nullable
                    as String?,
        criticalReasonText:
            freezed == criticalReasonText
                ? _value.criticalReasonText
                : criticalReasonText // ignore: cast_nullable_to_non_nullable
                    as String?,
        percentage:
            freezed == percentage
                ? _value.percentage
                : percentage // ignore: cast_nullable_to_non_nullable
                    as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PersonImpl implements _Person {
  const _$PersonImpl({
    @_FlexibleIntConverter() this.id,
    @JsonKey(name: 'created_at') this.createdAt,
    this.firstName = '',
    this.lastName = '',
    @_FlexibleStringConverter() this.birthday,
    @_FlexibleStringConverter() this.joined,
    @_FlexibleStringConverter() this.left,
    @_FlexibleStringConverter() this.email,
    @_FlexibleStringConverter() this.appId,
    @_FlexibleStringConverter() this.notes,
    @_FlexibleStringConverter() this.img,
    @_FlexibleStringConverter() this.telegramId,
    @_FlexibleBoolConverter() this.paused = false,
    @JsonKey(name: 'paused_until') @_FlexibleStringConverter() this.pausedUntil,
    @_FlexibleIntConverter() this.tenantId,
    @JsonKey(name: 'additional_fields')
    final Map<String, dynamic>? additionalFields,
    @_FlexibleStringConverter() this.phone,
    @JsonKey(name: 'shift_id') @_FlexibleStringConverter() this.shiftId,
    @JsonKey(name: 'shift_start') @_FlexibleStringConverter() this.shiftStart,
    @JsonKey(name: 'shift_name') @_FlexibleStringConverter() this.shiftName,
    @_FlexibleBoolConverter() this.pending = false,
    @JsonKey(name: 'self_register')
    @_FlexibleBoolConverter()
    this.selfRegister = false,
    @_FlexibleIntConverter() this.instrument,
    @_FlexibleBoolConverter() this.hasTeacher = false,
    @_FlexibleStringConverter() this.playsSince,
    @_FlexibleBoolConverter() this.isLeader = false,
    @_FlexibleIntConverter() this.teacher,
    @_FlexibleBoolConverter() this.isCritical = false,
    @_FlexibleStringConverter() this.criticalReason,
    @_FlexibleStringConverter() this.lastSolve,
    @_FlexibleBoolConverter() this.correctBirthday = false,
    @_HistoryListConverter() final List<PlayerHistoryEntry> history = const [],
    @_FlexibleStringListConverter() final List<String>? otherOrchestras,
    @_FlexibleStringConverter() this.otherExercise,
    @_FlexibleStringConverter() this.testResult,
    @_FlexibleBoolConverter() this.examinee = false,
    @_FlexibleStringConverter() this.range,
    @_FlexibleStringConverter() this.instruments,
    @JsonKey(name: 'parent_id') @_FlexibleIntConverter() this.parentId,
    @_FlexibleIntConverter() this.legacyId,
    @_FlexibleIntConverter() this.legacyConductorId,
    @JsonKey(name: 'global_person_id', includeToJson: false)
    @_FlexibleStringConverter()
    this.globalPersonId,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    this.groupName,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    this.teacherName,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    this.criticalReasonText,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleIntConverter()
    this.percentage,
  }) : _additionalFields = additionalFields,
       _history = history,
       _otherOrchestras = otherOrchestras;

  factory _$PersonImpl.fromJson(Map<String, dynamic> json) =>
      _$$PersonImplFromJson(json);

  // Base Person fields
  @override
  @_FlexibleIntConverter()
  final int? id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey()
  final String firstName;
  @override
  @JsonKey()
  final String lastName;
  @override
  @_FlexibleStringConverter()
  final String? birthday;
  @override
  @_FlexibleStringConverter()
  final String? joined;
  @override
  @_FlexibleStringConverter()
  final String? left;
  @override
  @_FlexibleStringConverter()
  final String? email;
  @override
  @_FlexibleStringConverter()
  final String? appId;
  @override
  @_FlexibleStringConverter()
  final String? notes;
  @override
  @_FlexibleStringConverter()
  final String? img;
  @override
  @_FlexibleStringConverter()
  final String? telegramId;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool paused;
  @override
  @JsonKey(name: 'paused_until')
  @_FlexibleStringConverter()
  final String? pausedUntil;
  @override
  @_FlexibleIntConverter()
  final int? tenantId;
  final Map<String, dynamic>? _additionalFields;
  @override
  @JsonKey(name: 'additional_fields')
  Map<String, dynamic>? get additionalFields {
    final value = _additionalFields;
    if (value == null) return null;
    if (_additionalFields is EqualUnmodifiableMapView) return _additionalFields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @_FlexibleStringConverter()
  final String? phone;
  @override
  @JsonKey(name: 'shift_id')
  @_FlexibleStringConverter()
  final String? shiftId;
  @override
  @JsonKey(name: 'shift_start')
  @_FlexibleStringConverter()
  final String? shiftStart;
  @override
  @JsonKey(name: 'shift_name')
  @_FlexibleStringConverter()
  final String? shiftName;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool pending;
  @override
  @JsonKey(name: 'self_register')
  @_FlexibleBoolConverter()
  final bool selfRegister;
  // Player extension fields
  @override
  @_FlexibleIntConverter()
  final int? instrument;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool hasTeacher;
  @override
  @_FlexibleStringConverter()
  final String? playsSince;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool isLeader;
  @override
  @_FlexibleIntConverter()
  final int? teacher;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool isCritical;
  @override
  @_FlexibleStringConverter()
  final String? criticalReason;
  @override
  @_FlexibleStringConverter()
  final String? lastSolve;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool correctBirthday;
  final List<PlayerHistoryEntry> _history;
  @override
  @JsonKey()
  @_HistoryListConverter()
  List<PlayerHistoryEntry> get history {
    if (_history is EqualUnmodifiableListView) return _history;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_history);
  }

  final List<String>? _otherOrchestras;
  @override
  @_FlexibleStringListConverter()
  List<String>? get otherOrchestras {
    final value = _otherOrchestras;
    if (value == null) return null;
    if (_otherOrchestras is EqualUnmodifiableListView) return _otherOrchestras;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @_FlexibleStringConverter()
  final String? otherExercise;
  @override
  @_FlexibleStringConverter()
  final String? testResult;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool examinee;
  @override
  @_FlexibleStringConverter()
  final String? range;
  @override
  @_FlexibleStringConverter()
  final String? instruments;
  @override
  @JsonKey(name: 'parent_id')
  @_FlexibleIntConverter()
  final int? parentId;
  @override
  @_FlexibleIntConverter()
  final int? legacyId;
  @override
  @_FlexibleIntConverter()
  final int? legacyConductorId;
  // SETTINGS_EXT: Verknüpfung über Instanzen hinweg (Personen verknüpfen).
  // Nicht in toJson, damit generische Updates den Wert nie überschreiben.
  @override
  @JsonKey(name: 'global_person_id', includeToJson: false)
  @_FlexibleStringConverter()
  final String? globalPersonId;
  // Computed/transient fields (not in DB, used for display)
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleStringConverter()
  final String? groupName;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleStringConverter()
  final String? teacherName;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleStringConverter()
  final String? criticalReasonText;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleIntConverter()
  final int? percentage;

  @override
  String toString() {
    return 'Person(id: $id, createdAt: $createdAt, firstName: $firstName, lastName: $lastName, birthday: $birthday, joined: $joined, left: $left, email: $email, appId: $appId, notes: $notes, img: $img, telegramId: $telegramId, paused: $paused, pausedUntil: $pausedUntil, tenantId: $tenantId, additionalFields: $additionalFields, phone: $phone, shiftId: $shiftId, shiftStart: $shiftStart, shiftName: $shiftName, pending: $pending, selfRegister: $selfRegister, instrument: $instrument, hasTeacher: $hasTeacher, playsSince: $playsSince, isLeader: $isLeader, teacher: $teacher, isCritical: $isCritical, criticalReason: $criticalReason, lastSolve: $lastSolve, correctBirthday: $correctBirthday, history: $history, otherOrchestras: $otherOrchestras, otherExercise: $otherExercise, testResult: $testResult, examinee: $examinee, range: $range, instruments: $instruments, parentId: $parentId, legacyId: $legacyId, legacyConductorId: $legacyConductorId, globalPersonId: $globalPersonId, groupName: $groupName, teacherName: $teacherName, criticalReasonText: $criticalReasonText, percentage: $percentage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PersonImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.birthday, birthday) ||
                other.birthday == birthday) &&
            (identical(other.joined, joined) || other.joined == joined) &&
            (identical(other.left, left) || other.left == left) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.appId, appId) || other.appId == appId) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.img, img) || other.img == img) &&
            (identical(other.telegramId, telegramId) ||
                other.telegramId == telegramId) &&
            (identical(other.paused, paused) || other.paused == paused) &&
            (identical(other.pausedUntil, pausedUntil) ||
                other.pausedUntil == pausedUntil) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            const DeepCollectionEquality().equals(
              other._additionalFields,
              _additionalFields,
            ) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.shiftId, shiftId) || other.shiftId == shiftId) &&
            (identical(other.shiftStart, shiftStart) ||
                other.shiftStart == shiftStart) &&
            (identical(other.shiftName, shiftName) ||
                other.shiftName == shiftName) &&
            (identical(other.pending, pending) || other.pending == pending) &&
            (identical(other.selfRegister, selfRegister) ||
                other.selfRegister == selfRegister) &&
            (identical(other.instrument, instrument) ||
                other.instrument == instrument) &&
            (identical(other.hasTeacher, hasTeacher) ||
                other.hasTeacher == hasTeacher) &&
            (identical(other.playsSince, playsSince) ||
                other.playsSince == playsSince) &&
            (identical(other.isLeader, isLeader) ||
                other.isLeader == isLeader) &&
            (identical(other.teacher, teacher) || other.teacher == teacher) &&
            (identical(other.isCritical, isCritical) ||
                other.isCritical == isCritical) &&
            (identical(other.criticalReason, criticalReason) ||
                other.criticalReason == criticalReason) &&
            (identical(other.lastSolve, lastSolve) ||
                other.lastSolve == lastSolve) &&
            (identical(other.correctBirthday, correctBirthday) ||
                other.correctBirthday == correctBirthday) &&
            const DeepCollectionEquality().equals(other._history, _history) &&
            const DeepCollectionEquality().equals(
              other._otherOrchestras,
              _otherOrchestras,
            ) &&
            (identical(other.otherExercise, otherExercise) ||
                other.otherExercise == otherExercise) &&
            (identical(other.testResult, testResult) ||
                other.testResult == testResult) &&
            (identical(other.examinee, examinee) ||
                other.examinee == examinee) &&
            (identical(other.range, range) || other.range == range) &&
            (identical(other.instruments, instruments) ||
                other.instruments == instruments) &&
            (identical(other.parentId, parentId) ||
                other.parentId == parentId) &&
            (identical(other.legacyId, legacyId) ||
                other.legacyId == legacyId) &&
            (identical(other.legacyConductorId, legacyConductorId) ||
                other.legacyConductorId == legacyConductorId) &&
            (identical(other.globalPersonId, globalPersonId) ||
                other.globalPersonId == globalPersonId) &&
            (identical(other.groupName, groupName) ||
                other.groupName == groupName) &&
            (identical(other.teacherName, teacherName) ||
                other.teacherName == teacherName) &&
            (identical(other.criticalReasonText, criticalReasonText) ||
                other.criticalReasonText == criticalReasonText) &&
            (identical(other.percentage, percentage) ||
                other.percentage == percentage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    createdAt,
    firstName,
    lastName,
    birthday,
    joined,
    left,
    email,
    appId,
    notes,
    img,
    telegramId,
    paused,
    pausedUntil,
    tenantId,
    const DeepCollectionEquality().hash(_additionalFields),
    phone,
    shiftId,
    shiftStart,
    shiftName,
    pending,
    selfRegister,
    instrument,
    hasTeacher,
    playsSince,
    isLeader,
    teacher,
    isCritical,
    criticalReason,
    lastSolve,
    correctBirthday,
    const DeepCollectionEquality().hash(_history),
    const DeepCollectionEquality().hash(_otherOrchestras),
    otherExercise,
    testResult,
    examinee,
    range,
    instruments,
    parentId,
    legacyId,
    legacyConductorId,
    globalPersonId,
    groupName,
    teacherName,
    criticalReasonText,
    percentage,
  ]);

  /// Create a copy of Person
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PersonImplCopyWith<_$PersonImpl> get copyWith =>
      __$$PersonImplCopyWithImpl<_$PersonImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PersonImplToJson(this);
  }
}

abstract class _Person implements Person {
  const factory _Person({
    @_FlexibleIntConverter() final int? id,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    final String firstName,
    final String lastName,
    @_FlexibleStringConverter() final String? birthday,
    @_FlexibleStringConverter() final String? joined,
    @_FlexibleStringConverter() final String? left,
    @_FlexibleStringConverter() final String? email,
    @_FlexibleStringConverter() final String? appId,
    @_FlexibleStringConverter() final String? notes,
    @_FlexibleStringConverter() final String? img,
    @_FlexibleStringConverter() final String? telegramId,
    @_FlexibleBoolConverter() final bool paused,
    @JsonKey(name: 'paused_until')
    @_FlexibleStringConverter()
    final String? pausedUntil,
    @_FlexibleIntConverter() final int? tenantId,
    @JsonKey(name: 'additional_fields')
    final Map<String, dynamic>? additionalFields,
    @_FlexibleStringConverter() final String? phone,
    @JsonKey(name: 'shift_id')
    @_FlexibleStringConverter()
    final String? shiftId,
    @JsonKey(name: 'shift_start')
    @_FlexibleStringConverter()
    final String? shiftStart,
    @JsonKey(name: 'shift_name')
    @_FlexibleStringConverter()
    final String? shiftName,
    @_FlexibleBoolConverter() final bool pending,
    @JsonKey(name: 'self_register')
    @_FlexibleBoolConverter()
    final bool selfRegister,
    @_FlexibleIntConverter() final int? instrument,
    @_FlexibleBoolConverter() final bool hasTeacher,
    @_FlexibleStringConverter() final String? playsSince,
    @_FlexibleBoolConverter() final bool isLeader,
    @_FlexibleIntConverter() final int? teacher,
    @_FlexibleBoolConverter() final bool isCritical,
    @_FlexibleStringConverter() final String? criticalReason,
    @_FlexibleStringConverter() final String? lastSolve,
    @_FlexibleBoolConverter() final bool correctBirthday,
    @_HistoryListConverter() final List<PlayerHistoryEntry> history,
    @_FlexibleStringListConverter() final List<String>? otherOrchestras,
    @_FlexibleStringConverter() final String? otherExercise,
    @_FlexibleStringConverter() final String? testResult,
    @_FlexibleBoolConverter() final bool examinee,
    @_FlexibleStringConverter() final String? range,
    @_FlexibleStringConverter() final String? instruments,
    @JsonKey(name: 'parent_id') @_FlexibleIntConverter() final int? parentId,
    @_FlexibleIntConverter() final int? legacyId,
    @_FlexibleIntConverter() final int? legacyConductorId,
    @JsonKey(name: 'global_person_id', includeToJson: false)
    @_FlexibleStringConverter()
    final String? globalPersonId,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    final String? groupName,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    final String? teacherName,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter()
    final String? criticalReasonText,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleIntConverter()
    final int? percentage,
  }) = _$PersonImpl;

  factory _Person.fromJson(Map<String, dynamic> json) = _$PersonImpl.fromJson;

  // Base Person fields
  @override
  @_FlexibleIntConverter()
  int? get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  String get firstName;
  @override
  String get lastName;
  @override
  @_FlexibleStringConverter()
  String? get birthday;
  @override
  @_FlexibleStringConverter()
  String? get joined;
  @override
  @_FlexibleStringConverter()
  String? get left;
  @override
  @_FlexibleStringConverter()
  String? get email;
  @override
  @_FlexibleStringConverter()
  String? get appId;
  @override
  @_FlexibleStringConverter()
  String? get notes;
  @override
  @_FlexibleStringConverter()
  String? get img;
  @override
  @_FlexibleStringConverter()
  String? get telegramId;
  @override
  @_FlexibleBoolConverter()
  bool get paused;
  @override
  @JsonKey(name: 'paused_until')
  @_FlexibleStringConverter()
  String? get pausedUntil;
  @override
  @_FlexibleIntConverter()
  int? get tenantId;
  @override
  @JsonKey(name: 'additional_fields')
  Map<String, dynamic>? get additionalFields;
  @override
  @_FlexibleStringConverter()
  String? get phone;
  @override
  @JsonKey(name: 'shift_id')
  @_FlexibleStringConverter()
  String? get shiftId;
  @override
  @JsonKey(name: 'shift_start')
  @_FlexibleStringConverter()
  String? get shiftStart;
  @override
  @JsonKey(name: 'shift_name')
  @_FlexibleStringConverter()
  String? get shiftName;
  @override
  @_FlexibleBoolConverter()
  bool get pending;
  @override
  @JsonKey(name: 'self_register')
  @_FlexibleBoolConverter()
  bool get selfRegister; // Player extension fields
  @override
  @_FlexibleIntConverter()
  int? get instrument;
  @override
  @_FlexibleBoolConverter()
  bool get hasTeacher;
  @override
  @_FlexibleStringConverter()
  String? get playsSince;
  @override
  @_FlexibleBoolConverter()
  bool get isLeader;
  @override
  @_FlexibleIntConverter()
  int? get teacher;
  @override
  @_FlexibleBoolConverter()
  bool get isCritical;
  @override
  @_FlexibleStringConverter()
  String? get criticalReason;
  @override
  @_FlexibleStringConverter()
  String? get lastSolve;
  @override
  @_FlexibleBoolConverter()
  bool get correctBirthday;
  @override
  @_HistoryListConverter()
  List<PlayerHistoryEntry> get history;
  @override
  @_FlexibleStringListConverter()
  List<String>? get otherOrchestras;
  @override
  @_FlexibleStringConverter()
  String? get otherExercise;
  @override
  @_FlexibleStringConverter()
  String? get testResult;
  @override
  @_FlexibleBoolConverter()
  bool get examinee;
  @override
  @_FlexibleStringConverter()
  String? get range;
  @override
  @_FlexibleStringConverter()
  String? get instruments;
  @override
  @JsonKey(name: 'parent_id')
  @_FlexibleIntConverter()
  int? get parentId;
  @override
  @_FlexibleIntConverter()
  int? get legacyId;
  @override
  @_FlexibleIntConverter()
  int? get legacyConductorId; // SETTINGS_EXT: Verknüpfung über Instanzen hinweg (Personen verknüpfen).
  // Nicht in toJson, damit generische Updates den Wert nie überschreiben.
  @override
  @JsonKey(name: 'global_person_id', includeToJson: false)
  @_FlexibleStringConverter()
  String? get globalPersonId; // Computed/transient fields (not in DB, used for display)
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleStringConverter()
  String? get groupName;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleStringConverter()
  String? get teacherName;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleStringConverter()
  String? get criticalReasonText;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @_FlexibleIntConverter()
  int? get percentage;

  /// Create a copy of Person
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PersonImplCopyWith<_$PersonImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlayerHistoryEntry _$PlayerHistoryEntryFromJson(Map<String, dynamic> json) {
  return _PlayerHistoryEntry.fromJson(json);
}

/// @nodoc
mixin _$PlayerHistoryEntry {
  @_FlexibleStringConverter()
  String? get date => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get text => throw _privateConstructorUsedError;
  @_FlexibleIntConverter()
  int? get type => throw _privateConstructorUsedError;

  /// Serializes this PlayerHistoryEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlayerHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlayerHistoryEntryCopyWith<PlayerHistoryEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlayerHistoryEntryCopyWith<$Res> {
  factory $PlayerHistoryEntryCopyWith(
    PlayerHistoryEntry value,
    $Res Function(PlayerHistoryEntry) then,
  ) = _$PlayerHistoryEntryCopyWithImpl<$Res, PlayerHistoryEntry>;
  @useResult
  $Res call({
    @_FlexibleStringConverter() String? date,
    @_FlexibleStringConverter() String? text,
    @_FlexibleIntConverter() int? type,
  });
}

/// @nodoc
class _$PlayerHistoryEntryCopyWithImpl<$Res, $Val extends PlayerHistoryEntry>
    implements $PlayerHistoryEntryCopyWith<$Res> {
  _$PlayerHistoryEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlayerHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = freezed,
    Object? text = freezed,
    Object? type = freezed,
  }) {
    return _then(
      _value.copyWith(
            date:
                freezed == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as String?,
            text:
                freezed == text
                    ? _value.text
                    : text // ignore: cast_nullable_to_non_nullable
                        as String?,
            type:
                freezed == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlayerHistoryEntryImplCopyWith<$Res>
    implements $PlayerHistoryEntryCopyWith<$Res> {
  factory _$$PlayerHistoryEntryImplCopyWith(
    _$PlayerHistoryEntryImpl value,
    $Res Function(_$PlayerHistoryEntryImpl) then,
  ) = __$$PlayerHistoryEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @_FlexibleStringConverter() String? date,
    @_FlexibleStringConverter() String? text,
    @_FlexibleIntConverter() int? type,
  });
}

/// @nodoc
class __$$PlayerHistoryEntryImplCopyWithImpl<$Res>
    extends _$PlayerHistoryEntryCopyWithImpl<$Res, _$PlayerHistoryEntryImpl>
    implements _$$PlayerHistoryEntryImplCopyWith<$Res> {
  __$$PlayerHistoryEntryImplCopyWithImpl(
    _$PlayerHistoryEntryImpl _value,
    $Res Function(_$PlayerHistoryEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlayerHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = freezed,
    Object? text = freezed,
    Object? type = freezed,
  }) {
    return _then(
      _$PlayerHistoryEntryImpl(
        date:
            freezed == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as String?,
        text:
            freezed == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                    as String?,
        type:
            freezed == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PlayerHistoryEntryImpl implements _PlayerHistoryEntry {
  const _$PlayerHistoryEntryImpl({
    @_FlexibleStringConverter() required this.date,
    @_FlexibleStringConverter() required this.text,
    @_FlexibleIntConverter() required this.type,
  });

  factory _$PlayerHistoryEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlayerHistoryEntryImplFromJson(json);

  @override
  @_FlexibleStringConverter()
  final String? date;
  @override
  @_FlexibleStringConverter()
  final String? text;
  @override
  @_FlexibleIntConverter()
  final int? type;

  @override
  String toString() {
    return 'PlayerHistoryEntry(date: $date, text: $text, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlayerHistoryEntryImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, text, type);

  /// Create a copy of PlayerHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlayerHistoryEntryImplCopyWith<_$PlayerHistoryEntryImpl> get copyWith =>
      __$$PlayerHistoryEntryImplCopyWithImpl<_$PlayerHistoryEntryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PlayerHistoryEntryImplToJson(this);
  }
}

abstract class _PlayerHistoryEntry implements PlayerHistoryEntry {
  const factory _PlayerHistoryEntry({
    @_FlexibleStringConverter() required final String? date,
    @_FlexibleStringConverter() required final String? text,
    @_FlexibleIntConverter() required final int? type,
  }) = _$PlayerHistoryEntryImpl;

  factory _PlayerHistoryEntry.fromJson(Map<String, dynamic> json) =
      _$PlayerHistoryEntryImpl.fromJson;

  @override
  @_FlexibleStringConverter()
  String? get date;
  @override
  @_FlexibleStringConverter()
  String? get text;
  @override
  @_FlexibleIntConverter()
  int? get type;

  /// Create a copy of PlayerHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlayerHistoryEntryImplCopyWith<_$PlayerHistoryEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
