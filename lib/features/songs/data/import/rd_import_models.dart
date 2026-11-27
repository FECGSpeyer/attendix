part of 'rd_import_logic.dart';

// Data models for the Noten-Import plan, decisions, file/work state, and upload items.

// ---------------------------------------------------------------------------
// Input

/// A file of the source (one entry of the ZIP).
class RdImportEntry {
  const RdImportEntry({required this.path, required this.size, this.modified});

  /// Path inside the source with "/" ("Noten/120 Wie wunderbar/Violine 1.pdf").
  final String path;
  final int size;

  /// Last change stored in the ZIP (Google Drive: when it was uploaded there).
  final DateTime? modified;

  String get name => path.substring(path.lastIndexOf('/') + 1);

  /// The folders above the file, top first.
  List<String> get folders {
    final parts = path.split('/');
    return [for (final p in parts.sublist(0, parts.length - 1)) if (p.trim().isNotEmpty) p];
  }

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  }
}

/// A Werk already in Attendix, as far as the import needs it.
class RdImportSong {
  const RdImportSong({required this.id, required this.name, this.number, this.prefix, this.files = const []});

  final int id;
  final String name;
  final int? number;
  final String? prefix;
  final List<SongFile> files;

  String get label => [if ((prefix ?? '').trim().isNotEmpty || number != null) '${(prefix ?? '').trim()}${number ?? ''}', name].join(' ');
}

/// How sure the Werk in Attendix is.
enum RdMatchKind {
  /// Number and title fit (or the very same title without number).
  sure,

  /// The number fits, the title does not.
  numberOnly,

  /// The title fits, the number is another one or missing.
  titleOnly,

  /// Several Werke fit equally well ("A1 Stille Nacht", "B1 Stille Nacht"
  /// for the folder "1 Stille Nacht").
  ambiguous,

  /// The KI named this Werk (other spelling, translation): to be checked.
  byAi,

  /// No Werk fits: a new one is created.
  none,
}

class RdWorkMatch {
  const RdWorkMatch(this.kind, [this.songId]);

  static const RdWorkMatch none = RdWorkMatch(RdMatchKind.none);

  final RdMatchKind kind;
  final int? songId;
}

// ---------------------------------------------------------------------------
// Categories

/// What a file becomes in Attendix: a group (part), a type (Partitur …),
/// a group still to be created, or "Sonstige" (all null).
class RdImportCategory {
  const RdImportCategory({this.instrumentId, this.note, this.newGroup})
      : groups = const [],
        fromPage = false;

  /// A part for several groups ("Posaune und Tuba"): the file is stored once
  /// for each of [groups] (Leon, 07.11.2026).
  const RdImportCategory.several(this.groups)
      : instrumentId = null,
        note = null,
        newGroup = null,
        fromPage = false;

  /// Only as the answer to a question ("Solo", "Parts"): each file gets
  /// the part the KI reads on its first page, as if nobody had answered
  /// (Leon, 08.11.2026). Never the category of a file.
  const RdImportCategory.fromPage()
      : instrumentId = null,
        note = null,
        newGroup = null,
        groups = const [],
        fromPage = true;

  static const RdImportCategory other = RdImportCategory();

  final int? instrumentId;
  final String? note;

  /// Name of a group created on upload ("Neue Gruppe anlegen").
  final String? newGroup;

  /// The groups of a part for several groups (each a group or a new group);
  /// empty for any other category.
  final List<RdImportCategory> groups;

  /// [RdImportCategory.fromPage].
  final bool fromPage;

  bool get isSeveral => groups.isNotEmpty;

  /// What a file of this category is stored as: once per group of a part
  /// for several groups, else once as it is.
  List<RdImportCategory> get each => groups.isEmpty ? [this] : groups;

  bool get isPart => isSeveral || newGroup != null || (instrumentId != null && instrumentId! > InstrumentMatcher.lyricsId);

  @override
  bool operator ==(Object other) =>
      other is RdImportCategory &&
      other.instrumentId == instrumentId &&
      other.note == note &&
      other.newGroup == newGroup &&
      other.fromPage == fromPage &&
      other.groups.length == groups.length &&
      Iterable.generate(groups.length).every((i) => other.groups[i] == groups[i]);

  @override
  int get hashCode => Object.hash(instrumentId, note, newGroup, fromPage, Object.hashAll(groups));
}

// ---------------------------------------------------------------------------
// The plan

