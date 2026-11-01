// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PlanField _$PlanFieldFromJson(Map<String, dynamic> json) {
  return _PlanField.fromJson(json);
}

/// @nodoc
mixin _$PlanField {
  @PlanStringConverter()
  String get id => throw _privateConstructorUsedError;
  @PlanStringConverter()
  String get name => throw _privateConstructorUsedError;
  @PlanStringConverter()
  String get time => throw _privateConstructorUsedError;
  String? get conductor => throw _privateConstructorUsedError;
  String? get currentTime => throw _privateConstructorUsedError;
  @PlanIntConverter()
  int? get songId => throw _privateConstructorUsedError;
  String? get info => throw _privateConstructorUsedError;

  /// Set when the field is an agenda item (TOP) of the team organisation.
  String? get agendaItemId => throw _privateConstructorUsedError;

  /// Head of a Programmblock.
  @PlanBoolConverter()
  bool get isGroup => throw _privateConstructorUsedError;

  /// Id of the Programmblock head this Unterpunkt belongs to.
  String? get groupId => throw _privateConstructorUsedError;

  /// Legacy Flutter flag for notes (Ionic only uses the `noteFld` id prefix).
  @JsonKey(includeToJson: false)
  @PlanBoolConverter()
  bool get isNote => throw _privateConstructorUsedError;

  /// Stable id of the row (Gemeinde App link); song rows reuse the song id
  /// as [id], which repeats (see `PlanBeamer.ensureFieldUids`).
  String? get uid => throw _privateConstructorUsedError;

  /// "Beamer-Datei nötig", set only when switched by hand; otherwise
  /// derived from the row (see `PlanBeamer.needsBeamer`).
  bool? get needsBeamer => throw _privateConstructorUsedError;

  /// SongBeamer file linked in the Gemeinde App.
  @BeamerFileConverter()
  BeamerFile? get beamerFile => throw _privateConstructorUsedError;

  /// Serializes this PlanField to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlanField
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanFieldCopyWith<PlanField> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanFieldCopyWith<$Res> {
  factory $PlanFieldCopyWith(PlanField value, $Res Function(PlanField) then) =
      _$PlanFieldCopyWithImpl<$Res, PlanField>;
  @useResult
  $Res call({
    @PlanStringConverter() String id,
    @PlanStringConverter() String name,
    @PlanStringConverter() String time,
    String? conductor,
    String? currentTime,
    @PlanIntConverter() int? songId,
    String? info,
    String? agendaItemId,
    @PlanBoolConverter() bool isGroup,
    String? groupId,
    @JsonKey(includeToJson: false) @PlanBoolConverter() bool isNote,
    String? uid,
    bool? needsBeamer,
    @BeamerFileConverter() BeamerFile? beamerFile,
  });

  $BeamerFileCopyWith<$Res>? get beamerFile;
}

/// @nodoc
class _$PlanFieldCopyWithImpl<$Res, $Val extends PlanField>
    implements $PlanFieldCopyWith<$Res> {
  _$PlanFieldCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanField
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? time = null,
    Object? conductor = freezed,
    Object? currentTime = freezed,
    Object? songId = freezed,
    Object? info = freezed,
    Object? agendaItemId = freezed,
    Object? isGroup = null,
    Object? groupId = freezed,
    Object? isNote = null,
    Object? uid = freezed,
    Object? needsBeamer = freezed,
    Object? beamerFile = freezed,
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
            time:
                null == time
                    ? _value.time
                    : time // ignore: cast_nullable_to_non_nullable
                        as String,
            conductor:
                freezed == conductor
                    ? _value.conductor
                    : conductor // ignore: cast_nullable_to_non_nullable
                        as String?,
            currentTime:
                freezed == currentTime
                    ? _value.currentTime
                    : currentTime // ignore: cast_nullable_to_non_nullable
                        as String?,
            songId:
                freezed == songId
                    ? _value.songId
                    : songId // ignore: cast_nullable_to_non_nullable
                        as int?,
            info:
                freezed == info
                    ? _value.info
                    : info // ignore: cast_nullable_to_non_nullable
                        as String?,
            agendaItemId:
                freezed == agendaItemId
                    ? _value.agendaItemId
                    : agendaItemId // ignore: cast_nullable_to_non_nullable
                        as String?,
            isGroup:
                null == isGroup
                    ? _value.isGroup
                    : isGroup // ignore: cast_nullable_to_non_nullable
                        as bool,
            groupId:
                freezed == groupId
                    ? _value.groupId
                    : groupId // ignore: cast_nullable_to_non_nullable
                        as String?,
            isNote:
                null == isNote
                    ? _value.isNote
                    : isNote // ignore: cast_nullable_to_non_nullable
                        as bool,
            uid:
                freezed == uid
                    ? _value.uid
                    : uid // ignore: cast_nullable_to_non_nullable
                        as String?,
            needsBeamer:
                freezed == needsBeamer
                    ? _value.needsBeamer
                    : needsBeamer // ignore: cast_nullable_to_non_nullable
                        as bool?,
            beamerFile:
                freezed == beamerFile
                    ? _value.beamerFile
                    : beamerFile // ignore: cast_nullable_to_non_nullable
                        as BeamerFile?,
          )
          as $Val,
    );
  }

  /// Create a copy of PlanField
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BeamerFileCopyWith<$Res>? get beamerFile {
    if (_value.beamerFile == null) {
      return null;
    }

    return $BeamerFileCopyWith<$Res>(_value.beamerFile!, (value) {
      return _then(_value.copyWith(beamerFile: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PlanFieldImplCopyWith<$Res>
    implements $PlanFieldCopyWith<$Res> {
  factory _$$PlanFieldImplCopyWith(
    _$PlanFieldImpl value,
    $Res Function(_$PlanFieldImpl) then,
  ) = __$$PlanFieldImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @PlanStringConverter() String id,
    @PlanStringConverter() String name,
    @PlanStringConverter() String time,
    String? conductor,
    String? currentTime,
    @PlanIntConverter() int? songId,
    String? info,
    String? agendaItemId,
    @PlanBoolConverter() bool isGroup,
    String? groupId,
    @JsonKey(includeToJson: false) @PlanBoolConverter() bool isNote,
    String? uid,
    bool? needsBeamer,
    @BeamerFileConverter() BeamerFile? beamerFile,
  });

  @override
  $BeamerFileCopyWith<$Res>? get beamerFile;
}

/// @nodoc
class __$$PlanFieldImplCopyWithImpl<$Res>
    extends _$PlanFieldCopyWithImpl<$Res, _$PlanFieldImpl>
    implements _$$PlanFieldImplCopyWith<$Res> {
  __$$PlanFieldImplCopyWithImpl(
    _$PlanFieldImpl _value,
    $Res Function(_$PlanFieldImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlanField
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? time = null,
    Object? conductor = freezed,
    Object? currentTime = freezed,
    Object? songId = freezed,
    Object? info = freezed,
    Object? agendaItemId = freezed,
    Object? isGroup = null,
    Object? groupId = freezed,
    Object? isNote = null,
    Object? uid = freezed,
    Object? needsBeamer = freezed,
    Object? beamerFile = freezed,
  }) {
    return _then(
      _$PlanFieldImpl(
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
        time:
            null == time
                ? _value.time
                : time // ignore: cast_nullable_to_non_nullable
                    as String,
        conductor:
            freezed == conductor
                ? _value.conductor
                : conductor // ignore: cast_nullable_to_non_nullable
                    as String?,
        currentTime:
            freezed == currentTime
                ? _value.currentTime
                : currentTime // ignore: cast_nullable_to_non_nullable
                    as String?,
        songId:
            freezed == songId
                ? _value.songId
                : songId // ignore: cast_nullable_to_non_nullable
                    as int?,
        info:
            freezed == info
                ? _value.info
                : info // ignore: cast_nullable_to_non_nullable
                    as String?,
        agendaItemId:
            freezed == agendaItemId
                ? _value.agendaItemId
                : agendaItemId // ignore: cast_nullable_to_non_nullable
                    as String?,
        isGroup:
            null == isGroup
                ? _value.isGroup
                : isGroup // ignore: cast_nullable_to_non_nullable
                    as bool,
        groupId:
            freezed == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                    as String?,
        isNote:
            null == isNote
                ? _value.isNote
                : isNote // ignore: cast_nullable_to_non_nullable
                    as bool,
        uid:
            freezed == uid
                ? _value.uid
                : uid // ignore: cast_nullable_to_non_nullable
                    as String?,
        needsBeamer:
            freezed == needsBeamer
                ? _value.needsBeamer
                : needsBeamer // ignore: cast_nullable_to_non_nullable
                    as bool?,
        beamerFile:
            freezed == beamerFile
                ? _value.beamerFile
                : beamerFile // ignore: cast_nullable_to_non_nullable
                    as BeamerFile?,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class _$PlanFieldImpl implements _PlanField {
  const _$PlanFieldImpl({
    @PlanStringConverter() required this.id,
    @PlanStringConverter() required this.name,
    @PlanStringConverter() this.time = '0',
    this.conductor,
    this.currentTime,
    @PlanIntConverter() this.songId,
    this.info,
    this.agendaItemId,
    @PlanBoolConverter() this.isGroup = false,
    this.groupId,
    @JsonKey(includeToJson: false) @PlanBoolConverter() this.isNote = false,
    this.uid,
    this.needsBeamer,
    @BeamerFileConverter() this.beamerFile,
  });

  factory _$PlanFieldImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanFieldImplFromJson(json);

  @override
  @PlanStringConverter()
  final String id;
  @override
  @PlanStringConverter()
  final String name;
  @override
  @JsonKey()
  @PlanStringConverter()
  final String time;
  @override
  final String? conductor;
  @override
  final String? currentTime;
  @override
  @PlanIntConverter()
  final int? songId;
  @override
  final String? info;

  /// Set when the field is an agenda item (TOP) of the team organisation.
  @override
  final String? agendaItemId;

  /// Head of a Programmblock.
  @override
  @JsonKey()
  @PlanBoolConverter()
  final bool isGroup;

  /// Id of the Programmblock head this Unterpunkt belongs to.
  @override
  final String? groupId;

  /// Legacy Flutter flag for notes (Ionic only uses the `noteFld` id prefix).
  @override
  @JsonKey(includeToJson: false)
  @PlanBoolConverter()
  final bool isNote;

  /// Stable id of the row (Gemeinde App link); song rows reuse the song id
  /// as [id], which repeats (see `PlanBeamer.ensureFieldUids`).
  @override
  final String? uid;

  /// "Beamer-Datei nötig", set only when switched by hand; otherwise
  /// derived from the row (see `PlanBeamer.needsBeamer`).
  @override
  final bool? needsBeamer;

  /// SongBeamer file linked in the Gemeinde App.
  @override
  @BeamerFileConverter()
  final BeamerFile? beamerFile;

  @override
  String toString() {
    return 'PlanField(id: $id, name: $name, time: $time, conductor: $conductor, currentTime: $currentTime, songId: $songId, info: $info, agendaItemId: $agendaItemId, isGroup: $isGroup, groupId: $groupId, isNote: $isNote, uid: $uid, needsBeamer: $needsBeamer, beamerFile: $beamerFile)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanFieldImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.conductor, conductor) ||
                other.conductor == conductor) &&
            (identical(other.currentTime, currentTime) ||
                other.currentTime == currentTime) &&
            (identical(other.songId, songId) || other.songId == songId) &&
            (identical(other.info, info) || other.info == info) &&
            (identical(other.agendaItemId, agendaItemId) ||
                other.agendaItemId == agendaItemId) &&
            (identical(other.isGroup, isGroup) || other.isGroup == isGroup) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.isNote, isNote) || other.isNote == isNote) &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.needsBeamer, needsBeamer) ||
                other.needsBeamer == needsBeamer) &&
            (identical(other.beamerFile, beamerFile) ||
                other.beamerFile == beamerFile));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    time,
    conductor,
    currentTime,
    songId,
    info,
    agendaItemId,
    isGroup,
    groupId,
    isNote,
    uid,
    needsBeamer,
    beamerFile,
  );

  /// Create a copy of PlanField
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanFieldImplCopyWith<_$PlanFieldImpl> get copyWith =>
      __$$PlanFieldImplCopyWithImpl<_$PlanFieldImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanFieldImplToJson(this);
  }
}

