import 'dart:typed_data';

import 'web_window_stub.dart'
    if (dart.library.js_interop) 'web_window_web.dart' as impl;

/// Ionic 4.17.18/4.17.19 (`Utils.isStandaloneWebApp`, `Utils.openInNewTab`):
/// browser helpers for the web build. Outside the web they do nothing.

/// True when the web app runs installed (display-mode standalone /
/// fullscreen / minimal-ui or iOS `navigator.standalone`), e.g. Safari
/// "Zum Dock hinzufügen". Such windows ignore or block `window.open`.
bool isStandaloneWebApp() => impl.isStandaloneWebApp();

/// Opens [url] in a new browser tab. Installed web apps silently ignore
/// `window.open(url, '_blank')`, so there (or when it fails) a real link is
/// clicked, which hands the URL to the default browser. Returns false
/// outside the web.
bool openInNewTab(String url) => impl.openInNewTab(url);

/// Triggers a browser download of [bytes] as [fileName]. Returns false
/// outside the web.
bool downloadBytesInBrowser(Uint8List bytes, String fileName) =>
    impl.downloadBytesInBrowser(bytes, fileName);

/// Ionic `@HostListener('window:beforeunload')` on the settings pages:
/// while any [owner] has unsaved changes, closing or reloading the browser
/// tab asks first. Call with `false` (or from dispose) to release it.
/// Does nothing outside the web.
void setUnloadWarning(Object owner, bool unsaved) =>
    impl.setUnloadWarning(owner, unsaved);

/// Ionic `if (navigator.share) navigator.share({url, title}) else copy`:
/// shares [url] through the Web Share API. Returns false when the browser
/// has none or sharing failed (the caller copies instead), true once shared
/// or cancelled by the user (AbortError), null outside the web.
Future<bool?> shareUrlInBrowser(String url, {String? title}) =>
    impl.shareUrlInBrowser(url, title: title);
