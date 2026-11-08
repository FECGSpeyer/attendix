import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart' show currentAuthUserIdProvider;
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../rd_members_list_filter.dart';
import '../rd_members_logic.dart' show RdMembersFilter;

/// REDESIGN (UX D3): "Fehlen oft" filter of the Mitglieder tab. A provider
/// and not page state, so "Heute" can open the tab already filtered.
final rdMembersCriticalOnlyProvider = StateProvider<bool>((ref) {
  // Starts unfiltered in another group or account.
  ref.watch(currentTenantIdProvider);
  ref.watch(currentAuthUserIdProvider);
  return false;
});

/// REDESIGN: Aktiv / Pausiert / Wartet of the Mitglieder tab. A provider
/// and not page state, so the hint "N neue Anmeldungen" and the
/// "Anfragen" tile of the overview can open "Wartet".
final rdMembersTabProvider = StateProvider<RdMembersFilter>((ref) {
  ref.watch(currentTenantIdProvider);
  ref.watch(currentAuthUserIdProvider);
  return RdMembersFilter.active;
});

/// REDESIGN: "Sortieren & Filtern" of the Mitglieder tab. Kept while the
/// app runs (leaving the tab keeps it); another group or account starts
/// unfiltered.
final rdMembersListFilterProvider = StateProvider<RdMembersListFilter>((ref) {
  ref.watch(currentTenantIdProvider);
  ref.watch(currentAuthUserIdProvider);
  return const RdMembersListFilter();
});

/// Accounts that are also members of the linked tenant [tenantId] (filter
/// "Auch Mitglied in").
final rdOtherInstanceUserIdsProvider = FutureProvider.autoDispose.family<Set<String>, int>((ref, tenantId) async {
  final repo = ref.watch(crossTenantPersonRepositoryWithTenantProvider);
  final linkedIds = await ref.watch(linkedTenantIdsProvider.future);
  return repo.getUserIdsInTenant(tenantId, linkedTenantIds: linkedIds);
});

/// REDESIGN: "Auswählen" mode of the Mitglieder tab (several members at
/// once). A provider so the Verwaltung search can open the tab in it;
/// another group or account starts without it.
final rdMembersSelectingProvider = StateProvider<bool>((ref) {
  ref.watch(currentTenantIdProvider);
  ref.watch(currentAuthUserIdProvider);
  return false;
});
