import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../router/route_access.dart' show canOpenSongsTab;
import 'debug_providers.dart';
import 'organisation_providers.dart';
import 'tenant_providers.dart';

/// SETTINGS2: optional bottom tabs "Werke" and "Org" (Ionic tabs.page,
/// `db.getShowSongsTab` / `db.getShowOrgPlansTab`).
///
/// Stored per user and tenant in the auth `user_metadata`
/// (`showSongsTab_<tenantId>`, `showOrgPlansTab_<tenantId>`), like Ionic.
@immutable
class OptionalTabs {
  const OptionalTabs({this.songs = false, this.orgPlans = false});

  final bool songs;
  final bool orgPlans;

  OptionalTabs copyWith({bool? songs, bool? orgPlans}) => OptionalTabs(
        songs: songs ?? this.songs,
        orgPlans: orgPlans ?? this.orgPlans,
      );
}

/// Metadata keys (shared with Ionic).
String songsTabKey(int tenantId) => 'showSongsTab_$tenantId';
String orgPlansTabKey(int tenantId) => 'showOrgPlansTab_$tenantId';

/// Reads the optional tab flags of [tenantId] from the user metadata.
OptionalTabs optionalTabsFromMetadata(Map<String, dynamic>? metadata, int tenantId) =>
    OptionalTabs(
      songs: metadata?[songsTabKey(tenantId)] == true,
      orgPlans: metadata?[orgPlansTabKey(tenantId)] == true,
    );

class OptionalTabsNotifier extends Notifier<OptionalTabs> {
  @override
  OptionalTabs build() {
    // SOL_FIX15: user_metadata of the signed-in account – rebuild per account.
    ref.watch(currentAuthUserIdProvider);
    final tenantId = ref.watch(currentTenantIdProvider);
    if (tenantId == null) return const OptionalTabs();
    final metadata = ref.read(supabaseAuthProvider).currentUser?.userMetadata;
    return optionalTabsFromMetadata(metadata, tenantId);
  }

  Future<void> _save(String key, bool value, OptionalTabs next) async {
    final previous = state;
    state = next;
    try {
      // GoTrue merges `data` into user_metadata, so only our key is sent.
      await ref.read(supabaseAuthProvider).updateUser(UserAttributes(data: {key: value}));
    } catch (e) {
      // SOL_FIX21: only roll back our own change – not after a tenant /
      // account switch (rebuilt state) or a newer edit.
      if (identical(state, next)) state = previous;
      rethrow;
    }
  }

  /// Ionic `setShowSongsTab`.
  Future<void> setShowSongsTab(bool value) async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
    await _save(songsTabKey(tenantId), value, state.copyWith(songs: value));
  }

  /// Ionic `setShowOrgPlansTab`.
  Future<void> setShowOrgPlansTab(bool value) async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
    await _save(orgPlansTabKey(tenantId), value, state.copyWith(orgPlans: value));
  }
}

final optionalTabsNotifierProvider =
    NotifierProvider<OptionalTabsNotifier, OptionalTabs>(OptionalTabsNotifier.new);

/// Whether the current role/tenant may have the optional "Werke" tab at all
/// (tab and its "Als Tab anzeigen" toggle). Ionic tabs.page:
/// `tenant.type !== 'general' && role !== APPLICANT`; SOL_FIX22: bound to the
/// `/songs-tab` route guard (`canOpenSongsTab`), which also denies parents.
final songsTabAllowedProvider = Provider<bool>((ref) {
  final tenant = ref.watch(currentTenantProvider);
  final role = ref.watch(effectiveRoleProvider);
  return tenant != null && tenant.type != 'general' && canOpenSongsTab(role);
});

/// Ionic: `showSongsTabSignal() && tenant.type !== 'general' && role !== APPLICANT`
/// (plus the route guard's parent rule, see [songsTabAllowedProvider]).
final showSongsTabProvider = Provider<bool>((ref) {
  if (!ref.watch(songsTabAllowedProvider)) return false;
  return ref.watch(optionalTabsNotifierProvider).songs;
});

/// Ionic: `showOrgPlansTabSignal() && organisation && role in [ADMIN, RESPONSIBLE]`.
final showOrgPlansTabProvider = Provider<bool>((ref) {
  final role = ref.watch(effectiveRoleProvider);
  if (!(role.isAdmin || role.isResponsible)) return false;
  if (ref.watch(currentOrganisationProvider).valueOrNull == null) return false;
  return ref.watch(optionalTabsNotifierProvider).orgPlans;
});
