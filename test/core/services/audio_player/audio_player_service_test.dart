import 'dart:async';

import 'package:attendix/core/services/audio_player/audio_player_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class _FakeAudioPlayer implements AudioPlayer {
  final _playingCtrl = StreamController<bool>.broadcast();
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration?>.broadcast();
  final _processingStateCtrl = StreamController<ProcessingState>.broadcast();

  @override
  bool playing = false;
  @override
  Duration position = Duration.zero;
  String? lastUrl;
  bool disposed = false;

  @override
  Stream<bool> get playingStream => _playingCtrl.stream;

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;

  @override
  Stream<Duration?> get durationStream => _durationCtrl.stream;

  @override
  Stream<ProcessingState> get processingStateStream =>
      _processingStateCtrl.stream;

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    lastUrl = url;
    return const Duration(minutes: 3);
  }

  @override
  Future<void> play() async {
    playing = true;
    _playingCtrl.add(true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    _playingCtrl.add(false);
  }

  @override
  Future<void> stop() async {
    if (disposed) return;
    playing = false;
    _playingCtrl.add(false);
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    this.position = position ?? Duration.zero;
    _positionCtrl.add(this.position);
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await _playingCtrl.close();
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _processingStateCtrl.close();
  }

  // Test helpers
  void emitPosition(Duration p) => _positionCtrl.add(p);
  void emitProcessingState(ProcessingState s) => _processingStateCtrl.add(s);

  // Unused members throw to keep the test honest about coverage.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Fake whose `setUrl` always throws — for the failure-path test.
class _FailingSetUrlFake extends _FakeAudioPlayer {
  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    throw StateError('boom');
  }
}

/// Records the playback speed (REDESIGN "0,8×").
class _SpeedFake extends _FakeAudioPlayer {
  final speeds = <double>[];

  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);
}

