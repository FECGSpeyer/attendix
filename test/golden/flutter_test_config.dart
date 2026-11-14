import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Setup for the golden images in this folder.
///
/// The images are rendered with the app's real fonts and icons, so a person
/// can read them (they are also shown as before/after on pull requests).
/// Text rendering differs between operating systems, so the images are made
/// and compared on Linux only (CI and the cloud containers); on macOS and
/// Windows the comparison is skipped.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadAppFonts();
  final previous = goldenFileComparator;
  if (previous is LocalFileComparator) {
    goldenFileComparator = _LinuxComparator(previous.basedir.resolve('golden_test.dart'));
  }
  await testMain();
}

/// Loads every font of the app bundle (Roboto, Material icons, Ionicons).
/// Roboto also stands in for the system fonts the iOS look asks for, and for
/// the test font ('FlutterTest') that text without a font family falls back
/// to in tests (on a device that is the system font).
Future<void> _loadAppFonts() async {
  const systemFamilies = [
    '.SF UI Display',
    '.SF UI Text',
    '.SF Pro Text',
    '.SF Pro Display',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
  ];
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    final assets = [
      for (final font in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) font['asset'] as String,
    ];
    for (final name in [family, if (family == 'Roboto') ...systemFamilies]) {
      final loader = FontLoader(name);
      for (final asset in assets) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  }
}

class _LinuxComparator extends LocalFileComparator {
  _LinuxComparator(super.testFile);

  /// Share of pixels that may differ (rounding between machines). A changed
  /// word or a moved widget is far above it.
  static const double _tolerance = 0.0005;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    if (!Platform.isLinux) {
      debugPrint('Golden $golden not compared: images are made on Linux only.');
      return true;
    }
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
