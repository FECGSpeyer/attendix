import 'package:attendix/features/auth/data/auth_flow_service.dart';
import 'package:attendix/features/registration/data/providers/registration_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AUTH package: Ionic login/OTP/deep-link parity (pure logic).
void main() {
  group('AuthLink.parse (Ionic handleAuthUrl)', () {
    test('token_hash recovery link', () {
      final link = AuthLink.parse(Uri.parse(
          'https://attendix.de/resetPassword?token_hash=abc&type=recovery'));
      expect(link.tokenHash, 'abc');
      expect(link.isRecovery, isTrue);
      expect(link.isSignupConfirm, isFalse);
      expect(link.isAuthLink, isTrue);
    });

    test('signup confirmation pointing to /resetPassword stays signup', () {
      final link = AuthLink.parse(Uri.parse(
          'https://attendix.de/resetPassword?token_hash=abc&type=signup'));
      expect(link.isRecovery, isFalse);
      expect(link.isSignupConfirm, isTrue);
    });

    test('legacy PKCE code on /resetPassword without type is recovery', () {
      final link =
          AuthLink.parse(Uri.parse('https://attendix.de/resetPassword?code=xyz'));
      expect(link.code, 'xyz');
      expect(link.isRecovery, isTrue);
    });

    test('PKCE code on /login is a signup confirmation', () {
      final link = AuthLink.parse(Uri.parse('https://attendix.de/login?code=xyz'));
      expect(link.isRecovery, isFalse);
      expect(link.isSignupConfirm, isTrue);
    });

    test('implicit fragment tokens', () {
      final link = AuthLink.parse(Uri.parse(
          'https://attendix.de/#access_token=a&refresh_token=r&type=recovery'));
      expect(link.accessToken, 'a');
      expect(link.refreshToken, 'r');
      expect(link.isRecovery, isTrue);
    });

    test('hash-routed query is parsed', () {
      final link = AuthLink.parse(
          Uri.parse('https://app.example/#/login?token_hash=t&type=signup'));
      expect(link.tokenHash, 't');
      expect(link.isSignupConfirm, isTrue);
    });

    test('normal app URL is no auth link', () {
      final link = AuthLink.parse(Uri.parse('https://attendix.de/#/people'));
      expect(link.isAuthLink, isFalse);
    });
  });

  group('Login error mapping (Ionic db.login)', () {
    test('wrong password suggests the code login', () {
      final f = mapLoginError(
          const AuthException('Invalid login credentials', code: 'invalid_credentials'));
      expect(f.kind, LoginFailureKind.invalidCredentials);
      expect(f.message, contains('Anmelde-Code per E-Mail'));
    });

    test('unconfirmed e-mail → resend dialog without toast', () {
      final f = mapLoginError(const AuthException('Email not confirmed'));
      expect(f.kind, LoginFailureKind.emailNotConfirmed);
      expect(f.message, isNull);
    });

    test('user not found → register prompt', () {
      final f = mapLoginError(
          const AuthException('x', code: 'user_not_found'));
      expect(f.kind, LoginFailureKind.userNotFound);
      expect(f.message, contains('Kein Konto'));
    });

    test('unknown → Fehler beim Anmelden', () {
      final f = mapLoginError(const AuthException('boom', code: 'weird'));
      expect(f.kind, LoginFailureKind.other);
      expect(f.message, 'Fehler beim Anmelden');
    });
  });

  group('OTP error mapping (Ionic sendEmailOtp / verifyEmailOtp)', () {
    test('sign-in only surface: disabled signup means no account', () {
      final r = mapSendOtpError(
          const AuthException('Signups not allowed for otp', code: 'otp_disabled'),
          allowCreate: false);
      expect(r.success, isFalse);
      expect(r.noAccount, isTrue);
    });

    test('registration surface: otp disabled message', () {
      final r = mapSendOtpError(
          const AuthException('x', code: 'otp_disabled'),
          allowCreate: true);
      expect(r.noAccount, isFalse);
      expect(r.message, 'Anmeldung per Code ist derzeit nicht möglich.');
    });

    test('rate limit', () {
      final r = mapSendOtpError(
          const AuthException('x', code: 'over_email_send_rate_limit'),
          allowCreate: true);
      expect(r.message, startsWith('Zu viele Anfragen'));
    });

    test('verify errors', () {
      expect(mapVerifyOtpError(const AuthException('x', code: 'otp_expired')),
          contains('abgelaufen'));
      expect(mapVerifyOtpError(const AuthException('x', code: 'nope')),
          contains('ungültig'));
    });

    test('update password errors', () {
      expect(mapUpdatePasswordError(const AuthException('x', code: 'same_password')),
          contains('nicht mit dem alten'));
      expect(mapUpdatePasswordError(null), contains('nicht geändert'));
    });
  });

  group('Validation helpers', () {
    test('isValidEmail (Ionic Utils.validateEmail)', () {
      expect(isValidEmail('max@example.de'), isTrue);
      expect(isValidEmail(' max@example.de '), isTrue);
      expect(isValidEmail('max@example'), isFalse);
      expect(isValidEmail('max'), isFalse);
      expect(isValidEmail(null), isFalse);
    });

    test('isValidPhoneNumber (Ionic Utils.validatePhoneNumber)', () {
      expect(isValidPhoneNumber('+491701234567'), isTrue);
      expect(isValidPhoneNumber('01701234567'), isTrue);
      expect(isValidPhoneNumber('abc'), isFalse);
    });
  });

  group('Tenant registration', () {
    test('four distinct success texts', () {
      final texts = {
        for (final auto in [true, false])
          for (final isNew in [true, false])
            RegistrationResult.successMessageFor(
                autoApproved: auto, isNewAccount: isNew),
      };
      expect(texts.length, 4);
      expect(
          RegistrationResult.successMessageFor(
              autoApproved: true, isNewAccount: false),
          contains('Du bist nun teil der Instanz'));
      expect(
          RegistrationResult.successMessageFor(
              autoApproved: false, isNewAccount: true),
          contains('wartet auf die Genehmigung'));
    });

    test('player row matches Ionic addPlayer fields', () {
      final data = buildRegistrationPlayerData(
        tenantId: 7,
        appId: 'uid',
        formData: RegistrationFormData(
          firstName: 'Max',
          lastName: 'Muster',
          groupId: 3,
          birthDate: DateTime(2000, 5, 4),
        ),
        email: 'max@example.de',
        pending: true,
        hasBirthDate: false,
        phone: '0170',
        todayIso: '2026-10-28T00:00:00.000Z',
      );
      expect(data['tenantId'], 7);
      expect(data['appId'], 'uid');
      expect(data['self_register'], isTrue);
      expect(data['pending'], isTrue);
      expect(data['instrument'], 3);
      expect(data['birthday'], isNull, reason: 'only when birthDate field');
      expect(data['correctBirthday'], isFalse);
      expect(data['joined'], '2026-10-28T00:00:00.000Z');
      expect(data['playsSince'], '2026-10-28T00:00:00.000Z');
      expect(data['history'], isEmpty);
    });
  });
}
