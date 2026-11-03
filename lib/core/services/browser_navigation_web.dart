import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// `Date.now()` of the last history step the browser animated itself, set by
/// the SWIPE_BACK_WEB script in `web/index.html`.
int? lastBrowserAnimatedNavigationMs() {
  try {
    final value = globalContext['attendixUaNavAt'];
    if (value == null || value.isUndefinedOrNull) return null;
    return (value as JSNumber).toDartDouble.toInt();
  } catch (_) {
    return null;
  }
}

/// Lets the SWIPE_BACK_WEB script remove its picture of the page.
void browserNavigationShown() {
  try {
    if (globalContext.has('attendixUaNavShown')) {
      globalContext.callMethod('attendixUaNavShown'.toJS);
    }
  } catch (_) {}
}
