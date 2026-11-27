import 'package:flutter/material.dart';

/// REDESIGN: the five Farbwelten of the new design (Beta), as shown in the
/// design canvas (boards "Farbwelt A–E" and "V6 Darstellung").
enum RdFarbwelt {
  petrol('petrol'),
  konzertsaal('konzertsaal'),
  nachtblau('nachtblau'),
  klar('klar'),
  buehne('buehne');

  const RdFarbwelt(this.key);

  /// Value stored on the device.
  final String key;

  static RdFarbwelt fromKey(String? key) => RdFarbwelt.values.firstWhere(
        (w) => w.key == key,
        orElse: () => RdFarbwelt.petrol,
      );

  /// Bühne has no light variant.
  bool get alwaysDark => this == RdFarbwelt.buehne;

  /// Letter on the canvas boards (A–E).
  String get letter => const ['A', 'B', 'C', 'D', 'E'][index];

  /// iOS alternate app icon (an AppIcon… set in ios/Runner/Assets.xcassets);
  /// null: the default icon, which is Petrol (the Ionic app's icon).
  String? get appIconName => switch (this) {
        RdFarbwelt.petrol => null,
        RdFarbwelt.konzertsaal => 'AppIconKonzertsaal',
        RdFarbwelt.nachtblau => 'AppIconNachtblau',
        RdFarbwelt.klar => 'AppIconKlar',
        RdFarbwelt.buehne => 'AppIconBuehne',
      };
}

/// Colour tokens and shapes of one Farbwelt in one brightness.
///
/// Status colours: p = anwesend/dabei, l = verspätet/später,
/// e = entschuldigt, a = abwesend/fehlt.
@immutable
class RdPalette {
  const RdPalette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.soft,
    required this.softText,
    required this.bg,
    required this.surface,
    required this.text,
    required this.text2,
    required this.line,
    required this.track,
    required this.link,
    required this.present,
    required this.late,
    required this.excused,
    required this.absent,
    required this.presentSoft,
    required this.lateSoft,
    required this.excusedSoft,
    required this.absentSoft,
    required this.onStatus,
    required this.off,
    required this.offBorder,
    required this.toastBg,
    required this.toastText,
    required this.toastAction,
    required this.cardRadius,
    required this.buttonRadius,
    required this.headWeight,
    this.serifHeadings = false,
    this.cardShadow = const [],
  });

  final Brightness brightness;
  final Color primary;
  final Color onPrimary;

  /// Tinted surface (selected tab pill, badges, eyebrows background).
  final Color soft;

  /// Text on [soft] and eyebrow text.
  final Color softText;

  /// Page background.
  final Color bg;

  /// Cards, lists, bars.
  final Color surface;
  final Color text;

  /// Secondary text (meta lines, labels).
  final Color text2;

  /// Hairlines between list rows.
  final Color line;

  /// Empty part of status bars, segment background.
  final Color track;
  final Color link;

  final Color present;
  final Color late;
  final Color excused;
  final Color absent;
  final Color presentSoft;
  final Color lateSoft;
  final Color excusedSoft;
  final Color absentSoft;

  /// Icon colour on a filled status button.
  final Color onStatus;

  /// Icon colour of an unselected status button and its border.
  final Color off;
  final Color offBorder;

  final Color toastBg;
  final Color toastText;
  final Color toastAction;

  final double cardRadius;

  /// 999 = pill buttons (Nachtblau).
  final double buttonRadius;
  final FontWeight headWeight;

  /// Konzertsaal: serif titles like a concert programme.
  final bool serifHeadings;
  final List<BoxShadow> cardShadow;

  bool get isDark => brightness == Brightness.dark;

  /// Radius of grouped lists (never rounder than 16).
  double get listRadius => cardRadius < 16 ? cardRadius : 16;
}

const _darkSt = (
  p: Color(0xFF4ADE80),
  l: Color(0xFFFBBF24),
  e: Color(0xFF93A8F4),
  a: Color(0xFFF87171),
);

