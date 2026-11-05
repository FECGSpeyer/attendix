import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/share_origin.dart';

/// Save and share a generated file on native platforms (iOS, Android,
/// macOS). [text] is the message next to the file (e.g. "Song-Dateien" for
/// the ZIP of a work); [sharePositionOrigin] anchors the iPad popover
/// (default: middle of the screen).
Future<void> saveZipFile(
  Uint8List data,
  String fileName, {
  String? text,
  Rect? sharePositionOrigin,
}) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(data);

  await Share.shareXFiles(
    [XFile(file.path)],
    text: text,
    sharePositionOrigin: sharePositionOrigin ?? shareOriginFor(),
  );
}
