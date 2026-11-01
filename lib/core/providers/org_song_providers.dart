import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song/org_song.dart';
import '../../data/repositories/org_song_repository.dart';
import '../config/supabase_config.dart';
import 'tenant_providers.dart';

/// Organisation-wide Werk search (Ionic 4.17.13): repository bound to the
/// current tenant (the RPC and the organisation lookup use it).
final orgSongRepositoryWithTenantProvider = Provider<OrgSongRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(orgSongRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [OrgSongRepository] per tenant and account.
final orgSongRepositoryForTenantProvider = Provider.family<OrgSongRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(_orgSongRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _orgSongRepositoryForAccountProvider = Provider.family<OrgSongRepository, AccountScopeKey>((ref, key) {
  final repo = OrgSongRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

/// A copy target: an instance where the user is admin/responsible and the
/// library its Werke are stored in (differs with Werk-Synchronisierung).
class OrgSongCopyTarget {
  const OrgSongCopyTarget({required this.tenant, required this.libraryId, this.libraryName});

  final OrgSongTenant tenant;
  final int libraryId;

  /// Name of the library instance when it is not [tenant] itself.
  final String? libraryName;
}

/// Ionic `buildTargets`: instances with role admin (1) / responsible (5),
/// one entry per Werk library, the current instance first.
List<OrgSongCopyTarget> buildOrgSongCopyTargets({
  required int currentTenantId,
  required List<OrgSongTenant> orgTenants,
  required Map<int, int> rolesByTenant,
}) {
  final all = [
    ...orgTenants.where((t) => t.id == currentTenantId),
    ...orgTenants.where((t) => t.id != currentTenantId),
  ];
  final seen = <int>{};
  final targets = <OrgSongCopyTarget>[];
  for (final tenant in all) {
    final role = rolesByTenant[tenant.id];
    if (role != 1 && role != 5) continue;
    final libraryId = tenant.libraryId;
    if (!seen.add(libraryId)) continue;
    final library = libraryId != tenant.id ? all.where((t) => t.id == libraryId).firstOrNull : null;
    targets.add(OrgSongCopyTarget(tenant: tenant, libraryId: libraryId, libraryName: library?.shortName));
  }
  return targets;
}
