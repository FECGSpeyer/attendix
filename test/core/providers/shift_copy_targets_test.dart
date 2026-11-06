import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/shift_providers.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:flutter_test/flutter_test.dart';

Tenant _tenant(int? id, Role role) => Tenant(
      id: id,
      shortName: 'T$id',
      longName: 'Tenant $id',
      role: role.value,
    );

void main() {
  group('shiftCopyTargets (Ionic ShiftPage linkedTenants)', () {
    final userTenants = [
      _tenant(1, Role.admin), // current instance
      _tenant(2, Role.admin), // linked, admin → allowed
      _tenant(3, Role.viewer), // linked, observer → excluded
      _tenant(4, Role.player), // linked, player → allowed (only viewer is excluded)
      _tenant(5, Role.admin), // other organisation → excluded
      _tenant(null, Role.admin), // no id → excluded
    ];

    test('keeps only linked instances, not as observer, not the current one',
        () {
      final targets = shiftCopyTargets(
        userTenants: userTenants,
        // tenant 6 is linked but the user is no member there
        linkedTenantIds: const [2, 3, 4, 6],
        currentTenantId: 1,
      );

      expect(targets.map((t) => t.id), [2, 4]);
    });

    test('is empty without organisation links or current instance', () {
      expect(
        shiftCopyTargets(
          userTenants: userTenants,
          linkedTenantIds: const [],
          currentTenantId: 1,
        ),
        isEmpty,
      );
      expect(
        shiftCopyTargets(
          userTenants: userTenants,
          linkedTenantIds: const [2, 4],
          currentTenantId: null,
        ),
        isEmpty,
      );
    });
  });
}
