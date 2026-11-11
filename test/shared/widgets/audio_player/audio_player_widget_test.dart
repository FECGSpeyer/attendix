import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/core/services/audio_player/audio_player_service.dart';
import 'package:attendix/core/services/audio_player/audio_player_state.dart';
import 'package:attendix/shared/widgets/audio_player/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubService extends AudioPlayerService {
  _StubService(this._state);
  AudioPlayerState _state;

  @override
  AudioPlayerState build() => _state;

  void setForTest(AudioPlayerState s) {
    _state = s;
    state = s;
  }
}

Widget _harness({required AudioPlayerState initial}) {
  final stub = _StubService(initial);
  return ProviderScope(
    overrides: [
      audioPlayerServiceProvider.overrideWith(() => stub),
    ],
    child: const MaterialApp(
      home: Scaffold(body: AudioPlayerWidget()),
    ),
  );
}

void main() {
  group('AudioPlayerWidget', () {
    testWidgets('renders nothing when no file is loaded', (tester) async {
      await tester.pumpWidget(_harness(initial: const AudioPlayerState()));
      expect(find.byType(Slider), findsNothing);
      expect(find.byIcon(AppIcons.playCircleFill), findsNothing);
    });

    testWidgets('shows song title and current/total time when a file is loaded',
        (tester) async {
      await tester.pumpWidget(_harness(
        initial: const AudioPlayerState(
          currentUrl: 'https://example.com/a.mp3',
          currentFileName: 'a.mp3',
          currentSongName: 'Konzert in D',
          isPlaying: true,
          currentTime: Duration(seconds: 12),
          duration: Duration(minutes: 3, seconds: 30),
        ),
      ));

      expect(find.text('Konzert in D'), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);
      expect(find.text('3:30'), findsOneWidget);
      expect(find.byIcon(AppIcons.pauseCircleFilled), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('falls back to file name when songName is empty',
        (tester) async {
      await tester.pumpWidget(_harness(
        initial: const AudioPlayerState(
          currentUrl: 'https://example.com/foo.mp3',
          currentFileName: 'foo.mp3',
          duration: Duration(minutes: 1),
        ),
      ));

      expect(find.text('foo.mp3'), findsOneWidget);
    });
  });
}
