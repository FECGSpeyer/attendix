import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../../data/models/history/history_entry.dart';
import '../../data/models/song/song.dart';
import '../../features/history/history_utils.dart';
import 'conductor_providers.dart';
import 'song_providers.dart';
import 'tenant_providers.dart';

/// Provider for performance history (song performances/Aufführungen).
///
/// Ionic history.page parity: the DB column is `songId`, hidden entries
/// (`visible = false`) are skipped, the date of a linked Termin wins, the
/// conductor name comes from `person_id`, and `count` is the number of
/// rehearsals (type `uebung`) in the four months before whose plan
/// contains the song.
final performanceHistoryProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  if (tenant == null) return [];

  final conductors = await ref.watch(conductorsProvider.future);
  final conductorNames = {
    for (final c in conductors)
      if (c.id != null) c.id!: '${c.firstName} ${c.lastName}',
  };

  final response = await supabase
      .from('history')
      .select('*, song:songId(name, number), attendance:attendance_id(date)')
      .eq('tenantId', tenant.id!)
      .eq('visible', true)
      .order('date', ascending: false);

  final rehearsals = await supabase
      .from('attendance')
      .select('*')
      .eq('tenantId', tenant.id!)
      .eq('type', 'uebung')
      .not('plan', 'is', null);
  final rehearsalRows = (rehearsals as List).cast<Map<String, dynamic>>();

  return (response as List).map((e) {
    final songData = e['song'] as Map<String, dynamic>?;
    final attendanceData = e['attendance'] as Map<String, dynamic>?;
    final songId = e['songId'] as int? ?? 0;
    final date = attendanceData?['date'] as String? ??
        e['date'] as String? ??
        DateTime.now().toIso8601String();
    final personId = e['person_id'] as int?;
    return HistoryEntry(
      id: e['id'] as int?,
      songId: songId,
      songName: songData?['name'] as String?,
      songNumber: songData?['number']?.toString(),
      personId: personId,
      conductorName: personId != null ? conductorNames[personId] : null,
      otherConductor: e['otherConductor'] as String?,
      date: date,
      attendanceId: e['attendance_id'] as int?,
      count: countRehearsalsForSong(rehearsalRows, songId, date),
    );
  }).toList();
});

/// Provider for songs (for history page add dialog).
///
/// Ionic history.page `db.getSongs()`: songs of the effective song library
/// (Werk-Synchronisierung source tenant), loaded in pages of 1000.
final planSongsProviderHistory = FutureProvider<List<Song>>((ref) async {
  // Wait for the song source tenant so synced instances never read their
  // own (empty) library.
  await ref.watch(songTenantSettingsProvider.future);
  final repo = ref.watch(songRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getSongs();
});
