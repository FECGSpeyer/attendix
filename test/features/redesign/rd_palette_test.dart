import 'dart:math' as math;

import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// REDESIGN: every text colour of the five Farbwelten reaches WCAG AA
/// (4.5:1) on the background it is used on, in light and dark.
void main() {
  for (final world in RdFarbwelt.values) {
    for (final brightness in Brightness.values) {
      final p = rdPalette(world, brightness);
      final name = '${world.key}/${p.isDark ? 'dark' : 'light'}';

      // Soft backgrounds are drawn on the card surface.
      Color onSurface(Color soft) => Color.alphaBlend(soft, p.surface);

      final pairs = <String, (Color, Color)>{
        'text on bg': (p.text, p.bg),
        'text on surface': (p.text, p.surface),
        'text2 on bg': (p.text2, p.bg),
        'text2 on surface': (p.text2, p.surface),
        'onPrimary on primary': (p.onPrimary, p.primary),
        'link on bg': (p.link, p.bg),
        'link on surface': (p.link, p.surface),
        'softText on soft': (p.softText, onSurface(p.soft)),
        'present on presentSoft': (p.present, onSurface(p.presentSoft)),
        'late on lateSoft': (p.late, onSurface(p.lateSoft)),
        'excused on excusedSoft': (p.excused, onSurface(p.excusedSoft)),
        'absent on absentSoft': (p.absent, onSurface(p.absentSoft)),
        'onStatus on present': (p.onStatus, p.present),
        'toast text': (p.toastText, p.toastBg),
        'toast action': (p.toastAction, p.toastBg),
      };

      for (final entry in pairs.entries) {
        test('$name: ${entry.key} >= 4.5:1', () {
          final (fg, bg) = entry.value;
          expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5),
              reason: '$name ${entry.key}: ${_contrast(fg, bg).toStringAsFixed(2)}');
        });
      }
    }
  }

  test('Bühne is always dark', () {
    expect(rdPalette(RdFarbwelt.buehne, Brightness.light).isDark, isTrue);
    expect(RdFarbwelt.buehne.alwaysDark, isTrue);
    expect(RdFarbwelt.petrol.alwaysDark, isFalse);
  });

  test('fromKey falls back to Petrol', () {
    expect(RdFarbwelt.fromKey('konzertsaal'), RdFarbwelt.konzertsaal);
    expect(RdFarbwelt.fromKey(null), RdFarbwelt.petrol);
    expect(RdFarbwelt.fromKey('unbekannt'), RdFarbwelt.petrol);
  });

  test('swatches: primary, soft, background', () {
    final p = rdPalette(RdFarbwelt.petrol, Brightness.light);
    expect(rdSwatches(RdFarbwelt.petrol), [p.primary, p.soft, p.bg]);
  });

  testWidgets('status bar segments fill the bar height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: RdStatusBar(
              total: 4,
              semanticLabel: 'bar',
              segments: const [
                RdBarSegment(3, Colors.green),
                RdBarSegment(1, Colors.orange),
              ],
            ),
          ),
        ),
      ),
    );
    final boxes = tester
        .widgetList<ColoredBox>(find.descendant(of: find.byType(RdStatusBar), matching: find.byType(ColoredBox)))
        .toList();
    final green = find.byWidget(boxes.firstWhere((b) => b.color == Colors.green));
    final orange = find.byWidget(boxes.firstWhere((b) => b.color == Colors.orange));
    expect(tester.getSize(green), const Size(150, 8));
    expect(tester.getSize(orange), const Size(50, 8));
  });
}
