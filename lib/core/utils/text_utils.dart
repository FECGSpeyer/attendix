/// Trim + lowercase an email for duplicate matching. Returns null for empty
/// input so empty emails never match each other (Ionic uses
/// `.ilike('email', email.trim().toLowerCase())`).
String? normalizeEmailForMatch(String? email) {
  final normalized = (email ?? '').trim().toLowerCase();
  return normalized.isEmpty ? null : normalized;
}

/// Escape LIKE/ILIKE wildcards so user input matches literally.
String escapeLikePattern(String input) => input
    .replaceAll(r'\', r'\\')
    .replaceAll('%', r'\%')
    .replaceAll('_', r'\_');

/// Case-insensitive email equality (trimmed). Empty never equals empty.
bool emailsMatch(String? a, String? b) {
  final na = normalizeEmailForMatch(a);
  final nb = normalizeEmailForMatch(b);
  return na != null && na == nb;
}
