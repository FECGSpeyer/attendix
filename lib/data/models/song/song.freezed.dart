// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'song.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Song _$SongFromJson(Map<String, dynamic> json) {
  return _Song.fromJson(json);
}

/// @nodoc
mixin _$Song {
  int? get id => throw _privateConstructorUsedError;
  int? get tenantId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int? get number => throw _privateConstructorUsedError;
  String? get prefix => throw _privateConstructorUsedError;
  bool get withChoir => throw _privateConstructorUsedError;
  bool get withSolo => throw _privateConstructorUsedError;

  /// Computed client-side from history (last past entry). Not a DB column.
  @JsonKey(includeToJson: false)
  String? get lastSung => throw _privateConstructorUsedError;

  /// Computed client-side: next planned (future) history entry. Not a DB column.
  @JsonKey(includeToJson: false)
  String? get nextPlanned => throw _privateConstructorUsedError;
  String? get link => throw _privateConstructorUsedError;

  /// Computed client-side: conductor of [lastSung]. Not a DB column.
  @JsonKey(includeToJson: false)
  String? get conductor => throw _privateConstructorUsedError;
  String? get composer => throw _privateConstructorUsedError;
  int? get legacyId => throw _privateConstructorUsedError;
  @JsonKey(name: 'instrument_ids')
  List<int>? get instrumentIds => throw _privateConstructorUsedError;
  List<SongFile>? get files => throw _privateConstructorUsedError;
  int? get difficulty => throw _privateConstructorUsedError;

  /// Legacy single category (superseded by [categoryIds])
  String? get category => throw _privateConstructorUsedError;

  /// Song category ids (uuid[] column `category_ids`)
  @JsonKey(name: 'category_ids')
  List<String>? get categoryIds => throw _privateConstructorUsedError;

  /// Values of the tenant's `song_additional_fields`
  @JsonKey(name: 'additional_fields')
  Map<String, dynamic>? get additionalFields =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// SongBeamer file of the Werk, written by the Gemeinde App only
  /// (never sent back by Attendix).
  @JsonKey(name: 'beamer_file', includeToJson: false)
  @BeamerFileConverter()
  BeamerFile? get beamerFile => throw _privateConstructorUsedError;

  /// Serializes this Song to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Song
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SongCopyWith<Song> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SongCopyWith<$Res> {
  factory $SongCopyWith(Song value, $Res Function(Song) then) =
      _$SongCopyWithImpl<$Res, Song>;
  @useResult
  $Res call({
    int? id,
    int? tenantId,
    String name,
    int? number,
    String? prefix,
    bool withChoir,
    bool withSolo,
    @JsonKey(includeToJson: false) String? lastSung,
    @JsonKey(includeToJson: false) String? nextPlanned,
    String? link,
    @JsonKey(includeToJson: false) String? conductor,
    String? composer,
    int? legacyId,
    @JsonKey(name: 'instrument_ids') List<int>? instrumentIds,
    List<SongFile>? files,
    int? difficulty,
    String? category,
    @JsonKey(name: 'category_ids') List<String>? categoryIds,
    @JsonKey(name: 'additional_fields') Map<String, dynamic>? additionalFields,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'beamer_file', includeToJson: false)
    @BeamerFileConverter()
    BeamerFile? beamerFile,
  });

  $BeamerFileCopyWith<$Res>? get beamerFile;
}

