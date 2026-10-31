import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/instrument/instrument.dart';
import '../../data/models/song/song.dart';
import '../../data/models/song/song_additional_field.dart';
import '../../data/models/tenant/tenant.dart';
import '../../data/repositories/repositories.dart';
import '../config/supabase_config.dart';
import '../utils/choir_file_utils.dart';
import 'group_providers.dart';
import 'locale_provider.dart';
import 'tenant_providers.dart';
import '../../l10n/l10n.dart';

// ============================================================================
// Tenant song settings (Werk-Synchronisierung, additional fields)
// ============================================================================

/// Song related settings of the current tenant (`song_source_tenant_id`,
/// `song_additional_fields`, `song_sharing_id`). Falls back to defaults if the
/// tenant row cannot be read, so songs still load from the own tenant.
final songTenantSettingsProvider =
    FutureProvider<SongTenantSettings>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const SongTenantSettings();

  // The settings query only uses the current tenant id (never the song
  // source), so the base repository with tenant context is sufficient here.
  // songRepositoryWithTenantProvider itself depends on this provider.
  // SOL_FIX1: per-tenant instance instead of mutating the shared one.
  final repo = ref.watch(songRepositoryForTenantProvider(
      (tenantId: tenantId, songSourceTenantId: null)));
  try {
    return await repo.getSongTenantSettings();
  } catch (_) {
    return const SongTenantSettings();
  }
});

/// Initialized song repository with tenant context and song source tenant.
/// SOL_FIX1: per-(tenant, song source) immutable instance, so a tenant
/// switch never changes the tenant of an operation that is already running.
final songRepositoryWithTenantProvider = Provider<SongRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  final source =
      ref.watch(songTenantSettingsProvider).valueOrNull?.songSourceTenantId;
  return ref.watch(songRepositoryForTenantProvider(
      (tenantId: tenant, songSourceTenantId: source)));
});

/// Resolve the repository only after the song source tenant is known, so
/// synced tenants never briefly load their own (empty) library.
Future<SongRepository> _readySongRepository(Ref ref) async {
  await ref.watch(songTenantSettingsProvider.future);
  return ref.watch(songRepositoryWithTenantProvider);
}

// ============================================================================
// Songs
// ============================================================================

/// Enrich songs with `lastSung`, `nextPlanned` and `conductor` from the
/// history (Ionic `SongsPage.getSongs`).
///
/// [history] must be sorted by date descending and may contain planned
/// future entries: "Zuletzt gesungen" only considers entries up to today,
/// the nearest future entry becomes `nextPlanned`.
List<Song> enrichSongsWithHistory(
  List<Song> songs,
  List<SongHistory> history, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final bySong = <int, List<SongHistory>>{};
  for (final h in history) {
    final id = h.songId;
    if (id != null) bySong.putIfAbsent(id, () => []).add(h);
  }

  DateTime? dayOf(SongHistory h) {
    final d = DateTime.tryParse(h.date ?? '')?.toLocal();
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  return songs.map((song) {
    final entries = bySong[song.id] ?? const <SongHistory>[];
    // Ionic: lastSung = latest entry not after today (future attendances
    // are ignored), nextPlanned = nearest future entry. Order independent.
    SongHistory? last;
    DateTime? lastDay;
    SongHistory? next;
    DateTime? nextDay;
    for (final h in entries) {
      final day = dayOf(h);
      if (day == null) continue;
      if (day.isAfter(todayDate)) {
        if (nextDay == null || day.isBefore(nextDay)) {
          next = h;
          nextDay = day;
        }
      } else if (lastDay == null || day.isAfter(lastDay)) {
        last = h;
        lastDay = day;
      }
    }
    final conductor = last == null
        ? null
        : (last.conductorName?.isNotEmpty == true
            ? last.conductorName
            : last.otherConductor);
    return song.copyWith(
      lastSung: last?.date,
      nextPlanned: next?.date,
      conductor: conductor,
    );
  }).toList();
}

/// Provider for the songs of the (effective) song library, enriched with
/// last sung / next planned data from the current tenant's history.
final songsProvider = FutureProvider<List<Song>>((ref) async {
  final repo = await _readySongRepository(ref);

  if (!repo.hasTenantId) return [];

  final songs = await repo.getSongs();
  List<SongHistory> history;
  try {
    history = await repo.getHistory();
  } catch (_) {
    history = const [];
  }
  return enrichSongsWithHistory(songs, history);
});

/// Provider for single song by ID (loaded from the song source tenant).
final songByIdProvider = FutureProvider.family<Song?, int>((ref, id) async {
  final repo = await _readySongRepository(ref);

  if (!repo.hasTenantId) return null;

  return repo.getSongById(id);
});

/// Provider for song categories (of the song source tenant)
final songCategoriesProvider = FutureProvider<List<SongCategory>>((ref) async {
  final repo = await _readySongRepository(ref);

  if (!repo.hasTenantId) return [];

  return repo.getSongCategories();
});

/// Provider for song history. With a song id: Werkhistorie of that song
/// (visible entries incl. attendance type and conductor).
final songHistoryProvider =
    FutureProvider.family<List<SongHistory>, int?>((ref, songId) async {
  final repo = await _readySongRepository(ref);

  if (!repo.hasTenantId) return [];

  if (songId != null) return repo.getHistoryBySongId(songId);
  return repo.getSongHistory();
});

/// Provider for current songs (all upcoming events from tomorrow onwards)
final currentSongsProvider =
    FutureProvider<List<CurrentSongsGroup>>((ref) async {
  final repo = await _readySongRepository(ref);

  if (!repo.hasTenantId) return [];

  return repo.getCurrentSongs();
});

/// Names of the other instances sharing the current song library.
final songSyncedTenantNamesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  // REVIEW_FIX2: the fallback label follows the active language.
  ref.watch(localeProvider);
  final repo = await _readySongRepository(ref);
  if (!repo.hasTenantId) return [];
  try {
    return await repo.getSyncedTenantNames();
  } catch (_) {
    return repo.isSyncedLibrary ? [l10nWithoutContext.songsSourceInstance] : [];
  }
});

