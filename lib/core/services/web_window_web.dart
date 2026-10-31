import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

@JS('window.navigator.standalone')
external bool? get _navigatorStandalone;

bool isStandaloneWebApp() {
  try {
    if (_navigatorStandalone == true) return true;
  } catch (_) {}
  try {
    for (final mode in const ['standalone', 'fullscreen', 'minimal-ui']) {
      if (web.window.matchMedia('(display-mode: $mode)').matches) return true;
    }
  } catch (_) {}
  return false;
}

void _clickLink(String url, {String? download}) {
  final link = web.document.createElement('a') as web.HTMLAnchorElement;
  link.href = url;
  if (download != null) {
    link.download = download;
  } else {
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
  }
  link.style.display = 'none';
  web.document.body?.appendChild(link);
  link.click();
  link.remove();
}

bool openInNewTab(String url) {
  if (!isStandaloneWebApp()) {
    try {
      final opened = web.window.open(url, '_blank');
      if (opened != null) {
        try {
          opened.opener = null;
        } catch (_) {}
        return true;
      }
    } catch (_) {}
  }
  _clickLink(url);
  return true;
}

bool downloadBytesInBrowser(Uint8List bytes, String fileName) {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  _clickLink(url, download: fileName);
  Future.delayed(
      const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  return true;
}
