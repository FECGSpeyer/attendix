import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// ACCOUNT_SWITCH: protects a fresh switch against a late token refresh of
/// the account that was left, coming from ANOTHER browser tab.
///
/// Supabase shares the session between tabs over a BroadcastChannel. A tab
/// that still held account A may finish its own SDK refresh of A just
/// after this tab switched to B; its TOKEN_REFRESHED broadcast would put
/// this tab (and all others) back on A. Within [window] after the switch
/// such a broadcast refresh of the left account is answered by activating
/// B again (which broadcasts B to the other tabs). A's new token is kept by
/// the normal auth listener, so nothing is lost. Intended changes – a
/// sign-in or sign-out anywhere – end the guard.
class StaleRefreshGuard {
  StaleRefreshGuard({
    required Stream<AuthState> events,
    required String leftUserId,
    required Session target,
    required Future<void> Function(Session target) reactivate,
    Duration window = const Duration(seconds: 90),
  })  : _leftUserId = leftUserId,
        _latestTarget = target,
        _reactivate = reactivate {
    _sub = events.listen(_onEvent, onError: (_) {});
    _timer = Timer(window, cancel);
  }

  final String _leftUserId;
  final Future<void> Function(Session) _reactivate;
  Session _latestTarget;
  StreamSubscription<AuthState>? _sub;
  Timer? _timer;

  bool get isActive => _sub != null;

  void _onEvent(AuthState state) {
    final session = state.session;
    switch (state.event) {
      case AuthChangeEvent.signedIn ||
            AuthChangeEvent.signedOut ||
            AuthChangeEvent.passwordRecovery:
        // Someone signed in or out on purpose: that wins.
        cancel();
      case AuthChangeEvent.tokenRefreshed:
        if (session == null) return;
        if (session.user.id == _latestTarget.user.id) {
          _latestTarget = session; // keep the newest session of B
        } else if (state.fromBroadcast && session.user.id == _leftUserId) {
          unawaited(_reactivate(_latestTarget).catchError((_) {}));
        }
      default:
        break;
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _sub?.cancel();
    _sub = null;
  }
}