/// 16 % of a dark status colour on the dark page (rgba(…, .16)).
Color _darkSoft(Color c) => c.withValues(alpha: 0.16);

const _shadowSoft = [
  BoxShadow(color: Color(0x0F111827), blurRadius: 2, offset: Offset(0, 1)),
];
const _shadowNachtblau = [
  BoxShadow(color: Color(0x0F0F172A), blurRadius: 8, offset: Offset(0, 2)),
];

/// Light variants (canvas ThemePetrol `P` / Darstellung `L`).
final Map<RdFarbwelt, RdPalette> _light = {
  RdFarbwelt.petrol: const RdPalette(
    brightness: Brightness.light,
    primary: Color(0xFF2F7680),
    onPrimary: Color(0xFFFFFFFF),
    soft: Color(0xFFE6F1F2),
    softText: Color(0xFF245E66),
    bg: Color(0xFFF4F6F6),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF111827),
    text2: Color(0xFF5B6770),
    line: Color(0xFFEEF0F1),
    track: Color(0xFFE5E7EB),
    link: Color(0xFF2F7680),
    present: Color(0xFF1F7A4D),
    late: Color(0xFF9A5B00),
    excused: Color(0xFF2F5FC4),
    absent: Color(0xFFB42318),
    presentSoft: Color(0xFFE7F3EC),
    lateSoft: Color(0xFFFBF1E2),
    excusedSoft: Color(0xFFE8EEFB),
    absentSoft: Color(0xFFFDECEA),
    onStatus: Color(0xFFFFFFFF),
    off: Color(0xFF6B7280),
    offBorder: Color(0xFFE5E7EB),
    toastBg: Color(0xFF1F2937),
    toastText: Color(0xFFFFFFFF),
    toastAction: Color(0xFF8FD3DA),
    cardRadius: 20,
    buttonRadius: 14,
    headWeight: FontWeight.w700,
    cardShadow: _shadowSoft,
  ),
  RdFarbwelt.konzertsaal: const RdPalette(
    brightness: Brightness.light,
    primary: Color(0xFF6A2C4A),
    onPrimary: Color(0xFFFFFFFF),
    soft: Color(0xFFF4E9EE),
    softText: Color(0xFF5A2440),
    bg: Color(0xFFF8F5F0),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF1C1917),
    text2: Color(0xFF6B625A),
    line: Color(0xFFEFEAE4),
    track: Color(0xFFE7E1DA),
    link: Color(0xFF6A2C4A),
    present: Color(0xFF1F7A4D),
    late: Color(0xFF9A5B00),
    excused: Color(0xFF2F5FC4),
    absent: Color(0xFFB42318),
    presentSoft: Color(0xFFE7F3EC),
    lateSoft: Color(0xFFFBF1E2),
    excusedSoft: Color(0xFFE8EEFB),
    absentSoft: Color(0xFFFDECEA),
    onStatus: Color(0xFFFFFFFF),
    off: Color(0xFF7A7068),
    offBorder: Color(0xFFE7E1DA),
    toastBg: Color(0xFF2A2420),
    toastText: Color(0xFFFFFFFF),
    toastAction: Color(0xFFF0C6D8),
    cardRadius: 14,
    buttonRadius: 10,
    headWeight: FontWeight.w700,
    serifHeadings: true,
    cardShadow: [
      BoxShadow(color: Color(0x0F1C1917), blurRadius: 2, offset: Offset(0, 1)),
    ],
  ),
  RdFarbwelt.nachtblau: const RdPalette(
    brightness: Brightness.light,
    primary: Color(0xFF2B3FBF),
    onPrimary: Color(0xFFFFFFFF),
    soft: Color(0xFFE8EBFB),
    softText: Color(0xFF22309A),
    bg: Color(0xFFF3F5FA),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF0F172A),
    text2: Color(0xFF55607A),
    line: Color(0xFFE8EBF2),
    track: Color(0xFFE2E6EF),
    link: Color(0xFF2B3FBF),
    present: Color(0xFF1F7A4D),
    late: Color(0xFF9A5B00),
    excused: Color(0xFF6B3FC0),
    absent: Color(0xFFB42318),
    presentSoft: Color(0xFFE7F3EC),
    lateSoft: Color(0xFFFBF1E2),
    excusedSoft: Color(0xFFF0EAFB),
    absentSoft: Color(0xFFFDECEA),
    onStatus: Color(0xFFFFFFFF),
    off: Color(0xFF6B7280),
    offBorder: Color(0xFFE2E6EF),
    toastBg: Color(0xFF0F172A),
    toastText: Color(0xFFFFFFFF),
    toastAction: Color(0xFFA9B4F5),
    cardRadius: 24,
    buttonRadius: 999,
    headWeight: FontWeight.w800,
    cardShadow: _shadowNachtblau,
  ),
  RdFarbwelt.klar: const RdPalette(
    brightness: Brightness.light,
    primary: Color(0xFF111827),
    onPrimary: Color(0xFFFFFFFF),
    soft: Color(0xFFF1F2F4),
    softText: Color(0xFF111827),
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF4F5F7),
    text: Color(0xFF111827),
    text2: Color(0xFF5B6770),
    line: Color(0xFFE6E8EB),
    track: Color(0xFFE5E7EB),
    link: Color(0xFF111827),
    present: Color(0xFF1F7A4D),
    late: Color(0xFF9A5B00),
    excused: Color(0xFF2F5FC4),
    absent: Color(0xFFB42318),
    presentSoft: Color(0xFFE7F3EC),
    lateSoft: Color(0xFFFBF1E2),
    excusedSoft: Color(0xFFE8EEFB),
    absentSoft: Color(0xFFFDECEA),
    onStatus: Color(0xFFFFFFFF),
    off: Color(0xFF6B7280),
    offBorder: Color(0xFFE0E3E7),
    toastBg: Color(0xFF111827),
    toastText: Color(0xFFFFFFFF),
    toastAction: Color(0xFF93C5FD),
    cardRadius: 16,
    buttonRadius: 12,
    headWeight: FontWeight.w700,
  ),
};

