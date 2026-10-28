import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../../data/models/history/history_entry.dart';
import '../../data/models/song/song.dart';
import 'tenant_providers.dart';

/// Provider for performance history (song performances/Aufführungen)
final performanceHistoryProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  if (tenant == null) return [];

  // Ionic HistoryService.getHistory: only visible rows; column is `songId`
  // (camelCase). conductorName is computed from the person join.
  final response = await supabase
      .from('history')
      .select('*, song:songId(name, number), person:person_id(firstName, lastName), attendance:attendance_id(date)')
      .eq('tenantId', tenant.id!)
      .eq('visible', true)
      .order('date', ascending: false);

  return (response as List).map((e) {
    final songData = e['song'] as Map<String, dynamic>?;
    final person = e['person'] as Map<String, dynamic>?;
    final attendance = e['attendance'] as Map<String, dynamic>?;
    final otherConductor = e['otherConductor'] as String?;
    return HistoryEntry(
      id: e['id'] as int?,
      songId: e['songId'] as int,
      songName: songData?['name'] as String?,
      songNumber: songData?['number']?.toString(),
      personId: e['person_id'] as int?,
      conductorName: person != null
          ? '${person['firstName'] ?? ''} ${person['lastName'] ?? ''}'.trim()
          : otherConductor,
      otherConductor: otherConductor,
      // Ionic groups by attendance.date ?? date.
      date: attendance?['date'] as String? ??
          e['date'] as String? ??
          DateTime.now().toIso8601String(),
      attendanceId: e['attendance_id'] as int?,
      count: 1,
    );
  }).toList();
});

/// Provider for songs (for history page add dialog)
final planSongsProviderHistory = FutureProvider<List<Song>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  if (tenant == null) return [];

  final response = await supabase
      .from('songs')
      .select('*')
      .eq('tenantId', tenant.id!)
      .order('number')
      .order('name');

  return (response as List).map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
});
