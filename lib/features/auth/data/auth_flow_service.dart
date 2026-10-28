import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../l10n/l10n.dart';

/// AUTH: E-Mail/Passwort- und Code-Login-Flows (Ionic `db.service.ts`
/// login / sendEmailOtp / verifyEmailOtp / resendConfirmationEmail /
/// updatePassword / resetPassword und `app.component.ts#handleAuthUrl`).
///
/// NOTE (Multi-Tenant): reine Auth-Operationen des aktuellen Benutzers
/// (Supabase Auth), keine Tenant-Daten → kein tenantId-Filter.

/// Ionic `Utils.validateEmail`.
final RegExp _emailRegExp = RegExp(
  r'^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
);

/// Ionic `Utils.validateEmail`.
bool isValidEmail(String? email) =>
    email != null && _emailRegExp.hasMatch(email.trim());

/// Ionic `Utils.validatePhoneNumber`.
bool isValidPhoneNumber(String? phone) =>
    phone != null && RegExp(r'^(\+?[1-9]\d{1,14}|0\d+)$').hasMatch(phone);

/// Cooldown (Sekunden) für "Code erneut senden" (Ionic startResendCooldown).
const int kOtpResendCooldownSeconds = 30;

/// Länge des E-Mail-Codes (Ionic ion-input-otp length="6").
const int kOtpLength = 6;

/// Base URL used in auth e-mail redirects (Ionic uses https://attendix.de).
String authRedirectBase() {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.startsWith('http')) return origin;
  }
  return 'https://attendix.de';
}

/// Kind of login failure, decides which follow-up dialog the login page shows.
enum LoginFailureKind {
  /// E-Mail noch nicht bestätigt → "Erneut senden"-Dialog.
  emailNotConfirmed,

  /// Falsches Passwort → Hinweis auf Code-Login.
  invalidCredentials,

  /// Kein Konto → "jetzt registrieren?"-Dialog.
  userNotFound,

  /// Sonstiger Fehler (nur Meldung).
  other,
}

/// Result of a password login attempt.
class LoginFailure implements Exception {
  const LoginFailure(this.kind, this.message);

  final LoginFailureKind kind;

  /// German message (Ionic db.login toast); null when the page shows a
  /// dialog instead (email_not_confirmed).
  final String? message;

  @override
  String toString() => message ?? kind.name;
}

/// Ionic `db.login` error switch.
LoginFailure mapLoginError(AuthException e) {
  final code = e.code ?? _codeFromMessage(e.message);
  switch (code) {
    case 'invalid_login_credentials':
    case 'invalid_credentials':
      return LoginFailure(
        LoginFailureKind.invalidCredentials,
        l10nWithoutContext.dbWrongCredentials,
      );
    case 'user_disabled':
    case 'user_banned':
      return LoginFailure(
        LoginFailureKind.other,
        l10nWithoutContext.dbAccountDisabled,
      );
    case 'too_many_requests':
    case 'over_request_rate_limit':
      return LoginFailure(
        LoginFailureKind.other,
        l10nWithoutContext.dbTooManyLogins,
      );
    case 'invalid_email':
    case 'email_address_invalid':
      return LoginFailure(
          LoginFailureKind.other, l10nWithoutContext.dbInvalidEmail);
    case 'invalid_password':
      return LoginFailure(LoginFailureKind.other, l10nWithoutContext.dbInvalidPassword);
    case 'user_not_found':
      return LoginFailure(
        LoginFailureKind.userNotFound,
        l10nWithoutContext.dbNoAccount,
      );
    case 'email_not_confirmed':
      return const LoginFailure(LoginFailureKind.emailNotConfirmed, null);
    case 'password_strength_insufficient':
    case 'weak_password':
      return LoginFailure(
        LoginFailureKind.other,
        l10nWithoutContext.dbWeakPasswordRequirements,
      );
    default:
      return LoginFailure(LoginFailureKind.other, l10nWithoutContext.dbLoginFailed);
  }
}

