import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/models/song/song.dart';
import '../../../attendance/presentation/attendance_song_history.dart';
import '../../../attendance/presentation/widgets/songs_selection_sheet.dart' show SongHistoryEntry;
import '../../../planning/presentation/widgets/plan_song_helper.dart';

/// The Werke planned for one Termin, as a Probe can take them over
/// ("Adventskonzert", its date, the Werke with their conductors).
typedef RdWorksSource = ({PlanAttendance att, String name, List<SongHistoryEntry> entries});

/// REDESIGN: the coming Auftritte (hervorgehobene Terminart) whose Werke
/// the Termin [attendanceId] can take over, nearest first (see
/// [PlanSongHelper.eventWorks]). A Probe without Werke of its own shows
/// those of the first one.
///
/// Empty for an Auftritt itself, for a Termin of a past day, for groups of
/// type "general" and when the Termin is not among the loaded ones. Every
/// query behind it filters by the tenant.
final rdEventWorksSourcesProvider = FutureProvider.autoDispose.family<List<RdWorksSource>, int>((
  ref,
  attendanceId,
) async {
  if (ref.watch(currentTenantProvider.select((t) => t?.type)) == 'general') return const [];
  final attendances = await ref.watch(planAttendancesProvider.future);
  final att = attendances.where((a) => a.id == attendanceId).firstOrNull;
  if (att == null) return const [];
  final types = await ref.watch(planAttendanceTypesProvider.future);
  if (PlanSongHelper.isAuftritt(att, types)) return const [];
  final day = DateTime.tryParse(att.date);
  final now = DateTime.now();
  if (day == null || day.isBefore(DateTime(now.year, now.month, now.day))) return const [];
  final history = [for (final group in await ref.watch(currentSongsProvider.future)) ...group.history];
  final songs = await ref.watch(songsProvider.future);
  final sources = PlanSongHelper.eventWorks(
    att,
    attendances: attendances,
    types: types,
    history: history,
    songs: songs,
    limit: 4,
    distinct: false,
  );
  return [
    for (final source in sources)
      if (!source.own && PlanSongHelper.isAuftritt(source.att, types))
        (
          att: source.att,
          name:
              (source.att.typeInfo?.isNotEmpty ?? false)
                  ? source.att.typeInfo!
                  : (types.where((t) => t.id == source.att.typeId).firstOrNull?.name ?? ''),
          entries: [
            for (final work in source.works)
              () {
                final row = history.where((h) => h.attendanceId == source.att.id && h.songId == work.song.id).firstOrNull;
                final other = row?.otherConductor;
                final person = other?.isNotEmpty == true ? null : row?.personId;
                return SongHistoryEntry(
                  songId: work.song.id!,
                  songName: work.song.displayName,
                  conductorId: person,
                  conductorName: person == null ? null : row?.conductorName,
                  otherConductor: other?.isNotEmpty == true ? other : null,
                );
              }(),
          ],
        ),
  ];
});

/// The Werke the Termin shows: its own ones, else those of the next
/// Auftritt ([source], "die Liste folgt dem Auftritt").
typedef RdEventWorks = ({
  List<SongHistoryEntry> entries,
  bool own,
  RdWorksSource? source,
  List<RdWorksSource> sources,
});

/// REDESIGN: Werke of the Termin [attendanceId] for the Überblick, the
/// hint in the Reiter Programm and the Ablauf (see [RdEventWorks]).
final rdEventWorksProvider = FutureProvider.autoDispose.family<RdEventWorks, int>((ref, attendanceId) async {
  final stored = await ref.watch(attendanceSongEntriesProvider(attendanceId).future);
  List<RdWorksSource> sources;
  try {
    sources = await ref.watch(rdEventWorksSourcesProvider(attendanceId).future);
  } catch (_) {
    // The Termin's own Werke show also when the Auftritte did not load.
    sources = const [];
  }
  final own = stored.isNotEmpty;
  final source = own || sources.isEmpty ? null : sources.first;
  return (entries: source?.entries ?? stored, own: own, source: source, sources: sources);
});
