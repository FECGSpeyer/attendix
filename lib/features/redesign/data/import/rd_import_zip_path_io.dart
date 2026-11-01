import 'dart:io' as io;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

/// Apps: the ZIP is read from disk piece by piece instead of all at once
/// (a Drive download can be several hundred MB).
InputStreamBase? rdOpenZipPath(String path) => InputFileStream(path);

/// Apps: native zlib (raw deflate of a ZIP entry), stopped as soon as more
/// than [limit] bytes come out, so an entry that claims a small size can
/// not fill the memory ([FormatException]).
List<int>? rdInflateAtMost(List<int> data, int limit) {
  final out = _LimitedSink(limit);
  final input = io.ZLibDecoder(raw: true).startChunkedConversion(out);
  const step = 64 * 1024;
  final bytes = data is Uint8List ? data : Uint8List.fromList(data);
  for (var i = 0; i < bytes.length; i += step) {
    input.add(Uint8List.sublistView(bytes, i, i + step > bytes.length ? bytes.length : i + step));
  }
  input.close();
  return out.builder.takeBytes();
}

class _LimitedSink implements Sink<List<int>> {
  _LimitedSink(this.limit);

  final int limit;
  final builder = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (builder.length + chunk.length > limit) throw const FormatException('unpacks to more than declared');
    builder.add(chunk);
  }

  @override
  void close() {}
}
