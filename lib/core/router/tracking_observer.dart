import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendix/core/services/tracking/tracking_event.dart';
import 'package:attendix/core/services/tracking/tracking_service.dart';

/// URL to track as `page_view` after a navigation, or null to skip it
/// (Ionic app.component `trackPageViews`: every NavigationEnd with
/// `{url: urlAfterRedirects}`, skipped when the url contains `/login` or
/// `/legal`). Navigations to the same url are not tracked again (Angular
/// ignores same-url navigations).
@visibleForTesting
String? pageViewUrlToTrack(String url, String? lastTrackedUrl) {
  if (url.isEmpty || url == lastTrackedUrl) return null;
  if (url.contains('/login') || url.contains('/legal')) return null;
  return url;
}

/// Fires `page_view` with `{url}` for every navigation of the [GoRouter],
/// including tab pages inside the `ShellRoute` (a `NavigatorObserver` on the
/// root navigator does not see them).
class PageViewTracker {
  PageViewTracker(this._container, this._router) {
    _router.routerDelegate.addListener(_onChange);
  }

  final ProviderContainer _container;
  final GoRouter _router;
  String? _lastUrl;
  String? _lastSeen;

  void _onChange() {
    final String url;
    try {
      url = _router.routerDelegate.currentConfiguration.uri.toString();
    } catch (_) {
      return;
    }
    if (url == _lastSeen) return;
    _lastSeen = url;
    final toTrack = pageViewUrlToTrack(url, _lastUrl);
    if (toTrack == null) return;
    _lastUrl = toTrack;
    _container.read(trackingServiceProvider).track(
          TrackingEvent.pageView,
          properties: {'url': toTrack},
        );
  }

  void dispose() {
    _router.routerDelegate.removeListener(_onChange);
  }
}
