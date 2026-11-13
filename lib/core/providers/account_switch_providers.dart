import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../router/app_router.dart' show routerProvider;
import '../services/account_switch/account_switch_service.dart';
import '../services/account_switch/auth_token_api.dart';
import '../services/account_switch/saved_account.dart';
import '../services/account_switch/saved_accounts_store.dart';
import 'dashboard_providers.dart' show superDeveloperEmail;
import 'redesign_providers.dart';
import 'tenant_providers.dart';

/// ACCOUNT_SWITCH: account switcher of the new design (Beta).
///
/// NOTE (Multi-Tenant): only Supabase Auth sessions of this device, no
/// tenant data → no tenantId filter.

/// Token calls for accounts other than the signed-in one.
final authTokenApiProvider = Provider<AuthTokenApi>((ref) {
  return HttpAuthTokenApi(
    supabaseUrl: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
});

final accountSwitchServiceProvider = Provider<AccountSwitchService>((ref) {
  final auth = SupabaseAccountSwitchAuth(ref.watch(supabaseAuthProvider));
  final service = AccountSwitchService(
    store: createSavedAccountsStore(),
    api: ref.watch(authTokenApiProvider),
    auth: auth,
  );
  ref.onDispose(service.dispose);
  ref.onDispose(auth.dispose);
  return service;
});

/// ACCOUNT_SWITCH is a developer feature (Leon, 13.11.2026): unlocked on a
/// device once the super developer is signed in there or remembered there,
/// then also for the test accounts switched to from it. Everyone else sees
/// neither "Konto wechseln" nor saved accounts on the login page, and their
/// logins are not remembered.
bool isAccountSwitchUnlocked(String? currentEmail, Iterable<SavedAccount> accounts) {
  bool isDev(String? email) => email?.trim().toLowerCase() == superDeveloperEmail;
  return isDev(currentEmail) || accounts.any((a) => isDev(a.email));
}

/// See [isAccountSwitchUnlocked].
final accountSwitchUnlockedProvider = Provider<bool>((ref) {
  // Re-evaluate on auth changes (login/logout/switch).
  ref.watch(authStateProvider);
  final email = ref.watch(supabaseAuthProvider).currentUser?.email;
  final accounts = ref.watch(savedAccountsProvider).valueOrNull ?? const <SavedAccount>[];
  return isAccountSwitchUnlocked(email, accounts);
});

/// Remembered accounts of this device (incl. the signed-in one).
final savedAccountsProvider = StreamProvider<List<SavedAccount>>((ref) async* {
  final service = ref.watch(accountSwitchServiceProvider);
  yield await service.load();
  yield* service.changes;
});

/// Keeps the remembered accounts in step with the auth client (read once
/// from AttendixApp):
/// - every new session or token refresh stores the account's newest
///   refresh token; new accounts are only added while the new design is on
///   and the switcher is unlocked on this device,
/// - a sign-out removes the account that was signed in (its session is
///   revoked by the sign-out anyway),
/// - another browser tab that changed the account (switch or sign-in, it
///   reaches this tab as a broadcast) makes this tab follow like the
///   switching tab: no group selected, back to the group selection – the
///   group of the old account may not exist for the new one.
final accountSwitchBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(accountSwitchServiceProvider);
  final auth = ref.watch(supabaseAuthProvider);
  String? activeUserId = auth.currentUser?.id;

  // New accounts are only added on a device where the switcher is unlocked
  // (developer feature, see [isAccountSwitchUnlocked]).
  Future<void> rememberSession(Session session, {required bool add}) async {
    final unlocked = add && isAccountSwitchUnlocked(session.user.email, await service.load());
    await service.remember(session, add: unlocked);
  }

  void handle(AuthState state) {
    final session = state.session;
    if (state.event == AuthChangeEvent.signedOut) {
      final userId = activeUserId;
      activeUserId = null;
      if (userId != null) unawaited(service.forget(userId).catchError((_) {}));
      return;
    }
    if (session == null) return;
    // Every event that carries a session (incl. password recovery, MFA)
    // names the signed-in account, so a later sign-out removes the right one.
    final previous = activeUserId;
    activeUserId = session.user.id;
    if (followsOtherTab(previous, state)) {
      unawaited(followAccountChange(
        userId: session.user.id,
        generation: () => service.sessionGeneration,
        currentUserId: () => auth.currentSession?.user.id,
        clearTenant: () => ref.read(currentTenantProvider.notifier).setTenantLocal(null),
        navigate: () => ref.read(routerProvider).go('/tenants'),
      ).catchError((_) => false));
    }
    // A recovery session only updates a saved account, it never adds one.
    final add = state.event != AuthChangeEvent.passwordRecovery &&
        ref.read(redesignEnabledProvider);
    unawaited(rememberSession(session, add: add).catchError((_) {}));
  }

  final current = auth.currentSession;
  if (current != null) {
    unawaited(rememberSession(current, add: ref.read(redesignEnabledProvider))
        .catchError((_) {}));
  }
  final sub = auth.onAuthStateChange.listen(handle, onError: (_) {});
  ref.onDispose(sub.cancel);

  // Turning the new design on remembers the signed-in account right away.
  ref.listen<bool>(redesignEnabledProvider, (_, enabled) {
    final session = auth.currentSession;
    if (enabled && session != null) {
      unawaited(rememberSession(session, add: true).catchError((_) {}));
    }
  });
});

/// True when [state] is an account change made in another browser tab
/// while this tab ran as [previousUserId]. A password recovery is left to
/// its own flow (the auth link listener shows the alert "Neues Passwort").
bool followsOtherTab(String? previousUserId, AuthState state) {
  final userId = state.session?.user.id;
  return state.fromBroadcast &&
      state.event != AuthChangeEvent.passwordRecovery &&
      previousUserId != null &&
      userId != null &&
      userId != previousUserId;
}

/// Makes this tab follow an account change of another tab: no group
/// selected, then the group selection. Navigates only when the tab still
/// runs as [userId] in the same session after clearing the group (a newer
/// change meanwhile has its own follow-up). Returns whether it navigated.
Future<bool> followAccountChange({
  required String userId,
  required int Function() generation,
  required String? Function() currentUserId,
  required Future<void> Function() clearTenant,
  required void Function() navigate,
}) async {
  final start = generation();
  await clearTenant();
  if (generation() != start || currentUserId() != userId) return false;
  try {
    navigate();
  } catch (_) {
    // Router not built yet (start-up): the normal start opens the selection.
    return false;
  }
  return true;
}
