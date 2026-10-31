// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'org_song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrgSongFileImpl _$$OrgSongFileImplFromJson(Map<String, dynamic> json) =>
    _$OrgSongFileImpl(
      storageName: json['storageName'] as String?,
      fileName: json['fileName'] as String,
      fileType: json['fileType'] as String? ?? '',
      url: json['url'] as String,
      instrumentId: (json['instrumentId'] as num?)?.toInt(),
      note: json['note'] as String?,
      groupName: json['groupName'] as String?,
      groupSynonyms: json['groupSynonyms'] as String?,
    );

Map<String, dynamic> _$$OrgSongFileImplToJson(_$OrgSongFileImpl instance) =>
    <String, dynamic>{
      'storageName': instance.storageName,
      'fileName': instance.fileName,
      'fileType': instance.fileType,
      'url': instance.url,
      'instrumentId': instance.instrumentId,
      'note': instance.note,
      'groupName': instance.groupName,
      'groupSynonyms': instance.groupSynonyms,
    };

_$OrgSongResultImpl _$$OrgSongResultImplFromJson(Map<String, dynamic> json) =>
    _$OrgSongResultImpl(
      id: (json['id'] as num).toInt(),
      tenantId: (json['tenant_id'] as num).toInt(),
      tenantName: json['tenant_name'] as String? ?? '',
      name: json['name'] as String,
      number: (json['number'] as num?)?.toInt(),
      prefix: json['prefix'] as String?,
      withChoir: json['withChoir'] as bool? ?? false,
      withSolo: json['withSolo'] as bool? ?? false,
      link: json['link'] as String?,
      difficulty: (json['difficulty'] as num?)?.toInt(),
      categoryNames:
          (json['category_names'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      additionalFields: json['additional_fields'] as Map<String, dynamic>?,
      fieldDefs:
          (json['field_defs'] as List<dynamic>?)
              ?.map((e) => ExtraField.fromJson(e as Map<String, dynamic>))
              .toList(),
      beamerFile: json['beamer_file'] as Map<String, dynamic>?,
      files:
          (json['files'] as List<dynamic>?)
              ?.map((e) => OrgSongFile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <OrgSongFile>[],
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$OrgSongResultImplToJson(_$OrgSongResultImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'tenant_name': instance.tenantName,
      'name': instance.name,
      'number': instance.number,
      'prefix': instance.prefix,
      'withChoir': instance.withChoir,
      'withSolo': instance.withSolo,
      'link': instance.link,
      'difficulty': instance.difficulty,
      'category_names': instance.categoryNames,
      'additional_fields': instance.additionalFields,
      'field_defs': instance.fieldDefs,
      'beamer_file': instance.beamerFile,
      'files': instance.files,
      'total_count': instance.totalCount,
    };
