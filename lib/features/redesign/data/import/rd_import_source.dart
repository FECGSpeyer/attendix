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
  final Map<String, ArchiveFile> _files;
  final List<InputStreamBase> _streams;

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
    final files = <String, ArchiveFile>{};
    final streams = <InputStreamBase>[];
    var junk = 0;
    for (final zip in zips) {
      final path = zip.bytes != null ? null : rdPickedPath(zip);
      final InputStreamBase? input = zip.bytes != null ? InputStream(zip.bytes!) : (path == null ? null : rdOpenZipPath(path));
      if (input == null) throw FormatException(zip.name);
      streams.add(input);
      final Archive archive;
      try {
        archive = ZipDecoder().decodeBuffer(input);
      } catch (_) {
        throw FormatException(zip.name);
      }
      final stem = zipStem(zip.name);
      for (final file in archive.files) {
        if (!file.isFile) continue;
        var path = file.name.replaceAll('\\', '/');
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
        entries.add(RdImportEntry(path: path, size: file.size, modified: rdZipDate(file.lastModTime)));
      }
    }
    final names = {for (final z in zips) zipStem(z.name)};
    return RdImportSource._(names.length == 1 ? names.first : names.join(', '), entries, junk, files, streams);
  }

  /// Content of the file at [path]. Read freshly each time, so a large
  /// import does not keep every file in memory. Only files up to the upload
  /// limit are unpacked; a file whose length or checksum does not match the
  /// ZIP's directory is refused ([FormatException]).
  Uint8List read(String path) {
    final file = _files[path];
    if (file == null) throw StateError('not in import: $path');
    if (file.size > rdMaxUploadBytes) throw FormatException('too large: $path');
    final raw = file.rawContent;
    final Uint8List out;
    if (raw == null) {
      final content = file.content as List<int>;
      out = content is Uint8List ? content : Uint8List.fromList(content);
    } else {
      if (raw.length > rdMaxUploadBytes + 1024 * 1024) throw FormatException('too large: $path');
      raw.reset();
      final data = raw.toUint8List();
      raw.reset();
      final List<int> unpacked = switch (file.compressionType) {
        ZipFile.zipCompressionStore => data,
        ZipFile.zipCompressionDeflate => inflateBuffer(data) ?? Inflate(data).getBytes(),
        ZipFile.zipCompressionBZip2 => BZip2Decoder().decodeBytes(data),
        _ => throw FormatException('compression ${file.compressionType}: $path'),
      };
      out = unpacked is Uint8List ? unpacked : Uint8List.fromList(unpacked);
    }
    if (out.length != file.size) throw FormatException('length: $path');
    final crc = file.crc32;
    if (crc != null && getCrc32(out) != crc) throw FormatException('checksum: $path');
    return out;
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
  Future<void> close() async {
    for (final s in _streams) {
      try {
        await s.close();
      } catch (_) {}
    }
  }
}
