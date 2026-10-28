// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instrument.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InstrumentImpl _$$InstrumentImplFromJson(Map<String, dynamic> json) =>
    _$InstrumentImpl(
      id: (json['id'] as num?)?.toInt(),
      tenantId: (json['tenantId'] as num?)?.toInt(),
      name: json['name'] as String,
      shortName: json['shortName'] as String?,
      color: json['color'] as String?,
      isSection: json['isSection'] as bool? ?? false,
      sectionIndex: (json['sectionIndex'] as num?)?.toInt(),
      parentId: (json['parentId'] as num?)?.toInt(),
      legacyId: (json['legacyId'] as num?)?.toInt(),
      createdAt:
          json['created_at'] == null
              ? null
              : DateTime.parse(json['created_at'] as String),
      category: (json['category'] as num?)?.toInt(),
      clefs:
          (json['clefs'] as List<dynamic>?)?.map((e) => e as String).toList(),
      maingroup: json['maingroup'] as bool? ?? false,
      notes: json['notes'] as String?,
      range: json['range'] as String?,
      synonyms: json['synonyms'] as String?,
      tuning: json['tuning'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$InstrumentImplToJson(_$InstrumentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'name': instance.name,
      'shortName': instance.shortName,
      'color': instance.color,
      'isSection': instance.isSection,
      'sectionIndex': instance.sectionIndex,
      'parentId': instance.parentId,
      'legacyId': instance.legacyId,
      'created_at': instance.createdAt?.toIso8601String(),
      'category': instance.category,
      'clefs': instance.clefs,
      'maingroup': instance.maingroup,
      'notes': instance.notes,
      'range': instance.range,
      'synonyms': instance.synonyms,
      'tuning': instance.tuning,
      'sort_order': instance.sortOrder,
    };

_$GroupImpl _$$GroupImplFromJson(Map<String, dynamic> json) => _$GroupImpl(
  id: (json['id'] as num?)?.toInt(),
  tenantId: (json['tenantId'] as num?)?.toInt(),
  name: json['name'] as String,
  shortName: json['shortName'] as String?,
  color: json['color'] as String?,
  index: (json['index'] as num?)?.toInt(),
  categoryId: (json['category'] as num?)?.toInt(),
  createdAt:
      json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
  maingroup: json['maingroup'] as bool? ?? false,
  synonyms: json['synonyms'] as String?,
  tuning: json['tuning'] as String?,
  range: json['range'] as String?,
  clefs: (json['clefs'] as List<dynamic>?)?.map((e) => e as String).toList(),
  notes: json['notes'] as String?,
  categoryData:
      json['categoryData'] == null
          ? null
          : GroupCategory.fromJson(
            json['categoryData'] as Map<String, dynamic>,
          ),
  sortOrder: (json['sort_order'] as num?)?.toInt(),
);

Map<String, dynamic> _$$GroupImplToJson(_$GroupImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'name': instance.name,
      'shortName': instance.shortName,
      'color': instance.color,
      'index': instance.index,
      'category': instance.categoryId,
      'created_at': instance.createdAt?.toIso8601String(),
      'maingroup': instance.maingroup,
      'synonyms': instance.synonyms,
      'tuning': instance.tuning,
      'range': instance.range,
      'clefs': instance.clefs,
      'notes': instance.notes,
  'sort_order': instance.sortOrder,
    };

_$GroupCategoryImpl _$$GroupCategoryImplFromJson(Map<String, dynamic> json) =>
    _$GroupCategoryImpl(
      id: (json['id'] as num?)?.toInt(),
      tenantId: (json['tenantId'] as num?)?.toInt(),
      name: json['name'] as String,
      createdAt:
          json['created_at'] == null
              ? null
              : DateTime.parse(json['created_at'] as String),
      sortOrder: (json['sort_order'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$GroupCategoryImplToJson(_$GroupCategoryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'name': instance.name,
      'created_at': instance.createdAt?.toIso8601String(),
      'sort_order': instance.sortOrder,
    };
