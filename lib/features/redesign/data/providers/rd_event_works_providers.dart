import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/attendance_logic_utils.dart' show showSongsForType;
import '../../../../core/utils/event_list_utils.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/models/song/song.dart';
import '../../../attendance/presentation/attendance_song_history.dart';
import '../../../attendance/presentation/widgets/songs_selection_sheet.dart' show SongHistoryEntry;
import '../../../planning/presentation/widgets/plan_song_helper.dart';
import '../rd_event_phase.dart';

/// The Werke planned for one Termin, as a Probe can take them over
/// ("Adventskonzert", its date, the Werke with their conductors).
typedef RdWorksSource = ({PlanAttendance att, String name, List<SongHistoryEntry> entries});

/// REDESIGN: the coming Auftritte (hervorgehobene Terminart) whose Werke
/// the Termin [attendanceId] can take over, nearest first (see
/// [PlanSongHelper.eventWorks]). A Probe without Werke of its own shows
/// those of the first one.
///
/// Only a Termin whose Terminart has Werke follows an Auftritt. Empty for
/// an Auftritt itself, for a Termin that is over or archived and for groups
/// of type "general". The Termin and the coming ones are read anew each
/// time (a Termin created or moved since counts). Every query behind it
/// filters by the tenant.
final rdEventWorksSourcesProvider = FutureProvider.autoDispose.family<List<RdWorksSource>, int>((
  ref,
  attendanceId,
) async {
  final tenantType = ref.watch(currentTenantProvider.select((t) => t?.type));
  if (tenantType == 'general') return const [];
  final own = await ref.watch(attendanceDetailProvider(attendanceId).future);
  if (own?.id == null || own!.archived) return const [];
  final type = await ref.watch(attendanceTypeForAttendanceProvider(attendanceId).future);
  if (!showSongsForType(type, tenantType)) return const [];
  final types = await ref.watch(planAttendanceTypesProvider.future);
  final att = PlanAttendance(
    id: own.id,
    tenantId: own.tenantId,
    date: own.date,
    durationDays: own.durationDays,
    typeId: own.typeId,
    typeInfo: own.typeInfo,
    type: own.type,
    startTime: own.startTime,
  );
  if ((type?.highlight ?? false) || PlanSongHelper.isAuftritt(att, types)) return const [];
  final span = rdEventSpan(
    day: EventListUtils.parse(own.date),
    startTime: own.startTime ?? type?.startTime,
    endTime: own.endTime ?? type?.endTime,
    durationDays: rdEffectiveDurationDays(
      own.durationDays,
      typeAllDay: type?.allDay ?? false,
      typeDurationDays: type?.durationDays,
    ),
  );
  if (span == null || rdEventPhase(span) == RdEventPhase.after) return const [];
  final attendances = await ref.watch(comingPlanAttendancesProvider(own.date).future);
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
    auftritteOnly: true,
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
                  conductorName: other?.isNotEmpty == true ? null : row?.conductorName,
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