/// True if a realtime DELETE (old record, usually only the `id`) concerns a
/// loaded song. Unknown song lists (not loaded yet) count as relevant.
bool isRelevantSongDelete(Map<String, dynamic> oldRecord, List<Song>? songs) {
  final id = (oldRecord['id'] as num?)?.toInt();
  if (id == null) return false;
  if (songs == null) return true;
  return songs.any((s) => s.id == id);
}

/// Realtime subscription on the songs table of the effective song tenant.
/// Watch it from a page to refresh [songsProvider] on changes.
final songsRealtimeProvider = Provider.autoDispose<void>((ref) {
  final settings = ref.watch(songTenantSettingsProvider).valueOrNull;
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null || settings == null) return;
  final songTenantId = settings.songSourceTenantId ?? tenantId;

  final supabase = ref.watch(supabaseClientProvider);
  Timer? debounce;
  void refresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () {
      ref.invalidate(songsProvider);
    });
  }

  final channel = supabase
      .channel('songs-changes-$songTenantId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'songs',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tenantId',
          value: songTenantId,
        ),
        callback: (_) => refresh(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'songs',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tenantId',
          value: songTenantId,
        ),
        callback: (_) => refresh(),
      )
      // Supabase does not apply column filters to DELETE events (the old
      // record only carries the id), so deletes are received unfiltered and
      // matched against the loaded songs (Ionic songs.page: `payload.old.id`).
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'songs',
        callback: (payload) {
          if (isRelevantSongDelete(
            payload.oldRecord,
            ref.read(songsProvider).valueOrNull,
          )) {
            refresh();
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    supabase.removeChannel(channel);
  });
});

// ============================================================================
// Songs list data (authenticated and public share link)
// ============================================================================

/// Everything the songs list needs - for the logged-in tenant or for a
/// public song sharing link (Ionic `/:songSharingId`).
class SongsListData {
  const SongsListData({
    required this.tenantId,
    required this.tenantType,
    required this.songs,
    required this.categories,
    required this.groups,
    required this.groupCategories,
    required this.currentSongs,
    required this.additionalFields,
    this.publicTenant,
    this.songSharingId,
  });

  /// Tenant used for persisted filter settings (current or shared tenant)
  final int tenantId;
  final String tenantType;
  final List<Song> songs;
  final List<SongCategory> categories;

  /// All groups of the tenant (incl. main group)
  final List<Group> groups;
  final List<GroupCategory> groupCategories;
  final List<CurrentSongsGroup> currentSongs;
  final List<SongAdditionalField> additionalFields;