/// @nodoc
class _$SongCopyWithImpl<$Res, $Val extends Song>
    implements $SongCopyWith<$Res> {
  _$SongCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Song
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? name = null,
    Object? number = freezed,
    Object? prefix = freezed,
    Object? withChoir = null,
    Object? withSolo = null,
    Object? lastSung = freezed,
    Object? nextPlanned = freezed,
    Object? link = freezed,
    Object? conductor = freezed,
    Object? composer = freezed,
    Object? legacyId = freezed,
    Object? instrumentIds = freezed,
    Object? files = freezed,
    Object? difficulty = freezed,
    Object? category = freezed,
    Object? categoryIds = freezed,
    Object? additionalFields = freezed,
    Object? createdAt = freezed,
    Object? beamerFile = freezed,
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
            withChoir:
                null == withChoir
                    ? _value.withChoir
                    : withChoir // ignore: cast_nullable_to_non_nullable
                        as bool,
            withSolo:
                null == withSolo
                    ? _value.withSolo
                    : withSolo // ignore: cast_nullable_to_non_nullable
                        as bool,
            lastSung:
                freezed == lastSung
                    ? _value.lastSung
                    : lastSung // ignore: cast_nullable_to_non_nullable
                        as String?,
            nextPlanned:
                freezed == nextPlanned
                    ? _value.nextPlanned
                    : nextPlanned // ignore: cast_nullable_to_non_nullable
                        as String?,
            link:
                freezed == link
                    ? _value.link
                    : link // ignore: cast_nullable_to_non_nullable
                        as String?,
            conductor:
                freezed == conductor
                    ? _value.conductor
                    : conductor // ignore: cast_nullable_to_non_nullable
                        as String?,
            composer:
                freezed == composer
                    ? _value.composer
                    : composer // ignore: cast_nullable_to_non_nullable
                        as String?,
            legacyId:
                freezed == legacyId
                    ? _value.legacyId
                    : legacyId // ignore: cast_nullable_to_non_nullable
                        as int?,
            instrumentIds:
                freezed == instrumentIds
                    ? _value.instrumentIds
                    : instrumentIds // ignore: cast_nullable_to_non_nullable
                        as List<int>?,
            files:
                freezed == files
                    ? _value.files
                    : files // ignore: cast_nullable_to_non_nullable
                        as List<SongFile>?,
            difficulty:
                freezed == difficulty
                    ? _value.difficulty
                    : difficulty // ignore: cast_nullable_to_non_nullable
                        as int?,
            category:
                freezed == category
                    ? _value.category
                    : category // ignore: cast_nullable_to_non_nullable
                        as String?,
            categoryIds:
                freezed == categoryIds
                    ? _value.categoryIds
                    : categoryIds // ignore: cast_nullable_to_non_nullable
                        as List<String>?,
            additionalFields:
                freezed == additionalFields
                    ? _value.additionalFields
                    : additionalFields // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            beamerFile:
                freezed == beamerFile
                    ? _value.beamerFile
                    : beamerFile // ignore: cast_nullable_to_non_nullable
                        as BeamerFile?,
          )
          as $Val,
    );
  }

  /// Create a copy of Song
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
abstract class _$$SongImplCopyWith<$Res> implements $SongCopyWith<$Res> {
  factory _$$SongImplCopyWith(
    _$SongImpl value,
    $Res Function(_$SongImpl) then,
  ) = __$$SongImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    int? tenantId,
    String name,
    int? number,
    String? prefix,
    bool withChoir,
    bool withSolo,
    @JsonKey(includeToJson: false) String? lastSung,
    @JsonKey(includeToJson: false) String? nextPlanned,
    String? link,
    @JsonKey(includeToJson: false) String? conductor,
    String? composer,
    int? legacyId,
    @JsonKey(name: 'instrument_ids') List<int>? instrumentIds,
    List<SongFile>? files,
    int? difficulty,
    String? category,
    @JsonKey(name: 'category_ids') List<String>? categoryIds,
    @JsonKey(name: 'additional_fields') Map<String, dynamic>? additionalFields,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'beamer_file', includeToJson: false)
    @BeamerFileConverter()
    BeamerFile? beamerFile,
  });

  @override
  $BeamerFileCopyWith<$Res>? get beamerFile;
}

