import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'media_session.dart';

/// NATIVE_MISC: lock-screen / notification controls in the installed app
/// (Ionic @capgo/capacitor-media-session on Android; on iOS WebKit's own
/// Now Playing). Backed by `audio_service`: the handler only mirrors the
/// state of the existing just_audio player and forwards button presses to
/// the handlers registered by [AudioPlayerService] – playback itself stays
/// in just_audio.
///
/// `AudioService.init` runs lazily on the first track. When the native side
/// is not set up (missing manifest entries / activity) it throws; the bridge
/// then silently stays a no-op, like Ionic's `isPluginAvailable` fallback.
class NativeMediaSessionBridge implements MediaSessionBridge {
  NativeMediaSessionBridge({Future<AudioHandler> Function(NativeMediaSessionBridge)? init})
      : _initHandler = init ?? _defaultInit;

  final Future<AudioHandler> Function(NativeMediaSessionBridge) _initHandler;
  final Map<MediaSessionAction, MediaSessionHandler> _handlers = {};
  Future<AudioHandler?>? _handlerFuture;
  bool _trackSkipping = false;
  bool _playing = false;
  MediaSessionPlayback _state = MediaSessionPlayback.none;
  MediaItem? _item;

  static Future<AudioHandler> _defaultInit(NativeMediaSessionBridge bridge) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      if (kDebugMode) debugPrint('[MediaSession] audio session config failed: $e');
    }
    return AudioService.init(
      builder: () => AttendixAudioHandler(bridge),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'de.attendix.attendix.audio',
        androidNotificationChannelName: 'Audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  Future<AudioHandler?> _ensureHandler() {
    return _handlerFuture ??= () async {
      try {
        return await _initHandler(this);
      } catch (e) {
        if (kDebugMode) debugPrint('[MediaSession] native init failed: $e');
        return null;
      }
    }();
  }

  void _withHandler(void Function(BaseAudioHandler handler) fn) {
    unawaited(_ensureHandler().then((h) {
      if (h is! BaseAudioHandler) return;
      try {
        fn(h);
      } catch (e) {
        if (kDebugMode) debugPrint('[MediaSession] update failed: $e');
      }
    }));
  }

  /// Dispatches a lock-screen button press to the registered handler.
  @visibleForTesting
  void dispatch(MediaSessionAction action, [Duration? seekTime]) {
    try {
      _handlers[action]?.call(seekTime);
    } catch (e) {
      if (kDebugMode) debugPrint('[MediaSession] handler failed: $e');
    }
  }

  @override
  bool get isSupported => true;

  @override
  void setActionHandler(MediaSessionAction action, MediaSessionHandler handler) {
    _handlers[action] = handler;
  }

  @override
  void setTrackSkipping(bool enabled) {
    _trackSkipping = enabled;
    if (_handlerFuture != null) _publishState();
  }

  @override
  void setMetadata(String title, String artist, {String? coverUrl}) {
    final cover = coverUrl == null ? null : Uri.tryParse(coverUrl);
    _item = MediaItem(
      id: title,
      title: title,
      artist: artist,
      artUri: cover,
      duration: _item?.duration,
    );
    final item = _item;
    _withHandler((h) => h.mediaItem.add(item));
  }

  @override
  void clearMetadata() {
    _item = null;
    if (_handlerFuture == null) return;
    _withHandler((h) => h.mediaItem.add(null));
  }

  @override
  void setPlaybackState(MediaSessionPlayback state) {
    _state = state;
    _playing = state == MediaSessionPlayback.playing;
    if (_handlerFuture == null && state == MediaSessionPlayback.none) return;
    _publishState();
  }

  Duration _position = Duration.zero;

  @override
  void setPositionState(Duration duration, Duration position) {
    _position = position;
    final item = _item;
    if (item != null && item.duration != duration && duration > Duration.zero) {
      _item = item.copyWith(duration: duration);
      final updated = _item;
      _withHandler((h) => h.mediaItem.add(updated));
    }
    if (_handlerFuture != null) _publishState();
  }

  /// Current lock-screen state (Ionic setPlaybackState + setPositionState).
  @visibleForTesting
  PlaybackState buildPlaybackState() {
    final controls = <MediaControl>[
      if (_trackSkipping) MediaControl.skipToPrevious,
      _playing ? MediaControl.pause : MediaControl.play,
      if (_trackSkipping) MediaControl.skipToNext,
    ];
    return PlaybackState(
      controls: controls,
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices:
          List<int>.generate(controls.length, (i) => i),
      processingState: _state == MediaSessionPlayback.none
          ? AudioProcessingState.idle
          : AudioProcessingState.ready,
      playing: _playing,
      updatePosition: _position,
    );
  }

  void _publishState() {
    final state = buildPlaybackState();
    _withHandler((h) => h.playbackState.add(state));
  }
}

/// NATIVE_MISC: forwards system media buttons to [NativeMediaSessionBridge].
class AttendixAudioHandler extends BaseAudioHandler {
  AttendixAudioHandler(this._bridge);

  final NativeMediaSessionBridge _bridge;

  @override
  Future<void> play() async => _bridge.dispatch(MediaSessionAction.play);

  @override
  Future<void> pause() async => _bridge.dispatch(MediaSessionAction.pause);

  @override
  Future<void> stop() async => _bridge.dispatch(MediaSessionAction.stop);

  @override
  Future<void> seek(Duration position) async =>
      _bridge.dispatch(MediaSessionAction.seekTo, position);

  @override
  Future<void> skipToNext() async => _bridge.dispatch(MediaSessionAction.nextTrack);

  @override
  Future<void> skipToPrevious() async =>
      _bridge.dispatch(MediaSessionAction.previousTrack);
}
