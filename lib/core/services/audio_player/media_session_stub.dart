import 'media_session.dart';

/// Non-web platforms: no browser Media Session API.
MediaSessionBridge createMediaSessionBridge() => const NoopMediaSessionBridge();
