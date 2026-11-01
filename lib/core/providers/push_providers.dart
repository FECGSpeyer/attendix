// PUSH: Riverpod wiring of the native push service (Ionic PushService).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/tenant/tenant.dart';
import '../../data/repositories/device_token_repository.dart';
import '../../l10n/l10n.dart';
import '../config/supabase_config.dart';
import '../constants/enums.dart';
import '../router/app_router.dart';
import '../router/redesign_routes.dart';
import '../services/live_activity_service.dart'
    show endLiveActivitiesBeforeSignOut, liveActivityServiceProvider;
import '../services/push/firebase_push_messaging_client.dart';
import '../services/push/push_messaging_client.dart';
import '../services/push/push_navigation.dart';
import '../services/push/push_service.dart';
import '../services/tracking/tracking_event.dart';
import '../services/tracking/tracking_service.dart';
import 'message_providers.dart';
import 'signout_providers.dart';
import 'tenant_providers.dart';
import '../../shared/widgets/adaptive/adaptive.dart';

/// Whether native push exists on this platform (Ionic
/// `Capacitor.isNativePlatform()`): iOS / Android apps, never the PWA.
bool get isNativePushPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// The push service (no-op on the web).
final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(
    client: FirebasePushMessagingClient(),
    tokens: ref.watch(deviceTokenRepositoryProvider),
    promptStore: SharedPrefsPushPromptStore(),
    host: RiverpodPushHost(ref),
    isNativePlatform: isNativePushPlatform,
    platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Starts push handling once (read from AttendixApp): listeners for
/// foreground pushes / taps, token registration after sign-in (Ionic
/// `SIGNED_IN` → promptAndEnable), token removal on sign-out and clearing
/// the app badge whenever the app is resumed (capacitor Badge `autoClear`).
final pushBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(pushServiceProvider);
  if (!service.isNativePlatform) return;

  unawaited(service.start());

  ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
    final state = next.valueOrNull;
    if (state == null) return;
    switch (state.event) {
      case AuthChangeEvent.signedIn:
        unawaited(service.promptAndEnable());
      case AuthChangeEvent.initialSession:
        // Restored session on app start: refresh the token registration.
        if (state.session != null) unawaited(service.promptAndEnable());
      case AuthChangeEvent.signedOut:
        // SOL_FIX19: joins the logout button's cleanup (one run per
        // session); the next sign-in's registration waits for it.
        unawaited(service.removeToken());
      default:
        break;
    }
  }, fireImmediately: true);

  final lifecycle = AppLifecycleListener(onResume: service.clearBadge);
  ref.onDispose(lifecycle.dispose);
});

/// Removes this device's push token before signing out (RLS needs the
/// session). Use on every logout button before `auth.signOut()`.
Future<void> removePushTokenBeforeSignOut(WidgetRef ref) async {
  try {
    await ref.read(pushServiceProvider).removeToken();
  } catch (_) {
    // Never block the logout.
  }
  // SOL_FIX15: also end the Live Activities and remove this device's Live
  // Activity tokens of the account (same session requirement).
  try {
    await endLiveActivitiesBeforeSignOut(
      ref.read(liveActivityServiceProvider),
      ref.read(currentAuthUserIdProvider),
    );
  } catch (_) {}
}

/// Ionic localStorage `push_prompt_shown`.
class SharedPrefsPushPromptStore implements PushPromptStore {
  @override
  Future<bool> wasShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kPushPromptShownKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPushPromptShownKey, true);
    } catch (_) {}
  }
}

/// Locations of the startup flow; push navigation waits until the app has
/// left them (Ionic waits for the LoginGuard redirect).
const Set<String> _startupLocations = {
  '/',
  '/login',
  '/register',
  '/terms',
  '/tenants',
  '/open-link',
  '/open-attendance',
};

/// [PushHost] backed by go_router and the Riverpod providers.
class RiverpodPushHost implements PushHost {
  RiverpodPushHost(this._ref);

