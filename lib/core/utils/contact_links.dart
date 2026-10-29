import 'package:url_launcher/url_launcher.dart';

/// Contact links for a person (Anrufen, WhatsApp, Telegram, E-Mail).
///
/// WhatsApp and Telegram open a chat by phone number, so they work with the
/// `phone` field that persons already have; no extra database field.
/// `telegramId` is the chat id of the notification bot and cannot open a chat
/// reliably, so it is not used here.

/// Country code for numbers stored in national format ("0176 …").
const defaultContactCountryCode = '49';

/// The phone number as international digits without "+" ("491761234567"),
/// or null when it is not a usable number.
///
/// "+49 …" and "0049 …" keep their country code, "0176 …" gets
/// [countryCode], and the trunk zero in "+49 (0) 176 …" is dropped.
String? internationalPhoneDigits(
  String? phone, {
  String countryCode = defaultContactCountryCode,
}) {
  if (phone == null) return null;
  final raw = phone.trim().replaceAll('(0)', '');
  if (raw.isEmpty) return null;

  final hasPlus = raw.startsWith('+');
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  if (!hasPlus) {
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = countryCode + digits.substring(1);
    }
  }
  // "+49 0176 …": the national zero has no place after the country code.
  if (digits.startsWith('${countryCode}0')) {
    digits = countryCode + digits.substring(countryCode.length + 1);
  }

  // E.164: at most 15 digits; shorter than 7 is no callable number.
  if (digits.length < 7 || digits.length > 15 || digits.startsWith('0')) {
    return null;
  }
  return digits;
}

/// `tel:+491761234567`
Uri? phoneCallUri(String? phone) {
  final digits = internationalPhoneDigits(phone);
  return digits == null ? null : Uri(scheme: 'tel', path: '+$digits');
}

/// `https://wa.me/491761234567` (opens the WhatsApp app, Web or Desktop)
Uri? whatsAppUri(String? phone) {
  final digits = internationalPhoneDigits(phone);
  return digits == null ? null : Uri.https('wa.me', '/$digits');
}

/// `https://t.me/+491761234567` (opens Telegram; only finds the person when
/// they allow being found by their number)
Uri? telegramUri(String? phone) {
  final digits = internationalPhoneDigits(phone);
  return digits == null ? null : Uri.https('t.me', '/+$digits');
}

/// `mailto:name@example.org`
Uri? mailUri(String? email) {
  final address = email?.trim() ?? '';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) return null;
  return Uri(scheme: 'mailto', path: address);
}

/// Opens [uri] in the matching app. Returns false when nothing could open it
/// (PWA without a handler, no mail app, ...).
Future<bool> launchContactUri(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
