import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../../data/models/history/history_entry.dart';
import '../../data/models/song/song.dart';
import 'tenant_providers.dart';

/// INTEGRATION: number of rehearsals ("Proben") of [songId] before [date]
/// (Ionic history.page isSongInPlan): Termine of legacy type `uebung` within
/// the 4 months before [date] whose plan(s) contain the song.
int countRehearsals(List<Map<String, dynamic>> attendances, int songId, String date) {
  final ref = DateTime.tryParse(date);
  if (ref == null) return 0;
  final from = DateTime(ref.year, ref.month - 4, ref.day, ref.hour, ref.minute, ref.second);
  final id = '$songId';
  var count = 0;
  for (final att in attendances) {
    if (att['type'] != 'uebung' || att['plan'] == null) continue;
    final d = DateTime.tryParse(att['date']?.toString() ?? '');
    if (d == null || !d.isBefore(ref) || !d.isAfter(from)) continue;
    final plans = [
      att['plan'],
      ...((att['extra_plans'] as List?) ?? const []),
    ].whereType<Map>();
    final inPlan = plans.any((plan) =>
        ((plan['fields'] as List?) ?? const [])
            .whereType<Map>()
            .any((f) => f['id']?.toString() == id));
    if (inPlan) count++;
  }
  return count;
}

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

  // Ionic getAttendance(true): rehearsals with plans for the "Proben" badge.
  var rehearsals = const <Map<String, dynamic>>[];
  try {
    final rows = await supabase
        .from('attendance')
        .select('date, type, plan, extra_plans')
        .eq('tenantId', tenant.id!)
        .eq('type', 'uebung')
        .not('plan', 'is', null)
        .gt('date', '2020-01-01');
    rehearsals = List<Map<String, dynamic>>.from(rows as List);
  } catch (_) {
    // Badge is optional.
  }

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
      count: countRehearsals(
        rehearsals,
        e['songId'] as int,
        attendance?['date'] as String? ?? e['date'] as String? ?? '',
      ),
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
