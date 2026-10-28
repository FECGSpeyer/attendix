// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Attendance _$AttendanceFromJson(Map<String, dynamic> json) {
  return _Attendance.fromJson(json);
}

/// @nodoc
mixin _$Attendance {
  @_FlexibleIntConverter()
  int? get id => throw _privateConstructorUsedError;
  @_FlexibleIntConverter()
  int? get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by')
  @_FlexibleStringConverter()
  String? get createdBy => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'type_id')
  @_FlexibleStringConverter()
  String? get typeId => throw _privateConstructorUsedError;
  @JsonKey(name: 'save_in_history')
  @_FlexibleBoolConverter()
  bool get saveInHistory => throw _privateConstructorUsedError;
  double? get percentage => throw _privateConstructorUsedError;
  @_FlexibleStringListConverter()
  List<String>? get excused => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get typeInfo => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get notes => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get img => throw _privateConstructorUsedError;
  Map<String, dynamic>? get plan => throw _privateConstructorUsedError;
  @_FlexibleStringListConverter()
  List<String>? get lateExcused => throw _privateConstructorUsedError;
  @_FlexibleIntListConverter()
  List<int>? get songs => throw _privateConstructorUsedError;
  @_FlexibleIntListConverter()
  List<int>? get criticalPlayers => throw _privateConstructorUsedError;
  Map<String, dynamic>? get playerNotes => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_time')
  @_FlexibleStringConverter()
  String? get startTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_time')
  @_FlexibleStringConverter()
  String? get endTime => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get deadline => throw _privateConstructorUsedError;
  @JsonKey(name: 'duration_days')
  @_FlexibleIntConverter()
  int? get durationDays => throw _privateConstructorUsedError;
  List<ChecklistItem>? get checklist =>
      throw _privateConstructorUsedError; // Fields from Ionic that were missing
  @_FlexibleIntListConverter()
  List<int>? get conductors => throw _privateConstructorUsedError;
  Map<String, dynamic>? get players => throw _privateConstructorUsedError;
  @JsonKey(name: 'share_plan')
  @_FlexibleBoolConverter()
  bool get sharePlan => throw _privateConstructorUsedError; // ATTENDANCE_SIGNOUT: place, files folder, description & attachment
  @_FlexibleStringConverter()
  String? get place => throw _privateConstructorUsedError;
  @JsonKey(name: 'files_folder')
  @_FlexibleStringConverter()
  String? get filesFolder => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'attachment_url')
  @_FlexibleStringConverter()
  String? get attachmentUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'attachment_name')
  @_FlexibleStringConverter()
  String? get attachmentName => throw _privateConstructorUsedError;

  /// Serializes this Attendance to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Attendance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttendanceCopyWith<Attendance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceCopyWith<$Res> {
  factory $AttendanceCopyWith(
    Attendance value,
    $Res Function(Attendance) then,
  ) = _$AttendanceCopyWithImpl<$Res, Attendance>;
  @useResult
  $Res call({
    @_FlexibleIntConverter() int? id,
    @_FlexibleIntConverter() int? tenantId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'created_by') @_FlexibleStringConverter() String? createdBy,
    String date,
    @_FlexibleStringConverter() String? type,
    @JsonKey(name: 'type_id') @_FlexibleStringConverter() String? typeId,
    @JsonKey(name: 'save_in_history')
    @_FlexibleBoolConverter()
    bool saveInHistory,
    double? percentage,
    @_FlexibleStringListConverter() List<String>? excused,
    @_FlexibleStringConverter() String? typeInfo,
    @_FlexibleStringConverter() String? notes,
    @_FlexibleStringConverter() String? img,
    Map<String, dynamic>? plan,
    @_FlexibleStringListConverter() List<String>? lateExcused,
    @_FlexibleIntListConverter() List<int>? songs,
    @_FlexibleIntListConverter() List<int>? criticalPlayers,
    Map<String, dynamic>? playerNotes,
    @JsonKey(name: 'start_time') @_FlexibleStringConverter() String? startTime,
    @JsonKey(name: 'end_time') @_FlexibleStringConverter() String? endTime,
    @_FlexibleStringConverter() String? deadline,
    @JsonKey(name: 'duration_days') @_FlexibleIntConverter() int? durationDays,
    List<ChecklistItem>? checklist,
    @_FlexibleIntListConverter() List<int>? conductors,
    Map<String, dynamic>? players,
    @JsonKey(name: 'share_plan') @_FlexibleBoolConverter() bool sharePlan,
    @_FlexibleStringConverter() String? place,
    @JsonKey(name: 'files_folder')
    @_FlexibleStringConverter()
    String? filesFolder,
    @_FlexibleStringConverter() String? description,
    @JsonKey(name: 'attachment_url')
    @_FlexibleStringConverter()
    String? attachmentUrl,
    @JsonKey(name: 'attachment_name')
    @_FlexibleStringConverter()
    String? attachmentName,
  });
}

/// @nodoc
class _$AttendanceCopyWithImpl<$Res, $Val extends Attendance>
    implements $AttendanceCopyWith<$Res> {
  _$AttendanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Attendance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? createdAt = freezed,
    Object? createdBy = freezed,
    Object? date = null,
    Object? type = freezed,
    Object? typeId = freezed,
    Object? saveInHistory = null,
    Object? percentage = freezed,
    Object? excused = freezed,
    Object? typeInfo = freezed,
    Object? notes = freezed,
    Object? img = freezed,
    Object? plan = freezed,
    Object? lateExcused = freezed,
    Object? songs = freezed,
    Object? criticalPlayers = freezed,
    Object? playerNotes = freezed,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? deadline = freezed,
    Object? durationDays = freezed,
    Object? checklist = freezed,
    Object? conductors = freezed,
    Object? players = freezed,
    Object? sharePlan = null,
    Object? place = freezed,
    Object? filesFolder = freezed,
    Object? description = freezed,
    Object? attachmentUrl = freezed,
    Object? attachmentName = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as int?,
            tenantId:
                freezed == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int?,
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
            date:
                null == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as String,
            type:
                freezed == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String?,
            typeId:
                freezed == typeId
                    ? _value.typeId
                    : typeId // ignore: cast_nullable_to_non_nullable
                        as String?,
            saveInHistory:
                null == saveInHistory
                    ? _value.saveInHistory
                    : saveInHistory // ignore: cast_nullable_to_non_nullable
                        as bool,
            percentage:
                freezed == percentage
                    ? _value.percentage
                    : percentage // ignore: cast_nullable_to_non_nullable
                        as double?,
            excused:
                freezed == excused
                    ? _value.excused
                    : excused // ignore: cast_nullable_to_non_nullable
                        as List<String>?,
            typeInfo:
                freezed == typeInfo
                    ? _value.typeInfo
                    : typeInfo // ignore: cast_nullable_to_non_nullable
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
            plan:
                freezed == plan
                    ? _value.plan
                    : plan // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
            lateExcused:
                freezed == lateExcused
                    ? _value.lateExcused
                    : lateExcused // ignore: cast_nullable_to_non_nullable
                        as List<String>?,
            songs:
                freezed == songs
                    ? _value.songs
                    : songs // ignore: cast_nullable_to_non_nullable
                        as List<int>?,
            criticalPlayers:
                freezed == criticalPlayers
                    ? _value.criticalPlayers
                    : criticalPlayers // ignore: cast_nullable_to_non_nullable
                        as List<int>?,
            playerNotes:
                freezed == playerNotes
                    ? _value.playerNotes
                    : playerNotes // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
            startTime:
                freezed == startTime
                    ? _value.startTime
                    : startTime // ignore: cast_nullable_to_non_nullable
                        as String?,
            endTime:
                freezed == endTime
                    ? _value.endTime
                    : endTime // ignore: cast_nullable_to_non_nullable
                        as String?,
            deadline:
                freezed == deadline
                    ? _value.deadline
                    : deadline // ignore: cast_nullable_to_non_nullable
                        as String?,
            durationDays:
                freezed == durationDays
                    ? _value.durationDays
                    : durationDays // ignore: cast_nullable_to_non_nullable
                        as int?,
            checklist:
                freezed == checklist
                    ? _value.checklist
                    : checklist // ignore: cast_nullable_to_non_nullable
                        as List<ChecklistItem>?,
            conductors:
                freezed == conductors
                    ? _value.conductors
                    : conductors // ignore: cast_nullable_to_non_nullable
                        as List<int>?,
            players:
                freezed == players
                    ? _value.players
                    : players // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
            sharePlan:
                null == sharePlan
                    ? _value.sharePlan
                    : sharePlan // ignore: cast_nullable_to_non_nullable
                        as bool,
            place:
                freezed == place
                    ? _value.place
                    : place // ignore: cast_nullable_to_non_nullable
                        as String?,
            filesFolder:
                freezed == filesFolder
                    ? _value.filesFolder
                    : filesFolder // ignore: cast_nullable_to_non_nullable
                        as String?,
            description:
                freezed == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String?,
            attachmentUrl:
                freezed == attachmentUrl
                    ? _value.attachmentUrl
                    : attachmentUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            attachmentName:
                freezed == attachmentName
                    ? _value.attachmentName
                    : attachmentName // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AttendanceImplCopyWith<$Res>
    implements $AttendanceCopyWith<$Res> {
  factory _$$AttendanceImplCopyWith(
    _$AttendanceImpl value,
    $Res Function(_$AttendanceImpl) then,
  ) = __$$AttendanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @_FlexibleIntConverter() int? id,
    @_FlexibleIntConverter() int? tenantId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'created_by') @_FlexibleStringConverter() String? createdBy,
    String date,
    @_FlexibleStringConverter() String? type,
    @JsonKey(name: 'type_id') @_FlexibleStringConverter() String? typeId,
    @JsonKey(name: 'save_in_history')
    @_FlexibleBoolConverter()
    bool saveInHistory,
    double? percentage,
    @_FlexibleStringListConverter() List<String>? excused,
    @_FlexibleStringConverter() String? typeInfo,
    @_FlexibleStringConverter() String? notes,
    @_FlexibleStringConverter() String? img,
    Map<String, dynamic>? plan,
    @_FlexibleStringListConverter() List<String>? lateExcused,
    @_FlexibleIntListConverter() List<int>? songs,
    @_FlexibleIntListConverter() List<int>? criticalPlayers,
    Map<String, dynamic>? playerNotes,
    @JsonKey(name: 'start_time') @_FlexibleStringConverter() String? startTime,
    @JsonKey(name: 'end_time') @_FlexibleStringConverter() String? endTime,
    @_FlexibleStringConverter() String? deadline,
    @JsonKey(name: 'duration_days') @_FlexibleIntConverter() int? durationDays,
    List<ChecklistItem>? checklist,
    @_FlexibleIntListConverter() List<int>? conductors,
    Map<String, dynamic>? players,
    @JsonKey(name: 'share_plan') @_FlexibleBoolConverter() bool sharePlan,
    @_FlexibleStringConverter() String? place,
    @JsonKey(name: 'files_folder')
    @_FlexibleStringConverter()
    String? filesFolder,
    @_FlexibleStringConverter() String? description,
    @JsonKey(name: 'attachment_url')
    @_FlexibleStringConverter()
    String? attachmentUrl,
    @JsonKey(name: 'attachment_name')
    @_FlexibleStringConverter()
    String? attachmentName,
  });
}

