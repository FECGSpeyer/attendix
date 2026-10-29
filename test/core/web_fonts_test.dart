// WEB_FONTS: bundled Roboto with real weights for the web build (CanvasKit
// only has Roboto Regular and fakes semibold / bold).

import 'dart:io';

import 'package:attendix/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `usWeightClass` and italic bit of the `OS/2` table of a TrueType file.
(int weight, bool italic) _os2(String path) {
  final data = ByteData.sublistView(File(path).readAsBytesSync());
  expect(data.getUint32(0), 0x00010000, reason: '$path is no TrueType font');
  final numTables = data.getUint16(4);
  for (var i = 0; i < numTables; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes(
        [for (var b = 0; b < 4; b++) data.getUint8(record + b)]);
    if (tag == 'OS/2') {
      final offset = data.getUint32(record + 8);
      final fsSelection = data.getUint16(offset + 62);
      return (data.getUint16(offset + 4), fsSelection & 1 == 1);
    }
  }
  fail('$path has no OS/2 table');
}

void main() {
  const fonts = {
    'assets/fonts/Roboto-Regular.ttf': (400, false),
    'assets/fonts/Roboto-Italic.ttf': (400, true),
    'assets/fonts/Roboto-Medium.ttf': (500, false),
    'assets/fonts/Roboto-SemiBold.ttf': (600, false),
    'assets/fonts/Roboto-Bold.ttf': (700, false),
  };

  test('pubspec registers Roboto 400/500/600/700 (+ italic) as one family',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- family: ${AppTheme.webFontFamily}\n'));
    for (final entry in fonts.entries) {
      final (weight, italic) = entry.value;
      expect(
        pubspec,
        contains('- asset: ${entry.key}\n          weight: $weight'
            '${italic ? '\n          style: italic' : ''}\n'),
        reason: entry.key,
      );
    }
    // the badge-only font was replaced by the family
    expect(pubspec, isNot(contains('family: IonBadge')));
  });

  test('font files carry the declared weights, small Latin subsets', () {
    var total = 0;
    for (final entry in fonts.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: entry.key);
      final size = file.lengthSync();
      total += size;
      expect(size, lessThan(40 * 1024), reason: '${entry.key}: $size B');
      expect(_os2(entry.key), entry.value, reason: entry.key);
    }
    expect(total, lessThan(200 * 1024));
    final licence = File('assets/fonts/Roboto-OFL.txt').readAsStringSync();
    expect(licence, contains('SIL Open Font License, Version 1.1'));
  });

  group('theme', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final brightness in Brightness.values) {
        test('web ($platform, $brightness) uses the bundled Roboto', () {
          final theme =
              AppTheme.forPlatform(brightness, platform, web: true);
          for (final style in [
            theme.textTheme.bodyMedium,
            theme.textTheme.bodyLarge,
            theme.textTheme.titleMedium,
            theme.textTheme.labelLarge,
            theme.primaryTextTheme.titleLarge,
          ]) {
            expect(style!.fontFamily, AppTheme.webFontFamily);
          }
        });
      }
    }

    test('native iOS keeps the system font (SF), not Roboto', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final theme = AppTheme.forPlatform(
          Brightness.light, TargetPlatform.iOS,
          web: false);
      expect(theme.textTheme.bodyMedium!.fontFamily, 'CupertinoSystemText');
      expect(theme.textTheme.titleMedium!.fontFamily,
          isNot(AppTheme.webFontFamily));
    });

    testWidgets('web: bold text inherits the bundled family', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS,
            web: true),
        home: const Scaffold(
          body: Text('Anwesend',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ));
      final rich = tester.widget<RichText>(find.descendant(
          of: find.text('Anwesend'), matching: find.byType(RichText)));
      expect(rich.text.style!.fontFamily, AppTheme.webFontFamily);
      expect(rich.text.style!.fontWeight, FontWeight.w600);
    });
  });
}