/// Dark variants (canvas Darstellung `D`); Bühne is the same in both.
final Map<RdFarbwelt, RdPalette> _dark = {
  RdFarbwelt.petrol: _darkPalette(
    primary: const Color(0xFF7CC4CC),
    onPrimary: const Color(0xFF0F1416),
    soft: const Color(0xFF21434A),
    softText: const Color(0xFF9ED4DA),
    bg: const Color(0xFF0F1416),
    surface: const Color(0xFF1A2225),
    text: const Color(0xFFE8EEF0),
    text2: const Color(0xFFA9B5BB),
    line: const Color(0xFF26313A),
    track: const Color(0xFF2A3437),
    link: const Color(0xFF9ED4DA),
    toastAction: const Color(0xFF2F7680),
    cardRadius: 20,
    buttonRadius: 14,
  ),
  RdFarbwelt.konzertsaal: _darkPalette(
    primary: const Color(0xFFE3A6C1),
    onPrimary: const Color(0xFF2A0F1C),
    soft: const Color(0xFF3A2430),
    softText: const Color(0xFFF0C6D8),
    bg: const Color(0xFF161214),
    surface: const Color(0xFF211B1E),
    text: const Color(0xFFF3EEEA),
    text2: const Color(0xFFB5AAA2),
    line: const Color(0xFF33292E),
    track: const Color(0xFF382D32),
    link: const Color(0xFFF0C6D8),
    toastAction: const Color(0xFF6A2C4A),
    cardRadius: 14,
    buttonRadius: 10,
    serifHeadings: true,
  ),
  RdFarbwelt.nachtblau: _darkPalette(
    primary: const Color(0xFFA9B4F5),
    onPrimary: const Color(0xFF0F1640),
    soft: const Color(0xFF232C56),
    softText: const Color(0xFFC7CEFA),
    bg: const Color(0xFF0B1020),
    surface: const Color(0xFF151B2E),
    text: const Color(0xFFE8ECF7),
    text2: const Color(0xFFA3ADC6),
    line: const Color(0xFF252D45),
    track: const Color(0xFF2A3350),
    link: const Color(0xFFC7CEFA),
    toastAction: const Color(0xFF2B3FBF),
    cardRadius: 24,
    buttonRadius: 999,
    headWeight: FontWeight.w800,
    excused: const Color(0xFFC4B5FD),
  ),
  RdFarbwelt.klar: _darkPalette(
    primary: const Color(0xFFF2F2F7),
    onPrimary: const Color(0xFF111827),
    soft: const Color(0xFF2C2C2E),
    softText: const Color(0xFFF2F2F7),
    bg: const Color(0xFF0B0B0C),
    surface: const Color(0xFF1C1C1E),
    text: const Color(0xFFF2F2F7),
    text2: const Color(0xFFAEAEB6),
    line: const Color(0xFF2C2C2E),
    track: const Color(0xFF3A3A3C),
    link: const Color(0xFFF2F2F7),
    toastAction: const Color(0xFF111827),
    cardRadius: 16,
    buttonRadius: 12,
  ),
  RdFarbwelt.buehne: _darkPalette(
    primary: const Color(0xFF5FB3BD),
    onPrimary: const Color(0xFF0F1416),
    soft: const Color(0xFF203A3E),
    softText: const Color(0xFF9FD8DE),
    bg: const Color(0xFF0F1416),
    surface: const Color(0xFF1A2225),
    text: const Color(0xFFF3F4F6),
    text2: const Color(0xFFB0BAC0),
    line: const Color(0xFF26302F),
    track: const Color(0xFF2A3437),
    link: const Color(0xFF9FD8DE),
    toastAction: const Color(0xFF2F7680),
    cardRadius: 20,
    buttonRadius: 14,
  ),
};

