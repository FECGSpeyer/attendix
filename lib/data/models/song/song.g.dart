// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SongImpl _$$SongImplFromJson(Map<String, dynamic> json) => _$SongImpl(
  id: (json['id'] as num?)?.toInt(),
  tenantId: (json['tenantId'] as num?)?.toInt(),
  name: json['name'] as String,
  number: (json['number'] as num?)?.toInt(),
  prefix: json['prefix'] as String?,
  withChoir: json['withChoir'] as bool? ?? false,
  withSolo: json['withSolo'] as bool? ?? false,
  lastSung: json['lastSung'] as String?,
  nextPlanned: json['nextPlanned'] as String?,
  link: json['link'] as String?,
  conductor: json['conductor'] as String?,
  composer: json['composer'] as String?,
  legacyId: (json['legacyId'] as num?)?.toInt(),
  instrumentIds:
      (json['instrument_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
  files:
      (json['files'] as List<dynamic>?)
          ?.map((e) => SongFile.fromJson(e as Map<String, dynamic>))
          .toList(),
  difficulty: (json['difficulty'] as num?)?.toInt(),
  category: json['category'] as String?,
  categoryIds:
      (json['category_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
  additionalFields: json['additional_fields'] as Map<String, dynamic>?,
  createdAt:
      json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$SongImplToJson(_$SongImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'name': instance.name,
      'number': instance.number,
      'prefix': instance.prefix,
      'withChoir': instance.withChoir,
      'withSolo': instance.withSolo,
      'link': instance.link,
      'composer': instance.composer,
      'legacyId': instance.legacyId,
      'instrument_ids': instance.instrumentIds,
      'files': instance.files,
      'difficulty': instance.difficulty,
      'category': instance.category,
      'category_ids': instance.categoryIds,
      'additional_fields': instance.additionalFields,
      'created_at': instance.createdAt?.toIso8601String(),
    };

_$SongFileImpl _$$SongFileImplFromJson(Map<String, dynamic> json) =>
    _$SongFileImpl(
      storageName: json['storageName'] as String?,
      createdAt: json['created_at'] as String?,
      fileName: json['fileName'] as String,
      fileType: json['fileType'] as String,
      url: json['url'] as String,
      instrumentId: (json['instrumentId'] as num?)?.toInt(),
      note: json['note'] as String?,
    );

Map<String, dynamic> _$$SongFileImplToJson(_$SongFileImpl instance) =>
    <String, dynamic>{
      'storageName': instance.storageName,
      'created_at': instance.createdAt,
      'fileName': instance.fileName,
      'fileType': instance.fileType,
      'url': instance.url,
      'instrumentId': instance.instrumentId,
      'note': instance.note,
    };

_$SongHistoryImpl _$$SongHistoryImplFromJson(Map<String, dynamic> json) =>
    _$SongHistoryImpl(
      id: (json['id'] as num?)?.toInt(),
      tenantId: (json['tenantId'] as num?)?.toInt(),
      songId: (json['songId'] as num?)?.toInt(),
      attendanceId: (json['attendance_id'] as num?)?.toInt(),
      personId: (json['person_id'] as num?)?.toInt(),
      date: json['date'] as String?,
      conductorName: json['conductorName'] as String?,
      otherConductor: json['otherConductor'] as String?,
      count: (json['count'] as num?)?.toInt(),
      visible: json['visible'] as bool?,
      createdAt:
          json['created_at'] == null
              ? null
              : DateTime.parse(json['created_at'] as String),
      typeTitle: json['typeTitle'] as String?,
      attendanceDate: json['attendanceDate'] as String?,
      song:
          json['song'] == null
              ? null
              : Song.fromJson(json['song'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$SongHistoryImplToJson(_$SongHistoryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'songId': instance.songId,
      'attendance_id': instance.attendanceId,
      'person_id': instance.personId,
      'date': instance.date,
      'otherConductor': instance.otherConductor,
      'count': instance.count,
      'visible': instance.visible,
      'created_at': instance.createdAt?.toIso8601String(),
    };

_$SongCategoryImpl _$$SongCategoryImplFromJson(Map<String, dynamic> json) =>
    _$SongCategoryImpl(
      id: json['id'] as String?,
      tenantId: (json['tenant_id'] as num?)?.toInt(),
      name: json['name'] as String,
      index: (json['index'] as num?)?.toInt() ?? 0,
      createdAt:
          json['created_at'] == null
              ? null
              : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$SongCategoryImplToJson(_$SongCategoryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'name': instance.name,
      'index': instance.index,
      'created_at': instance.createdAt?.toIso8601String(),
    };
