import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// ACCOUNT_SWITCH: the saved session of an account cannot be used any more
/// (signed out elsewhere, password changed, token revoked) – the account
/// needs a normal login.
class SavedSessionExpired implements Exception {
  const SavedSessionExpired([this.code]);
  final String? code;
  @override
  String toString() => 'SavedSessionExpired($code)';
}

/// ACCOUNT_SWITCH: the auth server could not be reached (offline, 5xx,
/// rate limit). Nothing changed, the switch can be tried again.
class AccountSwitchUnavailable implements Exception {
  const AccountSwitchUnavailable([this.cause]);
  final Object? cause;
  @override
  String toString() => 'AccountSwitchUnavailable($cause)';
}

/// Token calls for accounts that are NOT the signed-in one.
///
/// They go straight to the GoTrue REST API instead of through a second
/// `GoTrueClient`: in the browser every GoTrueClient of the project joins
/// the same BroadcastChannel, so a second client's events (new session,
/// sign-out after a failed refresh) would also switch or sign out the
/// app's own client.
abstract class AuthTokenApi {
  /// Exchanges [refreshToken] for a new session (the token is used up).
  Future<Session> refresh(String refreshToken);

  /// Ends the session of [accessToken] on the server (scope local: only this
  /// device's session of that account).
  Future<void> revoke(String accessToken);
}

class HttpAuthTokenApi implements AuthTokenApi {
  HttpAuthTokenApi({
    required String supabaseUrl,
    required String anonKey,
    http.Client? client,
  })  : _authUrl = '${supabaseUrl.replaceAll(RegExp(r'/+$'), '')}/auth/v1',
        _anonKey = anonKey,
        _client = client ?? http.Client();

  final String _authUrl;
  final String _anonKey;
  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  @override
  Future<Session> refresh(String refreshToken) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$_authUrl/token?grant_type=refresh_token'),
            headers: {
              'apikey': _anonKey,
              'Authorization': 'Bearer $_anonKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(_timeout);
    } catch (e) {
      throw AccountSwitchUnavailable(e);
    }
    final body = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && body != null) {
      final session = Session.fromJson(body);
      if (session != null && (session.refreshToken ?? '').isNotEmpty) {
        return session;
      }
      throw const AccountSwitchUnavailable('no session in response');
    }
    if (res.statusCode == 429 || res.statusCode >= 500) {
      throw AccountSwitchUnavailable('HTTP ${res.statusCode}');
    }
    // 400/401/403/404: refresh token unknown, used up or revoked.
    final code = body?['error_code'] ?? body?['error'];
    throw SavedSessionExpired(code is String ? code : 'HTTP ${res.statusCode}');
  }

  @override
  Future<void> revoke(String accessToken) async {
    try {
      await _client
          .post(
            Uri.parse('$_authUrl/logout?scope=local'),
            headers: {
              'apikey': _anonKey,
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(_timeout);
    } catch (_) {
      // Best effort: the local entry is removed anyway.
    }
  }

  static Map<String, dynamic>? _decode(String body) {
    try {
      final json = jsonDecode(body);
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }
}
