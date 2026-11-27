import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/repositories/base_repository.dart';
import 'package:attendix/data/repositories/group_repository.dart';
import 'package:attendix/features/instruments/data/catalog_import.dart';
import 'package:attendix/features/instruments/data/catalog_selection.dart';
import 'package:flutter_test/flutter_test.dart';

const flute = CatalogGroupDraft(
  key: 'flute',
  instrumentId: 'flute',
  name: 'Querflöte',
  categoryName: 'Holzbläser',
  synonyms: ['Flöte', 'Flute'],
  tuning: 'C',
  clefs: ['g'],
);
const bassFlute = CatalogGroupDraft(
  key: 'bass-flute',
  instrumentId: 'bass_flute',
  name: 'Bassflöte',
  categoryName: 'Holzbläser',
  synonyms: ['Bass flute'],
  tuning: 'C',
  clefs: ['g'],
);
const soprano = CatalogGroupDraft(
  key: 'soprano',
  instrumentId: 'soprano',
  name: 'Sopran',
  synonyms: ['Soprano'],
);

class FakeGroups extends Fake implements GroupRepository {
  List<Group> groups = [];
  List<GroupCategory> categories = [];
  final List<List<Map<String, dynamic>>> batches = [];
  bool demo = false;
  bool failCategory = false;
  bool loseBatchReply = false;
  void Function()? afterRead;
  void Function()? afterCategory;
  Role role = Role.admin;

  @override
  int get currentTenantId => 42;
  @override
  Role get currentUserRole => role;
  @override
  void ensureNotDemo(String operation) {
    if (demo) throw DemoModeException(operation);
  }

  @override
  Future<List<Group>> getGroups() async {
    afterRead?.call();
    return [...groups];
  }

  @override
  Future<List<GroupCategory>> getGroupCategories() async => [...categories];
  @override
  Future<GroupCategory> createGroupCategory({
    required String name,
    int? sortOrder,
  }) async {
    if (failCategory) throw StateError('category write failed');
    final category = GroupCategory(
      id: categories.length + 10,
      tenantId: 42,
      name: name,
      sortOrder: sortOrder,
    );
    categories.add(category);
    afterCategory?.call();
    return category;
  }

  @override
  Future<List<Group>> createGroups(List<Map<String, dynamic>> rows) async {
    batches.add(rows);
    final added = [
      for (var i = 0; i < rows.length; i++)
        Group.fromJson({
          ...rows[i],
          'id': groups.length + i + 100,
          'tenantId': 42,
        }),
    ];
    groups.addAll(added);
    if (loseBatchReply) throw StateError('reply lost after commit');
    return added;
  }
}

