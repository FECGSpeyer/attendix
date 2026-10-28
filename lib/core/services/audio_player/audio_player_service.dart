import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../providers/branding_providers.dart';
import 'audio_player_state.dart';
import 'media_session.dart';

/// Factory for the underlying `just_audio` `AudioPlayer`.
///
/// Tests override this with a fake; production uses the real player.
final audioPlayerFactoryProvider = Provider<AudioPlayer Function()>(
  (_) => AudioPlayer.new,
);

/// INTEGRATION: an entry of a playback queue (Ionic `AudioQueueItem`).
/// The URL is resolved lazily (e.g. signed storage URLs).
class AudioQueueItem {
  const AudioQueueItem({
    required this.fileName,
    required this.title,
    required this.resolveUrl,
  });

  final String fileName;
  final String title;
  final Future<String> Function() resolveUrl;
}

/// Position in the playback queue (Ionic `queue` / `queueIndex` signals).
class AudioQueueInfo {
  const AudioQueueInfo({this.length = 0, this.index = -1});

  final int length;
  final int index;

  /// More than one track queued (shows the skip buttons).
  bool get hasQueue => length > 1;
  bool get hasNext => index < length - 1;
  bool get hasPrevious => index > 0;
}

/// Queue state of [AudioPlayerService] (kept separate from the Freezed
/// [AudioPlayerState] so the player bar can show next/previous buttons).
final audioQueueInfoProvider = StateProvider<AudioQueueInfo>((_) => const AudioQueueInfo());

/// Cross-cutting audio playback service.
///
/// Mirrors Ionic v4.0.5 `AudioPlayerService` (`audio-player.service.ts`).
/// Exactly one file plays at a time. Calling `play`/`playFromUrl` while
/// another file is loaded stops the current playback first.
class AudioPlayerService extends Notifier<AudioPlayerState> {
  AudioPlayer? _player;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<ProcessingState>? _processingSub;

  static const _audioExtensions = [
    '.mp3',
    '.wav',
    '.ogg',
    '.m4a',
    '.aac',
    '.flac',
    '.wma',
    '.webm',
    '.opus',
  ];

  /// True if the file name ends with any recognized audio extension.
  static bool isAudioFile(String fileName) {
    final lower = fileName.toLowerCase();
    return _audioExtensions.any(lower.endsWith);
  }

  /// Seconds after which "previous" restarts the current track instead of
  /// skipping back (Ionic RESTART_THRESHOLD).
  static const restartThreshold = Duration(seconds: 3);

  List<AudioQueueItem> _queue = const [];
  int _queueIndex = -1;

  /// Incremented on every track change to ignore stale URL resolutions.
  int _loadToken = 0;

  void _setQueue(List<AudioQueueItem> items, int index) {
    _queue = items;
    _queueIndex = index;
    try {
      ref.read(audioQueueInfoProvider.notifier).state =
          AudioQueueInfo(length: items.length, index: index);
    } catch (_) {
      // Provider container already disposed.
    }
  }

  /// `m:ss` formatting for slider labels (e.g. `1:30`, `12:45`).
  static String formatTime(Duration d) {
    if (d == Duration.zero) return '0:00';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// MEDIA_REALTIME: lock-screen controls (Ionic `MediaSessionBridge`).
  MediaSessionBridge _mediaSession = const NoopMediaSessionBridge();

  @override
  AudioPlayerState build() {
    ref.onDispose(_disposePlayer);
    _mediaSession = ref.read(mediaSessionBridgeProvider);
    _registerMediaSessionHandlers();
    return const AudioPlayerState();
  }

  /// MEDIA_REALTIME: Ionic `registerMediaSessionHandlers`.
  void _registerMediaSessionHandlers() {
    final session = _mediaSession;
    if (!session.isSupported) return;
    session.setActionHandler(MediaSessionAction.play, (_) => unawaited(_player?.play()));
    session.setActionHandler(MediaSessionAction.pause, (_) => unawaited(_player?.pause()));
    session.setActionHandler(MediaSessionAction.stop, (_) => unawaited(_player?.pause()));
    session.setActionHandler(MediaSessionAction.previousTrack, (_) {
      unawaited(previous().catchError((_) => stop()));
    });
    session.setActionHandler(MediaSessionAction.nextTrack, (_) {
      unawaited(next().catchError((_) => stop()));
    });
    session.setActionHandler(MediaSessionAction.seekTo, (seekTime) {
      if (seekTime == null || _player == null) return;
      unawaited(seek(seekTime));
    });
  }

  /// MEDIA_REALTIME: Ionic `syncPositionState`.
  void _syncPositionState() {
    final player = _player;
    if (player == null || state.currentFileName == null) return;
    _mediaSession.setPositionState(state.duration, player.position);
  }

  /// Branding logo as lock-screen cover (Ionic `audioPlayer.coverUrl`).
  String? _coverUrl() {
    try {
      return ref.read(brandingSourceProvider).valueOrNull?.logoUrl;
    } catch (_) {
      return null;
    }
  }

  /// Plays a single file. Stops any previous playback and clears the queue.
  Future<void> playFromUrl(
    String url,
    String fileName,
    String songName,
  ) async {
    _loadToken++;
    _setQueue(const [], -1);
    await _load(url, fileName, songName);
  }

  /// INTEGRATION: plays a list of audio files starting at [startIndex] and
  /// advances automatically when a track ends (Ionic `playQueue`).
  Future<void> playQueue(List<AudioQueueItem> items, [int startIndex = 0]) async {
    _setQueue(items, -1);
    await _playQueueItem(startIndex);
  }

  Future<void> next() async {
    if (_queueIndex >= _queue.length - 1) return;
    await _playQueueItem(_queueIndex + 1);
  }

  Future<void> previous() async {
    final player = _player;
    if ((player != null && player.position > restartThreshold) || _queueIndex <= 0) {
      await seek(Duration.zero);
      return;
    }
    await _playQueueItem(_queueIndex - 1);
  }

  Future<void> _playQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final item = _queue[index];
    final token = ++_loadToken;
    _setQueue(_queue, index);
    await _player?.pause();
    final url = await item.resolveUrl();
    if (token != _loadToken) return;
    await _load(url, item.fileName, item.title);
  }