abstract class _PlanField implements PlanField {
  const factory _PlanField({
    @PlanStringConverter() required final String id,
    @PlanStringConverter() required final String name,
    @PlanStringConverter() final String time,
    final String? conductor,
    final String? currentTime,
    @PlanIntConverter() final int? songId,
    final String? info,
    final String? agendaItemId,
    @PlanBoolConverter() final bool isGroup,
    final String? groupId,
    @JsonKey(includeToJson: false) @PlanBoolConverter() final bool isNote,
    final String? uid,
    final bool? needsBeamer,
    @BeamerFileConverter() final BeamerFile? beamerFile,
  }) = _$PlanFieldImpl;

  factory _PlanField.fromJson(Map<String, dynamic> json) =
      _$PlanFieldImpl.fromJson;

  @override
  @PlanStringConverter()
  String get id;
  @override
  @PlanStringConverter()
  String get name;
  @override
  @PlanStringConverter()
  String get time;
  @override
  String? get conductor;
  @override
  String? get currentTime;
  @override
  @PlanIntConverter()
  int? get songId;
  @override
  String? get info;

  /// Set when the field is an agenda item (TOP) of the team organisation.
  @override
  String? get agendaItemId;

  /// Head of a Programmblock.
  @override
  @PlanBoolConverter()
  bool get isGroup;

  /// Id of the Programmblock head this Unterpunkt belongs to.
  @override
  String? get groupId;

  /// Legacy Flutter flag for notes (Ionic only uses the `noteFld` id prefix).
  @override
  @JsonKey(includeToJson: false)
  @PlanBoolConverter()
  bool get isNote;

  /// Stable id of the row (Gemeinde App link); song rows reuse the song id
  /// as [id], which repeats (see `PlanBeamer.ensureFieldUids`).
  @override
  String? get uid;

  /// "Beamer-Datei nötig", set only when switched by hand; otherwise
  /// derived from the row (see `PlanBeamer.needsBeamer`).
  @override
  bool? get needsBeamer;

  /// SongBeamer file linked in the Gemeinde App.
  @override
  @BeamerFileConverter()
  BeamerFile? get beamerFile;

  /// Create a copy of PlanField
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanFieldImplCopyWith<_$PlanFieldImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BeamerFile _$BeamerFileFromJson(Map<String, dynamic> json) {
  return _BeamerFile.fromJson(json);
}

/// @nodoc
mixin _$BeamerFile {
  String get name => throw _privateConstructorUsedError;
  String get path => throw _privateConstructorUsedError;
  String? get linkedAt => throw _privateConstructorUsedError;

  /// Serializes this BeamerFile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BeamerFile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BeamerFileCopyWith<BeamerFile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BeamerFileCopyWith<$Res> {
  factory $BeamerFileCopyWith(
    BeamerFile value,
    $Res Function(BeamerFile) then,
  ) = _$BeamerFileCopyWithImpl<$Res, BeamerFile>;
  @useResult
  $Res call({String name, String path, String? linkedAt});
}

/// @nodoc
class _$BeamerFileCopyWithImpl<$Res, $Val extends BeamerFile>
    implements $BeamerFileCopyWith<$Res> {
  _$BeamerFileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BeamerFile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = null,
    Object? linkedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            path:
                null == path
                    ? _value.path
                    : path // ignore: cast_nullable_to_non_nullable
                        as String,
            linkedAt:
                freezed == linkedAt
                    ? _value.linkedAt
                    : linkedAt // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BeamerFileImplCopyWith<$Res>
    implements $BeamerFileCopyWith<$Res> {
  factory _$$BeamerFileImplCopyWith(
    _$BeamerFileImpl value,
    $Res Function(_$BeamerFileImpl) then,
  ) = __$$BeamerFileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, String path, String? linkedAt});
}

