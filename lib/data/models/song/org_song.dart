import 'package:freezed_annotation/freezed_annotation.dart';

import '../tenant/tenant.dart' show ExtraField;
import 'song.dart';

part 'org_song.freezed.dart';
part 'org_song.g.dart';

/// File of a Werk found by the organisation-wide search, with the name of
/// its group in the source instance (Ionic `OrgSongFile`).
@freezed
class OrgSongFile with _$OrgSongFile {
  const factory OrgSongFile({
    String? storageName,
    required String fileName,
    @Default('') String fileType,
    required String url,
    int? instrumentId,
    String? note,
    String? groupName,
    String? groupSynonyms,
  }) = _OrgSongFile;

  factory OrgSongFile.fromJson(Map<String, dynamic> json) =>
      _$OrgSongFileFromJson(json);
}

/// Row returned by the `search_org_songs` RPC (Ionic `OrgSongResult`).
@freezed
class OrgSongResult with _$OrgSongResult {
  const factory OrgSongResult({
    required int id,
    @JsonKey(name: 'tenant_id') required int tenantId,
    @JsonKey(name: 'tenant_name') @Default('') String tenantName,
    required String name,
    int? number,
    String? prefix,
    @Default(false) bool withChoir,
    @Default(false) bool withSolo,
    String? link,
    int? difficulty,
    @JsonKey(name: 'category_names') @Default(<String>[]) List<String> categoryNames,
    @JsonKey(name: 'additional_fields') Map<String, dynamic>? additionalFields,
    @JsonKey(name: 'field_defs') List<ExtraField>? fieldDefs,
    @JsonKey(name: 'beamer_file') Map<String, dynamic>? beamerFile,
    @Default(<OrgSongFile>[]) List<OrgSongFile> files,
    @JsonKey(name: 'total_count') @Default(0) int totalCount,
  }) = _OrgSongResult;

  factory OrgSongResult.fromJson(Map<String, dynamic> json) =>
      _$OrgSongResultFromJson(json);
}

/// A Werk to copy from the organisation search into a target library.
/// [fields] holds the chosen `songs` columns (raw JSON keys).
class OrgSongCopyRequest {
  const OrgSongCopyRequest({
    required this.source,
    required this.targetLibraryId,
    this.existingSongId,
    this.fields = const {},
    this.files = const [],
    this.mainGroupId,
  });

  final OrgSongResult source;

  /// Instance whose Werkbibliothek receives the Werk.
  final int targetLibraryId;

  /// Copy into this Werk of the target library instead of creating one.
  final int? existingSongId;
  final Map<String, dynamic> fields;
  final List<({OrgSongFile file, int? instrumentId})> files;
  final int? mainGroupId;
}

/// `songs.copied_from` of a Werk copied from [source] now.
SongCopiedFrom copiedFromOf(OrgSongResult source, DateTime now) => SongCopiedFrom(
      tenantId: source.tenantId,
      tenantName: source.tenantName,
      songId: source.id,
      copiedAt: now.toUtc().toIso8601String(),
    );

/// Instance of the organisation with its Werk library settings
/// (`tenants.song_source_tenant_id`, `song_additional_fields`).
class OrgSongTenant {
  const OrgSongTenant({
    required this.id,
    required this.shortName,
    this.longName = '',
    this.songSourceTenantId,
    this.songAdditionalFields = const [],
  });

  factory OrgSongTenant.fromJson(Map<String, dynamic> json) => OrgSongTenant(
        id: (json['id'] as num).toInt(),
        shortName: (json['shortName'] as String?) ?? '',
        longName: (json['longName'] as String?) ?? '',
        songSourceTenantId: (json['song_source_tenant_id'] as num?)?.toInt(),
        songAdditionalFields: [
          for (final f in (json['song_additional_fields'] as List?) ?? const [])
            if (f is Map) ExtraField.fromJson(Map<String, dynamic>.from(f)),
        ],
      );

  final int id;
  final String shortName;
  final String longName;

  /// Werk-Synchronisierung: instance whose library this one uses.
  final int? songSourceTenantId;
  final List<ExtraField> songAdditionalFields;

  /// Instance whose Werkbibliothek is used.
  int get libraryId => songSourceTenantId ?? id;
}
