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
///
/// SOL_FIX14: unlike Ionic, the tracked value is [sanitizePageViewUrl] –
/// share / edit keys must never end up in `usage_events`.
@visibleForTesting
String? pageViewUrlToTrack(
  String url,
  String? lastTrackedUrl, {
  String? routePattern,
}) {
  if (url.isEmpty || url == lastTrackedUrl) return null;
  if (url.contains('/login') || url.contains('/legal')) return null;
  return sanitizePageViewUrl(url, routePattern: routePattern);
}

/// Route patterns whose path parameters are access secrets themselves
/// (public song share link, registration invite link): only the pattern
/// is tracked for them.
const _secretPathRoutePrefixes = ['/:songSharingId', '/register/:'];

/// SOL_FIX14: the path of [url] without query parameters and fragment
/// (`/plan?id=1&key=…&edit=…` → `/plan`, `/planung?id=…&edit=…` →
/// `/planung`, `/org-plan?key=…` → `/org-plan`). For routes whose path
/// carries a secret ([routePattern] = the matched go_router pattern, e.g.
/// `/:songSharingId/:songId`) the pattern is tracked instead.
@visibleForTesting
String sanitizePageViewUrl(String url, {String? routePattern}) {
  if (routePattern != null &&
      _secretPathRoutePrefixes.any(routePattern.startsWith)) {
    return routePattern;
  }
  final cut = url.indexOf(RegExp(r'[?#]'));
  final path = cut == -1 ? url : url.substring(0, cut);
  return path.isEmpty ? '/' : path;
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
    final String? routePattern;
    try {
      final config = _router.routerDelegate.currentConfiguration;
      url = config.uri.toString();
      routePattern = config.fullPath;
    } catch (_) {
      return;
    }
    if (url == _lastSeen) return;
    _lastSeen = url;
    final toTrack =
        pageViewUrlToTrack(url, _lastUrl, routePattern: routePattern);
    if (toTrack == null) return;
    _lastUrl = url;
    _container.read(trackingServiceProvider).track(
          TrackingEvent.pageView,
          properties: {'url': toTrack},
        );
  }

  void dispose() {
    _router.routerDelegate.removeListener(_onChange);
  }
}