  final Ref _ref;

  GoRouter get _router => _ref.read(routerProvider);

  BuildContext? get _context =>
      _router.routerDelegate.navigatorKey.currentContext;

  bool get _hasSession {
    try {
      return _ref.read(supabaseClientProvider).auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  String get _location {
    try {
      return _router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return '/';
    }
  }

  @override
  void track(TrackingEvent event) {
    try {
      _ref.read(trackingServiceProvider).track(event);
    } catch (_) {}
  }

  @override
  Future<void> waitUntilReadyForNavigation() async {
    const step = Duration(milliseconds: 250);
    const timeout = Duration(seconds: 15);
    var waited = Duration.zero;
    while (waited < timeout) {
      final ready = _hasSession &&
          _ref.read(currentTenantProvider) != null &&
          !_startupLocations.contains(_location);
      if (ready) return;
      await Future<void>.delayed(step);
      waited += step;
    }
  }

  @override
  Future<bool?> confirmEnablePush() async {
    // Show it inside the app shell: a dialog on the login page would be
    // removed together with that page by the startup redirect.
    await waitUntilReadyForNavigation();
    final context = _context;
    if (context == null || !context.mounted) return null;
    return showAppDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AppAlertDialog(
          title: Text(l10n.svcPushTitle),
          content: Text(l10n.svcPushPrompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.svcLater),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.svcActivate),
            ),
          ],
        );
      },
    );
  }

  @override
  Future<bool> showForegroundAlert(PushMessage message) async {
    final context = _context;
    if (context == null || !context.mounted) return false;
    final result = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        final title = message.title ?? '';
        return AppAlertDialog(
          title: Text(title.isNotEmpty ? title : l10n.svcNotification),
          content: Text(message.body ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonOk),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.svcShow),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Future<void> navigateFromData(Map<String, dynamic> data) async {
    // No session – nothing to do, the normal login flow proceeds (Ionic).
    if (!_hasSession || _ref.read(currentTenantProvider) == null) return;

    final tenantId = pushTenantId(data);
    if (tenantId != null && tenantId != _ref.read(currentTenantIdProvider)) {
      try {
        final tenants = await _ref.read(userTenantsProvider.future);
        Tenant? tenant;
        for (final t in tenants) {
          if (t.id == tenantId) tenant = t;
        }
        if (tenant != null) {
          await _ref.read(currentTenantProvider.notifier).setTenant(tenant);
        }
      } catch (_) {
        // Stay in the current tenant.
      }
    }

    Role role = Role.none;
    try {
      final tenantUser = await _ref.read(currentTenantUserProvider.future);
      role = tenantUser?.roleEnum ?? Role.none;
    } catch (_) {}

    final target = resolvePushTarget(data, role);

    final readType = target.markReadType;
    if (readType != null) {
      try {
        // tenant-read-after-await: intended — the push may have switched to
        // its target tenant above; markMatchingRead must run there.
        final repo = _ref.read(userNotificationRepositoryWithTenantProvider);
        if (repo.hasTenantId) {
          await repo.markMatchingRead(readType,
              attendanceId: target.markReadAttendanceId);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[push] markMatchingRead failed: $e');
      }
    }

    final pending = target.pendingAttendanceId;
    if (pending != null) {
      _ref.read(pendingAttendanceIdProvider.notifier).state = pending;
    }

    final raw = target.location;
    if (raw == null) return;
    // In the new design (Beta) the Termin opens on its new page.
    final location = RedesignRoutes.betaTarget(raw);
    // Detail pages are pushed like in the notification center, so "back"
    // returns to where the user was; tab roots are opened with go.
    final isDetail = location.startsWith('/messages/') ||
        RegExp(r'^/(attendance|termine)/\d+([?#]|$)').hasMatch(location);
    if (isDetail && !_startupLocations.contains(_location)) {
      unawaited(_router.push(location));
    } else {
      _router.go(location);
    }
  }
}
