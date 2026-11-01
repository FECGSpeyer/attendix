import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

Future<T> runWithLock<T>(String name, Future<T> Function() body) async {
  final navigator = web.window.navigator as JSObject;
  if (!navigator.has('locks')) return body();
  final result = Completer<T>();
  JSPromise<JSAny?> granted(JSAny? _) {
    final done = Completer<void>();
    body().then(result.complete, onError: result.completeError).whenComplete(done.complete);
    return done.future.toJS;
  }

  try {
    await web.window.navigator.locks.request(name, granted.toJS).toDart;
  } catch (e, st) {
    // Lock API failed before running the body: run without it.
    if (!result.isCompleted) {
      try {
        result.complete(await body());
      } catch (e2, st2) {
        result.completeError(e2, st2);
      }
    }
    if (!result.isCompleted) result.completeError(e, st);
  }
  return result.future;
}
