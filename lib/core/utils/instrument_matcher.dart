import '../../l10n/l10n.dart';

/// Utility class for matching filenames to instruments
/// Based on Ionic's instrument-matcher.ts
class InstrumentMatcher {
  /// Special instrument IDs
  static const int recordingId = 1;
  static const int lyricsId = 2;

  /// Translations for instrument names (EN, DE, IT, RU)
  static const Map<String, List<String>> translations = {
    // Strings
    'violine': ['violin', 'geige', 'violino', 'скрипка'],
    'viola': ['viola', 'bratsche', 'альт'],
    'cello': ['cello', 'violoncello', 'violoncell', 'виолончель'],
    'kontrabass': ['contrabass', 'double bass', 'bass', 'контрабас'],

    // Woodwinds
    'flöte': ['flute', 'flauto', 'флейта'],
    'oboe': ['oboe', 'hautbois', 'гобой'],
    'klarinette': ['clarinet', 'clarinetto', 'кларнет'],
    'fagott': ['bassoon', 'fagotto', 'фагот'],
    'saxophon': ['saxophone', 'sax', 'саксофон'],

    // Brass
    'horn': ['horn', 'french horn', 'corno', 'валторна'],
    'trompete': ['trumpet', 'tromba', 'труба'],
    'posaune': ['trombone', 'trombon', 'тромбон'],
    'tuba': ['tuba', 'туба'],

    // Percussion
    'schlagzeug': ['percussion', 'drums', 'batterie', 'перкуссия'],
    'pauke': ['timpani', 'pauken', 'kettledrum', 'литавры'],

    // Keyboard
    'klavier': ['piano', 'pianoforte', 'фортепиано', 'пианино'],
    'orgel': ['organ', 'organo', 'орган'],
    'cembalo': ['harpsichord', 'clavecin', 'клавесин'],

    // Other
    'harfe': ['harp', 'arpa', 'арфа'],
    'gitarre': ['guitar', 'chitarra', 'гитара'],

    // Special
    'partitur': ['score', 'full score', 'conductor', 'партитура'],
    'stimmen': ['parts', 'voices', 'parti', 'голоса'],
  };

  /// Abbreviations mapping
  static const Map<String, List<String>> abbreviations = {
    'violine': ['vl', 'vln', 'vi', 'viol'],
    'viola': ['va', 'vla', 'br'],
    'cello': ['vc', 'vlc', 'cel'],
    'kontrabass': ['kb', 'cb', 'db'],
    'flöte': ['fl', 'flt'],
    'oboe': ['ob'],
    'klarinette': ['cl', 'kl', 'clar'],
    'fagott': ['fg', 'bn', 'bsn'],
    'saxophon': ['sx', 'sax'],
    'horn': ['hr', 'hn', 'cor'],
    'trompete': ['tr', 'tp', 'trp', 'tpt'],
    'posaune': ['pos', 'tb', 'tbn', 'trb'],
    'tuba': ['tu', 'tba'],
    'schlagzeug': ['perc', 'pk', 'schlg'],
    'pauke': ['timp', 'pk'],
    'klavier': ['pf', 'pno', 'kl'],
    'orgel': ['org'],
    'harfe': ['hp', 'hrf'],
    'gitarre': ['gt', 'gtr', 'git'],
    'partitur': ['part', 'dir', 'cond'],
  };

  /// Roman numeral patterns
  static const Map<String, int> romanNumerals = {
    'i': 1,
    'ii': 2,
    'iii': 3,
    'iv': 4,
    'v': 5,
  };

  /// Audio file extensions that indicate recordings
  static const List<String> audioExtensions = [
    'mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'wma'
  ];

  /// Keywords that indicate lyrics/text
  static const List<String> lyricsKeywords = [
    'text', 'lyrics', 'liedtext', 'gesang', 'vocal', 'vokal',
    'words', 'parole', 'тексt', 'слова'
  ];

