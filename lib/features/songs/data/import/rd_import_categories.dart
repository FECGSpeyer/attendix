part of 'rd_import_logic.dart';

// Instrument/part detection, multi-group splitting, clash keys, and question keys.

/// Types that clash with the same type already at the Werk.
const Set<String> _uniqueNotes = {'Partitur', 'Klavierauszug', 'Sibelius', 'Chor'};

/// Key of a category for "already there" and Fassungen; null for kinds a
/// Werk often has several of (recordings, texts, MIDI, Sonstige).
String? rdImportClashKey(RdImportCategory c) {
  if (c.newGroup != null) return 'new:${c.newGroup}';
  final id = c.instrumentId;
  if (id != null) return id > InstrumentMatcher.lyricsId ? 'g$id' : null;
  final note = c.note;
  return note != null && _uniqueNotes.contains(note) ? 'n$note' : null;
}

/// Whether the Werk [song] already has a file of [c]'s kind (its part).
bool _atSong(RdImportSong song, RdImportCategory c) {
  final clash = rdImportClashKey(c);
  return clash != null &&
      song.files.any((x) => rdImportClashKey(RdImportCategory(instrumentId: x.instrumentId, note: x.instrumentId == null ? x.note : null)) == clash);
}

/// Whether the Werk [song] has a file named [name] already; for a part for
/// several groups only when every group has it ("Posaune und Tuba.pdf" at
/// Posaune only: Tuba still gets it).
bool _sameName(RdImportSong song, String name, RdImportCategory c) {
  final same = song.files.where((x) => x.fileName == name);
  if (!c.isSeveral) return same.isNotEmpty;
  return c.groups.every((g) => same.any((x) =>
      rdImportClashKey(RdImportCategory(instrumentId: x.instrumentId, note: x.instrumentId == null ? x.note : null)) ==
      rdImportClashKey(g)));
}

