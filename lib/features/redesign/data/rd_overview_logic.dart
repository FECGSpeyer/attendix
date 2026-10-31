import '../../../data/models/person/person.dart';
import '../../../data/models/song/song.dart';
import 'rd_members_logic.dart' show rdDaysToBirthday;

/// REDESIGN: pure logic of the overview shown in the empty detail column of
/// the split view (Werke / Mitglieder, nothing chosen on the left).

class RdWorksOverview {
  const RdWorksOverview({
    required this.total,
    required this.withFiles,
    required this.nextDate,
    required this.next,
    required this.missing,
    required this.longAgo,
  });

  final int total;

  /// Works with at least one file.
  final int withFiles;
  int get withoutFiles => total - withFiles;

  /// Day of the nearest planned (future) entry and the works planned then.
  final DateTime? nextDate;
  final List<Song> next;

  /// Works without any file, by number / name.
  final List<Song> missing;

  /// Works played before, the longest ago first.
  final List<Song> longAgo;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? _localDay(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? null : _day(d.toLocal());
}

RdWorksOverview rdWorksOverview(List<Song> songs, {DateTime? now, int longAgoCount = 5}) {
  final today = _day(now ?? DateTime.now());
  final withFiles = songs.where((s) => (s.files ?? const []).isNotEmpty).length;

  DateTime? nextDate;
  for (final s in songs) {
    final d = _localDay(s.nextPlanned);
    if (d == null || d.isBefore(today)) continue;
    if (nextDate == null || d.isBefore(nextDate)) nextDate = d;
  }
  final next = nextDate == null ? const <Song>[] : songs.where((s) => _localDay(s.nextPlanned) == nextDate).toList();

  final missing = songs.where((s) => (s.files ?? const []).isEmpty).toList();

  final played = [
    for (final s in songs)
      if (_localDay(s.lastSung) != null) (song: s, day: _localDay(s.lastSung)!),
  ]..sort((a, b) => a.day.compareTo(b.day));
  // A work already planned again is not "long ago".
  bool plannedAgain(Song s) {
    final d = _localDay(s.nextPlanned);
    return d != null && !d.isBefore(today);
  }

  final longAgo =
      [
        for (final e in played)
          if (!plannedAgain(e.song)) e.song,
      ].take(longAgoCount).toList();

  return RdWorksOverview(
    total: songs.length,
    withFiles: withFiles,
    nextDate: nextDate,
    next: next,
    missing: missing,
    longAgo: longAgo,
  );
}

class RdMembersOverview {
  const RdMembersOverview({
    required this.active,
    required this.paused,
    required this.birthdays,
    required this.critical,
  });

  final int active;
  final int paused;

  /// Active people with a birthday in the next days, the nearest first.
  final List<({Person person, int days})> birthdays;

  /// Active people marked critical (attendance), by last name.
  final List<Person> critical;
}

RdMembersOverview rdMembersOverview(List<Person> people, {DateTime? now, int birthdayDays = 30}) {
  final active = people.where((x) => !x.paused).toList();
  final birthdays = [
    for (final x in active)
      if (rdDaysToBirthday(x.birthday, now: now) case final days? when days <= birthdayDays) (person: x, days: days),
  ]..sort((a, b) => a.days.compareTo(b.days));
  final critical =
      active.where((x) => x.isCritical).toList()
        ..sort((a, b) => a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()));
  return RdMembersOverview(
    active: active.length,
    paused: people.length - active.length,
    birthdays: birthdays,
    critical: critical,
  );
}
