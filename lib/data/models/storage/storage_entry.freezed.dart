// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'storage_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$StorageEntry {
  String get name => throw _privateConstructorUsedError;

  /// Pfad relativ zum Tenant-Root (ohne `<tenantId>/`-Präfix)
  String get path => throw _privateConstructorUsedError;
  bool get isFolder => throw _privateConstructorUsedError;
  int? get size => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of StorageEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StorageEntryCopyWith<StorageEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StorageEntryCopyWith<$Res> {
  factory $StorageEntryCopyWith(
    StorageEntry value,
    $Res Function(StorageEntry) then,
  ) = _$StorageEntryCopyWithImpl<$Res, StorageEntry>;
  @useResult
  $Res call({
    String name,
    String path,
    bool isFolder,
    int? size,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$StorageEntryCopyWithImpl<$Res, $Val extends StorageEntry>
    implements $StorageEntryCopyWith<$Res> {
  _$StorageEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StorageEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = null,
    Object? isFolder = null,
    Object? size = freezed,
    Object? updatedAt = freezed,
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
            isFolder:
                null == isFolder
                    ? _value.isFolder
                    : isFolder // ignore: cast_nullable_to_non_nullable
                        as bool,
            size:
                freezed == size
                    ? _value.size
                    : size // ignore: cast_nullable_to_non_nullable
                        as int?,
            updatedAt:
                freezed == updatedAt
                    ? _value.updatedAt
                    : updatedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StorageEntryImplCopyWith<$Res>
    implements $StorageEntryCopyWith<$Res> {
  factory _$$StorageEntryImplCopyWith(
    _$StorageEntryImpl value,
    $Res Function(_$StorageEntryImpl) then,
  ) = __$$StorageEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String path,
    bool isFolder,
    int? size,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$StorageEntryImplCopyWithImpl<$Res>
    extends _$StorageEntryCopyWithImpl<$Res, _$StorageEntryImpl>
    implements _$$StorageEntryImplCopyWith<$Res> {
  __$$StorageEntryImplCopyWithImpl(
    _$StorageEntryImpl _value,
    $Res Function(_$StorageEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StorageEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = null,
    Object? isFolder = null,
    Object? size = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$StorageEntryImpl(
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
        isFolder:
            null == isFolder
                ? _value.isFolder
                : isFolder // ignore: cast_nullable_to_non_nullable
                    as bool,
        size:
            freezed == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                    as int?,
        updatedAt:
            freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$StorageEntryImpl implements _StorageEntry {
  const _$StorageEntryImpl({
    required this.name,
    required this.path,
    required this.isFolder,
    this.size,
    this.updatedAt,
  });

  @override
  final String name;

  /// Pfad relativ zum Tenant-Root (ohne `<tenantId>/`-Präfix)
  @override
  final String path;
  @override
  final bool isFolder;
  @override
  final int? size;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'StorageEntry(name: $name, path: $path, isFolder: $isFolder, size: $size, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StorageEntryImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.isFolder, isFolder) ||
                other.isFolder == isFolder) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, name, path, isFolder, size, updatedAt);

  /// Create a copy of StorageEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StorageEntryImplCopyWith<_$StorageEntryImpl> get copyWith =>
      __$$StorageEntryImplCopyWithImpl<_$StorageEntryImpl>(this, _$identity);
}

abstract class _StorageEntry implements StorageEntry {
  const factory _StorageEntry({
    required final String name,
    required final String path,
    required final bool isFolder,
    final int? size,
    final DateTime? updatedAt,
  }) = _$StorageEntryImpl;

  @override
  String get name;

  /// Pfad relativ zum Tenant-Root (ohne `<tenantId>/`-Präfix)
  @override
  String get path;
  @override
  bool get isFolder;
  @override
  int? get size;
  @override
  DateTime? get updatedAt;

  /// Create a copy of StorageEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StorageEntryImplCopyWith<_$StorageEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
