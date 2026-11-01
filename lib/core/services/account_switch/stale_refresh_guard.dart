import 'dart:async';

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ACCOUNT_SWITCH: marks the newest deliberate account switch across all
/// browser tabs, so a [StaleRefreshGuard] can tell a late refresh of the
/// left account from a newer switch made on purpose in another tab.
abstract class SwitchStamp {
  /// Records a new switch and returns its stamp. Called BEFORE the switch
  /// becomes visible to other tabs.
  Future<String> next();

  /// The stamp of the newest switch (any tab).
  Future<String?> current();
}

const _stampKey = 'account_switch.last_switch';

/// SharedPreferences = localStorage in the browser, shared by all tabs.
class PrefsSwitchStamp implements SwitchStamp {
  static final _random = Random();

  @override
  Future<String> next() async {
    final stamp = '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stampKey, stamp);
    return stamp;
  }

  @override
  Future<String?> current() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    return prefs.getString(_stampKey);
  }
}

/// Tests: one instance shared by several simulated tabs.
class InMemorySwitchStamp implements SwitchStamp {
  int _n = 0;
  String? value;

  @override
  Future<String> next() async => value = 's${++_n}';

  @override
  Future<String?> current() async => value;
}

/// ACCOUNT_SWITCH: protects a fresh switch against a late token refresh of
/// the account that was left, coming from ANOTHER browser tab.
///
/// Supabase shares the session between tabs over a BroadcastChannel. A tab
/// that still held account A may finish its own SDK refresh of A just
/// after this tab switched to B; its TOKEN_REFRESHED broadcast would put
/// this tab (and all others) back on A. Within [window] after the switch
/// such a broadcast refresh of the left account is answered by activating
/// B again (which broadcasts B to the other tabs). A's new token is kept by
/// the normal auth listener, so nothing is lost. Intended changes end the
/// guard: a sign-in or sign-out anywhere, and a newer switch in any tab
/// (its [SwitchStamp] differs from [stamp]) – otherwise two tabs switching
/// A→B and B→A would keep reactivating their own target.
class StaleRefreshGuard {
  StaleRefreshGuard({
    required Stream<AuthState> events,
    required String leftUserId,
    required Session target,
    required Future<void> Function(Session target) reactivate,
    required SwitchStamp stamps,
    required String stamp,
    Duration window = const Duration(seconds: 90),
  })  : _leftUserId = leftUserId,
        _latestTarget = target,
        _reactivate = reactivate,
        _stamps = stamps,
        _stamp = stamp {
    _sub = events.listen(_onEvent, onError: (_) {});
    _timer = Timer(window, cancel);
  }

  final String _leftUserId;
  final Future<void> Function(Session) _reactivate;
  final SwitchStamp _stamps;
  final String _stamp;
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
          unawaited(_reactivateIfStillLatest());
        }
      default:
        break;
    }
  }

  Future<void> _reactivateIfStillLatest() async {
    try {
      final latest = await _stamps.current();
      if (!isActive) return;
      if (latest != _stamp) {
        // A newer switch on purpose (this or another tab): it wins.
        cancel();
        return;
      }
      await _reactivate(_latestTarget);
    } catch (_) {}
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _sub?.cancel();
    _sub = null;
  }
}