/// @nodoc
class __$$SongImplCopyWithImpl<$Res>
    extends _$SongCopyWithImpl<$Res, _$SongImpl>
    implements _$$SongImplCopyWith<$Res> {
  __$$SongImplCopyWithImpl(_$SongImpl _value, $Res Function(_$SongImpl) _then)
    : super(_value, _then);

  /// Create a copy of Song
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? name = null,
    Object? number = freezed,
    Object? prefix = freezed,
    Object? withChoir = null,
    Object? withSolo = null,
    Object? lastSung = freezed,
    Object? nextPlanned = freezed,
    Object? link = freezed,
    Object? conductor = freezed,
    Object? composer = freezed,
    Object? legacyId = freezed,
    Object? instrumentIds = freezed,
    Object? files = freezed,
    Object? difficulty = freezed,
    Object? category = freezed,
    Object? categoryIds = freezed,
    Object? additionalFields = freezed,
    Object? createdAt = freezed,
    Object? beamerFile = freezed,
  }) {
    return _then(
      _$SongImpl(
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
        withChoir:
            null == withChoir
                ? _value.withChoir
                : withChoir // ignore: cast_nullable_to_non_nullable
                    as bool,
        withSolo:
            null == withSolo
                ? _value.withSolo
                : withSolo // ignore: cast_nullable_to_non_nullable
                    as bool,
        lastSung:
            freezed == lastSung
                ? _value.lastSung
                : lastSung // ignore: cast_nullable_to_non_nullable
                    as String?,
        nextPlanned:
            freezed == nextPlanned
                ? _value.nextPlanned
                : nextPlanned // ignore: cast_nullable_to_non_nullable
                    as String?,
        link:
            freezed == link
                ? _value.link
                : link // ignore: cast_nullable_to_non_nullable
                    as String?,
        conductor:
            freezed == conductor
                ? _value.conductor
                : conductor // ignore: cast_nullable_to_non_nullable
                    as String?,
        composer:
            freezed == composer
                ? _value.composer
                : composer // ignore: cast_nullable_to_non_nullable
                    as String?,
        legacyId:
            freezed == legacyId
                ? _value.legacyId
                : legacyId // ignore: cast_nullable_to_non_nullable
                    as int?,
        instrumentIds:
            freezed == instrumentIds
                ? _value._instrumentIds
                : instrumentIds // ignore: cast_nullable_to_non_nullable
                    as List<int>?,
        files:
            freezed == files
                ? _value._files
                : files // ignore: cast_nullable_to_non_nullable
                    as List<SongFile>?,
        difficulty:
            freezed == difficulty
                ? _value.difficulty
                : difficulty // ignore: cast_nullable_to_non_nullable
                    as int?,
        category:
            freezed == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                    as String?,
        categoryIds:
            freezed == categoryIds
                ? _value._categoryIds
                : categoryIds // ignore: cast_nullable_to_non_nullable
                    as List<String>?,
        additionalFields:
            freezed == additionalFields
                ? _value._additionalFields
                : additionalFields // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
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
@JsonSerializable()
class _$SongImpl implements _Song {
  const _$SongImpl({
    this.id,
    this.tenantId,
    required this.name,
    this.number,
    this.prefix,
    this.withChoir = false,
    this.withSolo = false,
    @JsonKey(includeToJson: false) this.lastSung,
    @JsonKey(includeToJson: false) this.nextPlanned,
    this.link,
    @JsonKey(includeToJson: false) this.conductor,
    this.composer,
    this.legacyId,
    @JsonKey(name: 'instrument_ids') final List<int>? instrumentIds,
    final List<SongFile>? files,
    this.difficulty,
    this.category,
    @JsonKey(name: 'category_ids') final List<String>? categoryIds,
    @JsonKey(name: 'additional_fields')
    final Map<String, dynamic>? additionalFields,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'beamer_file', includeToJson: false)
    @BeamerFileConverter()
    this.beamerFile,
  }) : _instrumentIds = instrumentIds,
       _files = files,
       _categoryIds = categoryIds,
       _additionalFields = additionalFields;

  factory _$SongImpl.fromJson(Map<String, dynamic> json) =>
      _$$SongImplFromJson(json);

  @override
  final int? id;
  @override
  final int? tenantId;
  @override
  final String name;
  @override
  final int? number;
  @override
  final String? prefix;
  @override
  @JsonKey()
  final bool withChoir;
  @override
  @JsonKey()
  final bool withSolo;

  /// Computed client-side from history (last past entry). Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  final String? lastSung;

  /// Computed client-side: next planned (future) history entry. Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  final String? nextPlanned;
  @override
  final String? link;

  /// Computed client-side: conductor of [lastSung]. Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  final String? conductor;
  @override
  final String? composer;
  @override
  final int? legacyId;
  final List<int>? _instrumentIds;
  @override
  @JsonKey(name: 'instrument_ids')
  List<int>? get instrumentIds {
    final value = _instrumentIds;
    if (value == null) return null;
    if (_instrumentIds is EqualUnmodifiableListView) return _instrumentIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<SongFile>? _files;
  @override
  List<SongFile>? get files {
    final value = _files;
    if (value == null) return null;
    if (_files is EqualUnmodifiableListView) return _files;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final int? difficulty;

  /// Legacy single category (superseded by [categoryIds])
  @override
  final String? category;

  /// Song category ids (uuid[] column `category_ids`)
  final List<String>? _categoryIds;

  /// Song category ids (uuid[] column `category_ids`)
  @override
  @JsonKey(name: 'category_ids')
  List<String>? get categoryIds {
    final value = _categoryIds;
    if (value == null) return null;
    if (_categoryIds is EqualUnmodifiableListView) return _categoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Values of the tenant's `song_additional_fields`
  final Map<String, dynamic>? _additionalFields;

  /// Values of the tenant's `song_additional_fields`
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
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  /// SongBeamer file of the Werk, written by the Gemeinde App only
  /// (never sent back by Attendix).
  @override
  @JsonKey(name: 'beamer_file', includeToJson: false)
  @BeamerFileConverter()
  final BeamerFile? beamerFile;

  @override
  String toString() {
    return 'Song(id: $id, tenantId: $tenantId, name: $name, number: $number, prefix: $prefix, withChoir: $withChoir, withSolo: $withSolo, lastSung: $lastSung, nextPlanned: $nextPlanned, link: $link, conductor: $conductor, composer: $composer, legacyId: $legacyId, instrumentIds: $instrumentIds, files: $files, difficulty: $difficulty, category: $category, categoryIds: $categoryIds, additionalFields: $additionalFields, createdAt: $createdAt, beamerFile: $beamerFile)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SongImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.number, number) || other.number == number) &&
            (identical(other.prefix, prefix) || other.prefix == prefix) &&
            (identical(other.withChoir, withChoir) ||
                other.withChoir == withChoir) &&
            (identical(other.withSolo, withSolo) ||
                other.withSolo == withSolo) &&
            (identical(other.lastSung, lastSung) ||
                other.lastSung == lastSung) &&
            (identical(other.nextPlanned, nextPlanned) ||
                other.nextPlanned == nextPlanned) &&
            (identical(other.link, link) || other.link == link) &&
            (identical(other.conductor, conductor) ||
                other.conductor == conductor) &&
            (identical(other.composer, composer) ||
                other.composer == composer) &&
            (identical(other.legacyId, legacyId) ||
                other.legacyId == legacyId) &&
            const DeepCollectionEquality().equals(
              other._instrumentIds,
              _instrumentIds,
            ) &&
            const DeepCollectionEquality().equals(other._files, _files) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(
              other._categoryIds,
              _categoryIds,
            ) &&
            const DeepCollectionEquality().equals(
              other._additionalFields,
              _additionalFields,
            ) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.beamerFile, beamerFile) ||
                other.beamerFile == beamerFile));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    tenantId,
    name,
    number,
    prefix,
    withChoir,
    withSolo,
    lastSung,
    nextPlanned,
    link,
    conductor,
    composer,
    legacyId,
    const DeepCollectionEquality().hash(_instrumentIds),
    const DeepCollectionEquality().hash(_files),
    difficulty,
    category,
    const DeepCollectionEquality().hash(_categoryIds),
    const DeepCollectionEquality().hash(_additionalFields),
    createdAt,
    beamerFile,
  ]);

  /// Create a copy of Song
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SongImplCopyWith<_$SongImpl> get copyWith =>
      __$$SongImplCopyWithImpl<_$SongImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SongImplToJson(this);
  }
}

