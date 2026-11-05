import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:web/web.dart' as web;

/// Save a generated file on web platform - triggers browser download.
/// [text] and [sharePositionOrigin] only matter for the native share sheet.
Future<void> saveZipFile(
  Uint8List data,
  String fileName, {
  String? text,
  Rect? sharePositionOrigin,
}) async {
  // Create a blob from the data (type from the file name, not always ZIP)
  final blob = web.Blob(
    [data.toJS].toJS,
    web.BlobPropertyBag(type: _mimeType(fileName)),
  );

  // Create object URL
  final url = web.URL.createObjectURL(blob);

  // Create and click download link
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  web.document.body?.removeChild(anchor);

  // Revoke object URL after a delay
  Future.delayed(const Duration(seconds: 1), () {
    web.URL.revokeObjectURL(url);
  });
}

String _mimeType(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return switch (ext) {
    'zip' => 'application/zip',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'xls' => 'application/vnd.ms-excel',
    'csv' => 'text/csv',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}
