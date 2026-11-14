import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/attendance_detail_providers.dart';
import '../../../core/providers/attendance_providers.dart';
import '../../../core/providers/attendance_type_providers.dart';
import '../../../core/providers/conductor_providers.dart';
import '../../../core/providers/song_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/services/error_reporter.dart';
import '../../../core/services/offline_queue_service.dart';
import '../../../data/models/person/person.dart';
import '../../../data/models/song/song.dart';
import '../../attendance/presentation/attendance_song_history.dart';
import '../../attendance/presentation/widgets/songs_selection_sheet.dart' show SongHistoryEntry;
import '../presentation/widgets/event/rd_event_now.dart' show rdPlanOf;
import 'providers/rd_event_works_providers.dart';
import 'rd_type_flags.dart';

/// REDESIGN: a Werk that stands in the Ablauf of the Termin
/// [attendanceId] belongs to its Werke (Überblick › "Werke").
///
/// Called after the Ablauf editor stored the Termin. Only adds: a Werk that
/// left the Ablauf stays in the list, and a list that already holds every
/// Werk of the Ablauf is not touched (a Probe keeps following the next
/// Auftritt). When the Probe followed an Auftritt and gets a Werk from
/// outside its list, that list becomes the Probe's own, plus the new Werk.
///
/// Best effort: a failure is reported, the Ablauf itself is stored already.
/// Every query behind it filters by the tenant.
Future<void> rdSyncPlanWorks(ProviderContainer container, int attendanceId) async {
  try {
    if (container.read(currentTenantProvider)?.type == 'general') return;
    final repo = container.read(attendanceRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    final session = container.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    final attendance = await container.read(attendanceDetailProvider(attendanceId).future);
    final plan = attendance == null ? null : rdPlanOf(attendance);
    if (attendance == null || plan == null) return;
    final inPlan = <int, String>{};
    for (final f in plan.fields) {
      final id = f.songId;
      if (id != null) inPlan.putIfAbsent(id, () => (f.conductor ?? '').trim());
    }
    if (inPlan.isEmpty) return;
    final works = await container.read(rdEventWorksProvider(attendanceId).future);
    final listed = {for (final e in works.entries) e.songId};
    if (inPlan.keys.every(listed.contains)) return;

    final songs = await container.read(songsProvider.future);
    final conductors = await container.read(conductorsProvider.future);
    // The latest stored list: nothing else changes.
    final stored = await loadAttendanceSongEntries(
      repo: repo,
      songsFuture: Future.value(songs),
      conductorsFuture: Future.value(conductors),
      attendanceId: attendanceId,
    );
    if (stored == null || !session.isCurrent()) return;
    final base = stored.isNotEmpty ? stored : works.entries;
    final have = {for (final e in base) e.songId};
    final added = <SongHistoryEntry>[];
    for (final entry in inPlan.entries) {
      if (have.contains(entry.key)) continue;
      final song = songs.where((s) => s.id == entry.key).firstOrNull;
      if (song == null) continue; // deleted Werk
      final person = entry.value.isEmpty ? null : conductors.where((c) => c.fullName == entry.value).firstOrNull;
      added.add(SongHistoryEntry(
        songId: entry.key,
        songName: song.displayName,
        conductorId: person?.id,
        conductorName: person?.fullName,
        otherConductor: person == null && entry.value.isNotEmpty ? entry.value : null,
      ));
    }
    if (added.isEmpty) return;
    await syncAttendanceSongHistory(repo, attendanceId, attendance.date, [...base, ...added]);
    container
      ..invalidate(attendanceSongEntriesProvider(attendanceId))
      ..invalidate(currentSongsProvider)
      ..invalidate(songHistoryProvider(null));
    // Like "+ Werk" in the Überblick: the Terminart shows Werke from now on.
    final type = await container.read(attendanceTypeForAttendanceProvider(attendanceId).future);
    if (type != null && !type.manageSongs && session.isCurrent()) {
      await rdEnsureTypeFlags(container.read(attendanceTypeNotifierProvider.notifier), type, songs: true);
    }
  } catch (e, st) {
    ErrorReporter.report(e, st, where: 'rdSyncPlanWorks');
  }
}
