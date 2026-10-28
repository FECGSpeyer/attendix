import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/l10n.dart';

/// Save and share ZIP file on native platforms (iOS, Android, macOS)
Future<void> saveZipFile(Uint8List data, String fileName) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(data);

  await Share.shareXFiles(
    [XFile(file.path)],
    text: l10nWithoutContext.coreFlutterSongFiles,
  );
}
