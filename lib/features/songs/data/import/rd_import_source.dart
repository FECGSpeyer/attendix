import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/services/song_file_service.dart';
import '../rd_work_files_logic.dart' show rdMaxUploadBytes;
import 'rd_import_logic.dart';
import 'rd_import_zip_path_stub.dart' if (dart.library.io) 'rd_import_zip_path_io.dart';

/// The path of a picked file; null in the browser, where file_picker's
/// `path` getter throws, and when there is none.
String? rdPickedPath(PlatformFile file) {
  if (kIsWeb) return null;
  try {
    return file.path;
  } catch (_) {
    return null;
  }
}

/// A picked file that only comes as a stream (the browser with
/// `withReadStream`): its bytes are read in first.
bool rdIsStreamed(PlatformFile file) => file.bytes == null && file.readStream != null && rdPickedPath(file) == null;

/// REDESIGN: where the files of an import come from: ZIP files
/// ([RdImportSource]) or a shared Google Drive folder (RdDriveSource).
abstract class RdImportFiles {
  /// Shown name ("Noten (Speyer)").
  String get name;
  List<RdImportEntry> get entries;

  /// System files left out (.DS_Store, __MACOSX …).
  int get junk;

  /// A hash of the content of [path] when [hash] (same hash = same file;
  /// null when unknown) and the date inside the PDF when [date].
  Future<({String? hash, DateTime? date})> inspect(String path, {required bool hash, required bool date});

  /// Puts the file at [path] into the song as [fileName].
  Future<void> upload(
    SongFileService service, {
    required int songId,
    required String path,
    required String fileName,
    int? instrumentId,
    String? note,
    int? mainGroupId,
  });

  /// The whole file at [path], to show its first page in the review and let
  /// the KI read it; null when it cannot be had (too large, a Google Doc,
  /// not available).
  Future<Uint8List?> content(String path);

  /// Where the file at [path] opens outside the app (Drive); null for ZIPs.
  Uri? viewLink(String path);

  Future<void> close();
}

/// REDESIGN: the files of the import, read from one or more ZIPs (Google
/// Drive splits large folders into "…-001.zip", "…-002.zip"). Contents are
/// read only when needed (duplicates, dates, upload).
class RdImportSource implements RdImportFiles {
  RdImportSource._(this.name, this.entries, this.junk, this._files, this._streams);

  @override
  final String name;
  @override
  final List<RdImportEntry> entries;
  @override
  final int junk;
  final Map<String, ZipFile> _files;
  final List<InputStream> _streams;

  /// The name of a ZIP without Google Drive's date and part number
  /// ("Noten-20261031T174501Z-001.zip" → "Noten").
  static String zipStem(String fileName) {
    var stem = fileName.replaceFirst(RegExp(r'\.zip$', caseSensitive: false), '');
    stem = stem.replaceFirst(RegExp(r'-\d{8}T\d{6}Z(-\d{3})?$'), '').replaceFirst(RegExp(r'-\d{3}$'), '');
    return stem.trim().isEmpty ? fileName : stem.trim();
  }

  /// Opens [zips]. Throws [FormatException] when a file is no ZIP.
  static RdImportSource open(List<PlatformFile> zips) {
    final entries = <RdImportEntry>[];
    final files = <String, ZipFile>{};
    final streams = <InputStream>[];
    var junk = 0;
    for (final zip in zips) {
      final path = zip.bytes != null ? null : rdPickedPath(zip);
      final InputStream? input = zip.bytes != null ? InputMemoryStream(zip.bytes!) : (path == null ? null : rdOpenZipPath(path));
      if (input == null) throw FormatException(zip.name);
      streams.add(input);
      final Map<String, ZipFile> inZip;
      try {
        inZip = _filesOf(input);
      } catch (_) {
        throw FormatException(zip.name);
      }
      final stem = zipStem(zip.name);
      for (final MapEntry(key: name, value: file) in inZip.entries) {
        var path = name.replaceAll('\\', '/');
        while (path.startsWith('/')) {
          path = path.substring(1);
        }
        if (rdImportIsJunk(path)) {
          junk++;
          continue;
        }
        // Files right in the ZIP belong to a folder named like the ZIP.
        if (!path.contains('/')) path = '$stem/$path';
        // The same file in two parts of a split download.
        if (files.containsKey(path)) continue;
        files[path] = file;
        final modified = rdZipDate(file.lastModFileDate << 16 | file.lastModFileTime);
        entries.add(RdImportEntry(path: path, size: file.uncompressedSize, modified: modified));
      }
    }
    final names = {for (final z in zips) zipStem(z.name)};
    return RdImportSource._(names.length == 1 ? names.first : names.join(', '), entries, junk, files, streams);
  }

