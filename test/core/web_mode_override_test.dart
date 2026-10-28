import 'package:attendix/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('?mode=ios / ?ionic:mode=md map to the Ionic modes', () {
    expect(webModeOverride(Uri.parse('https://x.dev/?mode=ios#/tabs')),
        TargetPlatform.iOS);
    expect(webModeOverride(Uri.parse('https://x.dev/?ionic:mode=md')),
        TargetPlatform.android);
    expect(webModeOverride(Uri.parse('https://x.dev/')), isNull);
  });
}
