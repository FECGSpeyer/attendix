import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/utils/attendance_songs.dart';
import '../../../../core/utils/event_list_utils.dart';
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

/// Ionic 4.17.26/27: Werke selected for each Termin of "Meine Termine"
/// (own past and upcoming Termine), by Termin id. Feeds the "♪ n Werke" chip,
/// the Werke sheet and "Aktuelle Werke".
final signoutAttendanceSongsProvider =
    FutureProvider<Map<int, List<AttendanceSong>>>((ref) async {
  final data = await ref.watch(signoutDataProvider.future);
  final ids = [...data.allUpcoming, ...data.past]
      .map((a) => a.attendanceId)
      .whereType<int>()
      .toList();
  if (ids.isEmpty) return const {};
  final repo = ref.watch(songRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return const {};
  List<SongHistory> history;
  try {
    history = await repo.getHistoryForAttendances(ids);
  } catch (_) {
    // Ionic: logged, the page works without the Werke.
    history = const [];
  }
  if (history.isEmpty) return const {};
  final songs = await ref.watch(songsProvider.future);
  return songsByAttendance(history, songs);
});

/// "Aktuelle Werke" of "Meine Termine" (Ionic 4.17.26 `upcomingSongs`): the
/// Werke of the own Termine from today on, one group per Termin, ascending.
final upcomingSongsProvider =
    FutureProvider<List<UpcomingSongGroup>>((ref) async {
  // Account switch rebuilds the list (signoutDataProvider is per account).
  ref.watch(currentAuthUserIdProvider);
  final data = await ref.watch(signoutDataProvider.future);
  final byAttendance = await ref.watch(signoutAttendanceSongsProvider.future);
  if (byAttendance.isEmpty) return [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final seen = <int>{};
  final atts = [...data.allUpcoming, ...data.past].where((a) {
    final id = a.attendanceId;
    final date = EventListUtils.parse(a.date);
    if (id == null || date == null || !byAttendance.containsKey(id)) return false;
    if (DateTime(date.year, date.month, date.day).isBefore(today)) return false;
    return seen.add(id);
  }).toList()
    ..sort((a, b) => (EventListUtils.parse(a.date) ?? now)
        .compareTo(EventListUtils.parse(b.date) ?? now));
  return [
    for (final att in atts)
      UpcomingSongGroup(
        date: att.date ?? '',
        typeInfo: att.eventTitle,
        attendanceId: att.attendanceId,
        songs: [
          for (final entry in byAttendance[att.attendanceId]!)
            entry.toHistory(att.attendanceId!),
        ],
      ),
  ];
});

/// Provider to get the current user's instrument ID
///
/// PARITY_SELF: Ionic uses `this.player.instrument` – the person of the
/// current instance (appId AND tenantId, multi-tenant rule), not any person
/// of the account in another instance.
final currentPlayerInstrumentProvider = FutureProvider<int?>((ref) async {
  final player = await ref.watch(currentSelfServicePlayerProvider.future);
  return player?.instrument;
});
