import 'dart:async';
import 'dart:convert';

import 'package:attendix/core/providers/account_switch_providers.dart' show followAccountChange, followsOtherTab;
import 'package:attendix/core/services/account_switch/account_switch_service.dart';
import 'package:attendix/core/services/account_switch/auth_token_api.dart';
import 'package:attendix/core/services/account_switch/saved_accounts_store.dart';
import 'package:attendix/core/services/account_switch/stale_refresh_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user(String id, [String? email]) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: email ?? '$id@test.de',
      createdAt: '2026-11-01T00:00:00Z',
    );

Session _session(String userId, String refresh) => Session(
      accessToken: 'access-$userId-$refresh',
      tokenType: 'bearer',
      refreshToken: refresh,
      user: _user(userId),
    );

class _FakeApi implements AuthTokenApi {
  /// refresh token → user id; each use rotates to the token plus a "+".
  final Map<String, String> valid = {};
  final List<String> refreshed = [];
  final List<String> revoked = [];
  Object? failWith;

  @override
  Future<Session> refresh(String refreshToken) async {
    refreshed.add(refreshToken);
    if (failWith != null) throw failWith!;
    final user = valid.remove(refreshToken);
    if (user == null) throw const SavedSessionExpired('refresh_token_not_found');
    final next = '$refreshToken+';
    valid[next] = user;
    return _session(user, next);
  }

  /// e-mail → (password, user id)
  final Map<String, (String, String)> accounts = {};

  @override
  Future<Session> signInWithPassword(String email, String password) async {
    if (failWith != null) throw failWith!;
    final entry = accounts[email];
    if (entry == null || entry.$1 != password) {
      throw const AuthException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials');
    }
    final token = 'login-${entry.$2}';
    valid[token] = entry.$2;
    return _session(entry.$2, token);
  }

  @override
  Future<void> revoke(String accessToken) async => revoked.add(accessToken);
}

class _FakeAuth implements AccountSwitchAuth {
  _FakeAuth(this.currentSession);

  @override
  Session? currentSession;
  final List<String> log = [];

  final List<String?> leftUsers = [];

  @override
  Future<void> activate(Session session, {String? leftUserId}) async {
    leftUsers.add(leftUserId);
    log.add('activate:${session.user.id}');
    currentSession = session;
  }

  @override
  void pauseAutoRefresh() => log.add('pause');

  @override
  void resumeAutoRefresh() => log.add('resume');

  /// Simulates a refresh of the current session that was already running.
  Session? pendingRefresh;

  /// Simulates a sign-in that finishes while the switch waits in settle().
  Session? loginDuringSettle;

  @override
  int sessionGeneration = 0;

  /// A sign-in somewhere else in the app (login page).
  void signInElsewhere(Session s) {
    currentSession = s;
    sessionGeneration++;
  }

  @override
  Future<void> settle() async {
    log.add('settle');
    final pending = pendingRefresh;
    if (pending != null) {
      pendingRefresh = null;
      currentSession = pending; // same session, refreshed: no new generation
    }
    final login = loginDuringSettle;
    if (login != null) {
      loginDuringSettle = null;
      signInElsewhere(login);
    }
  }
}

