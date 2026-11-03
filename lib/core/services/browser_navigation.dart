import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'browser_navigation_stub.dart'
    if (dart.library.js_interop) 'browser_navigation_web.dart'
    as impl;

/// SWIPE_BACK_WEB: true while the route change of a history step the
/// browser animated itself starts, e.g. Safari's edge swipe back (or
/// forward) on the iPhone.
///
/// Safari slides a snapshot of the previous page in under the finger and
/// only then fires `popstate`. Without this check the app afterwards plays
/// its own pop transition as well, so the page that was just swiped away
/// jumps back in and slides out a second time. `web/index.html` marks such
/// steps (`PopStateEvent.hasUAVisualTransition`, or in browsers without it a
/// swipe that started at the screen edge). The transitions that start in the
/// first frame of the route change (the page leaving and the page below)
/// then jump to their end (see `BrowserNavigationTransitionGate`); the step
/// counts as handled after that frame, so a later push or pop animates as
/// usual. [window] limits how late the route change may start.
bool browserAnimatedNavigationJustHappened({
  Duration window = const Duration(milliseconds: 800),
}) {
  if (!kIsWeb) return false;
  final at = impl.lastBrowserAnimatedNavigationMs();
  if (at == null || at == _handledMark) return false;
  final age = DateTime.now().millisecondsSinceEpoch - at;
  if (age < 0 || age >= window.inMilliseconds) return false;
  if (_pendingMark != at) {
    _pendingMark = at;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _handledMark = at;
    });
  }
  return true;
}

/// Mark whose route change already started (one frame per browser step).
int? _handledMark;

/// SWIPE_BACK_WEB: the router's location changed. A pending browser step
/// counts as handled after this frame, also when the change plays no
/// transition (e.g. a tab switch) and so never asks
/// [browserAnimatedNavigationJustHappened].
void browserNavigationRouteChanged() {
  if (!kIsWeb) return;
  final at = impl.lastBrowserAnimatedNavigationMs();
  if (at == null || at == _handledMark || at == _pendingMark) return;
  _pendingMark = at;
  SchedulerBinding.instance.addPostFrameCallback((_) {
    _handledMark = at;
  });
  SchedulerBinding.instance.scheduleFrame();
}

/// SWIPE_BACK_WEB: who sees the app (account and group). The page script
/// drops its page pictures when this changes, so a swipe back after a
/// logout or group switch never shows the previous account's data.
void setBrowserNavigationContext(String key) {
  if (kIsWeb) impl.setBrowserNavigationContext(key);
}

/// Mark whose "handled" post-frame callback is scheduled.
int? _pendingMark;

/// SWIPE_BACK_WEB: call when a transition was skipped after such a step.
/// Once the app has drawn the page (two frames: the one that starts the
/// transition and the one that shows its end), the page script removes the
/// picture it laid over the app to bridge the moment Safari drops its
/// snapshot (`web/index.html`).
void notifyBrowserNavigationShown() {
  if (!kIsWeb) return;
  // The step this transition belongs to; the script only removes its own
  // picture, never one of a newer step.
  final mark = impl.lastBrowserAnimatedNavigationMs();
  if (mark == null) return;
  final binding = SchedulerBinding.instance;
  var frames = 0;
  void afterFrame(Duration _) {
    frames++;
    if (frames < 2) {
      binding.addPostFrameCallback(afterFrame);
      binding.scheduleFrame();
      return;
    }
    impl.browserNavigationShown(mark);
  }

  binding.addPostFrameCallback(afterFrame);
  binding.scheduleFrame();
}
