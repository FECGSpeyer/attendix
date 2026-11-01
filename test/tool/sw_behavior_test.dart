// PWA_SW: runs the executable service worker / update tests
// (tool/web/test/sw_behavior.test.mjs) with Node, so `flutter test` and CI
// cover the worker's behaviour, not only its source text.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final hasNode = () {
    try {
      return Process.runSync('node', ['--version']).exitCode == 0;
    } catch (_) {
      return false;
    }
  }();

  test(
    'service worker and update handling behave as specified (node --test)',
    () {
      final result = Process.runSync(
        'node',
        ['--test', 'tool/web/test/sw_behavior.test.mjs'],
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
    skip: hasNode ? false : 'node is not installed',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
