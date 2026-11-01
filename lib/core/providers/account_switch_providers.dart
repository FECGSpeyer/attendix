import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../router/app_router.dart' show routerProvider;
import '../services/account_switch/account_switch_service.dart';
import '../services/account_switch/auth_token_api.dart';
import '../services/account_switch/saved_accounts_store.dart';
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

/// Remembered accounts of this device (incl. the signed-in one).
final savedAccountsProvider = StreamProvider<List<SavedAccount>>((ref) async* {
  final service = ref.watch(accountSwitchServiceProvider);
  yield await service.load();
  yield* service.changes;
});

/// Keeps the remembered accounts in step with the auth client (read once
/// from AttendixApp):
/// - every new session or token refresh stores the account's newest
///   refresh token; new accounts are only added while the new design is on,
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
    if (followsOtherTab(previous, state)) unawaited(_followAccountChange(ref));
    // A recovery session only updates a saved account, it never adds one.
    final add = state.event != AuthChangeEvent.passwordRecovery &&
        ref.read(redesignEnabledProvider);
    unawaited(service.remember(session, add: add).catchError((_) {}));
  }

  final current = auth.currentSession;
  if (current != null) {
    unawaited(service
        .remember(current, add: ref.read(redesignEnabledProvider))
        .catchError((_) {}));
  }
  final sub = auth.onAuthStateChange.listen(handle, onError: (_) {});
  ref.onDispose(sub.cancel);

  // Turning the new design on remembers the signed-in account right away.
  ref.listen<bool>(redesignEnabledProvider, (_, enabled) {
    final session = auth.currentSession;
    if (enabled && session != null) {
      unawaited(service.remember(session).catchError((_) {}));
    }
  });
});

/// True when [state] is an account change made in another browser tab
/// while this tab ran as [previousUserId].
bool followsOtherTab(String? previousUserId, AuthState state) {
  final userId = state.session?.user.id;
  return state.fromBroadcast && previousUserId != null && userId != null && userId != previousUserId;
}

Future<void> _followAccountChange(Ref ref) async {
  try {
    await ref.read(currentTenantProvider.notifier).setTenantLocal(null);
    ref.read(routerProvider).go('/tenants');
  } catch (_) {
    // Router not built yet (start-up): the normal start opens the selection.
  }
}