  /// Set when the list is shown via a public share link
  final Tenant? publicTenant;
  final String? songSharingId;

  bool get isPublic => publicTenant != null;
  bool get isOrchestra => tenantType == 'orchestra';

  /// Groups shown as instruments (all but the main group)
  List<Group> get instruments =>
      groups.where((g) => g.maingroup != true).toList();
}

/// Ionic: for orchestras, songs without instrument_ids count as fully
/// instrumented (all group ids).
List<Song> _applyDefaultInstruments(List<Song> songs, List<Group> groups, bool isOrchestra) {
  if (!isOrchestra) return songs;
  final allIds = groups.map((g) => g.id).whereType<int>().toList();
  return songs
      .map((s) => (s.instrumentIds?.isNotEmpty ?? false)
          ? s
          : s.copyWith(instrumentIds: allIds))
      .toList();
}

/// Data for the songs list. `null` sharing id = logged-in tenant.
/// Returns null if a public sharing id is invalid.
final songsListDataProvider =
    FutureProvider.autoDispose.family<SongsListData?, String?>((ref, sharingId) async {
  // SOL_FIX16: account link before the first await (see account_scoped test).
  ref.watch(currentAuthUserIdProvider);
  if (sharingId != null) {
    final repo = ref.watch(publicSongRepositoryProvider);
    final shared = await repo.getTenantBySongSharingId(sharingId);
    if (shared == null) return null;
    final tid = shared.id;
    final results = await Future.wait([
      repo.getSongs(tid),
      repo.getSongCategories(tid),
      repo.getGroups(tid),
      repo.getGroupCategories(tid).catchError((_) => <GroupCategory>[]),
      repo.getCurrentSongs(tid).catchError((_) => <CurrentSongsGroup>[]),
    ]);
    final groups = results[2] as List<Group>;
    final isOrchestra = shared.tenant.type == 'orchestra';
    return SongsListData(
      tenantId: tid,
      tenantType: shared.tenant.type,
      songs: _applyDefaultInstruments(results[0] as List<Song>, groups, isOrchestra),
      categories: results[1] as List<SongCategory>,
      groups: groups,
      groupCategories: results[3] as List<GroupCategory>,
      currentSongs: results[4] as List<CurrentSongsGroup>,
      additionalFields: shared.additionalFields,
      publicTenant: shared.tenant,
      songSharingId: sharingId,
    );
  }

  final tenant = ref.watch(currentTenantProvider);
  final tenantId = tenant?.id;
  if (tenantId == null) return null;

  final settings = await ref.watch(songTenantSettingsProvider.future);
  final songs = await ref.watch(songsProvider.future);
  final categories = await ref.watch(songCategoriesProvider.future);
  final groups = await ref.watch(groupsProvider.future);
  List<GroupCategory> groupCategories;
  try {
    groupCategories = await ref.watch(groupCategoriesProvider.future);
  } catch (_) {
    groupCategories = const [];
  }
  List<CurrentSongsGroup> currentSongs;
  try {
    currentSongs = await ref.watch(currentSongsProvider.future);
  } catch (_) {
    currentSongs = const [];
  }
  final isOrchestra = tenant!.type == 'orchestra';

  return SongsListData(
    tenantId: tenantId,
    tenantType: tenant.type,
    songs: _applyDefaultInstruments(songs, groups, isOrchestra),
    categories: categories,
    groups: groups,
    groupCategories: groupCategories,
    currentSongs: currentSongs,
    additionalFields: settings.additionalFields,
    songSharingId: settings.songSharingId ?? tenant.songSharingId,
  );
});

// ============================================================================
// Song detail data (authenticated and public share link)
// ============================================================================

/// Parameters for [songDetailDataProvider]
typedef SongDetailParams = ({int songId, String? sharingId});

/// Everything the song detail page needs.
class SongDetailData {
  const SongDetailData({
    required this.song,
    required this.tenantType,
    required this.instruments,
    required this.categories,
    required this.additionalFields,
    required this.history,
    required this.readOnly,
    this.publicTenant,
    this.songSharingId,
    this.mainGroupId,
  });

  final Song song;
  final String tenantType;

  /// Groups without the main group (only loaded for orchestras)
  final List<Group> instruments;
  final List<SongCategory> categories;
  final List<SongAdditionalField> additionalFields;

