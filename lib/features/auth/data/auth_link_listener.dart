import 'dart:async';

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

  if (!kIsWeb) return;
  final link = AuthLink.parse(Uri.base);
  if (!link.isAuthLink) return;
  unawaited(_processLink(ref, router, link));
}

Future<void> _processLink(WidgetRef ref, GoRouter router, AuthLink link) async {
  final outcome = await ref.read(authFlowServiceProvider).handleAuthLink(link);
  clearAuthParamsFromBrowserUrl();
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
