// Chat assistant: speech input. The words become text in the input field;
// nothing is sent until the person taps "Senden" (the text then goes the
// same way as typed text). No audio is stored or sent by Attendix.
//
// The recognition is done by the system: on iPhone / iPad / Mac on the
// device itself (`onDevice`), on Android and in the browser by the system's
// or browser's speech service.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech to text for the chat input (replaceable in tests).
abstract class AssistantVoice {
  /// Starts listening in [language] (e.g. 'de'). [onText] gets the words
  /// so far, [onEnd] is called once when listening stops. False when speech
  /// input is not available (no permission, no service).
  Future<bool> start({
    required String language,
    required void Function(String text) onText,
    required VoidCallback onEnd,
  });

  Future<void> stop();
}

/// Whether recognition must stay on the device on this platform.
bool assistantVoiceOnDevice({bool web = kIsWeb, TargetPlatform? platform}) {
  if (web) return false;
  final p = platform ?? defaultTargetPlatform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}

/// The locale id of the speech service for [language] ('de' → 'de_DE'),
/// null for the system default.
String? assistantVoiceLocale(Iterable<String> available, String language) {
  final lang = language.toLowerCase();
  String norm(String id) => id.replaceAll('-', '_').toLowerCase();
  final preferred = {'de': 'de_de', 'en': 'en_us', 'ru': 'ru_ru', 'es': 'es_es'}[lang];
  for (final id in available) {
    if (norm(id) == preferred) return id;
  }
  for (final id in available) {
    if (norm(id) == lang || norm(id).startsWith('${lang}_')) return id;
  }
  return null;
}

class SpeechToTextVoice implements AssistantVoice {
  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  VoidCallback? _onEnd;

  void _ended() {
    final cb = _onEnd;
    _onEnd = null;
    cb?.call();
  }

  @override
  Future<bool> start({
    required String language,
    required void Function(String text) onText,
    required VoidCallback onEnd,
  }) async {
    try {
      _ready = _ready ||
          await _speech.initialize(
            onStatus: (s) {
              if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) _ended();
            },
            onError: (_) => _ended(),
          );
      if (!_ready) return false;
      final locales = await _speech.locales();
      _onEnd = onEnd;
      await _speech.listen(
        onResult: (r) => onText(r.recognizedWords),
        listenOptions: SpeechListenOptions(
          localeId: assistantVoiceLocale(locales.map((l) => l.localeId), language),
          onDevice: assistantVoiceOnDevice(),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      return true;
    } catch (_) {
      _onEnd = null;
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
    _ended();
  }
}

final assistantVoiceProvider = Provider<AssistantVoice>((ref) => SpeechToTextVoice());
