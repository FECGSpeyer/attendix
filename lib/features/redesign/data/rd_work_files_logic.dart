import 'package:file_picker/file_picker.dart';

import 'package:flutter/foundation.dart' show setEquals;

import '../../../core/utils/instrument_matcher.dart';
import '../../../data/models/song/song.dart';

/// REDESIGN: rules of the desktop file workspace of a Werk (table, upload
/// queue, selection, keyboard), free of widgets so they can be tested.

/// Largest file the upload takes (as the old upload sheet).
const int rdMaxUploadBytes = 20 * 1024 * 1024;

enum RdUploadStatus { waiting, uploading, done, failed }

/// One file of the upload queue.
class RdUpload {
  const RdUpload({
    required this.id,
    required this.file,
    required this.instrumentId,
    this.note,
    this.replace = const [],
    this.status = RdUploadStatus.waiting,
    this.error,
    this.stored = false,
    this.storedUrl,
  });

  final int id;
  final PlatformFile file;
  final int? instrumentId;
  final String? note;

  /// Existing files removed before this one is stored ("Ersetzen").
  final List<SongFile> replace;
  final RdUploadStatus status;
  final String? error;

  /// The new file is stored; only removing [replace] is left (a retry does
  /// not upload it twice).
  final bool stored;

  /// URL of the stored new file.
  final String? storedUrl;

  RdUpload copyWith({RdUploadStatus? status, String? error, bool? stored, String? storedUrl}) => RdUpload(
        id: id,
        file: file,
        instrumentId: instrumentId,
        note: note,
        replace: replace,
        status: status ?? this.status,
        error: error,
        stored: stored ?? this.stored,
        storedUrl: storedUrl ?? this.storedUrl,
      );
}

/// State of the workspace of one Werk: the upload queue and the files that
/// were deleted but can still be restored ("Rückgängig").
class RdWorkFilesState {
  const RdWorkFilesState({this.uploads = const [], this.hidden = const {}, this.notice});

  final List<RdUpload> uploads;

  /// URLs of files deleted a moment ago (hidden until the delete is stored).
  final Set<String> hidden;

  /// Short message at the bottom ("„Stimme 1.pdf“ gelöscht · Rückgängig").
  final String? notice;

  int get total => uploads.length;
  int get doneCount => uploads.where((u) => u.status == RdUploadStatus.done).length;
  int get failedCount => uploads.where((u) => u.status == RdUploadStatus.failed).length;
  bool get busy => uploads.any((u) => u.status == RdUploadStatus.waiting || u.status == RdUploadStatus.uploading);

  RdWorkFilesState copyWith({List<RdUpload>? uploads, Set<String>? hidden, String? notice, bool clearNotice = false}) =>
      RdWorkFilesState(
        uploads: uploads ?? this.uploads,
        hidden: hidden ?? this.hidden,
        notice: clearNotice ? null : (notice ?? this.notice),
      );
}

/// Existing files an upload would clash with: a file of the same name, or
/// for a part, Aufnahme or Liedtext a file of that category. Free-text
/// categories ("Sonstige") only clash by name, as a Werk often has several.
List<SongFile> rdUploadConflicts(String name, int? instrumentId, List<SongFile> existing) => existing
    .where((f) => f.fileName == name || (instrumentId != null && f.instrumentId == instrumentId))
    .toList();

/// One part PDF exported from Sibelius with the part it was given.
typedef RdPartPdf = ({String name, int? instrumentId, String? note});

/// Which existing PDF each of [parts] replaces (null: added as new). Each
/// file is replaced by at most one part:
/// 1. a PDF of the same name,
/// 2. a PDF of the same part whose part numbers are the same ("Violine II"
///    replaces "05 Violine II.pdf", not "05 Violine I.pdf"; a leading
///    number of the file is the Werk's, not the part's),
/// 3. the only PDF of a part left, when only one part of it was exported.
List<SongFile?> rdPartReplacements(List<RdPartPdf> parts, List<SongFile> existing) {
  final pdfs = existing.where(_isPdfFile).toList();
  final result = List<SongFile?>.filled(parts.length, null);
  final used = <SongFile>{};

  void take(int part, SongFile file) {
    result[part] = file;
    used.add(file);
  }

  // 1. Same name.
  for (var i = 0; i < parts.length; i++) {
    final name = _stem(parts[i].name);
    final same = pdfs.where((f) => !used.contains(f) && _stem(f.fileName) == name).firstOrNull;
    if (same != null) take(i, same);
  }

  // 2. Same part and part numbers; the closer name first.
  final pairs = <({int part, SongFile file, int score})>[];
  for (var i = 0; i < parts.length; i++) {
    if (result[i] != null) continue;
    final words = _partWords(parts[i].name);
    for (final f in pdfs) {
      if (used.contains(f) || !_samePart(parts[i], f)) continue;
      final other = _partWords(f.fileName);
      if (!setEquals(words.numbers, other.numbers)) continue;
      pairs.add((part: i, file: f, score: words.words.intersection(other.words).length));
    }
  }
  pairs.sort((a, b) => b.score.compareTo(a.score));
  for (final p in pairs) {
    if (result[p.part] == null && !used.contains(p.file)) take(p.part, p.file);
  }

  // 3. One part exported, one PDF of it left.
  for (var i = 0; i < parts.length; i++) {
    if (result[i] != null) continue;
    final same = [
      for (var j = 0; j < parts.length; j++)
        if (_samePartOf(parts[i], parts[j])) j,
    ];
    final left = pdfs.where((f) => !used.contains(f) && _samePart(parts[i], f)).toList();
    if (same.length == 1 && left.length == 1) take(i, left.single);
  }
  return result;
}