/// Why a file is left out.
enum RdSkipReason {
  /// File type Attendix does not keep (ZIP inside, Excel, shortcut …).
  unsupported,

  /// Larger than an upload may be.
  tooLarge,

  /// The same file once more (same size and content).
  duplicate,

  /// The Werk is not imported.
  workSkipped,

  /// Belongs to a Fassung that is not taken.
  otherFassung,

  /// A file of that name is already at the Werk in Attendix.
  sameName,

  /// A Word file next to a PDF of the same name.
  wordNextToPdf,

  /// The Werk in Attendix already has this part.
  partExists,

  /// Left out by hand.
  byHand,
}

/// A file in the plan.
class RdImportFile {
  const RdImportFile({
    required this.entry,
    required this.fassungKey,
    required this.guess,
    this.questionKey,
    this.hardSkip,
    this.besidePdf = false,
    this.newGroup,
    this.several = const [],
  });

  final RdImportEntry entry;

  /// The sub-folder (version) it lies in.
  final String fassungKey;

  /// Category read from the name.
  final FileCategoryGuess guess;

  /// Question it is part of ([RdImportQuestion.key]).
  final String? questionKey;

  /// Left out whatever is decided (type, size, duplicate).
  final RdSkipReason? hardSkip;

  /// Word/text file with a PDF of the same name next to it.
  final bool besidePdf;

  /// A known instrument without a group in Attendix ("Oboe"): becomes a new
  /// group unless the person decides otherwise.
  final String? newGroup;

  /// The name names two or more instruments ("Posaune und Tuba"): their
  /// groups (or new groups), the file goes to each of them.
  final List<RdImportCategory> several;

  String get path => entry.path;
  String get name => entry.name;

  RdImportCategory get guessed => several.isNotEmpty
      ? RdImportCategory.several(several)
      : guess.instrumentId == null && guess.note == null && newGroup != null
          ? RdImportCategory(newGroup: newGroup)
          : RdImportCategory(instrumentId: guess.instrumentId, note: guess.note);
}

/// A version of a Werk: the files of one sub-folder.
class RdImportFassung {
  const RdImportFassung({required this.key, required this.label, required this.fileCount, this.newest, this.isOld = false});

  final String key;

  /// Folder shown ("Alt", "Dirigenten"); empty = the Werk folder itself.
  final String label;
  final int fileCount;

  /// Newest date of its files (inside the PDFs, else from the ZIP).
  final DateTime? newest;

  /// In a folder like "Alt" or "Alte Version".
  final bool isOld;
}

/// A Werk of the import: one or more folders that belong to the same Werk.
class RdImportWork {
  const RdImportWork({
    required this.key,
    required this.title,
    required this.folders,
    required this.match,
    required this.files,
    this.number,
    this.prefix,
    this.fassungen = const [],
    this.defaultFassung,
  });

  final String key;

  /// Title from the folder name (number taken off).
  final String title;
  final int? number;
  final String? prefix;

  /// Folder paths in the source.
  final List<String> folders;
  final RdWorkMatch match;
  final List<RdImportFile> files;

  /// Two or more competing versions (empty when there is only one).
  final List<RdImportFassung> fassungen;

  /// Proposed version ([RdImportFassung.key]); null = all.
  final String? defaultFassung;

  /// Name in the source ("120 Wie wunderbar").
  String get folderName => folders.isEmpty ? title : folders.first.split('/').last;
}

/// A part name Attendix does not know, asked once for all its files.
class RdImportQuestion {
  const RdImportQuestion({
    required this.key,
    required this.label,
    required this.fileCount,
    required this.works,
    this.files = const [],
    this.examples = const [],
    this.suggestion,
    this.newGroup,
    this.several = const [],
  });

  final String key;

  /// As written in the files ("Sax", "фл").
  final String label;
  final int fileCount;

  /// Titles of some Werke it appears in.
  final List<String> works;

  /// Names of some files it appears in ("Sax 1.pdf").
  final List<String> files;

  /// Some of its files with their Werk, to look at the first page (PDFs,
  /// then images first: a PDF among the files is always one of them).
  final List<({RdImportFile file, String work})> examples;

  /// Group the name might mean (unsure match).
  final int? suggestion;

  /// A known instrument without a group: "Neue Gruppe" with this name is
  /// the answer while the person gives none.
  final String? newGroup;

