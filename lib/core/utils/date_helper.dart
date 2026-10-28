/// Helper class for date formatting and manipulation
///
/// Based on Ionic Utils.ts getReadableDate method
class DateHelper {
  /// Converts a date string to a human-readable German format
  ///
  /// Returns:
  /// - "Heute" for today
  /// - "Morgen" for tomorrow
  /// - "Gestern" for yesterday
  /// - "Mo, 19. Feb" for other dates
  static String getReadableDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);

    // Check for special cases
    if (compareDate == today) {
      return 'Heute';
    } else if (compareDate == today.add(const Duration(days: 1))) {
      return 'Morgen';
    } else if (compareDate == today.subtract(const Duration(days: 1))) {
      return 'Gestern';
    }

    // Format: "Mo, 19. Feb"
    final weekday = _getWeekdayName(date.weekday);
    final day = date.day;
    final month = _getMonthName(date.month);

    return '$weekday, $day. $month';
  }

  /// Formats a date with full month name: "19. Februar 2024"
  static String getFullDate(DateTime date) {
    final day = date.day;
    final month = _getFullMonthName(date.month);
    final year = date.year;

    return '$day. $month $year';
  }

  /// Formats a date with short format: "19.02.2024"
  static String getShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;

    return '$day.$month.$year';
  }

  /// Formats time: "14:30"
  static String getTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  /// Formats date and time: "19.02.2024 14:30"
  static String getDateTime(DateTime date) {
    return '${getShortDate(date)} ${getTime(date)}';
  }

  /// Returns short weekday name (Mo, Di, Mi, etc.)
  static String _getWeekdayName(int weekday) {
    const names = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return names[weekday - 1];
  }

  /// Returns abbreviated month name
  static String _getMonthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez'
    ];
    return names[month - 1];
  }

  /// Returns full month name
  static String _getFullMonthName(int month) {
    const names = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember'
    ];
    return names[month - 1];
  }

  /// Checks if a date is in the past
  static bool isPast(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);

    return compareDate.isBefore(today);
  }

  /// Checks if a date is in the future
  static bool isFuture(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);

    return compareDate.isAfter(today);
  }

  /// Checks if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);

    return compareDate == today;
  }

  /// "2026-03-07" (local calendar day, no time / timezone).
  static String isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// "19:00" from a DB time like "19:00:00" (shorter values unchanged).
  static String hhmm(String time) =>
      time.length >= 5 ? time.substring(0, 5) : time;
}
