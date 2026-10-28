import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'media_session.dart';

MediaSessionBridge createMediaSessionBridge() => WebMediaSessionBridge();

/// `MediaSessionActionDetails` (not exposed by package:web 1.1).
extension type _ActionDetails._(JSObject _) implements JSObject {
  external double? get seekTime;
}

/// App icon of the PWA (Ionic LOGO_URL), resolved against the base URI.
const _logoPath = 'icons/Icon-192.png';

/// MEDIA_REALTIME: browser Media Session API (web/PWA, iOS Safari).
class WebMediaSessionBridge implements MediaSessionBridge {
  final Map<MediaSessionAction, MediaSessionHandler> _handlers = {};

  web.MediaSession? get _session {
    try {
      if (!web.window.navigator.has('mediaSession')) return null;
      return web.window.navigator.mediaSession;
    } catch (_) {
      return null;
    }
  }

  @override
  bool get isSupported => _session != null;

  @override
  void setActionHandler(MediaSessionAction action, MediaSessionHandler handler) {
    _handlers[action] = handler;
    _setWebHandler(action.jsName, handler);
  }

  @override
  void setTrackSkipping(bool enabled) {
    for (final action in const [
      MediaSessionAction.previousTrack,
      MediaSessionAction.nextTrack,
    ]) {
      _setWebHandler(action.jsName, enabled ? _handlers[action] : null);
    }
    if (enabled) {
      _setWebHandler('seekbackward', null);
      _setWebHandler('seekforward', null);
    }
    // WebKit drops the lock-screen scrubber when other handlers change, so
    // set seekto again last.
    final seekTo = _handlers[MediaSessionAction.seekTo];
    if (seekTo != null) _setWebHandler(MediaSessionAction.seekTo.jsName, seekTo);
  }

  void _setWebHandler(String action, MediaSessionHandler? handler) {
    _run(() {
      final session = _session;
      if (session == null) return;
      session.setActionHandler(
        action,
        handler == null
            ? null
            : ((JSObject? details) {
                final seconds =
                    details == null ? null : (details as _ActionDetails).seekTime;
                handler(
                  seconds == null
                      ? null
                      : Duration(milliseconds: (seconds * 1000).round()),
                );
              }).toJS,
      );
    });
  }

  @override
  void setMetadata(String title, String artist, {String? coverUrl}) {
    _run(() {
      final session = _session;
      if (session == null || !globalContext.has('MediaMetadata')) return;
      final artwork = <web.MediaImage>[
        if (coverUrl != null && coverUrl.isNotEmpty)
          web.MediaImage(src: coverUrl)
        else
          web.MediaImage(
            src: Uri.base.resolve(_logoPath).toString(),
            sizes: '192x192',
            type: 'image/png',
          ),
      ];
      session.metadata = web.MediaMetadata(
        web.MediaMetadataInit(
          title: title,
          artist: artist,
          artwork: artwork.toJS,
        ),
      );
    });
  }

  @override
  void clearMetadata() {
    _run(() => _session?.metadata = null);
  }

  @override
  void setPlaybackState(MediaSessionPlayback state) {
    _run(() => _session?.playbackState = state.name);
  }

  @override
  void setPositionState(Duration duration, Duration position) {
    final durSec = duration.inMilliseconds / 1000;
    if (durSec <= 0) return;
    final posSec = (position.inMilliseconds / 1000).clamp(0, durSec);
    _run(() {
      final session = _session;
      if (session == null || !session.has('setPositionState')) return;
      session.setPositionState(
        web.MediaPositionState(
          duration: durSec,
          position: posSec,
          playbackRate: 1,
        ),
      );
    });
  }

  /// Unsupported actions must not break playback.
  void _run(void Function() fn) {
    try {
      fn();
    } catch (_) {
      // ignore
    }
  }
}
