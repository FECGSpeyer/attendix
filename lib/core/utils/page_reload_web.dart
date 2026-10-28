import 'package:web/web.dart' as web;

/// Web: full page reload (Ionic `window.location.reload()`).
void reloadPage() {
  try {
    web.window.location.reload();
  } catch (_) {
    // PWA safety: ignore if reload is not possible
  }
}