/// @nodoc
class __$$AttendanceImplCopyWithImpl<$Res>
    extends _$AttendanceCopyWithImpl<$Res, _$AttendanceImpl>
    implements _$$AttendanceImplCopyWith<$Res> {
  __$$AttendanceImplCopyWithImpl(
    _$AttendanceImpl _value,
    $Res Function(_$AttendanceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Attendance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? createdAt = freezed,
    Object? createdBy = freezed,
    Object? date = null,
    Object? type = freezed,
    Object? typeId = freezed,
    Object? saveInHistory = null,
    Object? percentage = freezed,
    Object? excused = freezed,
    Object? typeInfo = freezed,
    Object? notes = freezed,
    Object? img = freezed,
    Object? plan = freezed,
    Object? lateExcused = freezed,
    Object? songs = freezed,
    Object? criticalPlayers = freezed,
    Object? playerNotes = freezed,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? deadline = freezed,
    Object? durationDays = freezed,
    Object? checklist = freezed,
    Object? conductors = freezed,
    Object? players = freezed,
    Object? sharePlan = null,
    Object? place = freezed,
    Object? filesFolder = freezed,
    Object? description = freezed,
    Object? attachmentUrl = freezed,
    Object? attachmentName = freezed,
  }) {
    return _then(
      _$AttendanceImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as int?,
        tenantId:
            freezed == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int?,
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
        date:
            null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as String,
        type:
            freezed == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String?,
        typeId:
            freezed == typeId
                ? _value.typeId
                : typeId // ignore: cast_nullable_to_non_nullable
                    as String?,
        saveInHistory:
            null == saveInHistory
                ? _value.saveInHistory
                : saveInHistory // ignore: cast_nullable_to_non_nullable
                    as bool,
        percentage:
            freezed == percentage
                ? _value.percentage
                : percentage // ignore: cast_nullable_to_non_nullable
                    as double?,
        excused:
            freezed == excused
                ? _value._excused
                : excused // ignore: cast_nullable_to_non_nullable
                    as List<String>?,
        typeInfo:
            freezed == typeInfo
                ? _value.typeInfo
                : typeInfo // ignore: cast_nullable_to_non_nullable
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
        plan:
            freezed == plan
                ? _value._plan
                : plan // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
        lateExcused:
            freezed == lateExcused
                ? _value._lateExcused
                : lateExcused // ignore: cast_nullable_to_non_nullable
                    as List<String>?,
        songs:
            freezed == songs
                ? _value._songs
                : songs // ignore: cast_nullable_to_non_nullable
                    as List<int>?,
        criticalPlayers:
            freezed == criticalPlayers
                ? _value._criticalPlayers
                : criticalPlayers // ignore: cast_nullable_to_non_nullable
                    as List<int>?,
        playerNotes:
            freezed == playerNotes
                ? _value._playerNotes
                : playerNotes // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
        startTime:
            freezed == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                    as String?,
        endTime:
            freezed == endTime
                ? _value.endTime
                : endTime // ignore: cast_nullable_to_non_nullable
                    as String?,
        deadline:
            freezed == deadline
                ? _value.deadline
                : deadline // ignore: cast_nullable_to_non_nullable
                    as String?,
        durationDays:
            freezed == durationDays
                ? _value.durationDays
                : durationDays // ignore: cast_nullable_to_non_nullable
                    as int?,
        checklist:
            freezed == checklist
                ? _value._checklist
                : checklist // ignore: cast_nullable_to_non_nullable
                    as List<ChecklistItem>?,
        conductors:
            freezed == conductors
                ? _value._conductors
                : conductors // ignore: cast_nullable_to_non_nullable
                    as List<int>?,
        players:
            freezed == players
                ? _value._players
                : players // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
        sharePlan:
            null == sharePlan
                ? _value.sharePlan
                : sharePlan // ignore: cast_nullable_to_non_nullable
                    as bool,
        place:
            freezed == place
                ? _value.place
                : place // ignore: cast_nullable_to_non_nullable
                    as String?,
        filesFolder:
            freezed == filesFolder
                ? _value.filesFolder
                : filesFolder // ignore: cast_nullable_to_non_nullable
                    as String?,
        description:
            freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String?,
        attachmentUrl:
            freezed == attachmentUrl
                ? _value.attachmentUrl
                : attachmentUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        attachmentName:
            freezed == attachmentName
                ? _value.attachmentName
                : attachmentName // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AttendanceImpl implements _Attendance {
  const _$AttendanceImpl({
    @_FlexibleIntConverter() this.id,
    @_FlexibleIntConverter() this.tenantId,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'created_by') @_FlexibleStringConverter() this.createdBy,
    required this.date,
    @_FlexibleStringConverter() this.type,
    @JsonKey(name: 'type_id') @_FlexibleStringConverter() this.typeId,
    @JsonKey(name: 'save_in_history')
    @_FlexibleBoolConverter()
    this.saveInHistory = false,
    this.percentage,
    @_FlexibleStringListConverter() final List<String>? excused,
    @_FlexibleStringConverter() this.typeInfo,
    @_FlexibleStringConverter() this.notes,
    @_FlexibleStringConverter() this.img,
    final Map<String, dynamic>? plan,
    @_FlexibleStringListConverter() final List<String>? lateExcused,
    @_FlexibleIntListConverter() final List<int>? songs,
    @_FlexibleIntListConverter() final List<int>? criticalPlayers,
    final Map<String, dynamic>? playerNotes,
    @JsonKey(name: 'start_time') @_FlexibleStringConverter() this.startTime,
    @JsonKey(name: 'end_time') @_FlexibleStringConverter() this.endTime,
    @_FlexibleStringConverter() this.deadline,
    @JsonKey(name: 'duration_days') @_FlexibleIntConverter() this.durationDays,
    final List<ChecklistItem>? checklist,
    @_FlexibleIntListConverter() final List<int>? conductors,
    final Map<String, dynamic>? players,
    @JsonKey(name: 'share_plan')
    @_FlexibleBoolConverter()
    this.sharePlan = false,
    @_FlexibleStringConverter() this.place,
    @JsonKey(name: 'files_folder') @_FlexibleStringConverter() this.filesFolder,
    @_FlexibleStringConverter() this.description,
    @JsonKey(name: 'attachment_url')
    @_FlexibleStringConverter()
    this.attachmentUrl,
    @JsonKey(name: 'attachment_name')
    @_FlexibleStringConverter()
    this.attachmentName,
  }) : _excused = excused,
       _plan = plan,
       _lateExcused = lateExcused,
       _songs = songs,
       _criticalPlayers = criticalPlayers,
       _playerNotes = playerNotes,
       _checklist = checklist,
       _conductors = conductors,
       _players = players;

  factory _$AttendanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttendanceImplFromJson(json);

  @override
  @_FlexibleIntConverter()
  final int? id;
  @override
  @_FlexibleIntConverter()
  final int? tenantId;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'created_by')
  @_FlexibleStringConverter()
  final String? createdBy;
  @override
  final String date;
  @override
  @_FlexibleStringConverter()
  final String? type;
  @override
  @JsonKey(name: 'type_id')
  @_FlexibleStringConverter()
  final String? typeId;
  @override
  @JsonKey(name: 'save_in_history')
  @_FlexibleBoolConverter()
  final bool saveInHistory;
  @override
  final double? percentage;
  final List<String>? _excused;
  @override
  @_FlexibleStringListConverter()
  List<String>? get excused {
    final value = _excused;
    if (value == null) return null;
    if (_excused is EqualUnmodifiableListView) return _excused;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @_FlexibleStringConverter()
  final String? typeInfo;
  @override
  @_FlexibleStringConverter()
  final String? notes;
  @override
  @_FlexibleStringConverter()
  final String? img;
  final Map<String, dynamic>? _plan;
  @override
  Map<String, dynamic>? get plan {
    final value = _plan;
    if (value == null) return null;
    if (_plan is EqualUnmodifiableMapView) return _plan;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final List<String>? _lateExcused;
  @override
  @_FlexibleStringListConverter()
  List<String>? get lateExcused {
    final value = _lateExcused;
    if (value == null) return null;
    if (_lateExcused is EqualUnmodifiableListView) return _lateExcused;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<int>? _songs;
  @override
  @_FlexibleIntListConverter()
  List<int>? get songs {
    final value = _songs;
    if (value == null) return null;
    if (_songs is EqualUnmodifiableListView) return _songs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<int>? _criticalPlayers;
  @override
  @_FlexibleIntListConverter()
  List<int>? get criticalPlayers {
    final value = _criticalPlayers;
    if (value == null) return null;
    if (_criticalPlayers is EqualUnmodifiableListView) return _criticalPlayers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final Map<String, dynamic>? _playerNotes;
  @override
  Map<String, dynamic>? get playerNotes {
    final value = _playerNotes;
    if (value == null) return null;
    if (_playerNotes is EqualUnmodifiableMapView) return _playerNotes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'start_time')
  @_FlexibleStringConverter()
  final String? startTime;
  @override
  @JsonKey(name: 'end_time')
  @_FlexibleStringConverter()
  final String? endTime;
  @override
  @_FlexibleStringConverter()
  final String? deadline;
  @override
  @JsonKey(name: 'duration_days')
  @_FlexibleIntConverter()
  final int? durationDays;
  final List<ChecklistItem>? _checklist;
  @override
  List<ChecklistItem>? get checklist {
    final value = _checklist;
    if (value == null) return null;
    if (_checklist is EqualUnmodifiableListView) return _checklist;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  // Fields from Ionic that were missing
  final List<int>? _conductors;
  // Fields from Ionic that were missing
  @override
  @_FlexibleIntListConverter()
  List<int>? get conductors {
    final value = _conductors;
    if (value == null) return null;
    if (_conductors is EqualUnmodifiableListView) return _conductors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final Map<String, dynamic>? _players;
  @override
  Map<String, dynamic>? get players {
    final value = _players;
    if (value == null) return null;
    if (_players is EqualUnmodifiableMapView) return _players;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'share_plan')
  @_FlexibleBoolConverter()
  final bool sharePlan;
  // ATTENDANCE_SIGNOUT: place, files folder, description & attachment
  @override
  @_FlexibleStringConverter()
  final String? place;
  @override
  @JsonKey(name: 'files_folder')
  @_FlexibleStringConverter()
  final String? filesFolder;
  @override
  @_FlexibleStringConverter()
  final String? description;
  @override
  @JsonKey(name: 'attachment_url')
  @_FlexibleStringConverter()
  final String? attachmentUrl;
  @override
  @JsonKey(name: 'attachment_name')
  @_FlexibleStringConverter()
  final String? attachmentName;

  @override
  String toString() {
    return 'Attendance(id: $id, tenantId: $tenantId, createdAt: $createdAt, createdBy: $createdBy, date: $date, type: $type, typeId: $typeId, saveInHistory: $saveInHistory, percentage: $percentage, excused: $excused, typeInfo: $typeInfo, notes: $notes, img: $img, plan: $plan, lateExcused: $lateExcused, songs: $songs, criticalPlayers: $criticalPlayers, playerNotes: $playerNotes, startTime: $startTime, endTime: $endTime, deadline: $deadline, durationDays: $durationDays, checklist: $checklist, conductors: $conductors, players: $players, sharePlan: $sharePlan, place: $place, filesFolder: $filesFolder, description: $description, attachmentUrl: $attachmentUrl, attachmentName: $attachmentName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.typeId, typeId) || other.typeId == typeId) &&
            (identical(other.saveInHistory, saveInHistory) ||
                other.saveInHistory == saveInHistory) &&
            (identical(other.percentage, percentage) ||
                other.percentage == percentage) &&
            const DeepCollectionEquality().equals(other._excused, _excused) &&
            (identical(other.typeInfo, typeInfo) ||
                other.typeInfo == typeInfo) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.img, img) || other.img == img) &&
            const DeepCollectionEquality().equals(other._plan, _plan) &&
            const DeepCollectionEquality().equals(
              other._lateExcused,
              _lateExcused,
            ) &&
            const DeepCollectionEquality().equals(other._songs, _songs) &&
            const DeepCollectionEquality().equals(
              other._criticalPlayers,
              _criticalPlayers,
            ) &&
            const DeepCollectionEquality().equals(
              other._playerNotes,
              _playerNotes,
            ) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.deadline, deadline) ||
                other.deadline == deadline) &&
            (identical(other.durationDays, durationDays) ||
                other.durationDays == durationDays) &&
            const DeepCollectionEquality().equals(
              other._checklist,
              _checklist,
            ) &&
            const DeepCollectionEquality().equals(
              other._conductors,
              _conductors,
            ) &&
            const DeepCollectionEquality().equals(other._players, _players) &&
            (identical(other.sharePlan, sharePlan) ||
                other.sharePlan == sharePlan) &&
            (identical(other.place, place) || other.place == place) &&
            (identical(other.filesFolder, filesFolder) ||
                other.filesFolder == filesFolder) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.attachmentUrl, attachmentUrl) ||
                other.attachmentUrl == attachmentUrl) &&
            (identical(other.attachmentName, attachmentName) ||
                other.attachmentName == attachmentName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    tenantId,
    createdAt,
    createdBy,
    date,
    type,
    typeId,
    saveInHistory,
    percentage,
    const DeepCollectionEquality().hash(_excused),
    typeInfo,
    notes,
    img,
    const DeepCollectionEquality().hash(_plan),
    const DeepCollectionEquality().hash(_lateExcused),
    const DeepCollectionEquality().hash(_songs),
    const DeepCollectionEquality().hash(_criticalPlayers),
    const DeepCollectionEquality().hash(_playerNotes),
    startTime,
    endTime,
    deadline,
    durationDays,
    const DeepCollectionEquality().hash(_checklist),
    const DeepCollectionEquality().hash(_conductors),
    const DeepCollectionEquality().hash(_players),
    sharePlan,
    place,
    filesFolder,
    description,
    attachmentUrl,
    attachmentName,
  ]);

  /// Create a copy of Attendance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendanceImplCopyWith<_$AttendanceImpl> get copyWith =>
      __$$AttendanceImplCopyWithImpl<_$AttendanceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttendanceImplToJson(this);
  }
}

