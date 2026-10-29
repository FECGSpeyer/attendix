import 'dart:io';

import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppTheme.webLookOverride = null);

  test('?mode=ios / ?ionic:mode=md map to the Ionic modes', () {
    expect(webModeOverride(Uri.parse('https://x.dev/?mode=ios#/tabs')),
        TargetPlatform.iOS);
    expect(webModeOverride(Uri.parse('https://x.dev/?ionic:mode=md')),
        TargetPlatform.android);
    expect(webModeOverride(Uri.parse('https://x.dev/')), isNull);
  });

  test('WEB_MODE_FIX: the override only changes the look', () {
    applyWebModeOverride(Uri.parse('https://x.dev/?mode=ios'));
    expect(AppTheme.light.platform, TargetPlatform.iOS);
    expect(AppTheme.dark.platform, TargetPlatform.iOS);
    expect(debugDefaultTargetPlatformOverride, isNull);

    applyWebModeOverride(Uri.parse('https://x.dev/?mode=md'));
    expect(AppTheme.light.platform, TargetPlatform.android);
  });

  test('WEB_MODE_FIX: no debug-only platform override in app code', () {
    // The setter throws in release builds (white screen with ?mode=…).
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => RegExp(r'debugDefaultTargetPlatformOverride\s*=')
            .hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