  /// The groups a part for several groups goes to while the person gives no
  /// answer ("Posaune und Tuba", one of them new).
  final List<RdImportCategory> several;

  /// The answer that counts while none is given.
  RdImportCategory? get proposed => several.isNotEmpty
      ? RdImportCategory.several(several)
      : newGroup == null
          ? null
          : RdImportCategory(newGroup: newGroup);
}

class RdImportPlan {
  const RdImportPlan({
    required this.works,
    required this.questions,
    required this.songs,
    required this.instruments,
    required this.junk,
    this.isChoir = false,
    this.newPrefix,
    this.takenNumbers = const {},
    this.pageReads = const {},
  });

  final List<RdImportWork> works;
  final List<RdImportQuestion> questions;

  /// The Werke in Attendix by id.
  final Map<int, RdImportSong> songs;

  /// The groups (without main group).
  final List<InstrumentInfo> instruments;
  final bool isChoir;

  /// System files left out on reading.
  final int junk;

  /// Kürzel of new Werke: the Sammlung's, when the Noten go into one (null:
  /// Repertoire, the folder's own prefix).
  final String? newPrefix;

  /// Numbers in use anywhere in the group ([rdImportNumberKey]), also in
  /// other Sammlungen than [songs].
  final Set<String> takenNumbers;

  /// What the KI read on page 1 of files whose name says no part, by path.
  final Map<String, RdImportPageRead> pageReads;

  int get fileCount => works.fold(0, (sum, w) => sum + w.files.length);

  RdImportWork? work(String key) => works.where((w) => w.key == key).firstOrNull;
}

/// The part the KI read on the first page of a file ([rdImportPagesToRead]).
class RdImportPageRead {
  const RdImportPageRead(this.category, {this.label, this.sure = false});

  final RdImportCategory category;

  /// The part name as printed ("1. Violine").
  final String? label;

  /// Taken without a look; otherwise only proposed and the file stays
  /// "Stimme unklar".
  final bool sure;
}

/// Where the files of a Werk go.
class RdWorkTarget {
  const RdWorkTarget.song(int this.songId)
      : name = null,
        number = null,
        prefix = null,
        skip = false;

  const RdWorkTarget.create({required String this.name, this.number, this.prefix})
      : songId = null,
        skip = false;

  const RdWorkTarget.skip()
      : songId = null,
        name = null,
        number = null,
        prefix = null,
        skip = true;

  /// Existing Werk.
  final int? songId;

  /// New Werk.
  final String? name;
  final int? number;
  final String? prefix;
  final bool skip;

  bool get isNew => name != null;

  @override
  bool operator ==(Object other) =>
      other is RdWorkTarget &&
      other.songId == songId &&
      other.name == name &&
      other.number == number &&
      other.prefix == prefix &&
      other.skip == skip;

  @override
  int get hashCode => Object.hash(songId, name, number, prefix, skip);
}

/// What the person decided while checking. Everything not decided follows
/// the plan.
class RdImportDecisions {
  const RdImportDecisions({
    this.targets = const {},
    this.fassungen = const {},
    this.take = const {},
    this.categories = const {},
    this.answers = const {},
    this.confirmed = const {},
    this.recheck = const {},
    this.skipWordBesidePdf = true,
    this.proposeFassung = true,
  });

  /// Werk key → where its files go.
  final Map<String, RdWorkTarget> targets;

  /// Werk key → chosen Fassung key (null = all Fassungen).
  final Map<String, String?> fassungen;

  /// File path → take (true) or leave out (false) by hand.
  final Map<String, bool> take;

  /// File path → category chosen by hand.
  final Map<String, RdImportCategory> categories;

  /// Question key → answer.
  final Map<String, RdImportCategory> answers;

  /// Werke someone looked at ("Passt so").
  final Set<String> confirmed;

  /// Werke whose "Passt so" a later change took back: they wait for
  /// another look, even when nothing is flagged any more.
  final Set<String> recheck;

  /// Switch "Word weglassen, wenn PDF daneben liegt".
  final bool skipWordBesidePdf;

  /// Switch "Neueste Fassung vorschlagen" (off: all Fassungen).
  final bool proposeFassung;

