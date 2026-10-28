import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../services/offline_queue_service.dart' show rootScaffoldMessengerKey;

/// DEMO_GUARD: Ionic `db.demoRestricted` / `people.demoUnavailable`.
const String kDemoRestrictedMessage =
    'Diese Funktion ist im Demo-Modus nicht verfügbar.';

/// Thrown when the demo account tries a blocked mutation
/// (Ionic `checkDemoRestriction()` → `Error('Demo mode restriction')`).
///
/// `toString()` returns the German user text, so existing
/// `ToastHelper.showError(context, 'Fehler: $e')` handlers show the
/// Ionic wording.
class DemoModeException implements Exception {
  const DemoModeException([this.operation = '']);

  final String operation;

  String get message => kDemoRestrictedMessage;

  @override
  String toString() => kDemoRestrictedMessage;
}

/// Demo-mode write protection (Ionic db.service `isDemo()` /
/// `checkDemoRestriction()`).
///
/// The demo account is the user whose e-mail equals the configured demo mail
/// (`DEMO_EMAIL`, Ionic `environment.demoMail`). For it, Ionic blocks every
/// guarded db.service mutation with a warning toast and an error.
class DemoGuard {
  DemoGuard._();

  /// Overridable for tests; defaults to [AppConstants.demoMailForGuard].
  @visibleForTesting
  static String? demoMailOverride;

  static DateTime? _lastToastAt;

  /// How long after a demo toast generic error toasts are swallowed, so the
  /// blocked operation's own "Fehler beim Speichern" does not replace the
  /// demo hint.
  static const Duration _suppressWindow = Duration(seconds: 4);

  static String get _demoMail =>
      (demoMailOverride ?? AppConstants.demoMailForGuard).trim().toLowerCase();

  /// Ionic `isDemo()`: `user.email === environment.demoMail`.
  static bool isDemoEmail(String? email) {
    final demo = _demoMail;
    if (demo.isEmpty || email == null) return false;
    return email.trim().toLowerCase() == demo;
  }

  /// Ionic `checkDemoRestriction()`: warning toast + throw when [email]
  /// belongs to the demo account.
  static void check(String? email, [String operation = '']) {
    if (!isDemoEmail(email)) return;
    showRestrictedToast();
    throw DemoModeException(operation);
  }

  /// E-mail of the signed-in user (null when Supabase is not initialised,
  /// e.g. in tests).
  static String? get currentEmail {
    try {
      return Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  /// Ionic `db.isDemo()` for code without a repository/ref.
  static bool get isDemo => isDemoEmail(currentEmail);

  /// Throwing guard for services that bypass the repositories.
  static void checkCurrent([String operation = '']) =>
      check(currentEmail, operation);

  /// Page-level guard (Ionic import/bulk-edit pages:
  /// `if (db.isDemo()) { showToast(...'warning'); return; }`).
  /// Returns true (and shows the warning toast) when the action is blocked.
  static bool blocked() {
    if (!isDemo) return false;
    showRestrictedToast();
    return true;
  }

  /// Shows the Ionic warning toast without a BuildContext.
  static void showRestrictedToast() {
    _lastToastAt = DateTime.now();
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                kDemoRestrictedMessage,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Whether a demo toast was shown just now (ToastHelper uses it to swallow
  /// the follow-up error toast of the blocked operation).
  static bool get recentlyShown {
    final last = _lastToastAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < _suppressWindow;
  }

  @visibleForTesting
  static void resetForTest() {
    _lastToastAt = null;
    demoMailOverride = null;
  }
}
