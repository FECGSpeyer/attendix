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
import '../models/song/song.dart';
import '../models/song/song_additional_field.dart';
import 'base_repository.dart';
import '../../l10n/l10n.dart';

/// Provider for SongRepository
final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository(ref);
});

/// SOL_FIX1: one immutable repository instance per (tenant, song source
/// tenant). A running multi-step operation (paged getSongs + offline cache
/// write) keeps its tenant even when the user switches tenants, so data of
/// tenant B is never cached under tenant A's key.
final songRepositoryForTenantProvider = Provider.family<SongRepository,
    ({int? tenantId, int? songSourceTenantId})>((ref, key) {
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

/// Repository for song operations.
///
/// Werk-Synchronisierung (Ionic `add_song_source_tenant_id.sql`): a tenant can
/// use the song library of another tenant (`tenants.song_source_tenant_id`).
/// All queries on `songs` and `song_categories` therefore filter by
/// [songTenantId] (= source tenant, or the current tenant when not synced),
/// while `history` stays per tenant and filters by [currentTenantId].
class SongRepository extends BaseRepository with TenantAwareRepository {
  SongRepository(super.ref);

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

  // ==========================================================================
  // Songs
  // ==========================================================================

  /// Ionic song.service `offline_songs_v1_<tenantId>` storage key.
  /// SOL_FIX7: additionally bound to the signed-in user (cleared on sign-out).
  static String offlineSongsCacheKey(String userId, int tenantId) =>
      'offline_songs_v1_${userId}_$tenantId';

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
    return userId == null ? null : offlineSongsCacheKey(userId, tenantId);
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
    final cacheKey = _offlineSongsKey(tenantId); // SOL_FIX7
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

      final files = (existing?['files'] as List?) ?? const [];
      final paths = files
          .whereType<Map>()
          .map((f) => (f['storageName'] ?? f['fileName'])?.toString())
          .whereType<String>()
          .map((name) => 'songs/$songTenantId/$id/$name')
          .toList();
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
          .order('number', nullsFirst: false)
          .order('name')
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
      final sourceId = songTenantId;
      final response = await supabase
          .from('tenants')
          .select('id, shortName')
          .or('id.eq.$sourceId,song_source_tenant_id.eq.$sourceId');

      return (response as List)
          .where((t) => (t['id'] as num?)?.toInt() != currentTenantId)
          .map((t) => t['shortName']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getSyncedTenantNames');
      rethrow;
    }
  }

  // ==========================================================================
  // Song Categories
  // ==========================================================================

  /// Get song categories of the effective song tenant
  Future<List<SongCategory>> getSongCategories() async {
    try {
      final response = await supabase
          .from('song_categories')
          .select('*')
          .eq('tenant_id', songTenantId)
          .order('index');

      return (response as List)
          .map((e) => SongCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getSongCategories');
      rethrow;
    }
  }

  /// Create a new song category
  Future<SongCategory> addSongCategory({
    required String name,
    required int index,
  }) async {
    ensureNotDemo('addSongCategory'); // DEMO_GUARD
    try {
      final response = await supabase
          .from('song_categories')
          .insert({
            'tenant_id': songTenantId,
            'name': name,
            'index': index,
          })
          .select()
          .single();

      return SongCategory.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'addSongCategory');
      rethrow;
    }
  }

  /// Update a song category
  Future<void> updateSongCategory(String id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateSongCategory'); // DEMO_GUARD
    try {
      await supabase
          .from('song_categories')
          .update(updates)
          .eq('id', id)
          .eq('tenant_id', songTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateSongCategory');
      rethrow;
    }
  }

  /// Delete a song category (Ionic removeSongCategory: delete only).
  /// PARITY_B (D8): the remaining categories are NOT renumbered.
  Future<void> deleteSongCategory(String id) async {
    ensureNotDemo('deleteSongCategory'); // DEMO_GUARD
    try {
      await supabase
          .from('song_categories')
          .delete()
          .eq('id', id)
          .eq('tenant_id', songTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteSongCategory');
      rethrow;
    }
  }

  // ==========================================================================
  // History (per tenant - NOT the song source tenant)
  // ==========================================================================

  /// All visible history entries of the current tenant, newest first
  /// (Ionic `HistoryService.getHistory`). Includes planned future entries.
  Future<List<SongHistory>> getHistory() async {
    try {
      final response = await supabase
          .from('history')
          .select('*, attendance:attendance_id(date), person:person_id(firstName, lastName)')
          .eq('tenantId', currentTenantId)
          .eq('visible', true)
          .order('date', ascending: false);

      return (response as List)
          .map((e) => _historyFromRow(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getHistory');
      rethrow;
    }
  }

  /// Werkhistorie of a single song (Ionic `getHistoryBySongId`).
  Future<List<SongHistory>> getHistoryBySongId(int songId) async {
    try {
      final response = await supabase
          .from('history')
          .select(
            '*, attendance:attendance_id(date, type_id, typeInfo, att_type:type_id(name, hide_name)), person:person_id(firstName, lastName)',
          )
          .eq('tenantId', currentTenantId)
          .eq('songId', songId)
          .eq('visible', true)
          .order('date', ascending: false);

      return (response as List)
          .map((e) => _historyFromRow(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getHistoryBySongId');
      rethrow;
    }
  }

  /// Get song history entries (optionally for one song)
  Future<List<SongHistory>> getSongHistory({int? songId, int? limit}) async {
    try {
      var baseQuery = supabase
          .from('history')
          .select('*, song:songId(*), person:person_id(firstName, lastName)')
          .eq('tenantId', currentTenantId);

      if (songId != null) {
        baseQuery = baseQuery.eq('songId', songId);
      }

      var query = baseQuery.order('date', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      return (response as List)
          .map((e) => _historyFromRow(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getSongHistory');
      rethrow;
    }
  }

  /// Add a song history entry
  /// BL-014: Validates that songId belongs to the song library before insert
  Future<SongHistory> addSongHistory({
    required int songId,
    required String date,
    String? conductorName,
    int? attendanceId,
  }) async {
    ensureNotDemo('addSongHistory'); // DEMO_GUARD
    try {
      final songValidation = await supabase
          .from('songs')
          .select('id')
          .eq('id', songId)
          .eq('tenantId', songTenantId)
          .maybeSingle();

      if (songValidation == null) {
        throw RepositoryException(
          message: l10nWithoutContext.coreFlutterRepoSongNotFoundOrDenied,
          operation: 'addSongHistory',
        );
      }

      final response = await supabase
          .from('history')
          .insert({
            'tenantId': currentTenantId,
            'songId': songId,
            'date': date,
            'otherConductor': conductorName,
            'attendance_id': attendanceId,
            'visible': true,
          })
          .select()
          .single();

      return _historyFromRow(response);
    } catch (e, stack) {
      handleError(e, stack, 'addSongHistory');
      rethrow;
    }
  }

  // ==========================================================================
  // Current Songs (all upcoming events)
  // ==========================================================================

  /// Songs of all upcoming events, grouped by date / attendance type.
  Future<List<CurrentSongsGroup>> getCurrentSongs() async {
    try {
      return await loadCurrentSongsForTenant(supabase, currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'getCurrentSongs');
      rethrow;
    }
  }
}

// ============================================================================
// Shared helpers (also used by the public song share page)
// ============================================================================

/// Sort song files by instrumentId like Ionic `getSong`.
Song sortSongFiles(Song song) {
  final files = [...?song.files]
    ..sort((a, b) => (a.instrumentId ?? 0).compareTo(b.instrumentId ?? 0));
  return song.copyWith(files: files);
}

SongHistory _historyFromRow(Map<String, dynamic> row) {
  var history = SongHistory.fromJson(row);
  final person = row['person'];
  final attendance = row['attendance'];
  String? conductorName;
  if (person is Map) {
    conductorName = '${person['firstName'] ?? ''} ${person['lastName'] ?? ''}'.trim();
  } else if ((row['otherConductor'] as String?)?.isNotEmpty == true) {
    conductorName = row['otherConductor'] as String;
  }
  String? typeTitle;
  String? attendanceDate;
  if (attendance is Map) {
    attendanceDate = attendance['date'] as String?;
    final typeInfo = attendance['typeInfo'] as String?;
    final attType = attendance['att_type'];
    if (typeInfo != null && typeInfo.isNotEmpty) {
      typeTitle = typeInfo;
    } else if (attType is Map && attType['name'] != null) {
      typeTitle = attType['name'] as String;
    }
  }
  final songRaw = row['song'];
  history = history.copyWith(
    conductorName: conductorName,
    typeTitle: typeTitle,
    attendanceDate: attendanceDate,
    song: songRaw is Map ? Song.fromJson(Map<String, dynamic>.from(songRaw)) : null,
  );
  return history;
}

/// Ionic `DbService.getCurrentSongs`: history entries after today, grouped by
/// `DD.MM.YYYY` (+ ` | <typeInfo or visible type name>`), dates ascending.
///
/// Explicit [tenantId] so the public share page can use it, too. The history
/// query is always restricted to that tenant.
Future<List<CurrentSongsGroup>> loadCurrentSongsForTenant(
  SupabaseClient supabase,
  int tenantId,
) async {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day).toUtc();

  final response = await supabase
      .from('history')
      .select('''
        id, date, otherConductor, person_id, songId, attendance_id, visible,
        person:person_id(firstName, lastName),
        song:songId(*),
        att:attendance_id(id, date, type_id, typeInfo)
      ''')
      .eq('tenantId', tenantId)
      .gt('date', startOfDay.toIso8601String());

  final typesResponse = await supabase
      .from('attendance_types')
      .select('id, name, hide_name')
      .eq('tenant_id', tenantId);
  final types = <String, Map<String, dynamic>>{
    for (final t in typesResponse as List)
      t['id'].toString(): Map<String, dynamic>.from(t as Map),
  };

  final fmt = DateFormat(dateFmt());
  final grouped = <String, List<(int, SongHistory)>>{};
  final keyDates = <String, DateTime>{};

  for (final raw in response as List) {
    final row = Map<String, dynamic>.from(raw as Map);
    final att = row['att'] is Map ? Map<String, dynamic>.from(row['att'] as Map) : null;
    final dateStr = (att?['date'] ?? row['date'])?.toString();
    final parsed = dateStr != null ? DateTime.tryParse(dateStr)?.toLocal() : null;
    if (parsed == null) continue;
    final dateKey = fmt.format(parsed);

    var groupKey = dateKey;
    if (att != null) {
      final type = types[att['type_id']?.toString()];
      final typeInfo = (att['typeInfo'] as String?)?.isNotEmpty == true
          ? att['typeInfo'] as String
          : (type != null && type['hide_name'] != true ? type['name'] as String? : null);
      if (typeInfo != null && typeInfo.isNotEmpty) {
        groupKey = '$dateKey | $typeInfo';
      }
    }

    final base = _historyFromRow(row);
    final history = base.copyWith(
      attendanceDate: att?['date'] as String?,
      conductorName: base.conductorName ?? '',
    );
    final attId = (att?['id'] as num?)?.toInt() ?? 0;
    grouped.putIfAbsent(groupKey, () => []).add((attId, history));
    keyDates[groupKey] = DateTime(parsed.year, parsed.month, parsed.day);
  }

  int maxId(String key) =>
      grouped[key]!.fold<int>(0, (m, e) => e.$1 > m ? e.$1 : m);

  final keys = grouped.keys.toList()
    ..sort((a, b) {
      final diff = keyDates[a]!.compareTo(keyDates[b]!);
      if (diff != 0) return diff;
      return maxId(a).compareTo(maxId(b));
    });

  return keys.map((key) {
    final entries = [...grouped[key]!]..sort((a, b) => b.$1.compareTo(a.$1));
    return (date: key, history: entries.map((e) => e.$2).toList());
  }).toList();
}
