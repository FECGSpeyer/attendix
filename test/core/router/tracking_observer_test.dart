import 'dart:io';

import 'package:attendix/core/router/tracking_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pageViewUrlToTrack (Ionic trackPageViews)', () {
    test('tracks the url', () {
      expect(pageViewUrlToTrack('/people', null), '/people');
      expect(pageViewUrlToTrack('/attendance/42', '/people'),
          '/attendance/42');
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

  group('SOL_FIX14: no secrets in usage_events', () {
    test('strips query parameters and fragments (share / edit keys)', () {
      expect(pageViewUrlToTrack('/plan?id=5&key=s3cr3t&edit=ed1t', null),
          '/plan');
      expect(pageViewUrlToTrack('/planung?id=abc&edit=ed1t', null), '/planung');
      expect(pageViewUrlToTrack('/org-plan?key=s3cr3t', null), '/org-plan');
      expect(pageViewUrlToTrack('/attendance/42?tab=1#top', null),
          '/attendance/42');
      expect(sanitizePageViewUrl('/people#x'), '/people');
      expect(sanitizePageViewUrl('?key=s3cr3t'), '/');
    });

    test('tracks only the pattern for routes with secret path parameters', () {
      expect(
        pageViewUrlToTrack('/AbCdEf123', null, routePattern: '/:songSharingId'),
        '/:songSharingId',
      );
      expect(
        pageViewUrlToTrack('/AbCdEf123/7', null,
            routePattern: '/:songSharingId/:songId'),
        '/:songSharingId/:songId',
      );
      expect(
        pageViewUrlToTrack('/register/inv-123', null,
            routePattern: '/register/:id'),
        '/register/:id',
      );
      expect(
        pageViewUrlToTrack('/attendance/42', null,
            routePattern: '/attendance/:id'),
        '/attendance/42',
      );
    });

    test('another plan of the same route is tracked again', () {
      // dedup compares the raw url; the tracked value is the sanitized one
      expect(pageViewUrlToTrack('/plan?id=2&key=b', '/plan?id=1&key=a'),
          '/plan');
      expect(pageViewUrlToTrack('/plan?id=1&key=a', '/plan?id=1&key=a'),
          isNull);
    });

    test('the tracker passes the route pattern and never the raw uri', () {
      final tracker =
          File('lib/core/router/tracking_observer.dart').readAsStringSync();
      expect(tracker, contains('routePattern = config.fullPath'));
      expect(tracker, contains("properties: {'url': toTrack}"));
      expect(tracker, isNot(contains("{'url': url}")));
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
