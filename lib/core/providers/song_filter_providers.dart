import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/song/song.dart';
import '../../data/models/song/song_additional_field.dart';
import '../../data/models/song/song_filter.dart';

/// Key pattern for persisting filter per tenant
String _getSongFilterPrefsKey(int tenantId) => 'songFilter_$tenantId';

/// Key pattern for persisting view options per tenant
String _getSongViewOptionsPrefsKey(int tenantId) => 'songViewOpts_$tenantId';

/// Search query for the songs list (already debounced by the page)
final songSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Song filter state per tenant (logged-in or shared tenant) with persistence
final songFilterProvider =
    StateNotifierProvider.family<SongFilterNotifier, SongFilter, int>(
  (ref, tenantId) => SongFilterNotifier(tenantId),
);

/// Notifier for song filter state with SharedPreferences persistence
class SongFilterNotifier extends StateNotifier<SongFilter> {
  SongFilterNotifier(this.tenantId, {bool loadPersisted = true})
      : super(const SongFilter()) {
    if (loadPersisted) _loadFromPrefs();
  }

  final int tenantId;

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_getSongFilterPrefsKey(tenantId));
      if (json != null && mounted) {
        state = SongFilter.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (_) {
      // If loading fails, use default filter
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _getSongFilterPrefsKey(tenantId), jsonEncode(state.toJson()));
    } catch (_) {
      // Ignore save errors
    }
  }

  void _set(SongFilter value) {
    state = value;
    _saveToPrefs();
  }

  void setWithChoir(bool value) => _set(state.copyWith(withChoir: value));

  void setWithSolo(bool value) => _set(state.copyWith(withSolo: value));

  void setInstrumentIds(List<int> value) =>
      _set(state.copyWith(instrumentIds: value));

  void setDifficulty(int? value) => _set(state.copyWith(difficulty: value));

  /// Category segment (null/'' = Alle)
  void setCategory(String? value) =>
      _set(state.copyWith(category: (value?.isEmpty ?? true) ? null : value));

  void setCategoryIds(List<String> value) =>
      _set(state.copyWith(categoryIds: value));

  void setFieldFilter(String fieldId, String value) {
    final next = Map<String, String>.from(state.fieldFilters);
    if (value.isEmpty) {
      next.remove(fieldId);
    } else {
      next[fieldId] = value;
    }
    _set(state.copyWith(fieldFilters: next));
  }

  void setSortOption(SongSortOption value) =>
      _set(state.copyWith(sortOption: value));

  /// Drop stored category selections that no longer exist (Ionic getSongs),
  /// otherwise songs stay hidden without a way to reset the filter.
  void pruneCategories(Set<String> existingIds) {
    final category =
        state.category != null && !existingIds.contains(state.category)
            ? null
            : state.category;
    final ids = state.categoryIds.where(existingIds.contains).toList();
    if (category != state.category || ids.length != state.categoryIds.length) {
      _set(state.copyWith(category: category, categoryIds: ids));
    }
  }

  void reset() => _set(SongFilter(
        category: state.category,
        sortOption: state.sortOption,
      ));
}

/// Song view options per tenant with persistence
final songViewOptionsProvider =
    StateNotifierProvider.family<SongViewOptionsNotifier, SongViewOptions, int>(
  (ref, tenantId) => SongViewOptionsNotifier(tenantId),
);

/// Notifier for song view options with SharedPreferences persistence
class SongViewOptionsNotifier extends StateNotifier<SongViewOptions> {
  SongViewOptionsNotifier(this.tenantId) : super(const SongViewOptions()) {
    _loadFromPrefs();
  }

  final int tenantId;

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_getSongViewOptionsPrefsKey(tenantId));
      if (json != null && mounted) {
        final decoded = jsonDecode(json);
        if (decoded is Map<String, dynamic> && decoded['opts'] is List) {
          state = SongViewOptions.fromJson(decoded);
        }
      }
    } catch (_) {
      // If loading fails, use default options
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _getSongViewOptionsPrefsKey(tenantId), jsonEncode(state.toJson()));
    } catch (_) {
      // Ignore save errors
    }
  }

  void setOpts(List<String> opts) {
    state = SongViewOptions(opts: opts);
    _saveToPrefs();
  }

  void toggle(String id) {
    final next = List<String>.from(state.opts);
    if (!next.remove(id)) next.add(id);
    setOpts(next);
  }
}

