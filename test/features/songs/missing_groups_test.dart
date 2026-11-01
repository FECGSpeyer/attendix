import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/songs/presentation/utils/song_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

void main() {
  const strings = GroupCategory(id: 1, name: 'Streicher');
  const winds = GroupCategory(id: 2, name: 'Holzbläser');
  const groups = [
    Group(id: 1, name: 'Dirigent', maingroup: true),
    Group(id: 10, name: 'Violine 1', categoryId: 1),
    Group(id: 11, name: 'Violine 3', categoryId: 1),
    Group(id: 20, name: 'Flöte', categoryId: 2),
    Group(id: 21, name: 'Saxophon', categoryId: 2),
    Group(id: 30, name: 'Celesta'),
  ];

  String text(List<int> ids, {Map<int, int>? counts}) =>
      SongUtils.missingInstrumentsText(ids, groups, [strings, winds], playerCounts: counts);

  group('"Ohne …" with active players', () {
    test('without counts every group counts (Ionic)', () {
      expect(text([10, 20]), contains('Saxophon'));
      expect(text([10, 20]), contains('Sonstige')); // Celesta, a category of its own
    });

    test('groups nobody plays are not missing', () {
      final counts = {10: 8, 20: 3};
      expect(text([10, 20], counts: counts), isEmpty);
      expect(text([10], counts: counts), contains('Flöte'));
      expect(text([10], counts: counts), isNot(contains('Saxophon')));
    });

    test('a whole category is named by the played groups only', () {
      // Flöte is the only played wind group: missing it means "Ohne Flöte".
      final counts = {10: 8, 11: 0, 20: 3};
      expect(text([10], counts: counts), contains('Flöte'));
      expect(text([10], counts: counts), isNot(contains('Violine 3')));
    });

    test('empty counts (not loaded) fall back to every group', () {
      expect(text([10, 20], counts: const {}), contains('Saxophon'));
    });
  });

  group('missingGroupsPlayerCountsProvider', () {
    List<Person> players = [];

    ProviderContainer container(Role role) {
      final c = ProviderContainer(overrides: [
        currentRoleProvider.overrideWithValue(role),
        playersProvider.overrideWith((ref) async => players),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      players = [
        TestFactories.createPerson(id: 1, tenantId: 10, instrument: 10),
        TestFactories.createPerson(id: 2, tenantId: 10, instrument: 10),
        TestFactories.createPerson(id: 3, tenantId: 10, instrument: 20),
        TestFactories.createPerson(id: 4, tenantId: 10),
      ];
    });

    test('counts the active players per group for conductors and helpers', () async {
      for (final role in [Role.admin, Role.helper, Role.voiceLeaderHelper]) {
        final c = container(role);
        c.listen(missingGroupsPlayerCountsProvider, (_, __) {});
        expect(c.read(missingGroupsPlayerCountsProvider), isNull, reason: 'list still loading');
        await c.read(playersProvider.future);
        expect(c.read(missingGroupsPlayerCountsProvider), {10: 2, 20: 1}, reason: '$role');
      }
    });

    test('other roles keep every group (Ionic)', () async {
      final c = container(Role.player);
      await c.read(playersProvider.future);
      expect(c.read(missingGroupsPlayerCountsProvider), isNull);
    });

    test('a player change (refreshed player list) updates the counts', () async {
      final c = container(Role.admin);
      c.listen(missingGroupsPlayerCountsProvider, (_, __) {});
      await c.read(playersProvider.future);
      expect(c.read(missingGroupsPlayerCountsProvider), {10: 2, 20: 1});

      // Saxophon (21) joins, a Flöte player (20) is archived.
      players = [
        TestFactories.createPerson(id: 1, tenantId: 10, instrument: 10),
        TestFactories.createPerson(id: 2, tenantId: 10, instrument: 10),
        TestFactories.createPerson(id: 5, tenantId: 10, instrument: 21),
      ];
      c.invalidate(playersProvider);
      await c.read(playersProvider.future);
      expect(c.read(missingGroupsPlayerCountsProvider), {10: 2, 21: 1});
    });
  });
}
