// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_filter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SongFilterImpl _$$SongFilterImplFromJson(Map<String, dynamic> json) =>
    _$SongFilterImpl(
      withChoir: json['withChoir'] as bool? ?? false,
      withSolo: json['withSolo'] as bool? ?? false,
      instrumentIds:
          (json['instrumentIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      category: json['category'] as String?,
      categoryIds:
          (json['categoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      fieldFilters:
          (json['fieldFilters'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      sortOption:
          $enumDecodeNullable(_$SongSortOptionEnumMap, json['sortOption']) ??
          SongSortOption.numberAsc,
    );

Map<String, dynamic> _$$SongFilterImplToJson(_$SongFilterImpl instance) =>
    <String, dynamic>{
      'withChoir': instance.withChoir,
      'withSolo': instance.withSolo,
      'instrumentIds': instance.instrumentIds,
      'category': instance.category,
      'categoryIds': instance.categoryIds,
      'fieldFilters': instance.fieldFilters,
      'sortOption': _$SongSortOptionEnumMap[instance.sortOption]!,
    };

const _$SongSortOptionEnumMap = {
  SongSortOption.numberAsc: 'numberAsc',
  SongSortOption.numberDesc: 'numberDesc',
  SongSortOption.nameAsc: 'nameAsc',
  SongSortOption.nameDesc: 'nameDesc',
  SongSortOption.lastSungAsc: 'lastSungAsc',
  SongSortOption.lastSungDesc: 'lastSungDesc',
};

_$SongViewOptionsImpl _$$SongViewOptionsImplFromJson(
  Map<String, dynamic> json,
) => _$SongViewOptionsImpl(
  opts:
      (json['opts'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      defaultSongViewOpts,
);

Map<String, dynamic> _$$SongViewOptionsImplToJson(
  _$SongViewOptionsImpl instance,
) => <String, dynamic>{'opts': instance.opts};