abstract class _Attendance implements Attendance {
  const factory _Attendance({
    @_FlexibleIntConverter() final int? id,
    @_FlexibleIntConverter() final int? tenantId,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'created_by')
    @_FlexibleStringConverter()
    final String? createdBy,
    required final String date,
    @_FlexibleStringConverter() final String? type,
    @JsonKey(name: 'type_id') @_FlexibleStringConverter() final String? typeId,
    @JsonKey(name: 'save_in_history')
    @_FlexibleBoolConverter()
    final bool saveInHistory,
    final double? percentage,
    @_FlexibleStringListConverter() final List<String>? excused,
    @_FlexibleStringConverter() final String? typeInfo,
    @_FlexibleStringConverter() final String? notes,
    @_FlexibleStringConverter() final String? img,
    final Map<String, dynamic>? plan,
    @_FlexibleStringListConverter() final List<String>? lateExcused,
    @_FlexibleIntListConverter() final List<int>? songs,
    @_FlexibleIntListConverter() final List<int>? criticalPlayers,
    final Map<String, dynamic>? playerNotes,
    @JsonKey(name: 'start_time')
    @_FlexibleStringConverter()
    final String? startTime,
    @JsonKey(name: 'end_time')
    @_FlexibleStringConverter()
    final String? endTime,
    @_FlexibleStringConverter() final String? deadline,
    @JsonKey(name: 'duration_days')
    @_FlexibleIntConverter()
    final int? durationDays,
    final List<ChecklistItem>? checklist,
    @_FlexibleIntListConverter() final List<int>? conductors,
    final Map<String, dynamic>? players,
    @JsonKey(name: 'share_plan') @_FlexibleBoolConverter() final bool sharePlan,
    @_FlexibleStringConverter() final String? place,
    @JsonKey(name: 'files_folder')
    @_FlexibleStringConverter()
    final String? filesFolder,
    @_FlexibleStringConverter() final String? description,
    @JsonKey(name: 'attachment_url')
    @_FlexibleStringConverter()
    final String? attachmentUrl,
    @JsonKey(name: 'attachment_name')
    @_FlexibleStringConverter()
    final String? attachmentName,
  }) = _$AttendanceImpl;

  factory _Attendance.fromJson(Map<String, dynamic> json) =
      _$AttendanceImpl.fromJson;

  @override
  @_FlexibleIntConverter()
  int? get id;
  @override
  @_FlexibleIntConverter()
  int? get tenantId;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'created_by')
  @_FlexibleStringConverter()
  String? get createdBy;
  @override
  String get date;
  @override
  @_FlexibleStringConverter()
  String? get type;
  @override
  @JsonKey(name: 'type_id')
  @_FlexibleStringConverter()
  String? get typeId;
  @override
  @JsonKey(name: 'save_in_history')
  @_FlexibleBoolConverter()
  bool get saveInHistory;
  @override
  double? get percentage;
  @override
  @_FlexibleStringListConverter()
  List<String>? get excused;
  @override
  @_FlexibleStringConverter()
  String? get typeInfo;
  @override
  @_FlexibleStringConverter()
  String? get notes;
  @override
  @_FlexibleStringConverter()
  String? get img;
  @override
  Map<String, dynamic>? get plan;
  @override
  @_FlexibleStringListConverter()
  List<String>? get lateExcused;
  @override
  @_FlexibleIntListConverter()
  List<int>? get songs;
  @override
  @_FlexibleIntListConverter()
  List<int>? get criticalPlayers;
  @override
  Map<String, dynamic>? get playerNotes;
  @override
  @JsonKey(name: 'start_time')
  @_FlexibleStringConverter()
  String? get startTime;
  @override
  @JsonKey(name: 'end_time')
  @_FlexibleStringConverter()
  String? get endTime;
  @override
  @_FlexibleStringConverter()
  String? get deadline;
  @override
  @JsonKey(name: 'duration_days')
  @_FlexibleIntConverter()
  int? get durationDays;
  @override
  List<ChecklistItem>? get checklist; // Fields from Ionic that were missing
  @override
  @_FlexibleIntListConverter()
  List<int>? get conductors;
  @override
  Map<String, dynamic>? get players;
  @override
  @JsonKey(name: 'share_plan')
  @_FlexibleBoolConverter()
  bool get sharePlan; // ATTENDANCE_SIGNOUT: place, files folder, description & attachment
  @override
  @_FlexibleStringConverter()
  String? get place;
  @override
  @JsonKey(name: 'files_folder')
  @_FlexibleStringConverter()
  String? get filesFolder;
  @override
  @_FlexibleStringConverter()
  String? get description;
  @override
  @JsonKey(name: 'attachment_url')
  @_FlexibleStringConverter()
  String? get attachmentUrl;
  @override
  @JsonKey(name: 'attachment_name')
  @_FlexibleStringConverter()
  String? get attachmentName;

  /// Create a copy of Attendance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendanceImplCopyWith<_$AttendanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PersonAttendance _$PersonAttendanceFromJson(Map<String, dynamic> json) {
  return _PersonAttendance.fromJson(json);
}

/// @nodoc
mixin _$PersonAttendance {
  @_FlexibleStringConverter()
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_id')
  @_FlexibleIntConverter()
  int? get attendanceId => throw _privateConstructorUsedError;
  @JsonKey(name: 'person_id')
  @_FlexibleIntConverter()
  int? get personId => throw _privateConstructorUsedError;
  @_FlexibleAttendanceStatusConverter()
  AttendanceStatus get status => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get notes => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get firstName => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get lastName => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get img => throw _privateConstructorUsedError;
  @_FlexibleIntConverter()
  int? get instrument => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get groupName => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get joined => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get date => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get text => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get title => throw _privateConstructorUsedError;
  @JsonKey(name: 'changed_by')
  @_FlexibleStringConverter()
  String? get changedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'changed_at')
  @_FlexibleStringConverter()
  String? get changedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'type_id')
  @_FlexibleStringConverter()
  String? get typeId => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get highlight => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get left => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get paused => throw _privateConstructorUsedError; // ATTENDANCE_SIGNOUT: answers to the attendance type's registration fields
  @JsonKey(name: 'registration_answers')
  Map<String, dynamic>? get registrationAnswers =>
      throw _privateConstructorUsedError;

  /// Serializes this PersonAttendance to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PersonAttendance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PersonAttendanceCopyWith<PersonAttendance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PersonAttendanceCopyWith<$Res> {
  factory $PersonAttendanceCopyWith(
    PersonAttendance value,
    $Res Function(PersonAttendance) then,
  ) = _$PersonAttendanceCopyWithImpl<$Res, PersonAttendance>;
  @useResult
  $Res call({
    @_FlexibleStringConverter() String? id,
    @JsonKey(name: 'attendance_id') @_FlexibleIntConverter() int? attendanceId,
    @JsonKey(name: 'person_id') @_FlexibleIntConverter() int? personId,
    @_FlexibleAttendanceStatusConverter() AttendanceStatus status,
    @_FlexibleStringConverter() String? notes,
    @_FlexibleStringConverter() String? firstName,
    @_FlexibleStringConverter() String? lastName,
    @_FlexibleStringConverter() String? img,
    @_FlexibleIntConverter() int? instrument,
    @_FlexibleStringConverter() String? groupName,
    @_FlexibleStringConverter() String? joined,
    @_FlexibleStringConverter() String? date,
    @_FlexibleStringConverter() String? text,
    @_FlexibleStringConverter() String? title,
    @JsonKey(name: 'changed_by') @_FlexibleStringConverter() String? changedBy,
    @JsonKey(name: 'changed_at') @_FlexibleStringConverter() String? changedAt,
    @JsonKey(name: 'type_id') @_FlexibleStringConverter() String? typeId,
    @_FlexibleBoolConverter() bool highlight,
    @_FlexibleStringConverter() String? left,
    @_FlexibleBoolConverter() bool paused,
    @JsonKey(name: 'registration_answers')
    Map<String, dynamic>? registrationAnswers,
  });
}

