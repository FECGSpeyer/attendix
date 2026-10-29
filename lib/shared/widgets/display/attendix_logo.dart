import 'package:flutter/material.dart';

import 'attendix_logo_paths.dart';

/// Colours of the Attendix logo: the tile, the clipboard and the check.
@immutable
class AttendixLogoColors {
  const AttendixLogoColors({
    required this.tile,
    required this.glyph,
    required this.check,
  });

  /// The Ionic app's icon: teal tile, white clipboard, green check.
  static const original = AttendixLogoColors(
    tile: Color(0xFF3EA5AE),
    glyph: Color(0xFFFFFFFF),
    check: Color(0xFF39C37E),
  );

  final Color tile;
  final Color glyph;
  final Color check;

  @override
  bool operator ==(Object other) =>
      other is AttendixLogoColors &&
      other.tile == tile &&
      other.glyph == glyph &&
      other.check == check;

  @override
  int get hashCode => Object.hash(tile, glyph, check);
}

/// The Attendix logo (clipboard with "A", person and check) taken over from
/// the Ionic app, drawn as a vector so it stays sharp at every size and can
/// take the colours of a Farbwelt.
class AttendixLogo extends StatelessWidget {
  const AttendixLogo({
    super.key,
    this.size = 48,
    this.colors = AttendixLogoColors.original,
    this.radius,
    this.semanticLabel = 'Attendix',
  });

  final double size;
  final AttendixLogoColors colors;

  /// Corner radius of the tile; null: the iOS app icon shape (22.5 %).
  final double? radius;

  /// null: decorative, hidden from screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final logo = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _AttendixLogoPainter(colors, radius ?? size * 0.225),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: logo);
    return Semantics(image: true, label: semanticLabel, child: logo);
  }
}

class _AttendixLogoPainter extends CustomPainter {
  _AttendixLogoPainter(this.colors, this.radius);

  final AttendixLogoColors colors;
  final double radius;

  static final Path _glyph = attendixLogoGlyphPath();
  static final Path _check = attendixLogoCheckPath();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = colors.tile,
    );
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    canvas.drawPath(_glyph, Paint()..color = colors.glyph);
    canvas.drawPath(_check, Paint()..color = colors.check);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AttendixLogoPainter old) =>
      old.colors != colors || old.radius != radius;
}
