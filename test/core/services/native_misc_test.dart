import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:attendix/core/services/audio_player/media_session.dart';
import 'package:attendix/core/services/audio_player/media_session_native.dart';
import 'package:attendix/core/services/native/native_file_service.dart';
import 'package:attendix/core/services/native/native_platform.dart';
import 'package:attendix/core/services/native/store_update_service.dart';
import 'package:attendix/shared/widgets/layout/root_back_button_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// NATIVE_MISC: native-only Ionic behaviour (Capacitor plugins) ported to
/// the Flutter app – file viewer, printer fallback, store update, media
/// session, Android back button, haptics and native-app ads.
void main() {
  tearDown(() {
    debugIsNativeAppOverride = null;
    NativeFileService.debugReset();
  });

  group('NativeFileService', () {
    test('cacheFileName keeps extension and strips umlauts/separators', () {
      expect(NativeFileService.cacheFileName('Einsam und allein - Flöte.pdf'),
          'Einsam_und_allein_-_Flote.pdf');
      expect(NativeFileService.cacheFileName('a/b\\c.PDF'), 'a_b_c.pdf');
      expect(NativeFileService.cacheFileName('Straße.mp3'), 'Strasse.mp3');
      expect(NativeFileService.cacheFileName('...'), 'datei');
      expect(NativeFileService.cacheFileName('noext'), 'noext');
    });

    test('fileNameFromUrl uses the last path segment without query', () {
      expect(
        NativeFileService.fileNameFromUrl(
            'https://x.supabase.co/storage/v1/object/public/songs/12/Noten%20A.pdf?token=1'),
        'Noten A.pdf',
      );
      expect(NativeFileService.fileNameFromUrl('https://x.de/'),
          startsWith('document_'));
    });

    test('web/desktop: openUrl launches the URL externally (unchanged)', () async {
      debugIsNativeAppOverride = false;
      var downloaded = false;
      Uri? launched;
      NativeFileService.downloadAndOpen = (_, __) async => downloaded = true;
      NativeFileService.launchExternal = (uri) async {
        launched = uri;
        return true;
      };
      expect(await NativeFileService.openUrl('https://x.de/a.pdf'), isTrue);
      expect(downloaded, isFalse);
      expect(launched.toString(), 'https://x.de/a.pdf');
    });

    test('native: openUrl downloads + opens in the system viewer', () async {
      debugIsNativeAppOverride = true;
      String? name;
      var launched = false;
      NativeFileService.downloadAndOpen = (url, fileName) async {
        name = fileName;
        return true;
      };
      NativeFileService.launchExternal = (_) async => launched = true;
      expect(await NativeFileService.openUrl('https://x.de/a.pdf', fileName: 'Noten.pdf'),
          isTrue);
      expect(name, 'Noten.pdf');
      expect(launched, isFalse);
    });

    test('native: viewer failure falls back to the external app', () async {
      debugIsNativeAppOverride = true;
      var launched = false;
      NativeFileService.downloadAndOpen =
          (_, __) async => throw const HttpException('404');
      NativeFileService.launchExternal = (_) async => launched = true;
      expect(await NativeFileService.openUrl('https://x.de/a.pdf'), isTrue);
      expect(launched, isTrue);
    });

    test('saveBytes: web shares/downloads, native opens viewer first', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final shared = <String>[];
      final opened = <String>[];
      NativeFileService.shareBytes = (_, name) async {
        shared.add(name);
        return true;
      };
      NativeFileService.writeAndOpen = (_, name) async {
        opened.add(name);
        return true;
      };

      debugIsNativeAppOverride = false;
      await NativeFileService.saveBytes(bytes, 'a.xlsx');
      expect(shared, ['a.xlsx']);
      expect(opened, isEmpty);

      debugIsNativeAppOverride = true;
      await NativeFileService.saveBytes(bytes, 'b.pdf');
      expect(opened, ['b.pdf']);
      expect(shared, ['a.xlsx']);

      // No app to open the file → share sheet fallback
      NativeFileService.writeAndOpen = (_, __) async => false;
      await NativeFileService.saveBytes(bytes, 'c.pdf');
      expect(shared, ['a.xlsx', 'c.pdf']);
    });

    test('printPdf: native print failure opens the viewer (Ionic fallback)', () async {
      final bytes = Uint8List.fromList([1]);
      final opened = <String>[];
      NativeFileService.layoutPdf = (_, __) async => throw Exception('no printer');
      NativeFileService.writeAndOpen = (_, name) async {
        opened.add(name);
        return true;
      };

      debugIsNativeAppOverride = true;
      expect(await NativeFileService.printPdf(bytes, 'Noten'), isFalse);
      expect(opened, ['Noten.pdf']);

      debugIsNativeAppOverride = false;
      expect(() => NativeFileService.printPdf(bytes, 'Noten'), throwsException);
    });
  });

  group('StoreUpdateService (Ionic LiveUpdate equivalent)', () {
    test('compareVersions matches Ionic semantics', () {
      expect(StoreUpdateService.compareVersions('1.2.0', '1.1.9'), 1);
      expect(StoreUpdateService.compareVersions('1.2', '1.2.0'), 0);
      expect(StoreUpdateService.compareVersions('0.6.0', '0.10.0'), -1);
      expect(StoreUpdateService.compareVersions('1.0.0+5', '1.0.0'), 0);
    });

    test('parseItunesLookup reads version and store URL', () {
      final r = StoreUpdateService.parseItunesLookup(
          '{"resultCount":1,"results":[{"version":"1.2.3","trackViewUrl":"https://apps.apple.com/app/x"}]}');
      expect(r?.version, '1.2.3');
      expect(r?.url, 'https://apps.apple.com/app/x');
      expect(StoreUpdateService.parseItunesLookup('{"resultCount":0,"results":[]}'), isNull);
      expect(StoreUpdateService.parseItunesLookup('garbage'), isNull);
    });

    test('no check outside the native app (web keeps service worker flow)', () async {
      debugIsNativeAppOverride = false;
      expect(await StoreUpdateService().check(), isNull);
    });
  });

  group('NativeMediaSessionBridge', () {
    test('forwards lock-screen buttons to the registered handlers', () async {
      late AttendixAudioHandler handler;
      final bridge = NativeMediaSessionBridge(init: (b) async {
        handler = AttendixAudioHandler(b);
        return handler;
      });
      final calls = <String>[];
      bridge.setActionHandler(MediaSessionAction.play, (_) => calls.add('play'));
      bridge.setActionHandler(MediaSessionAction.pause, (_) => calls.add('pause'));
      bridge.setActionHandler(
          MediaSessionAction.seekTo, (t) => calls.add('seek:${t?.inSeconds}'));
      bridge.setActionHandler(MediaSessionAction.nextTrack, (_) => calls.add('next'));

      bridge.setMetadata('Song', 'Attendix');
      bridge.setPlaybackState(MediaSessionPlayback.playing);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(handler.mediaItem.value?.title, 'Song');
      expect(handler.playbackState.value.playing, isTrue);

      await handler.play();
      await handler.pause();
      await handler.seek(const Duration(seconds: 42));
      await handler.skipToNext();
      expect(calls, ['play', 'pause', 'seek:42', 'next']);
    });

    test('controls follow track skipping and playing state', () {
      final bridge = NativeMediaSessionBridge(init: (b) async => AttendixAudioHandler(b));
      bridge.setPlaybackState(MediaSessionPlayback.paused);
      expect(bridge.buildPlaybackState().controls, [MediaControl.play]);
      bridge.setTrackSkipping(true);
      bridge.setPlaybackState(MediaSessionPlayback.playing);
      expect(bridge.buildPlaybackState().controls,
          [MediaControl.skipToPrevious, MediaControl.pause, MediaControl.skipToNext]);
      bridge.setPlaybackState(MediaSessionPlayback.none);
      expect(bridge.buildPlaybackState().processingState, AudioProcessingState.idle);
    });

    test('native init failure keeps the bridge a silent no-op', () async {
      final bridge = NativeMediaSessionBridge(init: (_) async => throw Exception('no service'));
      bridge.setMetadata('Song', 'Attendix');
      bridge.setPlaybackState(MediaSessionPlayback.playing);
      bridge.setPositionState(const Duration(minutes: 1), Duration.zero);
      bridge.clearMetadata();
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('RootBackButtonScope (Android back → exitApp)', () {
    testWidgets('exits at the root when enabled', (tester) async {
      var exited = 0;
      await tester.pumpWidget(MaterialApp(
        home: RootBackButtonScope(
          enabled: true,
          onExit: () => exited++,
          child: const Scaffold(body: Text('root')),
        ),
      ));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exited, 1);
    });

    testWidgets('pages above the shell still pop normally', (tester) async {
      var exited = 0;
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        home: RootBackButtonScope(
          enabled: true,
          onExit: () => exited++,
          child: const Scaffold(body: Text('root')),
        ),
      ));
      key.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('detail'))));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
      expect(exited, 0);
    });

    testWidgets('inactive on web/iOS/tests by default', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: RootBackButtonScope(child: Text('x')),
      ));
      expect(find.byType(PopScope), findsNothing);
    });
  });

  group('source checks', () {
    String read(String p) => File(p).readAsStringSync();

    test('main shell wraps the tabs in RootBackButtonScope', () {
      expect(read('lib/shared/widgets/layout/main_shell.dart'),
          contains('RootBackButtonScope('));
    });

    test('file open/save call sites use NativeFileService', () {
      expect(read('lib/features/songs/presentation/widgets/song_file_opener.dart'),
          contains('NativeFileService.openUrl'));
      expect(read('lib/features/self_service/presentation/widgets/song_options_sheet.dart'),
          contains('NativeFileService.openUrl'));
      expect(read('lib/features/settings/presentation/pages/files_page.dart'),
          contains('NativeFileService.openUrl'));
      final print = read('lib/features/songs/data/song_print_service.dart');
      expect(print, contains('NativeFileService.printPdf'));
      expect(print, isNot(contains('Printing.sharePdf')));
      for (final p in [
        'lib/core/services/export_service.dart',
        'lib/core/services/plan_export_service.dart',
        'lib/features/export/presentation/pages/export_page.dart',
        'lib/features/team_organization/presentation/pages/protocol_page.dart',
        'lib/features/settings/presentation/widgets/vorkurs_certificates.dart',
      ]) {
        expect(read(p), isNot(contains('Printing.sharePdf')), reason: p);
      }
    });

    test('haptics at the same places as Ionic (Light status, Medium remove)', () {
      expect(read('lib/features/attendance/presentation/widgets/attendance_detail/attendance_person_tile.dart'),
          contains('HapticHelper.light()'));
      expect(read('lib/features/attendance/presentation/pages/attendance_list_page.dart'),
          contains('HapticHelper.medium()'));
      expect(read('lib/features/history/presentation/pages/history_page.dart'),
          contains('HapticHelper.medium()'));
      expect(read('lib/core/utils/haptic_helper.dart'), contains('try {'));
    });

    test('native app ads / store promo are web-only (Ionic isNativePlatform)', () {
      expect(read('lib/shared/widgets/dialogs/native_app_ad.dart'), contains('!kIsWeb'));
      expect(read('lib/features/settings/presentation/widgets/app_promo_card.dart'),
          contains('!kIsWeb'));
    });

    test('update action on login + settings (Ionic installUpdate)', () {
      expect(read('lib/features/auth/presentation/pages/login_page.dart'),
          contains('l10n.loginInstallUpdate'));
      expect(read('lib/features/settings/presentation/pages/settings_page.dart'),
          contains('l10n.settingsInstallUpdate'));
    });

    test('Android is wired for audio_service', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('com.ryanheise.audioservice.AudioService'));
      expect(manifest, contains('FOREGROUND_SERVICE_MEDIA_PLAYBACK'));
      expect(read('android/app/src/main/kotlin/de/attendix/attendix/MainActivity.kt'),
          contains('AudioServiceActivity()'));
    });
  });
}
