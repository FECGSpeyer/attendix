import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../services/account_switch/account_switch_service.dart';
import '../services/account_switch/auth_token_api.dart';
import '../services/account_switch/saved_accounts_store.dart';
import 'redesign_providers.dart';

/// ACCOUNT_SWITCH: account switcher of the new design (Beta).
///
/// NOTE (Multi-Tenant): only Supabase Auth sessions of this device, no
/// tenant data → no tenantId filter.
final accountSwitchServiceProvider = Provider<AccountSwitchService>((ref) {
  final service = AccountSwitchService(
    store: createSavedAccountsStore(),
    api: HttpAuthTokenApi(
      supabaseUrl: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    ),
    auth: SupabaseAccountSwitchAuth(ref.watch(supabaseAuthProvider)),
  );
  ref.onDispose(service.dispose);
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
///   revoked by the sign-out anyway).
final accountSwitchBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(accountSwitchServiceProvider);
  final auth = ref.watch(supabaseAuthProvider);
  String? activeUserId = auth.currentUser?.id;

  void handle(AuthState state) {
    final session = state.session;
    switch (state.event) {
      case AuthChangeEvent.signedOut:
        final userId = activeUserId;
        activeUserId = null;
        if (userId != null) unawaited(service.forget(userId).catchError((_) {}));
      case AuthChangeEvent.signedIn ||
            AuthChangeEvent.initialSession ||
            AuthChangeEvent.tokenRefreshed ||
            AuthChangeEvent.userUpdated:
        if (session == null) return;
        activeUserId = session.user.id;
        final add = ref.read(redesignEnabledProvider);
        unawaited(service.remember(session, add: add).catchError((_) {}));
      default:
        break;
    }
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
