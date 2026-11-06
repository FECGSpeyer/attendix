import 'dart:async';

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

/// Completes once [route] has finished its push transition (at once when
/// it already has, or after [timeout]).
///
/// A page that leaves the tab shell (e.g. the group selection after an
/// account switch) and navigates back into it right away must wait for
/// this: until the push is done the old shell page is still in the tree,
/// and the new shell would share its navigator key with it (duplicate
/// GlobalKey) – the tab content then stays blank until the next tab change.
Future<void> untilRouteShown(
  ModalRoute<dynamic>? route, {
  Duration timeout = const Duration(seconds: 1),
}) {
  final animation = route?.animation;
  if (animation == null || animation.isCompleted) return Future.value();
  final done = Completer<void>();
  void listener(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    animation.removeStatusListener(listener);
    if (!done.isCompleted) done.complete();
  }

  animation.addStatusListener(listener);
  return done.future.timeout(timeout, onTimeout: () {
    animation.removeStatusListener(listener);
  });
}
