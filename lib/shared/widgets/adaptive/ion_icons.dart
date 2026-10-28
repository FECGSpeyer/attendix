import 'package:flutter/material.dart';

/// IOS_THEME2: ionicons without a Material / Cupertino font glyph, drawn
/// from their SVG paths so they look like in Ionic (both modes).

/// ionicon `information-outline`: a plain "i" (no circle) – the legend
/// button in the Ionic headers (Meine Termine, Übersicht, Eltern).
/// Uses the ambient [IconTheme] colour and size like [Icon].
class IonInformationIcon extends StatelessWidget {
  const IonInformationIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final s = size ?? iconTheme.size ?? 24;
    final c = color ?? iconTheme.color ?? const Color(0xFF000000);
    return Semantics(
      excludeSemantics: true,
      child: SizedBox(
        width: s,
        height: s,
        child: CustomPaint(painter: _InformationOutlinePainter(c)),
      ),
    );
  }
}

class _InformationOutlinePainter extends CustomPainter {
  const _InformationOutlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox 0 0 512 512
    final k = size.shortestSide / 512;
    canvas.scale(k);
    final stroke = Paint()
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
    // M256 160a32 32 0 1 1 32-32 32 32 0 0 1-32 32
    canvas.drawCircle(
      const Offset(256, 128),
      32,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_InformationOutlinePainter old) => old.color != color;
}
