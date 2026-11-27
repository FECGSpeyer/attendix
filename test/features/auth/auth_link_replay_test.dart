import 'dart:convert';

import 'package:attendix/features/auth/data/auth_flow_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryPkce extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

Map<String, dynamic> userJson() => {
  'id': 'audit-user-a',
  'aud': 'authenticated',
  'created_at': '2026-01-01T00:00:00Z',
  'email': 'audit@example.invalid',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
};

String fakeJwt() {
  String part(Object data) =>
      base64UrlEncode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'sub': 'audit-user-a', 'exp': 4102444800})}.local-fake';
}

void main() {
  // This uses the ACTUAL GoTrue client and ACTUAL replaying auth stream, not a mock stream.
  for (final event in [
    AuthChangeEvent.passwordRecovery,
    AuthChangeEvent.signedIn,
  ]) {
    test('an old $event replay cannot validate a later invalid PKCE link', () async {
      final storage = MemoryPkce();
      var requests = 0;
      final auth = GoTrueClient(
        url: 'http://127.0.0.1:1/auth/v1',
        autoRefreshToken: false,
        asyncStorage: storage,
        httpClient: MockClient((req) async {
          requests++;
          return http.Response(
            jsonEncode({
              'access_token': fakeJwt(),
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'local-fake-refresh',
              'user': userJson(),
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        }),
      );
      addTearDown(auth.dispose);
      storage.values['supabase.auth.token-code-verifier'] =
          'local-verifier/${event.name}';
      await auth.exchangeCodeForSession('valid-earlier-local-code');
      expect(requests, 1);
      expect(
        storage.values,
        isEmpty,
        reason: 'valid earlier link already consumed its PKCE verifier',
      );
      final code = AuthLink.parse(
        Uri.parse(
          event == AuthChangeEvent.passwordRecovery
              ? 'https://attendix.de/resetPassword?code=invalid-later-code&type=recovery'
              : 'https://attendix.de/login?code=invalid-later-code&type=signup',
        ),
      );
      await expectLater(
        auth.exchangeCodeForSession('invalid-later-code'),
        throwsA(isA<AuthException>()),
      );
      final outcome = await AuthFlowService(auth).handleAuthLink(code);
      expect(outcome, AuthLinkOutcome.failed);
      expect(
        requests,
        1,
        reason:
            'later link was never successfully exchanged, only the old auth event replayed',
      );
    });
  }
}
