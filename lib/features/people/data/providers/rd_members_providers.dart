import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// REDESIGN: "Gliedern nach" of the Mitglieder tab: true = by category
/// (Holzbläser, Sonstiges …), false = by register (Akkordeon, Violine 1 …).
/// Remembered per group on this device, unlike the filters: it is how the
/// group wants to read its list, e.g. a mixed orchestra with many registers
/// under one category.
final rdMembersByCategoryProvider = NotifierProvider<RdMembersByCategoryNotifier, bool>(
  RdMembersByCategoryNotifier.new,
);

class RdMembersByCategoryNotifier extends Notifier<bool> {
  int? _tenantId;
  bool _chosen = false;

  static String _key(int tenantId) => 'rdMembersByCategory_$tenantId';

  @override
  bool build() {
    _tenantId = ref.watch(currentTenantIdProvider);
    _chosen = false;
    _load(_tenantId);
    return true;
  }

  Future<void> _load(int? tenantId) async {
    if (tenantId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(_key(tenantId));
      // A choice made meanwhile, or another group, wins.
      if (value != null && !_chosen && tenantId == _tenantId) state = value;
    } catch (_) {
      // Not stored: by category.
    }
  }

  Future<void> set(bool byCategory) async {
    _chosen = true;
    state = byCategory;
    final tenantId = _tenantId;
    if (tenantId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (byCategory) {
        await prefs.remove(_key(tenantId));
      } else {
        await prefs.setBool(_key(tenantId), false);
      }
    } catch (_) {
      // Only for this session then.
    }
  }
}

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
