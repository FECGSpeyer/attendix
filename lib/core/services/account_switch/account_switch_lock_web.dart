import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

Future<T> runWithLock<T>(String name, Future<T> Function() body) async {
  final navigator = web.window.navigator as JSObject;
  if (!navigator.has('locks')) return body();
  // The body's outcome is kept as plain values (no Completer that could
  // report an error before anyone listens) and handed out after the lock.
  var ran = false;
  T? value;
  Object? error;
  StackTrace? stack;

  JSPromise<JSAny?> granted(JSAny? _) {
    ran = true;
    return () async {
      try {
        value = await body();
      } catch (e, st) {
        error = e;
        stack = st;
      }
    }()
        .toJS;
  }

  try {
    await web.window.navigator.locks.request(name, granted.toJS).toDart;
  } catch (_) {
    // Lock API failed before granting: run without it.
    if (!ran) return body();
  }
  if (error != null) Error.throwWithStackTrace(error!, stack ?? StackTrace.current);
  return value as T;
}
