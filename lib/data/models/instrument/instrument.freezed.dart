// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'instrument.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Instrument _$InstrumentFromJson(Map<String, dynamic> json) {
  return _Instrument.fromJson(json);
}

/// @nodoc
mixin _$Instrument {
  int? get id => throw _privateConstructorUsedError;
  int? get tenantId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get shortName => throw _privateConstructorUsedError;
  String? get color => throw _privateConstructorUsedError;
  bool get isSection => throw _privateConstructorUsedError;
  int? get sectionIndex => throw _privateConstructorUsedError;
  int? get parentId => throw _privateConstructorUsedError;
  int? get legacyId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError; // Fields from Ionic that were missing
  int? get category => throw _privateConstructorUsedError;
  List<String>? get clefs => throw _privateConstructorUsedError;
  bool get maingroup => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  String? get range => throw _privateConstructorUsedError;
  String? get synonyms => throw _privateConstructorUsedError;
  String? get tuning => throw _privateConstructorUsedError;
  @JsonKey(name: 'sort_order')
  int? get sortOrder => throw _privateConstructorUsedError;

  /// Serializes this Instrument to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Instrument
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InstrumentCopyWith<Instrument> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InstrumentCopyWith<$Res> {
  factory $InstrumentCopyWith(
    Instrument value,
    $Res Function(Instrument) then,
  ) = _$InstrumentCopyWithImpl<$Res, Instrument>;
  @useResult
  $Res call({
    int? id,
    int? tenantId,
    String name,
    String? shortName,
    String? color,
    bool isSection,
    int? sectionIndex,
    int? parentId,
    int? legacyId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    int? category,
    List<String>? clefs,
    bool maingroup,
    String? notes,
    String? range,
    String? synonyms,
    String? tuning,
    @JsonKey(name: 'sort_order') int? sortOrder,
  });
}

/// @nodoc
class _$InstrumentCopyWithImpl<$Res, $Val extends Instrument>
    implements $InstrumentCopyWith<$Res> {
  _$InstrumentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Instrument
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? name = null,
    Object? shortName = freezed,
    Object? color = freezed,
    Object? isSection = null,
    Object? sectionIndex = freezed,
    Object? parentId = freezed,
    Object? legacyId = freezed,
    Object? createdAt = freezed,
    Object? category = freezed,
    Object? clefs = freezed,
    Object? maingroup = null,
    Object? notes = freezed,
    Object? range = freezed,
    Object? synonyms = freezed,
    Object? tuning = freezed,
    Object? sortOrder = freezed,
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
            shortName:
                freezed == shortName
                    ? _value.shortName
                    : shortName // ignore: cast_nullable_to_non_nullable
                        as String?,
            color:
                freezed == color
                    ? _value.color
                    : color // ignore: cast_nullable_to_non_nullable
                        as String?,
            isSection:
                null == isSection
                    ? _value.isSection
                    : isSection // ignore: cast_nullable_to_non_nullable
                        as bool,
            sectionIndex:
                freezed == sectionIndex
                    ? _value.sectionIndex
                    : sectionIndex // ignore: cast_nullable_to_non_nullable
                        as int?,
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
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            category:
                freezed == category
                    ? _value.category
                    : category // ignore: cast_nullable_to_non_nullable
                        as int?,
            clefs:
                freezed == clefs
                    ? _value.clefs
                    : clefs // ignore: cast_nullable_to_non_nullable
                        as List<String>?,
            maingroup:
                null == maingroup
                    ? _value.maingroup
                    : maingroup // ignore: cast_nullable_to_non_nullable
                        as bool,
            notes:
                freezed == notes
                    ? _value.notes
                    : notes // ignore: cast_nullable_to_non_nullable
                        as String?,
            range:
                freezed == range
                    ? _value.range
                    : range // ignore: cast_nullable_to_non_nullable
                        as String?,
            synonyms:
                freezed == synonyms
                    ? _value.synonyms
                    : synonyms // ignore: cast_nullable_to_non_nullable
                        as String?,
            tuning:
                freezed == tuning
                    ? _value.tuning
                    : tuning // ignore: cast_nullable_to_non_nullable
                        as String?,
            sortOrder:
                freezed == sortOrder
                    ? _value.sortOrder
                    : sortOrder // ignore: cast_nullable_to_non_nullable
                        as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$InstrumentImplCopyWith<$Res>
    implements $InstrumentCopyWith<$Res> {
  factory _$$InstrumentImplCopyWith(
    _$InstrumentImpl value,
    $Res Function(_$InstrumentImpl) then,
  ) = __$$InstrumentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    int? tenantId,
    String name,
    String? shortName,
    String? color,
    bool isSection,
    int? sectionIndex,
    int? parentId,
    int? legacyId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    int? category,
    List<String>? clefs,
    bool maingroup,
    String? notes,
    String? range,
    String? synonyms,
    String? tuning,
    @JsonKey(name: 'sort_order') int? sortOrder,
  });
}