/// Roman numerals as part numbers ("Violine II").
const Map<String, int> _roman = {'i': 1, 'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6};

int? _numberWord(String w) => int.tryParse(w) ?? _roman[w];

/// The name of a group without its part number and the number
/// ("Flöte 2" → (flöte, 2)).
({String base, int? number}) _splitPartNumber(String name) {
  final words = InstrumentMatcher.tokenize(name);
  if (words.length > 1) {
    final n = _numberWord(words.last);
    if (n != null) return (base: words.sublist(0, words.length - 1).join(' '), number: n);
  }
  return (base: words.join(' '), number: null);
}

/// The group of the same family with the part number of [fileName]: the
/// answer "фл → Flöte 1" puts "фл2.pdf" to Flöte 2 when that group exists.
int rdImportSiblingGroup(int groupId, String fileName, List<InstrumentInfo> groups, {String? workName}) {
  final group = groups.where((g) => g.id == groupId).firstOrNull;
  if (group == null) return groupId;
  final own = _splitPartNumber(group.name);
  if (own.number == null) return groupId;
  final term = InstrumentMatcher.partTerm(fileName, workName: workName) ?? fileName;
  final words = InstrumentMatcher.tokenize(term);
  int? fileNumber;
  for (final w in words.reversed) {
    fileNumber = _numberWord(w);
    if (fileNumber != null) break;
  }
  if (fileNumber == null || fileNumber == own.number) return groupId;
  for (final g in groups) {
    final other = _splitPartNumber(g.name);
    if (other.base == own.base && other.number == fileNumber) return g.id;
  }
  return groupId;
}

/// The words of a part name the questions are grouped by: without part
/// numbers ("Sax 1" and "Sax 2" are one question).
String? rdImportQuestionKey(String fileName, {String? workName}) {
  final term = InstrumentMatcher.partTerm(fileName, workName: workName);
  if (term == null) return null;
  final words = InstrumentMatcher.tokenize(term).where((w) => _numberWord(w) == null).toList();
  return words.isEmpty ? null : words.join(' ');
}

/// [rdImportQuestionKey] as written in the file name ("Sax", "фл").
String? rdImportQuestionLabel(String fileName, {String? workName}) => _questionLabel(fileName, workName: workName);

String? _questionLabel(String fileName, {String? workName}) {
  final term = InstrumentMatcher.partTerm(fileName, workName: workName);
  if (term == null) return null;
  final label = term
      .replaceAll(RegExp(r'(?<![\p{L}])(\d+|[IVX]+|[ivx]{1,3})(?![\p{L}])', unicode: true), ' ')
      .replaceAll(RegExp(r'^[\s\-–.,()_]+|[\s\-–.,()_]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return label.isEmpty ? null : label;
}

/// The part of a single file [fileName] (no folders) read as the import
/// reads it ([_readName]): used by the upload on the Werk page.
({FileCategoryGuess guess, String? newGroup, List<RdImportCategory> several}) rdImportReadName(
  String fileName, {
  required List<InstrumentInfo> instruments,
  required bool isChoir,
  required String workName,
}) =>
    _readName(
      RdImportEntry(path: fileName, size: 0),
      '',
      instruments,
      isChoir,
      {for (final g in instruments) g.name.trim().toLowerCase()},
      workName,
    );

/// The part of [e] read from its name (or its folder's), and the new group
/// a known instrument without a group in Attendix becomes ("Oboe").
({FileCategoryGuess guess, String? newGroup, List<RdImportCategory> several}) _readName(
  RdImportEntry e,
  String folder,
  List<InstrumentInfo> instruments,
  bool isChoir,
  Set<String> groupNames,
  String workName,
) {
  var guess = guessFileCategory(e.name, instruments: instruments, isChoir: isChoir);
  // A part named only by its folder ("Violine 1/Seite 1.pdf").
  final byFolderName = e.folders.isNotEmpty && e.folders.join('/') != folder ? '${e.folders.last} ${e.name}' : null;
  if (guess.confidence == MatchConfidence.none && byFolderName != null) {
    final byFolder = guessFileCategory(byFolderName, instruments: instruments, isChoir: isChoir);
    if (byFolder.instrumentId != null || byFolder.note != null) guess = byFolder;
  }
  bool open(FileCategoryGuess g) => g.confidence == MatchConfidence.none && g.instrumentId == null && g.note == null;
  // In a choir every sheet without a group is "Chor"; a voice that has no
  // group yet ("Tenor.pdf") comes first.
  final choirOnly = isChoir &&
      guess.note == kChoirAllNote &&
      open(guessFileCategory(e.name, instruments: instruments, isChoir: false));
  String? newGroup;
  if (open(guess) || choirOnly) {
    newGroup = InstrumentMatcher.knownGroup(e.name, isChoir: isChoir);
    if (newGroup == null && byFolderName != null && !choirOnly) {
      newGroup = InstrumentMatcher.knownGroup(byFolderName, isChoir: isChoir);
    }
    if (newGroup != null && groupNames.contains(newGroup.toLowerCase())) newGroup = null;
    if (newGroup != null && choirOnly) guess = const FileCategoryGuess(instrumentId: null, note: null, confidence: MatchConfidence.none);
  }
  var several = const <RdImportCategory>[];
  // Only the part of the name counts: "Le viole - Vl II.pdf" names no viola.
  final part = rdImportWithoutWorkName(e.name, workName);
  if (newGroup == null && _maybeSeveral(part, guess, instruments, isChoir, choirOnly: choirOnly)) {
    final named = rdImportNamedGroups(part, instruments, isChoir: isChoir);
    if (named.groups.length > 1) {
      if (named.sure) {
        several = named.groups;
      } else if (guess.confidence == MatchConfidence.sure) {
        // An instrument whose group is not sure ("Posaune 1 und Tuba" with
        // only "Posaune 1/2" … ): asked, not taken for one group.
        guess = FileCategoryGuess(instrumentId: guess.instrumentId, note: guess.note, confidence: MatchConfidence.unsure);
      }
    }
  }
  return (guess: guess, newGroup: newGroup, several: several);
}

/// Whether a part named [name] may go to several groups: it names two or
/// more instruments and is not a group of its own ("Posaune/Tuba"), a
/// recording, text or note like Partitur, nor a sheet with three or more
/// choir voices (the choir).
bool _maybeSeveral(String name, FileCategoryGuess guess, List<InstrumentInfo> instruments, bool isChoir, {required bool choirOnly}) {
  final id = guess.instrumentId;
  // In a choir a sheet of voices without groups is "Chor" only for now.
  if (guess.note != null && !choirOnly) return false;
  if (id != null && id <= InstrumentMatcher.lyricsId) return false;
  final named = InstrumentMatcher.knownGroups(name, isChoir: isChoir);
  if (named.length < 2) return false;
  // (no instrument besides the voices; outside a choir only "Sopran" counts)
  if (isChoir && named.length >= 3 && InstrumentMatcher.knownGroups(name).every((g) => g == 'Sopran')) return false;
  if (id != null && guess.confidence == MatchConfidence.sure) {
    final own = instruments.where((g) => g.id == id).firstOrNull;
    if (own != null && InstrumentMatcher.knownGroups(own.name, isChoir: isChoir).length > 1) return false;
  }
  return true;
}

/// [name] without its file ending and the Werk name [workName] in it ("Le
/// viole - Vl II.pdf" of "Le viole" → "Vl II"), for the instruments it names.
String rdImportWithoutWorkName(String name, String? workName) {
  var stem = name.replaceFirst(RegExp(r'\.[A-Za-z0-9]{1,5}$'), '');
  final words = (workName ?? '')
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .map(RegExp.escape)
      .toList();
  if (words.isEmpty) return stem;
  // With the Werk number in front of it ("02 Air Violine und Cello"): no
  // part number.
  stem = stem.replaceAll(
    RegExp('(?:^\\s*\\d+[\\s._\\-]*)?(?<![\\p{L}\\p{N}])${words.join(r'[\s_\-.,]+')}(?![\\p{L}\\p{N}])',
        caseSensitive: false, unicode: true),
    ' ',
  );
  final rest = stem.replaceAll(RegExp(r'^[\s\-–.,()]+|[\s\-–.,()]+$'), '').trim();
  return rest.isEmpty ? name : rest;
}

/// The groups of the instruments [name] names ("Posaune 1 und Tuba"): each
/// matched with its own number where it is written apart, a known
/// instrument without a group as a new group. [sure] is false when a group
/// is not sure (several groups "Posaune 1", "Posaune 2" for "Posaune"); the
/// likely one is in [groups] then.
({List<RdImportCategory> groups, bool sure}) rdImportNamedGroups(
  String name,
  List<InstrumentInfo> instruments, {
  required bool isChoir,
}) {
  final stem = name.replaceFirst(RegExp(r'\.[A-Za-z0-9]{1,5}$'), '');
  final pieces = stem.split(RegExp(r'\s+(?:und|u\.?|and|&|\+)\s+|\s*[,;&+]\s*|\s+[-–]\s+', caseSensitive: false));
  final groups = <RdImportCategory>[];
  var sure = true;
  int? group(PartMatch m) => m.instrumentId != null && m.instrumentId! > InstrumentMatcher.lyricsId ? m.instrumentId : null;
  String? missingNumbered(String piece, List<String> names) {
    if (names.length != 1) return null;
    final numbered = InstrumentMatcher.knownGroup(piece, isChoir: isChoir);
    if (numbered == null || numbered == names.single) return null;
    return instruments.any((g) => g.name.trim().toLowerCase() == numbered.toLowerCase()) ? null : numbered;
  }
  for (final piece in pieces) {
    final names = InstrumentMatcher.knownGroups(piece, isChoir: isChoir);
    for (final n in names) {
      // A piece for one instrument is matched with its number ("Posaune 1").
      final own = InstrumentMatcher.detect(names.length == 1 ? piece : n, instruments);
      final byName = names.length == 1 ? InstrumentMatcher.detect(n, instruments) : own;
      final RdImportCategory c;
      if (group(own) != null && own.confidence == MatchConfidence.sure) {
        c = RdImportCategory(instrumentId: group(own));
      } else if (group(byName) != null && byName.confidence == MatchConfidence.sure) {
        c = RdImportCategory(instrumentId: group(byName));
      } else if (group(own) == null && group(byName) == null) {
        // As for one part: "Violine 1" keeps its number.
        c = RdImportCategory(newGroup: names.length == 1 ? InstrumentMatcher.knownGroup(piece, isChoir: isChoir) ?? n : n);
      } else if (missingNumbered(piece, names) case final numbered?) {
        // "Violine 2" named, only "Violine 1" there: a new group, not Violine 1.
        c = RdImportCategory(newGroup: numbered);
      } else {
        sure = false;
        c = RdImportCategory(instrumentId: group(own) ?? group(byName));
      }
      if (!groups.contains(c)) groups.add(c);
    }
  }
  return (groups: groups, sure: sure);
}

/// Whether the first page of [file] can be shown (PDF or image).
bool rdImportPreviewable(RdImportFile file) => const {'pdf', 'png', 'jpg', 'jpeg'}.contains(file.entry.extension);

/// Key of a Werk number for [RdImportPlan.takenNumbers] ("S|12").
String rdImportNumberKey(String? prefix, int number) => '${(prefix ?? '').trim().toUpperCase()}|$number';
