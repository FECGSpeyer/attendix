import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Ionic `if (navigator.share)`: the browser has the Web Share API.
///
/// share_plus opens a `mailto:` link where the API (or `canShare`) is
/// missing, so callers check this first and copy the link instead.
bool canUseSystemShareSheet() {
  try {
    final navigator = web.window.navigator as JSObject;
    return navigator.has('share') && navigator.has('canShare');
  } catch (_) {
    return false;
  }
}
