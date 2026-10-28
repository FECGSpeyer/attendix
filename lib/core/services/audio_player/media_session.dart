import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_session_stub.dart'
    if (dart.library.js_interop) 'media_session_web.dart' as impl;

/// MEDIA_REALTIME: Media Session actions (Ionic `MediaSessionActionName`).
enum MediaSessionAction {
  play('play'),
  pause('pause'),
  previousTrack('previoustrack'),
  nextTrack('nexttrack'),
  seekTo('seekto'),
  stop('stop');

  const MediaSessionAction(this.jsName);

  /// Name of the action in the browser Media Session API.
  final String jsName;
}

/// Playback state shown on the lock screen (Ionic `MediaSessionPlayback`).
enum MediaSessionPlayback { none, paused, playing }

/// Handler for a media session action; `seekTime` is set for `seekto`.
typedef MediaSessionHandler = void Function(Duration? seekTime);

/// MEDIA_REALTIME: lock-screen / notification controls for the audio player
/// (Ionic `MediaSessionBridge` in services/audio-player/media-session.ts).
///
/// On the web/PWA this drives `navigator.mediaSession`; on other platforms
/// it is a no-op. All calls are best-effort and never throw.
abstract class MediaSessionBridge {
  bool get isSupported;

  void setActionHandler(MediaSessionAction action, MediaSessionHandler handler);

  /// Previous/next track buttons only make sense with a queue (Ionic
  /// `setTrackSkipping`): browsers show their own ±10 s buttons otherwise.
  void setTrackSkipping(bool enabled);

  /// Shows the track with a cover: the branding logo when given, otherwise
  /// the Attendix app icon.
  void setMetadata(String title, String artist, {String? coverUrl});

  void clearMetadata();

  void setPlaybackState(MediaSessionPlayback state);

  void setPositionState(Duration duration, Duration position);
}

/// No-op bridge for non-web platforms and tests.
class NoopMediaSessionBridge implements MediaSessionBridge {
  const NoopMediaSessionBridge();

  @override
  bool get isSupported => false;
  @override
  void setActionHandler(MediaSessionAction action, MediaSessionHandler handler) {}
  @override
  void setTrackSkipping(bool enabled) {}
  @override
  void setMetadata(String title, String artist, {String? coverUrl}) {}
  @override
  void clearMetadata() {}
  @override
  void setPlaybackState(MediaSessionPlayback state) {}
  @override
  void setPositionState(Duration duration, Duration position) {}
}

/// Platform media session bridge (web: `navigator.mediaSession`).
final mediaSessionBridgeProvider = Provider<MediaSessionBridge>(
  (_) => impl.createMediaSessionBridge(),
);
