import '../../data/models/song/song.dart';

/// One Werk of a Termin as members see it (Ionic 4.17.26
/// `utilities/attendance-songs.ts`).
class AttendanceSong {
  const AttendanceSong({
    required this.songId,
    required this.song,
    required this.name,
    this.conductorName = '',
  });

  final int songId;
  final Song song;

  /// "12. Name"
  final String name;
  final String conductorName;

  /// As history row for the existing song widgets ("Aktuelle Werke").
  SongHistory toHistory(int attendanceId) => SongHistory(
        songId: songId,
        attendanceId: attendanceId,
        conductorName: conductorName,
        song: song,
      );
}

/// Ionic `songsForAttendance` (4.17.27): the Werke selected for one Termin
/// (its `history` rows) in the order they were added, each Werk once. Werke
/// that are not in this instance's Werke list are left out.
List<AttendanceSong> songsForAttendance(List<SongHistory> history, List<Song> songs) {
  final result = <AttendanceSong>[];
  final seen = <int>{};
  for (final his in history) {
    final songId = his.songId;
    if (songId == null || songId == 0 || seen.contains(songId)) continue;
    final song = songs.where((s) => s.id == songId).firstOrNull;
    if (song == null) continue;
    seen.add(songId);
    result.add(AttendanceSong(
      songId: songId,
      song: song,
      name: '${song.number ?? ''}. ${song.name}',
      conductorName: his.conductorName ?? '',
    ));
  }
  return result;
}

/// Ionic `groupHistoryByAttendance` + `songsForAttendance` for every Termin:
/// Termin id → its Werke (only Termine with at least one Werk).
Map<int, List<AttendanceSong>> songsByAttendance(
  List<SongHistory> history,
  List<Song> songs,
) {
  final grouped = <int, List<SongHistory>>{};
  for (final his in history) {
    final id = his.attendanceId;
    if (id == null || id == 0) continue;
    grouped.putIfAbsent(id, () => []).add(his);
  }
  final result = <int, List<AttendanceSong>>{};
  grouped.forEach((id, rows) {
    final list = songsForAttendance(rows, songs);
    if (list.isNotEmpty) result[id] = list;
  });
  return result;
}
