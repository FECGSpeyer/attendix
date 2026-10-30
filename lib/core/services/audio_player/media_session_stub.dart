import '../native/native_platform.dart';
import 'media_session.dart';
import 'media_session_native.dart';

/// Non-web platforms: the installed iOS/Android app gets native lock-screen
/// controls via audio_service (NATIVE_MISC); desktop and tests stay no-op.
MediaSessionBridge createMediaSessionBridge() =>
    isNativeApp ? NativeMediaSessionBridge() : const NoopMediaSessionBridge();
