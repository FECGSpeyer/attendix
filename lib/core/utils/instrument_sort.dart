import '../../data/models/instrument/instrument.dart';

/// Instruments grouped under one category (or none) for display & reordering.
/// Mirrors Ionic instrument-list.page.ts groupInstrumentsByCategory().
class InstrumentCategorySection {
  InstrumentCategorySection({
    required this.categoryId,
    required this.name,
    required this.sortOrder,
    required this.groups,
  });

  /// null = "Ohne Kategorie"
  final int? categoryId;
  final String name;
  final int? sortOrder;
  final List<Group> groups;
}

/// Compare two nullable sort orders: both set → numeric, only one set → the
/// one with a value first, none set → 0 (caller falls back to name).
int compareSortOrder(int? a, int? b) {
  if (a != null && b != null) return a.compareTo(b);
  if (a != null) return -1;
  if (b != null) return 1;
  return 0;
}

/// Sort instruments within a category: sort_order first, then name.
List<Group> sortGroupsBySortOrder(Iterable<Group> groups) {
  final list = [...groups];
  list.sort((a, b) {
    final c = compareSortOrder(a.sortOrder, b.sortOrder);
    if (c != 0) return c;
    return a.name.compareTo(b.name);
  });
  return list;
}

/// Sort categories: sort_order first, then name.
List<GroupCategory> sortCategoriesBySortOrder(Iterable<GroupCategory> cats) {
  final list = [...cats];
  list.sort((a, b) {
    final c = compareSortOrder(a.sortOrder, b.sortOrder);
    if (c != 0) return c;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return list;
}

/// Group instruments by category, sort sections by category sort_order then
/// name, and sort instruments in each section by sort_order then name.
List<InstrumentCategorySection> groupInstrumentsByCategory(
  List<Group> groups,
  List<GroupCategory> categories, {
  String noCategoryLabel = 'Ohne Kategorie',
}) {
  final byCategory = <int?, List<Group>>{};
  for (final g in groups) {
    byCategory.putIfAbsent(g.categoryId, () => []).add(g);
  }
  final categoryMap = {for (final c in categories) c.id: c};

  final sections = byCategory.entries.map((e) {
    final cat = e.key == null ? null : categoryMap[e.key];
    return InstrumentCategorySection(
      categoryId: e.key,
      name: cat?.name ?? noCategoryLabel,
      sortOrder: cat?.sortOrder,
      groups: sortGroupsBySortOrder(e.value),
    );
  }).toList();

  sections.sort((a, b) {
    final c = compareSortOrder(a.sortOrder, b.sortOrder);
    if (c != 0) return c;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sections;
}

/// Assign a global, 1-based sort_order following section order and the order
/// inside each section. Ionic: updateGlobalSortOrder().
Map<int, int> computeGlobalSortOrder(List<InstrumentCategorySection> sections) {
  final result = <int, int>{};
  var order = 1;
  for (final section in sections) {
    for (final g in section.groups) {
      if (g.id != null) result[g.id!] = order;
      order++;
    }
  }
  return result;
}

/// Reorder sections to follow the given category order (ids). Sections whose
/// category is not in [orderedCategoryIds] (e.g. "Ohne Kategorie") keep their
/// relative order at the end.
List<InstrumentCategorySection> reorderSectionsByCategories(
  List<InstrumentCategorySection> sections,
  List<int?> orderedCategoryIds,
) {
  final indexOf = {
    for (var i = 0; i < orderedCategoryIds.length; i++) orderedCategoryIds[i]: i
  };
  final original = {for (var i = 0; i < sections.length; i++) sections[i]: i};
  final list = [...sections];
  list.sort((a, b) {
    final c = compareSortOrder(indexOf[a.categoryId], indexOf[b.categoryId]);
    if (c != 0) return c;
    return original[a]!.compareTo(original[b]!); // stable for the rest
  });
  return list;
}
