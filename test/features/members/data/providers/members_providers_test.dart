import 'dart:io';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/features/members/data/providers/members_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../factories/test_factories.dart';

void main() {
  test('members_providers uses repositories, not supabaseClientProvider', () {
    final source = File(
      'lib/features/members/data/providers/members_providers.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('supabaseClientProvider')),
        reason: 'Repository-bypass forbidden in members_providers');
    expect(source, isNot(contains('tenant.id!')),
        reason: 'Force-unwrap on tenant.id! forbidden');
    expect(source, contains('RepositoryWithTenantProvider'),
        reason: 'Must use a *WithTenantProvider');
  });

  // P10_PEOPLE: Ionic members.page order (getModifiedPlayersForList without
  // main group): group sort_order, then name; ungrouped first; inside a
  // group by last name. The main group is not pulled to the top.
  test('buildMembersGroups orders groups like Ionic', () {
    final groups = [
      const Group(id: 1, name: 'Dirigent', maingroup: true, sortOrder: 9),
      const Group(id: 2, name: 'Sopran', sortOrder: 2),
      const Group(id: 3, name: 'Alt', sortOrder: 1),
    ];
    final people = [
      TestFactories.createPerson(id: 1, lastName: 'Zett', instrument: 2),
      TestFactories.createPerson(id: 2, lastName: 'Adam', instrument: 2),
      TestFactories.createPerson(id: 3, lastName: 'Chef', instrument: 1),
      TestFactories.createPerson(id: 4, lastName: 'Bern', instrument: 3),
      TestFactories.createPerson(id: 5, lastName: 'Los', instrument: 99),
    ];
    final result = buildMembersGroups(people, groups);
    expect(result.map((g) => g.groupId).toList(), [-1, 3, 2, 1]);
    expect(result[2].members.map((p) => p.lastName).toList(), ['Adam', 'Zett']);
  });
}
