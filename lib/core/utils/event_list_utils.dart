import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/enums.dart';
import '../theme/app_colors.dart';
import 'date_helper.dart';

/// Helpers for the card layout of the Terminlisten (Termine, Meine Termine,
/// Eltern, Übersicht): date tile, month groups, time line, status pills and
/// multi-day Termine.
///
/// Port of Ionic `utilities/event-list.ts` and `utilities/plan-days.ts`.
abstract final class EventListUtils {
  /// How many past Termine are shown before "Alle anzeigen".
  static const int pastPreviewCount = 3;

  /// Default absence reasons (Ionic DEFAULT_ABSENCE_REASONS).
  static const List<String> defaultAbsenceReasons = [
    'Krankheitsbedingt',
    'Urlaubsbedingt',
    'Arbeitsbedingt',
    'Familienbedingt',
  ];

  /// Default late reasons (Ionic DEFAULT_LATE_REASONS).
  static const List<String> defaultLateReasons = [
    'Krankheitsbedingt',
    'Urlaubsbedingt',
    'Arbeitsbedingt',
    'Familienbedingt',
  ];

  /// Default info text for Termine the person is not part of (show_all_attendances).
  static const String defaultShowAllInfoText =
      'Du bist bei diesem Termin nicht dabei.';

  /// Absence reasons of the tenant or the defaults.
  static List<String> absenceReasonsOf(List<String>? tenantReasons) =>
      (tenantReasons != null && tenantReasons.isNotEmpty)
          ? tenantReasons
          : defaultAbsenceReasons;

  /// Late reasons of the tenant or the defaults.
  static List<String> lateReasonsOf(List<String>? tenantReasons) =>
      (tenantReasons != null && tenantReasons.isNotEmpty)
          ? tenantReasons
          : defaultLateReasons;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Parses an ISO date; returns null when not parseable.
  static DateTime? parse(String? date) {
    if (date == null || date.isEmpty) return null;
    final parsed = DateTime.tryParse(date);
    return parsed?.toLocal();
  }

  /// Last day of a Termin; multi-day Termine end `durationDays - 1` days after their start.
  static DateTime? endDate(String? date, int? durationDays) {
    final start = parse(date);
    if (start == null) return null;
    final days = (durationDays ?? 1) < 1 ? 1 : (durationDays ?? 1);
    return _day(start).add(Duration(days: days - 1));
  }

  /// A Termin is past only once its last day is over, so a running Freizeit stays current.
  static bool hasEnded(String? date, int? durationDays, {DateTime? now}) {
    final end = endDate(date, durationDays);
    if (end == null) return false;
    return end.isBefore(_day(now ?? DateTime.now()));
  }

  /// Termin starts today or is still running today.
  static bool isRunning(String? date, int? durationDays, {DateTime? now}) {
    final start = parse(date);
    if (start == null) return false;
    final today = _day(now ?? DateTime.now());
    return !_day(start).isAfter(today) &&
        !hasEnded(date, durationDays, now: now);
  }

  /// More than one day long.
  static bool isMultiDay(int? durationDays) => (durationDays ?? 1) > 1;

  /// Short weekday ("Di") for the date tile.
  static String weekday(String? date) {
    final d = parse(date);
    if (d == null) return '';
    const names = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return names[d.weekday - 1];
  }

  /// Day of month ("05") for the date tile.
  static String day(String? date) {
    final d = parse(date);
    if (d == null) return '';
    return d.day.toString().padLeft(2, '0');
  }

  /// "Oktober 2026" month header.
  static String monthLabel(DateTime date) =>
      DateFormat('MMMM yyyy', 'de_DE').format(date);

  /// "19:00–21:00", "19:00" or '' when no time is set.
  static String timeRange(String? start, String? end) {
    String cut(String? v) =>
        (v == null || v.isEmpty) ? '' : DateHelper.hhmm(v);
    final s = cut(start);
    final e = cut(end);
    if (s.isNotEmpty && e.isNotEmpty) return '$s–$e';
    return s;
  }

  /// Joins the non-empty parts of a meta line with " · ".
  static String meta(List<String?> parts) =>
      parts.where((p) => p != null && p.isNotEmpty).join(' · ');

  /// "Di., 20.10.2026" or a range for multi-day all-day types.
  static String readableDate(String? date, {bool allDay = false, int? durationDays}) {
    final d = parse(date);
    if (d == null) return date ?? '';
    final fmt = DateFormat('EEE, dd.MM.yyyy', 'de_DE');
    if (allDay && (durationDays ?? 1) > 1) {
      final end = d.add(Duration(days: (durationDays ?? 1) - 1));
      return '${fmt.format(d)} - ${fmt.format(end)}';
    }
    return fmt.format(d);
  }