/// Older GoTrue versions return no `code` — derive it from the message.
String? _codeFromMessage(String message) {
  final m = message.toLowerCase();
  if (m.contains('invalid login credentials')) return 'invalid_credentials';
  if (m.contains('email not confirmed')) return 'email_not_confirmed';
  if (m.contains('user not found')) return 'user_not_found';
  if (m.contains('banned')) return 'user_banned';
  if (m.contains('rate limit') || m.contains('too many')) {
    return 'too_many_requests';
  }
  if (m.contains('signups not allowed for otp')) return 'otp_disabled';
  if (m.contains('token has expired')) return 'otp_expired';
  return null;
}

/// Result of a passwordless code request / verification.
class OtpResult {
  const OtpResult._(this.success, this.message, {this.noAccount = false});

  const OtpResult.ok(String message) : this._(true, message);
  const OtpResult.failed(String message, {bool noAccount = false})
      : this._(false, message, noAccount: noAccount);

  final bool success;
  final String message;

  /// Sign-in-only surface and no account exists (Ionic: promptRegister).
  final bool noAccount;
}

/// Ionic `db.sendEmailOtp` error switch.
OtpResult mapSendOtpError(AuthException e, {required bool allowCreate}) {
  final noAccount = OtpResult.failed(
    l10nWithoutContext.dbNoAccount,
    noAccount: true,
  );
  final code = e.code ?? _codeFromMessage(e.message);
  switch (code) {
    case 'over_email_send_rate_limit':
    case 'too_many_requests':
      return OtpResult.failed(
          l10nWithoutContext.dbTooManyRequests);
    case 'invalid_email':
    case 'email_address_invalid':
      return OtpResult.failed(l10nWithoutContext.dbInvalidEmail);
    case 'signup_disabled':
    case 'otp_disabled':
      if (!allowCreate) return noAccount;
      return OtpResult.failed(
          l10nWithoutContext.dbOtpUnavailable);
    case 'user_not_found':
      return noAccount;
    default:
      if (!allowCreate) return noAccount;
      return OtpResult.failed(
          l10nWithoutContext.dbCodeSendFailed);
  }
}

/// Ionic `db.verifyEmailOtp` error switch.
String mapVerifyOtpError(AuthException e) {
  final code = e.code ?? _codeFromMessage(e.message);
  switch (code) {
    case 'otp_expired':
      return l10nWithoutContext.dbCodeExpired;
    case 'too_many_requests':
    case 'over_request_rate_limit':
      return l10nWithoutContext.dbTooManyAttempts;
    default:
      return l10nWithoutContext.dbCodeInvalid;
  }
}

/// Ionic `db.updatePassword` error switch.
String mapUpdatePasswordError(AuthException? e) {
  switch (e?.code) {
    case 'same_password':
      return l10nWithoutContext.dbPasswordSameAsOld;
    case 'weak_password':
    case 'password_strength_insufficient':
      return l10nWithoutContext.dbPasswordTooWeak;
    case 'over_request_rate_limit':
    case 'too_many_requests':
      return l10nWithoutContext.dbTooManyAttemptsWait;
    case 'session_not_found':
    case 'session_expired':
      return l10nWithoutContext.dbSessionExpired;
    default:
      return l10nWithoutContext.dbPasswordChangeFailed;
  }
}

/// Parsed Supabase auth link (password recovery / signup confirmation).
///
/// Mirrors Ionic `app.component.ts#handleAuthUrl`:
///   Token-hash: `?token_hash=...&type=recovery|signup`
///   PKCE:       `?code=...`
///   Implicit:   `#access_token=...&refresh_token=...&type=...`
class AuthLink {
  const AuthLink({
    this.type,
    this.tokenHash,
    this.code,
    this.accessToken,
    this.refreshToken,
    this.errorDescription,
    this.path = '',
  });

  final String? type;
  final String? tokenHash;
  final String? code;
  final String? accessToken;
  final String? refreshToken;
  final String? errorDescription;
  final String path;