  /// Werkhistorie (only loaded for admins/responsibles)
  final List<SongHistory> history;
  final bool readOnly;
  final Tenant? publicTenant;
  final String? songSharingId;
  final int? mainGroupId;

  bool get isPublic => publicTenant != null;
  bool get isOrchestra => tenantType == 'orchestra';
  bool get isChoir => tenantType == 'choir';
}

final songDetailDataProvider = FutureProvider.autoDispose
    .family<SongDetailData?, SongDetailParams>((ref, params) async {
  // SOL_FIX16: account link before the first await (see account_scoped test).
  ref.watch(currentAuthUserIdProvider);
  if (params.sharingId != null) {
    final repo = ref.watch(publicSongRepositoryProvider);
    final shared = await repo.getTenantBySongSharingId(params.sharingId!);
    if (shared == null) return null;
    final song = await repo.getSong(params.songId, shared.id);
    if (song == null) return null;
    final isOrchestra = shared.tenant.type == 'orchestra';
    final groups = isOrchestra ? await repo.getGroups(shared.id) : const <Group>[];
    List<SongCategory> categories;
    try {
      categories = await repo.getSongCategories(shared.id);
    } catch (_) {
      categories = const [];
    }
    return SongDetailData(
      song: song,
      tenantType: shared.tenant.type,
      instruments: groups.where((g) => g.maingroup != true).toList(),
      categories: categories,
      additionalFields: shared.additionalFields,
      history: const [],
      readOnly: true,
      publicTenant: shared.tenant,
      songSharingId: params.sharingId,
    );
  }

  final tenant = ref.watch(currentTenantProvider);
  if (tenant?.id == null) return null;
  final role = ref.watch(currentRoleProvider);
  final readOnly = !(role.isAdmin || role.isResponsible);

  final settings = await ref.watch(songTenantSettingsProvider.future);
  final song = await ref.watch(songByIdProvider(params.songId).future);
  if (song == null) return null;

  final groups = await ref.watch(groupsProvider.future);
  List<SongCategory> categories;
  try {
    categories = await ref.watch(songCategoriesProvider.future);
  } catch (_) {
    categories = const [];
  }
  List<SongHistory> history = const [];
  if (!readOnly) {
    try {
      history = await ref.watch(songHistoryProvider(params.songId).future);
    } catch (_) {
      // Non-critical
    }
  }

  final isOrchestra = tenant!.type == 'orchestra';
  return SongDetailData(
    song: song,
    tenantType: tenant.type,
    instruments: isOrchestra
        ? groups.where((g) => g.maingroup != true).toList()
        : const [],
    categories: categories,
    additionalFields: settings.additionalFields,
    history: history,
    readOnly: readOnly,
    songSharingId: settings.songSharingId ?? tenant.songSharingId,
    mainGroupId: groups.where((g) => g.maingroup == true).firstOrNull?.id,
  );
});

// ============================================================================
// Mutations
// ============================================================================

