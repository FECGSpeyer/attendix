import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/models/song/song.dart';

/// Group of songs for a specific date/attendance
class UpcomingSongGroup {
  final String date;
  final String? typeInfo;
  final int? attendanceId;
  final List<SongHistory> songs;

  UpcomingSongGroup({
    required this.date,
    this.typeInfo,
    this.attendanceId,
    required this.songs,
  });
}

/// Provider for upcoming songs across all tenants for the current user
final upcomingSongsProvider =
    FutureProvider<List<UpcomingSongGroup>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  // Get all person records for this user
  final personRecords = await supabase
      .from('player')
      .select('id, tenantId, instrument')
      .eq('appId', userId);

  if (personRecords.isEmpty) return [];

  final personIds = (personRecords as List).map((p) => p['id'] as int).toList();
  final tenantIds =
      (personRecords as List).map((p) => p['tenantId'] as int).toSet().toList();

  // Get upcoming attendances for these persons
  final now = DateTime.now().toIso8601String().split('T')[0];
  final upcomingAttendances = await supabase
      .from('attendance')
      .select('id, date, typeInfo')
      .inFilter('tenantId', tenantIds)
      .gte('date', now)
      .order('date', ascending: true)
      .limit(10);

  if ((upcomingAttendances as List).isEmpty) return [];

  final attendanceIds =
      (upcomingAttendances as List).map((a) => a['id'] as int).toList();

  // Get person_attendances to filter only those the user is invited to
  final personAttendances = await supabase
      .from('person_attendances')
      .select('attendance_id')
      .inFilter('person_id', personIds)
      .inFilter('attendance_id', attendanceIds);

  final filteredAttendanceIds = (personAttendances as List)
      .map((pa) => pa['attendance_id'] as int)
      .toSet()
      .toList();

  if (filteredAttendanceIds.isEmpty) return [];

  // Get history entries for these attendances with song data
  final historyResponse = await supabase
      .from('history')
      // Ionic History columns: songId (camelCase), person_id, otherConductor.
      // conductorName/count are computed client-side, not DB columns.
      .select('''
        id, songId, attendance_id, date, person_id, otherConductor,
        song:songId(id, name, number, prefix, link, instrument_ids, files, difficulty),
        person:person_id(firstName, lastName)
      ''')
      .inFilter('tenantId', tenantIds)
      .inFilter('attendance_id', filteredAttendanceIds);

  // Group history entries by attendance
  final Map<int, List<SongHistory>> groupedHistory = {};
  for (final h in historyResponse as List) {
    final attendanceId = h['attendance_id'] as int?;
    if (attendanceId == null) continue;

    final songData = h['song'] as Map<String, dynamic>?;
    final person = h['person'] as Map<String, dynamic>?;
    final otherConductor = h['otherConductor'] as String?;
    final history = SongHistory(
      id: h['id'] as int?,
      songId: h['songId'] as int?,
      attendanceId: attendanceId,
      personId: h['person_id'] as int?,
      date: h['date'] as String?,
      conductorName: person != null
          ? '${person['firstName'] ?? ''} ${person['lastName'] ?? ''}'.trim()
          : otherConductor,
      otherConductor: otherConductor,
      song: songData != null ? Song.fromJson(songData) : null,
    );

    groupedHistory.putIfAbsent(attendanceId, () => []).add(history);
  }

  // Create song groups sorted by date
  final List<UpcomingSongGroup> result = [];
  for (final att in upcomingAttendances) {
    final attendanceId = att['id'] as int;
    final songs = groupedHistory[attendanceId];
    if (songs == null || songs.isEmpty) continue;

    result.add(UpcomingSongGroup(
      date: att['date'] as String? ?? '',
      typeInfo: att['typeInfo'] as String?,
      attendanceId: attendanceId,
      songs: songs,
    ));
  }

  return result;
});

/// Provider to get the current user's instrument ID
final currentPlayerInstrumentProvider = FutureProvider<int?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final response = await supabase
      .from('player')
      .select('instrument')
      .eq('appId', userId)
      .limit(1)
      .maybeSingle();

  return response?['instrument'] as int?;
});