/// @nodoc
class _$PersonAttendanceCopyWithImpl<$Res, $Val extends PersonAttendance>
    implements $PersonAttendanceCopyWith<$Res> {
  _$PersonAttendanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PersonAttendance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? attendanceId = freezed,
    Object? personId = freezed,
    Object? status = null,
    Object? notes = freezed,
    Object? firstName = freezed,
    Object? lastName = freezed,
    Object? img = freezed,
    Object? instrument = freezed,
    Object? groupName = freezed,
    Object? joined = freezed,
    Object? date = freezed,
    Object? text = freezed,
    Object? title = freezed,
    Object? changedBy = freezed,
    Object? changedAt = freezed,
    Object? typeId = freezed,
    Object? highlight = null,
    Object? left = freezed,
    Object? paused = null,
    Object? registrationAnswers = freezed,
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
            personId:
                freezed == personId
                    ? _value.personId
                    : personId // ignore: cast_nullable_to_non_nullable
                        as int?,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as AttendanceStatus,
            notes:
                freezed == notes
                    ? _value.notes
                    : notes // ignore: cast_nullable_to_non_nullable
                        as String?,
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
            img:
                freezed == img
                    ? _value.img
                    : img // ignore: cast_nullable_to_non_nullable
                        as String?,
            instrument:
                freezed == instrument
                    ? _value.instrument
                    : instrument // ignore: cast_nullable_to_non_nullable
                        as int?,
            groupName:
                freezed == groupName
                    ? _value.groupName
                    : groupName // ignore: cast_nullable_to_non_nullable
                        as String?,
            joined:
                freezed == joined
                    ? _value.joined
                    : joined // ignore: cast_nullable_to_non_nullable
                        as String?,
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
            title:
                freezed == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String?,
            changedBy:
                freezed == changedBy
                    ? _value.changedBy
                    : changedBy // ignore: cast_nullable_to_non_nullable
                        as String?,
            changedAt:
                freezed == changedAt
                    ? _value.changedAt
                    : changedAt // ignore: cast_nullable_to_non_nullable
                        as String?,
            typeId:
                freezed == typeId
                    ? _value.typeId
                    : typeId // ignore: cast_nullable_to_non_nullable
                        as String?,
            highlight:
                null == highlight
                    ? _value.highlight
                    : highlight // ignore: cast_nullable_to_non_nullable
                        as bool,
            left:
                freezed == left
                    ? _value.left
                    : left // ignore: cast_nullable_to_non_nullable
                        as String?,
            paused:
                null == paused
                    ? _value.paused
                    : paused // ignore: cast_nullable_to_non_nullable
                        as bool,
            registrationAnswers:
                freezed == registrationAnswers
                    ? _value.registrationAnswers
                    : registrationAnswers // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PersonAttendanceImplCopyWith<$Res>
    implements $PersonAttendanceCopyWith<$Res> {
  factory _$$PersonAttendanceImplCopyWith(
    _$PersonAttendanceImpl value,
    $Res Function(_$PersonAttendanceImpl) then,
  ) = __$$PersonAttendanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @_FlexibleStringConverter() String? id,
    @JsonKey(name: 'attendance_id') @_FlexibleIntConverter() int? attendanceId,
    @JsonKey(name: 'person_id') @_FlexibleIntConverter() int? personId,
    @_FlexibleAttendanceStatusConverter() AttendanceStatus status,
    @_FlexibleStringConverter() String? notes,
    @_FlexibleStringConverter() String? firstName,
    @_FlexibleStringConverter() String? lastName,
    @_FlexibleStringConverter() String? img,
    @_FlexibleIntConverter() int? instrument,
    @_FlexibleStringConverter() String? groupName,
    @_FlexibleStringConverter() String? joined,
    @_FlexibleStringConverter() String? date,
    @_FlexibleStringConverter() String? text,
    @_FlexibleStringConverter() String? title,
    @JsonKey(name: 'changed_by') @_FlexibleStringConverter() String? changedBy,
    @JsonKey(name: 'changed_at') @_FlexibleStringConverter() String? changedAt,
    @JsonKey(name: 'type_id') @_FlexibleStringConverter() String? typeId,
    @_FlexibleBoolConverter() bool highlight,
    @_FlexibleStringConverter() String? left,
    @_FlexibleBoolConverter() bool paused,
    @JsonKey(name: 'registration_answers')
    Map<String, dynamic>? registrationAnswers,
  });
}

/// @nodoc
class __$$PersonAttendanceImplCopyWithImpl<$Res>
    extends _$PersonAttendanceCopyWithImpl<$Res, _$PersonAttendanceImpl>
    implements _$$PersonAttendanceImplCopyWith<$Res> {
  __$$PersonAttendanceImplCopyWithImpl(
    _$PersonAttendanceImpl _value,
    $Res Function(_$PersonAttendanceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PersonAttendance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? attendanceId = freezed,
    Object? personId = freezed,
    Object? status = null,
    Object? notes = freezed,
    Object? firstName = freezed,
    Object? lastName = freezed,
    Object? img = freezed,
    Object? instrument = freezed,
    Object? groupName = freezed,
    Object? joined = freezed,
    Object? date = freezed,
    Object? text = freezed,
    Object? title = freezed,
    Object? changedBy = freezed,
    Object? changedAt = freezed,
    Object? typeId = freezed,
    Object? highlight = null,
    Object? left = freezed,
    Object? paused = null,
    Object? registrationAnswers = freezed,
  }) {
    return _then(
      _$PersonAttendanceImpl(
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
        personId:
            freezed == personId
                ? _value.personId
                : personId // ignore: cast_nullable_to_non_nullable
                    as int?,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as AttendanceStatus,
        notes:
            freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                    as String?,
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
        img:
            freezed == img
                ? _value.img
                : img // ignore: cast_nullable_to_non_nullable
                    as String?,
        instrument:
            freezed == instrument
                ? _value.instrument
                : instrument // ignore: cast_nullable_to_non_nullable
                    as int?,
        groupName:
            freezed == groupName
                ? _value.groupName
                : groupName // ignore: cast_nullable_to_non_nullable
                    as String?,
        joined:
            freezed == joined
                ? _value.joined
                : joined // ignore: cast_nullable_to_non_nullable
                    as String?,
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
        title:
            freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String?,
        changedBy:
            freezed == changedBy
                ? _value.changedBy
                : changedBy // ignore: cast_nullable_to_non_nullable
                    as String?,
        changedAt:
            freezed == changedAt
                ? _value.changedAt
                : changedAt // ignore: cast_nullable_to_non_nullable
                    as String?,
        typeId:
            freezed == typeId
                ? _value.typeId
                : typeId // ignore: cast_nullable_to_non_nullable
                    as String?,
        highlight:
            null == highlight
                ? _value.highlight
                : highlight // ignore: cast_nullable_to_non_nullable
                    as bool,
        left:
            freezed == left
                ? _value.left
                : left // ignore: cast_nullable_to_non_nullable
                    as String?,
        paused:
            null == paused
                ? _value.paused
                : paused // ignore: cast_nullable_to_non_nullable
                    as bool,
        registrationAnswers:
            freezed == registrationAnswers
                ? _value._registrationAnswers
                : registrationAnswers // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PersonAttendanceImpl implements _PersonAttendance {
  const _$PersonAttendanceImpl({
    @_FlexibleStringConverter() this.id,
    @JsonKey(name: 'attendance_id') @_FlexibleIntConverter() this.attendanceId,
    @JsonKey(name: 'person_id') @_FlexibleIntConverter() this.personId,
    @_FlexibleAttendanceStatusConverter()
    this.status = AttendanceStatus.neutral,
    @_FlexibleStringConverter() this.notes,
    @_FlexibleStringConverter() this.firstName,
    @_FlexibleStringConverter() this.lastName,
    @_FlexibleStringConverter() this.img,
    @_FlexibleIntConverter() this.instrument,
    @_FlexibleStringConverter() this.groupName,
    @_FlexibleStringConverter() this.joined,
    @_FlexibleStringConverter() this.date,
    @_FlexibleStringConverter() this.text,
    @_FlexibleStringConverter() this.title,
    @JsonKey(name: 'changed_by') @_FlexibleStringConverter() this.changedBy,
    @JsonKey(name: 'changed_at') @_FlexibleStringConverter() this.changedAt,
    @JsonKey(name: 'type_id') @_FlexibleStringConverter() this.typeId,
    @_FlexibleBoolConverter() this.highlight = false,
    @_FlexibleStringConverter() this.left,
    @_FlexibleBoolConverter() this.paused = false,
    @JsonKey(name: 'registration_answers')
    final Map<String, dynamic>? registrationAnswers,
  }) : _registrationAnswers = registrationAnswers;

  factory _$PersonAttendanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$PersonAttendanceImplFromJson(json);

  @override
  @_FlexibleStringConverter()
  final String? id;
  @override
  @JsonKey(name: 'attendance_id')
  @_FlexibleIntConverter()
  final int? attendanceId;
  @override
  @JsonKey(name: 'person_id')
  @_FlexibleIntConverter()
  final int? personId;
  @override
  @JsonKey()
  @_FlexibleAttendanceStatusConverter()
  final AttendanceStatus status;
  @override
  @_FlexibleStringConverter()
  final String? notes;
  @override
  @_FlexibleStringConverter()
  final String? firstName;
  @override
  @_FlexibleStringConverter()
  final String? lastName;
  @override
  @_FlexibleStringConverter()
  final String? img;
  @override
  @_FlexibleIntConverter()
  final int? instrument;
  @override
  @_FlexibleStringConverter()
  final String? groupName;
  @override
  @_FlexibleStringConverter()
  final String? joined;
  @override
  @_FlexibleStringConverter()
  final String? date;
  @override
  @_FlexibleStringConverter()
  final String? text;
  @override
  @_FlexibleStringConverter()
  final String? title;
  @override
  @JsonKey(name: 'changed_by')
  @_FlexibleStringConverter()
  final String? changedBy;
  @override
  @JsonKey(name: 'changed_at')
  @_FlexibleStringConverter()
  final String? changedAt;
  @override
  @JsonKey(name: 'type_id')
  @_FlexibleStringConverter()
  final String? typeId;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool highlight;
  @override
  @_FlexibleStringConverter()
  final String? left;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool paused;
  // ATTENDANCE_SIGNOUT: answers to the attendance type's registration fields
  final Map<String, dynamic>? _registrationAnswers;
  // ATTENDANCE_SIGNOUT: answers to the attendance type's registration fields
  @override
  @JsonKey(name: 'registration_answers')
  Map<String, dynamic>? get registrationAnswers {
    final value = _registrationAnswers;
    if (value == null) return null;
    if (_registrationAnswers is EqualUnmodifiableMapView)
      return _registrationAnswers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'PersonAttendance(id: $id, attendanceId: $attendanceId, personId: $personId, status: $status, notes: $notes, firstName: $firstName, lastName: $lastName, img: $img, instrument: $instrument, groupName: $groupName, joined: $joined, date: $date, text: $text, title: $title, changedBy: $changedBy, changedAt: $changedAt, typeId: $typeId, highlight: $highlight, left: $left, paused: $paused, registrationAnswers: $registrationAnswers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PersonAttendanceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.attendanceId, attendanceId) ||
                other.attendanceId == attendanceId) &&
            (identical(other.personId, personId) ||
                other.personId == personId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.img, img) || other.img == img) &&
            (identical(other.instrument, instrument) ||
                other.instrument == instrument) &&
            (identical(other.groupName, groupName) ||
                other.groupName == groupName) &&
            (identical(other.joined, joined) || other.joined == joined) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.changedBy, changedBy) ||
                other.changedBy == changedBy) &&
            (identical(other.changedAt, changedAt) ||
                other.changedAt == changedAt) &&
            (identical(other.typeId, typeId) || other.typeId == typeId) &&
            (identical(other.highlight, highlight) ||
                other.highlight == highlight) &&
            (identical(other.left, left) || other.left == left) &&
            (identical(other.paused, paused) || other.paused == paused) &&
            const DeepCollectionEquality().equals(
              other._registrationAnswers,
              _registrationAnswers,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    attendanceId,
    personId,
    status,
    notes,
    firstName,
    lastName,
    img,
    instrument,
    groupName,
    joined,
    date,
    text,
    title,
    changedBy,
    changedAt,
    typeId,
    highlight,
    left,
    paused,
    const DeepCollectionEquality().hash(_registrationAnswers),
  ]);

  /// Create a copy of PersonAttendance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PersonAttendanceImplCopyWith<_$PersonAttendanceImpl> get copyWith =>
      __$$PersonAttendanceImplCopyWithImpl<_$PersonAttendanceImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PersonAttendanceImplToJson(this);
  }
}