  RdImportDecisions copyWith({
    Map<String, RdWorkTarget>? targets,
    Map<String, String?>? fassungen,
    Map<String, bool>? take,
    Map<String, RdImportCategory>? categories,
    Map<String, RdImportCategory>? answers,
    Set<String>? confirmed,
    Set<String>? recheck,
    bool? skipWordBesidePdf,
    bool? proposeFassung,
  }) =>
      RdImportDecisions(
        targets: targets ?? this.targets,
        fassungen: fassungen ?? this.fassungen,
        take: take ?? this.take,
        categories: categories ?? this.categories,
        answers: answers ?? this.answers,
        confirmed: confirmed ?? this.confirmed,
        recheck: recheck ?? this.recheck,
        skipWordBesidePdf: skipWordBesidePdf ?? this.skipWordBesidePdf,
        proposeFassung: proposeFassung ?? this.proposeFassung,
      );
}

enum RdImportNumberProblem { required, invalid, taken }

/// State of one file after all decisions.
class RdFileState {
  const RdFileState({
    required this.take,
    required this.category,
    this.reason,
    this.canToggle = true,
    this.unclear = false,
    this.byHand = false,
    this.pageRead,
  });

  final bool take;
  final RdImportCategory category;

  /// Why it is left out (null when taken).
  final RdSkipReason? reason;

  /// Can be taken / left out by hand.
  final bool canToggle;

  /// Taken, but nobody knows which part it is.
  final bool unclear;

  /// Category chosen by hand or by an answer (remembered as synonym).
  final bool byHand;

  /// The part the KI read on page 1, while nobody chose one ([unclear]
  /// still when it is not sure).
  final RdImportPageRead? pageRead;

  /// [unclear], but the KI proposed the part from page 1: shown as its
  /// proposal to check, not as "Stimme unklar".
  bool get proposedByAi => unclear && pageRead != null;
}

/// Why a Werk needs a look before it is uploaded.
enum RdWorkFlag {
  /// The Werk in Attendix is not sure.
  unsureMatch,

  /// Two or more Fassungen.
  fassungen,

  /// Parts it would add are already at the Werk.
  partExists,

  /// Files without a clear part.
  unclear,

  /// Files with a part the KI proposed from page 1, not sure enough to be
  /// taken without a look.
  aiProposal,
}

class RdWorkState {
  const RdWorkState({
    required this.target,
    required this.files,
    required this.flags,
    required this.confirmed,
    this.recheck = false,
  });

  final RdWorkTarget target;
  final Map<String, RdFileState> files;
  final Set<RdWorkFlag> flags;
  final bool confirmed;

  /// Its "Passt so" was taken back by a change ([RdImportDecisions.recheck]).
  final bool recheck;

  int get takeCount => files.values.where((f) => f.take).length;
  int get skipCount => files.length - takeCount;

  /// Waits for someone to look at it ("bitte prüfen"): flagged and not
  /// confirmed, or changed since it was.
  bool get open => !confirmed && !target.skip && (flags.isNotEmpty || recheck);

  /// Its files are uploaded.
  bool get ready => !open && !target.skip && takeCount > 0;
}

/// Counts for the overview and the upload button.
class RdImportSummary {
  const RdImportSummary({
    required this.works,
    required this.open,
    required this.ready,
    required this.newWorks,
    required this.skippedWorks,
    required this.take,
    required this.skip,
    required this.openQuestions,
  });

  final int works;

  /// Werke waiting for a look.
  final int open;

  /// Werke whose files are uploaded.
  final int ready;

  /// Of [ready]: new Werke.
  final int newWorks;
  final int skippedWorks;

  /// Files uploaded (of [ready] Werke).
  final int take;

  /// Files left out (all reasons, without files of open Werke).
  final int skip;
  final int openQuestions;
}

/// One file to upload.
class RdUploadItem {
  RdUploadItem({required this.work, required this.file, required this.category, List<RdImportCategory>? stores})
      : stores = stores ?? category.each;

  final RdImportWork work;
  final RdImportFile file;
  final RdImportCategory category;

  /// What the file is stored as: once, or once per group of a part for
  /// several groups (without the groups the Werk already has the part of).
  final List<RdImportCategory> stores;
}

/// Questions about names that most likely mean the same ([category]: the
/// answer, the KI's answer, the proposed new group or the matcher's guess;
/// null when nobody has a guess), to answer many with one tap ("Alle als
/// Trompete").
class RdImportQuestionGroup {
  const RdImportQuestionGroup(this.category, this.questions);

  final RdImportCategory? category;
  final List<RdImportQuestion> questions;

  int get fileCount => questions.fold(0, (n, q) => n + q.fileCount);
}
