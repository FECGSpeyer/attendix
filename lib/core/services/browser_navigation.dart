import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'browser_navigation_stub.dart'
    if (dart.library.js_interop) 'browser_navigation_web.dart'
    as impl;

/// SWIPE_BACK_WEB: true right after the browser itself animated a history
/// step, e.g. Safari's edge swipe back (or forward) on the iPhone.
///
/// Safari slides a snapshot of the previous page in under the finger and
/// only then fires `popstate`. Without this check the app afterwards plays
/// its own pop transition as well, so the page that was just swiped away
/// jumps back in and slides out a second time. `web/index.html` marks such
/// steps (`PopStateEvent.hasUAVisualTransition`, or a touch that started at
/// the screen edge); route transitions starting within [window] then jump to
/// their end instead (see `BrowserNavigationTransitionGate`).
bool browserAnimatedNavigationJustHappened({
  Duration window = const Duration(milliseconds: 800),
}) {
  if (!kIsWeb) return false;
  final at = impl.lastBrowserAnimatedNavigationMs();
  if (at == null) return false;
  final age = DateTime.now().millisecondsSinceEpoch - at;
  return age >= 0 && age < window.inMilliseconds;
}

/// SWIPE_BACK_WEB: call when a transition was skipped after such a step.
/// Once the app has drawn the page (two frames: the one that starts the
/// transition and the one that shows its end), the page script removes the
/// picture it laid over the app to bridge the moment Safari drops its
/// snapshot (`web/index.html`).
void notifyBrowserNavigationShown() {
  if (!kIsWeb) return;
  final binding = SchedulerBinding.instance;
  var frames = 0;
  void afterFrame(Duration _) {
    frames++;
    if (frames < 2) {
      binding.addPostFrameCallback(afterFrame);
      binding.scheduleFrame();
      return;
    }
    impl.browserNavigationShown();
  }

  binding.addPostFrameCallback(afterFrame);
  binding.scheduleFrame();
}
