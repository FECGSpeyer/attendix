import 'package:flutter/material.dart';

/// IOS_FORMS2: Ionicons glyphs without a Material/Cupertino equivalent,
/// drawn from the ionicons 512×512 SVGs with the ambient [IconTheme]
/// colour and size.

/// Ionicons `information` – a plain "i" (no circle), as in the Ionic
/// "Termin hinzufügen" date row.
class IonInformationIcon extends StatelessWidget {
  const IonInformationIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    return SizedBox.square(
      dimension: s,
      child: CustomPaint(
        painter: _InformationPainter(
          color ?? theme.color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _InformationPainter extends CustomPainter {
  _InformationPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 512;
    canvas.save();
    canvas.scale(k, k);
    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 40
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    // M196 220h64v172
    canvas.drawPath(
      Path()
        ..moveTo(196, 220)
        ..lineTo(260, 220)
        ..lineTo(260, 392),
      stroke,
    );
    // M187 396h138
    canvas.drawLine(const Offset(187, 396), const Offset(325, 396), stroke);
    // Dot: circle r=32 at (256,128)
    canvas.drawCircle(const Offset(256, 128), 32, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InformationPainter old) => old.color != color;
}

/// Ionicons `chevron-expand` (⇅) – the iOS `ion-select` icon.
class IonChevronExpandIcon extends StatelessWidget {
  const IonChevronExpandIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    return SizedBox.square(
      dimension: s,
      child: CustomPaint(
        painter: _ChevronExpandPainter(
          color ?? theme.color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ChevronExpandPainter extends CustomPainter {
  _ChevronExpandPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 512;
    canvas.save();
    canvas.scale(k, k);
    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 48
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    // m136 208 120-104 120 104
    canvas.drawPath(
      Path()
        ..moveTo(136, 208)
        ..lineTo(256, 104)
        ..lineTo(376, 208),
      stroke,
    );
    // M136 304l120 104 120-104
    canvas.drawPath(
      Path()
        ..moveTo(136, 304)
        ..lineTo(256, 408)
        ..lineTo(376, 304),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChevronExpandPainter old) => old.color != color;
}