abstract class _PersonAttendance implements PersonAttendance {
  const factory _PersonAttendance({
    @_FlexibleStringConverter() final String? id,
    @JsonKey(name: 'attendance_id')
    @_FlexibleIntConverter()
    final int? attendanceId,
    @JsonKey(name: 'person_id') @_FlexibleIntConverter() final int? personId,
    @_FlexibleAttendanceStatusConverter() final AttendanceStatus status,
    @_FlexibleStringConverter() final String? notes,
    @_FlexibleStringConverter() final String? firstName,
    @_FlexibleStringConverter() final String? lastName,
    @_FlexibleStringConverter() final String? img,
    @_FlexibleIntConverter() final int? instrument,
    @_FlexibleStringConverter() final String? groupName,
    @_FlexibleStringConverter() final String? joined,
    @_FlexibleStringConverter() final String? date,
    @_FlexibleStringConverter() final String? text,
    @_FlexibleStringConverter() final String? title,
    @JsonKey(name: 'changed_by')
    @_FlexibleStringConverter()
    final String? changedBy,
    @JsonKey(name: 'changed_at')
    @_FlexibleStringConverter()
    final String? changedAt,
    @JsonKey(name: 'type_id') @_FlexibleStringConverter() final String? typeId,
    @_FlexibleBoolConverter() final bool highlight,
    @_FlexibleStringConverter() final String? left,
    @_FlexibleBoolConverter() final bool paused,
    @JsonKey(name: 'registration_answers')
    final Map<String, dynamic>? registrationAnswers,
  }) = _$PersonAttendanceImpl;

  factory _PersonAttendance.fromJson(Map<String, dynamic> json) =
      _$PersonAttendanceImpl.fromJson;

  @override
  @_FlexibleStringConverter()
  String? get id;
  @override
  @JsonKey(name: 'attendance_id')
  @_FlexibleIntConverter()
  int? get attendanceId;
  @override
  @JsonKey(name: 'person_id')
  @_FlexibleIntConverter()
  int? get personId;
  @override
  @_FlexibleAttendanceStatusConverter()
  AttendanceStatus get status;
  @override
  @_FlexibleStringConverter()
  String? get notes;
  @override
  @_FlexibleStringConverter()
  String? get firstName;
  @override
  @_FlexibleStringConverter()
  String? get lastName;
  @override
  @_FlexibleStringConverter()
  String? get img;
  @override
  @_FlexibleIntConverter()
  int? get instrument;
  @override
  @_FlexibleStringConverter()
  String? get groupName;
  @override
  @_FlexibleStringConverter()
  String? get joined;
  @override
  @_FlexibleStringConverter()
  String? get date;
  @override
  @_FlexibleStringConverter()
  String? get text;
  @override
  @_FlexibleStringConverter()
  String? get title;
  @override
  @JsonKey(name: 'changed_by')
  @_FlexibleStringConverter()
  String? get changedBy;
  @override
  @JsonKey(name: 'changed_at')
  @_FlexibleStringConverter()
  String? get changedAt;
  @override
  @JsonKey(name: 'type_id')
  @_FlexibleStringConverter()
  String? get typeId;
  @override
  @_FlexibleBoolConverter()
  bool get highlight;
  @override
  @_FlexibleStringConverter()
  String? get left;
  @override
  @_FlexibleBoolConverter()
  bool get paused; // ATTENDANCE_SIGNOUT: answers to the attendance type's registration fields
  @override
  @JsonKey(name: 'registration_answers')
  Map<String, dynamic>? get registrationAnswers;

  /// Create a copy of PersonAttendance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PersonAttendanceImplCopyWith<_$PersonAttendanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChecklistItem _$ChecklistItemFromJson(Map<String, dynamic> json) {
  return _ChecklistItem.fromJson(json);
}

/// @nodoc
mixin _$ChecklistItem {
  String get id => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  @_FlexibleIntConverter()
  int? get deadlineHours => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get completed => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get dueDate => throw _privateConstructorUsedError;

  /// Serializes this ChecklistItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChecklistItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChecklistItemCopyWith<ChecklistItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChecklistItemCopyWith<$Res> {
  factory $ChecklistItemCopyWith(
    ChecklistItem value,
    $Res Function(ChecklistItem) then,
  ) = _$ChecklistItemCopyWithImpl<$Res, ChecklistItem>;
  @useResult
  $Res call({
    String id,
    String text,
    @_FlexibleIntConverter() int? deadlineHours,
    @_FlexibleBoolConverter() bool completed,
    @_FlexibleStringConverter() String? dueDate,
  });
}

/// @nodoc
class _$ChecklistItemCopyWithImpl<$Res, $Val extends ChecklistItem>
    implements $ChecklistItemCopyWith<$Res> {
  _$ChecklistItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChecklistItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? deadlineHours = freezed,
    Object? completed = null,
    Object? dueDate = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            text:
                null == text
                    ? _value.text
                    : text // ignore: cast_nullable_to_non_nullable
                        as String,
            deadlineHours:
                freezed == deadlineHours
                    ? _value.deadlineHours
                    : deadlineHours // ignore: cast_nullable_to_non_nullable
                        as int?,
            completed:
                null == completed
                    ? _value.completed
                    : completed // ignore: cast_nullable_to_non_nullable
                        as bool,
            dueDate:
                freezed == dueDate
                    ? _value.dueDate
                    : dueDate // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChecklistItemImplCopyWith<$Res>
    implements $ChecklistItemCopyWith<$Res> {
  factory _$$ChecklistItemImplCopyWith(
    _$ChecklistItemImpl value,
    $Res Function(_$ChecklistItemImpl) then,
  ) = __$$ChecklistItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String text,
    @_FlexibleIntConverter() int? deadlineHours,
    @_FlexibleBoolConverter() bool completed,
    @_FlexibleStringConverter() String? dueDate,
  });
}

/// @nodoc
class __$$ChecklistItemImplCopyWithImpl<$Res>
    extends _$ChecklistItemCopyWithImpl<$Res, _$ChecklistItemImpl>
    implements _$$ChecklistItemImplCopyWith<$Res> {
  __$$ChecklistItemImplCopyWithImpl(
    _$ChecklistItemImpl _value,
    $Res Function(_$ChecklistItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChecklistItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? deadlineHours = freezed,
    Object? completed = null,
    Object? dueDate = freezed,
  }) {
    return _then(
      _$ChecklistItemImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        text:
            null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                    as String,
        deadlineHours:
            freezed == deadlineHours
                ? _value.deadlineHours
                : deadlineHours // ignore: cast_nullable_to_non_nullable
                    as int?,
        completed:
            null == completed
                ? _value.completed
                : completed // ignore: cast_nullable_to_non_nullable
                    as bool,
        dueDate:
            freezed == dueDate
                ? _value.dueDate
                : dueDate // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChecklistItemImpl implements _ChecklistItem {
  const _$ChecklistItemImpl({
    required this.id,
    required this.text,
    @_FlexibleIntConverter() this.deadlineHours,
    @_FlexibleBoolConverter() this.completed = false,
    @_FlexibleStringConverter() this.dueDate,
  });

  factory _$ChecklistItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChecklistItemImplFromJson(json);

  @override
  final String id;
  @override
  final String text;
  @override
  @_FlexibleIntConverter()
  final int? deadlineHours;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool completed;
  @override
  @_FlexibleStringConverter()
  final String? dueDate;

  @override
  String toString() {
    return 'ChecklistItem(id: $id, text: $text, deadlineHours: $deadlineHours, completed: $completed, dueDate: $dueDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.deadlineHours, deadlineHours) ||
                other.deadlineHours == deadlineHours) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, text, deadlineHours, completed, dueDate);

  /// Create a copy of ChecklistItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistItemImplCopyWith<_$ChecklistItemImpl> get copyWith =>
      __$$ChecklistItemImplCopyWithImpl<_$ChecklistItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChecklistItemImplToJson(this);
  }
}

abstract class _ChecklistItem implements ChecklistItem {
  const factory _ChecklistItem({
    required final String id,
    required final String text,
    @_FlexibleIntConverter() final int? deadlineHours,
    @_FlexibleBoolConverter() final bool completed,
    @_FlexibleStringConverter() final String? dueDate,
  }) = _$ChecklistItemImpl;

  factory _ChecklistItem.fromJson(Map<String, dynamic> json) =
      _$ChecklistItemImpl.fromJson;

  @override
  String get id;
  @override
  String get text;
  @override
  @_FlexibleIntConverter()
  int? get deadlineHours;
  @override
  @_FlexibleBoolConverter()
  bool get completed;
  @override
  @_FlexibleStringConverter()
  String? get dueDate;

  /// Create a copy of ChecklistItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChecklistItemImplCopyWith<_$ChecklistItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AttendanceType _$AttendanceTypeFromJson(Map<String, dynamic> json) {
  return _AttendanceType.fromJson(json);
}

