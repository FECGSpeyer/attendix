// SOL_FIX19: Sol review of afa5b15 – a tenant setting saved for tenant A
// must not land in tenant B's local state when the user switches tenants
// while the save is still running.
import 'dart:async';
import 'dart:io';

import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/role_permission/tenant_role_permission.dart';
import 'package:attendix/data/repositories/role_permission_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';

/// Repository bound to one tenant whose files_shared update waits for
/// [gate] (delayed server reply).
class _DelayedRolePermissionRepository extends RolePermissionRepository {
  _DelayedRolePermissionRepository(super.ref, int tenantId) {
    bindTenantId(tenantId);
  }

  Completer<void>? gate;
  final saved = <String>[];

  @override
  Future<TenantRolePermission> updatePermission(TenantRolePermission permission) async {
    saved.add('perm:${permission.id}@$currentTenantId');
    return permission;
  }

  @override
  Future<void> updateFilesShared(bool filesShared) async {
    final g = gate;
    if (g != null) await g.future;
    saved.add('files_shared=$filesShared@$currentTenantId');
  }
}

void main() {
  final tenantA = TestFactories.createTenant(id: 1, shortName: 'A');
  final tenantB = TestFactories.createTenant(id: 2, shortName: 'B');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('updateTenantLocalIfCurrent', () {
    test('updates the current tenant from its current state', () async {
      final container = createTestContainer(tenant: tenantA);
      addTearDown(container.dispose);
      final notifier = container.read(currentTenantProvider.notifier);

      final updated = await notifier.updateTenantLocalIfCurrent(
          1, (current) => current.copyWith(filesShared: true));
      expect(updated, isTrue);
      expect(container.read(currentTenantProvider)?.id, 1);
      expect(container.read(currentTenantProvider)?.filesShared, isTrue);
    });

    test('leaves another tenant (and a cleared tenant) untouched', () async {
      final container = createTestContainer(tenant: tenantB);
      addTearDown(container.dispose);
      final notifier = container.read(currentTenantProvider.notifier);

      expect(
        await notifier.updateTenantLocalIfCurrent(
            1, (current) => current.copyWith(filesShared: true)),
        isFalse,
      );
      expect(container.read(currentTenantProvider), tenantB);

      await notifier.setTenantLocal(null);
      expect(
        await notifier.updateTenantLocalIfCurrent(
            2, (current) => current.copyWith(filesShared: true)),
        isFalse,
      );
      expect(container.read(currentTenantProvider), isNull);
    });
  });

  group('RolePermissionNotifier.save with a tenant switch', () {
    late _DelayedRolePermissionRepository repoA;
    late ProviderContainer container;

    setUp(() {
      container = createTestContainer(tenant: tenantA, overrides: [
        rolePermissionRepositoryWithTenantProvider.overrideWith((ref) {
          return repoA = _DelayedRolePermissionRepository(ref, 1);
        }),
        rolePermissionsProvider.overrideWith((ref) async => const []),
      ]);
    });

    tearDown(() => container.dispose());

    test('switch to B while A saves files_shared: B keeps its own value', () async {
      container.read(rolePermissionRepositoryWithTenantProvider);
      final gate = Completer<void>();
      repoA.gate = gate;

      final saving = container
          .read(rolePermissionNotifierProvider.notifier)
          .save(const [], filesShared: true);
      await pumpEventQueue();

      // User switches to tenant B while A's save is still waiting.
      await container.read(currentTenantProvider.notifier).setTenantLocal(tenantB);
      gate.complete();
      expect(await saving, isTrue);

      expect(repoA.saved, ['files_shared=true@1'], reason: 'saved for A');
      final current = container.read(currentTenantProvider);
      expect(current?.id, 2, reason: 'no switch back to A');
      expect(current?.filesShared, isFalse, reason: "A's value not copied into B");
    });

    test('no switch: the saved value reaches the local state of A', () async {
      final ok = await container
          .read(rolePermissionNotifierProvider.notifier)
          .save(const [], filesShared: true);
      expect(ok, isTrue);
      final current = container.read(currentTenantProvider);
      expect(current?.id, 1);
      expect(current?.filesShared, isTrue);
    });
  });

  test('tenant settings save paths never copy a stale tenant into the state', () {
    final copyInto = RegExp(r'setTenantLocal\(\s*\w+\.copyWith\(');
    final offenders = <String>[];
    for (final dir in ['lib/core', 'lib/features', 'lib/shared']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (copyInto.hasMatch(f.readAsStringSync())) offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Use updateTenantLocalIfCurrent(tenantId, ...) with the tenant '
            'id captured before the save.');

    for (final path in [
      'lib/core/providers/role_permission_providers.dart',
      'lib/features/settings/presentation/pages/extra_fields_page.dart',
      'lib/features/settings/presentation/pages/attendance_type_edit_page.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('updateTenantLocalIfCurrent('),
          reason: path);
    }
  });
}
