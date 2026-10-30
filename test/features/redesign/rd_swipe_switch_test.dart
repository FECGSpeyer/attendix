import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts how often the swiped content is built.
class _Counted extends StatelessWidget {
  const _Counted(this.onBuild);

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const SizedBox(width: double.infinity, height: 400, child: Text('content'));
  }
}

/// REDESIGN: swiping Aktiv / Pausiert must not rebuild the list on every
/// drag frame (that made the animation stutter on the iPhone).
void main() {
  testWidgets('dragging moves the content without rebuilding it, then switches', (tester) async {
    var builds = 0;
    var selected = 0;
    final positions = <double?>[];
    final content = _Counted(() => builds++);

    await tester.pumpWidget(MaterialApp(
      theme: buildRdTheme(RdFarbwelt.values.first, Brightness.light),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => RdSwipeSwitch<int>(
            values: const [0, 1],
            selected: selected,
            onChanged: (v) => setState(() => selected = v),
            onDrag: positions.add,
            child: content,
          ),
        ),
      ),
    ));
    expect(builds, 1);

    final gesture = await tester.startGesture(const Offset(400, 200));
    for (var i = 0; i < 30; i++) {
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(builds, 1, reason: 'drag frames only move the cached layer');
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
