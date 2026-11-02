import 'package:uuid/uuid.dart';

import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/song/song.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/choir_file_utils.dart';

/// REDESIGN: pure logic of the Termin details (Überblick sections, Termin
/// bearbeiten, the Programm of Spieler).

/// "Programm" for highlighted types (Vortrag, Konzert), "Werke" otherwise.
String rdProgramTitle(AppLocalizations l10n, AttendanceType? type) =>
    (type?.highlight ?? false) ? l10n.redesignEventProgram : l10n.redesignEventWorks;

/// Start of the Termin for checklist due dates (start time or 19:00, like
/// the Termin page).
DateTime? rdChecklistEventStart(Attendance attendance) {
  final date = DateTime.tryParse(attendance.date);
  if (date == null) return null;
  var hour = 19, minute = 0;
  final start = attendance.startTime;
  if (start != null && start.length >= 5) {
    hour = int.tryParse(start.substring(0, 2)) ?? 19;
    minute = int.tryParse(start.substring(3, 5)) ?? 0;
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}

/// A new checklist item due [hours] before [eventStart] (none without).
ChecklistItem rdNewChecklistItem(String text, int? hours, DateTime? eventStart) {
  final due = hours == null || eventStart == null
      ? null
      : eventStart.subtract(Duration(hours: hours)).toUtc().toIso8601String();
  return ChecklistItem(
    id: const Uuid().v4(),
    text: text,
    deadlineHours: hours,
    completed: false,
    dueDate: due,
  );
}

/// The type's default checklist with fresh ids and due dates (Ionic
/// restoreChecklist).
List<ChecklistItem> rdDefaultChecklist(AttendanceType type, Attendance attendance) {
  final start = rdChecklistEventStart(attendance);
  return [
    for (final item in type.checklist ?? const <ChecklistItem>[])
      rdNewChecklistItem(item.text, item.deadlineHours, start),
  ];
}

/// How urgent an open checklist item is.
enum RdDue { none, soon, overdue }

/// Overdue after the due date, soon within 24 hours of it (Termin page
/// rules); done items and items without a date are never due.
RdDue rdChecklistDue(ChecklistItem item, {DateTime? now}) {
  if (item.completed || item.dueDate == null) return RdDue.none;
  final due = DateTime.tryParse(item.dueDate!);
  if (due == null) return RdDue.none;
  final n = now ?? DateTime.now();
  if (n.isAfter(due)) return RdDue.overdue;
  if (n.isAfter(due.subtract(const Duration(hours: 24)))) return RdDue.soon;
  return RdDue.none;
}

/// "in 2 Tagen", "überfällig seit 3 Tagen" … (Ionic formatDeadline); '' without a date.
String rdChecklistDueText(AppLocalizations l10n, ChecklistItem item, {DateTime? now}) {
  final due = item.dueDate == null ? null : DateTime.tryParse(item.dueDate!);
  if (due == null) return '';
  final diff = due.difference(now ?? DateTime.now());
  if (diff.isNegative) {
    final abs = diff.abs();
    return abs.inDays >= 1 ? l10n.attendanceOverdueDays(abs.inDays) : l10n.attendanceOverdueHours(abs.inHours);
  }
  if (diff.inHours < 1) return l10n.attendanceDueNow;
  if (diff.inHours < 24) return l10n.attendanceInHours(diff.inHours);
  return l10n.attendanceInDays(diff.inDays);
}

/// Plain text of a description stored as HTML (Quill) for a one-line preview.
String rdPlainText(String? html) {
  if (html == null || html.isEmpty) return '';
  final text = html
      .replaceAll(RegExp(r'<br\s*/?>|</p>|</li>|</h\d>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\s+'), ' ');
  return text.trim();
}

// ---------------------------------------------------------------------------
// Programm of Spieler
// ---------------------------------------------------------------------------

/// One Werk of a Termin as a Spieler sees it.
class RdProgramItem {
  const RdProgramItem({
    required this.songId,
    required this.song,
    this.conductorPersonId,
    this.conductorName,
  });

  final int songId;

  /// Null when the Werk was deleted meanwhile ("Unbekanntes Werk").
  final Song? song;
  final int? conductorPersonId;

  /// Person or guest conductor; null when nobody is set.
  final String? conductorName;
}

/// Parses `history` rows joined with `song:songId(...)` and
/// `person:person_id(firstName, lastName)` in programme order.
List<RdProgramItem> rdProgramItems(List<Map<String, dynamic>> rows) {
  return [
    for (final row in rows)
      if (row['songId'] is num)
        () {
          final songRaw = row['song'];
          final person = row['person'];
          String? name;
          if (person is Map) {
            name = '${person['firstName'] ?? ''} ${person['lastName'] ?? ''}'.trim();
          }
          final other = (row['otherConductor'] as String?)?.trim();
          if (other != null && other.isNotEmpty) name = other;
          Song? song;
          if (songRaw is Map) {
            try {
              song = Song.fromJson(Map<String, dynamic>.from(songRaw));
            } catch (_) {
              song = null;
            }
          }
          return RdProgramItem(
            songId: (row['songId'] as num).toInt(),
            song: song,
            conductorPersonId: (row['person_id'] as num?)?.toInt(),
            conductorName: name == null || name.isEmpty ? null : name,
          );
        }(),
  ];
}

/// Score files of [song] for the group [instrumentId]; in a choir plus the
/// "Chor (alle)" files (like "Aktuelle Werke"), PDFs first, each once.
List<SongFile> rdMyNotes(Song? song, int? instrumentId, {required bool isChoir}) {
  if (song == null) return const [];
  final all = song.files ?? const <SongFile>[];
  final seen = <String>{};
  final files = [
    if (instrumentId != null) ...all.where((f) => f.instrumentId == instrumentId),
    if (isChoir) ...all.where((f) => isChoirAllFile(instrumentId: f.instrumentId, note: f.note)),
  ].where((f) => seen.add(f.url)).toList();
  bool isPdf(SongFile f) => f.fileName.toLowerCase().endsWith('.pdf') || f.fileType.contains('pdf');
  files.sort((a, b) => (isPdf(a) ? 0 : 1).compareTo(isPdf(b) ? 0 : 1));
  return files;
}

/// The recording of [song] (file category "Aufnahme").
SongFile? rdRecordingOf(Song? song) =>
    (song?.files ?? const <SongFile>[]).where((f) => f.instrumentId == 1).firstOrNull;