RdPalette _darkPalette({
  required Color primary,
  required Color onPrimary,
  required Color soft,
  required Color softText,
  required Color bg,
  required Color surface,
  required Color text,
  required Color text2,
  required Color line,
  required Color track,
  required Color link,
  required Color toastAction,
  required double cardRadius,
  required double buttonRadius,
  FontWeight headWeight = FontWeight.w700,
  bool serifHeadings = false,
  Color? excused,
}) {
  final e = excused ?? _darkSt.e;
  return RdPalette(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: onPrimary,
    soft: soft,
    softText: softText,
    bg: bg,
    surface: surface,
    text: text,
    text2: text2,
    line: line,
    track: track,
    link: link,
    present: _darkSt.p,
    late: _darkSt.l,
    excused: e,
    absent: _darkSt.a,
    presentSoft: _darkSoft(_darkSt.p),
    lateSoft: _darkSoft(_darkSt.l),
    excusedSoft: _darkSoft(e),
    absentSoft: _darkSoft(_darkSt.a),
    onStatus: bg,
    off: const Color(0xFF9CA3AF),
    offBorder: track,
    toastBg: const Color(0xFFF3F4F6),
    toastText: bg,
    toastAction: toastAction,
    cardRadius: cardRadius,
    buttonRadius: buttonRadius,
    headWeight: headWeight,
    serifHeadings: serifHeadings,
  );
}

/// Palette of [world] for [brightness] (Bühne is always dark).
RdPalette rdPalette(RdFarbwelt world, Brightness brightness) {
  if (world.alwaysDark || brightness == Brightness.dark) return _dark[world]!;
  return _light[world]!;
}

/// The three swatches of the Farbwelt picker (primary, soft, background).
List<Color> rdSwatches(RdFarbwelt world) {
  final p = rdPalette(world, Brightness.light);
  return [p.primary, p.soft, p.bg];
}
