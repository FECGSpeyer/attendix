import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_switch_lock.dart';
import 'auth_token_api.dart';
import 'saved_account.dart';
import 'saved_accounts_store.dart';
import 'stale_refresh_guard.dart';

export 'auth_token_api.dart' show AccountSwitchUnavailable, SavedSessionExpired;
export 'saved_account.dart';

/// ACCOUNT_SWITCH: the app's session changed while the switch was running
/// (e.g. a login on the login page): the switch does not replace it. The
/// target's new token is stored, so nothing is lost.
class AccountSwitchSuperseded implements Exception {
  const AccountSwitchSuperseded();
}

/// Runs [body] under a named lock shared by all app instances (browser tabs).
typedef AccountSwitchLock = Future<T> Function<T>(String name, Future<T> Function() body);

/// ACCOUNT_SWITCH: the app's own auth client, as far as the switcher needs it.
abstract class AccountSwitchAuth {
  Session? get currentSession;

  /// Makes [session] the app's session (replaces the current one WITHOUT
  /// signing it out, so its saved refresh token stays valid). [leftUserId]
  /// is the account that was active before (see [StaleRefreshGuard]).
  Future<void> activate(Session session, {String? leftUserId});

  /// No automatic token refresh of the current session while switching: a
  /// refresh that finished after [activate] would bring the old account back.
  void pauseAutoRefresh();
  void resumeAutoRefresh();

  /// Lets a token refresh of the current session that may already be
  /// running finish before the switch replaces the session (its late
  /// result would otherwise bring the old account back).
  Future<void> settle();

  /// Changes on every new sign-in, sign-out or change of account, but not
  /// on token refreshes of the same session – so a switch can tell "same
  /// session as when I started" from "someone signed in meanwhile" (also a
  /// new login of the same account).
  int get sessionGeneration;
}

class SupabaseAccountSwitchAuth implements AccountSwitchAuth {
  SupabaseAccountSwitchAuth(this._auth, {SwitchStamp? stamps}) : _stamps = stamps ?? PrefsSwitchStamp() {
    String? userId = _auth.currentUser?.id;
    // Events arrive a microtask after the change; every check of the
    // generation comes after a network call, so they are counted by then.
    _sub = _auth.onAuthStateChange.listen((state) {
      final nextUser = state.session?.user.id;
      final newLogin = state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.signedOut ||
          state.event == AuthChangeEvent.passwordRecovery ||
          nextUser != userId;
      userId = nextUser;
      if (newLogin) _generation++;
    }, onError: (_) {});
  }

  final GoTrueClient _auth;
  final SwitchStamp _stamps;
  StreamSubscription<AuthState>? _sub;
  int _generation = 0;

  @override
  int get sessionGeneration => _generation;

  void dispose() {
    _sub?.cancel();
    _guard?.cancel();
  }

  @override
  Session? get currentSession => _auth.currentSession;

  StaleRefreshGuard? _guard;

  @override
  Future<void> activate(Session session, {String? leftUserId}) async {
    _guard?.cancel();
    _guard = null;
    // Marks this switch for the guards of other tabs before they can see it.
    String? stamp;
    try {
      stamp = await _stamps.next();
    } catch (_) {}
    // Saves the session (supabase_flutter persists it) and emits
    // TOKEN_REFRESHED for the new user; no network call for a fresh session.
    await _recover(session);
    if (stamp != null && leftUserId != null && leftUserId != session.user.id) {
      _guard = StaleRefreshGuard(
        events: _auth.onAuthStateChange,
        leftUserId: leftUserId,
        target: session,
        reactivate: _recover,
        stamps: _stamps,
        stamp: stamp,
      );
    }
  }

  Future<void> _recover(Session session) => _auth.recoverSession(jsonEncode(session.toJson()));

  @override
  void pauseAutoRefresh() {
    try {
      _auth.stopAutoRefresh();
    } catch (_) {}
  }

  @override
  void resumeAutoRefresh() {
    try {
      _auth.startAutoRefresh();
    } catch (_) {}
  }

  @override
  Future<void> settle() async {
    final session = _auth.currentSession;
    final expiresAt = session?.expiresAt;
    if (session == null || expiresAt == null) return;
    // GoTrue refreshes automatically only within ~30 s of expiry. Within
    // 60 s a refresh may be running: refreshSession() joins it (or does it
    // now), so it cannot finish after the switch.
    final left = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000).difference(DateTime.now());
    if (left > const Duration(seconds: 60)) return;
    try {
      await _auth.refreshSession();
    } catch (_) {
      // Offline or the old session is gone: nothing left to race with.
    }
  }
}