void main() {
  late InMemorySavedAccountsStore store;
  late _FakeApi api;
  late _FakeAuth auth;
  late AccountSwitchService service;

  void build({Session? current, List<SavedAccount> saved = const []}) {
    store = InMemorySavedAccountsStore(saved);
    api = _FakeApi();
    auth = _FakeAuth(current);
    service = AccountSwitchService(store: store, api: api, auth: auth);
  }

  String? tokenOf(String userId) =>
      store.accounts.where((a) => a.userId == userId).firstOrNull?.refreshToken;

  group('Account switch – remembering', () {
    test('adds a new account only when add is true', () async {
      build();
      await service.remember(_session('a', 'ra1'), add: false);
      expect(store.accounts, isEmpty);
      await service.remember(_session('a', 'ra1'));
      expect(store.accounts.single.userId, 'a');
      expect(store.accounts.single.email, 'a@test.de');
      expect(tokenOf('a'), 'ra1');
    });

    test('a token refresh of a known account stores the newest token', () async {
      build(saved: const [SavedAccount(userId: 'a', email: 'a@test.de', refreshToken: 'ra1')]);
      await service.remember(_session('a', 'ra2'), add: false);
      expect(tokenOf('a'), 'ra2');
    });

    test('concurrent updates are serialised, none is lost', () async {
      build();
      await Future.wait([
        service.remember(_session('a', 'ra1')),
        service.remember(_session('b', 'rb1')),
        service.remember(_session('c', 'rc1')),
        service.updateProfile('a', name: 'Anna A'),
      ]);
      expect(store.accounts.map((a) => a.userId), ['a', 'b', 'c']);
    });

    test('forget removes only that account', () async {
      build(saved: const [
        SavedAccount(userId: 'a', email: 'a@test.de', refreshToken: 'ra'),
        SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb'),
      ]);
      await service.forget('a');
      expect(store.accounts.map((a) => a.userId), ['b']);
    });

    test('changes stream reports the new list', () async {
      build();
      final next = service.changes.first;
      await service.remember(_session('a', 'ra1'));
      expect((await next).single.userId, 'a');
    });
  });

  group('Account switch – switching', () {
    test('switches without signing out and keeps both tokens valid', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      api.valid['rb1'] = 'b';
      final order = <String>[];
      final next = await service.switchTo('b', beforeActivate: () async {
        // Old account still active; new token already stored.
        order.add('before:${auth.currentSession?.user.id}:${tokenOf('b')}');
      });

      expect(next.user.id, 'b');
      expect(auth.currentSession?.user.id, 'b');
      expect(order, ['before:a:rb1+']);
      expect(auth.log, ['pause', 'settle', 'activate:b', 'resume']);
      // A's newest token was saved before leaving it, B's rotated token too.
      expect(tokenOf('a'), 'ra1');
      expect(tokenOf('b'), 'rb1+');
      expect(api.refreshed, ['rb1']);
      expect(api.revoked, isEmpty);
    });

    test('switch back uses the token saved when leaving', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      api.valid['rb1'] = 'b';
      api.valid['ra1'] = 'a';
      await service.switchTo('b');
      await service.switchTo('a');
      expect(auth.currentSession?.user.id, 'a');
      expect(api.refreshed, ['rb1', 'ra1']);
      expect(tokenOf('a'), 'ra1+');
      expect(tokenOf('b'), 'rb1+');
    });

    test('expired saved session: stays on the current account, token cleared', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'gone')],
      );
      var before = false;
      await expectLater(
        service.switchTo('b', beforeActivate: () async => before = true),
        throwsA(isA<SavedSessionExpired>()),
      );
      expect(auth.currentSession?.user.id, 'a');
      expect(before, isFalse);
      expect(auth.log, ['pause', 'settle', 'resume']);
      final b = store.accounts.firstWhere((x) => x.userId == 'b');
      expect(b.canResume, isFalse);
      expect(service.isSwitching, isFalse);
    });

    test('offline: nothing changes and the token is kept', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      api.failWith = const AccountSwitchUnavailable('offline');
      await expectLater(service.switchTo('b'), throwsA(isA<AccountSwitchUnavailable>()));
      expect(auth.currentSession?.user.id, 'a');
      expect(tokenOf('b'), 'rb1');
    });

    test('a token of another user is never activated', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rx')],
      );
      api.valid['rx'] = 'c';
      await expectLater(service.switchTo('b'), throwsA(isA<SavedSessionExpired>()));
      expect(auth.currentSession?.user.id, 'a');
    });

    test('switching to the signed-in account does nothing', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'a', email: 'a@test.de', refreshToken: 'ra1')],
      );
      await service.switchTo('a');
      expect(api.refreshed, isEmpty);
      expect(auth.log, ['pause', 'settle', 'resume']);
    });

    test('works from the login page (no current session)', () async {
      build(saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')]);
      api.valid['rb1'] = 'b';
      await service.switchTo('b');
      expect(auth.currentSession?.user.id, 'b');
    });

    test('a failing cleanup of the old account does not block the switch', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      api.valid['rb1'] = 'b';
      await service.switchTo('b', beforeActivate: () async => throw Exception('push'));
      expect(auth.currentSession?.user.id, 'b');
    });
  });

  group('Account switch – races (Sol review)', () {
    test('a refresh of the old account that was running is settled first and its token kept', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      api.valid['rb1'] = 'b';
      auth.pendingRefresh = _session('a', 'ra2');
      await service.switchTo('b');
      expect(auth.currentSession?.user.id, 'b');
      expect(tokenOf('a'), 'ra2');
    });

    test('a login that finished during the switch wins', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      api.valid['rb1'] = 'b';
      await expectLater(
        service.switchTo('b', beforeActivate: () async {
          auth.signInElsewhere(_session('c', 'rc1')); // login page
        }),
        throwsA(isA<AccountSwitchSuperseded>()),
      );
      expect(auth.currentSession?.user.id, 'c');
      // B's rotated token is not lost.
      expect(tokenOf('b'), 'rb1+');
    });

    test('a login that finished while the switch waited is not overwritten', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      api.valid['rb1'] = 'b';
      auth.loginDuringSettle = _session('c', 'rc1');
      await expectLater(service.switchTo('b'), throwsA(isA<AccountSwitchSuperseded>()));
      expect(auth.currentSession?.user.id, 'c');
      expect(api.refreshed, isEmpty);
    });

    test('a new login of the SAME account meanwhile also wins', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      api.valid['rb1'] = 'b';
      await expectLater(
        service.switchTo('b', beforeActivate: () async {
          auth.signInElsewhere(_session('a', 'ra-new'));
        }),
        throwsA(isA<AccountSwitchSuperseded>()),
      );
      expect(auth.currentSession?.refreshToken, 'ra-new');
    });

    test('remove runs after a running switch and uses the fresh token', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      api.valid['rb1'] = 'b';
      final switching = service.switchTo('b');
      final removing = service.remove('b');
      await switching;
      await removing;
      // remove waited: B is active, so its session is not revoked.
      expect(auth.currentSession?.user.id, 'b');
      expect(api.revoked, isEmpty);
      expect(api.refreshed, ['rb1']);
    });

    test('the target token is read fresh from the store (other tab)', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      await service.load();
      // Another tab switched to B meanwhile and stored the rotated token.
      store.accounts = [const SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb2')];
      api.valid['rb2'] = 'b';
      await service.switchTo('b');
      expect(api.refreshed, ['rb2']);
    });

    test('switches and list updates run under the cross-tab locks', () async {
      final locks = <String>[];
      store = InMemorySavedAccountsStore(const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')]);
      api = _FakeApi()..valid['rb1'] = 'b';
      auth = _FakeAuth(_session('a', 'ra1'));
      service = AccountSwitchService(
        store: store,
        api: api,
        auth: auth,
        lock: <T>(name, body) {
          locks.add(name);
          return body();
        },
      );
      await service.switchTo('b');
      expect(locks.first, 'attendix.account-switch');
      expect(locks, contains('attendix.saved-accounts'));
    });
  });

  group('Account switch – adding', () {
    test('wrong password changes nothing (no cleanup of the current account)', () async {
      build(current: _session('a', 'ra1'));
      api.accounts['b@test.de'] = ('secret', 'b');
      var cleanup = false;
      await expectLater(
        service.addAccount(
          () => api.signInWithPassword('b@test.de', 'wrong'),
          beforeActivate: () async => cleanup = true,
        ),
        throwsA(isA<AuthException>()),
      );
      expect(cleanup, isFalse);
      expect(auth.currentSession?.user.id, 'a');
      expect(store.accounts.map((a) => a.userId), ['a']);
    });

    test('correct password stores both accounts and activates the new one', () async {
      build(current: _session('a', 'ra1'));
      api.accounts['b@test.de'] = ('secret', 'b');
      final order = <String>[];
      await service.addAccount(
        () => api.signInWithPassword('b@test.de', 'secret'),
        beforeActivate: () async => order.add('cleanup:${auth.currentSession?.user.id}'),
      );
      expect(order, ['cleanup:a']);
      expect(auth.currentSession?.user.id, 'b');
      expect(tokenOf('a'), 'ra1');
      expect(tokenOf('b'), 'login-b');
    });
  });

  group('Account switch – removing', () {
    test('removing another account revokes its session on the server', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      api.valid['rb1'] = 'b';
      await service.remove('b');
      expect(store.accounts, isEmpty);
      expect(api.revoked, ['access-b-rb1+']);
    });

    test('removing the signed-in account makes no server call', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'a', email: 'a@test.de', refreshToken: 'ra1')],
      );
      await service.remove('a');
      expect(store.accounts, isEmpty);
      expect(api.refreshed, isEmpty);
    });
  });

  group('Account switch – token API', () {
    Map<String, dynamic> sessionJson(String user, String refresh) => {
          'access_token': 'acc',
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': refresh,
          'user': _user(user).toJson(),
        };

    test('refresh posts to the GoTrue token endpoint with the anon key', () async {
      late http.Request seen;
      final api = HttpAuthTokenApi(
        supabaseUrl: 'https://x.supabase.co/',
        anonKey: 'anon',
        client: MockClient((req) async {
          seen = req;
          return http.Response(jsonEncode(sessionJson('b', 'new')), 200);
        }),
      );
      final s = await api.refresh('old');
      expect(seen.url.toString(), 'https://x.supabase.co/auth/v1/token?grant_type=refresh_token');
      expect(seen.headers['apikey'], 'anon');
      expect(jsonDecode(seen.body), {'refresh_token': 'old'});
      expect(s.user.id, 'b');
      expect(s.refreshToken, 'new');
    });

    test('400 means the saved session is gone', () async {
      final api = HttpAuthTokenApi(
        supabaseUrl: 'https://x.supabase.co',
        anonKey: 'anon',
        client: MockClient((_) async => http.Response(
              jsonEncode({'code': 400, 'error_code': 'refresh_token_not_found'}),
              400,
            )),
      );
      await expectLater(
        api.refresh('old'),
        throwsA(isA<SavedSessionExpired>().having((e) => e.code, 'code', 'refresh_token_not_found')),
      );
    });

    test('5xx, 429 and network errors are retryable', () async {
      for (final client in [
        MockClient((_) async => http.Response('oops', 503)),
        MockClient((_) async => http.Response('slow down', 429)),
        MockClient((_) async => throw http.ClientException('offline')),
      ]) {
        final api = HttpAuthTokenApi(supabaseUrl: 'https://x.supabase.co', anonKey: 'anon', client: client);
        await expectLater(api.refresh('old'), throwsA(isA<AccountSwitchUnavailable>()));
      }
    });

    test('revoke ends only this session (scope local) and never throws', () async {
      late http.Request seen;
      final api = HttpAuthTokenApi(
        supabaseUrl: 'https://x.supabase.co',
        anonKey: 'anon',
        client: MockClient((req) async {
          seen = req;
          throw http.ClientException('offline');
        }),
      );
      await api.revoke('acc');
      expect(seen.url.toString(), 'https://x.supabase.co/auth/v1/logout?scope=local');
      expect(seen.headers['Authorization'], 'Bearer acc');
    });
  });

  group('Account switch – password sign-in API', () {
    test('posts to the password grant and maps rejected credentials to AuthException', () async {
      late http.Request seen;
      final api = HttpAuthTokenApi(
        supabaseUrl: 'https://x.supabase.co',
        anonKey: 'anon',
        client: MockClient((req) async {
          seen = req;
          return http.Response(
            jsonEncode({'code': 400, 'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'}),
            400,
          );
        }),
      );
      await expectLater(
        api.signInWithPassword(' b@test.de ', 'pw'),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', 'invalid_credentials')),
      );
      expect(seen.url.toString(), 'https://x.supabase.co/auth/v1/token?grant_type=password');
      expect(jsonDecode(seen.body), {'email': 'b@test.de', 'password': 'pw'});
    });

    test('offline is retryable', () async {
      final api = HttpAuthTokenApi(
        supabaseUrl: 'https://x.supabase.co',
        anonKey: 'anon',
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await expectLater(api.signInWithPassword('b@test.de', 'pw'), throwsA(isA<AccountSwitchUnavailable>()));
    });
  });

  group('Account switch – session generation of the real auth adapter', () {
    String jwt(String sub) {
      String b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
      final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': sub, 'exp': exp})}.sig';
    }

    String sessionJson(String user, String refresh) => jsonEncode({
          'access_token': jwt(user),
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': refresh,
          'user': _user(user).toJson(),
        });

    test('counts account changes and sign-outs, not refreshes of the same account', () async {
      final client = GoTrueClient(url: 'http://localhost:1/auth/v1', autoRefreshToken: false);
      final auth = SupabaseAccountSwitchAuth(client);
      Future<void> settleEvents() => Future<void>.delayed(Duration.zero);

      expect(auth.sessionGeneration, 0);
      await client.recoverSession(sessionJson('a', 'ra1'));
      await settleEvents();
      final afterA = auth.sessionGeneration;
      expect(afterA, greaterThan(0));

      // Same account, new tokens (refresh): no new generation.
      await client.recoverSession(sessionJson('a', 'ra2'));
      await settleEvents();
      expect(auth.sessionGeneration, afterA);

      // Other account activated: new generation.
      await client.recoverSession(sessionJson('b', 'rb1'));
      await settleEvents();
      expect(auth.sessionGeneration, afterA + 1);

      // The server call fails here (no server); the local sign-out and its
      // event happen before it.
      try {
        await client.signOut();
      } catch (_) {}
      await settleEvents();
      expect(auth.sessionGeneration, afterA + 2);

      // A new login of the same account B: new generation.
      await client.recoverSession(sessionJson('b', 'rb2'));
      await settleEvents();
      final afterB = auth.sessionGeneration;
      await client.recoverSession(sessionJson('b', 'rb3')); // refresh: same
      await settleEvents();
      expect(auth.sessionGeneration, afterB);
      auth.dispose();
      client.dispose();
    });
  });

  group('Account switch – sign-in while the switch mark is written (real client)', () {
    test('the sign-in wins, the switch is superseded', () async {
      String jwt(String sub) {
        String b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
        final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
        return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': sub, 'exp': exp})}.sig';
      }

      String sessionJson(String user, String refresh) => jsonEncode({
            'access_token': jwt(user),
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': refresh,
            'user': _user(user).toJson(),
          });

      final client = GoTrueClient(url: 'http://localhost:1/auth/v1', autoRefreshToken: false);
      final stamps = _DelayedSwitchStamp();
      final auth = SupabaseAccountSwitchAuth(client, stamps: stamps);
      await client.recoverSession(sessionJson('a', 'ra1'));
      await Future<void>.delayed(Duration.zero);

      final switching = auth.activate(Session.fromJson(jsonDecode(sessionJson('b', 'rb1')))!, leftUserId: 'a');
      // Someone signs in as C while the mark is still being written.
      await client.recoverSession(sessionJson('c', 'rc1'));
      await Future<void>.delayed(Duration.zero);
      stamps.release.complete();

      await expectLater(switching, throwsA(isA<AccountSwitchSuperseded>()));
      expect(client.currentSession?.user.id, 'c');
      auth.dispose();
      client.dispose();
    });
  });

  group('Account switch – new login of the same account (real client)', () {
    test('SIGNED_IN of the same account starts a new generation', () async {
      String jwt(String sub) {
        String b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
        final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
        return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': sub, 'exp': exp})}.sig';
      }

      var n = 0;
      final client = GoTrueClient(
        url: 'http://auth.test/auth/v1',
        autoRefreshToken: false,
        httpClient: MockClient((req) async {
          n++;
          return http.Response(
            jsonEncode({
              'access_token': jwt('a'),
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'ra$n',
              'user': _user('a').toJson(),
            }),
            200,
          );
        }),
      );
      final auth = SupabaseAccountSwitchAuth(client);
      await client.signInWithPassword(email: 'a@test.de', password: 'pw');
      await Future<void>.delayed(Duration.zero);
      final first = auth.sessionGeneration;
      await client.signInWithPassword(email: 'a@test.de', password: 'pw');
      await Future<void>.delayed(Duration.zero);
      expect(auth.sessionGeneration, first + 1);
      auth.dispose();
      client.dispose();
    });
  });

  group('Account switch – late refresh from another tab', () {
    late StreamController<AuthState> events;
    late List<String> reactivated;

    late InMemorySwitchStamp stamps;

    StaleRefreshGuard guard({Duration window = const Duration(seconds: 90)}) => StaleRefreshGuard(
          events: events.stream,
          leftUserId: 'a',
          target: _session('b', 'rb1'),
          reactivate: (s) async => reactivated.add(s.refreshToken!),
          stamps: stamps,
          stamp: stamps.value ?? 's0',
          window: window,
        );

    setUp(() {
      events = StreamController<AuthState>.broadcast(sync: true);
      reactivated = [];
      stamps = InMemorySwitchStamp()..value = 's0';
    });
    tearDown(() => events.close());

    test('a broadcast refresh of the left account brings back the newest session of B', () async {
      final g = guard();
      events.add(AuthState(AuthChangeEvent.tokenRefreshed, _session('b', 'rb2')));
      events.add(AuthState(AuthChangeEvent.tokenRefreshed, _session('a', 'ra9'), fromBroadcast: true));
      await pumpEventQueue();
      expect(reactivated, ['rb2']);
      g.cancel();
    });

    test('a refresh of A in this tab (not broadcast) is left alone', () {
      final g = guard();
      events.add(AuthState(AuthChangeEvent.tokenRefreshed, _session('a', 'ra9')));
      expect(reactivated, isEmpty);
      g.cancel();
    });

    test('a sign-in or sign-out ends the guard', () {
      final g = guard();
      events.add(AuthState(AuthChangeEvent.signedIn, _session('a', 'ra9'), fromBroadcast: true));
      events.add(AuthState(AuthChangeEvent.tokenRefreshed, _session('a', 'ra10'), fromBroadcast: true));
      expect(reactivated, isEmpty);
      expect(g.isActive, isFalse);
    });

    test('the guard ends after its window', () async {
      final g = guard(window: const Duration(milliseconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      events.add(AuthState(AuthChangeEvent.tokenRefreshed, _session('a', 'ra9'), fromBroadcast: true));
      expect(reactivated, isEmpty);
      expect(g.isActive, isFalse);
    });

    test('a newer switch in another tab ends the guard instead of switching back', () async {
      // Tab 1 switched A→B (stamp s0). Tab 2 now switches B→A: it records
      // a new stamp first, then its activation reaches tab 1 as a broadcast
      // TOKEN_REFRESHED of A.
      final g = guard();
      await stamps.next();
      events.add(AuthState(AuthChangeEvent.tokenRefreshed, _session('a', 'ra9'), fromBroadcast: true));
      await pumpEventQueue();
      expect(reactivated, isEmpty);
      expect(g.isActive, isFalse);
    });

    test('two tabs switching A→B and B→A do not ping-pong', () async {
      // One broadcast channel, one shared stamp (localStorage), two tabs.
      final channel = StreamController<(int, AuthState)>.broadcast(sync: true);
      final shared = InMemorySwitchStamp();
      final active = <int, String>{1: 'a', 2: 'b'};
      final switches = <String>[];
      final guards = <int, StaleRefreshGuard>{};

      // What a tab sees: its own changes locally, the other tab's as broadcast.
      Stream<AuthState> eventsOf(int tab) => channel.stream.map((e) {
            final (from, state) = e;
            return from == tab ? state : AuthState(state.event, state.session, fromBroadcast: true);
          });
      void apply(int from, Session s) {
        active[1] = s.user.id;
        active[2] = s.user.id;
        channel.add((from, AuthState(AuthChangeEvent.tokenRefreshed, s)));
      }

      Future<void> switchTab(int tab, String left, Session target) async {
        guards[tab]?.cancel();
        final stamp = await shared.next();
        apply(tab, target);
        switches.add('$tab→${target.user.id}');
        guards[tab] = StaleRefreshGuard(
          events: eventsOf(tab),
          leftUserId: left,
          target: target,
          stamps: shared,
          stamp: stamp,
          reactivate: (s) async {
            switches.add('guard$tab→${s.user.id}');
            apply(tab, s);
          },
        );
      }

      await switchTab(1, 'a', _session('b', 'rb1'));
      await switchTab(2, 'b', _session('a', 'ra1'));
      await pumpEventQueue();

      expect(switches, ['1→b', '2→a']);
      expect(active, {1: 'a', 2: 'a'});
      expect(guards[1]!.isActive, isFalse);
      for (final g in guards.values) {
        g.cancel();
      }
      await channel.close();
    });

    test('the service tells the adapter which account was left', () async {
      build(
        current: _session('a', 'ra1'),
        saved: const [SavedAccount(userId: 'b', email: 'b@test.de', refreshToken: 'rb1')],
      );
      api.valid['rb1'] = 'b';
      await service.switchTo('b');
      expect(auth.leftUsers, ['a']);
    });
  });

  group('Account switch – other tabs', () {
    test('a broadcast change to another account is followed', () {
      expect(followsOtherTab('a', AuthState(AuthChangeEvent.tokenRefreshed, _session('b', 'rb1'), fromBroadcast: true)), isTrue);
      expect(followsOtherTab('a', AuthState(AuthChangeEvent.signedIn, _session('b', 'rb1'), fromBroadcast: true)), isTrue);
    });

    test('own changes, refreshes of the same account and first sign-ins are not', () {
      expect(followsOtherTab('a', AuthState(AuthChangeEvent.tokenRefreshed, _session('b', 'rb1'))), isFalse);
      expect(followsOtherTab('a', AuthState(AuthChangeEvent.tokenRefreshed, _session('a', 'ra2'), fromBroadcast: true)), isFalse);
      expect(followsOtherTab(null, AuthState(AuthChangeEvent.signedIn, _session('b', 'rb1'), fromBroadcast: true)), isFalse);
    });

    test('a password recovery of another account keeps its own flow', () {
      expect(
        followsOtherTab('a', AuthState(AuthChangeEvent.passwordRecovery, _session('b', 'rb1'), fromBroadcast: true)),
        isFalse,
      );
    });

    test('following clears the group, then opens the group selection', () async {
      final steps = <String>[];
      final navigated = await followAccountChange(
        userId: 'b',
        generation: () => 1,
        currentUserId: () => 'b',
        clearTenant: () async => steps.add('clear'),
        navigate: () => steps.add('go'),
      );
      expect(navigated, isTrue);
      expect(steps, ['clear', 'go']);
    });

    test('a newer change while the group is cleared stops the navigation', () async {
      var gen = 1;
      String? user = 'b';
      final steps = <String>[];
      final navigated = await followAccountChange(
        userId: 'b',
        generation: () => gen,
        currentUserId: () => user,
        clearTenant: () async {
          steps.add('clear');
          // Meanwhile: sign-in as C (or a new login of B).
          gen = 2;
          user = 'c';
        },
        navigate: () => steps.add('go'),
      );
      expect(navigated, isFalse);
      expect(steps, ['clear']);

      gen = 1;
      user = 'b';
      final sameUserNewLogin = await followAccountChange(
        userId: 'b',
        generation: () => gen,
        currentUserId: () => user,
        clearTenant: () async => gen = 2,
        navigate: () => steps.add('go'),
      );
      expect(sameUserNewLogin, isFalse);
      expect(steps, ['clear']);
    });
  });

  group('Account switch – storage format', () {
    test('round trip and damaged data', () {
      final list = [
        SavedAccount(
          userId: 'a',
          email: 'a@test.de',
          refreshToken: 'ra',
          name: 'Anna',
          label: 'Spieler · SO',
          lastUsedAt: DateTime.utc(2026, 11, 1),
        ),
        const SavedAccount(userId: 'b', email: 'b@test.de'),
      ];
      expect(decodeSavedAccounts(encodeSavedAccounts(list)), list);
      expect(decodeSavedAccounts('not json'), isEmpty);
      expect(decodeSavedAccounts('[{"email":"x"}, 3, {"userId":"c","email":"c@x.de"}]').single.userId, 'c');
      expect(decodeSavedAccounts(null), isEmpty);
    });
  });
}

class _DelayedSwitchStamp implements SwitchStamp {
  final release = Completer<void>();

  @override
  Future<String> next() async {
    await release.future;
    return 's1';
  }

  @override
  Future<String?> current() async => 's1';
}
