import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'native_file_service.dart' show NativeFileService;

/// NATIVE_MISC: writes [bytes] to the cache dir and opens the system viewer
/// (Ionic `Filesystem.writeFile(Directory.Cache)` +
/// `FileViewer.openDocumentFromLocalPath`). Returns false when no app could
/// open the file.
Future<bool> writeAndOpen(Uint8List bytes, String fileName) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/attendix_files');
  if (!await dir.exists()) await dir.create(recursive: true);
  final file = File('${dir.path}/${NativeFileService.cacheFileName(fileName)}');
  await file.writeAsBytes(bytes, flush: true);
  final result = await OpenFilex.open(file.path);
  return result.type == ResultType.done;
}

/// NATIVE_MISC: downloads [url] and opens it in the system viewer
/// (Ionic `FileViewer.openDocumentFromUrl`).
Future<bool> downloadAndOpen(String url, String fileName) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
  }
  return writeAndOpen(response.bodyBytes, fileName);
}
