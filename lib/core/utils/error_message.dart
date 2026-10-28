import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthException,
        AuthRetryableFetchException,
        FunctionException,
        PostgrestException,
        StorageException;

import '../../data/repositories/base_repository.dart' show RepositoryException;
import '../../l10n/l10n.dart';

/// Turns any thrown object into a text that can be shown to users.
///
/// Raw exceptions (`ClientException: Failed to fetch, uri=http://…`,
/// `RepositoryException: … (operation: …)`) must never reach the UI. This:
/// - maps network failures (offline, blocked, DNS, timeouts) to the Ionic
///   text "Keine Internetverbindung vorhanden",
/// - unwraps [RepositoryException] / Supabase exceptions to their message,
/// - strips the `Exception: ` prefix of plain exceptions,
/// - falls back to "Unbekannter Fehler" for anything still technical.
String friendlyErrorMessage(Object? error, [AppLocalizations? l10n]) {
  final t = l10n ?? l10nWithoutContext;
  if (error == null) return t.commonUnknownError;
  if (isNetworkError(error)) return t.coreFlutterNoConnection;

  final String raw;
  if (error is RepositoryException) {
    final inner = error.originalError;
    if (inner != null && inner is! RepositoryException) {
      return friendlyErrorMessage(inner, t);
    }
    raw = error.message;
  } else if (error is PostgrestException) {
    raw = error.message;
  } else if (error is AuthException) {
    raw = error.message;
  } else if (error is StorageException) {
    raw = error.message;
  } else if (error is FunctionException) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      raw = details['error'] as String;
    } else if (details is String && details.isNotEmpty) {
      raw = details;
    } else {
      raw = error.reasonPhrase ?? '';
    }
  } else if (error is String) {
    raw = error;
  } else {
    raw = error.toString();
  }

  final cleaned = raw.replaceFirst(RegExp(r'^(Exception|Error):\s*'), '').trim();
  if (cleaned.isEmpty || _looksTechnical(cleaned)) return t.commonUnknownError;
  if (_networkPattern.hasMatch(cleaned)) return t.coreFlutterNoConnection;
  return cleaned;
}

/// Whether [error] is a connectivity problem (offline, blocked request,
/// DNS failure, timeout) rather than an application error.
bool isNetworkError(Object? error) {
  if (error == null) return false;
  if (error is RepositoryException) {
    return isNetworkError(error.originalError) ||
        _networkPattern.hasMatch(error.message);
  }
  if (error is http.ClientException) return true;
  if (error is TimeoutException) return true;
  if (error is AuthRetryableFetchException) return true;
  // dart:io's SocketException/HandshakeException are not available on web,
  // so match them by type name.
  final type = error.runtimeType.toString();
  if (type == 'SocketException' ||
      type == 'HandshakeException' ||
      type == 'HttpException') {
    return true;
  }
  return _networkPattern.hasMatch(error.toString());
}

final _networkPattern = RegExp(
  r'ClientException|SocketException|Failed to fetch|XMLHttpRequest error|'
  r'Connection (refused|reset|closed|failed)|Network is unreachable|'
  r'Failed host lookup|ERR_INTERNET_DISCONNECTED|ERR_NAME_NOT_RESOLVED|'
  r'NetworkError',
  caseSensitive: false,
);

bool _looksTechnical(String s) =>
    s.length > 300 ||
    s.contains('uri=') ||
    s.contains('Instance of ') ||
    s.contains('(operation: ') ||
    s.contains('#0 ') ||
    s.startsWith('TypeError') ||
    s.startsWith('Null check') ||
    s.contains('is not a subtype of');
