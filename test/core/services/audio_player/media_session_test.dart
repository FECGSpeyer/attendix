import 'dart:async';

import 'package:attendix/core/providers/branding_providers.dart';
import 'package:attendix/core/services/audio_player/audio_player_service.dart';
import 'package:attendix/core/services/audio_player/media_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class _FakeAudioPlayer implements AudioPlayer {
  final _playingCtrl = StreamController<bool>.broadcast();
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration?>.broadcast();
  final _processingStateCtrl = StreamController<ProcessingState>.broadcast();
  bool disposed = false;

  @override
  bool playing = false;
  @override
  Duration position = Duration.zero;

  @override
  Stream<bool> get playingStream => _playingCtrl.stream;
  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;
  @override
  Stream<Duration?> get durationStream => _durationCtrl.stream;
  @override
  Stream<ProcessingState> get processingStateStream => _processingStateCtrl.stream;

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async =>
      const Duration(minutes: 3);

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
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    this.position = position ?? Duration.zero;
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

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _RecordingBridge implements MediaSessionBridge {
  final handlers = <MediaSessionAction, MediaSessionHandler>{};
  final playbackStates = <MediaSessionPlayback>[];
  final trackSkipping = <bool>[];
  ({String title, String artist, String? coverUrl})? metadata;
  int clearCount = 0;
  Duration? lastDuration;

  @override
  bool get isSupported => true;
  @override
  void setActionHandler(MediaSessionAction action, MediaSessionHandler handler) =>
      handlers[action] = handler;
  @override
  void setTrackSkipping(bool enabled) => trackSkipping.add(enabled);
  @override
  void setMetadata(String title, String artist, {String? coverUrl}) =>
      metadata = (title: title, artist: artist, coverUrl: coverUrl);
  @override
  void clearMetadata() {
    metadata = null;
    clearCount++;
  }

  @override
  void setPlaybackState(MediaSessionPlayback state) => playbackStates.add(state);
  @override
  void setPositionState(Duration duration, Duration position) => lastDuration = duration;
}

void main() {
  late _RecordingBridge bridge;
  late ProviderContainer container;

  setUp(() {
    bridge = _RecordingBridge();
    container = ProviderContainer(overrides: [
      audioPlayerFactoryProvider.overrideWithValue(_FakeAudioPlayer.new),
      mediaSessionBridgeProvider.overrideWithValue(bridge),
      brandingSourceProvider.overrideWith(
        (ref) async => (logoUrl: 'https://example.com/logo.png', text: null),
      ),
    ]);
  });

  tearDown(() => container.dispose());

  test('default bridge is a no-op outside the web', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(mediaSessionBridgeProvider).isSupported, isFalse);
  });

  test('registers play/pause/stop/previous/next/seekto handlers on build', () {
    container.read(audioPlayerServiceProvider);
    expect(bridge.handlers.keys.toSet(), MediaSessionAction.values.toSet());
  });

  test('playFromUrl sets title, artist "Attendix", branding cover and state', () async {
    await container.read(brandingSourceProvider.future);
    await container
        .read(audioPlayerServiceProvider.notifier)
        .playFromUrl('https://x/a.mp3', 'a.mp3', 'Hallelujah');
    await Future<void>.delayed(Duration.zero);

    expect(bridge.metadata?.title, 'Hallelujah');
    expect(bridge.metadata?.artist, 'Attendix');
    expect(bridge.metadata?.coverUrl, 'https://example.com/logo.png');
    expect(bridge.trackSkipping.last, isFalse);
    expect(bridge.playbackStates.last, MediaSessionPlayback.playing);
  });

  test('falls back to the file name when the song name is empty', () async {
    await container
        .read(audioPlayerServiceProvider.notifier)
        .playFromUrl('https://x/a.mp3', 'a.mp3', '');
    expect(bridge.metadata?.title, 'a.mp3');
  });

  test('queue enables track skipping and nexttrack advances', () async {
    final service = container.read(audioPlayerServiceProvider.notifier);
    AudioQueueItem item(String name) => AudioQueueItem(
          fileName: '$name.mp3',
          title: name,
          resolveUrl: () async => 'https://x/$name.mp3',
        );
    await service.playQueue([item('one'), item('two')]);
    expect(bridge.trackSkipping.last, isTrue);
    expect(bridge.metadata?.title, 'one');

    bridge.handlers[MediaSessionAction.nextTrack]!(null);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(audioQueueInfoProvider).index, 1);
    expect(bridge.metadata?.title, 'two');
  });

  test('pause handler pauses and reports paused', () async {
    await container
        .read(audioPlayerServiceProvider.notifier)
        .playFromUrl('https://x/a.mp3', 'a.mp3', 'Song');
    bridge.handlers[MediaSessionAction.pause]!(null);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioPlayerServiceProvider).isPlaying, isFalse);
    expect(bridge.playbackStates.last, MediaSessionPlayback.paused);
  });

  test('stop clears metadata and sets playback state none', () async {
    final service = container.read(audioPlayerServiceProvider.notifier);
    await service.playFromUrl('https://x/a.mp3', 'a.mp3', 'Song');
    await service.stop();
    expect(bridge.metadata, isNull);
    expect(bridge.playbackStates.last, MediaSessionPlayback.none);
  });
}
