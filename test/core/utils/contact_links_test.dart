import 'package:attendix/core/utils/contact_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('internationalPhoneDigits', () {
    test('national numbers get the German country code', () {
      expect(internationalPhoneDigits('0176 1234567'), '491761234567');
      expect(internationalPhoneDigits('06232/123456'), '496232123456');
      expect(internationalPhoneDigits('0176-123 45 67'), '491761234567');
    });

    test('international numbers keep their country code', () {
      expect(internationalPhoneDigits('+49 176 1234567'), '491761234567');
      expect(internationalPhoneDigits('0049 176 1234567'), '491761234567');
      expect(internationalPhoneDigits('+43 660 1234567'), '436601234567');
      expect(internationalPhoneDigits('491761234567'), '491761234567');
    });

    test('the trunk zero after the country code is dropped', () {
      expect(internationalPhoneDigits('+49 (0)176 1234567'), '491761234567');
      expect(internationalPhoneDigits('+49 0176 1234567'), '491761234567');
    });

    test('other country codes can be passed', () {
      expect(internationalPhoneDigits('0660 1234567', countryCode: '43'),
          '436601234567');
    });

    test('unusable values give null', () {
      expect(internationalPhoneDigits(null), isNull);
      expect(internationalPhoneDigits(''), isNull);
      expect(internationalPhoneDigits('   '), isNull);
      expect(internationalPhoneDigits('keine'), isNull);
      expect(internationalPhoneDigits('123'), isNull);
      expect(internationalPhoneDigits('+1234567890123456'), isNull);
    });
  });

  group('contact uris', () {
    test('build call, WhatsApp and Telegram links from the phone number', () {
      expect(phoneCallUri('0176 1234567').toString(), 'tel:+491761234567');
      expect(whatsAppUri('0176 1234567').toString(),
          'https://wa.me/491761234567');
      expect(telegramUri('0176 1234567').toString(),
          'https://t.me/+491761234567');
    });

    test('no phone number, no phone links', () {
      expect(phoneCallUri(null), isNull);
      expect(whatsAppUri(''), isNull);
      expect(telegramUri('abc'), isNull);
    });

    test('mail link only for a valid address', () {
      expect(mailUri(' lena@example.org ').toString(),
          'mailto:lena@example.org');
      expect(mailUri('lena'), isNull);
      expect(mailUri(null), isNull);
    });
  });
}
