/// Pure helpers for the performance history page (Ionic history.page.ts).
library;

import '../../l10n/l10n.dart';

/// All plans of a Termin: `plan` plus `extra_plans` (Ionic `allPlans`).
List<Map<String, dynamic>> allPlansOf(Map<String, dynamic> attendance) {
  final plan = attendance['plan'];
  if (plan is! Map) return const [];
  final extra = attendance['extra_plans'];
  return [
    Map<String, dynamic>.from(plan),
    if (extra is List)
      for (final p in extra)
        if (p is Map) Map<String, dynamic>.from(p),
  ];
}

/// Ionic `isSongInPlan`: the rehearsal (type `uebung`) happened within the
/// four months before [performanceDate] and one of its plans contains the song.
bool isSongInPlan(
  Map<String, dynamic> attendance,
  int songId,
  DateTime performanceDate,
) {
  if (attendance['type'] != 'uebung' || attendance['plan'] == null) {
    return false;
  }
  final attDate = DateTime.tryParse(attendance['date']?.toString() ?? '');
  if (attDate == null) return false;

  final windowStart = DateTime(
    performanceDate.year,
    performanceDate.month - 4,
    performanceDate.day,
    performanceDate.hour,
    performanceDate.minute,
  );
  if (!attDate.isBefore(performanceDate) || !attDate.isAfter(windowStart)) {
    return false;
  }

  final id = songId.toString();
  return allPlansOf(attendance).any((plan) {
    final fields = plan['fields'];
    if (fields is! List) return false;
    return fields.any((f) => f is Map && f['id']?.toString() == id);
  });
}

/// Number of rehearsals in which the song was practised before the
/// performance (Ionic `count`).
int countRehearsalsForSong(
  List<Map<String, dynamic>> attendances,
  int songId,
  String performanceDate,
) {
  final date = DateTime.tryParse(performanceDate);
  if (date == null) return 0;
  return attendances.where((a) => isSongInPlan(a, songId, date)).length;
}

/// Plural label for the rehearsal badge (Ionic `history.rehearsals`).
String rehearsalsLabel(int count) => l10nWithoutContext.historyRehearsals(count);
