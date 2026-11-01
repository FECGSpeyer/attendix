import 'dart:convert';

import 'package:attendix/core/services/account_switch/account_switch_service.dart';
import 'package:attendix/core/services/account_switch/auth_token_api.dart';
import 'package:attendix/core/services/account_switch/saved_accounts_store.dart';
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

  @override
  Future<void> activate(Session session) async {
    log.add('activate:${session.user.id}');
    currentSession = session;
  }

  @override
  void pauseAutoRefresh() => log.add('pause');

  @override
  void resumeAutoRefresh() => log.add('resume');

  /// Simulates a refresh of the current session that was already running.
  Session? pendingRefresh;

  @override
  Future<void> settle() async {
    log.add('settle');
    final pending = pendingRefresh;
    if (pending != null) {
      pendingRefresh = null;
      currentSession = pending;
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
          auth.currentSession = _session('c', 'rc1'); // login page
        }),
        throwsA(isA<AccountSwitchSuperseded>()),
      );
      expect(auth.currentSession?.user.id, 'c');
      // B's rotated token is not lost.
      expect(tokenOf('b'), 'rb1+');
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