  /// Keywords that indicate recordings
  static const List<String> recordingKeywords = [
    'aufnahme', 'recording', 'audio', 'track', 'запись',
    'registrazione', 'enregistrement'
  ];

  /// Try to match a filename to an instrument
  /// Returns the instrument ID if found, null otherwise
  static int? matchInstrument(String filename, List<InstrumentInfo> instruments) {
    final normalized = _normalizeFilename(filename);
    final extension = _getExtension(filename).toLowerCase();

    // Check for audio files -> Recording
    if (audioExtensions.contains(extension)) {
      return recordingId;
    }

    // Check for recording keywords
    for (final keyword in recordingKeywords) {
      if (normalized.contains(keyword)) {
        return recordingId;
      }
    }

    // Check for lyrics keywords
    for (final keyword in lyricsKeywords) {
      if (normalized.contains(keyword)) {
        return lyricsId;
      }
    }

    // Try to match instruments
    for (final instrument in instruments) {
      if (_matchesInstrument(normalized, instrument)) {
        return instrument.id;
      }
    }

    return null;
  }

  /// Check if filename matches an instrument
  static bool _matchesInstrument(String normalized, InstrumentInfo instrument) {
    final instrumentName = instrument.name.toLowerCase();
    final instrumentSynonyms = instrument.synonyms?.toLowerCase() ?? '';

    // Direct name match
    if (normalized.contains(instrumentName)) {
      return true;
    }

    // Check synonyms from instrument
    if (instrumentSynonyms.isNotEmpty) {
      for (final synonym in instrumentSynonyms.split(',')) {
        if (normalized.contains(synonym.trim())) {
          return true;
        }
      }
    }

    // Check translations
    for (final entry in translations.entries) {
      if (instrumentName.contains(entry.key)) {
        for (final translation in entry.value) {
          if (normalized.contains(translation)) {
            return true;
          }
        }
      }
    }

    // Check abbreviations
    for (final entry in abbreviations.entries) {
      if (instrumentName.contains(entry.key)) {
        for (final abbr in entry.value) {
          // Match abbreviation with word boundaries
          final pattern = RegExp(r'(^|[^a-z])' + abbr + r'([^a-z]|$)');
          if (pattern.hasMatch(normalized)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Normalize filename for matching
  static String _normalizeFilename(String filename) {
    return filename
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-\.]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Get file extension
  static String _getExtension(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  /// Extract number from filename (e.g., "Violine 1" -> 1, "Violine II" -> 2)
  static int? extractNumber(String filename) {
    final normalized = filename.toLowerCase();

    // Try Roman numerals first
    for (final entry in romanNumerals.entries) {
      final pattern = RegExp(r'(^|[^a-z])' + entry.key + r'([^a-z]|$)');
      if (pattern.hasMatch(normalized)) {
        return entry.value;
      }
    }

    // Try Arabic numerals
    final numberMatch = RegExp(r'(\d+)').firstMatch(filename);
    if (numberMatch != null) {
      return int.tryParse(numberMatch.group(1)!);
    }

    return null;
  }

  /// Get a descriptive label for a file based on its instrumentId and note
  static String getFileLabel({
    required int? instrumentId,
    required String? note,
    required List<InstrumentInfo> instruments,
  }) {
    // First check note
    if (note != null && note.isNotEmpty) {
      return note;
    }

    // Check special IDs
    if (instrumentId == recordingId) {
      return l10nWithoutContext.songsRecording;
    }
    if (instrumentId == lyricsId) {
      return l10nWithoutContext.songsLyrics;
    }

    // Find instrument name
    if (instrumentId != null) {
      final instrument = instruments.where((i) => i.id == instrumentId).firstOrNull;
      if (instrument != null) {
        return instrument.name;
      }
    }

    return l10nWithoutContext.songsOther;
  }
}

/// Simple info class for instrument matching
class InstrumentInfo {
  final int id;
  final String name;
  final String? synonyms;

  const InstrumentInfo({
    required this.id,
    required this.name,
    this.synonyms,
  });
}