/// @nodoc
mixin _$AttendanceType {
  @_FlexibleStringConverter()
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'default_status')
  @_FlexibleAttendanceStatusConverter()
  AttendanceStatus get defaultStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'available_statuses')
  @_FlexibleAttendanceStatusListConverter()
  List<AttendanceStatus>? get availableStatuses =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'default_plan')
  Map<String, dynamic>? get defaultPlan => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  @_FlexibleIntConverter()
  int? get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'relevant_groups')
  List<int>? get relevantGroups => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_time')
  @_FlexibleStringConverter()
  String? get startTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_time')
  @_FlexibleStringConverter()
  String? get endTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'manage_songs')
  @_FlexibleBoolConverter()
  bool get manageSongs => throw _privateConstructorUsedError;
  @_FlexibleIntConverter()
  int? get index => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get visible => throw _privateConstructorUsedError;
  @_FlexibleStringConverter()
  String? get color => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get highlight => throw _privateConstructorUsedError;
  @JsonKey(name: 'hide_name')
  @_FlexibleBoolConverter()
  bool get hideName => throw _privateConstructorUsedError;
  @JsonKey(name: 'include_in_average')
  @_FlexibleBoolConverter()
  bool get includeInAverage => throw _privateConstructorUsedError;
  @JsonKey(name: 'all_day')
  @_FlexibleBoolConverter()
  bool get allDay => throw _privateConstructorUsedError;
  @JsonKey(name: 'duration_days')
  @_FlexibleIntConverter()
  int? get durationDays => throw _privateConstructorUsedError;
  @_FlexibleBoolConverter()
  bool get notification => throw _privateConstructorUsedError;
  List<int>? get reminders => throw _privateConstructorUsedError;
  @JsonKey(name: 'additional_fields_filter')
  Map<String, dynamic>? get additionalFieldsFilter =>
      throw _privateConstructorUsedError;
  List<ChecklistItem>? get checklist =>
      throw _privateConstructorUsedError; // Field from Ionic that was missing
  @JsonKey(name: 'planning_title')
  @_FlexibleStringConverter()
  String? get planningTitle => throw _privateConstructorUsedError; // ATTENDANCE_SIGNOUT: place/navigation and registration fields per type
  @JsonKey(name: 'place_enabled')
  @_FlexibleBoolConverter()
  bool get placeEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'registration_fields')
  List<RegistrationField>? get registrationFields =>
      throw _privateConstructorUsedError;

  /// Serializes this AttendanceType to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AttendanceType
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttendanceTypeCopyWith<AttendanceType> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceTypeCopyWith<$Res> {
  factory $AttendanceTypeCopyWith(
    AttendanceType value,
    $Res Function(AttendanceType) then,
  ) = _$AttendanceTypeCopyWithImpl<$Res, AttendanceType>;
  @useResult
  $Res call({
    @_FlexibleStringConverter() String? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    String name,
    @JsonKey(name: 'default_status')
    @_FlexibleAttendanceStatusConverter()
    AttendanceStatus defaultStatus,
    @JsonKey(name: 'available_statuses')
    @_FlexibleAttendanceStatusListConverter()
    List<AttendanceStatus>? availableStatuses,
    @JsonKey(name: 'default_plan') Map<String, dynamic>? defaultPlan,
    @JsonKey(name: 'tenant_id') @_FlexibleIntConverter() int? tenantId,
    @JsonKey(name: 'relevant_groups') List<int>? relevantGroups,
    @JsonKey(name: 'start_time') @_FlexibleStringConverter() String? startTime,
    @JsonKey(name: 'end_time') @_FlexibleStringConverter() String? endTime,
    @JsonKey(name: 'manage_songs') @_FlexibleBoolConverter() bool manageSongs,
    @_FlexibleIntConverter() int? index,
    @_FlexibleBoolConverter() bool visible,
    @_FlexibleStringConverter() String? color,
    @_FlexibleBoolConverter() bool highlight,
    @JsonKey(name: 'hide_name') @_FlexibleBoolConverter() bool hideName,
    @JsonKey(name: 'include_in_average')
    @_FlexibleBoolConverter()
    bool includeInAverage,
    @JsonKey(name: 'all_day') @_FlexibleBoolConverter() bool allDay,
    @JsonKey(name: 'duration_days') @_FlexibleIntConverter() int? durationDays,
    @_FlexibleBoolConverter() bool notification,
    List<int>? reminders,
    @JsonKey(name: 'additional_fields_filter')
    Map<String, dynamic>? additionalFieldsFilter,
    List<ChecklistItem>? checklist,
    @JsonKey(name: 'planning_title')
    @_FlexibleStringConverter()
    String? planningTitle,
    @JsonKey(name: 'place_enabled') @_FlexibleBoolConverter() bool placeEnabled,
    @JsonKey(name: 'registration_fields')
    List<RegistrationField>? registrationFields,
  });
}

/// @nodoc
class _$AttendanceTypeCopyWithImpl<$Res, $Val extends AttendanceType>
    implements $AttendanceTypeCopyWith<$Res> {
  _$AttendanceTypeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttendanceType
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? name = null,
    Object? defaultStatus = null,
    Object? availableStatuses = freezed,
    Object? defaultPlan = freezed,
    Object? tenantId = freezed,
    Object? relevantGroups = freezed,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? manageSongs = null,
    Object? index = freezed,
    Object? visible = null,
    Object? color = freezed,
    Object? highlight = null,
    Object? hideName = null,
    Object? includeInAverage = null,
    Object? allDay = null,
    Object? durationDays = freezed,
    Object? notification = null,
    Object? reminders = freezed,
    Object? additionalFieldsFilter = freezed,
    Object? checklist = freezed,
    Object? planningTitle = freezed,
    Object? placeEnabled = null,
    Object? registrationFields = freezed,
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
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            defaultStatus:
                null == defaultStatus
                    ? _value.defaultStatus
                    : defaultStatus // ignore: cast_nullable_to_non_nullable
                        as AttendanceStatus,
            availableStatuses:
                freezed == availableStatuses
                    ? _value.availableStatuses
                    : availableStatuses // ignore: cast_nullable_to_non_nullable
                        as List<AttendanceStatus>?,
            defaultPlan:
                freezed == defaultPlan
                    ? _value.defaultPlan
                    : defaultPlan // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
            tenantId:
                freezed == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int?,
            relevantGroups:
                freezed == relevantGroups
                    ? _value.relevantGroups
                    : relevantGroups // ignore: cast_nullable_to_non_nullable
                        as List<int>?,
            startTime:
                freezed == startTime
                    ? _value.startTime
                    : startTime // ignore: cast_nullable_to_non_nullable
                        as String?,
            endTime:
                freezed == endTime
                    ? _value.endTime
                    : endTime // ignore: cast_nullable_to_non_nullable
                        as String?,
            manageSongs:
                null == manageSongs
                    ? _value.manageSongs
                    : manageSongs // ignore: cast_nullable_to_non_nullable
                        as bool,
            index:
                freezed == index
                    ? _value.index
                    : index // ignore: cast_nullable_to_non_nullable
                        as int?,
            visible:
                null == visible
                    ? _value.visible
                    : visible // ignore: cast_nullable_to_non_nullable
                        as bool,
            color:
                freezed == color
                    ? _value.color
                    : color // ignore: cast_nullable_to_non_nullable
                        as String?,
            highlight:
                null == highlight
                    ? _value.highlight
                    : highlight // ignore: cast_nullable_to_non_nullable
                        as bool,
            hideName:
                null == hideName
                    ? _value.hideName
                    : hideName // ignore: cast_nullable_to_non_nullable
                        as bool,
            includeInAverage:
                null == includeInAverage
                    ? _value.includeInAverage
                    : includeInAverage // ignore: cast_nullable_to_non_nullable
                        as bool,
            allDay:
                null == allDay
                    ? _value.allDay
                    : allDay // ignore: cast_nullable_to_non_nullable
                        as bool,
            durationDays:
                freezed == durationDays
                    ? _value.durationDays
                    : durationDays // ignore: cast_nullable_to_non_nullable
                        as int?,
            notification:
                null == notification
                    ? _value.notification
                    : notification // ignore: cast_nullable_to_non_nullable
                        as bool,
            reminders:
                freezed == reminders
                    ? _value.reminders
                    : reminders // ignore: cast_nullable_to_non_nullable
                        as List<int>?,
            additionalFieldsFilter:
                freezed == additionalFieldsFilter
                    ? _value.additionalFieldsFilter
                    : additionalFieldsFilter // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
            checklist:
                freezed == checklist
                    ? _value.checklist
                    : checklist // ignore: cast_nullable_to_non_nullable
                        as List<ChecklistItem>?,
            planningTitle:
                freezed == planningTitle
                    ? _value.planningTitle
                    : planningTitle // ignore: cast_nullable_to_non_nullable
                        as String?,
            placeEnabled:
                null == placeEnabled
                    ? _value.placeEnabled
                    : placeEnabled // ignore: cast_nullable_to_non_nullable
                        as bool,
            registrationFields:
                freezed == registrationFields
                    ? _value.registrationFields
                    : registrationFields // ignore: cast_nullable_to_non_nullable
                        as List<RegistrationField>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AttendanceTypeImplCopyWith<$Res>
    implements $AttendanceTypeCopyWith<$Res> {
  factory _$$AttendanceTypeImplCopyWith(
    _$AttendanceTypeImpl value,
    $Res Function(_$AttendanceTypeImpl) then,
  ) = __$$AttendanceTypeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @_FlexibleStringConverter() String? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    String name,
    @JsonKey(name: 'default_status')
    @_FlexibleAttendanceStatusConverter()
    AttendanceStatus defaultStatus,
    @JsonKey(name: 'available_statuses')
    @_FlexibleAttendanceStatusListConverter()
    List<AttendanceStatus>? availableStatuses,
    @JsonKey(name: 'default_plan') Map<String, dynamic>? defaultPlan,
    @JsonKey(name: 'tenant_id') @_FlexibleIntConverter() int? tenantId,
    @JsonKey(name: 'relevant_groups') List<int>? relevantGroups,
    @JsonKey(name: 'start_time') @_FlexibleStringConverter() String? startTime,
    @JsonKey(name: 'end_time') @_FlexibleStringConverter() String? endTime,
    @JsonKey(name: 'manage_songs') @_FlexibleBoolConverter() bool manageSongs,
    @_FlexibleIntConverter() int? index,
    @_FlexibleBoolConverter() bool visible,
    @_FlexibleStringConverter() String? color,
    @_FlexibleBoolConverter() bool highlight,
    @JsonKey(name: 'hide_name') @_FlexibleBoolConverter() bool hideName,
    @JsonKey(name: 'include_in_average')
    @_FlexibleBoolConverter()
    bool includeInAverage,
    @JsonKey(name: 'all_day') @_FlexibleBoolConverter() bool allDay,
    @JsonKey(name: 'duration_days') @_FlexibleIntConverter() int? durationDays,
    @_FlexibleBoolConverter() bool notification,
    List<int>? reminders,
    @JsonKey(name: 'additional_fields_filter')
    Map<String, dynamic>? additionalFieldsFilter,
    List<ChecklistItem>? checklist,
    @JsonKey(name: 'planning_title')
    @_FlexibleStringConverter()
    String? planningTitle,
    @JsonKey(name: 'place_enabled') @_FlexibleBoolConverter() bool placeEnabled,
    @JsonKey(name: 'registration_fields')
    List<RegistrationField>? registrationFields,
  });
}

