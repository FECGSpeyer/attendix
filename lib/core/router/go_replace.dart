import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// NAV_REPLACE: `router.go(location)` without a new browser history entry
/// (the current one is replaced), like Ionic `navigateRoot(..., replaceUrl)`
/// after the tenant redirect: browser Back then never returns to the
/// instance selection. Uses the router's own navigator context, so it also
/// works when the calling page was already replaced.
void goReplacingHistory(GoRouter router, String location) {
  final ctx = router.routerDelegate.navigatorKey.currentContext;
  if (ctx == null) {
    router.go(location);
    return;
  }
  Router.neglect(ctx, () => router.go(location));
}
