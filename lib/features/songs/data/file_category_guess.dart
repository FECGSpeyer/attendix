import '../../../core/services/part_vision_service.dart';
import '../../../core/utils/choir_file_utils.dart' show kChoirAllNote;
import '../../../core/utils/instrument_matcher.dart';
import '../../../data/models/song/song.dart';

/// Ionic `detectSpecialFileType`: category from the file name / extension
/// when no group matched. Returns null if nothing special was detected.
/// Words are matched whole ("Soundtrack" is no "track", "Kontext" no "text").
({int? instrumentId, String? note})? detectSpecialFileType(String filename) {
  final lower = filename.toLowerCase();
  final words = InstrumentMatcher.tokenize(lower).join(' ');
  bool any(List<String> terms) => terms.any((t) {
        final term = InstrumentMatcher.tokenize(t).join(' ');
        return RegExp('(^| )${RegExp.escape(term)}( |\$)').hasMatch(words);
      });

  if (InstrumentMatcher.audioExtensions.any((e) => lower.endsWith('.$e'))) {
    return (instrumentId: 1, note: null);
  }
  if (lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.txt')) {
    return (instrumentId: 2, note: null);
  }
  if (lower.contains('.sib')) return (instrumentId: null, note: 'Sibelius');
  if (any(['klavierauszug', 'piano reduction', 'vocal score', 'klavier auszug', 'клавир', 'klavir', 'переложение'])) {
    return (instrumentId: null, note: 'Klavierauszug');
  }
  if (any([
    'partitur', 'score', 'full score', 'conductor', 'direktion', 'dirigent', 'партитура', 'partitura', 'дирижер',
    'dirizher', ...partiturCompounds,
  ])) {
    return (instrumentId: null, note: 'Partitur');
  }
  if (any(['liedtext', 'songtext', 'lyrics', 'text', 'texte', 'words', 'текст', 'tekst', 'слова', 'slova'])) {
    return (instrumentId: 2, note: null);
  }
  // "S. A." / "T. B.": the choir's voices in two sheets.
  if (any(['chor', 'choir', 'choral', 'chorsatz', 'coro', 'cori', 'satb', 's a t b', 's a', 't b', 'хор', 'khor', 'хоровая'])) {
    return (instrumentId: null, note: kChoirAllNote);
  }
  return null;
}

/// Scores named as one word (the matcher only knows "partitur" itself).
const partiturCompounds = [
  'generalpartitur', 'dirigierpartitur', 'dirigentenpartitur', 'dirigentenauszug', 'direktionsstimme',
  'studienpartitur', 'gesamtpartitur',
];

/// Labels by file type that win over a part in the name: a Sibelius file
/// "Violine 1.sib" is the Sibelius file, not the violin part.
({int? instrumentId, String? note})? fileTypeLabel(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.sib')) return (instrumentId: null, note: 'Sibelius');
  if (lower.endsWith('.mid') || lower.endsWith('.midi')) return (instrumentId: null, note: 'MIDI');
  return null;
}

/// Ionic `findConflictingFiles`: existing files with the same category.
List<SongFile> findConflictingFiles(List<SongFile> files, int? instrumentId, String? note) {
  if (instrumentId != null) {
    return files.where((f) => f.instrumentId == instrumentId).toList();
  }
  return files
      .where((f) => f.instrumentId == null && (f.note ?? '') == (note ?? ''))
      .toList();
}

bool _isPdfName(String name) => name.toLowerCase().endsWith('.pdf');

/// Category of an uploaded file with how sure the detection is.
class FileCategoryGuess {
  const FileCategoryGuess({
    required this.instrumentId,
    required this.note,
    required this.confidence,
    this.term,
    this.byVision = false,
  });

  /// [match] read on the first page (`part-detect`).
  factory FileCategoryGuess.vision(PartMatch match) => FileCategoryGuess(
        instrumentId: match.instrumentId,
        note: null,
        confidence: match.confidence,
        term: match.term,
        byVision: true,
      );

  final int? instrumentId;
  final String? note;
  final MatchConfidence confidence;

  /// The words of the file name the guess is based on.
  final String? term;

  /// Read on the first page instead of the file name.
  final bool byVision;

  /// The page may still help: the name was not clear and it is a PDF/image.
  bool canAskVision(String fileName) => !byVision && needsReview && PartVisionService.supports(fileName);

  /// The person should look at it before uploading. A part read on page 1
  /// is always confirmed by hand: the model's own "sure" is no proof (a
  /// page can carry misleading text).
  bool get needsReview => byVision || confidence != MatchConfidence.sure;
}

