// LOGIC_SETTINGS: "Neu laden" like Ionic `window.location.reload()`.
// On web the page is reloaded; on native platforms this is a no-op
// (callers invalidate their providers instead).
export 'page_reload_stub.dart'
    if (dart.library.js_interop) 'page_reload_web.dart';
