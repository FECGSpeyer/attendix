import 'dart:typed_data';

/// Non-web build: no browser window.
bool isStandaloneWebApp() => false;

bool openInNewTab(String url) => false;

bool downloadBytesInBrowser(Uint8List bytes, String fileName) => false;