abstract class _Song implements Song {
  const factory _Song({
    final int? id,
    final int? tenantId,
    required final String name,
    final int? number,
    final String? prefix,
    final bool withChoir,
    final bool withSolo,
    @JsonKey(includeToJson: false) final String? lastSung,
    @JsonKey(includeToJson: false) final String? nextPlanned,
    final String? link,
    @JsonKey(includeToJson: false) final String? conductor,
    final String? composer,
    final int? legacyId,
    @JsonKey(name: 'instrument_ids') final List<int>? instrumentIds,
    final List<SongFile>? files,
    final int? difficulty,
    final String? category,
    @JsonKey(name: 'category_ids') final List<String>? categoryIds,
    @JsonKey(name: 'additional_fields')
    final Map<String, dynamic>? additionalFields,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'beamer_file', includeToJson: false)
    @BeamerFileConverter()
    final BeamerFile? beamerFile,
  }) = _$SongImpl;

  factory _Song.fromJson(Map<String, dynamic> json) = _$SongImpl.fromJson;

  @override
  int? get id;
  @override
  int? get tenantId;
  @override
  String get name;
  @override
  int? get number;
  @override
  String? get prefix;
  @override
  bool get withChoir;
  @override
  bool get withSolo;

  /// Computed client-side from history (last past entry). Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  String? get lastSung;

  /// Computed client-side: next planned (future) history entry. Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  String? get nextPlanned;
  @override
  String? get link;

  /// Computed client-side: conductor of [lastSung]. Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  String? get conductor;
  @override
  String? get composer;
  @override
  int? get legacyId;
  @override
  @JsonKey(name: 'instrument_ids')
  List<int>? get instrumentIds;
  @override
  List<SongFile>? get files;
  @override
  int? get difficulty;

  /// Legacy single category (superseded by [categoryIds])
  @override
  String? get category;

  /// Song category ids (uuid[] column `category_ids`)
  @override
  @JsonKey(name: 'category_ids')
  List<String>? get categoryIds;

  /// Values of the tenant's `song_additional_fields`
  @override
  @JsonKey(name: 'additional_fields')
  Map<String, dynamic>? get additionalFields;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// SongBeamer file of the Werk, written by the Gemeinde App only
  /// (never sent back by Attendix).
  @override
  @JsonKey(name: 'beamer_file', includeToJson: false)
  @BeamerFileConverter()
  BeamerFile? get beamerFile;

  /// Create a copy of Song
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SongImplCopyWith<_$SongImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SongFile _$SongFileFromJson(Map<String, dynamic> json) {
  return _SongFile.fromJson(json);
}

/// @nodoc
mixin _$SongFile {
  String? get storageName => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String? get createdAt => throw _privateConstructorUsedError;
  String get fileName => throw _privateConstructorUsedError;
  String get fileType => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  int? get instrumentId => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// Serializes this SongFile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SongFile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SongFileCopyWith<SongFile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SongFileCopyWith<$Res> {
  factory $SongFileCopyWith(SongFile value, $Res Function(SongFile) then) =
      _$SongFileCopyWithImpl<$Res, SongFile>;
  @useResult
  $Res call({
    String? storageName,
    @JsonKey(name: 'created_at') String? createdAt,
    String fileName,
    String fileType,
    String url,
    int? instrumentId,
    String? note,
  });
}

