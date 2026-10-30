// WCAG 2.1 contrast of the five Farbwelten of the new design (Beta), light
// and dark: body text 4.5:1 (AA), buttons, links and status text 3:1
// (large/bold text and UI components).
import 'dart:math' as math;

import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final world in RdFarbwelt.values) {
    for (final brightness in Brightness.values) {
      final p = rdPalette(world, brightness);
      final name = '${world.name}/${brightness.name}';
      test('$name: text and secondary text are readable', () {
        expect(contrast(p.text, p.bg), greaterThanOrEqualTo(4.5), reason: '$name text/bg');
        expect(contrast(p.text, p.surface), greaterThanOrEqualTo(4.5), reason: '$name text/surface');
        expect(contrast(p.text2, p.surface), greaterThanOrEqualTo(4.5), reason: '$name text2/surface');
      });
      test('$name: buttons, links and badges are distinguishable', () {
        expect(contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(3), reason: '$name onPrimary/primary');
        expect(contrast(p.link, p.surface), greaterThanOrEqualTo(3), reason: '$name link/surface');
        expect(contrast(p.softText, p.soft), greaterThanOrEqualTo(4.5), reason: '$name softText/soft');
        expect(contrast(p.toastText, p.toastBg), greaterThanOrEqualTo(4.5), reason: '$name toast');
      });
    }
  }
}
