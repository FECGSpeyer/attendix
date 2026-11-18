import 'dart:convert';
import 'dart:io' show ContentType;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Decodes the single file part of an actual storage_client upload request.
/// The multipart envelope and cacheControl field are not file content.
/// Latin-1 preserves every payload byte while locating MIME delimiters.
({Uint8List bytes, String contentType}) storageUploadBody(
  http.Request request,
) {
  final type = ContentType.parse(request.headers['content-type']!);
  if (type.mimeType != 'multipart/form-data') {
    throw StateError('Expected a multipart storage upload, got $type');
  }
  final boundary = type.parameters['boundary']!;
  final parts = latin1.decode(request.bodyBytes).split('--$boundary');
  final file = parts.singleWhere((part) => part.contains('filename='));
  final separator = file.indexOf('\r\n\r\n');
  final headers = file.substring(0, separator).split('\r\n');
  final mime = headers.singleWhere(
    (header) => header.toLowerCase().startsWith('content-type:'),
  );
  return (
    bytes: Uint8List.fromList(
      latin1.encode(file.substring(separator + 4, file.length - 2)),
    ),
    contentType: mime.substring(mime.indexOf(':') + 1).trim(),
  );
}
