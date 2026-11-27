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

part 'song_notifiers.dart';
part 'song_view_data_providers.dart';

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
    final settings = await repo.getSongTenantSettings();
    _setSongSettingsFailed(ref, false);
    return settings;
  } catch (_) {
    _setSongSettingsFailed(ref, true);
    return const SongTenantSettings();
  }
});

/// Whether the last load of [songTenantSettingsProvider] failed and fell
/// back to the defaults. The Werke then come from the own group even when
/// the group shares another one's library, so an empty list may be wrong
/// and a new Werk would land in the wrong library. The redesign shows an
/// error card instead (the classic pages keep the fallback).
final songTenantSettingsFailedProvider = StateProvider<bool>((ref) {
  ref.watch(currentTenantIdProvider);
  return false;
});

void _setSongSettingsFailed(Ref ref, bool failed) {
  try {
    final flag = ref.read(songTenantSettingsFailedProvider.notifier);
    if (flag.state != failed) flag.state = failed;
  } catch (_) {
    // Disposed while loading (tenant switch): the next load sets it.
  }
}

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

/// Sammlungen of the song library (of the song source tenant), in their
/// order. Null when the database has no Sammlungen yet (migration
/// `song_collections.sql` not run): then everything works as before.
/// Bumped whenever Werke changed their Sammlung or prefix through
/// [SongCollectionNotifier]: song lists loaded on their own (the planning's
/// `planSongsProvider`) watch it and reload.
final songCollectionChangesProvider = StateProvider<int>((ref) => 0);

final songCollectionsProvider = FutureProvider<List<SongCollection>?>((ref) async {
  final repo = await _readySongRepository(ref);

  if (!repo.hasTenantId) return null;

  return repo.getSongCollections();
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

/// True while a Sammlung is deleted with its Werke: the realtime changes
/// then do not reload [songsProvider] after every Werk (that is done once at
/// the end).
final songsBulkDeleteRunningProvider = StateProvider<bool>((ref) => false);

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
    if (ref.read(songsBulkDeleteRunningProvider)) return;
    debounce = Timer(const Duration(milliseconds: 300), () {
      if (ref.read(songsBulkDeleteRunningProvider)) return;
      ref.invalidate(songsProvider);
    });
  }

  // A bulk delete reloads once at its end: no reload waiting from before.
  ref.listen(songsBulkDeleteRunningProvider, (_, running) {
    if (running) debounce?.cancel();
  });

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
