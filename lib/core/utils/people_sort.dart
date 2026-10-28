/// LOGIC_PEOPLE: sort helpers for the people list (Ionic list.page).

/// Approximation of JS `String.localeCompare` for German names:
/// case-insensitive, umlauts sort with their base letter (ä→a, ö→o, ü→u,
/// ß→ss, accents folded). Ties fall back to a case-sensitive compare so the
/// order stays stable and deterministic.
int localeCompareDe(String a, String b) {
  final c = _fold(a).compareTo(_fold(b));
  if (c != 0) return c;
  final lower = a.toLowerCase().compareTo(b.toLowerCase());
  if (lower != 0) return lower;
  return a.compareTo(b);
}

const Map<String, String> _foldMap = {
  'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss',
  'á': 'a', 'à': 'a', 'â': 'a', 'å': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
};

String _fold(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_foldMap[ch] ?? ch);
  }
  return buffer.toString();
}

/// Ionic: `a.testResult ? Number(a.testResult.replace('%', '')) : 0`
/// (unparseable values count as 0 here instead of JS NaN).
double testResultValue(String? testResult) {
  if (testResult == null || testResult.isEmpty) return 0;
  return double.tryParse(testResult.replaceAll('%', '').trim()) ?? 0;
}