/// @nodoc
class __$$BeamerFileImplCopyWithImpl<$Res>
    extends _$BeamerFileCopyWithImpl<$Res, _$BeamerFileImpl>
    implements _$$BeamerFileImplCopyWith<$Res> {
  __$$BeamerFileImplCopyWithImpl(
    _$BeamerFileImpl _value,
    $Res Function(_$BeamerFileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BeamerFile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = null,
    Object? linkedAt = freezed,
  }) {
    return _then(
      _$BeamerFileImpl(
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        path:
            null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                    as String,
        linkedAt:
            freezed == linkedAt
                ? _value.linkedAt
                : linkedAt // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _$BeamerFileImpl implements _BeamerFile {
  const _$BeamerFileImpl({this.name = '', this.path = '', this.linkedAt});

  factory _$BeamerFileImpl.fromJson(Map<String, dynamic> json) =>
      _$$BeamerFileImplFromJson(json);

  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String path;
  @override
  final String? linkedAt;

  @override
  String toString() {
    return 'BeamerFile(name: $name, path: $path, linkedAt: $linkedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BeamerFileImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.linkedAt, linkedAt) ||
                other.linkedAt == linkedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, path, linkedAt);

  /// Create a copy of BeamerFile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BeamerFileImplCopyWith<_$BeamerFileImpl> get copyWith =>
      __$$BeamerFileImplCopyWithImpl<_$BeamerFileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BeamerFileImplToJson(this);
  }
}

abstract class _BeamerFile implements BeamerFile {
  const factory _BeamerFile({
    final String name,
    final String path,
    final String? linkedAt,
  }) = _$BeamerFileImpl;

  factory _BeamerFile.fromJson(Map<String, dynamic> json) =
      _$BeamerFileImpl.fromJson;

  @override
  String get name;
  @override
  String get path;
  @override
  String? get linkedAt;

  /// Create a copy of BeamerFile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BeamerFileImplCopyWith<_$BeamerFileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Plan _$PlanFromJson(Map<String, dynamic> json) {
  return _Plan.fromJson(json);
}

/// @nodoc
mixin _$Plan {
  @PlanStringConverter()
  String get time => throw _privateConstructorUsedError;
  @PlanStringConverter()
  String get end => throw _privateConstructorUsedError;
  List<PlanField> get fields => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;

  /// Stable id of an additional plan (see `attendance.extra_plans`).
  String? get id => throw _privateConstructorUsedError;

  /// Custom chip label.
  String? get label => throw _privateConstructorUsedError;

  /// Day within a multi-day Termin, 0 = first day.
  @PlanIntConverter()
  int? get day => throw _privateConstructorUsedError;

  /// Serializes this Plan to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanCopyWith<Plan> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanCopyWith<$Res> {
  factory $PlanCopyWith(Plan value, $Res Function(Plan) then) =
      _$PlanCopyWithImpl<$Res, Plan>;
  @useResult
  $Res call({
    @PlanStringConverter() String time,
    @PlanStringConverter() String end,
    List<PlanField> fields,
    String? title,
    String? id,
    String? label,
    @PlanIntConverter() int? day,
  });
}

/// @nodoc
class _$PlanCopyWithImpl<$Res, $Val extends Plan>
    implements $PlanCopyWith<$Res> {
  _$PlanCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? time = null,
    Object? end = null,
    Object? fields = null,
    Object? title = freezed,
    Object? id = freezed,
    Object? label = freezed,
    Object? day = freezed,
  }) {
    return _then(
      _value.copyWith(
            time:
                null == time
                    ? _value.time
                    : time // ignore: cast_nullable_to_non_nullable
                        as String,
            end:
                null == end
                    ? _value.end
                    : end // ignore: cast_nullable_to_non_nullable
                        as String,
            fields:
                null == fields
                    ? _value.fields
                    : fields // ignore: cast_nullable_to_non_nullable
                        as List<PlanField>,
            title:
                freezed == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String?,
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String?,
            label:
                freezed == label
                    ? _value.label
                    : label // ignore: cast_nullable_to_non_nullable
                        as String?,
            day:
                freezed == day
                    ? _value.day
                    : day // ignore: cast_nullable_to_non_nullable
                        as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlanImplCopyWith<$Res> implements $PlanCopyWith<$Res> {
  factory _$$PlanImplCopyWith(
    _$PlanImpl value,
    $Res Function(_$PlanImpl) then,
  ) = __$$PlanImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @PlanStringConverter() String time,
    @PlanStringConverter() String end,
    List<PlanField> fields,
    String? title,
    String? id,
    String? label,
    @PlanIntConverter() int? day,
  });
}

/// @nodoc
class __$$PlanImplCopyWithImpl<$Res>
    extends _$PlanCopyWithImpl<$Res, _$PlanImpl>
    implements _$$PlanImplCopyWith<$Res> {
  __$$PlanImplCopyWithImpl(_$PlanImpl _value, $Res Function(_$PlanImpl) _then)
    : super(_value, _then);

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? time = null,
    Object? end = null,
    Object? fields = null,
    Object? title = freezed,
    Object? id = freezed,
    Object? label = freezed,
    Object? day = freezed,
  }) {
    return _then(
      _$PlanImpl(
        time:
            null == time
                ? _value.time
                : time // ignore: cast_nullable_to_non_nullable
                    as String,
        end:
            null == end
                ? _value.end
                : end // ignore: cast_nullable_to_non_nullable
                    as String,
        fields:
            null == fields
                ? _value._fields
                : fields // ignore: cast_nullable_to_non_nullable
                    as List<PlanField>,
        title:
            freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String?,
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String?,
        label:
            freezed == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                    as String?,
        day:
            freezed == day
                ? _value.day
                : day // ignore: cast_nullable_to_non_nullable
                    as int?,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class _$PlanImpl implements _Plan {
  const _$PlanImpl({
    @PlanStringConverter() this.time = '',
    @PlanStringConverter() this.end = '',
    final List<PlanField> fields = const <PlanField>[],
    this.title,
    this.id,
    this.label,
    @PlanIntConverter() this.day,
  }) : _fields = fields;

  factory _$PlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanImplFromJson(json);

  @override
  @JsonKey()
  @PlanStringConverter()
  final String time;
  @override
  @JsonKey()
  @PlanStringConverter()
  final String end;
  final List<PlanField> _fields;
  @override
  @JsonKey()
  List<PlanField> get fields {
    if (_fields is EqualUnmodifiableListView) return _fields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fields);
  }

  @override
  final String? title;

  /// Stable id of an additional plan (see `attendance.extra_plans`).
  @override
  final String? id;

  /// Custom chip label.
  @override
  final String? label;

  /// Day within a multi-day Termin, 0 = first day.
  @override
  @PlanIntConverter()
  final int? day;

  @override
  String toString() {
    return 'Plan(time: $time, end: $end, fields: $fields, title: $title, id: $id, label: $label, day: $day)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanImpl &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.end, end) || other.end == end) &&
            const DeepCollectionEquality().equals(other._fields, _fields) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.day, day) || other.day == day));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    time,
    end,
    const DeepCollectionEquality().hash(_fields),
    title,
    id,
    label,
    day,
  );

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanImplCopyWith<_$PlanImpl> get copyWith =>
      __$$PlanImplCopyWithImpl<_$PlanImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanImplToJson(this);
  }
}

abstract class _Plan implements Plan {
  const factory _Plan({
    @PlanStringConverter() final String time,
    @PlanStringConverter() final String end,
    final List<PlanField> fields,
    final String? title,
    final String? id,
    final String? label,
    @PlanIntConverter() final int? day,
  }) = _$PlanImpl;

  factory _Plan.fromJson(Map<String, dynamic> json) = _$PlanImpl.fromJson;

  @override
  @PlanStringConverter()
  String get time;
  @override
  @PlanStringConverter()
  String get end;
  @override
  List<PlanField> get fields;
  @override
  String? get title;

  /// Stable id of an additional plan (see `attendance.extra_plans`).
  @override
  String? get id;

  /// Custom chip label.
  @override
  String? get label;

  /// Day within a multi-day Termin, 0 = first day.
  @override
  @PlanIntConverter()
  int? get day;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanImplCopyWith<_$PlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlanBlockTemplate _$PlanBlockTemplateFromJson(Map<String, dynamic> json) {
  return _PlanBlockTemplate.fromJson(json);
}

/// @nodoc
mixin _$PlanBlockTemplate {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<PlanField> get fields => throw _privateConstructorUsedError;

  /// Serializes this PlanBlockTemplate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlanBlockTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanBlockTemplateCopyWith<PlanBlockTemplate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanBlockTemplateCopyWith<$Res> {
  factory $PlanBlockTemplateCopyWith(
    PlanBlockTemplate value,
    $Res Function(PlanBlockTemplate) then,
  ) = _$PlanBlockTemplateCopyWithImpl<$Res, PlanBlockTemplate>;
  @useResult
  $Res call({String id, String name, List<PlanField> fields});
}

/// @nodoc
class _$PlanBlockTemplateCopyWithImpl<$Res, $Val extends PlanBlockTemplate>
    implements $PlanBlockTemplateCopyWith<$Res> {
  _$PlanBlockTemplateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanBlockTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? name = null, Object? fields = null}) {
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
            fields:
                null == fields
                    ? _value.fields
                    : fields // ignore: cast_nullable_to_non_nullable
                        as List<PlanField>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlanBlockTemplateImplCopyWith<$Res>
    implements $PlanBlockTemplateCopyWith<$Res> {
  factory _$$PlanBlockTemplateImplCopyWith(
    _$PlanBlockTemplateImpl value,
    $Res Function(_$PlanBlockTemplateImpl) then,
  ) = __$$PlanBlockTemplateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String name, List<PlanField> fields});
}

