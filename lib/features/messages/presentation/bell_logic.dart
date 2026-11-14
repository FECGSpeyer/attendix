// REDESIGN (Beta bell): pure helpers of the notification centre – short
// lines for sign-in/out entries, one block per Termin, relative times.
// Unit tested in test/features/messages/bell_logic_test.dart.

import 'package:intl/intl.dart';

import '../../../core/constants/enums.dart' show AttendanceStatus;
import '../../../data/models/user_notification/user_notification.dart';
import '../../../l10n/l10n.dart';

/// What a sign-in/out entry says, read from the server text
/// (edge function quick-processor, German texts `qp.*`).
enum BellChange { late, onTime, signout, signin, note }

/// A sign-in/out entry split into its parts.
class BellAttendanceLine {
  const BellAttendanceLine({
    required this.name,
    required this.change,
    required this.date,
    this.detail,
    this.eventInfo,
    this.byParents = false,
  });

  final String name;
  final BellChange change;

  /// Day of the Termin as written in the text.
  final DateTime date;

  /// Reason or note, without "Grund:" / "Notiz:".
  final String? detail;

  /// Termin name after the date (`typeInfo` or "(Vortrag)").
  final String? eventInfo;
  final bool byParents;
}

final _late = RegExp(r'^(.+?) kommt am (\d{2}\.\d{2}\.\d{4})(.*?) zu spät\.(?: Grund: (.*))?$');
final _onTime = RegExp(r'^(.+?) kommt am (\d{2}\.\d{2}\.\d{4})(.*?) doch pünktlich\.(?: Notiz: (.*))?$');
final _signout = RegExp(r'^(.+?) hat sich für den (\d{2}\.\d{2}\.\d{4})(.*?) abgemeldet\.(?: Grund: (.*))?$');
final _signin = RegExp(r'^(.+?) hat sich für den (\d{2}\.\d{2}\.\d{4})(.*?) angemeldet\.(?: Notiz: (.*))?$');
final _note = RegExp(r'^(.+?) hat die Notiz für den (\d{2}\.\d{2}\.\d{4})(.*?) angepasst: (.*)$');
const _byParents = '(von Elternteil abgemeldet)';

/// Splits a sign-in/out text; null when the text has another shape (other
/// languages, other types) – the row then shows the text as it is.
BellAttendanceLine? parseBellAttendanceBody(String body) {
  var text = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  var byParents = false;
  if (text.endsWith(_byParents)) {
    byParents = true;
    text = text.substring(0, text.length - _byParents.length).trim();
  }
  for (final (pattern, change) in [
    (_late, BellChange.late),
    (_onTime, BellChange.onTime),
    (_signout, BellChange.signout),
    (_signin, BellChange.signin),
    (_note, BellChange.note),
  ]) {
    final m = pattern.firstMatch(text);
    if (m == null) continue;
    final date = _parseDate(m.group(2)!);
    if (date == null) return null;
    var info = m.group(3)!.trim();
    if (info.startsWith('(') && info.endsWith(')')) info = info.substring(1, info.length - 1).trim();
    final detail = m.group(4)?.trim();
    return BellAttendanceLine(
      name: m.group(1)!.trim(),
      change: change,
      date: date,
      detail: detail == null || detail.isEmpty ? null : detail,
      eventInfo: info.isEmpty ? null : info,
      byParents: byParents,
    );
  }
  return null;
}