/// Ionic `addFiles` category detection: group by name/synonym, then special
/// types (Aufnahme, Liedtext, Partitur, ...), then "Chor" for PDFs in choirs.
({int? instrumentId, String? note}) detectFileCategory(
  String fileName, {
  required List<InstrumentInfo> instruments,
  required bool isChoir,
}) {
  final guess = guessFileCategory(fileName, instruments: instruments, isChoir: isChoir);
  return (instrumentId: guess.instrumentId, note: guess.note);
}

/// [detectFileCategory] with the confidence of the guess.
FileCategoryGuess guessFileCategory(
  String fileName, {
  required List<InstrumentInfo> instruments,
  required bool isChoir,
}) {
  final byType = fileTypeLabel(fileName);
  if (byType != null) {
    return FileCategoryGuess(instrumentId: byType.instrumentId, note: byType.note, confidence: MatchConfidence.sure);
  }
  // Recordings and texts keep their type whatever the name says
  // ("Generalpartitur.mp3" is a recording).
  final lower = fileName.toLowerCase();
  final byExtension = InstrumentMatcher.audioExtensions.any((e) => lower.endsWith('.$e')) ||
      lower.endsWith('.doc') ||
      lower.endsWith('.docx') ||
      lower.endsWith('.txt');
  if (byExtension) {
    // Ionic order: a group in the name, then Aufnahme / Liedtext.
    final match = instruments.isEmpty ? PartMatch.none : InstrumentMatcher.detect(fileName, instruments);
    if (match.instrumentId != null) {
      return FileCategoryGuess(instrumentId: match.instrumentId, note: null, confidence: match.confidence, term: match.term);
    }
    final special = detectSpecialFileType(fileName)!;
    return FileCategoryGuess(instrumentId: special.instrumentId, note: special.note, confidence: MatchConfidence.sure);
  }
  // A full score stays one even when a part is named ("Mit Harfe -
  // Generalpartitur"); a plain "Partitur" does not ("Werk - Partitur - Oboe"
  // is the oboe part taken from the score).
  final tokens = InstrumentMatcher.tokenize(fileName.toLowerCase());
  if (tokens.any(partiturCompounds.contains)) {
    return const FileCategoryGuess(instrumentId: null, note: 'Partitur', confidence: MatchConfidence.sure);
  }
  // A "Vocal score" is the Klavierauszug, not a "Gesang" part.
  if (RegExp(r'(^| )vocal scores?( |$)').hasMatch(tokens.join(' '))) {
    return const FileCategoryGuess(instrumentId: null, note: 'Klavierauszug', confidence: MatchConfidence.sure);
  }
  final match = instruments.isEmpty ? PartMatch.none : InstrumentMatcher.detect(fileName, instruments);
  if (match.instrumentId != null) {
    return FileCategoryGuess(
      instrumentId: match.instrumentId,
      note: null,
      confidence: match.confidence,
      term: match.term,
    );
  }
  final special = detectSpecialFileType(fileName);
  if (special != null) {
    return FileCategoryGuess(
      instrumentId: special.instrumentId,
      note: special.note,
      confidence: MatchConfidence.sure,
    );
  }
  if (isChoir && _isPdfName(fileName)) {
    return const FileCategoryGuess(instrumentId: null, note: kChoirAllNote, confidence: MatchConfidence.sure);
  }
  return const FileCategoryGuess(instrumentId: null, note: null, confidence: MatchConfidence.none);
}

/// The file-name term to remember as synonym when the person assigned
/// [fileName] to group [chosenId] by hand (upload: "künftig so erkennen").
/// Null for recordings / lyrics / free text, or when the name already leads
/// to that group for sure.
String? learnableTerm(
  String fileName, {
  required int? chosenId,
  required List<InstrumentInfo> instruments,
  String? workName,
}) {
  if (chosenId == null ||
      chosenId == InstrumentMatcher.recordingId ||
      chosenId == InstrumentMatcher.lyricsId) {
    return null;
  }
  final now = InstrumentMatcher.detect(fileName, instruments);
  if (now.instrumentId == chosenId && now.confidence == MatchConfidence.sure) return null;
  return InstrumentMatcher.partTerm(fileName, workName: workName);
}

/// Ionic: preselect same-named files, otherwise all conflicts.
Set<String> defaultReplaceSelection(List<SongFile> conflicts, String name) {
  final same = conflicts.where((f) => f.fileName == name).map((f) => f.url).toSet();
  return same.isNotEmpty ? same : conflicts.map((f) => f.url).toSet();
}
