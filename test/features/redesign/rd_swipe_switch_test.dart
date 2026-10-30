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
                    child: SizedBox(width: double.infinity, height: 400, child: Text('page $selected')),
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
    expect(tester.getTopLeft(find.text('page 0')).dx, lessThan(-250));
    expect(positions.last, greaterThan(0.3));

    final dragged = tester.getTopLeft(find.text('page 0')).dx;

    // Released: the neighbour is built at once and slides in beside the
    // old content, the thumb keeps moving instead of waiting.
    await gesture.up();
    await tester.pump();
    expect(selected, 1);
    expect(find.text('page 0'), findsOneWidget);
    expect(find.text('page 1'), findsOneWidget);
    expect(tester.getTopLeft(find.text('page 1')).dx, closeTo(dragged + 800, 1));

    final released = positions.length;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final thumb = positions.skip(released).whereType<double>().toList();
    expect(thumb.length, greaterThan(5));
    expect(thumb.last, closeTo(1, 0.01));
    expect(paints, 2, reason: 'only the new page is painted, the old one keeps its layer');
    for (var i = 1; i < thumb.length; i++) {
      expect(thumb[i], greaterThan(thumb[i - 1]), reason: 'the thumb never stands still');
    }
    expect(positions.last, isNull);
    expect(find.text('page 0'), findsNothing);
    expect(tester.getTopLeft(find.text('page 1')).dx, 0);
  });
}
