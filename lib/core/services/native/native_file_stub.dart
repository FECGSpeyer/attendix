import 'dart:typed_data';

/// NATIVE_MISC: web build – the native file viewer is never used there.
Future<bool> writeAndOpen(Uint8List bytes, String fileName) async => false;

/// NATIVE_MISC: web build – the native file viewer is never used there.
Future<bool> downloadAndOpen(String url, String fileName) async => false;