  /// The files of a ZIP by name, read from its directory only. Nothing is
  /// unpacked here: archive's `ZipDecoder` reads a symbolic link's target
  /// right away, and a manipulated link entry could unpack to any size.
  /// Folders and links are left out; of two entries with the same name the
  /// last counts, as in `ZipDecoder`.
  static Map<String, ZipFile> _filesOf(InputStream input) {
    final directory = ZipDirectory()..read(input);
    final files = <String, ZipFile>{};
    for (final header in directory.fileHeaders) {
      final file = header.file;
      if (file == null) continue;
      final attributes = header.externalFileAttributes;
      final type = (attributes >> 16) & 0xF000;
      final system = header.versionMadeBy >> 8;
      final folder = file.filename.endsWith('/') ||
          file.filename.endsWith('\\') ||
          (system == 0 && attributes & 0x10 != 0) ||
          // Unix: only regular files (or no type given), no folders or links.
          (system == 3 && type != 0x8000 && type != 0);
      if (!folder) files[file.filename] = file;
    }
    return files;
  }

  /// Content of the file at [path]. Read freshly each time, so a large
  /// import does not keep every file in memory. Only files up to the upload
  /// limit are unpacked, never to more than the size the ZIP declares; a
  /// file whose length or checksum does not match the ZIP's directory is
  /// refused ([FormatException]).
  Uint8List read(String path) {
    final file = _files[path];
    if (file == null) throw StateError('not in import: $path');
    final size = file.uncompressedSize;
    if (size > rdMaxUploadBytes || file.compressedSize > rdMaxUploadBytes + 1024 * 1024) {
      throw FormatException('too large: $path');
    }
    final out = OutputMemoryStream(size: size < 1 ? 1 : size);
    file
      ..verify = false
      ..throwOnError = true;
    try {
      // Stops while unpacking once more than the declared size comes out.
      file.decompress(out);
    } on ArchiveLimitException {
      throw const FormatException('unpacks to more than declared');
    } on FormatException catch (e) {
      throw FormatException('${e.message}: $path');
    }
    final bytes = out.getBytes();
    if (bytes.length != size) throw FormatException('length: $path');
    if (file.hasCrc32 && getCrc32(bytes) != file.crc32) throw FormatException('checksum: $path');
    return bytes;
  }

  @override
  Future<({String? hash, DateTime? date})> inspect(String path, {required bool hash, required bool date}) async {
    final bytes = read(path);
    return (
      hash: hash ? sha1.convert(bytes).toString() : null,
      date: date && path.toLowerCase().endsWith('.pdf') ? rdPdfDate(bytes) : null,
    );
  }

  @override
  Future<void> upload(
    SongFileService service, {
    required int songId,
    required String path,
    required String fileName,
    int? instrumentId,
    String? note,
    int? mainGroupId,
  }) async {
    final bytes = await Future(() => read(path));
    await service.uploadFile(
      songId: songId,
      file: PlatformFile(name: fileName, size: bytes.length, bytes: bytes),
      instrumentId: instrumentId,
      note: note,
      mainGroupId: mainGroupId,
      keepBesetzung: true,
    );
  }

  @override
  Future<Uint8List?> content(String path) async {
    try {
      return await Future(() => read(path));
    } catch (_) {
      return null;
    }
  }

  @override
  Uri? viewLink(String path) => null;

  @override
  Future<void> close() async {
    for (final s in _streams) {
      try {
        await s.close();
      } catch (_) {}
    }
  }
}