/// @nodoc
class __$$PlanBlockTemplateImplCopyWithImpl<$Res>
    extends _$PlanBlockTemplateCopyWithImpl<$Res, _$PlanBlockTemplateImpl>
    implements _$$PlanBlockTemplateImplCopyWith<$Res> {
  __$$PlanBlockTemplateImplCopyWithImpl(
    _$PlanBlockTemplateImpl _value,
    $Res Function(_$PlanBlockTemplateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlanBlockTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? name = null, Object? fields = null}) {
    return _then(
      _$PlanBlockTemplateImpl(
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
        fields:
            null == fields
                ? _value._fields
                : fields // ignore: cast_nullable_to_non_nullable
                    as List<PlanField>,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class _$PlanBlockTemplateImpl implements _PlanBlockTemplate {
  const _$PlanBlockTemplateImpl({
    required this.id,
    required this.name,
    final List<PlanField> fields = const <PlanField>[],
  }) : _fields = fields;

  factory _$PlanBlockTemplateImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanBlockTemplateImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  final List<PlanField> _fields;
  @override
  @JsonKey()
  List<PlanField> get fields {
    if (_fields is EqualUnmodifiableListView) return _fields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fields);
  }

  @override
  String toString() {
    return 'PlanBlockTemplate(id: $id, name: $name, fields: $fields)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanBlockTemplateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._fields, _fields));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    const DeepCollectionEquality().hash(_fields),
  );

  /// Create a copy of PlanBlockTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanBlockTemplateImplCopyWith<_$PlanBlockTemplateImpl> get copyWith =>
      __$$PlanBlockTemplateImplCopyWithImpl<_$PlanBlockTemplateImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanBlockTemplateImplToJson(this);
  }
}

abstract class _PlanBlockTemplate implements PlanBlockTemplate {
  const factory _PlanBlockTemplate({
    required final String id,
    required final String name,
    final List<PlanField> fields,
  }) = _$PlanBlockTemplateImpl;

  factory _PlanBlockTemplate.fromJson(Map<String, dynamic> json) =
      _$PlanBlockTemplateImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  List<PlanField> get fields;

  /// Create a copy of PlanBlockTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanBlockTemplateImplCopyWith<_$PlanBlockTemplateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SharedPlan _$SharedPlanFromJson(Map<String, dynamic> json) {
  return _SharedPlan.fromJson(json);
}

/// @nodoc
mixin _$SharedPlan {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'edit_key')
  String get editKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'plan_title')
  String? get planTitle => throw _privateConstructorUsedError;
  String? get date => throw _privateConstructorUsedError;
  String? get time => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_time')
  String? get endTime => throw _privateConstructorUsedError;
  List<PlanField> get fields => throw _privateConstructorUsedError;
  @JsonKey(name: 'branding_id')
  String? get brandingId => throw _privateConstructorUsedError;
  @JsonKey(name: 'creator_user_id')
  String? get creatorUserId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'org_id')
  @PlanIntConverter()
  int? get orgId => throw _privateConstructorUsedError;

  /// Serializes this SharedPlan to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SharedPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SharedPlanCopyWith<SharedPlan> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SharedPlanCopyWith<$Res> {
  factory $SharedPlanCopyWith(
    SharedPlan value,
    $Res Function(SharedPlan) then,
  ) = _$SharedPlanCopyWithImpl<$Res, SharedPlan>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'edit_key') String editKey,
    @JsonKey(name: 'plan_title') String? planTitle,
    String? date,
    String? time,
    @JsonKey(name: 'end_time') String? endTime,
    List<PlanField> fields,
    @JsonKey(name: 'branding_id') String? brandingId,
    @JsonKey(name: 'creator_user_id') String? creatorUserId,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'org_id') @PlanIntConverter() int? orgId,
  });
}

/// @nodoc
class _$SharedPlanCopyWithImpl<$Res, $Val extends SharedPlan>
    implements $SharedPlanCopyWith<$Res> {
  _$SharedPlanCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SharedPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? editKey = null,
    Object? planTitle = freezed,
    Object? date = freezed,
    Object? time = freezed,
    Object? endTime = freezed,
    Object? fields = null,
    Object? brandingId = freezed,
    Object? creatorUserId = freezed,
    Object? createdAt = freezed,
    Object? orgId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            editKey:
                null == editKey
                    ? _value.editKey
                    : editKey // ignore: cast_nullable_to_non_nullable
                        as String,
            planTitle:
                freezed == planTitle
                    ? _value.planTitle
                    : planTitle // ignore: cast_nullable_to_non_nullable
                        as String?,
            date:
                freezed == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as String?,
            time:
                freezed == time
                    ? _value.time
                    : time // ignore: cast_nullable_to_non_nullable
                        as String?,
            endTime:
                freezed == endTime
                    ? _value.endTime
                    : endTime // ignore: cast_nullable_to_non_nullable
                        as String?,
            fields:
                null == fields
                    ? _value.fields
                    : fields // ignore: cast_nullable_to_non_nullable
                        as List<PlanField>,
            brandingId:
                freezed == brandingId
                    ? _value.brandingId
                    : brandingId // ignore: cast_nullable_to_non_nullable
                        as String?,
            creatorUserId:
                freezed == creatorUserId
                    ? _value.creatorUserId
                    : creatorUserId // ignore: cast_nullable_to_non_nullable
                        as String?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as String?,
            orgId:
                freezed == orgId
                    ? _value.orgId
                    : orgId // ignore: cast_nullable_to_non_nullable
                        as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SharedPlanImplCopyWith<$Res>
    implements $SharedPlanCopyWith<$Res> {
  factory _$$SharedPlanImplCopyWith(
    _$SharedPlanImpl value,
    $Res Function(_$SharedPlanImpl) then,
  ) = __$$SharedPlanImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'edit_key') String editKey,
    @JsonKey(name: 'plan_title') String? planTitle,
    String? date,
    String? time,
    @JsonKey(name: 'end_time') String? endTime,
    List<PlanField> fields,
    @JsonKey(name: 'branding_id') String? brandingId,
    @JsonKey(name: 'creator_user_id') String? creatorUserId,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'org_id') @PlanIntConverter() int? orgId,
  });
}

/// @nodoc
class __$$SharedPlanImplCopyWithImpl<$Res>
    extends _$SharedPlanCopyWithImpl<$Res, _$SharedPlanImpl>
    implements _$$SharedPlanImplCopyWith<$Res> {
  __$$SharedPlanImplCopyWithImpl(
    _$SharedPlanImpl _value,
    $Res Function(_$SharedPlanImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SharedPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? editKey = null,
    Object? planTitle = freezed,
    Object? date = freezed,
    Object? time = freezed,
    Object? endTime = freezed,
    Object? fields = null,
    Object? brandingId = freezed,
    Object? creatorUserId = freezed,
    Object? createdAt = freezed,
    Object? orgId = freezed,
  }) {
    return _then(
      _$SharedPlanImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        editKey:
            null == editKey
                ? _value.editKey
                : editKey // ignore: cast_nullable_to_non_nullable
                    as String,
        planTitle:
            freezed == planTitle
                ? _value.planTitle
                : planTitle // ignore: cast_nullable_to_non_nullable
                    as String?,
        date:
            freezed == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as String?,
        time:
            freezed == time
                ? _value.time
                : time // ignore: cast_nullable_to_non_nullable
                    as String?,
        endTime:
            freezed == endTime
                ? _value.endTime
                : endTime // ignore: cast_nullable_to_non_nullable
                    as String?,
        fields:
            null == fields
                ? _value._fields
                : fields // ignore: cast_nullable_to_non_nullable
                    as List<PlanField>,
        brandingId:
            freezed == brandingId
                ? _value.brandingId
                : brandingId // ignore: cast_nullable_to_non_nullable
                    as String?,
        creatorUserId:
            freezed == creatorUserId
                ? _value.creatorUserId
                : creatorUserId // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as String?,
        orgId:
            freezed == orgId
                ? _value.orgId
                : orgId // ignore: cast_nullable_to_non_nullable
                    as int?,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class _$SharedPlanImpl implements _SharedPlan {
  const _$SharedPlanImpl({
    required this.id,
    @JsonKey(name: 'edit_key') required this.editKey,
    @JsonKey(name: 'plan_title') this.planTitle,
    this.date,
    this.time,
    @JsonKey(name: 'end_time') this.endTime,
    final List<PlanField> fields = const <PlanField>[],
    @JsonKey(name: 'branding_id') this.brandingId,
    @JsonKey(name: 'creator_user_id') this.creatorUserId,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'org_id') @PlanIntConverter() this.orgId,
  }) : _fields = fields;

  factory _$SharedPlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$SharedPlanImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'edit_key')
  final String editKey;
  @override
  @JsonKey(name: 'plan_title')
  final String? planTitle;
  @override
  final String? date;
  @override
  final String? time;
  @override
  @JsonKey(name: 'end_time')
  final String? endTime;
  final List<PlanField> _fields;
  @override
  @JsonKey()
  List<PlanField> get fields {
    if (_fields is EqualUnmodifiableListView) return _fields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fields);
  }

  @override
  @JsonKey(name: 'branding_id')
  final String? brandingId;
  @override
  @JsonKey(name: 'creator_user_id')
  final String? creatorUserId;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @override
  @JsonKey(name: 'org_id')
  @PlanIntConverter()
  final int? orgId;

  @override
  String toString() {
    return 'SharedPlan(id: $id, editKey: $editKey, planTitle: $planTitle, date: $date, time: $time, endTime: $endTime, fields: $fields, brandingId: $brandingId, creatorUserId: $creatorUserId, createdAt: $createdAt, orgId: $orgId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SharedPlanImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.editKey, editKey) || other.editKey == editKey) &&
            (identical(other.planTitle, planTitle) ||
                other.planTitle == planTitle) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            const DeepCollectionEquality().equals(other._fields, _fields) &&
            (identical(other.brandingId, brandingId) ||
                other.brandingId == brandingId) &&
            (identical(other.creatorUserId, creatorUserId) ||
                other.creatorUserId == creatorUserId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.orgId, orgId) || other.orgId == orgId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    editKey,
    planTitle,
    date,
    time,
    endTime,
    const DeepCollectionEquality().hash(_fields),
    brandingId,
    creatorUserId,
    createdAt,
    orgId,
  );

  /// Create a copy of SharedPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SharedPlanImplCopyWith<_$SharedPlanImpl> get copyWith =>
      __$$SharedPlanImplCopyWithImpl<_$SharedPlanImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SharedPlanImplToJson(this);
  }
}

