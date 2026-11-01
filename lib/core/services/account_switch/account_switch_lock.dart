import 'account_switch_lock_stub.dart'
    if (dart.library.js_interop) 'account_switch_lock_web.dart' as impl;

/// ACCOUNT_SWITCH: runs [body] while holding the lock [name] across all
/// browser tabs of the app (Web Locks API), so two tabs cannot use the same
/// saved refresh token or overwrite each other's account list. Outside the
/// browser (one app instance) and in browsers without Web Locks it just
/// runs [body]; the service serialises its own calls anyway.
Future<T> runWithAccountSwitchLock<T>(String name, Future<T> Function() body) =>
    impl.runWithLock(name, body);