void main() {
  test(
    'preserves automatic alphabetical ordering of existing ensembles',
    () async {
      final repo =
          FakeGroups()
            ..groups = [const Group(id: 1, name: 'Oboe')]
            ..categories = [const GroupCategory(id: 10, name: 'Streicher')];
      await importCatalogGroups(repo, [flute]);
      expect(repo.groups.first.sortOrder, isNull);
      expect(repo.batches.single.single['sort_order'], isNull);
      expect(repo.categories.last.sortOrder, isNull);
    },
  );

  test('new families in an empty ensemble use musical order', () async {
    final repo = FakeGroups();
    await importCatalogGroups(repo, [
      flute,
      const CatalogGroupDraft(
        key: 'cello',
        instrumentId: 'cello',
        name: 'Violoncello',
        categoryName: 'Streicher',
      ),
    ]);
    expect(repo.categories.map((c) => c.name), ['Streicher', 'Holzbläser']);
    expect(repo.categories.map((c) => c.sortOrder), [1, 2]);
  });

  test(
    'skips an existing alias and reuses its category without altering it',
    () async {
      final repo =
          FakeGroups()
            ..groups = [
              const Group(
                id: 5,
                tenantId: 42,
                name: 'Flöte',
                categoryId: 3,
                sortOrder: 8,
                notes: 'Custom',
              ),
            ]
            ..categories = [
              const GroupCategory(
                id: 3,
                tenantId: 42,
                name: 'Holzbläser',
                sortOrder: 2,
              ),
            ];
      final original = repo.groups.first;
      final result = await importCatalogGroups(repo, [flute, bassFlute]);
      expect(result.added, 1);
      expect(result.skipped, 1);
      expect(repo.groups.first, original);
      expect(repo.categories, hasLength(1));
      expect(repo.batches.single.single['category'], 3);
      expect(repo.batches.single.single['sort_order'], 9);
    },
  );

  test(
    'all selected rows use one batch and a second import is a no-op',
    () async {
      final repo = FakeGroups();
      final first = await importCatalogGroups(repo, [flute, bassFlute]);
      final second = await importCatalogGroups(repo, [flute, bassFlute]);
      expect(first.added, 2);
      expect(second.added, 0);
      expect(second.skipped, 2);
      expect(repo.batches, hasLength(1));
      expect(repo.batches.single, hasLength(2));
      expect(repo.categories, hasLength(1));
    },
  );

  test('choir creates no category and leaves unknown tuning unset', () async {
    final repo = FakeGroups();
    await importCatalogGroups(repo, [soprano]);
    expect(repo.categories, isEmpty);
    expect(repo.batches.single.single['tuning'], isNull);
    expect(repo.batches.single.single['clefs'], isEmpty);
  });

  test('main leadership group never suppresses a catalog instrument', () async {
    final repo =
        FakeGroups()
          ..groups = [const Group(id: 1, name: 'Querflöte', maingroup: true)];
    final result = await importCatalogGroups(repo, [flute]);
    expect(result.added, 1);
  });

  test('duplicate drafts within the same selection are written once', () async {
    final repo = FakeGroups();
    final result = await importCatalogGroups(repo, [flute, flute]);
    expect(result.added, 1);
    expect(result.skipped, 1);
  });

  test(
    'blank names reject the entire selection before any category writes',
    () async {
      final repo = FakeGroups();
      await expectLater(
        importCatalogGroups(repo, [flute, bassFlute.copyWith(name: ' ')]),
        throwsArgumentError,
      );
      expect(repo.categories, isEmpty);
      expect(repo.batches, isEmpty);
    },
  );

  test('category failure never writes a partial instrument batch', () async {
    final repo = FakeGroups()..failCategory = true;
    await expectLater(
      importCatalogGroups(repo, [flute, bassFlute]),
      throwsStateError,
    );
    expect(repo.groups, isEmpty);
    expect(repo.batches, isEmpty);
  });

  test(
    'a lost success reply can be retried without duplicating groups',
    () async {
      final repo = FakeGroups()..loseBatchReply = true;
      await expectLater(
        importCatalogGroups(repo, [flute, bassFlute]),
        throwsStateError,
      );
      repo.loseBatchReply = false;
      final retry = await importCatalogGroups(repo, [flute, bassFlute]);
      expect(retry.added, 0);
      expect(repo.groups, hasLength(2));
      expect(repo.batches, hasLength(1));
    },
  );

  test(
    'tenant/account switch after read prevents category and instrument writes',
    () async {
      var current = true;
      final repo = FakeGroups()..afterRead = () => current = false;
      await expectLater(
        importCatalogGroups(repo, [flute], isCurrent: () => current),
        throwsA(isA<CatalogImportCancelled>()),
      );
      expect(repo.categories, isEmpty);
      expect(repo.batches, isEmpty);
    },
  );

  test(
    'scope change after category creation prevents the instrument batch',
    () async {
      var current = true;
      final repo = FakeGroups()..afterCategory = () => current = false;
      await expectLater(
        importCatalogGroups(repo, [flute], isCurrent: () => current),
        throwsA(isA<CatalogImportCancelled>()),
      );
      expect(repo.categories, hasLength(1));
      expect(repo.batches, isEmpty);
    },
  );

  test(
    'role revocation during a category write stops further mutations',
    () async {
      final repo = FakeGroups();
      repo.afterCategory = () => repo.role = Role.player;
      await expectLater(
        importCatalogGroups(repo, [flute]),
        throwsA(isA<RepositoryException>()),
      );
      expect(repo.batches, isEmpty);
    },
  );

  test('demo account fails before reading or writing', () async {
    final repo = FakeGroups()..demo = true;
    await expectLater(
      importCatalogGroups(repo, [flute]),
      throwsA(isA<DemoModeException>()),
    );
    expect(repo.batches, isEmpty);
    expect(repo.categories, isEmpty);
  });

  test('an empty selection performs no writes', () async {
    final repo = FakeGroups();
    final result = await importCatalogGroups(repo, []);
    expect(result.added, 0);
    expect(repo.batches, isEmpty);
  });
}
