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
void browserNavigationShown(int mark) {
  try {
    if (globalContext.has('attendixUaNavShown')) {
      globalContext.callMethod('attendixUaNavShown'.toJS, mark.toJS);
    }
  } catch (_) {}
}

/// Hands the account/group key to the SWIPE_BACK_WEB script; returns the
/// script's context generation.
int? setBrowserNavigationContext(String key) {
  try {
    if (globalContext.has('attendixSetNavContext')) {
      final gen = globalContext.callMethod(
        'attendixSetNavContext'.toJS,
        key.toJS,
      );
      if (gen != null && gen.isA<JSNumber>()) {
        return (gen as JSNumber).toDartDouble.toInt();
      }
    }
  } catch (_) {}
  return null;
}

/// The app has drawn a page for context generation [gen].
void browserNavigationContextDrawn(int gen) {
  try {
    if (globalContext.has('attendixNavContextDrawn')) {
      globalContext.callMethod('attendixNavContextDrawn'.toJS, gen.toJS);
    }
  } catch (_) {}
}