  /// Groups already sorted items by month, keeping their order.
  static List<EventMonthGroup<T>> groupByMonth<T>(
    List<T> items,
    String? Function(T item) getDate,
  ) {
    final groups = <EventMonthGroup<T>>[];
    for (final item in items) {
      final d = parse(getDate(item));
      final key = d == null
          ? ''
          : '${d.year}-${d.month.toString().padLeft(2, '0')}';
      if (groups.isEmpty || groups.last.key != key) {
        groups.add(EventMonthGroup<T>(
          key: key,
          label: d == null ? '' : monthLabel(d),
          items: [],
        ));
      }
      groups.last.items.add(item);
    }
    return groups;
  }

  /// Color of a percentage pill.
  static Color percentageColor(int perc) => perc >= 75
      ? AppColors.success
      : perc >= 50
          ? AppColors.warning
          : AppColors.danger;

  /// Color of a status pill or dot (Ionic statusColor).
  static Color statusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppColors.success;
      case AttendanceStatus.absent:
        return AppColors.danger;
      case AttendanceStatus.late:
        return AppColors.tertiary;
      case AttendanceStatus.lateExcused:
        return rosa;
      case AttendanceStatus.neutral:
        return AppColors.medium;
      case AttendanceStatus.excused:
        return AppColors.warning;
    }
  }

  /// Ionic "rosa" color used for reported late arrivals.
  static const Color rosa = Color(0xFFE91E63);

  /// Readable status for the pill; upcoming Termine read as a plan
  /// ("Zugesagt"), past ones as a result.
  static String statusLabel(AttendanceStatus status, {bool past = false}) {
    switch (status) {
      case AttendanceStatus.present:
        return past ? 'Anwesend' : 'Zugesagt';
      case AttendanceStatus.absent:
        return 'Abwesend';
      case AttendanceStatus.late:
        return 'Verspätet';
      case AttendanceStatus.lateExcused:
        return past ? 'Verspätet entsch.' : 'Verspätung gemeldet';
      case AttendanceStatus.neutral:
        return 'Neutral';
      case AttendanceStatus.excused:
        return 'Entschuldigt';
    }
  }

  /// Letter code like Ionic `Utils.getAttText`.
  static String attText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.neutral:
        return 'N';
      case AttendanceStatus.present:
        return 'X';
      case AttendanceStatus.excused:
        return 'E';
      case AttendanceStatus.late:
      case AttendanceStatus.lateExcused:
        return 'L';
      case AttendanceStatus.absent:
        return 'A';
    }
  }

  /// Sign-in still possible (no deadline or deadline not passed).
  ///
  /// Like Ionic: the deadline is stored as local wall time in UTC notation,
  /// so the UTC offset is subtracted before comparing.
  static bool isSigninOpen(String? deadline, {DateTime? now}) {
    final local = deadlineLocal(deadline);
    if (local == null) return true;
    return !(now ?? DateTime.now()).isAfter(local);
  }

  /// Deadline as local wall time (see [isSigninOpen]).
  static DateTime? deadlineLocal(String? deadline) {
    if (deadline == null || deadline.isEmpty) return null;
    final parsed = DateTime.tryParse(deadline);
    if (parsed == null) return null;
    if (!parsed.isUtc) return parsed;
    // Stored wall time: interpret the UTC components as local time.
    return DateTime(parsed.year, parsed.month, parsed.day, parsed.hour,
        parsed.minute, parsed.second);
  }

  /// "Anmeldefrist: 20.10.2026 18:00 Uhr" / "Anmeldefrist abgelaufen".
  static String deadlineText(String? deadline, {DateTime? now}) {
    final local = deadlineLocal(deadline);
    if (local == null) return '';
    if ((now ?? DateTime.now()).isAfter(local)) return 'Anmeldefrist abgelaufen';
    return 'Anmeldefrist: ${DateFormat('dd.MM.yyyy HH:mm').format(local)} Uhr';
  }

  /// Google Maps search URL for a place (Ionic Utils.getNavigationUrl).
  static Uri navigationUrl(String place, {bool apple = false}) {
    final encoded = Uri.encodeComponent(place);
    if (apple) return Uri.parse('maps://?q=$encoded');
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
  }
}

/// A month section of a Terminliste.
class EventMonthGroup<T> {
  EventMonthGroup({required this.key, required this.label, required this.items});

  final String key;
  final String label;
  final List<T> items;
}
