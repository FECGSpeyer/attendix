import 'dart:typed_data';

import 'package:attendix/core/services/native/native_file_service.dart';
import 'package:attendix/core/services/native/native_platform.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/songs/presentation/widgets/song_file_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ionic 4.17.18–4.17.20 (open-file-web.spec): song files in an installed
/// web app and in the iOS app on Apple silicon Macs.
void main() {
  tearDown(() {
    debugIsNativeAppOverride = null;
    debugIsIosAppOnMacOverride = null;
    NativeFileService.debugReset();
  });

  group('iOS app on Mac (4.17.20)', () {
    test('opens http files in the browser instead of the native viewer',
        () async {
      debugIsNativeAppOverride = true;
      debugIsIosAppOnMacOverride = true;
      var viewer = false;
      Uri? launched;
      NativeFileService.downloadAndOpen = (_, __) async => viewer = true;
      NativeFileService.launchExternal = (uri) async {
        launched = uri;
        return true;
      };
      expect(
          await NativeFileService.openUrl('https://x.de/noten.pdf',
              fileName: 'noten.pdf'),
          isTrue);
      expect(viewer, isFalse);
      expect(launched.toString(), 'https://x.de/noten.pdf');
    });

    test('iPhone/iPad keep the native viewer', () async {
      debugIsNativeAppOverride = true;
      debugIsIosAppOnMacOverride = false;
      var viewer = false;
      NativeFileService.downloadAndOpen = (_, __) async => viewer = true;
      NativeFileService.launchExternal = (_) async => false;
      expect(await NativeFileService.openUrl('https://x.de/noten.pdf'), isTrue);
      expect(viewer, isTrue);
    });

    test('is not detected outside the iOS app', () async {
      debugIsNativeAppOverride = false;
      expect(await isIosAppOnMac(), isFalse);
    });
  });

  group('installed web app (4.17.19)', () {
    const sib = SongFile(
      url: 'https://x.de/satz.sib',
      fileName: 'satz.sib',
      fileType: 'application/octet-stream',
      instrumentId: 1,
    );

    Future<void> openIn(WidgetTester tester, SongFile file) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => openSongFileExternally(context, file),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('regular browser opens a new tab', (tester) async {
      NativeFileService.isStandaloneWeb = () => false;
      Uri? launched;
      NativeFileService.launchExternal = (uri) async {
        launched = uri;
        return true;
      };
      await openIn(tester, sib);
      expect(launched.toString(), 'https://x.de/satz.sib');
      expect(find.text('satz.sib'), findsNothing);
    });

    testWidgets(
        'files without preview get a download hint instead of a window',
        (tester) async {
      NativeFileService.isStandaloneWeb = () => true;
      var launched = false;
      NativeFileService.launchExternal = (_) async => launched = true;
      String? downloadedAs;
      NativeFileService.fetchBytes = (_) async => Uint8List.fromList([1, 2]);
      NativeFileService.browserDownload = (bytes, name) {
        downloadedAs = name;
        return true;
      };

      await openIn(tester, sib);
      expect(launched, isFalse);
      expect(find.text('satz.sib'), findsOneWidget);
      expect(find.textContaining('keine Vorschau'), findsOneWidget);

      await tester.tap(_button('Datei herunterladen'));
      await tester.pumpAndSettle();
      expect(downloadedAs, 'satz.sib');
    });

    testWidgets('closing the hint downloads nothing', (tester) async {
      NativeFileService.isStandaloneWeb = () => true;
      var fetched = false;
      NativeFileService.fetchBytes = (_) async {
        fetched = true;
        return Uint8List(0);
      };
      await openIn(tester, sib);
      await tester.tap(_button('Schließen'));
      await tester.pumpAndSettle();
      expect(fetched, isFalse);
      expect(find.text('satz.sib'), findsNothing);
    });
  });
}

/// Dialog buttons (md mode shows them in capitals).
Finder _button(String label) {
  String norm(String s) => s.toLowerCase().replaceAll('ß', 'ss');
  return find.byWidgetPredicate(
      (w) => w is Text && norm(w.data ?? '') == norm(label));
}
