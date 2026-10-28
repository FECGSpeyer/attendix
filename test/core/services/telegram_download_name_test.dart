import 'package:attendix/core/services/telegram_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ionic 4.17.6: Telegram plan exports carry `?download=<clean name>` so the
/// chat shows the readable file name instead of the storage key.
void main() {
  test('download URL uses the clean name without the random suffix', () {
    expect(
      TelegramService.downloadUrl('https://x/attendances/Probe_123.pdf', 'Probe (Sonntag)', '.pdf'),
      'https://x/attendances/Probe_123.pdf?download=${Uri.encodeComponent('Probe -Sonntag.pdf')}',
    );
  });

  test('empty names fall back to file', () {
    expect(TelegramService.cleanName('???'), 'file');
    expect(TelegramService.cleanName('Übung'), 'Ubung');
  });
}
