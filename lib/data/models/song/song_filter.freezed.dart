// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'song_filter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SongFilter _$SongFilterFromJson(Map<String, dynamic> json) {
  return _SongFilter.fromJson(json);
}

/// @nodoc
mixin _$SongFilter {
  /// "Chor & Orchester" toggle (Ionic `inclChoir`)
  bool get withChoir => throw _privateConstructorUsedError;

  /// "Solo" toggle (Ionic `inclSolo`)
  bool get withSolo => throw _privateConstructorUsedError;

  /// Groups filter (Ionic `instrumentsToFilter`)
  List<int> get instrumentIds => throw _privateConstructorUsedError;

  /// Difficulty filter - not persisted (Ionic never restores it)
  @JsonKey(includeToJson: false, includeFromJson: false)
  int? get difficulty => throw _privateConstructorUsedError;

  /// Category segment (Ionic `selectedCategory`, a category id)
  String? get category => throw _privateConstructorUsedError;

  /// Multi category filter (Ionic `selectedCategories`)
  List<String> get categoryIds => throw _privateConstructorUsedError;

  /// Additional field filters (Ionic `filterOpts`): field id -> value
  /// ('' = all, 'true'/'false' for booleans)
  Map<String, String> get fieldFilters => throw _privateConstructorUsedError;
  SongSortOption get sortOption => throw _privateConstructorUsedError;

  /// Serializes this SongFilter to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SongFilter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SongFilterCopyWith<SongFilter> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SongFilterCopyWith<$Res> {
  factory $SongFilterCopyWith(
    SongFilter value,
    $Res Function(SongFilter) then,
  ) = _$SongFilterCopyWithImpl<$Res, SongFilter>;
  @useResult
  $Res call({
    bool withChoir,
    bool withSolo,
    List<int> instrumentIds,
    @JsonKey(includeToJson: false, includeFromJson: false) int? difficulty,
    String? category,
    List<String> categoryIds,
    Map<String, String> fieldFilters,
    SongSortOption sortOption,
  });
}

