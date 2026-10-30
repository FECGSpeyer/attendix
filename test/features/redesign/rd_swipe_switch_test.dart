import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts how often the swiped content is painted.
class _CountingPainter extends CustomPainter {
  _CountingPainter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// REDESIGN: swiping Aktiv / Pausiert must not rebuild or repaint the list on
/// every drag frame (that made the animation stutter on the iPhone).
void main() {
  testWidgets('dragging moves the content without repainting it, then switches', (tester) async {
    var paints = 0;
    var selected = 0;
    final positions = <double?>[];
    final painter = _CountingPainter(() => paints++);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRdTheme(RdFarbwelt.values.first, Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder:
                (context, setState) => RdSwipeSwitch<int>(
                  values: const [0, 1],
                  selected: selected,
                  onChanged: (v) => setState(() => selected = v),
                  onDrag: positions.add,
                  child: CustomPaint(
                    painter: painter,
                    child: const SizedBox(width: double.infinity, height: 400, child: Text('content')),
                  ),
                ),
          ),
        ),
      ),
    );
    expect(paints, 1);

    final gesture = await tester.startGesture(const Offset(400, 200));
    for (var i = 0; i < 30; i++) {
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(paints, 1, reason: 'drag frames only move the cached layer');
    expect(tester.getTopLeft(find.text('content')).dx, lessThan(-250));
    expect(positions.last, greaterThan(0.3));

    await gesture.up();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(selected, 1);
    expect(positions.last, isNull);
    expect(tester.getTopLeft(find.text('content')).dx, 0);
  });
}