  Future<void> _load(
    String url,
    String fileName,
    String songName,
  ) async {
    await _stopInternal(keepQueue: true);

    final player = ref.read(audioPlayerFactoryProvider)();
    _player = player;
    _wireStreams(player);

    try {
      final loadedDuration = await player.setUrl(url);

      // Race guard: a newer playFromUrl call may have superseded us
      // while setUrl was loading. If so, _player no longer points to
      // our player — dispose ours (the newer call only cleans up the
      // player that was active when IT started, not us) and bail out
      // without touching state or calling play.
      if (_player != player) {
        await player.stop();
        await player.dispose();
        return;
      }

      state = state.copyWith(
        currentUrl: url,
        currentFileName: fileName,
        currentSongName: songName,
        duration: loadedDuration ?? Duration.zero,
        currentTime: Duration.zero,
        isSeeking: false,
      );
      if (_mediaSession.isSupported) {
        _mediaSession.setMetadata(
          songName.isNotEmpty ? songName : fileName,
          'Attendix',
          coverUrl: _coverUrl(),
        );
        _mediaSession.setTrackSkipping(_queue.length > 1);
      }
      await player.play();
    } catch (_) {
      // setUrl or play failed (network drop, bad URL, codec error).
      // Tear down so we're not left wired to a half-initialized player.
      if (_player == player) {
        await _stopInternal();
      }
      rethrow;
    }
  }

  Future<void> togglePlayPause() async {
    final player = _player;
    if (player == null) return;
    if (state.isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> stop() {
    _loadToken++;
    return _stopInternal();
  }

  Future<void> seek(Duration position) async {
    final player = _player;
    if (player == null) return;
    await player.seek(position);
    state = state.copyWith(currentTime: position);
    _syncPositionState();
  }

  void startSeeking() {
    state = state.copyWith(isSeeking: true);
  }

  Future<void> stopSeeking(Duration position) async {
    state = state.copyWith(isSeeking: false);
    await seek(position);
  }

  void _wireStreams(AudioPlayer player) {
    _playingSub = player.playingStream.listen((p) {
      state = state.copyWith(isPlaying: p);
      // MEDIA_REALTIME: also reflects pauses from the lock screen/headphones.
      if (state.currentFileName != null) {
        _mediaSession.setPlaybackState(
          p ? MediaSessionPlayback.playing : MediaSessionPlayback.paused,
        );
        _syncPositionState();
      }
    });
    _positionSub = player.positionStream.listen((pos) {
      // Anti-flicker: while the user drags the slider, ignore the player's
      // own position updates so the knob doesn't snap back.
      if (state.isSeeking) return;
      state = state.copyWith(currentTime: pos);
    });
    _durationSub = player.durationStream.listen((d) {
      if (d != null) {
        state = state.copyWith(duration: d);
        _syncPositionState();
      }
    });
    _processingSub = player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) {
        // INTEGRATION: queue advances automatically (Ionic onEnded).
        if (_queueIndex >= 0 && _queueIndex < _queue.length - 1) {
          unawaited(next().catchError((_) => _stopInternal()));
          return;
        }
        state = state.copyWith(
          isPlaying: false,
          currentTime: Duration.zero,
        );
      }
    });
  }

  Future<void> _stopInternal({bool keepQueue = false}) async {
    if (!keepQueue) _setQueue(const [], -1);
    await _playingSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _processingSub?.cancel();
    _playingSub = null;
    _positionSub = null;
    _durationSub = null;
    _processingSub = null;

    final player = _player;
    if (player != null) {
      await player.stop();
      await player.dispose();
      _player = null;
    }
    state = const AudioPlayerState();
    if (!keepQueue) {
      // MEDIA_REALTIME: Ionic resetPlayback.
      _mediaSession.setPlaybackState(MediaSessionPlayback.none);
      _mediaSession.clearMetadata();
    }
  }

  void _disposePlayer() {
    // Best-effort fire-and-forget; a Notifier's onDispose can't await.
    unawaited(_stopInternal());
  }
}

final audioPlayerServiceProvider =
    NotifierProvider<AudioPlayerService, AudioPlayerState>(
  AudioPlayerService.new,
);