  /// Parses query and fragment of [uri]. With the hash URL strategy the
  /// fragment can itself contain a route plus query (`#/login?type=...`).
  factory AuthLink.parse(Uri uri) {
    final params = <String, String>{...uri.queryParameters};
    var fragment = uri.fragment;
    if (fragment.isNotEmpty) {
      final q = fragment.indexOf('?');
      if (fragment.startsWith('/') && q >= 0) {
        fragment = fragment.substring(q + 1);
      } else if (fragment.startsWith('/')) {
        fragment = '';
      }
      if (fragment.contains('=')) {
        try {
          for (final entry in Uri.splitQueryString(fragment).entries) {
            params.putIfAbsent(entry.key, () => entry.value);
          }
        } catch (_) {
          // Malformed fragment – ignore.
        }
      }
    }
    String? get(String k) {
      final v = params[k];
      return (v == null || v.isEmpty) ? null : v;
    }

    return AuthLink(
      type: get('type'),
      tokenHash: get('token_hash'),
      code: get('code'),
      accessToken: get('access_token'),
      refreshToken: get('refresh_token'),
      errorDescription: get('error_description'),
      path: uri.path + (uri.fragment.startsWith('/') ? uri.fragment : ''),
    );
  }

  bool get _hasCredential => code != null || tokenHash != null;

  /// `type` is authoritative; the path is only a fallback for legacy links.
  bool get isRecovery =>
      type == 'recovery' ||
      (type == null && _hasCredential && path.contains('resetPassword'));

  bool get isSignupConfirm =>
      type == 'signup' || (_hasCredential && !isRecovery);

  /// Used to pick the error text ("Link zum Zurücksetzen" vs. "Bestätigungslink").
  bool get looksLikeRecovery =>
      isRecovery || type == 'recovery' || path.contains('resetPassword');

  /// Whether this URL is an auth link at all.
  bool get isAuthLink =>
      (isRecovery || isSignupConfirm) ||
      (errorDescription != null && (type != null || path.contains('reset')));
}

/// Maps the link's `type` parameter to the [OtpType] for `verifyOTP`
/// (invite / magiclink / email_change links must not be verified as signup).
OtpType otpTypeForLink(AuthLink link) {
  switch (link.type) {
    case 'recovery':
      return OtpType.recovery;
    case 'invite':
      return OtpType.invite;
    case 'magiclink':
      return OtpType.magiclink;
    case 'email_change':
      return OtpType.emailChange;
    case 'email':
      return OtpType.email;
    case 'signup':
      return OtpType.signup;
    default:
      return link.isRecovery ? OtpType.recovery : OtpType.signup;
  }
}

/// Outcome of processing an [AuthLink].
enum AuthLinkOutcome { none, recovery, signupConfirmed, failed }

/// Service with the Ionic auth flows.
class AuthFlowService {
  AuthFlowService(this._auth);

  final GoTrueClient _auth;