/// @nodoc
class __$$InstrumentImplCopyWithImpl<$Res>
    extends _$InstrumentCopyWithImpl<$Res, _$InstrumentImpl>
    implements _$$InstrumentImplCopyWith<$Res> {
  __$$InstrumentImplCopyWithImpl(
    _$InstrumentImpl _value,
    $Res Function(_$InstrumentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Instrument
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? name = null,
    Object? shortName = freezed,
    Object? color = freezed,
    Object? isSection = null,
    Object? sectionIndex = freezed,
    Object? parentId = freezed,
    Object? legacyId = freezed,
    Object? createdAt = freezed,
    Object? category = freezed,
    Object? clefs = freezed,
    Object? maingroup = null,
    Object? notes = freezed,
    Object? range = freezed,
    Object? synonyms = freezed,
    Object? tuning = freezed,
    Object? sortOrder = freezed,
  }) {
    return _then(
      _$InstrumentImpl(
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
        shortName:
            freezed == shortName
                ? _value.shortName
                : shortName // ignore: cast_nullable_to_non_nullable
                    as String?,
        color:
            freezed == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                    as String?,
        isSection:
            null == isSection
                ? _value.isSection
                : isSection // ignore: cast_nullable_to_non_nullable
                    as bool,
        sectionIndex:
            freezed == sectionIndex
                ? _value.sectionIndex
                : sectionIndex // ignore: cast_nullable_to_non_nullable
                    as int?,
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
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        category:
            freezed == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                    as int?,
        clefs:
            freezed == clefs
                ? _value._clefs
                : clefs // ignore: cast_nullable_to_non_nullable
                    as List<String>?,
        maingroup:
            null == maingroup
                ? _value.maingroup
                : maingroup // ignore: cast_nullable_to_non_nullable
                    as bool,
        notes:
            freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                    as String?,
        range:
            freezed == range
                ? _value.range
                : range // ignore: cast_nullable_to_non_nullable
                    as String?,
        synonyms:
            freezed == synonyms
                ? _value.synonyms
                : synonyms // ignore: cast_nullable_to_non_nullable
                    as String?,
        tuning:
            freezed == tuning
                ? _value.tuning
                : tuning // ignore: cast_nullable_to_non_nullable
                    as String?,
        sortOrder:
            freezed == sortOrder
                ? _value.sortOrder
                : sortOrder // ignore: cast_nullable_to_non_nullable
                    as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$InstrumentImpl implements _Instrument {
  const _$InstrumentImpl({
    this.id,
    this.tenantId,
    required this.name,
    this.shortName,
    this.color,
    this.isSection = false,
    this.sectionIndex,
    this.parentId,
    this.legacyId,
    @JsonKey(name: 'created_at') this.createdAt,
    this.category,
    final List<String>? clefs,
    this.maingroup = false,
    this.notes,
    this.range,
    this.synonyms,
    this.tuning,
    @JsonKey(name: 'sort_order') this.sortOrder,
  }) : _clefs = clefs;

  factory _$InstrumentImpl.fromJson(Map<String, dynamic> json) =>
      _$$InstrumentImplFromJson(json);

  @override
  final int? id;
  @override
  final int? tenantId;
  @override
  final String name;
  @override
  final String? shortName;
  @override
  final String? color;
  @override
  @JsonKey()
  final bool isSection;
  @override
  final int? sectionIndex;
  @override
  final int? parentId;
  @override
  final int? legacyId;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  // Fields from Ionic that were missing
  @override
  final int? category;
  final List<String>? _clefs;
  @override
  List<String>? get clefs {
    final value = _clefs;
    if (value == null) return null;
    if (_clefs is EqualUnmodifiableListView) return _clefs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final bool maingroup;
  @override
  final String? notes;
  @override
  final String? range;
  @override
  final String? synonyms;
  @override
  final String? tuning;
  @override
  @JsonKey(name: 'sort_order')
  final int? sortOrder;

  @override
  String toString() {
    return 'Instrument(id: $id, tenantId: $tenantId, name: $name, shortName: $shortName, color: $color, isSection: $isSection, sectionIndex: $sectionIndex, parentId: $parentId, legacyId: $legacyId, createdAt: $createdAt, category: $category, clefs: $clefs, maingroup: $maingroup, notes: $notes, range: $range, synonyms: $synonyms, tuning: $tuning, sortOrder: $sortOrder)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InstrumentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.shortName, shortName) ||
                other.shortName == shortName) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.isSection, isSection) ||
                other.isSection == isSection) &&
            (identical(other.sectionIndex, sectionIndex) ||
                other.sectionIndex == sectionIndex) &&
            (identical(other.parentId, parentId) ||
                other.parentId == parentId) &&
            (identical(other.legacyId, legacyId) ||
                other.legacyId == legacyId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(other._clefs, _clefs) &&
            (identical(other.maingroup, maingroup) ||
                other.maingroup == maingroup) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.range, range) || other.range == range) &&
            (identical(other.synonyms, synonyms) ||
                other.synonyms == synonyms) &&
            (identical(other.tuning, tuning) || other.tuning == tuning) &&
            (identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tenantId,
    name,
    shortName,
    color,
    isSection,
    sectionIndex,
    parentId,
    legacyId,
    createdAt,
    category,
    const DeepCollectionEquality().hash(_clefs),
    maingroup,
    notes,
    range,
    synonyms,
    tuning,
    sortOrder,
  );

  /// Create a copy of Instrument
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InstrumentImplCopyWith<_$InstrumentImpl> get copyWith =>
      __$$InstrumentImplCopyWithImpl<_$InstrumentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InstrumentImplToJson(this);
  }
}

abstract class _Instrument implements Instrument {
  const factory _Instrument({
    final int? id,
    final int? tenantId,
    required final String name,
    final String? shortName,
    final String? color,
    final bool isSection,
    final int? sectionIndex,
    final int? parentId,
    final int? legacyId,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    final int? category,
    final List<String>? clefs,
    final bool maingroup,
    final String? notes,
    final String? range,
    final String? synonyms,
    final String? tuning,
    @JsonKey(name: 'sort_order') final int? sortOrder,
  }) = _$InstrumentImpl;

  factory _Instrument.fromJson(Map<String, dynamic> json) =
      _$InstrumentImpl.fromJson;

  @override
  int? get id;
  @override
  int? get tenantId;
  @override
  String get name;
  @override
  String? get shortName;
  @override
  String? get color;
  @override
  bool get isSection;
  @override
  int? get sectionIndex;
  @override
  int? get parentId;
  @override
  int? get legacyId;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt; // Fields from Ionic that were missing
  @override
  int? get category;
  @override
  List<String>? get clefs;
  @override
  bool get maingroup;
  @override
  String? get notes;
  @override
  String? get range;
  @override
  String? get synonyms;
  @override
  String? get tuning;
  @override
  @JsonKey(name: 'sort_order')
  int? get sortOrder;

  /// Create a copy of Instrument
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InstrumentImplCopyWith<_$InstrumentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Group _$GroupFromJson(Map<String, dynamic> json) {
  return _Group.fromJson(json);
}

/// @nodoc
mixin _$Group {
  int? get id => throw _privateConstructorUsedError;
  int? get tenantId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get shortName => throw _privateConstructorUsedError;
  String? get color => throw _privateConstructorUsedError;
  int? get index => throw _privateConstructorUsedError;
  @JsonKey(name: 'category')
  int? get categoryId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  bool? get maingroup => throw _privateConstructorUsedError;
  String? get synonyms => throw _privateConstructorUsedError;
  String? get tuning => throw _privateConstructorUsedError;
  String? get range => throw _privateConstructorUsedError;
  List<String>? get clefs => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  @JsonKey(name: 'sort_order')
  int? get sortOrder => throw _privateConstructorUsedError;
  @JsonKey(includeToJson: false)
  GroupCategory? get categoryData => throw _privateConstructorUsedError;

  /// Serializes this Group to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Group
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupCopyWith<Group> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupCopyWith<$Res> {
  factory $GroupCopyWith(Group value, $Res Function(Group) then) =
      _$GroupCopyWithImpl<$Res, Group>;
  @useResult
  $Res call({
    int? id,
    int? tenantId,
    String name,
    String? shortName,
    String? color,
    int? index,
    @JsonKey(name: 'category') int? categoryId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    bool? maingroup,
    String? synonyms,
    String? tuning,
    String? range,
    List<String>? clefs,
    String? notes,
    @JsonKey(name: 'sort_order') int? sortOrder,
    @JsonKey(includeToJson: false) GroupCategory? categoryData,
  });

  $GroupCategoryCopyWith<$Res>? get categoryData;
}

/// @nodoc
class _$GroupCopyWithImpl<$Res, $Val extends Group>
    implements $GroupCopyWith<$Res> {
  _$GroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Group
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? name = null,
    Object? shortName = freezed,
    Object? color = freezed,
    Object? index = freezed,
    Object? categoryId = freezed,
    Object? createdAt = freezed,
    Object? maingroup = freezed,
    Object? synonyms = freezed,
    Object? tuning = freezed,
    Object? range = freezed,
    Object? clefs = freezed,
    Object? notes = freezed,
    Object? sortOrder = freezed,
    Object? categoryData = freezed,
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
            shortName:
                freezed == shortName
                    ? _value.shortName
                    : shortName // ignore: cast_nullable_to_non_nullable
                        as String?,
            color:
                freezed == color
                    ? _value.color
                    : color // ignore: cast_nullable_to_non_nullable
                        as String?,
            index:
                freezed == index
                    ? _value.index
                    : index // ignore: cast_nullable_to_non_nullable
                        as int?,
            categoryId:
                freezed == categoryId
                    ? _value.categoryId
                    : categoryId // ignore: cast_nullable_to_non_nullable
                        as int?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            maingroup:
                freezed == maingroup
                    ? _value.maingroup
                    : maingroup // ignore: cast_nullable_to_non_nullable
                        as bool?,
            synonyms:
                freezed == synonyms
                    ? _value.synonyms
                    : synonyms // ignore: cast_nullable_to_non_nullable
                        as String?,
            tuning:
                freezed == tuning
                    ? _value.tuning
                    : tuning // ignore: cast_nullable_to_non_nullable
                        as String?,
            range:
                freezed == range
                    ? _value.range
                    : range // ignore: cast_nullable_to_non_nullable
                        as String?,
            clefs:
                freezed == clefs
                    ? _value.clefs
                    : clefs // ignore: cast_nullable_to_non_nullable
                        as List<String>?,
            notes:
                freezed == notes
                    ? _value.notes
                    : notes // ignore: cast_nullable_to_non_nullable
                        as String?,
            sortOrder:
                freezed == sortOrder
                    ? _value.sortOrder
                    : sortOrder // ignore: cast_nullable_to_non_nullable
                        as int?,
            categoryData:
                freezed == categoryData
                    ? _value.categoryData
                    : categoryData // ignore: cast_nullable_to_non_nullable
                        as GroupCategory?,
          )
          as $Val,
    );
  }

  /// Create a copy of Group
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GroupCategoryCopyWith<$Res>? get categoryData {
    if (_value.categoryData == null) {
      return null;
    }

    return $GroupCategoryCopyWith<$Res>(_value.categoryData!, (value) {
      return _then(_value.copyWith(categoryData: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$GroupImplCopyWith<$Res> implements $GroupCopyWith<$Res> {
  factory _$$GroupImplCopyWith(
    _$GroupImpl value,
    $Res Function(_$GroupImpl) then,
  ) = __$$GroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    int? tenantId,
    String name,
    String? shortName,
    String? color,
    int? index,
    @JsonKey(name: 'category') int? categoryId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    bool? maingroup,
    String? synonyms,
    String? tuning,
    String? range,
    List<String>? clefs,
    String? notes,
    @JsonKey(name: 'sort_order') int? sortOrder,
    @JsonKey(includeToJson: false) GroupCategory? categoryData,
  });

  @override
  $GroupCategoryCopyWith<$Res>? get categoryData;
}

/// @nodoc
class __$$GroupImplCopyWithImpl<$Res>
    extends _$GroupCopyWithImpl<$Res, _$GroupImpl>
    implements _$$GroupImplCopyWith<$Res> {
  __$$GroupImplCopyWithImpl(
    _$GroupImpl _value,
    $Res Function(_$GroupImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Group
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? name = null,
    Object? shortName = freezed,
    Object? color = freezed,
    Object? index = freezed,
    Object? categoryId = freezed,
    Object? createdAt = freezed,
    Object? maingroup = freezed,
    Object? synonyms = freezed,
    Object? tuning = freezed,
    Object? range = freezed,
    Object? clefs = freezed,
    Object? notes = freezed,
    Object? sortOrder = freezed,
    Object? categoryData = freezed,
  }) {
    return _then(
      _$GroupImpl(
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
        shortName:
            freezed == shortName
                ? _value.shortName
                : shortName // ignore: cast_nullable_to_non_nullable
                    as String?,
        color:
            freezed == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                    as String?,
        index:
            freezed == index
                ? _value.index
                : index // ignore: cast_nullable_to_non_nullable
                    as int?,
        categoryId:
            freezed == categoryId
                ? _value.categoryId
                : categoryId // ignore: cast_nullable_to_non_nullable
                    as int?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        maingroup:
            freezed == maingroup
                ? _value.maingroup
                : maingroup // ignore: cast_nullable_to_non_nullable
                    as bool?,
        synonyms:
            freezed == synonyms
                ? _value.synonyms
                : synonyms // ignore: cast_nullable_to_non_nullable
                    as String?,
        tuning:
            freezed == tuning
                ? _value.tuning
                : tuning // ignore: cast_nullable_to_non_nullable
                    as String?,
        range:
            freezed == range
                ? _value.range
                : range // ignore: cast_nullable_to_non_nullable
                    as String?,
        clefs:
            freezed == clefs
                ? _value._clefs
                : clefs // ignore: cast_nullable_to_non_nullable
                    as List<String>?,
        notes:
            freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                    as String?,
        sortOrder:
            freezed == sortOrder
                ? _value.sortOrder
                : sortOrder // ignore: cast_nullable_to_non_nullable
                    as int?,
        categoryData:
            freezed == categoryData
                ? _value.categoryData
                : categoryData // ignore: cast_nullable_to_non_nullable
                    as GroupCategory?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GroupImpl implements _Group {
  const _$GroupImpl({
    this.id,
    this.tenantId,
    required this.name,
    this.shortName,
    this.color,
    this.index,
    @JsonKey(name: 'category') this.categoryId,
    @JsonKey(name: 'created_at') this.createdAt,
    this.maingroup = false,
    this.synonyms,
    this.tuning,
    this.range,
    final List<String>? clefs,
    this.notes,
    @JsonKey(name: 'sort_order') this.sortOrder,
    @JsonKey(includeToJson: false) this.categoryData,
  }) : _clefs = clefs;

  factory _$GroupImpl.fromJson(Map<String, dynamic> json) =>
      _$$GroupImplFromJson(json);

  @override
  final int? id;
  @override
  final int? tenantId;
  @override
  final String name;
  @override
  final String? shortName;
  @override
  final String? color;
  @override
  final int? index;
  @override
  @JsonKey(name: 'category')
  final int? categoryId;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey()
  final bool? maingroup;
  @override
  final String? synonyms;
  @override
  final String? tuning;
  @override
  final String? range;
  final List<String>? _clefs;
  @override
  List<String>? get clefs {
    final value = _clefs;
    if (value == null) return null;
    if (_clefs is EqualUnmodifiableListView) return _clefs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? notes;
  @override
  @JsonKey(name: 'sort_order')
  final int? sortOrder;
  @override
  @JsonKey(includeToJson: false)
  final GroupCategory? categoryData;

  @override
  String toString() {
    return 'Group(id: $id, tenantId: $tenantId, name: $name, shortName: $shortName, color: $color, index: $index, categoryId: $categoryId, createdAt: $createdAt, maingroup: $maingroup, synonyms: $synonyms, tuning: $tuning, range: $range, clefs: $clefs, notes: $notes, sortOrder: $sortOrder, categoryData: $categoryData)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.shortName, shortName) ||
                other.shortName == shortName) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.maingroup, maingroup) ||
                other.maingroup == maingroup) &&
            (identical(other.synonyms, synonyms) ||
                other.synonyms == synonyms) &&
            (identical(other.tuning, tuning) || other.tuning == tuning) &&
            (identical(other.range, range) || other.range == range) &&
            const DeepCollectionEquality().equals(other._clefs, _clefs) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder) &&
            (identical(other.categoryData, categoryData) ||
                other.categoryData == categoryData));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tenantId,
    name,
    shortName,
    color,
    index,
    categoryId,
    createdAt,
    maingroup,
    synonyms,
    tuning,
    range,
    const DeepCollectionEquality().hash(_clefs),
    notes,
    sortOrder,
    categoryData,
  );

  /// Create a copy of Group
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupImplCopyWith<_$GroupImpl> get copyWith =>
      __$$GroupImplCopyWithImpl<_$GroupImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GroupImplToJson(this);
  }
}

abstract class _Group implements Group {
  const factory _Group({
    final int? id,
    final int? tenantId,
    required final String name,
    final String? shortName,
    final String? color,
    final int? index,
    @JsonKey(name: 'category') final int? categoryId,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    final bool? maingroup,
    final String? synonyms,
    final String? tuning,
    final String? range,
    final List<String>? clefs,
    final String? notes,
    @JsonKey(name: 'sort_order') final int? sortOrder,
    @JsonKey(includeToJson: false) final GroupCategory? categoryData,
  }) = _$GroupImpl;

  factory _Group.fromJson(Map<String, dynamic> json) = _$GroupImpl.fromJson;

  @override
  int? get id;
  @override
  int? get tenantId;
  @override
  String get name;
  @override
  String? get shortName;
  @override
  String? get color;
  @override
  int? get index;
  @override
  @JsonKey(name: 'category')
  int? get categoryId;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  bool? get maingroup;
  @override
  String? get synonyms;
  @override
  String? get tuning;
  @override
  String? get range;
  @override
  List<String>? get clefs;
  @override
  String? get notes;
  @override
  @JsonKey(name: 'sort_order')
  int? get sortOrder;
  @override
  @JsonKey(includeToJson: false)
  GroupCategory? get categoryData;

  /// Create a copy of Group
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupImplCopyWith<_$GroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GroupCategory _$GroupCategoryFromJson(Map<String, dynamic> json) {
  return _GroupCategory.fromJson(json);
}

/// @nodoc
mixin _$GroupCategory {
  int? get id => throw _privateConstructorUsedError;
  int? get tenantId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'sort_order')
  int? get sortOrder => throw _privateConstructorUsedError;

  /// Serializes this GroupCategory to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GroupCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupCategoryCopyWith<GroupCategory> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupCategoryCopyWith<$Res> {
  factory $GroupCategoryCopyWith(
    GroupCategory value,
    $Res Function(GroupCategory) then,
  ) = _$GroupCategoryCopyWithImpl<$Res, GroupCategory>;
  @useResult
  $Res call({
    int? id,
    int? tenantId,
    String name,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'sort_order') int? sortOrder,
  });
}

/// @nodoc
class _$GroupCategoryCopyWithImpl<$Res, $Val extends GroupCategory>
    implements $GroupCategoryCopyWith<$Res> {
  _$GroupCategoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? name = null,
    Object? createdAt = freezed,
    Object? sortOrder = freezed,
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
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            sortOrder:
                freezed == sortOrder
                    ? _value.sortOrder
                    : sortOrder // ignore: cast_nullable_to_non_nullable
                        as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GroupCategoryImplCopyWith<$Res>
    implements $GroupCategoryCopyWith<$Res> {
  factory _$$GroupCategoryImplCopyWith(
    _$GroupCategoryImpl value,
    $Res Function(_$GroupCategoryImpl) then,
  ) = __$$GroupCategoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    int? tenantId,
    String name,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'sort_order') int? sortOrder,
  });
}