void main() {
  group('AudioPlayerService.isAudioFile', () {
    test('matches all 9 supported extensions, case-insensitive', () {
      const cases = [
        'foo.mp3',
        'FOO.WAV',
        'piece.ogg',
        'voice.m4a',
        'note.aac',
        'tune.flac',
        'old.wma',
        'web.webm',
        'opus.opus',
        'CAPS.MP3',
      ];
      for (final c in cases) {
        expect(AudioPlayerService.isAudioFile(c), isTrue, reason: c);
      }
    });

    test('rejects non-audio extensions', () {
      expect(AudioPlayerService.isAudioFile('score.pdf'), isFalse);
      expect(AudioPlayerService.isAudioFile('cover.jpg'), isFalse);
      expect(AudioPlayerService.isAudioFile(''), isFalse);
    });
  });

  group('AudioPlayerService.formatTime', () {
    test('formats Duration as m:ss', () {
      expect(AudioPlayerService.formatTime(Duration.zero), '0:00');
      expect(
        AudioPlayerService.formatTime(const Duration(seconds: 5)),
        '0:05',
      );
      expect(
        AudioPlayerService.formatTime(const Duration(minutes: 1, seconds: 30)),
        '1:30',
      );
      expect(
        AudioPlayerService.formatTime(
          const Duration(minutes: 12, seconds: 45),
        ),
        '12:45',
      );
    });
  });

  group('AudioPlayerService notifier', () {
    late _FakeAudioPlayer fake;

    ProviderContainer makeContainer() {
      fake = _FakeAudioPlayer();
      return ProviderContainer(
        overrides: [
          audioPlayerFactoryProvider.overrideWithValue(() => fake),
        ],
      );
    }

    test('initial state has no file and is not playing', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final state = c.read(audioPlayerServiceProvider);
      expect(state.hasFile, isFalse);
      expect(state.isPlaying, isFalse);
    });

    test('playFromUrl sets currentUrl, currentSongName and starts playback',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final svc = c.read(audioPlayerServiceProvider.notifier);

      await svc.playFromUrl(
        'https://example.com/song.mp3',
        'song.mp3',
        'Test Song',
      );

      final state = c.read(audioPlayerServiceProvider);
      expect(state.currentUrl, 'https://example.com/song.mp3');
      expect(state.currentSongName, 'Test Song');
      expect(state.currentFileName, 'song.mp3');
      expect(fake.lastUrl, 'https://example.com/song.mp3');
      expect(fake.playing, isTrue);
    });

    test('togglePlayPause flips between play and pause', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final svc = c.read(audioPlayerServiceProvider.notifier);

      await svc.playFromUrl('https://example.com/a.mp3', 'a.mp3', 'A');
      expect(fake.playing, isTrue);

      await svc.togglePlayPause();
      expect(fake.playing, isFalse);

      await svc.togglePlayPause();
      expect(fake.playing, isTrue);
    });

    test('stop clears state and stops the underlying player', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final svc = c.read(audioPlayerServiceProvider.notifier);

      await svc.playFromUrl('https://example.com/a.mp3', 'a.mp3', 'A');
      await svc.stop();

      final state = c.read(audioPlayerServiceProvider);
      expect(state.hasFile, isFalse);
      expect(state.isPlaying, isFalse);
    });

    test('isSeeking suppresses position updates while user drags', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final svc = c.read(audioPlayerServiceProvider.notifier);

      await svc.playFromUrl('https://example.com/a.mp3', 'a.mp3', 'A');
      svc.startSeeking();

      // Simulate a position event from just_audio while seeking
      fake.emitPosition(const Duration(seconds: 30));
      await Future<void>.delayed(Duration.zero);

      // currentTime must NOT have followed the event — anti-flicker.
      expect(c.read(audioPlayerServiceProvider).currentTime, Duration.zero);

      // Releasing the slider seeks AND re-enables position updates.
      await svc.stopSeeking(const Duration(seconds: 90));
      expect(fake.position, const Duration(seconds: 90));
      expect(c.read(audioPlayerServiceProvider).isSeeking, isFalse);
    });

    test('rapid playFromUrl: second call supersedes first without leaking state',
        () async {
      // For this test we need a *fresh* fake per factory call, so the
      // race-guard (`_player != player`) actually triggers — otherwise
      // both calls would share one already-disposed fake.
      final fakes = <_FakeAudioPlayer>[];
      final c = ProviderContainer(
        overrides: [
          audioPlayerFactoryProvider.overrideWithValue(() {
            final f = _FakeAudioPlayer();
            fakes.add(f);
            return f;
          }),
        ],
      );
      addTearDown(c.dispose);
      final svc = c.read(audioPlayerServiceProvider.notifier);

      // Two back-to-back calls; the second resolves last in this synthetic
      // setup (just_audio fake's setUrl is `async {... return ...; }`).
      final first = svc.playFromUrl('https://a.example/1.mp3', '1.mp3', 'One');
      final second = svc.playFromUrl('https://a.example/2.mp3', '2.mp3', 'Two');

      await Future.wait([first, second]);

      // The newer call wins — state reflects '2.mp3', not '1.mp3'.
      final state = c.read(audioPlayerServiceProvider);
      expect(state.currentUrl, 'https://a.example/2.mp3');
      expect(state.currentFileName, '2.mp3');
      expect(state.currentSongName, 'Two');
    });

    test('setUrl failure is propagated and state is reset', () async {
      final failingFake = _FailingSetUrlFake();
      final c = ProviderContainer(
        overrides: [
          audioPlayerFactoryProvider.overrideWithValue(() => failingFake),
        ],
      );
      addTearDown(c.dispose);
      final svc = c.read(audioPlayerServiceProvider.notifier);

      await expectLater(
        svc.playFromUrl('https://bad.example/x.mp3', 'x.mp3', 'X'),
        throwsA(isA<StateError>()),
      );

      // After failure: state is reset, no leaked currentUrl.
      final state = c.read(audioPlayerServiceProvider);
      expect(state.hasFile, isFalse);
      expect(state.isPlaying, isFalse);
    });
  });

  // INTEGRATION: playback queue (Ionic playQueue / next / previous / onEnded)
  group('AudioPlayerService queue', () {
    late List<_FakeAudioPlayer> fakes;

    ProviderContainer makeContainer() {
      fakes = [];
      return ProviderContainer(
        overrides: [
          audioPlayerFactoryProvider.overrideWithValue(() {
            final f = _FakeAudioPlayer();
            fakes.add(f);
            return f;
          }),
        ],
      );
    }

    List<AudioQueueItem> items(int n) => [
          for (var i = 0; i < n; i++)
            AudioQueueItem(
              fileName: 't$i.mp3',
              title: 'Track $i',
              resolveUrl: () async => 'https://example.com/t$i.mp3',
            ),
        ];

    test('playQueue starts at startIndex and exposes queue info', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      await c.read(audioPlayerServiceProvider.notifier).playQueue(items(3), 1);

      expect(c.read(audioPlayerServiceProvider).currentSongName, 'Track 1');
      final info = c.read(audioQueueInfoProvider);
      expect(info.length, 3);
      expect(info.index, 1);
      expect(info.hasNext, isTrue);
      expect(info.hasPrevious, isTrue);
    });

    test('next and previous move through the queue', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final svc = c.read(audioPlayerServiceProvider.notifier);
      await svc.playQueue(items(3));
      await svc.next();
      expect(c.read(audioPlayerServiceProvider).currentSongName, 'Track 1');
      await svc.previous();
      expect(c.read(audioPlayerServiceProvider).currentSongName, 'Track 0');
    });

    test('playFromUrl clears the queue', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final svc = c.read(audioPlayerServiceProvider.notifier);
      await svc.playQueue(items(3));
      await svc.playFromUrl('https://example.com/x.mp3', 'x.mp3', 'X');
      expect(c.read(audioQueueInfoProvider).hasQueue, isFalse);
    });

    test('stop clears the queue', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final svc = c.read(audioPlayerServiceProvider.notifier);
      await svc.playQueue(items(2));
      await svc.stop();
      expect(c.read(audioQueueInfoProvider).length, 0);
      expect(c.read(audioPlayerServiceProvider).hasFile, isFalse);
    });
  });

  group('AudioPlayerService speed', () {
    test('speed applies to the playing track and the following ones', () async {
      final players = <_SpeedFake>[];
      final c = ProviderContainer(
        overrides: [
          audioPlayerFactoryProvider.overrideWithValue(() {
            final p = _SpeedFake();
            players.add(p);
            return p;
          }),
        ],
      );
      addTearDown(c.dispose);
      final svc = c.read(audioPlayerServiceProvider.notifier);

      // Normal speed: never touched.
      await svc.playFromUrl('https://example.com/a.mp3', 'a.mp3', 'A');
      expect(players.single.speeds, isEmpty);

      await svc.setSpeed(0.8);
      expect(svc.speed, 0.8);
      expect(players.single.speeds, [0.8]);

      await svc.playFromUrl('https://example.com/b.mp3', 'b.mp3', 'B');
      expect(players.last.speeds, [0.8]);
    });
  });
}