/// @nodoc
class _$SongFileCopyWithImpl<$Res, $Val extends SongFile>
    implements $SongFileCopyWith<$Res> {
  _$SongFileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SongFile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? storageName = freezed,
    Object? createdAt = freezed,
    Object? fileName = null,
    Object? fileType = null,
    Object? url = null,
    Object? instrumentId = freezed,
    Object? note = freezed,
  }) {
    return _then(
      _value.copyWith(
            storageName:
                freezed == storageName
                    ? _value.storageName
                    : storageName // ignore: cast_nullable_to_non_nullable
                        as String?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as String?,
            fileName:
                null == fileName
                    ? _value.fileName
                    : fileName // ignore: cast_nullable_to_non_nullable
                        as String,
            fileType:
                null == fileType
                    ? _value.fileType
                    : fileType // ignore: cast_nullable_to_non_nullable
                        as String,
            url:
                null == url
                    ? _value.url
                    : url // ignore: cast_nullable_to_non_nullable
                        as String,
            instrumentId:
                freezed == instrumentId
                    ? _value.instrumentId
                    : instrumentId // ignore: cast_nullable_to_non_nullable
                        as int?,
            note:
                freezed == note
                    ? _value.note
                    : note // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SongFileImplCopyWith<$Res>
    implements $SongFileCopyWith<$Res> {
  factory _$$SongFileImplCopyWith(
    _$SongFileImpl value,
    $Res Function(_$SongFileImpl) then,
  ) = __$$SongFileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? storageName,
    @JsonKey(name: 'created_at') String? createdAt,
    String fileName,
    String fileType,
    String url,
    int? instrumentId,
    String? note,
  });
}

/// @nodoc
class __$$SongFileImplCopyWithImpl<$Res>
    extends _$SongFileCopyWithImpl<$Res, _$SongFileImpl>
    implements _$$SongFileImplCopyWith<$Res> {
  __$$SongFileImplCopyWithImpl(
    _$SongFileImpl _value,
    $Res Function(_$SongFileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SongFile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? storageName = freezed,
    Object? createdAt = freezed,
    Object? fileName = null,
    Object? fileType = null,
    Object? url = null,
    Object? instrumentId = freezed,
    Object? note = freezed,
  }) {
    return _then(
      _$SongFileImpl(
        storageName:
            freezed == storageName
                ? _value.storageName
                : storageName // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as String?,
        fileName:
            null == fileName
                ? _value.fileName
                : fileName // ignore: cast_nullable_to_non_nullable
                    as String,
        fileType:
            null == fileType
                ? _value.fileType
                : fileType // ignore: cast_nullable_to_non_nullable
                    as String,
        url:
            null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                    as String,
        instrumentId:
            freezed == instrumentId
                ? _value.instrumentId
                : instrumentId // ignore: cast_nullable_to_non_nullable
                    as int?,
        note:
            freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SongFileImpl implements _SongFile {
  const _$SongFileImpl({
    this.storageName,
    @JsonKey(name: 'created_at') this.createdAt,
    required this.fileName,
    required this.fileType,
    required this.url,
    this.instrumentId,
    this.note,
  });

  factory _$SongFileImpl.fromJson(Map<String, dynamic> json) =>
      _$$SongFileImplFromJson(json);

  @override
  final String? storageName;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @override
  final String fileName;
  @override
  final String fileType;
  @override
  final String url;
  @override
  final int? instrumentId;
  @override
  final String? note;

  @override
  String toString() {
    return 'SongFile(storageName: $storageName, createdAt: $createdAt, fileName: $fileName, fileType: $fileType, url: $url, instrumentId: $instrumentId, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SongFileImpl &&
            (identical(other.storageName, storageName) ||
                other.storageName == storageName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.fileType, fileType) ||
                other.fileType == fileType) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.instrumentId, instrumentId) ||
                other.instrumentId == instrumentId) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    storageName,
    createdAt,
    fileName,
    fileType,
    url,
    instrumentId,
    note,
  );

  /// Create a copy of SongFile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SongFileImplCopyWith<_$SongFileImpl> get copyWith =>
      __$$SongFileImplCopyWithImpl<_$SongFileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SongFileImplToJson(this);
  }
}

abstract class _SongFile implements SongFile {
  const factory _SongFile({
    final String? storageName,
    @JsonKey(name: 'created_at') final String? createdAt,
    required final String fileName,
    required final String fileType,
    required final String url,
    final int? instrumentId,
    final String? note,
  }) = _$SongFileImpl;

  factory _SongFile.fromJson(Map<String, dynamic> json) =
      _$SongFileImpl.fromJson;

  @override
  String? get storageName;
  @override
  @JsonKey(name: 'created_at')
  String? get createdAt;
  @override
  String get fileName;
  @override
  String get fileType;
  @override
  String get url;
  @override
  int? get instrumentId;
  @override
  String? get note;

  /// Create a copy of SongFile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SongFileImplCopyWith<_$SongFileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SongHistory _$SongHistoryFromJson(Map<String, dynamic> json) {
  return _SongHistory.fromJson(json);
}

/// @nodoc
mixin _$SongHistory {
  int? get id => throw _privateConstructorUsedError;
  int? get tenantId => throw _privateConstructorUsedError;

  /// DB column is `songId` (camelCase, see Ionic pickHistoryFields)
  @JsonKey(name: 'songId')
  int? get songId => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_id')
  int? get attendanceId => throw _privateConstructorUsedError;
  @JsonKey(name: 'person_id')
  int? get personId => throw _privateConstructorUsedError;
  String? get date => throw _privateConstructorUsedError;

  /// Computed client-side (conductor person name or otherConductor). Not a DB column.
  @JsonKey(includeToJson: false)
  String? get conductorName => throw _privateConstructorUsedError;
  String? get otherConductor => throw _privateConstructorUsedError;
  int? get count => throw _privateConstructorUsedError;
  bool? get visible => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Computed client-side: attendance typeInfo or type name. Not a DB column.
  @JsonKey(includeToJson: false)
  String? get typeTitle => throw _privateConstructorUsedError;

  /// Computed client-side: date of the linked attendance. Not a DB column.
  @JsonKey(includeToJson: false)
  String? get attendanceDate => throw _privateConstructorUsedError;
  @JsonKey(includeToJson: false)
  Song? get song => throw _privateConstructorUsedError;

  /// Serializes this SongHistory to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SongHistory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SongHistoryCopyWith<SongHistory> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SongHistoryCopyWith<$Res> {
  factory $SongHistoryCopyWith(
    SongHistory value,
    $Res Function(SongHistory) then,
  ) = _$SongHistoryCopyWithImpl<$Res, SongHistory>;
  @useResult
  $Res call({
    int? id,
    int? tenantId,
    @JsonKey(name: 'songId') int? songId,
    @JsonKey(name: 'attendance_id') int? attendanceId,
    @JsonKey(name: 'person_id') int? personId,
    String? date,
    @JsonKey(includeToJson: false) String? conductorName,
    String? otherConductor,
    int? count,
    bool? visible,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(includeToJson: false) String? typeTitle,
    @JsonKey(includeToJson: false) String? attendanceDate,
    @JsonKey(includeToJson: false) Song? song,
  });

  $SongCopyWith<$Res>? get song;
}

/// @nodoc
class _$SongHistoryCopyWithImpl<$Res, $Val extends SongHistory>
    implements $SongHistoryCopyWith<$Res> {
  _$SongHistoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SongHistory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? songId = freezed,
    Object? attendanceId = freezed,
    Object? personId = freezed,
    Object? date = freezed,
    Object? conductorName = freezed,
    Object? otherConductor = freezed,
    Object? count = freezed,
    Object? visible = freezed,
    Object? createdAt = freezed,
    Object? typeTitle = freezed,
    Object? attendanceDate = freezed,
    Object? song = freezed,
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
            songId:
                freezed == songId
                    ? _value.songId
                    : songId // ignore: cast_nullable_to_non_nullable
                        as int?,
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
            date:
                freezed == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as String?,
            conductorName:
                freezed == conductorName
                    ? _value.conductorName
                    : conductorName // ignore: cast_nullable_to_non_nullable
                        as String?,
            otherConductor:
                freezed == otherConductor
                    ? _value.otherConductor
                    : otherConductor // ignore: cast_nullable_to_non_nullable
                        as String?,
            count:
                freezed == count
                    ? _value.count
                    : count // ignore: cast_nullable_to_non_nullable
                        as int?,
            visible:
                freezed == visible
                    ? _value.visible
                    : visible // ignore: cast_nullable_to_non_nullable
                        as bool?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            typeTitle:
                freezed == typeTitle
                    ? _value.typeTitle
                    : typeTitle // ignore: cast_nullable_to_non_nullable
                        as String?,
            attendanceDate:
                freezed == attendanceDate
                    ? _value.attendanceDate
                    : attendanceDate // ignore: cast_nullable_to_non_nullable
                        as String?,
            song:
                freezed == song
                    ? _value.song
                    : song // ignore: cast_nullable_to_non_nullable
                        as Song?,
          )
          as $Val,
    );
  }

  /// Create a copy of SongHistory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SongCopyWith<$Res>? get song {
    if (_value.song == null) {
      return null;
    }

    return $SongCopyWith<$Res>(_value.song!, (value) {
      return _then(_value.copyWith(song: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SongHistoryImplCopyWith<$Res>
    implements $SongHistoryCopyWith<$Res> {
  factory _$$SongHistoryImplCopyWith(
    _$SongHistoryImpl value,
    $Res Function(_$SongHistoryImpl) then,
  ) = __$$SongHistoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    int? tenantId,
    @JsonKey(name: 'songId') int? songId,
    @JsonKey(name: 'attendance_id') int? attendanceId,
    @JsonKey(name: 'person_id') int? personId,
    String? date,
    @JsonKey(includeToJson: false) String? conductorName,
    String? otherConductor,
    int? count,
    bool? visible,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(includeToJson: false) String? typeTitle,
    @JsonKey(includeToJson: false) String? attendanceDate,
    @JsonKey(includeToJson: false) Song? song,
  });

  @override
  $SongCopyWith<$Res>? get song;
}

/// @nodoc
class __$$SongHistoryImplCopyWithImpl<$Res>
    extends _$SongHistoryCopyWithImpl<$Res, _$SongHistoryImpl>
    implements _$$SongHistoryImplCopyWith<$Res> {
  __$$SongHistoryImplCopyWithImpl(
    _$SongHistoryImpl _value,
    $Res Function(_$SongHistoryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SongHistory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? songId = freezed,
    Object? attendanceId = freezed,
    Object? personId = freezed,
    Object? date = freezed,
    Object? conductorName = freezed,
    Object? otherConductor = freezed,
    Object? count = freezed,
    Object? visible = freezed,
    Object? createdAt = freezed,
    Object? typeTitle = freezed,
    Object? attendanceDate = freezed,
    Object? song = freezed,
  }) {
    return _then(
      _$SongHistoryImpl(
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
        songId:
            freezed == songId
                ? _value.songId
                : songId // ignore: cast_nullable_to_non_nullable
                    as int?,
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
        date:
            freezed == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as String?,
        conductorName:
            freezed == conductorName
                ? _value.conductorName
                : conductorName // ignore: cast_nullable_to_non_nullable
                    as String?,
        otherConductor:
            freezed == otherConductor
                ? _value.otherConductor
                : otherConductor // ignore: cast_nullable_to_non_nullable
                    as String?,
        count:
            freezed == count
                ? _value.count
                : count // ignore: cast_nullable_to_non_nullable
                    as int?,
        visible:
            freezed == visible
                ? _value.visible
                : visible // ignore: cast_nullable_to_non_nullable
                    as bool?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        typeTitle:
            freezed == typeTitle
                ? _value.typeTitle
                : typeTitle // ignore: cast_nullable_to_non_nullable
                    as String?,
        attendanceDate:
            freezed == attendanceDate
                ? _value.attendanceDate
                : attendanceDate // ignore: cast_nullable_to_non_nullable
                    as String?,
        song:
            freezed == song
                ? _value.song
                : song // ignore: cast_nullable_to_non_nullable
                    as Song?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SongHistoryImpl implements _SongHistory {
  const _$SongHistoryImpl({
    this.id,
    this.tenantId,
    @JsonKey(name: 'songId') this.songId,
    @JsonKey(name: 'attendance_id') this.attendanceId,
    @JsonKey(name: 'person_id') this.personId,
    this.date,
    @JsonKey(includeToJson: false) this.conductorName,
    this.otherConductor,
    this.count,
    this.visible,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(includeToJson: false) this.typeTitle,
    @JsonKey(includeToJson: false) this.attendanceDate,
    @JsonKey(includeToJson: false) this.song,
  });

  factory _$SongHistoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$SongHistoryImplFromJson(json);

  @override
  final int? id;
  @override
  final int? tenantId;

  /// DB column is `songId` (camelCase, see Ionic pickHistoryFields)
  @override
  @JsonKey(name: 'songId')
  final int? songId;
  @override
  @JsonKey(name: 'attendance_id')
  final int? attendanceId;
  @override
  @JsonKey(name: 'person_id')
  final int? personId;
  @override
  final String? date;

  /// Computed client-side (conductor person name or otherConductor). Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  final String? conductorName;
  @override
  final String? otherConductor;
  @override
  final int? count;
  @override
  final bool? visible;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  /// Computed client-side: attendance typeInfo or type name. Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  final String? typeTitle;

  /// Computed client-side: date of the linked attendance. Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  final String? attendanceDate;
  @override
  @JsonKey(includeToJson: false)
  final Song? song;

  @override
  String toString() {
    return 'SongHistory(id: $id, tenantId: $tenantId, songId: $songId, attendanceId: $attendanceId, personId: $personId, date: $date, conductorName: $conductorName, otherConductor: $otherConductor, count: $count, visible: $visible, createdAt: $createdAt, typeTitle: $typeTitle, attendanceDate: $attendanceDate, song: $song)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SongHistoryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.songId, songId) || other.songId == songId) &&
            (identical(other.attendanceId, attendanceId) ||
                other.attendanceId == attendanceId) &&
            (identical(other.personId, personId) ||
                other.personId == personId) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.conductorName, conductorName) ||
                other.conductorName == conductorName) &&
            (identical(other.otherConductor, otherConductor) ||
                other.otherConductor == otherConductor) &&
            (identical(other.count, count) || other.count == count) &&
            (identical(other.visible, visible) || other.visible == visible) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.typeTitle, typeTitle) ||
                other.typeTitle == typeTitle) &&
            (identical(other.attendanceDate, attendanceDate) ||
                other.attendanceDate == attendanceDate) &&
            (identical(other.song, song) || other.song == song));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tenantId,
    songId,
    attendanceId,
    personId,
    date,
    conductorName,
    otherConductor,
    count,
    visible,
    createdAt,
    typeTitle,
    attendanceDate,
    song,
  );

  /// Create a copy of SongHistory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SongHistoryImplCopyWith<_$SongHistoryImpl> get copyWith =>
      __$$SongHistoryImplCopyWithImpl<_$SongHistoryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SongHistoryImplToJson(this);
  }
}

