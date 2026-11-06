import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/person/person.dart';
import 'group_providers.dart';
import 'player_providers.dart';
import '../services/offline_list_cache.dart';
import '../utils/global_toast.dart';
import '../../l10n/l10n.dart';

/// Provider for conductors (main group members)
/// Conductors are members of the "main group" (Hauptgruppe/Dirigenten)
final conductorsProvider = FutureProvider<List<Person>>((ref) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];

  // Ionic conductor.service `offline_conductors_v1_`: the last loaded list
  // while offline (song history with conductor, songs selection sheet).
  // The main group is loaded inside the fetch, so an offline start (main
  // group not reachable) still falls back to the cached list.
  return OfflineListCache.read<Person>(
    ref,
    tenantId: repo.currentTenantId,
    part: 'conductors',
    fetch: () async {
      final mainGroup = await ref.read(mainGroupProvider.future);
      final mainGroupId = mainGroup?.id;
      if (mainGroupId == null) return <Person>[];
      try {
        return await repo.getConductors(mainGroupId, includeLeft: true);
      } catch (_) {
        // Ionic ConductorService: toast 'Fehler beim Laden der Hauptgruppen-Personen'.
        GlobalToast.error(l10nWithoutContext.svcLoadMainGroupPeopleFailed);
        rethrow;
      }
    },
    toJson: (p) => p.toJson(),
    fromJson: Person.fromJson,
  );
});

/// Provider for active conductors only (not left)
final activeConductorsProvider = FutureProvider<List<Person>>((ref) async {
  final conductors = await ref.watch(conductorsProvider.future);
  return conductors.where((c) => c.left == null).toList();
});