/// @nodoc
class _$SongFilterCopyWithImpl<$Res, $Val extends SongFilter>
    implements $SongFilterCopyWith<$Res> {
  _$SongFilterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SongFilter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? withChoir = null,
    Object? withSolo = null,
    Object? instrumentIds = null,
    Object? difficulty = freezed,
    Object? category = freezed,
    Object? categoryIds = null,
    Object? fieldFilters = null,
    Object? sortOption = null,
  }) {
    return _then(
      _value.copyWith(
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
            instrumentIds:
                null == instrumentIds
                    ? _value.instrumentIds
                    : instrumentIds // ignore: cast_nullable_to_non_nullable
                        as List<int>,
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
                null == categoryIds
                    ? _value.categoryIds
                    : categoryIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            fieldFilters:
                null == fieldFilters
                    ? _value.fieldFilters
                    : fieldFilters // ignore: cast_nullable_to_non_nullable
                        as Map<String, String>,
            sortOption:
                null == sortOption
                    ? _value.sortOption
                    : sortOption // ignore: cast_nullable_to_non_nullable
                        as SongSortOption,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SongFilterImplCopyWith<$Res>
    implements $SongFilterCopyWith<$Res> {
  factory _$$SongFilterImplCopyWith(
    _$SongFilterImpl value,
    $Res Function(_$SongFilterImpl) then,
  ) = __$$SongFilterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool withChoir,
    bool withSolo,
    List<int> instrumentIds,
    @JsonKey(includeToJson: false, includeFromJson: false) int? difficulty,
    String? category,
    List<String> categoryIds,
    Map<String, String> fieldFilters,
    SongSortOption sortOption,
  });
}

/// @nodoc
class __$$SongFilterImplCopyWithImpl<$Res>
    extends _$SongFilterCopyWithImpl<$Res, _$SongFilterImpl>
    implements _$$SongFilterImplCopyWith<$Res> {
  __$$SongFilterImplCopyWithImpl(
    _$SongFilterImpl _value,
    $Res Function(_$SongFilterImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SongFilter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? withChoir = null,
    Object? withSolo = null,
    Object? instrumentIds = null,
    Object? difficulty = freezed,
    Object? category = freezed,
    Object? categoryIds = null,
    Object? fieldFilters = null,
    Object? sortOption = null,
  }) {
    return _then(
      _$SongFilterImpl(
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
        instrumentIds:
            null == instrumentIds
                ? _value._instrumentIds
                : instrumentIds // ignore: cast_nullable_to_non_nullable
                    as List<int>,
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
            null == categoryIds
                ? _value._categoryIds
                : categoryIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        fieldFilters:
            null == fieldFilters
                ? _value._fieldFilters
                : fieldFilters // ignore: cast_nullable_to_non_nullable
                    as Map<String, String>,
        sortOption:
            null == sortOption
                ? _value.sortOption
                : sortOption // ignore: cast_nullable_to_non_nullable
                    as SongSortOption,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SongFilterImpl extends _SongFilter {
  const _$SongFilterImpl({
    this.withChoir = false,
    this.withSolo = false,
    final List<int> instrumentIds = const [],
    @JsonKey(includeToJson: false, includeFromJson: false) this.difficulty,
    this.category,
    final List<String> categoryIds = const [],
    final Map<String, String> fieldFilters = const {},
    this.sortOption = SongSortOption.numberAsc,
  }) : _instrumentIds = instrumentIds,
       _categoryIds = categoryIds,
       _fieldFilters = fieldFilters,
       super._();

  factory _$SongFilterImpl.fromJson(Map<String, dynamic> json) =>
      _$$SongFilterImplFromJson(json);

  /// "Chor & Orchester" toggle (Ionic `inclChoir`)
  @override
  @JsonKey()
  final bool withChoir;

  /// "Solo" toggle (Ionic `inclSolo`)
  @override
  @JsonKey()
  final bool withSolo;

  /// Groups filter (Ionic `instrumentsToFilter`)
  final List<int> _instrumentIds;

  /// Groups filter (Ionic `instrumentsToFilter`)
  @override
  @JsonKey()
  List<int> get instrumentIds {
    if (_instrumentIds is EqualUnmodifiableListView) return _instrumentIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_instrumentIds);
  }

  /// Difficulty filter - not persisted (Ionic never restores it)
  @override
  @JsonKey(includeToJson: false, includeFromJson: false)
  final int? difficulty;

  /// Category segment (Ionic `selectedCategory`, a category id)
  @override
  final String? category;

  /// Multi category filter (Ionic `selectedCategories`)
  final List<String> _categoryIds;

  /// Multi category filter (Ionic `selectedCategories`)
  @override
  @JsonKey()
  List<String> get categoryIds {
    if (_categoryIds is EqualUnmodifiableListView) return _categoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categoryIds);
  }

  /// Additional field filters (Ionic `filterOpts`): field id -> value
  /// ('' = all, 'true'/'false' for booleans)
  final Map<String, String> _fieldFilters;

  /// Additional field filters (Ionic `filterOpts`): field id -> value
  /// ('' = all, 'true'/'false' for booleans)
  @override
  @JsonKey()
  Map<String, String> get fieldFilters {
    if (_fieldFilters is EqualUnmodifiableMapView) return _fieldFilters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_fieldFilters);
  }

  @override
  @JsonKey()
  final SongSortOption sortOption;

  @override
  String toString() {
    return 'SongFilter(withChoir: $withChoir, withSolo: $withSolo, instrumentIds: $instrumentIds, difficulty: $difficulty, category: $category, categoryIds: $categoryIds, fieldFilters: $fieldFilters, sortOption: $sortOption)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SongFilterImpl &&
            (identical(other.withChoir, withChoir) ||
                other.withChoir == withChoir) &&
            (identical(other.withSolo, withSolo) ||
                other.withSolo == withSolo) &&
            const DeepCollectionEquality().equals(
              other._instrumentIds,
              _instrumentIds,
            ) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(
              other._categoryIds,
              _categoryIds,
            ) &&
            const DeepCollectionEquality().equals(
              other._fieldFilters,
              _fieldFilters,
            ) &&
            (identical(other.sortOption, sortOption) ||
                other.sortOption == sortOption));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    withChoir,
    withSolo,
    const DeepCollectionEquality().hash(_instrumentIds),
    difficulty,
    category,
    const DeepCollectionEquality().hash(_categoryIds),
    const DeepCollectionEquality().hash(_fieldFilters),
    sortOption,
  );

  /// Create a copy of SongFilter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SongFilterImplCopyWith<_$SongFilterImpl> get copyWith =>
      __$$SongFilterImplCopyWithImpl<_$SongFilterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SongFilterImplToJson(this);
  }
}

abstract class _SongFilter extends SongFilter {
  const factory _SongFilter({
    final bool withChoir,
    final bool withSolo,
    final List<int> instrumentIds,
    @JsonKey(includeToJson: false, includeFromJson: false)
    final int? difficulty,
    final String? category,
    final List<String> categoryIds,
    final Map<String, String> fieldFilters,
    final SongSortOption sortOption,
  }) = _$SongFilterImpl;
  const _SongFilter._() : super._();

