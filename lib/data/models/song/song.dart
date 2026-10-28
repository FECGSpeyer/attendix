import 'package:freezed_annotation/freezed_annotation.dart';

part 'song.freezed.dart';
part 'song.g.dart';

/// Song model - represents a song/piece in the repertoire
@freezed
class Song with _$Song {
  const factory Song({
    int? id,
    int? tenantId,
    required String name,
    int? number,
    String? prefix,
    @Default(false) bool withChoir,
    @Default(false) bool withSolo,
    /// Computed client-side from history (last past entry). Not a DB column.
    @JsonKey(includeToJson: false) String? lastSung,
    /// Computed client-side: next planned (future) history entry. Not a DB column.
    @JsonKey(includeToJson: false) String? nextPlanned,
    String? link,
    /// Computed client-side: conductor of [lastSung]. Not a DB column.
    @JsonKey(includeToJson: false) String? conductor,
    String? composer,
    int? legacyId,
    @JsonKey(name: 'instrument_ids') List<int>? instrumentIds,
    List<SongFile>? files,
    int? difficulty,
    /// Legacy single category (superseded by [categoryIds])
    String? category,
    /// Song category ids (uuid[] column `category_ids`)
    @JsonKey(name: 'category_ids') List<String>? categoryIds,
    /// Values of the tenant's `song_additional_fields`
    @JsonKey(name: 'additional_fields') Map<String, dynamic>? additionalFields,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Song;

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
}

/// Song file attachment
@freezed
class SongFile with _$SongFile {
  const factory SongFile({
    String? storageName,
    @JsonKey(name: 'created_at') String? createdAt,
    required String fileName,
    required String fileType,
    required String url,
    int? instrumentId,
    String? note,
  }) = _SongFile;

  factory SongFile.fromJson(Map<String, dynamic> json) =>
      _$SongFileFromJson(json);
}

/// Song history - when a song was played
@freezed
class SongHistory with _$SongHistory {
  const factory SongHistory({
    int? id,
    int? tenantId,
    /// DB column is `songId` (camelCase, see Ionic pickHistoryFields)
    @JsonKey(name: 'songId') int? songId,
    @JsonKey(name: 'attendance_id') int? attendanceId,
    @JsonKey(name: 'person_id') int? personId,
    String? date,
    /// Computed client-side (conductor person name or otherConductor). Not a DB column.
    @JsonKey(includeToJson: false) String? conductorName,
    String? otherConductor,
    int? count,
    bool? visible,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    /// Computed client-side: attendance typeInfo or type name. Not a DB column.
    @JsonKey(includeToJson: false) String? typeTitle,
    /// Computed client-side: date of the linked attendance. Not a DB column.
    @JsonKey(includeToJson: false) String? attendanceDate,
    @JsonKey(includeToJson: false) Song? song,
  }) = _SongHistory;

  factory SongHistory.fromJson(Map<String, dynamic> json) =>
      _$SongHistoryFromJson(json);
}

/// Song category
@freezed
class SongCategory with _$SongCategory {
  const factory SongCategory({
    String? id,
    @JsonKey(name: 'tenant_id') int? tenantId,
    required String name,
    @Default(0) int index,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _SongCategory;

  factory SongCategory.fromJson(Map<String, dynamic> json) =>
      _$SongCategoryFromJson(json);
}

/// Extension for Song
extension SongExtension on Song {
  /// Full song number with prefix
  String get fullNumber {
    final p = prefix ?? '';
    final n = number?.toString() ?? '';
    return '$p$n'.trim();
  }
  
  /// Display name with number
  String get displayName {
    final fn = fullNumber;
    if (fn.isEmpty) return name;
    return '$fn - $name';
  }
  
  /// Difficulty label
  String? get difficultyLabel {
    if (difficulty == null) return null;
    switch (difficulty!) {
      case 1: return 'Leicht';
      case 2: return 'Mittel';
      case 3: return 'Schwer';
      case 4: return 'Sehr schwer';
      default: return null;
    }
  }
}