abstract class _SongHistory implements SongHistory {
  const factory _SongHistory({
    final int? id,
    final int? tenantId,
    @JsonKey(name: 'songId') final int? songId,
    @JsonKey(name: 'attendance_id') final int? attendanceId,
    @JsonKey(name: 'person_id') final int? personId,
    final String? date,
    @JsonKey(includeToJson: false) final String? conductorName,
    final String? otherConductor,
    final int? count,
    final bool? visible,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(includeToJson: false) final String? typeTitle,
    @JsonKey(includeToJson: false) final String? attendanceDate,
    @JsonKey(includeToJson: false) final Song? song,
  }) = _$SongHistoryImpl;

  factory _SongHistory.fromJson(Map<String, dynamic> json) =
      _$SongHistoryImpl.fromJson;

  @override
  int? get id;
  @override
  int? get tenantId;

  /// DB column is `songId` (camelCase, see Ionic pickHistoryFields)
  @override
  @JsonKey(name: 'songId')
  int? get songId;
  @override
  @JsonKey(name: 'attendance_id')
  int? get attendanceId;
  @override
  @JsonKey(name: 'person_id')
  int? get personId;
  @override
  String? get date;

  /// Computed client-side (conductor person name or otherConductor). Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  String? get conductorName;
  @override
  String? get otherConductor;
  @override
  int? get count;
  @override
  bool? get visible;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Computed client-side: attendance typeInfo or type name. Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  String? get typeTitle;

