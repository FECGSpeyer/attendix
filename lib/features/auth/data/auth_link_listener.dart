import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/services/offline_queue_service.dart'
    show rootScaffoldMessengerKey;
import '../../../core/theme/app_colors.dart';
import 'auth_flow_service.dart';
import 'browser_url.dart';
import '../../../l10n/l10n.dart';

/// Route of the "Neues Passwort" page.
const String kNewPasswordRoute = '/new-password';

/// AUTH: wires up the Ionic auth-link handling (app.component.ts):
/// * `PASSWORD_RECOVERY` auth events → "Neues Passwort" page
/// * on web, the initial URL is checked for recovery / signup-confirmation
///   links (`?token_hash&type`, `?code`, `#access_token`).
///
/// Call once from the root widget after the first frame.
void initAuthLinkHandling(WidgetRef ref, GoRouter router) {
  ref.listenManual<AsyncValue<AuthState>>(authStateProvider, (_, next) {
    final event = next.valueOrNull?.event;
    if (event == AuthChangeEvent.passwordRecovery) {
      router.go(kNewPasswordRoute);
    }
  });

  if (!kIsWeb) {
    initNativeAppLinks(ref, router);
    return;
  }
  final link = AuthLink.parse(Uri.base);
  if (!link.isAuthLink) return;
  unawaited(_processLink(ref, router, link));
}

// DB_REVIEW_REST (F1): Universal Links / App Links on iOS and Android
// (Ionic app.component setupDeepLinks → appUrlOpen). https://attendix.de/...
// links from mails and Telegram open in the app: auth links (password reset,
// magic link, signup confirmation) are processed like on web, every other
// link navigates to its path + query (legacy /tabs/... URLs are mapped by the
// router redirect). attendix://live-plan links are handled by the native
// LiveActivity channel (live_activity_service.dart), not here.

/// Hosts whose links the app handles (Ionic AASA / assetlinks: attendix.de).
const Set<String> kAppLinkHosts = {'attendix.de', 'www.attendix.de'};

/// In-app location for an opened universal/app link, or null when the link
/// is not ours (other host or scheme, e.g. attendix://live-plan).
String? appLinkLocation(Uri uri) {
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  if (!kAppLinkHosts.contains(uri.host.toLowerCase())) return null;
  final path = uri.path.isEmpty ? '/' : uri.path;
  return uri.hasQuery ? '$path?${uri.query}' : path;
}

StreamSubscription<Uri>? _appLinkSubscription;

/// Listens to links that open the native app (cold start included: app_links
/// emits the initial link on [AppLinks.uriLinkStream]).
void initNativeAppLinks(WidgetRef ref, GoRouter router, {Stream<Uri>? links}) {
  _appLinkSubscription?.cancel();
  Stream<Uri> stream;
  try {
    stream = links ?? AppLinks().uriLinkStream;
  } catch (e) {
    debugPrint('[AppLinks] not available: $e');
    return;
  }
  _appLinkSubscription = stream.listen(
    (uri) => unawaited(handleAppLink(ref, router, uri)),
    onError: (Object e) => debugPrint('[AppLinks] link error: $e'),
  );
}

/// Ionic appUrlOpen handler (minus the live-plan branch, see above).
Future<void> handleAppLink(WidgetRef ref, GoRouter router, Uri uri) async {
  final location = appLinkLocation(uri);
  if (location == null) return;
  final link = AuthLink.parse(uri);
  if (link.isAuthLink) {
    await _processLink(ref, router, link);
    return;
  }
  router.go(location);
}

Future<void> _processLink(WidgetRef ref, GoRouter router, AuthLink link) async {
  final outcome = await ref.read(authFlowServiceProvider).handleAuthLink(link);
  // REVIEW_FIX2: only touch the URL when the link was actually handled.
  if (outcome != AuthLinkOutcome.none) clearAuthParamsFromBrowserUrl();
  switch (outcome) {
    case AuthLinkOutcome.none:
      return;
    case AuthLinkOutcome.recovery:
      router.go(kNewPasswordRoute);
    case AuthLinkOutcome.signupConfirmed:
      _toast(l10nWithoutContext.appEmailConfirmed, AppColors.success);
      router.go('/tenants');
    case AuthLinkOutcome.failed:
      _toast(
        link.errorDescription != null
            ? authLinkErrorText(link)
            : link.looksLikeRecovery
                ? l10nWithoutContext.appResetLinkInvalid
                : l10nWithoutContext.appConfirmLinkInvalid,
        AppColors.danger,
      );
      router.go('/login');
  }
}

void _toast(String message, Color color) {
  try {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  } catch (_) {
    // No messenger available (e.g. tests)
  }
}

/// German text for a Supabase `error_description` (English, already decoded
/// by [Uri.splitQueryString]; never decoded twice).
String authLinkErrorText(AuthLink link) {
  final description = (link.errorDescription ?? '').toLowerCase();
  if (description.contains('expired') || description.contains('invalid')) {
    return link.looksLikeRecovery
        ? l10nWithoutContext.appResetLinkInvalid
        : l10nWithoutContext.appConfirmLinkInvalid;
  }
  if (description.contains('denied')) {
    return l10nWithoutContext.loginFlutterAccessDenied;
  }
  return l10nWithoutContext.loginFlutterLinkFailed;
}
