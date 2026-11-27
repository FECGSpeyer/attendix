import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/attendance_detail_cache.dart'
    show
        OfflineReadCacheGuard,
        isAuthOrPermissionError,
        isOfflineFallbackError,
        purgeOfflineReadCachesFor; // SOL_FIX7, SOL_FIX8, SOL_FIX9
import '../../core/services/offline_queue_service.dart'
    show connectivityCheckProvider;
import '../../core/config/supabase_config.dart' show currentAuthUserIdProvider;
import '../../core/utils/paged_query.dart';
import '../models/song/song.dart';
import '../models/song/song_additional_field.dart';
import 'base_repository.dart';
import '../../l10n/l10n.dart';

part 'song_repository_categories.dart';
part 'song_repository_files.dart';

/// Provider for SongRepository
final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository(ref);
});

/// SOL_FIX1: one immutable repository instance per (tenant, song source
/// tenant). A running multi-step operation (paged getSongs + offline cache
/// write) keeps its tenant even when the user switches tenants, so data of
/// tenant B is never cached under tenant A's key.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch.
final songRepositoryForTenantProvider = Provider.family<SongRepository,
    ({int? tenantId, int? songSourceTenantId})>((ref, key) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(_songRepositoryForAccountProvider((
    tenantId: key.tenantId,
    songSourceTenantId: key.songSourceTenantId,
    userId: userId,
  )));
});

final _songRepositoryForAccountProvider = Provider.family<SongRepository,
    ({int? tenantId, int? songSourceTenantId, String? userId})>((ref, key) {
  final repo = SongRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  repo.setSongSourceTenantId(key.songSourceTenantId);
  return repo;
});

/// Group of current (upcoming) songs: `date` is the display key
/// (`DD.MM.YYYY` or `DD.MM.YYYY | <Typ>`), like Ionic `getCurrentSongs`.
typedef CurrentSongsGroup = ({String date, List<SongHistory> history});

/// Song-related settings stored on the tenant row.
class SongTenantSettings {
  const SongTenantSettings({
    this.songSourceTenantId,
    this.additionalFields = const [],
    this.songSharingId,
  });

  /// Werk-Synchronisierung: tenant whose song library this tenant uses.
  final int? songSourceTenantId;
  final List<SongAdditionalField> additionalFields;
  final String? songSharingId;
}

