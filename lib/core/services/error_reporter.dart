import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';

/// Production error monitoring.
///
/// Sends unexpected errors to Sentry when `SENTRY_DSN` is set in `.env.app`.
/// Without a DSN every call is a no-op, so tests and local builds send
/// nothing. Uses the pure Dart `sentry` package (no native pods), so web
/// and iOS behave the same.
///
/// Privacy: no user, no IP (`sendDefaultPii` off), no request data and no
/// breadcrumbs leave the device; only the error, its stack trace, the
/// release and the place it was reported from.
class ErrorReporter {
  ErrorReporter._();

  static bool _enabled = false;

  /// Whether a DSN was configured and Sentry started.
  static bool get isEnabled => _enabled;

  /// Starts Sentry. Never throws: monitoring must not break the app start.
  static Future<void> init({
    required String? dsn,
    required String release,
    String? environment,
  }) async {
    final trimmed = dsn?.trim() ?? '';
    if (trimmed.isEmpty) return;
    try {
      await Sentry.init((options) {
        options.dsn = trimmed;
        options.release = 'attendix@$release';
        options.environment =
            (environment?.trim().isNotEmpty ?? false) ? environment!.trim() : 'production';
        options.sendDefaultPii = false;
        options.maxBreadcrumbs = 0;
        options.beforeSend = scrub;
      });
      _enabled = true;
    } catch (e) {
      if (kDebugMode) debugPrint('ErrorReporter: Sentry init failed: $e');
    }
  }

  /// Removes personal data before an event is sent.
  @visibleForTesting
  static SentryEvent? scrub(SentryEvent event, Hint hint) {
    event.user = null;
    event.request = null;
    event.breadcrumbs = null;
    event.serverName = null;
    return event;
  }

  /// Network failures happen all the time on mobile (offline, tunnel,
  /// Wi-Fi switch) and say nothing about a bug, so they are not sent.
  @visibleForTesting
  static bool isExpected(Object error) {
    final text = error.toString();
    return text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup') ||
        text.contains('XMLHttpRequest error') ||
        text.contains('Connection closed') ||
        text.contains('Connection reset') ||
        text.contains('TimeoutException');
  }

  /// Reports [error]. [where] names the place (e.g. `PlayerRepository.getAll`).
  /// Logs in debug mode, sends in release builds with a DSN.
  static void report(Object error, StackTrace? stack, {String? where}) {
    if (kDebugMode) {
      debugPrint('[${where ?? 'error'}] $error');
    }
    if (!_enabled || isExpected(error)) return;
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: where == null ? null : (scope) => scope.setTag('where', where),
      ).then((_) {}, onError: (_) {}),
    );
  }
}