  /// Password login. Throws [LoginFailure].
  Future<User> signInWithPassword(String email, String password) async {
    try {
      final res = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw LoginFailure(
            LoginFailureKind.other, l10nWithoutContext.dbEnterCorrectData);
      }
      return user;
    } on AuthException catch (e) {
      throw mapLoginError(e);
    }
  }

  /// Request a 6-digit code by e-mail. [allowCreate] = `shouldCreateUser`
  /// (true on registration surfaces, false on the login page).
  Future<OtpResult> sendEmailOtp(String email, {required bool allowCreate}) async {
    try {
      await _auth.signInWithOtp(
        email: email.trim().toLowerCase(),
        shouldCreateUser: allowCreate,
        // Flags OTP registrations so the "Confirm signup" template shows the
        // code instead of the link (Ionic).
        data: allowCreate
            ? {
                'signup_method': 'otp',
                AccountRepository.termsAcceptedAtKey:
                    DateTime.now().toUtc().toIso8601String(),
              }
            : null,
      );
      return OtpResult.ok(l10nWithoutContext.dbCodeSent);
    } on AuthException catch (e) {
      return mapSendOtpError(e, allowCreate: allowCreate);
    } catch (_) {
      return OtpResult.failed(
          l10nWithoutContext.dbCodeSendFailed);
    }
  }

  /// Verify the code. Tries type `email` first, then `signup` (new users).
  Future<OtpResult> verifyEmailOtp(String email, String code) async {
    final token = code.trim();
    final normalized = email.trim().toLowerCase();
    try {
      await _auth.verifyOTP(email: normalized, token: token, type: OtpType.email);
      return const OtpResult.ok('');
    } on AuthException catch (e) {
      final c = e.code ?? _codeFromMessage(e.message);
      if (c == 'otp_expired' || c == 'too_many_requests') {
        return OtpResult.failed(mapVerifyOtpError(e));
      }
      try {
        await _auth.verifyOTP(
            email: normalized, token: token, type: OtpType.signup);
        return const OtpResult.ok('');
      } on AuthException catch (e2) {
        return OtpResult.failed(mapVerifyOtpError(e2));
      }
    } catch (_) {
      return OtpResult.failed(
          l10nWithoutContext.dbCodeInvalid);
    }
  }

  /// Stamp terms acceptance after an OTP registration (Ionic).
  Future<void> stampTermsAccepted() async {
    try {
      await _auth.updateUser(UserAttributes(data: {
        AccountRepository.termsAcceptedAtKey:
            DateTime.now().toUtc().toIso8601String(),
      }));
    } catch (e) {
      debugPrint('stampTermsAccepted failed: $e');
    }
  }

  /// Ionic `auth.resendConfirmationEmail`. Returns the toast message and
  /// whether it succeeded.
  Future<(bool, String)> resendConfirmationEmail(String email) async {
    try {
      await _auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: '${authRedirectBase()}/login',
      );
      return (true, l10nWithoutContext.authConfirmationResent);
    } catch (_) {
      return (false, l10nWithoutContext.authResendConfirmationFailed);
    }
  }

  /// Ionic `auth.resetPassword`.
  Future<(bool, String)> resetPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: '${authRedirectBase()}/resetPassword',
      );
      return (true, l10nWithoutContext.authResetSent);
    } catch (_) {
      return (false, l10nWithoutContext.authResetFailed);
    }
  }

  /// Ionic `db.updatePassword` → (success, message).
  Future<(bool, String)> updatePassword(String password) async {
    try {
      final res = await _auth.updateUser(UserAttributes(password: password));
      if (res.user != null) {
        return (true, l10nWithoutContext.dbPasswordUpdated);
      }
      return (false, mapUpdatePasswordError(null));
    } on AuthException catch (e) {
      return (false, mapUpdatePasswordError(e));
    } catch (_) {
      return (false, mapUpdatePasswordError(null));
    }
  }

  Future<void> _waitForSession(Duration timeout) async {
    if (_auth.currentSession != null) return;
    try {
      await _auth.onAuthStateChange
          .firstWhere((state) => state.session != null)
          .timeout(timeout);
    } catch (_) {
      // Timeout or stream error – caller falls back to its own exchange.
    }
  }

  /// Process an auth deep link (Ionic `handleAuthUrl`).
  ///
  /// supabase_flutter may already have consumed `?code=` / `#access_token`
  /// (detectSessionInUri); in that case an existing session counts as success.
  Future<AuthLinkOutcome> handleAuthLink(AuthLink link) async {
    if (!link.isAuthLink) return AuthLinkOutcome.none;
    if (link.errorDescription != null) return AuthLinkOutcome.failed;

    try {
      if (link.tokenHash != null) {
        await _auth.verifyOTP(
          tokenHash: link.tokenHash,
          type: otpTypeForLink(link),
        );
      } else if (_auth.currentSession == null) {
        // supabase_flutter (detectSessionInUri) may still be exchanging the
        // code/token itself – give it a moment before doing it ourselves.
        await _waitForSession(const Duration(seconds: 4));
      }
      if (link.tokenHash == null && _auth.currentSession == null) {
        if (link.accessToken != null && link.refreshToken != null) {
          await _auth.setSession(link.refreshToken!);
        } else if (link.code != null) {
          await _auth.exchangeCodeForSession(link.code!);
        }
      }
      if (_auth.currentSession == null) return AuthLinkOutcome.failed;
      return link.isRecovery
          ? AuthLinkOutcome.recovery
          : AuthLinkOutcome.signupConfirmed;
    } catch (e) {
      debugPrint('[handleAuthLink] failed: $e');
      // A code may already have been exchanged by supabase_flutter.
      if (link.tokenHash == null && _auth.currentSession != null) {
        return link.isRecovery
            ? AuthLinkOutcome.recovery
            : AuthLinkOutcome.signupConfirmed;
      }
      return AuthLinkOutcome.failed;
    }
  }
}

/// Provider for [AuthFlowService].
final authFlowServiceProvider = Provider<AuthFlowService>((ref) {
  return AuthFlowService(ref.watch(supabaseAuthProvider));
});
