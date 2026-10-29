import 'dart:async';

import 'package:attendix/features/auth/data/auth_flow_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../mocks/supabase_mocks.dart';

/// SOL_FIX12: an auth link only succeeds when THIS link was processed — an
/// existing session (account A signed in) never turns an invalid reset link
/// into the "Neues Passwort" form for A.
void main() {
  late MockGoTrueClient auth;
  late StreamController<AuthState> events;
  Session? current;

  Session session(String userId, [String token = 'token']) => Session(
        accessToken: '$token-$userId',
        tokenType: 'bearer',
        user: User(
          id: userId,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );

  AuthFlowService service() =>
      AuthFlowService(auth, linkProcessingTimeout: const Duration(milliseconds: 200));

  setUpAll(() {
    registerFallbackValue(OtpType.recovery);
  });

  setUp(() {
    auth = MockGoTrueClient();
    events = StreamController<AuthState>.broadcast();
    current = session('user-a');
    when(() => auth.currentSession).thenAnswer((_) => current);
    when(() => auth.currentUser).thenAnswer((_) => current?.user);
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
  });

  tearDown(() => events.close());

  final recoveryCode = AuthLink.parse(
      Uri.parse('https://attendix.de/resetPassword?code=bad&type=recovery'));

  test('invalid PKCE recovery link with A signed in fails', () async {
    when(() => auth.exchangeCodeForSession(any()))
        .thenThrow(AuthException('invalid code'));
    final outcome = await service().handleAuthLink(recoveryCode);
    expect(outcome, AuthLinkOutcome.failed);
  });

  test('a signedIn event of A is no recovery processing', () async {
    when(() => auth.exchangeCodeForSession(any()))
        .thenThrow(AuthException('Code verifier could not be found'));
    final future = service().handleAuthLink(recoveryCode);
    events.add(AuthState(AuthChangeEvent.signedIn, current));
    expect(await future, AuthLinkOutcome.failed);
  });

  test('recovery processed by supabase_flutter (passwordRecovery event) succeeds', () async {
    when(() => auth.exchangeCodeForSession(any()))
        .thenThrow(AuthException('Code verifier could not be found'));
    final future = service().handleAuthLink(recoveryCode);
    current = session('user-b');
    events.add(AuthState(AuthChangeEvent.passwordRecovery, current));
    expect(await future, AuthLinkOutcome.recovery);
  });

  test('own successful code exchange succeeds', () async {
    final b = session('user-b');
    when(() => auth.exchangeCodeForSession(any())).thenAnswer((_) async {
      current = b;
      return AuthSessionUrlResponse(session: b, redirectType: 'passwordRecovery');
    });
    expect(await service().handleAuthLink(recoveryCode), AuthLinkOutcome.recovery);
  });

  test('invalid token_hash recovery link with A signed in fails (catch path)', () async {
    when(() => auth.verifyOTP(
          tokenHash: any(named: 'tokenHash'),
          type: any(named: 'type'),
        )).thenThrow(AuthException('Token has expired or is invalid'));
    final link = AuthLink.parse(
        Uri.parse('https://attendix.de/resetPassword?token_hash=bad&type=recovery'));
    expect(await service().handleAuthLink(link), AuthLinkOutcome.failed);
  });

  test('invalid implicit recovery link with A signed in fails', () async {
    when(() => auth.setSession(any())).thenThrow(AuthException('Invalid Refresh Token'));
    final link = AuthLink.parse(Uri.parse(
        'https://attendix.de/resetPassword#access_token=x&refresh_token=y&type=recovery'));
    expect(await service().handleAuthLink(link), AuthLinkOutcome.failed);
  });

  test('implicit link already consumed into the current session succeeds', () async {
    current = session('user-b', 'x');
    final link = AuthLink.parse(Uri.parse(
        'https://attendix.de/resetPassword#access_token=x-user-b&refresh_token=y&type=recovery'));
    expect(await service().handleAuthLink(link), AuthLinkOutcome.recovery);
  });
}
