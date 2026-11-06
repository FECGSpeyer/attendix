import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/attendance_providers.dart';
import '../../../core/providers/conductor_providers.dart';
import '../../../core/providers/song_providers.dart';
import '../../../core/utils/attendance_logic_utils.dart';
import '../../../data/models/person/person.dart';
import '../../../data/models/song/song.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../l10n/l10n.dart';
import 'widgets/songs_selection_sheet.dart';

// Werke of a Termin (table `history`), shared by the Termin page and the
// Termin page of the new design.

/// Loads the Werke of [attendanceId] with song and conductor names. Like
/// Ionic (getHistoryByAttendanceId) the history table is the only source;
/// the legacy attendance.songs/conductors arrays are neither read nor
/// written. Null when the tenant is not known yet.
Future<List<SongHistoryEntry>?> loadAttendanceSongEntries({
  required AttendanceRepository repo,
  required Future<List<Song>> songsFuture,
  required Future<List<Person>> conductorsFuture,
  required int attendanceId,
}) async {
  final songs = await songsFuture;
  final allConductors = await conductorsFuture;
  if (!repo.hasTenantId) return null;
  final rows = await repo.getHistoryForAttendance(attendanceId);
  return [
    for (final row in rows)
      () {
        final songId = (row['songId'] as num).toInt();
        final personId = (row['person_id'] as num?)?.toInt();
        final other = row['otherConductor'] as String?;
        final song = songs.where((s) => s.id == songId).firstOrNull;
        final conductor = allConductors.where((c) => c.id == personId).firstOrNull;
        return SongHistoryEntry(
          songId: songId,
          songName: song?.displayName ?? l10nWithoutContext.historyFlutterUnknownSong,
          conductorId: personId,
          conductorName: conductor?.fullName,
          otherConductor: other?.isNotEmpty == true ? other : null,
        );
      }(),
  ];
}

/// Brings the history rows of [attendanceId] to [entries]. Like Ionic only
/// the history table is written (no legacy attendance.songs / conductors),
/// row by row so unchanged entries keep their id, created_at and visible
/// flag. Every query of [repo] filters by the tenant.
Future<void> syncAttendanceSongHistory(
  AttendanceRepository repo,
  int attendanceId,
  String date,
  List<SongHistoryEntry> entries,
) async {
  final songEntries = List.of(entries);
  final rows = await repo.getHistoryForAttendance(attendanceId);
  final plan = planHistorySync(
    [
      for (final r in rows)
        (
          id: (r['id'] as num).toInt(),
          songId: (r['songId'] as num).toInt(),
          personId: (r['person_id'] as num?)?.toInt(),
          otherConductor: r['otherConductor'] as String?,
        ),
    ],
    [
      for (final e in songEntries)
        (
          songId: e.songId,
          personId: e.otherConductor?.isNotEmpty == true ? null : e.conductorId,
          otherConductor: e.otherConductor?.isNotEmpty == true ? e.otherConductor : null,
        ),
    ],
  );

  for (final id in plan.delete) {
    await repo.deleteHistoryEntry(id);
  }
  for (final u in plan.update) {
    await repo.updateHistoryEntry(u.id, {
      'person_id': u.entry.personId,
      'otherConductor': u.entry.otherConductor,
    });
  }
  // Ionic addSongsToHistory: History columns songId (camelCase),
  // person_id, otherConductor, visible: true, date of the Termin.
  await repo.addHistoryEntries([
    for (final e in plan.insert)
      {
        'songId': e.songId,
        'attendance_id': attendanceId,
        'date': date,
        'person_id': e.personId,
        'otherConductor': e.otherConductor,
        'visible': true,
      },
  ]);
}

/// Werke of a Termin for the new design (reloaded after each change).
final attendanceSongEntriesProvider =
    FutureProvider.autoDispose.family<List<SongHistoryEntry>, int>((ref, attendanceId) async {
  final entries = await loadAttendanceSongEntries(
    repo: ref.watch(attendanceRepositoryWithTenantProvider),
    songsFuture: ref.watch(songsProvider.future),
    conductorsFuture: ref.watch(conductorsProvider.future),
    attendanceId: attendanceId,
  );
  return entries ?? const [];
});