abstract class _SharedPlan implements SharedPlan {
  const factory _SharedPlan({
    required final String id,
    @JsonKey(name: 'edit_key') required final String editKey,
    @JsonKey(name: 'plan_title') final String? planTitle,
    final String? date,
    final String? time,
    @JsonKey(name: 'end_time') final String? endTime,
    final List<PlanField> fields,
    @JsonKey(name: 'branding_id') final String? brandingId,
    @JsonKey(name: 'creator_user_id') final String? creatorUserId,
    @JsonKey(name: 'created_at') final String? createdAt,
    @JsonKey(name: 'org_id') @PlanIntConverter() final int? orgId,
  }) = _$SharedPlanImpl;

  factory _SharedPlan.fromJson(Map<String, dynamic> json) =
      _$SharedPlanImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'edit_key')
  String get editKey;
  @override
  @JsonKey(name: 'plan_title')
  String? get planTitle;
  @override
  String? get date;
  @override
  String? get time;
  @override
  @JsonKey(name: 'end_time')
  String? get endTime;
  @override
  List<PlanField> get fields;
  @override
  @JsonKey(name: 'branding_id')
  String? get brandingId;
  @override
  @JsonKey(name: 'creator_user_id')
  String? get creatorUserId;
  @override
  @JsonKey(name: 'created_at')
  String? get createdAt;
  @override
  @JsonKey(name: 'org_id')
  @PlanIntConverter()
  int? get orgId;

  /// Create a copy of SharedPlan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SharedPlanImplCopyWith<_$SharedPlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlanAttendance _$PlanAttendanceFromJson(Map<String, dynamic> json) {
  return _PlanAttendance.fromJson(json);
}

/// @nodoc
mixin _$PlanAttendance {
  @PlanIntConverter()
  int? get id => throw _privateConstructorUsedError;
  @PlanIntConverter()
  int? get tenantId => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError;
  @JsonKey(name: 'duration_days')
  @PlanIntConverter()
  int? get durationDays => throw _privateConstructorUsedError;
  Plan? get plan => throw _privateConstructorUsedError;
  @JsonKey(name: 'extra_plans')
  List<Plan>? get extraPlans => throw _privateConstructorUsedError;
  @JsonKey(name: 'type_id')
  String? get typeId => throw _privateConstructorUsedError;
  String? get typeInfo => throw _privateConstructorUsedError;
  String? get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_time')
  String? get startTime => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  @JsonKey(name: 'share_plan')
  @PlanBoolConverter()
  bool get sharePlan => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_org_plan')
  @PlanBoolConverter()
  bool get isOrgPlan => throw _privateConstructorUsedError;
  @JsonKey(name: 'share_key')
  String? get shareKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'share_edit_key')
  String? get shareEditKey => throw _privateConstructorUsedError;

  /// Display name of the owning instance (org plans only, not a column).
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get tenantName => throw _privateConstructorUsedError;

  /// Serializes this PlanAttendance to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlanAttendance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanAttendanceCopyWith<PlanAttendance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanAttendanceCopyWith<$Res> {
  factory $PlanAttendanceCopyWith(
    PlanAttendance value,
    $Res Function(PlanAttendance) then,
  ) = _$PlanAttendanceCopyWithImpl<$Res, PlanAttendance>;
  @useResult
  $Res call({
    @PlanIntConverter() int? id,
    @PlanIntConverter() int? tenantId,
    String date,
    @JsonKey(name: 'duration_days') @PlanIntConverter() int? durationDays,
    Plan? plan,
    @JsonKey(name: 'extra_plans') List<Plan>? extraPlans,
    @JsonKey(name: 'type_id') String? typeId,
    String? typeInfo,
    String? type,
    @JsonKey(name: 'start_time') String? startTime,
    String? notes,
    @JsonKey(name: 'share_plan') @PlanBoolConverter() bool sharePlan,
    @JsonKey(name: 'is_org_plan') @PlanBoolConverter() bool isOrgPlan,
    @JsonKey(name: 'share_key') String? shareKey,
    @JsonKey(name: 'share_edit_key') String? shareEditKey,
    @JsonKey(includeFromJson: false, includeToJson: false) String? tenantName,
  });

  $PlanCopyWith<$Res>? get plan;
}

