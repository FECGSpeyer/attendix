// TENANT_BIND: every `*RepositoryWithTenantProvider` returns an immutable
// per-tenant instance (`*RepositoryForTenantProvider` + `bindTenantId`)
// instead of mutating a shared repository on tenant switch.
import 'dart:io';

import 'package:attendix/core/providers/duty_providers.dart';
import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Source of a top-level provider definition `final <name> = ...;` up to the
/// closing `});`.
String _definition(String source, String name) {
  final start = source.indexOf(RegExp('final $name\\s*='));
  expect(start, isNot(-1), reason: '$name not found');
  final end = source.indexOf('\n});', start);
  return source.substring(start, end == -1 ? source.length : end);
}

void main() {
  final providerFiles = Directory('lib/core/providers')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  final repoFiles = Directory('lib/data/repositories')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  final allSource = [...providerFiles, ...repoFiles]
      .map((f) => f.readAsStringSync())
      .join('\n');

  group('Multi-Tenant Security: TENANT_BIND source scan', () {
    final withTenant = <String, String>{}; // provider name → file source
    for (final f in providerFiles) {
      final src = f.readAsStringSync();
      for (final m in RegExp(r'final (\w+RepositoryWithTenantProvider)\s*=')
          .allMatches(src)) {
        withTenant[m.group(1)!] = src;
      }
    }

    test('finds all WithTenant providers', () {
      expect(withTenant.length, greaterThanOrEqualTo(32)); // meeting repository removed (#21)
    });

    test('every WithTenant provider returns its bound per-tenant instance', () {
      for (final entry in withTenant.entries) {
        final name = entry.key;
        final base = name.replaceFirst('WithTenantProvider', '');
        final body = _definition(entry.value, name);
        expect(body, contains('ref.watch(currentTenantIdProvider)'),
            reason: '$name must watch the current tenant');
        expect(body, contains('${base}ForTenantProvider('),
            reason: '$name must return ${base}ForTenantProvider(tenant)');
        expect(body, isNot(contains('setTenantId(')),
            reason: '$name must not mutate a shared repository');
      }
    });

    test('every ForTenant family binds its tenant immutably', () {
      for (final name in withTenant.keys) {
        final family = name.replaceFirst('WithTenant', 'ForTenant');
        var body = _definition(allSource, family);
        expect(body, contains('Provider.family<'), reason: family);
        // SOL_FIX15: the family delegates to a per (tenant, account)
        // instance, which binds the tenant.
        final account = '_${family.replaceFirst('ForTenant', 'ForAccount')}';
        if (body.contains('$account(')) {
          expect(body, contains('ref.watch(currentAuthUserIdProvider)'),
              reason: family);
          body = _definition(allSource, account);
          expect(body, contains('Provider.family<'), reason: account);
        }
        expect(body, contains('.bindTenantId('), reason: family);
        expect(body, isNot(contains('setTenantId(')), reason: family);
      }
    });

    test('no code outside the mixin switches a repository tenant', () {
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (f.path.endsWith('base_repository.dart')) continue;
        expect(f.readAsStringSync(), isNot(contains('.setTenantId(')),
            reason: '${f.path} must use a bound instance (bindTenantId / '
                '*RepositoryForTenantProvider) instead of setTenantId');
      }
    });
  });

  group('Multi-Tenant Security: TENANT_BIND behaviour', () {
    test('tenant switch A→B yields new instances, A keeps its tenant', () {
      var tenant = 1;
      final container = ProviderContainer(overrides: [
        currentTenantIdProvider.overrideWith((ref) => tenant),
      ]);
      addTearDown(container.dispose);

      final planA = container.read(planRepositoryWithTenantProvider);
      final dutyA = container.read(dutyRepositoryWithTenantProvider);
      final protocolA = container.read(protocolRepositoryWithTenantProvider);

      tenant = 2;
      container.invalidate(currentTenantIdProvider);

      final planB = container.read(planRepositoryWithTenantProvider);
      final dutyB = container.read(dutyRepositoryWithTenantProvider);
      final protocolB = container.read(protocolRepositoryWithTenantProvider);

      expect(identical(planA, planB), isFalse);
      expect(identical(dutyA, dutyB), isFalse);
      expect(identical(protocolA, protocolB), isFalse);
      expect(planA.currentTenantId, 1);
      expect(dutyA.currentTenantId, 1);
      expect(protocolA.currentTenantId, 1);
      expect(planB.currentTenantId, 2);
      expect(dutyB.currentTenantId, 2);
      expect(protocolB.currentTenantId, 2);

      // Switching back reuses the bound tenant-1 instance.
      tenant = 1;
      container.invalidate(currentTenantIdProvider);
      expect(identical(container.read(planRepositoryWithTenantProvider), planA),
          isTrue);
    });

    test('bound instance refuses a different tenant', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final duty = container.read(dutyRepositoryForTenantProvider(7));
      expect(duty.currentTenantId, 7);
      expect(() => duty.setTenantId(8), throwsStateError);
      expect(duty.currentTenantId, 7);
    });

    test('no tenant → instance without tenant (tenant guard)', () {
      final container = ProviderContainer(overrides: [
        currentTenantIdProvider.overrideWith((ref) => null),
      ]);
      addTearDown(container.dispose);
      expect(container.read(planRepositoryWithTenantProvider).hasTenantId,
          isFalse);
      expect(container.read(dutyRepositoryWithTenantProvider).hasTenantId,
          isFalse);
      expect(container.read(protocolRepositoryWithTenantProvider).hasTenantId,
          isFalse);
    });
  });
}
