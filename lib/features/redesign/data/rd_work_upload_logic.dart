import '../../../core/utils/instrument_matcher.dart';
import '../../songs/presentation/widgets/file_upload_sheet.dart' show FileCategoryGuess;
import 'import/rd_import_ai.dart';
import 'import/rd_import_logic.dart';

/// REDESIGN: the upload on the Werk page reads files as "Noten importieren"
/// does (Leon, 09.11.2026): the import's name rules (known instruments
/// without a group become "Neue Gruppe", "Posaune und Tuba" goes to both),
/// the KI's guess from the name (`part-suggest`) for the names that are not
/// clear, and page 1 (`part-detect`) only for what is still open.

/// One dropped file as the import reads its name.
class RdUploadRead {
  const RdUploadRead({required this.file, required this.review, this.questionKey});

  /// The file as a file of the import (name only, no folders).
  final RdImportFile file;

  /// Shown in "Zuordnung prüfen" before it is uploaded: the import asks
  /// about it (part not sure, or a group to create).
  final bool review;

  /// The import's question it belongs to ("Sax" for "Sax 1.pdf"); asked
  /// the KI. Null when the name has no part words or it is not asked.
  final String? questionKey;

  String get name => file.name;
  FileCategoryGuess get guess => file.guess;

  /// What the name proposes ([RdImportFile.guessed]).
  RdImportCategory get category => file.guessed;

  /// A part for several groups, or a known instrument without a group: the
  /// name decides it, only the KI's or page 1's word on unknown names counts.
  bool get byKnownName => file.several.isNotEmpty || file.newGroup != null;
}

/// [fileName] read as the import reads a file of the Werk [workName].
RdUploadRead rdUploadRead(
  String fileName, {
  required List<InstrumentInfo> instruments,
  required bool isChoir,
  required String workName,
}) {
  final r = rdImportReadName(fileName, instruments: instruments, isChoir: isChoir, workName: workName);
  final file = RdImportFile(
    entry: RdImportEntry(path: fileName, size: 0),
    fassungKey: '',
    guess: r.guess,
    newGroup: r.newGroup,
    several: r.several,
  );
  // As the import's questions (rdBuildImportPlan): a part for several
  // groups only when it makes a new group.
  final review = r.several.isEmpty ? r.guess.confidence != MatchConfidence.sure : r.several.any((c) => c.newGroup != null);
  final sibelius = file.entry.extension == 'sib';
  return RdUploadRead(
    file: file,
    review: review,
    // A part for several groups goes to all of them: the KI would name one.
    questionKey: review && !sibelius && r.several.isEmpty ? rdImportQuestionKey(fileName, workName: workName) : null,
  );
}

/// The import's questions for the [reads] to review: one per part name
/// ("Sax 1.pdf" and "Sax 2.pdf" are one), as `part-suggest` takes them.
List<RdImportQuestion> rdUploadQuestions(List<RdUploadRead> reads, {required String workName}) {
  final byKey = <String, List<RdUploadRead>>{};
  for (final r in reads) {
    final key = r.questionKey;
    if (key != null) byKey.putIfAbsent(key, () => []).add(r);
  }
  return [
    for (final e in byKey.entries)
      RdImportQuestion(
        key: e.key,
        label: _top([for (final r in e.value) rdImportQuestionLabel(r.name, workName: workName)]) ?? e.key,
        fileCount: e.value.length,
        works: [workName],
        files: {for (final r in e.value) r.name}.take(3).toList(),
        newGroup: _top([for (final r in e.value) r.file.newGroup]),
      ),
  ];
}

/// The most frequent of [values] (nulls left out).
String? _top(List<String?> values) {
  final counts = <String, int>{};
  for (final v in values) {
    if (v != null) counts[v] = (counts[v] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
}

/// The part the KI's [answer] gives [read] (with the file's own part
/// number), or null when page 1 should decide: the KI's "Ohne Zuordnung"
/// for a file whose page can be read ([readable]), as in the import.
RdImportCategory? rdUploadAiCategory(
  RdImportAiAnswer answer,
  RdUploadRead read, {
  required List<InstrumentInfo> instruments,
  required bool isChoir,
  required String workName,
  required bool readable,
}) {
  if (answer.category == RdImportCategory.other && readable) return null;
  return rdImportAnswerFor(answer.category, read.file, instruments: instruments, isChoir: isChoir, workTitle: workName);
}

/// Names of the groups [categories] create ("Neue Gruppe Oboe"), each once.
List<String> rdUploadNewGroups(Iterable<RdImportCategory> categories) => [
      ...{
        for (final c in categories)
          for (final g in c.each)
            if (g.newGroup != null) g.newGroup!,
      },
    ];