/// Core state and song CRUD / offline-cache operations shared by mixins.
abstract class _SongRepositoryCore extends BaseRepository
    with TenantAwareRepository {
  _SongRepositoryCore(super.ref);

  static const int _pageSize = 1000;
  static const String _bucket = 'songs';

  int? _songSourceTenantId;

  /// Set the song source tenant (null = own songs).
  void setSongSourceTenantId(int? tenantId) {
    _songSourceTenantId = tenantId;
  }

  /// Tenant owning the song library used by the current tenant.
  int get songTenantId => _songSourceTenantId ?? currentTenantId;

  /// True if the current tenant uses the song library of another tenant.
  bool get isSyncedLibrary =>
      _songSourceTenantId != null && _songSourceTenantId != currentTenantId;

  /// Signed-in auth user, null when signed out (or no auth client in tests).
  String? _signedInUserId() {
    try {
      return supabase.auth.currentUser?.id;
    } catch (_) {
      return null; // no auth client (tests) → no cache
    }
  }

  /// Cache key of the signed-in user, null (no cache) when signed out.
  String? _offlineSongsKey(int tenantId) {
    final userId = _signedInUserId();
    return userId == null
        ? null
        : SongRepository.offlineSongsCacheKey(userId, tenantId);
  }

  /// Get all songs of the (effective) song tenant.
  /// PostgREST caps each response, so songs are loaded in pages.
  ///
  /// Offline cache (Ionic song.service getSongs): offline, the songs are
  /// read from the local cache; online, the loaded list is cached. A failed
  /// load also falls back to the cache when one exists.
  Future<List<Song>> getSongs() async {
    // SOL_FIX1: effective tenant captured once; every page query and the
    // cache key use the same id.
    final tenantId = songTenantId;
    final cacheKey = _offlineSongsKey(tenantId);
    // SOL_FIX9: cache session captured before the load; a result arriving
    // after sign-out / account switch / cache clear is not stored.
    final cacheGuard = OfflineReadCacheGuard.capture(
      userId: _signedInUserId(),
      currentUserId: _signedInUserId,
    );
    // Shared connectivity check (offline_queue_service), never throws.
    if (!await ref.read(connectivityCheckProvider)()) {
      return await _readOfflineSongs(cacheKey) ?? const [];
    }
    try {
      final songs = <Song>[];
      final rawRows = <dynamic>[];
      for (var from = 0;; from += _pageSize) {
        final response = await supabase
            .from('songs')
            .select('*')
            .eq('tenantId', tenantId)
            .order('number', ascending: true)
            .order('id', ascending: true)
            .range(from, from + _pageSize - 1);

        final rows = response as List;
        rawRows.addAll(rows);
        final page = rows
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
        songs.addAll(page);
        if (page.length < _pageSize) break;
      }
      unawaited(_writeOfflineSongs(cacheKey, rawRows, cacheGuard));
      return songs;
    } catch (e, stack) {
      // SOL_FIX8: access revoked -> delete the user's offline copies of this
      // (song) tenant before the error is reported.
      if (cacheKey != null && isAuthOrPermissionError(e)) {
        await _purgeOfflineSongs(cacheKey, tenantId);
      }
      // SOL_FIX7: only network failures fall back to the offline copy.
      final cached =
          isOfflineFallbackError(e) ? await _readOfflineSongs(cacheKey) : null;
      if (cached != null) return cached;
      handleError(e, stack, 'getSongs');
      rethrow;
    }
  }

  Future<List<Song>?> _readOfflineSongs(String? key) async {
    if (key == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return (jsonDecode(raw) as List)
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// SOL_FIX8: removes the songs copy [key] and every other offline read
  /// cache entry of the signed-in user in [tenantId].
  Future<void> _purgeOfflineSongs(String key, int tenantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) await purgeOfflineReadCachesFor(userId, tenantId);
    } catch (_) {
      // Best effort.
    }
  }

  /// Caches the raw `songs` rows (lossless, like Ionic storing the rows).
  /// SOL_FIX9: skipped when [guard]'s session has ended in the meantime.
  Future<void> _writeOfflineSongs(
    String? key,
    List<dynamic> rows,
    OfflineReadCacheGuard guard,
  ) async {
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!guard.isCurrent) return;
      await prefs.setString(key, jsonEncode(rows));
    } catch (_) {
      // Cache is best effort (quota, private mode).
    }
  }

  /// Get a single song by ID (from the effective song tenant).
  Future<Song?> getSongById(int id) async {
    try {
      final response = await supabase
          .from('songs')
          .select('*')
          .eq('id', id)
          .eq('tenantId', songTenantId)
          .maybeSingle();

      if (response == null) return null;
      return sortSongFiles(Song.fromJson(response));
    } catch (e, stack) {
      handleError(e, stack, 'getSongById');
      rethrow;
    }
  }

  /// Create a new song
  Future<Song> createSong(Song song) async {
    ensureNotDemo('createSong'); // DEMO_GUARD
    try {
      // DB_FIX: explicit payload like Ionic songs.page addSong →
      // insert({number, name, link, withChoir, withSolo, instrument_ids,
      // prefix, tenantId}). Song.toJson would also send `composer` (no such
      // column → PGRST204) and nulls over column defaults. Optional song
      // columns are only sent when set.
      final data = <String, dynamic>{
        'number': song.number,
        'name': song.name,
        if (song.link != null) 'link': song.link,
        'withChoir': song.withChoir,
        'withSolo': song.withSolo,
        'instrument_ids': song.instrumentIds ?? const <int>[],
        'prefix': song.prefix ?? '',
        if (song.difficulty != null) 'difficulty': song.difficulty,
        if (song.category != null) 'category': song.category,
        if (song.categoryIds != null) 'category_ids': song.categoryIds,
        if (song.additionalFields != null)
          'additional_fields': song.additionalFields,
        // Only set when the database has Sammlungen (never sent otherwise).
        if (song.collectionId != null) 'collection_id': song.collectionId,
      };
      // Set tenant ID (effective song tenant)
      data['tenantId'] = songTenantId;

      final response = await supabase
          .from('songs')
          .insert(data)
          .select()
          .single();

      return Song.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createSong');
      rethrow;
    }
  }

  /// Update an existing song
  Future<Song> updateSong(int id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateSong'); // DEMO_GUARD
    try {
      // Remove read-only / computed fields
      updates.remove('id');
      updates.remove('created_at');
      updates.remove('createdAt');
      updates.remove('tenantId');
      updates.remove('lastSung');
      updates.remove('nextPlanned');
      updates.remove('conductor');

      final response = await supabase
          .from('songs')
          .update(updates)
          .eq('id', id)
          .eq('tenantId', songTenantId)
          .select()
          .single();

      return Song.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateSong');
      rethrow;
    }
  }

  /// Delete a song including its files in storage (Ionic `removeSong`).
  Future<void> deleteSong(int id) async {
    ensureNotDemo('deleteSong'); // DEMO_GUARD
    try {
      final existing = await supabase
          .from('songs')
          .select('files')
          .eq('id', id)
          .eq('tenantId', songTenantId)
          .maybeSingle();

      final paths = _songStoragePaths(existing?['files'] as List?, songTenantId, id);
      if (paths.isNotEmpty) {
        try {
          await supabase.storage.from(_bucket).remove(paths);
        } catch (_) {
          // Storage cleanup is best effort
        }
      }

      await supabase
          .from('songs')
          .delete()
          .eq('id', id)
          .eq('tenantId', songTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteSong');
      rethrow;
    }
  }

  /// Search songs by name
  Future<List<Song>> searchSongs(String query) async {
    try {
      // SEC-003: Sanitize search input to prevent SQL wildcard injection
      final sanitizedQuery = sanitizeSearchQuery(query);
      final response = await supabase
          .from('songs')
          .select('*')
          .eq('tenantId', songTenantId)
          .ilike('name', '%$sanitizedQuery%')
          .order('number', ascending: true, nullsFirst: false)
          .order('name', ascending: true)
          .limit(50);

      return (response as List)
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'searchSongs');
      rethrow;
    }
  }

  // ==========================================================================
  // Tenant song settings / Werk-Synchronisierung
  // ==========================================================================

  /// Load song related settings of the current tenant.
  /// The `tenants` table has no tenantId column - the row is selected by its
  /// own primary key (= current tenant).
  Future<SongTenantSettings> getSongTenantSettings() async {
    try {
      final response = await supabase
          .from('tenants')
          .select('song_source_tenant_id, song_additional_fields, song_sharing_id')
          .eq('id', currentTenantId)
          .maybeSingle();

      if (response == null) return const SongTenantSettings();
      return SongTenantSettings(
        songSourceTenantId: (response['song_source_tenant_id'] as num?)?.toInt(),
        additionalFields: SongAdditionalField.listFromJson(
          response['song_additional_fields'],
        ),
        songSharingId: response['song_sharing_id'] as String?,
      );
    } catch (e, stack) {
      handleError(e, stack, 'getSongTenantSettings');
      rethrow;
    }
  }

  /// SETTINGS2: Ionic org-settings `saveSongSync` — set the source tenant
  /// whose songs this tenant uses (null = own songs).
  /// `tenants` has no tenantId column - the row is the current tenant itself.
  Future<void> updateSongSourceTenantId(int? sourceTenantId) async {
    ensureNotDemo('updateSongSourceTenantId'); // DEMO_GUARD
    try {
      await supabase
          .from('tenants')
          .update({'song_source_tenant_id': sourceTenantId})
          .eq('id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateSongSourceTenantId');
      rethrow;
    }
  }

  /// Short names of the other instances sharing this song library
  /// (the source instance and every instance using the same source).
  /// `tenants` has no tenantId column - filtered by the song library owner.
  Future<List<String>> getSyncedTenantNames() async {
    try {
      return (await _libraryTenants())
          .where((t) => t.id != currentTenantId && t.name.isNotEmpty)
          .map((t) => t.name)
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getSyncedTenantNames');
      rethrow;
    }
  }

  /// Short name of the instance whose Werke this one shows; null for the own
  /// library or when that instance cannot be read.
  Future<String?> getSongSourceName() async {
    if (!isSyncedLibrary) return null;
    try {
      final name = (await _libraryTenants())
          .where((t) => t.id == songTenantId)
          .firstOrNull
          ?.name;
      return name == null || name.isEmpty ? null : name;
    } catch (e, stack) {
      handleError(e, stack, 'getSongSourceName');
      rethrow;
    }
  }

  /// The owner of the song library and every instance showing it.
  Future<List<({int? id, String name})>> _libraryTenants() async {
    final sourceId = songTenantId;
    final response = await supabase
        .from('tenants')
        .select('id, shortName')
        .or('id.eq.$sourceId,song_source_tenant_id.eq.$sourceId');

    return (response as List)
        .map((t) => (
              id: (t['id'] as num?)?.toInt(),
              name: t['shortName']?.toString() ?? '',
            ))
        .toList();
  }
}

/// Repository for song operations.
///
/// Werk-Synchronisierung (Ionic `add_song_source_tenant_id.sql`): a tenant can
/// use the song library of another tenant (`tenants.song_source_tenant_id`).
/// All queries on `songs` and `song_categories` therefore filter by
/// [songTenantId] (= source tenant, or the current tenant when not synced),
/// while `history` stays per tenant and filters by [currentTenantId].
class SongRepository extends _SongRepositoryCore
    with _SongCategoriesMixin, _SongFilesAndHistoryMixin {
  SongRepository(super.ref);

  /// Ionic song.service `offline_songs_v1_<tenantId>` storage key.
  /// SOL_FIX7: additionally bound to the signed-in user (cleared on sign-out).
  static String offlineSongsCacheKey(String userId, int tenantId) =>
      'offline_songs_v1_${userId}_$tenantId';

  /// Whether [e] says the database has no Sammlungen yet (the migration
  /// `song_collections.sql` has not run: table or column unknown).
  static bool isMissingCollectionsSchema(Object e) =>
      e is PostgrestException &&
      const {'42P01', 'PGRST205', '42703', 'PGRST204', 'PGRST200'}
          .contains(e.code);
}
