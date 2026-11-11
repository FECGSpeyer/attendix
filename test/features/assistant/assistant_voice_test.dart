import 'package:attendix/features/assistant/presentation/assistant_voice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the locale of the speech service follows the app language', () {
    const ids = ['en_US', 'en_GB', 'de_AT', 'de_DE', 'ru-RU', 'es_MX', 'es_ES'];
    expect(assistantVoiceLocale(ids, 'de'), 'de_DE');
    expect(assistantVoiceLocale(ids, 'en'), 'en_US');
    expect(assistantVoiceLocale(ids, 'ru'), 'ru-RU');
    expect(assistantVoiceLocale(ids, 'es'), 'es_ES');
    expect(assistantVoiceLocale(const ['de_CH'], 'de'), 'de_CH');
    expect(assistantVoiceLocale(const ['fr_FR'], 'de'), isNull);
  });

  test('recognition stays on the device on Apple platforms', () {
    expect(assistantVoiceOnDevice(web: false, platform: TargetPlatform.iOS), isTrue);
    expect(assistantVoiceOnDevice(web: false, platform: TargetPlatform.macOS), isTrue);
    expect(assistantVoiceOnDevice(web: false, platform: TargetPlatform.android), isFalse);
    expect(assistantVoiceOnDevice(web: true, platform: TargetPlatform.iOS), isFalse);
  });
}