/// ACCOUNT_SWITCH: remembers the accounts signed in on this device and
/// switches between them without password (new design / Beta).
///
/// How it stays valid: Supabase refresh tokens can be used once. The
/// service keeps the NEWEST refresh token of every remembered account –
/// the signed-in one is updated on every token refresh ([remember] from
/// the auth listener), the others only change when the service itself
/// uses their token. Switching never signs an account out (that would
/// revoke its session); it only swaps which session the app uses.
class AccountSwitchService {
  AccountSwitchService({
    required SavedAccountsStore store,
    required AuthTokenApi api,
    required AccountSwitchAuth auth,
    DateTime Function()? clock,
    AccountSwitchLock? lock,
  })  : _store = store,
        _api = api,
        _auth = auth,
        _clock = clock ?? DateTime.now,
        _lock = lock ?? runWithAccountSwitchLock;

  static const _switchLockName = 'attendix.account-switch';
  static const _storeLockName = 'attendix.saved-accounts';

  final AccountSwitchLock _lock;
  final SavedAccountsStore _store;
  final AuthTokenApi _api;
  final AccountSwitchAuth _auth;
  final DateTime Function() _clock;

  List<SavedAccount> _accounts = const [];
  final _changes = StreamController<List<SavedAccount>>.broadcast();
  Future<void> _queue = Future.value();
  bool _switching = false;
  bool _loaded = false;

  /// Remembered accounts, in the order they were added.
  List<SavedAccount> get accounts => _accounts;

  Stream<List<SavedAccount>> get changes => _changes.stream;

  /// A switch is running (its own token refresh events are not the user's).
  bool get isSwitching => _switching;

  /// Loads the list (once; later calls return the same data).
  Future<List<SavedAccount>> load() async {
    if (_loaded) return _accounts;
    await _mutate((list) => list);
    _loaded = true;
    return _accounts;
  }

  /// Stores the newest refresh token of [session]'s account and adds the
  /// account when [add] (otherwise only accounts already in the list are
  /// updated).
  Future<void> remember(Session session, {bool add = true}) {
    final token = session.refreshToken;
    final user = session.user;
    if (token == null || token.isEmpty) return Future.value();
    return _mutate((list) {
      final i = list.indexWhere((a) => a.userId == user.id);
      final now = _clock();
      if (i < 0) {
        if (!add) return list;
        return [
          ...list,
          SavedAccount(
            userId: user.id,
            email: user.email ?? '',
            refreshToken: token,
            lastUsedAt: now,
          ),
        ];
      }
      final updated = list[i].copyWith(
        email: (user.email ?? '').isNotEmpty ? user.email : null,
        refreshToken: token,
        lastUsedAt: now,
      );
      return [...list]..[i] = updated;
    });
  }

  /// Name and role/group shown in the switcher.
  Future<void> updateProfile(String userId, {String? name, String? label}) {
    final current = _accounts.where((a) => a.userId == userId).firstOrNull;
    // Cheap check first (called on every build of the Ich page).
    if (_loaded &&
        (current == null ||
            ((name == null || name == current.name) && (label == null || label == current.label)))) {
      return Future.value();
    }
    return _mutate((list) => [
          for (final a in list)
            a.userId == userId ? a.copyWith(name: name, label: label) : a,
        ]);
  }

  /// Removes [userId] from this device's list (no server call).
  Future<void> forget(String userId) =>
      _mutate((list) => list.where((a) => a.userId != userId).toList());

  /// Removes an account that is not the signed-in one and ends its saved
  /// session on the server, so the token on this device is worthless.
  /// Runs under the switch lock with the token read fresh from the store,
  /// so it cannot race a switch that uses the same token.
  Future<void> remove(String userId) {
    return _serial(() => _lock(_switchLockName, () async {
          final stored = await _store.load();
          final token = stored.where((a) => a.userId == userId).firstOrNull?.refreshToken;
          await forget(userId);
          if (token == null || _auth.currentSession?.user.id == userId) return;
          try {
            final session = await _api.refresh(token);
            await _api.revoke(session.accessToken);
          } catch (_) {
            // Already invalid or offline: the token is gone from this device.
          }
        }));
  }