/// Notifier for song mutations (CRUD operations)
class SongNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  SongRepository get _repo => ref.read(songRepositoryWithTenantProvider);

  Future<Song?> createSong(Song song) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createSong(song);
      state = const AsyncValue.data(null);
      ref.invalidate(songsProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<Song?> updateSong(int id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.updateSong(id, updates);
      state = const AsyncValue.data(null);
      ref.invalidate(songsProvider);
      ref.invalidate(songByIdProvider(id));
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<bool> deleteSong(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteSong(id);
      state = const AsyncValue.data(null);
      ref.invalidate(songsProvider);
      ref.invalidate(currentSongsProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<SongHistory?> addSongHistory({
    required int songId,
    required String date,
    String? conductorName,
    int? attendanceId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.addSongHistory(
        songId: songId,
        date: date,
        conductorName: conductorName,
        attendanceId: attendanceId,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(songHistoryProvider(songId));
      ref.invalidate(songHistoryProvider(null));
      ref.invalidate(songsProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
}

final songNotifierProvider =
    NotifierProvider<SongNotifier, AsyncValue<void>>(() {
  return SongNotifier();
});

/// Notifier for song category mutations (CRUD operations)
class SongCategoryNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  SongRepository get _repo => ref.read(songRepositoryWithTenantProvider);

  /// Add a new song category
  Future<SongCategory?> add(String name) async {
    final repo = _repo; // SOL_FIX4: bind the tenant repository before the first await.
    state = const AsyncValue.loading();
    try {
      final categories = await repo.getSongCategories();
      final result = await repo.addSongCategory(
        name: name,
        // Sol review: deleting no longer renumbers, so continue after the
        // highest index instead of using the count (avoids duplicates).
        index: categories.fold<int>(
                -1, (m, c) => c.index > m ? c.index : m) +
            1,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(songCategoriesProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Update a song category name
  Future<bool> update(String id, String name) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateSongCategory(id, {'name': name});
      state = const AsyncValue.data(null);
      ref.invalidate(songCategoriesProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Delete a song category
  Future<bool> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteSongCategory(id);
      state = const AsyncValue.data(null);
      ref.invalidate(songCategoriesProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Reorder categories
  Future<bool> reorder(List<SongCategory> categories) async {
    state = const AsyncValue.loading();
    // SOL_FIX3: bind the per-tenant repository once for the whole loop.
    final repo = _repo;
    try {
      for (int i = 0; i < categories.length; i++) {
        final category = categories[i];
        if (category.id != null) {
          await repo.updateSongCategory(category.id!, {'index': i});
        }
      }
      state = const AsyncValue.data(null);
      ref.invalidate(songCategoriesProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final songCategoryNotifierProvider =
    NotifierProvider<SongCategoryNotifier, AsyncValue<void>>(() {
  return SongCategoryNotifier();
});

// ============================================================================
// Group directory helpers (Gruppenverzeichnis)
// ============================================================================

/// Virtual group id for the "Dirigenten" entry (all scores / Partituren)
const int songConductorGroupId = -1;

/// Virtual group id for the "Chor (alle)" entry in choirs (Ionic 4.17.16
/// `CHOIR_ALL_GROUP_ID`): all files meant for the whole choir.
const int songChoirAllGroupId = -2;

/// Ionic `isScoreFile`: file without instrument and note "Partitur".
bool isScoreFile(SongFile file) =>
    file.instrumentId == null && file.note == 'Partitur';

/// Groups (sorted by name) with at least one file, plus a virtual
/// "Dirigenten" group first if any score exists (Ionic `buildGroupsWithFiles`).
/// In choirs ([isChoir]) a virtual "Chor (alle)" group follows when any file
/// is meant for the whole choir (Ionic 4.17.16).
/// [conductorsLabel] / [choirAllLabel]: pass the widget's l10n labels so they
/// follow a language switch (REVIEW_FIX2).
List<Group> buildGroupsWithFiles(
  List<Song> songs,
  List<Group> groups, {
  String? conductorsLabel,
  bool isChoir = false,
  String? choirAllLabel,
}) {
  final ids = <int>{};
  var hasScores = false;
  var hasChoirAll = false;
  for (final song in songs) {
    for (final file in song.files ?? const <SongFile>[]) {
      final id = file.instrumentId;
      if (id != null && id > 2) {
        ids.add(id);
      } else if (isScoreFile(file)) {
        hasScores = true;
      } else if (isChoir && isChoirAllFile(instrumentId: id, note: file.note)) {
        hasChoirAll = true;
      }
    }
  }
  final result = groups
      .where((g) => g.maingroup != true && g.id != null && ids.contains(g.id))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  if (hasChoirAll) {
    result.insert(0, Group(id: songChoirAllGroupId, name: choirAllLabel ?? l10nWithoutContext.songsChoirAll));
  }
  if (hasScores) {
    result.insert(0, Group(id: songConductorGroupId, name: conductorsLabel ?? l10nWithoutContext.songsConductors));
  }
  return result;
}

/// Files of a group (or all scores for the virtual conductor group, all
/// "Chor (alle)" files for the virtual choir group).
List<({Song song, SongFile file})> filesForGroup(List<Song> songs, int groupId) {
  final result = <({Song song, SongFile file})>[];
  for (final song in songs) {
    for (final file in song.files ?? const <SongFile>[]) {
      final matches = groupId == songConductorGroupId
          ? isScoreFile(file)
          : groupId == songChoirAllGroupId
              ? isChoirAllFile(instrumentId: file.instrumentId, note: file.note)
              : file.instrumentId == groupId;
      if (matches) result.add((song: song, file: file));
    }
  }
  return result;
}
