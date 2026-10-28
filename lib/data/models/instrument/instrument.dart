import 'package:freezed_annotation/freezed_annotation.dart';

part 'instrument.freezed.dart';
part 'instrument.g.dart';

/// Instrument model
@freezed
class Instrument with _$Instrument {
  const factory Instrument({
    int? id,
    int? tenantId,
    required String name,
    String? shortName,
    String? color,
    @Default(false) bool isSection,
    int? sectionIndex,
    int? parentId,
    int? legacyId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    // Fields from Ionic that were missing
    int? category,
    List<String>? clefs,
    @Default(false) bool maingroup,
    String? notes,
    String? range,
    String? synonyms,
    String? tuning,
    @JsonKey(name: 'sort_order') int? sortOrder,
  }) = _Instrument;

  factory Instrument.fromJson(Map<String, dynamic> json) =>
      _$InstrumentFromJson(json);
}

/// Group model (for organizing players)
@freezed
class Group with _$Group {
  const factory Group({
    int? id,
    int? tenantId,
    required String name,
    String? shortName,
    String? color,
    int? index,
    @JsonKey(name: 'category') int? categoryId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @Default(false) bool? maingroup,
    String? synonyms,
    String? tuning,
    String? range,
    List<String>? clefs,
    String? notes,
    /// Order of the instrument in the score (1, 2, 3...). NULL = alphabetical.
    @JsonKey(name: 'sort_order') int? sortOrder,
    @JsonKey(includeToJson: false) GroupCategory? categoryData,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}

/// Group category for organizing groups
@freezed
class GroupCategory with _$GroupCategory {
  const factory GroupCategory({
    int? id,
    int? tenantId,
    required String name,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'sort_order') int? sortOrder,
  }) = _GroupCategory;

  factory GroupCategory.fromJson(Map<String, dynamic> json) =>
      _$GroupCategoryFromJson(json);
}

/// Extension for Instrument
extension InstrumentExtension on Instrument {
  /// Display name
  String get displayName => shortName?.isNotEmpty == true ? shortName! : name;
}

/// Extension for Group
extension GroupExtension on Group {
  /// Display name
  String get displayName => shortName?.isNotEmpty == true ? shortName! : name;
}