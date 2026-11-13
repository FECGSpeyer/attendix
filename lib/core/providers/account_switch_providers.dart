import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Device-local developer mode (Leon, 13.11.2026): "Konto wechseln" and
/// the saved accounts on the login page are a developer feature. Tapping
/// the version at the bottom of the Ich page 7× turns it on or off on this
/// device. Without it, logins are not remembered either.
const developerModeStorageKey = 'attendix_developer_mode';

/// Reads the stored developer mode (false when storage is unavailable).
Future<bool> loadDeveloperMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(developerModeStorageKey) ?? false;
  } catch (_) {
    return false;
  }
}

class DeveloperModeNotifier extends Notifier<bool> {
  bool _touched = false;

  @override
  bool build() {
    unawaited(loadDeveloperMode().then((on) {
      if (!_touched) state = on;
    }));
    return false;
  }

  Future<void> setEnabled(bool enabled) async {
    _touched = true;
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(developerModeStorageKey, enabled);
    } catch (_) {
      // Storage unavailable (private browsing): on for this session only.
    }
  }
}

/// See [developerModeStorageKey].
final developerModeProvider = NotifierProvider<DeveloperModeNotifier, bool>(DeveloperModeNotifier.new);

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
///   and developer mode is on,
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

  // Every store change of this listener runs in event order: reading the
  // developer mode is async, so without the chain a sign-out's forget()
  // could run before the remember() of an earlier event and the signed-out
  // account would be stored again.
  Future<void> chain = Future.value();
  void enqueue(Future<void> Function() op) {
    chain = chain.then((_) => op()).catchError((_) {});
  }

  // New accounts are only added in developer mode (see
  // [developerModeStorageKey]).
  void rememberSession(Session session, {required bool add}) {
    enqueue(() async => service.remember(session, add: add && await loadDeveloperMode()));
  }

  void handle(AuthState state) {
    final session = state.session;
    if (state.event == AuthChangeEvent.signedOut) {
      final userId = activeUserId;
      activeUserId = null;
      if (userId != null) enqueue(() => service.forget(userId));
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
    rememberSession(session, add: add);
  }

  final current = auth.currentSession;
  if (current != null) {
    rememberSession(current, add: ref.read(redesignEnabledProvider));
  }
  final sub = auth.onAuthStateChange.listen(handle, onError: (_) {});
  ref.onDispose(sub.cancel);

  // Turning the new design or developer mode on remembers the signed-in
  // account right away.
  void rememberCurrent() {
    final session = auth.currentSession;
    if (session != null && ref.read(redesignEnabledProvider) && ref.read(developerModeProvider)) {
      enqueue(() => service.remember(session));
    }
  }

  ref.listen<bool>(redesignEnabledProvider, (_, enabled) {
    if (enabled) rememberCurrent();
  });
  ref.listen<bool>(developerModeProvider, (_, enabled) {
    if (enabled) rememberCurrent();
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
