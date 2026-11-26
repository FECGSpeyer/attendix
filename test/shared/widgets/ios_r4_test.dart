import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

void main() {
  test('tenants sort by longName (not by short name)', () {
    final chor = TestFactories.createTenant(id: 1, longName: 'Chor')
        .copyWith(shortName: 'ZZ');
    final orchester = TestFactories.createTenant(id: 2, longName: 'orchester')
        .copyWith(shortName: 'AA');
    final list = [orchester, chor]..sort(compareTenantLongNames);
    expect(list.map((t) => t.id), [1, 2]);
  });
}