/// @nodoc
class __$$AttendanceTypeImplCopyWithImpl<$Res>
    extends _$AttendanceTypeCopyWithImpl<$Res, _$AttendanceTypeImpl>
    implements _$$AttendanceTypeImplCopyWith<$Res> {
  __$$AttendanceTypeImplCopyWithImpl(
    _$AttendanceTypeImpl _value,
    $Res Function(_$AttendanceTypeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AttendanceType
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? name = null,
    Object? defaultStatus = null,
    Object? availableStatuses = freezed,
    Object? defaultPlan = freezed,
    Object? tenantId = freezed,
    Object? relevantGroups = freezed,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? manageSongs = null,
    Object? index = freezed,
    Object? visible = null,
    Object? color = freezed,
    Object? highlight = null,
    Object? hideName = null,
    Object? includeInAverage = null,
    Object? allDay = null,
    Object? durationDays = freezed,
    Object? notification = null,
    Object? reminders = freezed,
    Object? additionalFieldsFilter = freezed,
    Object? checklist = freezed,
    Object? planningTitle = freezed,
    Object? placeEnabled = null,
    Object? registrationFields = freezed,
  }) {
    return _then(
      _$AttendanceTypeImpl(
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
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        defaultStatus:
            null == defaultStatus
                ? _value.defaultStatus
                : defaultStatus // ignore: cast_nullable_to_non_nullable
                    as AttendanceStatus,
        availableStatuses:
            freezed == availableStatuses
                ? _value._availableStatuses
                : availableStatuses // ignore: cast_nullable_to_non_nullable
                    as List<AttendanceStatus>?,
        defaultPlan:
            freezed == defaultPlan
                ? _value._defaultPlan
                : defaultPlan // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
        tenantId:
            freezed == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int?,
        relevantGroups:
            freezed == relevantGroups
                ? _value._relevantGroups
                : relevantGroups // ignore: cast_nullable_to_non_nullable
                    as List<int>?,
        startTime:
            freezed == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                    as String?,
        endTime:
            freezed == endTime
                ? _value.endTime
                : endTime // ignore: cast_nullable_to_non_nullable
                    as String?,
        manageSongs:
            null == manageSongs
                ? _value.manageSongs
                : manageSongs // ignore: cast_nullable_to_non_nullable
                    as bool,
        index:
            freezed == index
                ? _value.index
                : index // ignore: cast_nullable_to_non_nullable
                    as int?,
        visible:
            null == visible
                ? _value.visible
                : visible // ignore: cast_nullable_to_non_nullable
                    as bool,
        color:
            freezed == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                    as String?,
        highlight:
            null == highlight
                ? _value.highlight
                : highlight // ignore: cast_nullable_to_non_nullable
                    as bool,
        hideName:
            null == hideName
                ? _value.hideName
                : hideName // ignore: cast_nullable_to_non_nullable
                    as bool,
        includeInAverage:
            null == includeInAverage
                ? _value.includeInAverage
                : includeInAverage // ignore: cast_nullable_to_non_nullable
                    as bool,
        allDay:
            null == allDay
                ? _value.allDay
                : allDay // ignore: cast_nullable_to_non_nullable
                    as bool,
        durationDays:
            freezed == durationDays
                ? _value.durationDays
                : durationDays // ignore: cast_nullable_to_non_nullable
                    as int?,
        notification:
            null == notification
                ? _value.notification
                : notification // ignore: cast_nullable_to_non_nullable
                    as bool,
        reminders:
            freezed == reminders
                ? _value._reminders
                : reminders // ignore: cast_nullable_to_non_nullable
                    as List<int>?,
        additionalFieldsFilter:
            freezed == additionalFieldsFilter
                ? _value._additionalFieldsFilter
                : additionalFieldsFilter // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
        checklist:
            freezed == checklist
                ? _value._checklist
                : checklist // ignore: cast_nullable_to_non_nullable
                    as List<ChecklistItem>?,
        planningTitle:
            freezed == planningTitle
                ? _value.planningTitle
                : planningTitle // ignore: cast_nullable_to_non_nullable
                    as String?,
        placeEnabled:
            null == placeEnabled
                ? _value.placeEnabled
                : placeEnabled // ignore: cast_nullable_to_non_nullable
                    as bool,
        registrationFields:
            freezed == registrationFields
                ? _value._registrationFields
                : registrationFields // ignore: cast_nullable_to_non_nullable
                    as List<RegistrationField>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AttendanceTypeImpl implements _AttendanceType {
  const _$AttendanceTypeImpl({
    @_FlexibleStringConverter() this.id,
    @JsonKey(name: 'created_at') this.createdAt,
    required this.name,
    @JsonKey(name: 'default_status')
    @_FlexibleAttendanceStatusConverter()
    this.defaultStatus = AttendanceStatus.neutral,
    @JsonKey(name: 'available_statuses')
    @_FlexibleAttendanceStatusListConverter()
    final List<AttendanceStatus>? availableStatuses,
    @JsonKey(name: 'default_plan') final Map<String, dynamic>? defaultPlan,
    @JsonKey(name: 'tenant_id') @_FlexibleIntConverter() this.tenantId,
    @JsonKey(name: 'relevant_groups') final List<int>? relevantGroups,
    @JsonKey(name: 'start_time') @_FlexibleStringConverter() this.startTime,
    @JsonKey(name: 'end_time') @_FlexibleStringConverter() this.endTime,
    @JsonKey(name: 'manage_songs')
    @_FlexibleBoolConverter()
    this.manageSongs = false,
    @_FlexibleIntConverter() this.index,
    @_FlexibleBoolConverter() this.visible = true,
    @_FlexibleStringConverter() this.color,
    @_FlexibleBoolConverter() this.highlight = false,
    @JsonKey(name: 'hide_name') @_FlexibleBoolConverter() this.hideName = false,
    @JsonKey(name: 'include_in_average')
    @_FlexibleBoolConverter()
    this.includeInAverage = true,
    @JsonKey(name: 'all_day') @_FlexibleBoolConverter() this.allDay = false,
    @JsonKey(name: 'duration_days') @_FlexibleIntConverter() this.durationDays,
    @_FlexibleBoolConverter() this.notification = false,
    final List<int>? reminders,
    @JsonKey(name: 'additional_fields_filter')
    final Map<String, dynamic>? additionalFieldsFilter,
    final List<ChecklistItem>? checklist,
    @JsonKey(name: 'planning_title')
    @_FlexibleStringConverter()
    this.planningTitle,
    @JsonKey(name: 'place_enabled')
    @_FlexibleBoolConverter()
    this.placeEnabled = false,
    @JsonKey(name: 'registration_fields')
    final List<RegistrationField>? registrationFields,
  }) : _availableStatuses = availableStatuses,
       _defaultPlan = defaultPlan,
       _relevantGroups = relevantGroups,
       _reminders = reminders,
       _additionalFieldsFilter = additionalFieldsFilter,
       _checklist = checklist,
       _registrationFields = registrationFields;

  factory _$AttendanceTypeImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttendanceTypeImplFromJson(json);

  @override
  @_FlexibleStringConverter()
  final String? id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  final String name;
  @override
  @JsonKey(name: 'default_status')
  @_FlexibleAttendanceStatusConverter()
  final AttendanceStatus defaultStatus;
  final List<AttendanceStatus>? _availableStatuses;
  @override
  @JsonKey(name: 'available_statuses')
  @_FlexibleAttendanceStatusListConverter()
  List<AttendanceStatus>? get availableStatuses {
    final value = _availableStatuses;
    if (value == null) return null;
    if (_availableStatuses is EqualUnmodifiableListView)
      return _availableStatuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

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
  @JsonKey(name: 'tenant_id')
  @_FlexibleIntConverter()
  final int? tenantId;
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
  @JsonKey(name: 'start_time')
  @_FlexibleStringConverter()
  final String? startTime;
  @override
  @JsonKey(name: 'end_time')
  @_FlexibleStringConverter()
  final String? endTime;
  @override
  @JsonKey(name: 'manage_songs')
  @_FlexibleBoolConverter()
  final bool manageSongs;
  @override
  @_FlexibleIntConverter()
  final int? index;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool visible;
  @override
  @_FlexibleStringConverter()
  final String? color;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool highlight;
  @override
  @JsonKey(name: 'hide_name')
  @_FlexibleBoolConverter()
  final bool hideName;
  @override
  @JsonKey(name: 'include_in_average')
  @_FlexibleBoolConverter()
  final bool includeInAverage;
  @override
  @JsonKey(name: 'all_day')
  @_FlexibleBoolConverter()
  final bool allDay;
  @override
  @JsonKey(name: 'duration_days')
  @_FlexibleIntConverter()
  final int? durationDays;
  @override
  @JsonKey()
  @_FlexibleBoolConverter()
  final bool notification;
  final List<int>? _reminders;
  @override
  List<int>? get reminders {
    final value = _reminders;
    if (value == null) return null;
    if (_reminders is EqualUnmodifiableListView) return _reminders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final Map<String, dynamic>? _additionalFieldsFilter;
  @override
  @JsonKey(name: 'additional_fields_filter')
  Map<String, dynamic>? get additionalFieldsFilter {
    final value = _additionalFieldsFilter;
    if (value == null) return null;
    if (_additionalFieldsFilter is EqualUnmodifiableMapView)
      return _additionalFieldsFilter;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final List<ChecklistItem>? _checklist;
  @override
  List<ChecklistItem>? get checklist {
    final value = _checklist;
    if (value == null) return null;
    if (_checklist is EqualUnmodifiableListView) return _checklist;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  // Field from Ionic that was missing
  @override
  @JsonKey(name: 'planning_title')
  @_FlexibleStringConverter()
  final String? planningTitle;
  // ATTENDANCE_SIGNOUT: place/navigation and registration fields per type
  @override
  @JsonKey(name: 'place_enabled')
  @_FlexibleBoolConverter()
  final bool placeEnabled;
  final List<RegistrationField>? _registrationFields;
  @override
  @JsonKey(name: 'registration_fields')
  List<RegistrationField>? get registrationFields {
    final value = _registrationFields;
    if (value == null) return null;
    if (_registrationFields is EqualUnmodifiableListView)
      return _registrationFields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'AttendanceType(id: $id, createdAt: $createdAt, name: $name, defaultStatus: $defaultStatus, availableStatuses: $availableStatuses, defaultPlan: $defaultPlan, tenantId: $tenantId, relevantGroups: $relevantGroups, startTime: $startTime, endTime: $endTime, manageSongs: $manageSongs, index: $index, visible: $visible, color: $color, highlight: $highlight, hideName: $hideName, includeInAverage: $includeInAverage, allDay: $allDay, durationDays: $durationDays, notification: $notification, reminders: $reminders, additionalFieldsFilter: $additionalFieldsFilter, checklist: $checklist, planningTitle: $planningTitle, placeEnabled: $placeEnabled, registrationFields: $registrationFields)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceTypeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.defaultStatus, defaultStatus) ||
                other.defaultStatus == defaultStatus) &&
            const DeepCollectionEquality().equals(
              other._availableStatuses,
              _availableStatuses,
            ) &&
            const DeepCollectionEquality().equals(
              other._defaultPlan,
              _defaultPlan,
            ) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            const DeepCollectionEquality().equals(
              other._relevantGroups,
              _relevantGroups,
            ) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.manageSongs, manageSongs) ||
                other.manageSongs == manageSongs) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.visible, visible) || other.visible == visible) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.highlight, highlight) ||
                other.highlight == highlight) &&
            (identical(other.hideName, hideName) ||
                other.hideName == hideName) &&
            (identical(other.includeInAverage, includeInAverage) ||
                other.includeInAverage == includeInAverage) &&
            (identical(other.allDay, allDay) || other.allDay == allDay) &&
            (identical(other.durationDays, durationDays) ||
                other.durationDays == durationDays) &&
            (identical(other.notification, notification) ||
                other.notification == notification) &&
            const DeepCollectionEquality().equals(
              other._reminders,
              _reminders,
            ) &&
            const DeepCollectionEquality().equals(
              other._additionalFieldsFilter,
              _additionalFieldsFilter,
            ) &&
            const DeepCollectionEquality().equals(
              other._checklist,
              _checklist,
            ) &&
            (identical(other.planningTitle, planningTitle) ||
                other.planningTitle == planningTitle) &&
            (identical(other.placeEnabled, placeEnabled) ||
                other.placeEnabled == placeEnabled) &&
            const DeepCollectionEquality().equals(
              other._registrationFields,
              _registrationFields,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    createdAt,
    name,
    defaultStatus,
    const DeepCollectionEquality().hash(_availableStatuses),
    const DeepCollectionEquality().hash(_defaultPlan),
    tenantId,
    const DeepCollectionEquality().hash(_relevantGroups),
    startTime,
    endTime,
    manageSongs,
    index,
    visible,
    color,
    highlight,
    hideName,
    includeInAverage,
    allDay,
    durationDays,
    notification,
    const DeepCollectionEquality().hash(_reminders),
    const DeepCollectionEquality().hash(_additionalFieldsFilter),
    const DeepCollectionEquality().hash(_checklist),
    planningTitle,
    placeEnabled,
    const DeepCollectionEquality().hash(_registrationFields),
  ]);

  /// Create a copy of AttendanceType
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendanceTypeImplCopyWith<_$AttendanceTypeImpl> get copyWith =>
      __$$AttendanceTypeImplCopyWithImpl<_$AttendanceTypeImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AttendanceTypeImplToJson(this);
  }
}