/// @nodoc
class _$PlanAttendanceCopyWithImpl<$Res, $Val extends PlanAttendance>
    implements $PlanAttendanceCopyWith<$Res> {
  _$PlanAttendanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanAttendance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? date = null,
    Object? durationDays = freezed,
    Object? plan = freezed,
    Object? extraPlans = freezed,
    Object? typeId = freezed,
    Object? typeInfo = freezed,
    Object? type = freezed,
    Object? startTime = freezed,
    Object? notes = freezed,
    Object? sharePlan = null,
    Object? isOrgPlan = null,
    Object? shareKey = freezed,
    Object? shareEditKey = freezed,
    Object? tenantName = freezed,
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
            date:
                null == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as String,
            durationDays:
                freezed == durationDays
                    ? _value.durationDays
                    : durationDays // ignore: cast_nullable_to_non_nullable
                        as int?,
            plan:
                freezed == plan
                    ? _value.plan
                    : plan // ignore: cast_nullable_to_non_nullable
                        as Plan?,
            extraPlans:
                freezed == extraPlans
                    ? _value.extraPlans
                    : extraPlans // ignore: cast_nullable_to_non_nullable
                        as List<Plan>?,
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
            type:
                freezed == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String?,
            startTime:
                freezed == startTime
                    ? _value.startTime
                    : startTime // ignore: cast_nullable_to_non_nullable
                        as String?,
            notes:
                freezed == notes
                    ? _value.notes
                    : notes // ignore: cast_nullable_to_non_nullable
                        as String?,
            sharePlan:
                null == sharePlan
                    ? _value.sharePlan
                    : sharePlan // ignore: cast_nullable_to_non_nullable
                        as bool,
            isOrgPlan:
                null == isOrgPlan
                    ? _value.isOrgPlan
                    : isOrgPlan // ignore: cast_nullable_to_non_nullable
                        as bool,
            shareKey:
                freezed == shareKey
                    ? _value.shareKey
                    : shareKey // ignore: cast_nullable_to_non_nullable
                        as String?,
            shareEditKey:
                freezed == shareEditKey
                    ? _value.shareEditKey
                    : shareEditKey // ignore: cast_nullable_to_non_nullable
                        as String?,
            tenantName:
                freezed == tenantName
                    ? _value.tenantName
                    : tenantName // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of PlanAttendance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PlanCopyWith<$Res>? get plan {
    if (_value.plan == null) {
      return null;
    }

    return $PlanCopyWith<$Res>(_value.plan!, (value) {
      return _then(_value.copyWith(plan: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PlanAttendanceImplCopyWith<$Res>
    implements $PlanAttendanceCopyWith<$Res> {
  factory _$$PlanAttendanceImplCopyWith(
    _$PlanAttendanceImpl value,
    $Res Function(_$PlanAttendanceImpl) then,
  ) = __$$PlanAttendanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @PlanIntConverter() int? id,
    @PlanIntConverter() int? tenantId,
    String date,
    @JsonKey(name: 'duration_days') @PlanIntConverter() int? durationDays,
    Plan? plan,
    @JsonKey(name: 'extra_plans') List<Plan>? extraPlans,
    @JsonKey(name: 'type_id') String? typeId,
    String? typeInfo,
    String? type,
    @JsonKey(name: 'start_time') String? startTime,
    String? notes,
    @JsonKey(name: 'share_plan') @PlanBoolConverter() bool sharePlan,
    @JsonKey(name: 'is_org_plan') @PlanBoolConverter() bool isOrgPlan,
    @JsonKey(name: 'share_key') String? shareKey,
    @JsonKey(name: 'share_edit_key') String? shareEditKey,
    @JsonKey(includeFromJson: false, includeToJson: false) String? tenantName,
  });

  @override
  $PlanCopyWith<$Res>? get plan;
}

/// @nodoc
class __$$PlanAttendanceImplCopyWithImpl<$Res>
    extends _$PlanAttendanceCopyWithImpl<$Res, _$PlanAttendanceImpl>
    implements _$$PlanAttendanceImplCopyWith<$Res> {
  __$$PlanAttendanceImplCopyWithImpl(
    _$PlanAttendanceImpl _value,
    $Res Function(_$PlanAttendanceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlanAttendance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? date = null,
    Object? durationDays = freezed,
    Object? plan = freezed,
    Object? extraPlans = freezed,
    Object? typeId = freezed,
    Object? typeInfo = freezed,
    Object? type = freezed,
    Object? startTime = freezed,
    Object? notes = freezed,
    Object? sharePlan = null,
    Object? isOrgPlan = null,
    Object? shareKey = freezed,
    Object? shareEditKey = freezed,
    Object? tenantName = freezed,
  }) {
    return _then(
      _$PlanAttendanceImpl(
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
        date:
            null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as String,
        durationDays:
            freezed == durationDays
                ? _value.durationDays
                : durationDays // ignore: cast_nullable_to_non_nullable
                    as int?,
        plan:
            freezed == plan
                ? _value.plan
                : plan // ignore: cast_nullable_to_non_nullable
                    as Plan?,
        extraPlans:
            freezed == extraPlans
                ? _value._extraPlans
                : extraPlans // ignore: cast_nullable_to_non_nullable
                    as List<Plan>?,
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
        type:
            freezed == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String?,
        startTime:
            freezed == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                    as String?,
        notes:
            freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                    as String?,
        sharePlan:
            null == sharePlan
                ? _value.sharePlan
                : sharePlan // ignore: cast_nullable_to_non_nullable
                    as bool,
        isOrgPlan:
            null == isOrgPlan
                ? _value.isOrgPlan
                : isOrgPlan // ignore: cast_nullable_to_non_nullable
                    as bool,
        shareKey:
            freezed == shareKey
                ? _value.shareKey
                : shareKey // ignore: cast_nullable_to_non_nullable
                    as String?,
        shareEditKey:
            freezed == shareEditKey
                ? _value.shareEditKey
                : shareEditKey // ignore: cast_nullable_to_non_nullable
                    as String?,
        tenantName:
            freezed == tenantName
                ? _value.tenantName
                : tenantName // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class _$PlanAttendanceImpl implements _PlanAttendance {
  const _$PlanAttendanceImpl({
    @PlanIntConverter() required this.id,
    @PlanIntConverter() this.tenantId,
    this.date = '',
    @JsonKey(name: 'duration_days') @PlanIntConverter() this.durationDays,
    this.plan,
    @JsonKey(name: 'extra_plans') final List<Plan>? extraPlans,
    @JsonKey(name: 'type_id') this.typeId,
    this.typeInfo,
    this.type,
    @JsonKey(name: 'start_time') this.startTime,
    this.notes,
    @JsonKey(name: 'share_plan') @PlanBoolConverter() this.sharePlan = false,
    @JsonKey(name: 'is_org_plan') @PlanBoolConverter() this.isOrgPlan = false,
    @JsonKey(name: 'share_key') this.shareKey,
    @JsonKey(name: 'share_edit_key') this.shareEditKey,
    @JsonKey(includeFromJson: false, includeToJson: false) this.tenantName,
  }) : _extraPlans = extraPlans;

  factory _$PlanAttendanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanAttendanceImplFromJson(json);

  @override
  @PlanIntConverter()
  final int? id;
  @override
  @PlanIntConverter()
  final int? tenantId;
  @override
  @JsonKey()
  final String date;
  @override
  @JsonKey(name: 'duration_days')
  @PlanIntConverter()
  final int? durationDays;
  @override
  final Plan? plan;
  final List<Plan>? _extraPlans;
  @override
  @JsonKey(name: 'extra_plans')
  List<Plan>? get extraPlans {
    final value = _extraPlans;
    if (value == null) return null;
    if (_extraPlans is EqualUnmodifiableListView) return _extraPlans;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'type_id')
  final String? typeId;
  @override
  final String? typeInfo;
  @override
  final String? type;
  @override
  @JsonKey(name: 'start_time')
  final String? startTime;
  @override
  final String? notes;
  @override
  @JsonKey(name: 'share_plan')
  @PlanBoolConverter()
  final bool sharePlan;
  @override
  @JsonKey(name: 'is_org_plan')
  @PlanBoolConverter()
  final bool isOrgPlan;
  @override
  @JsonKey(name: 'share_key')
  final String? shareKey;
  @override
  @JsonKey(name: 'share_edit_key')
  final String? shareEditKey;

  /// Display name of the owning instance (org plans only, not a column).
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? tenantName;

  @override
  String toString() {
    return 'PlanAttendance(id: $id, tenantId: $tenantId, date: $date, durationDays: $durationDays, plan: $plan, extraPlans: $extraPlans, typeId: $typeId, typeInfo: $typeInfo, type: $type, startTime: $startTime, notes: $notes, sharePlan: $sharePlan, isOrgPlan: $isOrgPlan, shareKey: $shareKey, shareEditKey: $shareEditKey, tenantName: $tenantName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanAttendanceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.durationDays, durationDays) ||
                other.durationDays == durationDays) &&
            (identical(other.plan, plan) || other.plan == plan) &&
            const DeepCollectionEquality().equals(
              other._extraPlans,
              _extraPlans,
            ) &&
            (identical(other.typeId, typeId) || other.typeId == typeId) &&
            (identical(other.typeInfo, typeInfo) ||
                other.typeInfo == typeInfo) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.sharePlan, sharePlan) ||
                other.sharePlan == sharePlan) &&
            (identical(other.isOrgPlan, isOrgPlan) ||
                other.isOrgPlan == isOrgPlan) &&
            (identical(other.shareKey, shareKey) ||
                other.shareKey == shareKey) &&
            (identical(other.shareEditKey, shareEditKey) ||
                other.shareEditKey == shareEditKey) &&
            (identical(other.tenantName, tenantName) ||
                other.tenantName == tenantName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tenantId,
    date,
    durationDays,
    plan,
    const DeepCollectionEquality().hash(_extraPlans),
    typeId,
    typeInfo,
    type,
    startTime,
    notes,
    sharePlan,
    isOrgPlan,
    shareKey,
    shareEditKey,
    tenantName,
  );

  /// Create a copy of PlanAttendance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanAttendanceImplCopyWith<_$PlanAttendanceImpl> get copyWith =>
      __$$PlanAttendanceImplCopyWithImpl<_$PlanAttendanceImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanAttendanceImplToJson(this);
  }
}

abstract class _PlanAttendance implements PlanAttendance {
  const factory _PlanAttendance({
    @PlanIntConverter() required final int? id,
    @PlanIntConverter() final int? tenantId,
    final String date,
    @JsonKey(name: 'duration_days') @PlanIntConverter() final int? durationDays,
    final Plan? plan,
    @JsonKey(name: 'extra_plans') final List<Plan>? extraPlans,
    @JsonKey(name: 'type_id') final String? typeId,
    final String? typeInfo,
    final String? type,
    @JsonKey(name: 'start_time') final String? startTime,
    final String? notes,
    @JsonKey(name: 'share_plan') @PlanBoolConverter() final bool sharePlan,
    @JsonKey(name: 'is_org_plan') @PlanBoolConverter() final bool isOrgPlan,
    @JsonKey(name: 'share_key') final String? shareKey,
    @JsonKey(name: 'share_edit_key') final String? shareEditKey,
    @JsonKey(includeFromJson: false, includeToJson: false)
    final String? tenantName,
  }) = _$PlanAttendanceImpl;

  factory _PlanAttendance.fromJson(Map<String, dynamic> json) =
      _$PlanAttendanceImpl.fromJson;

  @override
  @PlanIntConverter()
  int? get id;
  @override
  @PlanIntConverter()
  int? get tenantId;
  @override
  String get date;
  @override
  @JsonKey(name: 'duration_days')
  @PlanIntConverter()
  int? get durationDays;
  @override
  Plan? get plan;
  @override
  @JsonKey(name: 'extra_plans')
  List<Plan>? get extraPlans;
  @override
  @JsonKey(name: 'type_id')
  String? get typeId;
  @override
  String? get typeInfo;
  @override
  String? get type;
  @override
  @JsonKey(name: 'start_time')
  String? get startTime;
  @override
  String? get notes;
  @override
  @JsonKey(name: 'share_plan')
  @PlanBoolConverter()
  bool get sharePlan;
  @override
  @JsonKey(name: 'is_org_plan')
  @PlanBoolConverter()
  bool get isOrgPlan;
  @override
  @JsonKey(name: 'share_key')
  String? get shareKey;
  @override
  @JsonKey(name: 'share_edit_key')
  String? get shareEditKey;

  /// Display name of the owning instance (org plans only, not a column).
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get tenantName;

  /// Create a copy of PlanAttendance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanAttendanceImplCopyWith<_$PlanAttendanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlanAttendanceType _$PlanAttendanceTypeFromJson(Map<String, dynamic> json) {
  return _PlanAttendanceType.fromJson(json);
}

/// @nodoc
mixin _$PlanAttendanceType {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'default_plan')
  Plan? get defaultPlan => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_time')
  String? get startTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'planning_title')
  String? get planningTitle => throw _privateConstructorUsedError;
  @JsonKey(name: 'planning_prefix_instance_name')
  @PlanBoolConverter()
  bool get planningPrefixInstanceName => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_default_org_plan')
  @PlanBoolConverter()
  bool get isDefaultOrgPlan => throw _privateConstructorUsedError;

  /// Serializes this PlanAttendanceType to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlanAttendanceType
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanAttendanceTypeCopyWith<PlanAttendanceType> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanAttendanceTypeCopyWith<$Res> {
  factory $PlanAttendanceTypeCopyWith(
    PlanAttendanceType value,
    $Res Function(PlanAttendanceType) then,
  ) = _$PlanAttendanceTypeCopyWithImpl<$Res, PlanAttendanceType>;
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'default_plan') Plan? defaultPlan,
    @JsonKey(name: 'start_time') String? startTime,
    @JsonKey(name: 'planning_title') String? planningTitle,
    @JsonKey(name: 'planning_prefix_instance_name')
    @PlanBoolConverter()
    bool planningPrefixInstanceName,
    @JsonKey(name: 'is_default_org_plan')
    @PlanBoolConverter()
    bool isDefaultOrgPlan,
  });

  $PlanCopyWith<$Res>? get defaultPlan;
}

