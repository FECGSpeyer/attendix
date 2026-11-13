import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../data/models/tenant/tenant.dart';

/// REDESIGN: the other group whose Werke the current group shows
/// (Werk-Synchronisierung, set in the organisation settings). Null when the
/// Werke are the group's own, or while that is not known yet.
final rdSharedLibrarySourceProvider = Provider<int?>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  final source = ref.watch(songTenantSettingsProvider).valueOrNull?.songSourceTenantId;
  return source == null || source == tenantId ? null : source;
});

/// Whether the viewer may change the Werke of the group [source]: only as
/// Admin or Verantwortliche there (the database refuses everyone else, a
/// refused change returns no error). [tenants] are the viewer's own groups
/// with their role; while they are unknown nothing is hidden.
bool rdMayEditLibrary({required int? source, required List<Tenant>? tenants}) {
  if (source == null || tenants == null) return true;
  final role = tenants.where((t) => t.id == source).firstOrNull?.role;
  if (role == null) return false;
  final r = Role.fromValue(role);
  return r.isAdmin || r.isResponsible;
}

/// Whether the Werke the current group shows can be changed from here by
/// the viewer (on top of the role in the current group).
final rdLibraryEditableProvider = Provider<bool>((ref) {
  final source = ref.watch(rdSharedLibrarySourceProvider);
  if (source == null) return true;
  return rdMayEditLibrary(source: source, tenants: ref.watch(userTenantsProvider).valueOrNull);
});

/// Name of the group whose Werke are shown, for the note on the Werke tab.
/// Null for own Werke or when the name cannot be read.
final rdSharedLibraryNameProvider = FutureProvider.autoDispose<String?>((ref) async {
  if (ref.watch(rdSharedLibrarySourceProvider) == null) return null;
  final repo = ref.watch(songRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  try {
    return await repo.getSongSourceName();
  } catch (_) {
    return null;
  }
});
