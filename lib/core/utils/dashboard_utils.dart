import 'package:intl/intl.dart';

import '../../data/models/dashboard/dashboard_event.dart';
import '../../data/models/dashboard/dashboard_models.dart';
import '../../data/models/person/person.dart';
import '../../l10n/l10n.dart';

/// Pure helpers for the home dashboard
/// (Ionic `home-dashboard/components/shared/dashboard-date.ts`,
/// `utilities/plan-days.ts`, `utilities/plan-groups.ts` and the card logic).
///
/// Kept free of Flutter/Riverpod so they can be unit-tested directly.
abstract class DashboardUtils {
  static const _monthsShort = [
    'Jan', 'Feb', 'März', 'Apr', 'Mai', 'Juni',
    'Juli', 'Aug', 'Sept', 'Okt', 'Nov', 'Dez',
  ];
  static const _weekdays = [
    'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
    'Freitag', 'Samstag', 'Sonntag',
  ];

  /// Parses an ISO date/timestamp into LOCAL time (like dayjs).
  static DateTime? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    return parsed?.toLocal();
  }

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Difference in calendar days (b - a), DST-safe.
  static int dayDiff(DateTime a, DateTime b) {
    final ua = DateTime.utc(a.year, a.month, a.day);
    final ub = DateTime.utc(b.year, b.month, b.day);
    return ub.difference(ua).inDays;
  }

  static bool isSameDay(DateTime a, DateTime b) => dayDiff(a, b) == 0;

  /// Day number for the calendar tile, e.g. "18".
  static String tileDay(DateTime d) => '${d.day}';

  /// Short German month without dot, e.g. "Okt".
  static String tileMonth(DateTime d) => currentLanguage() == 'de'
      ? _monthsShort[d.month - 1]
      : DateFormat('MMM', currentIntlLocale()).format(d).replaceAll('.', '');

  /// German weekday, e.g. "Samstag".
  static String weekday(DateTime d) => currentLanguage() == 'de'
      ? _weekdays[d.weekday - 1]
      : DateFormat('EEEE', currentIntlLocale()).format(d);

  /// "Heute", "Morgen", "Gestern", "vor 3 Tagen", "in 5 Tagen".
  static String relativeDays(DateTime date, {DateTime? now}) {
    final diff = dayDiff(now ?? DateTime.now(), date);
    final l10n = l10nWithoutContext;
    if (diff == 0) return l10n.teamOrgTodayCap;
    if (diff == -1) return l10n.homeDashboardYesterday;
    if (diff == 1) return l10n.teamOrgTomorrow;
    return diff < 0
        ? l10n.homeDashboardDaysAgo(diff.abs())
        : l10n.homeDashboardInDays(diff);
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// "03.10." (current year) or "03.10.25".
  static String shortDate(DateTime d, {DateTime? now}) {
    final sameYear = d.year == (now ?? DateTime.now()).year;
    return DateFormat(
      dateFmt(sameYear ? DateFmtKind.dayMonth : DateFmtKind.short),
    ).format(d);
  }

  /// "Samstag, 18.10.2025"
  static String longDate(DateTime d) =>
      '${weekday(d)}, ${DateFormat(dateFmt()).format(d)}';

  /// "Samstag, 18.10."
  static String weekdayDayMonth(DateTime d) =>
      '${weekday(d)}, ${DateFormat(dateFmt(DateFmtKind.dayMonth)).format(d)}';

  static String hhmm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  // ---------------------------------------------------------------------------
  // Birthdays card
  // ---------------------------------------------------------------------------

  static const birthdayWindow = 14;

  /// Birthdays of the last and next 14 days. Archived persons (`left`) and
  /// persons without a confirmed birthday are hidden (Ionic BirthdaysCard).
  /// Upcoming (incl. today) ascending first, then past ones (most recent first).
  static List<BirthdayEntry> birthdays(List<Person> persons, {DateTime? now}) {
    final today = startOfDay(now ?? DateTime.now());
    final entries = <BirthdayEntry>[];

    for (final p in persons) {
      if (p.left != null || !p.correctBirthday) continue;
      final bday = parse(p.birthday);
      if (bday == null) continue;

      // SOL_FIX12: the closest occurrence of the birthday among the previous,
      // current and next year — so a December birthday is still in the
      // look-back in early January and a January birthday in the look-ahead
      // at the end of December.
      DateTime? date;
      int? diff;
      for (final year in [today.year - 1, today.year, today.year + 1]) {
        final candidate = _safeDate(year, bday.month, bday.day);
        final d = dayDiff(today, candidate);
        if (diff == null || d.abs() < diff.abs()) {
          date = candidate;
          diff = d;
        }
      }
      if (date == null || diff == null) continue;
      if (diff < -birthdayWindow || diff > birthdayWindow) continue;

      final age = _age(bday, today);
      entries.add(BirthdayEntry(
        person: p,
        date: date,
        daysOffset: diff,
        age: diff > 0 ? age + 1 : age,
      ));
    }

    entries.sort((a, b) {
      final aPast = a.daysOffset < 0;
      final bPast = b.daysOffset < 0;
      if (aPast != bPast) return aPast ? 1 : -1;
      return aPast
          ? b.daysOffset - a.daysOffset
          : a.daysOffset - b.daysOffset;
    });
    return entries;
  }

  static DateTime _safeDate(int year, int month, int day) {
    // 29.02. in non-leap years -> 28.02. (dayjs rolls to 01.03.; keep it in Feb)
    final d = DateTime(year, month, day);
    return d.month == month ? d : DateTime(year, month + 1, 0);
  }

  /// Ionic `Utils.calculateAge`: completed years as of today.
  static int _age(DateTime birthday, DateTime today) {
    var age = today.year - birthday.year;
    if (today.month < birthday.month ||
        (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return age;
  }

  static String birthdayAgeText(BirthdayEntry e) {
    final l10n = l10nWithoutContext;
    if (e.daysOffset == 0) return l10n.homeDashboardTurnsToday(e.age);
    if (e.daysOffset > 0) return l10n.homeDashboardTurns(e.age);
    return l10n.homeDashboardTurned(e.age);
  }

  // ---------------------------------------------------------------------------
  // Member changes card
  // ---------------------------------------------------------------------------

  /// Joins/leaves of the last 60 days, newest first, max. 5.
  static List<MemberChange> memberChanges(List<Person> persons, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 60));
    final changes = <MemberChange>[];
    for (final p in persons) {
      final joined = parse(p.joined);
      if (joined != null && joined.isAfter(cutoff)) {
        changes.add(MemberChange(person: p, date: joined, joined: true));
      }
      final left = parse(p.left);
      if (left != null && left.isAfter(cutoff)) {
        changes.add(MemberChange(person: p, date: left, joined: false));
      }
    }
    changes.sort((a, b) => b.date.compareTo(a.date));
    return changes.take(5).toList();
  }

  // ---------------------------------------------------------------------------
  // Absences card
  // ---------------------------------------------------------------------------

  static const _pausedHistoryType = 1; // PlayerHistoryType.paused

  /// Absences touching the last 4 weeks plus all currently paused persons.
  static List<AbsenceEntry> absences(
    List<DashboardAbsence> absences,
    List<Person> persons, {
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 28));
    final byId = {for (final p in persons) p.id: p};

    final entries = <AbsenceEntry>[
      for (final a in absences)
        if ((parse(a.fromDate)?.isAfter(cutoff) ?? false) ||
            (parse(a.untilDate)?.isAfter(cutoff) ?? false))
          AbsenceEntry(
            person: byId[a.personId],
            firstName: byId[a.personId]?.firstName ?? '?',
            lastName: byId[a.personId]?.lastName ?? '',
            fromDate: a.fromDate ?? '',
            untilDate: a.untilDate ?? '',
            reason: a.reason ?? '',
            isPause: false,
          ),
    ];

    for (final p in persons) {
      if (!p.paused || p.left != null) continue;
      final paused = p.history
          .where((h) => h.type == _pausedHistoryType)
          .toList()
        ..sort((a, b) => (parse(b.date) ?? DateTime(0))
            .compareTo(parse(a.date) ?? DateTime(0)));
      final last = paused.isNotEmpty ? paused.first : null;
      entries.add(AbsenceEntry(
        person: p,
        firstName: p.firstName,
        lastName: p.lastName,
        fromDate: last?.date ?? p.pausedUntil ?? '',
        untilDate: p.pausedUntil ?? '',
        reason: last?.text ?? 'Pausiert',
        isPause: true,
      ));
    }

    entries.sort((a, b) => (parse(b.fromDate) ?? DateTime(0))
        .compareTo(parse(a.fromDate) ?? DateTime(0)));
    return entries;
  }

  static String absenceSubtitle(AbsenceEntry e, {DateTime? now}) {
    final reason = e.reason.isNotEmpty && e.reason != 'Pausiert' ? e.reason : '';
    final from = parse(e.fromDate);
    final until = parse(e.untilDate);
    String range;
    if (e.isPause) {
      final l10n = l10nWithoutContext;
      range = until != null
          ? l10n.coreFlutterPausedUntil(shortDate(until, now: now))
          : l10n.coreFlutterPausedLower;
    } else if (until != null && e.untilDate != e.fromDate && from != null) {
      range = '${shortDate(from, now: now)} – ${shortDate(until, now: now)}';
    } else {
      range = from != null ? shortDate(from, now: now) : '';
    }
    return reason.isNotEmpty ? '$range · $reason' : range;
  }

  // ---------------------------------------------------------------------------
  // Critical persons card
  // ---------------------------------------------------------------------------

  /// Ionic `Utils.getPlayerHistoryTypeText` for `criticalReason`.
  static String criticalReasonText(Person p) {
    if (p.criticalReasonText != null && p.criticalReasonText!.isNotEmpty) {
      return p.criticalReasonText!;
    }
    final type = int.tryParse(p.criticalReason ?? '');
    if (type == null) return '';
    final l10n = l10nWithoutContext;
    return switch (type) {
      1 => l10n.commonHistoryPaused,
      2 => l10n.commonHistoryUnexcused,
      7 => l10n.commonHistoryGroupChange,
      8 => l10n.commonHistoryArchived,
      9 => l10n.commonHistoryReturned,
      3 || 10 || 11 || 12 || 13 => '',
      _ => l10n.commonOther,
    };
  }

  static String initials(Person p) {
    final f = p.firstName.isNotEmpty ? p.firstName[0] : '';
    final l = p.lastName.isNotEmpty ? p.lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // Termine (plan-days.ts)
  // ---------------------------------------------------------------------------

  /// Last day of a (multi-day) Termin.
  static DateTime endDate(DashboardEvent e) {
    final start = parse(e.attendance.date) ?? DateTime.now();
    final days = (e.attendance.durationDays ?? 1).clamp(1, 1000);
    return start.add(Duration(days: days - 1));
  }

  /// Past only once its last day is over (a running Freizeit stays current).
  static bool hasEnded(DashboardEvent e, {DateTime? now}) =>
      dayDiff(now ?? DateTime.now(), endDate(e)) < 0;

  static bool isMultiDay(DashboardEvent e) => (e.attendance.durationDays ?? 1) > 1;

  static List<Map<String, dynamic>> allPlans(DashboardEvent? e) {
    final plan = e?.attendance.plan;
    if (plan == null) return const [];
    return [plan, ...e!.extraPlans];
  }

  static int? planDay(DashboardEvent e, List<Map<String, dynamic>> plans, int index) {
    if (index >= plans.length) return null;
    final day = plans[index]['day'];
    if (day != null) return day is num ? day.toInt() : int.tryParse('$day');
    if (index == 0 && isMultiDay(e)) return 0;
    return null;
  }

  static DateTime planDate(DashboardEvent e, int index) {
    final plans = allPlans(e);
    final start = parse(e.attendance.date) ?? DateTime.now();
    return startOfDay(start).add(Duration(days: planDay(e, plans, index) ?? 0));
  }

  /// Index of today's plan, falling back to the first plan.
  static int todayPlanIndex(DashboardEvent? e, {DateTime? now}) {
    final plans = allPlans(e);
    if (plans.length < 2 || e == null) return 0;
    final today = now ?? DateTime.now();
    for (var i = 0; i < plans.length; i++) {
      if (planDay(e, plans, i) != null && isSameDay(planDate(e, i), today)) {
        return i;
      }
    }
    return 0;
  }

  /// Fields of a plan as maps.
  static List<Map<String, dynamic>> planFields(Map<String, dynamic>? plan) {
    final fields = plan?['fields'];
    if (fields is! List) return const [];
    return fields.whereType<Map>().map((f) => Map<String, dynamic>.from(f)).toList();
  }

  static bool isGroupHead(Map<String, dynamic> field) => field['isGroup'] == true;

  /// "1", "2", "2.1", "2.2", "3" …
  static List<String> fieldNumbers(List<Map<String, dynamic>> fields) {
    var top = 0;
    var sub = 0;
    return fields.map((f) {
      final groupId = f['groupId'];
      if (groupId != null && '$groupId'.isNotEmpty) {
        sub++;
        return '$top.$sub';
      }
      sub = 0;
      top++;
      return '$top';
    }).toList();
  }

  static int fieldMinutes(Map<String, dynamic> field) =>
      int.tryParse('${field['time'] ?? ''}'.split('.').first) ?? 0;

  /// Plan time ("HH:mm" or ISO) as "HH:mm".
  static String formatTime(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.length > 5) {
      final d = parse(value);
      if (d != null) return hhmm(d);
    }
    return value;
  }

  /// Start of a plan on [day]: "HH:mm" applied to [day], ISO used as-is.
  static DateTime? planStart(String? time, DateTime day) {
    if (time == null || time.isEmpty) return null;
    if (time.length > 5) return parse(time);
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }
}

/// Entry of the birthdays card.
class BirthdayEntry {
  const BirthdayEntry({
    required this.person,
    required this.date,
    required this.daysOffset,
    required this.age,
  });

  final Person person;
  final DateTime date;
  final int daysOffset;
  final int age;
}

/// Entry of the member changes card.
class MemberChange {
  const MemberChange({
    required this.person,
    required this.date,
    required this.joined,
  });

  final Person person;
  final DateTime date;
  final bool joined;
}

/// Entry of the absences card.
class AbsenceEntry {
  const AbsenceEntry({
    required this.person,
    required this.firstName,
    required this.lastName,
    required this.fromDate,
    required this.untilDate,
    required this.reason,
    required this.isPause,
  });

  final Person? person;
  final String firstName;
  final String lastName;
  final String fromDate;
  final String untilDate;
  final String reason;
  final bool isPause;
}