  /// Switches the app to [userId].
  ///
  /// [beforeActivate] runs after the new session is secured but while the
  /// old account is still signed in (push token removal needs its session).
  ///
  /// Throws [SavedSessionExpired] (the account stays in the list, without
  /// token, and needs a login), [AccountSwitchUnavailable] (nothing
  /// changed) or [AccountSwitchSuperseded]. In all cases the app keeps the
  /// session it has.
  Future<Session> switchTo(
    String userId, {
    Future<void> Function()? beforeActivate,
  }) {
    return _exclusive((start) async {
      final current = _auth.currentSession;
      if (current != null && current.user.id == userId) return current;
      // Fresh from the store: another tab may have used the token already.
      final stored = await _store.load();
      final token = stored.where((a) => a.userId == userId).firstOrNull?.refreshToken;
      if (token == null || token.isEmpty) {
        throw const SavedSessionExpired('no_saved_session');
      }

      final Session next;
      try {
        next = await _api.refresh(token);
      } on SavedSessionExpired {
        await _mutate((list) => [
              for (final a in list)
                a.userId == userId ? a.copyWith(clearRefreshToken: true) : a,
            ]);
        rethrow;
      }
      if (next.user.id != userId) {
        throw const SavedSessionExpired('user_mismatch');
      }
      return _activate(next, start, beforeActivate);
    });
  }

  /// Signs in another account through [signIn] (which must not touch the
  /// app's session, see [AuthTokenApi.signInWithPassword]) and switches to
  /// it. Errors of [signIn] propagate and change nothing.
  Future<Session> addAccount(
    Future<Session> Function() signIn, {
    Future<void> Function()? beforeActivate,
  }) {
    return _exclusive((start) async {
      final current = _auth.currentSession;
      final next = await signIn();
      if (current != null && current.user.id == next.user.id) {
        // Same account again (the UI prevents this): no cleanup needed.
        return _activate(next, start, null);
      }
      return _activate(next, start, beforeActivate);
    });
  }

  /// Common frame of a switch: one at a time (also across browser tabs),
  /// no auto refresh, a running refresh settled and the current account's
  /// newest token stored first. [body] gets the session generation taken
  /// BEFORE the first await (see [_activate]).
  Future<Session> _exclusive(Future<Session> Function(int startGeneration) body) {
    if (_switching) throw StateError('account switch already running');
    final startGeneration = _auth.sessionGeneration;
    final startUserId = _auth.currentSession?.user.id;
    _switching = true;
    _auth.pauseAutoRefresh();
    return _serial(() async {
      try {
        return await _lock(_switchLockName, () async {
          await load();
          await _auth.settle();
          _checkStillCurrent(startGeneration, startUserId);
          final current = _auth.currentSession;
          // Keep the current account's newest token before leaving it.
          if (current != null) await remember(current);
          return body(startGeneration);
        });
      } finally {
        _auth.resumeAutoRefresh();
        _switching = false;
      }
    });
  }

  /// One switch/removal at a time within this app instance (the web lock
  /// covers other tabs; outside the browser it runs [body] directly).
  Future<T> _serial<T>(Future<T> Function() body) {
    final run = _switchQueue.then((_) => body());
    _switchQueue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _switchQueue = Future.value();

  void _checkStillCurrent(int startGeneration, [String? startUserId]) {
    if (_auth.sessionGeneration != startGeneration ||
        (startUserId != null && _auth.currentSession?.user.id != startUserId)) {
      throw const AccountSwitchSuperseded();
    }
  }

  /// See [AccountSwitchAuth.sessionGeneration].
  int get sessionGeneration => _auth.sessionGeneration;

  Future<Session> _activate(
    Session next,
    int startGeneration,
    Future<void> Function()? beforeActivate,
  ) async {
    final leftUserId = _auth.currentSession?.user.id;
    // The old token is used up now: store the new one before anything
    // else can fail.
    await remember(next);
    _checkStillCurrent(startGeneration);
    if (beforeActivate != null) {
      try {
        await beforeActivate();
      } catch (_) {
        // Cleanup of the old account must never block the switch.
      }
    }
    // A sign-in elsewhere while the cleanup ran wins.
    _checkStillCurrent(startGeneration);
    await _auth.activate(next, leftUserId: leftUserId);
    return next;
  }

  /// Re-reads the store and applies [change]; serialised, so concurrent
  /// updates (auth events, switch, other browser tabs) do not overwrite
  /// each other.
  Future<void> _mutate(List<SavedAccount> Function(List<SavedAccount>) change) {
    final run = _queue.then((_) => _lock(_storeLockName, () async {
          final stored = await _store.load();
          final next = change(List.of(stored));
          if (!_sameList(next, stored)) await _store.save(next);
          if (!_sameList(next, _accounts)) {
            _accounts = List.unmodifiable(next);
            _changes.add(_accounts);
          }
        }));
    _queue = run.catchError((Object _) {});
    return run;
  }

  static bool _sameList(List<SavedAccount> a, List<SavedAccount> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void dispose() {
    _changes.close();
  }
}