/// @nodoc
class _$PlanAttendanceTypeCopyWithImpl<$Res, $Val extends PlanAttendanceType>
    implements $PlanAttendanceTypeCopyWith<$Res> {
  _$PlanAttendanceTypeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanAttendanceType
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? defaultPlan = freezed,
    Object? startTime = freezed,
    Object? planningTitle = freezed,
    Object? planningPrefixInstanceName = null,
    Object? isDefaultOrgPlan = null,
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
            defaultPlan:
                freezed == defaultPlan
                    ? _value.defaultPlan
                    : defaultPlan // ignore: cast_nullable_to_non_nullable
                        as Plan?,
            startTime:
                freezed == startTime
                    ? _value.startTime
                    : startTime // ignore: cast_nullable_to_non_nullable
                        as String?,
            planningTitle:
                freezed == planningTitle
                    ? _value.planningTitle
                    : planningTitle // ignore: cast_nullable_to_non_nullable
                        as String?,
            planningPrefixInstanceName:
                null == planningPrefixInstanceName
                    ? _value.planningPrefixInstanceName
                    : planningPrefixInstanceName // ignore: cast_nullable_to_non_nullable
                        as bool,
            isDefaultOrgPlan:
                null == isDefaultOrgPlan
                    ? _value.isDefaultOrgPlan
                    : isDefaultOrgPlan // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of PlanAttendanceType
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PlanCopyWith<$Res>? get defaultPlan {
    if (_value.defaultPlan == null) {
      return null;
    }

    return $PlanCopyWith<$Res>(_value.defaultPlan!, (value) {
      return _then(_value.copyWith(defaultPlan: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PlanAttendanceTypeImplCopyWith<$Res>
    implements $PlanAttendanceTypeCopyWith<$Res> {
  factory _$$PlanAttendanceTypeImplCopyWith(
    _$PlanAttendanceTypeImpl value,
    $Res Function(_$PlanAttendanceTypeImpl) then,
  ) = __$$PlanAttendanceTypeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'default_plan') Plan? defaultPlan,
    @JsonKey(name: 'start_time') String? startTime,
    @JsonKey(name: 'planning_title') String? planningTitle,
    @JsonKey(name: 'planning_prefix_instance_name')
    @PlanBoolConverter()
    bool planningPrefixInstanceName,
    @JsonKey(name: 'is_default_org_plan')
    @PlanBoolConverter()
    bool isDefaultOrgPlan,
  });

  @override
  $PlanCopyWith<$Res>? get defaultPlan;
}

/// @nodoc
class __$$PlanAttendanceTypeImplCopyWithImpl<$Res>
    extends _$PlanAttendanceTypeCopyWithImpl<$Res, _$PlanAttendanceTypeImpl>
    implements _$$PlanAttendanceTypeImplCopyWith<$Res> {
  __$$PlanAttendanceTypeImplCopyWithImpl(
    _$PlanAttendanceTypeImpl _value,
    $Res Function(_$PlanAttendanceTypeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlanAttendanceType
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? defaultPlan = freezed,
    Object? startTime = freezed,
    Object? planningTitle = freezed,
    Object? planningPrefixInstanceName = null,
    Object? isDefaultOrgPlan = null,
  }) {
    return _then(
      _$PlanAttendanceTypeImpl(
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
        defaultPlan:
            freezed == defaultPlan
                ? _value.defaultPlan
                : defaultPlan // ignore: cast_nullable_to_non_nullable
                    as Plan?,
        startTime:
            freezed == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                    as String?,
        planningTitle:
            freezed == planningTitle
                ? _value.planningTitle
                : planningTitle // ignore: cast_nullable_to_non_nullable
                    as String?,
        planningPrefixInstanceName:
            null == planningPrefixInstanceName
                ? _value.planningPrefixInstanceName
                : planningPrefixInstanceName // ignore: cast_nullable_to_non_nullable
                    as bool,
        isDefaultOrgPlan:
            null == isDefaultOrgPlan
                ? _value.isDefaultOrgPlan
                : isDefaultOrgPlan // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class _$PlanAttendanceTypeImpl implements _PlanAttendanceType {
  const _$PlanAttendanceTypeImpl({
    required this.id,
    this.name = '',
    @JsonKey(name: 'default_plan') this.defaultPlan,
    @JsonKey(name: 'start_time') this.startTime,
    @JsonKey(name: 'planning_title') this.planningTitle,
    @JsonKey(name: 'planning_prefix_instance_name')
    @PlanBoolConverter()
    this.planningPrefixInstanceName = false,
    @JsonKey(name: 'is_default_org_plan')
    @PlanBoolConverter()
    this.isDefaultOrgPlan = false,
  });

  factory _$PlanAttendanceTypeImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanAttendanceTypeImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey(name: 'default_plan')
  final Plan? defaultPlan;
  @override
  @JsonKey(name: 'start_time')
  final String? startTime;
  @override
  @JsonKey(name: 'planning_title')
  final String? planningTitle;
  @override
  @JsonKey(name: 'planning_prefix_instance_name')
  @PlanBoolConverter()
  final bool planningPrefixInstanceName;
  @override
  @JsonKey(name: 'is_default_org_plan')
  @PlanBoolConverter()
  final bool isDefaultOrgPlan;

  @override
  String toString() {
    return 'PlanAttendanceType(id: $id, name: $name, defaultPlan: $defaultPlan, startTime: $startTime, planningTitle: $planningTitle, planningPrefixInstanceName: $planningPrefixInstanceName, isDefaultOrgPlan: $isDefaultOrgPlan)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanAttendanceTypeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.defaultPlan, defaultPlan) ||
                other.defaultPlan == defaultPlan) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.planningTitle, planningTitle) ||
                other.planningTitle == planningTitle) &&
            (identical(
                  other.planningPrefixInstanceName,
                  planningPrefixInstanceName,
                ) ||
                other.planningPrefixInstanceName ==
                    planningPrefixInstanceName) &&
            (identical(other.isDefaultOrgPlan, isDefaultOrgPlan) ||
                other.isDefaultOrgPlan == isDefaultOrgPlan));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    defaultPlan,
    startTime,
    planningTitle,
    planningPrefixInstanceName,
    isDefaultOrgPlan,
  );

  /// Create a copy of PlanAttendanceType
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanAttendanceTypeImplCopyWith<_$PlanAttendanceTypeImpl> get copyWith =>
      __$$PlanAttendanceTypeImplCopyWithImpl<_$PlanAttendanceTypeImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanAttendanceTypeImplToJson(this);
  }
}

abstract class _PlanAttendanceType implements PlanAttendanceType {
  const factory _PlanAttendanceType({
    required final String id,
    final String name,
    @JsonKey(name: 'default_plan') final Plan? defaultPlan,
    @JsonKey(name: 'start_time') final String? startTime,
    @JsonKey(name: 'planning_title') final String? planningTitle,
    @JsonKey(name: 'planning_prefix_instance_name')
    @PlanBoolConverter()
    final bool planningPrefixInstanceName,
    @JsonKey(name: 'is_default_org_plan')
    @PlanBoolConverter()
    final bool isDefaultOrgPlan,
  }) = _$PlanAttendanceTypeImpl;

  factory _PlanAttendanceType.fromJson(Map<String, dynamic> json) =
      _$PlanAttendanceTypeImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'default_plan')
  Plan? get defaultPlan;
  @override
  @JsonKey(name: 'start_time')
  String? get startTime;
  @override
  @JsonKey(name: 'planning_title')
  String? get planningTitle;
  @override
  @JsonKey(name: 'planning_prefix_instance_name')
  @PlanBoolConverter()
  bool get planningPrefixInstanceName;
  @override
  @JsonKey(name: 'is_default_org_plan')
  @PlanBoolConverter()
  bool get isDefaultOrgPlan;

  /// Create a copy of PlanAttendanceType
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanAttendanceTypeImplCopyWith<_$PlanAttendanceTypeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrgExtraField _$OrgExtraFieldFromJson(Map<String, dynamic> json) {
  return _OrgExtraField.fromJson(json);
}

/// @nodoc
mixin _$OrgExtraField {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  dynamic get defaultValue => throw _privateConstructorUsedError;
  List<String> get options => throw _privateConstructorUsedError;
  bool get visibleToPlayers => throw _privateConstructorUsedError;
  bool get editableByPlayers => throw _privateConstructorUsedError;
  String get displayMode => throw _privateConstructorUsedError;

  /// Serializes this OrgExtraField to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrgExtraField
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrgExtraFieldCopyWith<OrgExtraField> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrgExtraFieldCopyWith<$Res> {
  factory $OrgExtraFieldCopyWith(
    OrgExtraField value,
    $Res Function(OrgExtraField) then,
  ) = _$OrgExtraFieldCopyWithImpl<$Res, OrgExtraField>;
  @useResult
  $Res call({
    String id,
    String name,
    String type,
    dynamic defaultValue,
    List<String> options,
    bool visibleToPlayers,
    bool editableByPlayers,
    String displayMode,
  });
}

/// @nodoc
class _$OrgExtraFieldCopyWithImpl<$Res, $Val extends OrgExtraField>
    implements $OrgExtraFieldCopyWith<$Res> {
  _$OrgExtraFieldCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrgExtraField
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? defaultValue = freezed,
    Object? options = null,
    Object? visibleToPlayers = null,
    Object? editableByPlayers = null,
    Object? displayMode = null,
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
                null == options
                    ? _value.options
                    : options // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            visibleToPlayers:
                null == visibleToPlayers
                    ? _value.visibleToPlayers
                    : visibleToPlayers // ignore: cast_nullable_to_non_nullable
                        as bool,
            editableByPlayers:
                null == editableByPlayers
                    ? _value.editableByPlayers
                    : editableByPlayers // ignore: cast_nullable_to_non_nullable
                        as bool,
            displayMode:
                null == displayMode
                    ? _value.displayMode
                    : displayMode // ignore: cast_nullable_to_non_nullable
                        as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OrgExtraFieldImplCopyWith<$Res>
    implements $OrgExtraFieldCopyWith<$Res> {
  factory _$$OrgExtraFieldImplCopyWith(
    _$OrgExtraFieldImpl value,
    $Res Function(_$OrgExtraFieldImpl) then,
  ) = __$$OrgExtraFieldImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String type,
    dynamic defaultValue,
    List<String> options,
    bool visibleToPlayers,
    bool editableByPlayers,
    String displayMode,
  });
}

/// @nodoc
class __$$OrgExtraFieldImplCopyWithImpl<$Res>
    extends _$OrgExtraFieldCopyWithImpl<$Res, _$OrgExtraFieldImpl>
    implements _$$OrgExtraFieldImplCopyWith<$Res> {
  __$$OrgExtraFieldImplCopyWithImpl(
    _$OrgExtraFieldImpl _value,
    $Res Function(_$OrgExtraFieldImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OrgExtraField
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? defaultValue = freezed,
    Object? options = null,
    Object? visibleToPlayers = null,
    Object? editableByPlayers = null,
    Object? displayMode = null,
  }) {
    return _then(
      _$OrgExtraFieldImpl(
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
            null == options
                ? _value._options
                : options // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        visibleToPlayers:
            null == visibleToPlayers
                ? _value.visibleToPlayers
                : visibleToPlayers // ignore: cast_nullable_to_non_nullable
                    as bool,
        editableByPlayers:
            null == editableByPlayers
                ? _value.editableByPlayers
                : editableByPlayers // ignore: cast_nullable_to_non_nullable
                    as bool,
        displayMode:
            null == displayMode
                ? _value.displayMode
                : displayMode // ignore: cast_nullable_to_non_nullable
                    as String,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class _$OrgExtraFieldImpl implements _OrgExtraField {
  const _$OrgExtraFieldImpl({
    required this.id,
    required this.name,
    this.type = 'text',
    this.defaultValue,
    final List<String> options = const <String>[],
    this.visibleToPlayers = false,
    this.editableByPlayers = false,
    this.displayMode = 'chip',
  }) : _options = options;

  factory _$OrgExtraFieldImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrgExtraFieldImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey()
  final String type;
  @override
  final dynamic defaultValue;
  final List<String> _options;
  @override
  @JsonKey()
  List<String> get options {
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_options);
  }

  @override
  @JsonKey()
  final bool visibleToPlayers;
  @override
  @JsonKey()
  final bool editableByPlayers;
  @override
  @JsonKey()
  final String displayMode;

  @override
  String toString() {
    return 'OrgExtraField(id: $id, name: $name, type: $type, defaultValue: $defaultValue, options: $options, visibleToPlayers: $visibleToPlayers, editableByPlayers: $editableByPlayers, displayMode: $displayMode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrgExtraFieldImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(
              other.defaultValue,
              defaultValue,
            ) &&
            const DeepCollectionEquality().equals(other._options, _options) &&
            (identical(other.visibleToPlayers, visibleToPlayers) ||
                other.visibleToPlayers == visibleToPlayers) &&
            (identical(other.editableByPlayers, editableByPlayers) ||
                other.editableByPlayers == editableByPlayers) &&
            (identical(other.displayMode, displayMode) ||
                other.displayMode == displayMode));
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
    visibleToPlayers,
    editableByPlayers,
    displayMode,
  );

  /// Create a copy of OrgExtraField
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrgExtraFieldImplCopyWith<_$OrgExtraFieldImpl> get copyWith =>
      __$$OrgExtraFieldImplCopyWithImpl<_$OrgExtraFieldImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrgExtraFieldImplToJson(this);
  }
}

abstract class _OrgExtraField implements OrgExtraField {
  const factory _OrgExtraField({
    required final String id,
    required final String name,
    final String type,
    final dynamic defaultValue,
    final List<String> options,
    final bool visibleToPlayers,
    final bool editableByPlayers,
    final String displayMode,
  }) = _$OrgExtraFieldImpl;

  factory _OrgExtraField.fromJson(Map<String, dynamic> json) =
      _$OrgExtraFieldImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get type;
  @override
  dynamic get defaultValue;
  @override
  List<String> get options;
  @override
  bool get visibleToPlayers;
  @override
  bool get editableByPlayers;
  @override
  String get displayMode;

  /// Create a copy of OrgExtraField
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrgExtraFieldImplCopyWith<_$OrgExtraFieldImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