/// The PDFs [part] may replace, those of its own part first.
List<SongFile> rdPartReplaceOptions(RdPartPdf part, List<SongFile> existing) {
  final pdfs =
      existing.where(_isPdfFile).toList()..sort((a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
  return [...pdfs.where((f) => _samePart(part, f)), ...pdfs.where((f) => !_samePart(part, f))];
}

bool _isPdfFile(SongFile f) {
  final type = f.fileType.toLowerCase();
  return type == 'application/pdf' || type == 'pdf' || f.fileName.toLowerCase().endsWith('.pdf');
}

bool _samePart(RdPartPdf part, SongFile f) {
  if (part.instrumentId != null) return f.instrumentId == part.instrumentId;
  final note = part.note ?? '';
  return note.isNotEmpty && f.instrumentId == null && f.note == note;
}

bool _samePartOf(RdPartPdf a, RdPartPdf b) =>
    a.instrumentId != null
        ? a.instrumentId == b.instrumentId
        : (a.note ?? '').isNotEmpty && a.note == b.note && b.instrumentId == null;

String _stem(String name) {
  final dot = name.lastIndexOf('.');
  return (dot > 0 ? name.substring(0, dot) : name).trim().toLowerCase();
}

const Map<String, int> _romans = {'i': 1, 'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6};

/// The words and part numbers (1–9, I–VI) of a file name, without its
/// extension and a leading number ("05 Violine II" → {violine}, {2}).
({Set<String> words, Set<int> numbers}) _partWords(String name) {
  final tokens = InstrumentMatcher.tokenize(_stem(name));
  final start = tokens.isNotEmpty && RegExp(r'^\d+$').hasMatch(tokens.first) && tokens.length > 1 ? 1 : 0;
  final words = <String>{};
  final numbers = <int>{};
  for (final t in tokens.skip(start)) {
    final n = int.tryParse(t) ?? _romans[t];
    if (n != null && n >= 1 && n <= 9) {
      numbers.add(n);
    } else {
      words.add(t);
    }
  }
  return (words: words, numbers: numbers);
}

/// The new file name of a rename, or null when nothing changes. Without an
/// extension the old one is kept ("Stimme 2" → "Stimme 2.pdf").
String? rdRenamedFileName(String old, String input) {
  var name = input.trim().replaceAll(RegExp(r'[/\\]'), '-');
  if (name.isEmpty || name == old) return null;
  final dot = old.lastIndexOf('.');
  if (dot > 0 && !name.contains('.')) name = '$name${old.substring(dot)}';
  return name == old ? null : name;
}

/// Whether a file can be renamed: very old uploads have no storageName and
/// are stored under their file name.
bool rdCanRename(SongFile file) => (file.storageName ?? '').isNotEmpty;

/// Row after a ↑ (-1) or ↓ (+1) press; the first press picks the first or
/// last row.
int rdNextIndex(int? current, int delta, int length) {
  if (length <= 0) return 0;
  if (current == null) return delta > 0 ? 0 : length - 1;
  return (current + delta).clamp(0, length - 1);
}

/// Rows between [anchor] and [target] (both included), for Umschalt+Klick
/// and Umschalt+↑↓.
Set<String> rdRangeSelection(List<String> order, String anchor, String target) {
  final a = order.indexOf(anchor);
  final b = order.indexOf(target);
  if (a < 0 || b < 0) return {target};
  final from = a < b ? a : b;
  final to = a < b ? b : a;
  return order.sublist(from, to + 1).toSet();
}
