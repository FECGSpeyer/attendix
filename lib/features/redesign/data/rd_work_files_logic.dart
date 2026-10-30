import 'package:file_picker/file_picker.dart';

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
