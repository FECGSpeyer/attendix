// Sol review 6667108318: saving permissions together with files_shared in
// the demo account must be blocked before the first write.
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/utils/demo_guard.dart';
import 'package:attendix/data/models/role_permission/tenant_role_permission.dart';
import 'package:attendix/data/repositories/role_permission_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';

class _DemoRolePermissionRepository extends RolePermissionRepository {
  _DemoRolePermissionRepository(super.ref) {
    bindTenantId(1);
  }

  final saved = <String>[];

  @override
  void ensureNotDemo(String operation) => throw DemoModeException(operation);

  @override
  Future<TenantRolePermission> updatePermission(TenantRolePermission permission) async {
    saved.add('perm:${permission.id}');
    return permission;
  }

  @override
  Future<void> updateFilesShared(bool filesShared) async {
    ensureNotDemo('updateFilesShared');
    saved.add('files_shared=$filesShared');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('demo: permissions + files_shared write nothing', () async {
    late _DemoRolePermissionRepository repo;
    final container = createTestContainer(
      tenant: TestFactories.createTenant(id: 1),
      overrides: [
        rolePermissionRepositoryWithTenantProvider.overrideWith((ref) {
          return repo = _DemoRolePermissionRepository(ref);
        }),
        rolePermissionsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container.read(rolePermissionNotifierProvider.notifier).save(
      const [TenantRolePermission(id: 7, tenantId: 1, role: 2)],
      filesShared: true,
    );

    expect(ok, isFalse);
    expect(repo.saved, isEmpty, reason: 'blocked before the first write');
    expect(container.read(rolePermissionNotifierProvider).error,
        isA<DemoModeException>());
  });
}
