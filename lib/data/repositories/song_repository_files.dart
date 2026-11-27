part of 'song_repository.dart';

/// Storage path helpers, song history, and upcoming songs for [SongRepository].
mixin _SongFilesAndHistoryMixin on _SongRepositoryCore {
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

  /// Ionic 4.17.26 `HistoryService.getHistoryForAttendances`: Werke of
  /// several Termine for the members' views (song id, Termin, conductor
  /// name). Queried in chunks of 150 ids so long Termin lists stay below the
  /// URL length limit; always restricted to the current tenant.
  Future<List<SongHistory>> getHistoryForAttendances(List<int> attendanceIds) async {
    final ids = attendanceIds.where((id) => id != 0).toSet().toList();
    if (ids.isEmpty) return const [];
    try {
      final result = <SongHistory>[];
      final tenantId = currentTenantId;
      for (var i = 0; i < ids.length; i += 150) {
        final chunk = ids.sublist(i, i + 150 > ids.length ? ids.length : i + 150);
        // Paged as well: one chunk can hold more rows than PostgREST
        // returns at once (max-rows 1000).
        final rows = await fetchAllPages<dynamic>((from, to) async => await supabase
            .from('history')
            .select('id, songId, attendance_id, otherConductor, person:person_id(firstName, lastName)')
            .eq('tenantId', tenantId)
            .inFilter('attendance_id', chunk)
            .order('id', ascending: true)
            .range(from, to) as List);
        for (final row in rows) {
          final map = row as Map<String, dynamic>;
          final person = map['person'];
          result.add(SongHistory(
            id: (map['id'] as num?)?.toInt(),
            songId: (map['songId'] as num?)?.toInt(),
            attendanceId: (map['attendance_id'] as num?)?.toInt(),
            otherConductor: map['otherConductor'] as String?,
            conductorName: person is Map
                ? '${person['firstName'] ?? ''} ${person['lastName'] ?? ''}'.trim()
                : (map['otherConductor'] as String? ?? ''),
          ));
        }
      }
      return result;
    } catch (e, stack) {
      handleError(e, stack, 'getHistoryForAttendances');
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

List<String> _songStoragePaths(List? files, int tenantId, int songId) {
  return (files ?? const [])
      .whereType<Map>()
      .map((f) => (f['storageName'] ?? f['fileName'])?.toString())
      .whereType<String>()
      .map((name) => 'songs/$tenantId/$songId/$name')
      .toList();
}

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

    final groupKey = _currentSongsGroupKey(fmt.format(parsed), att, types);
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

String _currentSongsGroupKey(
  String dateKey,
  Map<String, dynamic>? att,
  Map<String, Map<String, dynamic>> types,
) {
  if (att == null) return dateKey;
  final type = types[att['type_id']?.toString()];
  final typeInfo = (att['typeInfo'] as String?)?.isNotEmpty == true
      ? att['typeInfo'] as String
      : (type != null && type['hide_name'] != true ? type['name'] as String? : null);
  return typeInfo != null && typeInfo.isNotEmpty ? '$dateKey | $typeInfo' : dateKey;
}
