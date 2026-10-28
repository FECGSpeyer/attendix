/// Safe string utilities to prevent RangeError exceptions.
class StringUtils {
  StringUtils._(); // Private constructor - utility class

  /// DB_REVIEW_REST (M7): pattern for a case-insensitive but otherwise exact
  /// PostgREST `ilike` match (e-mail lookups like Ionic getAppIdByEmail).
  /// `%`, `_` and `\` are escaped so they match literally (an e-mail like
  /// `a_b@x.de` must not match `acb@x.de`); the value is trimmed.
  static String exactIlikePattern(String value) => value
      .trim()
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  /// Safely extracts initials from a string.
  ///
  /// Returns up to [length] characters from the beginning of [text].
  /// If [text] is shorter than [length], returns the entire string.
  /// If [text] is null or empty, returns [fallback].
  ///
  /// Example:
  /// ```dart
  /// StringUtils.getInitials('Orchestra', 2); // 'OR'
  /// StringUtils.getInitials('A', 2);         // 'A'
  /// StringUtils.getInitials('', 2);          // '?'
  /// ```
  static String getInitials(String? text, int length, {String fallback = '?'}) {
    if (text == null || text.isEmpty) return fallback;
    final safeLength = text.length < length ? text.length : length;
    return text.substring(0, safeLength).toUpperCase();
  }

  /// Extracts tenant initials with fallback logic.
  ///
  /// Prefers [shortName] if not empty, otherwise uses [longName].
  /// Returns up to 2 characters, or '?' if both are empty.
  static String getTenantInitials(String shortName, String longName) {
    final name = shortName.isNotEmpty ? shortName : longName;
    return getInitials(name, 2);
  }
}
