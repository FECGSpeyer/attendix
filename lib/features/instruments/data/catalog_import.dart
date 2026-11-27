import '../../../data/models/instrument/instrument.dart';
import '../../../data/repositories/base_repository.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../l10n/l10n.dart';
import 'catalog_selection.dart';
import 'instrument_catalog.dart';

class CatalogImportResult {
  const CatalogImportResult({required this.added, required this.skipped});
  final int added;
  final int skipped;
}

/// The page/account no longer owns this operation. Callers silently discard
/// the result instead of reporting success in another ensemble.
class CatalogImportCancelled implements Exception {
  const CatalogImportCancelled();
}

String _familyKey(String name) {
  final normalized = normalizeCatalogName(name);
  for (final family in InstrumentFamily.values) {
    if (['de', 'en'].any(
      (language) => normalizeCatalogName(family.label(language)) == normalized,
    )) {
      return family.name;
    }
  }
  return normalized;
}

/// Copies only selected new groups into the repository's fixed tenant.
/// Categories can remain empty after an error; instrument rows are one batch.
/// Reading fresh state on every attempt makes a lost success response retryable
/// without overwriting the ensemble's names, metadata or referenced IDs.
Future<CatalogImportResult> importCatalogGroups(
  GroupRepository repository,
  List<CatalogGroupDraft> drafts, {
  bool Function()? isCurrent,
}) async {
  void checkScope() {
    if (isCurrent != null && !isCurrent()) throw const CatalogImportCancelled();
    final role = repository.currentUserRole;
    if (!role.isAdmin && !role.isResponsible) {
      throw RepositoryException(
        message: l10nWithoutContext.coreFlutterRepoNoPermissionInTenant,
        operation: 'importCatalogGroups',
      );
    }
    repository.ensureNotDemo('importCatalogGroups');
  }

  checkScope();
  // Validate the whole draft before leaving any categories behind.
  for (final draft in drafts) {
    if (draft.name.trim().isEmpty) {
      throw ArgumentError.value(draft.name, 'name');
    }
  }
  if (drafts.isEmpty) return const CatalogImportResult(added: 0, skipped: 0);

  final groups = await repository.getGroups();
  checkScope();
  final pending = <CatalogGroupDraft>[];
  final known = [...groups];
  for (final draft in drafts) {
    if (known.any((group) => draftMatchesGroup(draft, group))) continue;
    pending.add(draft);
    known.add(
      Group(name: draft.name.trim(), synonyms: draft.synonyms.join(', ')),
    );
  }
  final skipped = drafts.length - pending.length;
  if (pending.isEmpty) return CatalogImportResult(added: 0, skipped: skipped);

  final categories = await repository.getGroupCategories();
  checkScope();
  final byFamily = <String, int>{};
  for (final category in categories) {
    if (category.id != null) {
      byFamily.putIfAbsent(_familyKey(category.name), () => category.id!);
    }
  }
  final missingFamilies = <String, String>{};
  for (final draft in pending) {
    final name = draft.categoryName?.trim();
    if (name == null || name.isEmpty) continue;
    final key = _familyKey(name);
    if (!byFamily.containsKey(key)) {
      missingFamilies.putIfAbsent(key, () => name);
    }
  }
  int rank(String key) {
    final index = InstrumentFamily.values.indexWhere(
      (family) => family.name == key,
    );
    return index < 0 ? InstrumentFamily.values.length : index;
  }

  final orderedFamilies =
      missingFamilies.keys.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
  var categoryOrder = categories.fold<int>(
    0,
    (max, c) => (c.sortOrder ?? 0) > max ? c.sortOrder! : max,
  );
  final alphabeticalCategories = categories.any((c) => c.sortOrder == null);
  for (final key in orderedFamilies) {
    checkScope();
    final category = await repository.createGroupCategory(
      name: missingFamilies[key]!,
      sortOrder: alphabeticalCategories ? null : ++categoryOrder,
    );
    checkScope();
    if (category.id == null) {
      throw StateError('Created instrument category has no id');
    }
    byFamily[key] = category.id!;
  }

  // Null means automatic alphabetical order in existing ensembles. Preserve
  // that convention rather than moving their old rows behind numbered ones.
  final normalGroups = groups.where((g) => g.maingroup != true).toList();
  final alphabetical = normalGroups.any((g) => g.sortOrder == null);
  var sortOrder = normalGroups.fold<int>(
    0,
    (max, g) => (g.sortOrder ?? 0) > max ? g.sortOrder! : max,
  );
  final rows = <Map<String, dynamic>>[
    for (final draft in pending)
      {
        'name': draft.name.trim(),
        'category':
            draft.categoryName == null
                ? null
                : byFamily[_familyKey(draft.categoryName!)],
        'synonyms': draft.synonyms.isEmpty ? null : draft.synonyms.join(', '),
        'tuning': draft.tuning,
        'clefs': draft.clefs ?? <String>[],
        'sort_order': alphabetical ? null : ++sortOrder,
        'maingroup': false,
      },
  ];
  checkScope();
  final added = await repository.createGroups(rows);
  checkScope();
  return CatalogImportResult(added: added.length, skipped: skipped);
}