// ============================================================================
// Pure filter / sort logic (Ionic songs.page filter(), searchSongs(), sort)
// ============================================================================

/// Apply category, groups, choir/solo, difficulty, additional field filters,
/// search and sorting.
List<Song> applySongFilter(
  List<Song> songs,
  SongFilter filter, {
  String search = '',
  List<SongAdditionalField> additionalFields = const [],
}) {
  bool choirSolo(Song song) {
    if (filter.withChoir && filter.withSolo) {
      return song.withChoir && song.withSolo;
    }
    if (filter.withChoir) return song.withChoir;
    if (filter.withSolo) return song.withSolo;
    return true;
  }

  final query = search.trim().toLowerCase();

  final filtered = songs.where((song) {
    final cats = song.categoryIds ?? const <String>[];
    if (filter.category != null && !cats.contains(filter.category)) {
      return false;
    }
    if (filter.categoryIds.isNotEmpty &&
        !filter.categoryIds.any(cats.contains)) {
      return false;
    }
    if (filter.instrumentIds.isNotEmpty) {
      final ids = song.instrumentIds ?? const <int>[];
      if (!ids.any(filter.instrumentIds.contains)) return false;
    }
    if (!choirSolo(song)) return false;
    if (filter.difficulty != null && song.difficulty != filter.difficulty) {
      return false;
    }
    for (final field in additionalFields) {
      final filterVal = filter.fieldFilters[field.id];
      if (filterVal == null || filterVal.isEmpty) continue;
      final songVal = song.additionalFields?[field.id];
      final normalized = filterVal == 'true'
          ? true
          : filterVal == 'false'
              ? false
              : filterVal;
      if (songVal != normalized) return false;
    }
    if (query.isNotEmpty) {
      final nameMatch = song.name.toLowerCase().contains(query);
      final conductorMatch =
          song.conductor?.toLowerCase().contains(query) ?? false;
      final numberMatch = song.fullNumber.toLowerCase().contains(query);
      if (!nameMatch && !conductorMatch && !numberMatch) return false;
    }
    return true;
  }).toList();

  return sortSongs(filtered, filter.sortOption);
}

/// Sort songs (ties are broken by id to keep the order stable)
List<Song> sortSongs(List<Song> songs, SongSortOption option) {
  int byId(Song a, Song b) => (a.id ?? 0).compareTo(b.id ?? 0);
  int byNumber(Song a, Song b) {
    final c = (a.number ?? 0).compareTo(b.number ?? 0);
    return c != 0 ? c : byId(a, b);
  }

  int byName(Song a, Song b) {
    final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return c != 0 ? c : byId(a, b);
  }

  int byLastSung(Song a, Song b, {required bool desc}) {
    final da = DateTime.tryParse(a.lastSung ?? '');
    final db = DateTime.tryParse(b.lastSung ?? '');
    // Songs never sung always at the end
    if (da == null && db == null) return byNumber(a, b);
    if (da == null) return 1;
    if (db == null) return -1;
    final c = desc ? db.compareTo(da) : da.compareTo(db);
    return c != 0 ? c : byNumber(a, b);
  }

  final result = [...songs];
  switch (option) {
    case SongSortOption.numberAsc:
      result.sort(byNumber);
    case SongSortOption.numberDesc:
      result.sort((a, b) => byNumber(b, a));
    case SongSortOption.nameAsc:
      result.sort(byName);
    case SongSortOption.nameDesc:
      result.sort((a, b) => byName(b, a));
    case SongSortOption.lastSungAsc:
      result.sort((a, b) => byLastSung(a, b, desc: false));
    case SongSortOption.lastSungDesc:
      result.sort((a, b) => byLastSung(a, b, desc: true));
  }
  return result;
}
