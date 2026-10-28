import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../l10n/l10n.dart';

part 'song_filter.freezed.dart';
part 'song_filter.g.dart';

/// Sort options for songs list (Ionic `sortOpt`)
enum SongSortOption {
  numberAsc,
  numberDesc,
  nameAsc,
  nameDesc,
  lastSungAsc,
  lastSungDesc,
}

extension SongSortOptionX on SongSortOption {
  /// Label; [orchestra] switches "gesungen" to "gespielt" like Ionic.
  String labelFor({bool orchestra = false}) {
    final l10n = l10nWithoutContext;
    final last = orchestra ? l10n.songsLastPlayed : l10n.songsLastSung;
    switch (this) {
      case SongSortOption.numberAsc:
        return l10n.songsNumberAsc;
      case SongSortOption.numberDesc:
        return l10n.songsNumberDesc;
      case SongSortOption.nameAsc:
        return l10n.songsNameAsc;
      case SongSortOption.nameDesc:
        return l10n.songsNameDesc;
      case SongSortOption.lastSungAsc:
        return '$last ↑';
      case SongSortOption.lastSungDesc:
        return '$last ↓';
    }
  }

  String get label => labelFor();

  bool get isLastSung =>
      this == SongSortOption.lastSungAsc || this == SongSortOption.lastSungDesc;
}

/// Filter and sort settings for songs list (Ionic songs.page filter state)
@freezed
class SongFilter with _$SongFilter {
  const SongFilter._();

  const factory SongFilter({
    /// "Chor & Orchester" toggle (Ionic `inclChoir`)
    @Default(false) bool withChoir,

    /// "Solo" toggle (Ionic `inclSolo`)
    @Default(false) bool withSolo,

    /// Groups filter (Ionic `instrumentsToFilter`)
    @Default([]) List<int> instrumentIds,

    /// Difficulty filter - not persisted (Ionic never restores it)
    @JsonKey(includeToJson: false, includeFromJson: false) int? difficulty,

    /// Category segment (Ionic `selectedCategory`, a category id)
    String? category,

    /// Multi category filter (Ionic `selectedCategories`)
    @Default([]) List<String> categoryIds,

    /// Additional field filters (Ionic `filterOpts`): field id -> value
    /// ('' = all, 'true'/'false' for booleans)
    @Default({}) Map<String, String> fieldFilters,

    @Default(SongSortOption.numberAsc) SongSortOption sortOption,
  }) = _SongFilter;

  factory SongFilter.fromJson(Map<String, dynamic> json) =>
      _$SongFilterFromJson(json);

  /// Check if any filter is active (excluding sort and category segment)
  bool get hasActiveFilters => activeFilterCount > 0;

  /// Count of active filters
  int get activeFilterCount {
    int count = 0;
    if (withChoir) count++;
    if (withSolo) count++;
    if (instrumentIds.isNotEmpty) count++;
    if (difficulty != null) count++;
    if (categoryIds.isNotEmpty) count++;
    count += fieldFilters.values.where((v) => v.isNotEmpty).length;
    return count;
  }
}

/// Default view options (Ionic `viewOpts` default)
const List<String> defaultSongViewOpts = [
  'withChoir',
  'withSolo',
  'missingInstruments',
  'link',
  'lastSung',
];

/// View options for songs list badges/info display (Ionic `viewOpts`).
/// Contains the built-in ids (link, difficulty, withChoir, withSolo,
/// missingInstruments, lastSung) and additional song field ids.
@freezed
class SongViewOptions with _$SongViewOptions {
  const SongViewOptions._();

  const factory SongViewOptions({
    @Default(defaultSongViewOpts) List<String> opts,
  }) = _SongViewOptions;

  factory SongViewOptions.fromJson(Map<String, dynamic> json) =>
      _$SongViewOptionsFromJson(json);

  bool has(String id) => opts.contains(id);
  bool get showChoirBadge => has('withChoir');
  bool get showSoloBadge => has('withSolo');
  bool get showMissingInstruments => has('missingInstruments');
  bool get showLink => has('link');
  bool get showLastSung => has('lastSung');
  bool get showDifficulty => has('difficulty');
}