  /// Computed client-side: date of the linked attendance. Not a DB column.
  @override
  @JsonKey(includeToJson: false)
  String? get attendanceDate;
  @override
  @JsonKey(includeToJson: false)
  Song? get song;

  /// Create a copy of SongHistory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SongHistoryImplCopyWith<_$SongHistoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SongCategory _$SongCategoryFromJson(Map<String, dynamic> json) {
  return _SongCategory.fromJson(json);
}

/// @nodoc
mixin _$SongCategory {
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  int? get tenantId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get index => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this SongCategory to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SongCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SongCategoryCopyWith<SongCategory> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SongCategoryCopyWith<$Res> {
  factory $SongCategoryCopyWith(
    SongCategory value,
    $Res Function(SongCategory) then,
  ) = _$SongCategoryCopyWithImpl<$Res, SongCategory>;
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'tenant_id') int? tenantId,
    String name,
    int index,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class _$SongCategoryCopyWithImpl<$Res, $Val extends SongCategory>
    implements $SongCategoryCopyWith<$Res> {
  _$SongCategoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SongCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? name = null,
    Object? index = null,
    Object? createdAt = freezed,
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
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            index:
                null == index
                    ? _value.index
                    : index // ignore: cast_nullable_to_non_nullable
                        as int,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SongCategoryImplCopyWith<$Res>
    implements $SongCategoryCopyWith<$Res> {
  factory _$$SongCategoryImplCopyWith(
    _$SongCategoryImpl value,
    $Res Function(_$SongCategoryImpl) then,
  ) = __$$SongCategoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? id,
    @JsonKey(name: 'tenant_id') int? tenantId,
    String name,
    int index,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class __$$SongCategoryImplCopyWithImpl<$Res>
    extends _$SongCategoryCopyWithImpl<$Res, _$SongCategoryImpl>
    implements _$$SongCategoryImplCopyWith<$Res> {
  __$$SongCategoryImplCopyWithImpl(
    _$SongCategoryImpl _value,
    $Res Function(_$SongCategoryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SongCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? name = null,
    Object? index = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$SongCategoryImpl(
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
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        index:
            null == index
                ? _value.index
                : index // ignore: cast_nullable_to_non_nullable
                    as int,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SongCategoryImpl implements _SongCategory {
  const _$SongCategoryImpl({
    this.id,
    @JsonKey(name: 'tenant_id') this.tenantId,
    required this.name,
    this.index = 0,
    @JsonKey(name: 'created_at') this.createdAt,
  });

  factory _$SongCategoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$SongCategoryImplFromJson(json);

  @override
  final String? id;
  @override
  @JsonKey(name: 'tenant_id')
  final int? tenantId;
  @override
  final String name;
  @override
  @JsonKey()
  final int index;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'SongCategory(id: $id, tenantId: $tenantId, name: $name, index: $index, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SongCategoryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, tenantId, name, index, createdAt);

  /// Create a copy of SongCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SongCategoryImplCopyWith<_$SongCategoryImpl> get copyWith =>
      __$$SongCategoryImplCopyWithImpl<_$SongCategoryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SongCategoryImplToJson(this);
  }
}

abstract class _SongCategory implements SongCategory {
  const factory _SongCategory({
    final String? id,
    @JsonKey(name: 'tenant_id') final int? tenantId,
    required final String name,
    final int index,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
  }) = _$SongCategoryImpl;

  factory _SongCategory.fromJson(Map<String, dynamic> json) =
      _$SongCategoryImpl.fromJson;

  @override
  String? get id;
  @override
  @JsonKey(name: 'tenant_id')
  int? get tenantId;
  @override
  String get name;
  @override
  int get index;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of SongCategory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SongCategoryImplCopyWith<_$SongCategoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