  factory _SongFilter.fromJson(Map<String, dynamic> json) =
      _$SongFilterImpl.fromJson;

  /// "Chor & Orchester" toggle (Ionic `inclChoir`)
  @override
  bool get withChoir;

  /// "Solo" toggle (Ionic `inclSolo`)
  @override
  bool get withSolo;

  /// Groups filter (Ionic `instrumentsToFilter`)
  @override
  List<int> get instrumentIds;

  /// Difficulty filter - not persisted (Ionic never restores it)
  @override
  @JsonKey(includeToJson: false, includeFromJson: false)
  int? get difficulty;

  /// Category segment (Ionic `selectedCategory`, a category id)
  @override
  String? get category;

  /// Multi category filter (Ionic `selectedCategories`)
  @override
  List<String> get categoryIds;

  /// Additional field filters (Ionic `filterOpts`): field id -> value
  /// ('' = all, 'true'/'false' for booleans)
  @override
  Map<String, String> get fieldFilters;
  @override
  SongSortOption get sortOption;

  /// Create a copy of SongFilter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SongFilterImplCopyWith<_$SongFilterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SongViewOptions _$SongViewOptionsFromJson(Map<String, dynamic> json) {
  return _SongViewOptions.fromJson(json);
}

/// @nodoc
mixin _$SongViewOptions {
  List<String> get opts => throw _privateConstructorUsedError;

  /// Serializes this SongViewOptions to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SongViewOptions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SongViewOptionsCopyWith<SongViewOptions> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SongViewOptionsCopyWith<$Res> {
  factory $SongViewOptionsCopyWith(
    SongViewOptions value,
    $Res Function(SongViewOptions) then,
  ) = _$SongViewOptionsCopyWithImpl<$Res, SongViewOptions>;
  @useResult
  $Res call({List<String> opts});
}

/// @nodoc
class _$SongViewOptionsCopyWithImpl<$Res, $Val extends SongViewOptions>
    implements $SongViewOptionsCopyWith<$Res> {
  _$SongViewOptionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SongViewOptions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? opts = null}) {
    return _then(
      _value.copyWith(
            opts:
                null == opts
                    ? _value.opts
                    : opts // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SongViewOptionsImplCopyWith<$Res>
    implements $SongViewOptionsCopyWith<$Res> {
  factory _$$SongViewOptionsImplCopyWith(
    _$SongViewOptionsImpl value,
    $Res Function(_$SongViewOptionsImpl) then,
  ) = __$$SongViewOptionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<String> opts});
}

/// @nodoc
class __$$SongViewOptionsImplCopyWithImpl<$Res>
    extends _$SongViewOptionsCopyWithImpl<$Res, _$SongViewOptionsImpl>
    implements _$$SongViewOptionsImplCopyWith<$Res> {
  __$$SongViewOptionsImplCopyWithImpl(
    _$SongViewOptionsImpl _value,
    $Res Function(_$SongViewOptionsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SongViewOptions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? opts = null}) {
    return _then(
      _$SongViewOptionsImpl(
        opts:
            null == opts
                ? _value._opts
                : opts // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SongViewOptionsImpl extends _SongViewOptions {
  const _$SongViewOptionsImpl({final List<String> opts = defaultSongViewOpts})
    : _opts = opts,
      super._();

  factory _$SongViewOptionsImpl.fromJson(Map<String, dynamic> json) =>
      _$$SongViewOptionsImplFromJson(json);

  final List<String> _opts;
  @override
  @JsonKey()
  List<String> get opts {
    if (_opts is EqualUnmodifiableListView) return _opts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_opts);
  }

  @override
  String toString() {
    return 'SongViewOptions(opts: $opts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SongViewOptionsImpl &&
            const DeepCollectionEquality().equals(other._opts, _opts));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_opts));

  /// Create a copy of SongViewOptions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SongViewOptionsImplCopyWith<_$SongViewOptionsImpl> get copyWith =>
      __$$SongViewOptionsImplCopyWithImpl<_$SongViewOptionsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SongViewOptionsImplToJson(this);
  }
}

abstract class _SongViewOptions extends SongViewOptions {
  const factory _SongViewOptions({final List<String> opts}) =
      _$SongViewOptionsImpl;
  const _SongViewOptions._() : super._();

  factory _SongViewOptions.fromJson(Map<String, dynamic> json) =
      _$SongViewOptionsImpl.fromJson;

  @override
  List<String> get opts;

  /// Create a copy of SongViewOptions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SongViewOptionsImplCopyWith<_$SongViewOptionsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
