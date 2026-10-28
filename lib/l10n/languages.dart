// Supported UI languages – mirrors Ionic src/app/i18n/languages.ts.
// German is the source language and the fallback for every missing key.

/// All languages the Ionic app ships (ru/es are hidden until complete).
const supportedLanguages = ['de', 'en', 'ru', 'es'];

/// Languages users can currently pick (Ionic ENABLED_LANGUAGES).
const enabledLanguages = ['de', 'en'];

const defaultLanguage = 'de';

/// Locale tags for intl (DateFormat / NumberFormat), per UI language.
const intlLocales = {
  'de': 'de_DE',
  'en': 'en_GB',
  'ru': 'ru_RU',
  'es': 'es_ES',
};

/// Native language names shown in the language picker.
const languageNames = {
  'de': 'Deutsch',
  'en': 'English',
  'ru': 'Русский',
  'es': 'Español',
};

/// Maps "en-US", "ru_RU", "ES" etc. to a supported language, or null.
String? normalizeLanguage(String? value) {
  if (value == null) return null;
  final base = value.trim().toLowerCase().split(RegExp('[-_]')).first;
  return supportedLanguages.contains(base) ? base : null;
}

/// Picks the UI language: an explicit user choice wins, then the device
/// languages, then German. Only enabled languages are returned.
String resolveLanguage(
  String? preferred,
  Iterable<String> deviceLanguages, {
  List<String> enabled = enabledLanguages,
}) {
  for (final candidate in [preferred, ...deviceLanguages]) {
    final lang = normalizeLanguage(candidate);
    if (lang != null && enabled.contains(lang)) return lang;
  }
  return defaultLanguage;
}

// Active UI language for code without BuildContext/ref (static helpers).
// LocaleNotifier keeps it in sync.
String _activeLanguage = defaultLanguage;

void setActiveLanguage(String lang) => _activeLanguage = lang;

String currentLanguage() => _activeLanguage;

/// intl locale tag of the active language, e.g. `de_DE` / `en_GB`.
String currentIntlLocale() => intlLocales[_activeLanguage] ?? 'de_DE';

enum DateFmtKind { date, short, dayMonth }

// Numeric DateFormat patterns per UI language (Ionic DATE_PATTERNS).
const _datePatterns = {
  'de': {
    DateFmtKind.date: 'dd.MM.yyyy',
    DateFmtKind.short: 'dd.MM.yy',
    DateFmtKind.dayMonth: 'dd.MM.',
  },
  'en': {
    DateFmtKind.date: 'dd/MM/yyyy',
    DateFmtKind.short: 'dd/MM/yy',
    DateFmtKind.dayMonth: 'dd/MM',
  },
  'ru': {
    DateFmtKind.date: 'dd.MM.yyyy',
    DateFmtKind.short: 'dd.MM.yy',
    DateFmtKind.dayMonth: 'dd.MM',
  },
  'es': {
    DateFmtKind.date: 'dd/MM/yyyy',
    DateFmtKind.short: 'dd/MM/yy',
    DateFmtKind.dayMonth: 'dd/MM',
  },
};

/// Numeric date pattern of the active language for `DateFormat(...)`:
/// full date, short year, or day and month.
String dateFmt([DateFmtKind kind = DateFmtKind.date]) =>
    _datePatterns[_activeLanguage]![kind]!;