DateTime? _parseDate(String s) {
  final parts = s.split('.');
  if (parts.length != 3) return null;
  final d = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final y = int.tryParse(parts[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y, m, d);
}

/// Short title of a parsed entry ("Anna Beispiel kommt zu spät").
String bellLineTitle(AppLocalizations l10n, BellAttendanceLine line) => switch (line.change) {
      BellChange.late => l10n.redesignBellLate(line.name),
      BellChange.onTime => l10n.redesignBellOnTime(line.name),
      BellChange.signout => l10n.redesignBellSignout(line.name),
      BellChange.signin => l10n.redesignBellSignin(line.name),
      BellChange.note => l10n.redesignBellNote(line.name),
    };

/// Second line of a parsed entry: reason/note, plus "von den Eltern gemeldet".
String bellLineDetail(AppLocalizations l10n, BellAttendanceLine line) =>
    [if (line.detail != null) line.detail!, if (line.byParents) l10n.redesignBellByParents].join(' · ');

/// Entry types that are grouped per Termin (sign-in/out of members).
const kBellEventGroupTypes = {'attendance'};

/// One block of the bell list: a single entry or all entries of one Termin.
sealed class BellItem {
  const BellItem();
}

class BellSingle extends BellItem {
  const BellSingle(this.notification);
  final UserNotification notification;
}

class BellEventGroup extends BellItem {
  const BellEventGroup({required this.tenantId, required this.attendanceId, required this.entries});
  final int tenantId;
  final int attendanceId;

  /// Newest first (order of the feed).
  final List<UserNotification> entries;
}

/// Groups the sign-in/out entries of one Termin into one block, placed where
/// its newest entry is. Other entries stay single. Keeps the feed order.
List<BellItem> groupBellEntries(List<UserNotification> list) {
  final items = <BellItem>[];
  final groups = <(int, int), List<UserNotification>>{};
  for (final n in list) {
    final attendanceId = n.attendanceId;
    if (attendanceId == null || !kBellEventGroupTypes.contains(n.type)) {
      items.add(BellSingle(n));
      continue;
    }
    final key = (n.targetTenantId, attendanceId);
    final existing = groups[key];
    if (existing != null) {
      existing.add(n);
      continue;
    }
    final entries = [n];
    groups[key] = entries;
    items.add(BellEventGroup(tenantId: key.$1, attendanceId: attendanceId, entries: entries));
  }
  return items;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Time of an entry: "17:44" today, "Gestern", the weekday within a week,
/// else "3.11." (with year when it is another year).
String bellRelativeTime(AppLocalizations l10n, DateTime when, {DateTime? now, String? locale}) {
  final current = now ?? DateTime.now();
  final local = when.toLocal();
  final diff = _daysBetween(local, current);
  if (diff <= 0) return DateFormat.Hm(locale).format(local);
  if (diff == 1) return l10n.redesignBellYesterday;
  if (diff < 7) return DateFormat.E(locale).format(local);
  if (local.year == current.year) return DateFormat('d.M.', locale).format(local);
  return DateFormat('d.M.yy', locale).format(local);
}

/// Day of a Termin: "Heute", "Morgen", "Gestern", else "So., 6. Dez.".
String bellEventDay(AppLocalizations l10n, DateTime date, {DateTime? now, String? locale}) {
  final diff = _daysBetween(now ?? DateTime.now(), _day(date));
  if (diff == 0) return l10n.redesignBellToday;
  if (diff == 1) return l10n.redesignBellTomorrow;
  if (diff == -1) return l10n.redesignBellYesterday;
  return DateFormat.MMMEd(locale).format(date);
}

final _personalHello = RegExp(r'^\s*(Hallo|Hi) [^,\n]{1,60},');

/// A lead's personal reminder to answer a Termin ("Offene erinnern" of the
/// redesign: "Hallo Tim, für … fehlt noch deine Antwort"). The server
/// stores it like every other reminder (type `reminder` with the Termin);
/// the automatic "startet in 2 Stunden" has the ⏰ title, the reminder of the
/// classic design has no greeting.
bool bellAsksForAnswer(UserNotification n) =>
    n.type == 'reminder' && n.attendanceId != null && !n.title.startsWith('⏰') && _personalHello.hasMatch(n.body);

/// The own answer behind [status]: true zugesagt (also "komme später"),
/// false abgesagt, null still open.
bool? bellOwnAnswer(AttendanceStatus? status) => switch (status) {
      null || AttendanceStatus.neutral => null,
      AttendanceStatus.present || AttendanceStatus.late || AttendanceStatus.lateExcused => true,
      AttendanceStatus.excused || AttendanceStatus.absent => false,
    };

/// The reminders of [list] that are done because the person has answered
/// the Termin since (id → zugesagt). [answerOf]: the own answer for a
/// Termin (group, Termin), null while open or unknown.
Map<String, bool> bellAnsweredReminders(
  List<UserNotification> list,
  bool? Function(int tenantId, int attendanceId) answerOf,
) => {
      for (final n in list)
        if (bellAsksForAnswer(n))
          if (answerOf(n.targetTenantId, n.attendanceId!) case final accepted?) n.id: accepted,
    };
