import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/account_repository.dart';
import '../../data/repositories/legal_repository.dart';
import '../services/tracking/tracking_event.dart';
import '../services/tracking/tracking_service.dart';
import 'tenant_providers.dart';

/// Legal text (Impressum & Datenschutz) as HTML.
///
/// Global content (no tenant) — cached for the app session like Ionic's
/// `LegalService`.
final legalContentProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(legalRepositoryProvider);
  return repo.getLegalContent();
});

/// Account mutations: accept terms, delete account (DSGVO).
class AccountNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Stamps `terms_accepted_at` (Ionic `TermsPage.accept`).
  Future<void> acceptTerms() async {
    state = const AsyncValue.loading();
    try {
      await ref.read(accountRepositoryProvider).acceptTerms();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Permanently deletes the user's account via the `delete-account` edge
  /// function, then signs out and clears the tenant state.
  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    try {
      // Ionic tracks before deleting (afterwards the user no longer exists).
      ref.read(trackingServiceProvider).track(TrackingEvent.accountDeleted);
      await ref.read(accountRepositoryProvider).deleteAccount();
      await ref.read(currentTenantProvider.notifier).clearTenant();
      ref.invalidate(userTenantsProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final accountNotifierProvider =
    NotifierProvider<AccountNotifier, AsyncValue<void>>(AccountNotifier.new);