abstract class _AttendanceType implements AttendanceType {
  const factory _AttendanceType({
    @_FlexibleStringConverter() final String? id,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    required final String name,
    @JsonKey(name: 'default_status')
    @_FlexibleAttendanceStatusConverter()
    final AttendanceStatus defaultStatus,
    @JsonKey(name: 'available_statuses')
    @_FlexibleAttendanceStatusListConverter()
    final List<AttendanceStatus>? availableStatuses,
    @JsonKey(name: 'default_plan') final Map<String, dynamic>? defaultPlan,
    @JsonKey(name: 'tenant_id') @_FlexibleIntConverter() final int? tenantId,
    @JsonKey(name: 'relevant_groups') final List<int>? relevantGroups,
    @JsonKey(name: 'start_time')
    @_FlexibleStringConverter()
    final String? startTime,
    @JsonKey(name: 'end_time')
    @_FlexibleStringConverter()
    final String? endTime,
    @JsonKey(name: 'manage_songs')
    @_FlexibleBoolConverter()
    final bool manageSongs,
    @_FlexibleIntConverter() final int? index,
    @_FlexibleBoolConverter() final bool visible,
    @_FlexibleStringConverter() final String? color,
    @_FlexibleBoolConverter() final bool highlight,
    @JsonKey(name: 'hide_name') @_FlexibleBoolConverter() final bool hideName,
    @JsonKey(name: 'include_in_average')
    @_FlexibleBoolConverter()
    final bool includeInAverage,
    @JsonKey(name: 'all_day') @_FlexibleBoolConverter() final bool allDay,
    @JsonKey(name: 'duration_days')
    @_FlexibleIntConverter()
    final int? durationDays,
    @_FlexibleBoolConverter() final bool notification,
    final List<int>? reminders,
    @JsonKey(name: 'additional_fields_filter')
    final Map<String, dynamic>? additionalFieldsFilter,
    final List<ChecklistItem>? checklist,
    @JsonKey(name: 'planning_title')
    @_FlexibleStringConverter()
    final String? planningTitle,
    @JsonKey(name: 'place_enabled')
    @_FlexibleBoolConverter()
    final bool placeEnabled,
    @JsonKey(name: 'registration_fields')
    final List<RegistrationField>? registrationFields,
  }) = _$AttendanceTypeImpl;

  factory _AttendanceType.fromJson(Map<String, dynamic> json) =
      _$AttendanceTypeImpl.fromJson;

  @override
  @_FlexibleStringConverter()
  String? get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  String get name;
  @override
  @JsonKey(name: 'default_status')
  @_FlexibleAttendanceStatusConverter()
  AttendanceStatus get defaultStatus;
  @override
  @JsonKey(name: 'available_statuses')
  @_FlexibleAttendanceStatusListConverter()
  List<AttendanceStatus>? get availableStatuses;
  @override
  @JsonKey(name: 'default_plan')
  Map<String, dynamic>? get defaultPlan;
  @override
  @JsonKey(name: 'tenant_id')
  @_FlexibleIntConverter()
  int? get tenantId;
  @override
  @JsonKey(name: 'relevant_groups')
  List<int>? get relevantGroups;
  @override
  @JsonKey(name: 'start_time')
  @_FlexibleStringConverter()
  String? get startTime;
  @override
  @JsonKey(name: 'end_time')
  @_FlexibleStringConverter()
  String? get endTime;
  @override
  @JsonKey(name: 'manage_songs')
  @_FlexibleBoolConverter()
  bool get manageSongs;
  @override
  @_FlexibleIntConverter()
  int? get index;
  @override
  @_FlexibleBoolConverter()
  bool get visible;
  @override
  @_FlexibleStringConverter()
  String? get color;
  @override
  @_FlexibleBoolConverter()
  bool get highlight;
  @override
  @JsonKey(name: 'hide_name')
  @_FlexibleBoolConverter()
  bool get hideName;
  @override
  @JsonKey(name: 'include_in_average')
  @_FlexibleBoolConverter()
  bool get includeInAverage;
  @override
  @JsonKey(name: 'all_day')
  @_FlexibleBoolConverter()
  bool get allDay;
  @override
  @JsonKey(name: 'duration_days')
  @_FlexibleIntConverter()
  int? get durationDays;
  @override
  @_FlexibleBoolConverter()
  bool get notification;
  @override
  List<int>? get reminders;
  @override
  @JsonKey(name: 'additional_fields_filter')
  Map<String, dynamic>? get additionalFieldsFilter;
  @override
  List<ChecklistItem>? get checklist; // Field from Ionic that was missing
  @override
  @JsonKey(name: 'planning_title')
  @_FlexibleStringConverter()
  String? get planningTitle; // ATTENDANCE_SIGNOUT: place/navigation and registration fields per type
  @override
  @JsonKey(name: 'place_enabled')
  @_FlexibleBoolConverter()
  bool get placeEnabled;
  @override
  @JsonKey(name: 'registration_fields')
  List<RegistrationField>? get registrationFields;

  /// Create a copy of AttendanceType
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendanceTypeImplCopyWith<_$AttendanceTypeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RegistrationField _$RegistrationFieldFromJson(Map<String, dynamic> json) {
  return _RegistrationField.fromJson(json);
}

/// @nodoc
mixin _$RegistrationField {
  String get id => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  List<String>? get options => throw _privateConstructorUsedError;

  /// Serializes this RegistrationField to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RegistrationField
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RegistrationFieldCopyWith<RegistrationField> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RegistrationFieldCopyWith<$Res> {
  factory $RegistrationFieldCopyWith(
    RegistrationField value,
    $Res Function(RegistrationField) then,
  ) = _$RegistrationFieldCopyWithImpl<$Res, RegistrationField>;
  @useResult
  $Res call({String id, String label, String type, List<String>? options});
}

/// @nodoc
class _$RegistrationFieldCopyWithImpl<$Res, $Val extends RegistrationField>
    implements $RegistrationFieldCopyWith<$Res> {
  _$RegistrationFieldCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RegistrationField
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? type = null,
    Object? options = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            label:
                null == label
                    ? _value.label
                    : label // ignore: cast_nullable_to_non_nullable
                        as String,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String,
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
abstract class _$$RegistrationFieldImplCopyWith<$Res>
    implements $RegistrationFieldCopyWith<$Res> {
  factory _$$RegistrationFieldImplCopyWith(
    _$RegistrationFieldImpl value,
    $Res Function(_$RegistrationFieldImpl) then,
  ) = __$$RegistrationFieldImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String label, String type, List<String>? options});
}

/// @nodoc
class __$$RegistrationFieldImplCopyWithImpl<$Res>
    extends _$RegistrationFieldCopyWithImpl<$Res, _$RegistrationFieldImpl>
    implements _$$RegistrationFieldImplCopyWith<$Res> {
  __$$RegistrationFieldImplCopyWithImpl(
    _$RegistrationFieldImpl _value,
    $Res Function(_$RegistrationFieldImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RegistrationField
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? type = null,
    Object? options = freezed,
  }) {
    return _then(
      _$RegistrationFieldImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        label:
            null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                    as String,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String,
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
class _$RegistrationFieldImpl implements _RegistrationField {
  const _$RegistrationFieldImpl({
    required this.id,
    this.label = '',
    this.type = RegistrationFieldType.text,
    final List<String>? options,
  }) : _options = options;

  factory _$RegistrationFieldImpl.fromJson(Map<String, dynamic> json) =>
      _$$RegistrationFieldImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String label;
  @override
  @JsonKey()
  final String type;
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
    return 'RegistrationField(id: $id, label: $label, type: $type, options: $options)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RegistrationFieldImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other._options, _options));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    label,
    type,
    const DeepCollectionEquality().hash(_options),
  );

  /// Create a copy of RegistrationField
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RegistrationFieldImplCopyWith<_$RegistrationFieldImpl> get copyWith =>
      __$$RegistrationFieldImplCopyWithImpl<_$RegistrationFieldImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RegistrationFieldImplToJson(this);
  }
}

abstract class _RegistrationField implements RegistrationField {
  const factory _RegistrationField({
    required final String id,
    final String label,
    final String type,
    final List<String>? options,
  }) = _$RegistrationFieldImpl;

  factory _RegistrationField.fromJson(Map<String, dynamic> json) =
      _$RegistrationFieldImpl.fromJson;

  @override
  String get id;
  @override
  String get label;
  @override
  String get type;
  @override
  List<String>? get options;

  /// Create a copy of RegistrationField
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RegistrationFieldImplCopyWith<_$RegistrationFieldImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
