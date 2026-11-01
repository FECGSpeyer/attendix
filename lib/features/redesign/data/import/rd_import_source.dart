import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import 'rd_import_logic.dart';
import 'rd_import_zip_path_stub.dart' if (dart.library.io) 'rd_import_zip_path_io.dart';

/// REDESIGN: the files of the import, read from one or more ZIPs (Google
/// Drive splits large folders into "…-001.zip", "…-002.zip"). Contents are
/// read only when needed (duplicates, dates, upload).
class RdImportSource {
  RdImportSource._(this.name, this.entries, this.junk, this._files, this._streams);

  /// Shown name ("Noten (Speyer)").
  final String name;
  final List<RdImportEntry> entries;

  /// System files left out (.DS_Store, __MACOSX …).
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
      final InputStreamBase? input =
          zip.bytes != null ? InputStream(zip.bytes!) : (zip.path == null ? null : rdOpenZipPath(zip.path!));
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
  /// import does not keep every file in memory.
  Uint8List read(String path) {
    final file = _files[path];
    if (file == null) throw StateError('not in import: $path');
    final raw = file.rawContent;
    if (raw == null) {
      final content = file.content as List<int>;
      return content is Uint8List ? content : Uint8List.fromList(content);
    }
    raw.reset();
    final data = raw.toUint8List();
    raw.reset();
    switch (file.compressionType) {
      case ZipFile.zipCompressionStore:
        return data;
      case ZipFile.zipCompressionDeflate:
        final out = inflateBuffer(data) ?? Inflate(data).getBytes();
        return out is Uint8List ? out : Uint8List.fromList(out);
      case ZipFile.zipCompressionBZip2:
        return Uint8List.fromList(BZip2Decoder().decodeBytes(data));
      default:
        throw FormatException('compression ${file.compressionType}: $path');
    }
  }

  Future<void> close() async {
    for (final s in _streams) {
      try {
        await s.close();
      } catch (_) {}
    }
  }
}
