import 'dart:io';

import 'package:attendix/core/router/tracking_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pageViewUrlToTrack (Ionic trackPageViews)', () {
    test('tracks the url', () {
      expect(pageViewUrlToTrack('/people', null), '/people');
      expect(pageViewUrlToTrack('/attendance/42?tab=1', '/people'),
          '/attendance/42?tab=1');
    });

    test('skips urls containing /login or /legal', () {
      expect(pageViewUrlToTrack('/login', null), isNull);
      expect(pageViewUrlToTrack('/login?redirect=/people', null), isNull);
      expect(pageViewUrlToTrack('/legal', null), isNull);
      expect(pageViewUrlToTrack('/settings/legal', null), isNull);
    });

    test('does not track the same url twice in a row', () {
      expect(pageViewUrlToTrack('/people', '/people'), isNull);
      expect(pageViewUrlToTrack('', null), isNull);
    });
  });

  test('tracker sends {url} and is attached to the router, not only the root navigator', () {
    final tracker = File('lib/core/router/tracking_observer.dart').readAsStringSync();
    expect(tracker, contains("properties: {'url': toTrack}"));
    expect(tracker, isNot(contains("'route':")));
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    expect(router, contains('PageViewTracker(ref.container, router)'));
  });
}