/// @nodoc
class __$$GroupCategoryImplCopyWithImpl<$Res>
    extends _$GroupCategoryCopyWithImpl<$Res, _$GroupCategoryImpl>
    implements _$$GroupCategoryImplCopyWith<$Res> {
  __$$GroupCategoryImplCopyWithImpl(
    _$GroupCategoryImpl _value,
    $Res Function(_$GroupCategoryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = freezed,
    Object? name = null,
    Object? createdAt = freezed,
    Object? sortOrder = freezed,
  }) {
    return _then(
      _$GroupCategoryImpl(
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
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        sortOrder:
            freezed == sortOrder
                ? _value.sortOrder
                : sortOrder // ignore: cast_nullable_to_non_nullable
                    as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GroupCategoryImpl implements _GroupCategory {
  const _$GroupCategoryImpl({
    this.id,
    this.tenantId,
    required this.name,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'sort_order') this.sortOrder,
  });

  factory _$GroupCategoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$GroupCategoryImplFromJson(json);

  @override
  final int? id;
  @override
  final int? tenantId;
  @override
  final String name;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'sort_order')
  final int? sortOrder;

  @override
  String toString() {
    return 'GroupCategory(id: $id, tenantId: $tenantId, name: $name, createdAt: $createdAt, sortOrder: $sortOrder)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupCategoryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, tenantId, name, createdAt, sortOrder);

  /// Create a copy of GroupCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupCategoryImplCopyWith<_$GroupCategoryImpl> get copyWith =>
      __$$GroupCategoryImplCopyWithImpl<_$GroupCategoryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GroupCategoryImplToJson(this);
  }
}

abstract class _GroupCategory implements GroupCategory {
  const factory _GroupCategory({
    final int? id,
    final int? tenantId,
    required final String name,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'sort_order') final int? sortOrder,
  }) = _$GroupCategoryImpl;

  factory _GroupCategory.fromJson(Map<String, dynamic> json) =
      _$GroupCategoryImpl.fromJson;

  @override
  int? get id;
  @override
  int? get tenantId;
  @override
  String get name;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'sort_order')
  int? get sortOrder;

  /// Create a copy of GroupCategory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupCategoryImplCopyWith<_$GroupCategoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
