import 'package:attendix/core/utils/instrument_sort.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final categories = [
    const GroupCategory(id: 1, name: 'Holz', sortOrder: 2),
    const GroupCategory(id: 2, name: 'Blech', sortOrder: 1),
  ];
  final groups = [
    const Group(id: 10, name: 'Flöte', categoryId: 1, sortOrder: 2),
    const Group(id: 11, name: 'Oboe', categoryId: 1, sortOrder: 1),
    const Group(id: 12, name: 'Trompete', categoryId: 2),
    const Group(id: 13, name: 'Horn', categoryId: 2),
    const Group(id: 14, name: 'Pauke'),
  ];

  test('compareSortOrder puts values before nulls', () {
    expect(compareSortOrder(1, 2), lessThan(0));
    expect(compareSortOrder(1, null), lessThan(0));
    expect(compareSortOrder(null, 1), greaterThan(0));
    expect(compareSortOrder(null, null), 0);
  });

  test('groups by category in category sort order', () {
    final sections = groupInstrumentsByCategory(groups, categories);
    expect(sections.map((s) => s.name), ['Blech', 'Holz', 'Ohne Kategorie']);
    // inside category: sort_order first, then name
    expect(sections[1].groups.map((g) => g.name), ['Oboe', 'Flöte']);
    expect(sections[0].groups.map((g) => g.name), ['Horn', 'Trompete']);
  });

  test('computeGlobalSortOrder numbers instruments across sections', () {
    final sections = groupInstrumentsByCategory(groups, categories);
    expect(computeGlobalSortOrder(sections), {
      13: 1,
      12: 2,
      11: 3,
      10: 4,
      14: 5,
    });
  });

  test('reorderSectionsByCategories follows the new category order', () {
    final sections = groupInstrumentsByCategory(groups, categories);
    final reordered = reorderSectionsByCategories(sections, [1, 2]);
    expect(reordered.map((s) => s.categoryId), [1, 2, null]);
  });
}
