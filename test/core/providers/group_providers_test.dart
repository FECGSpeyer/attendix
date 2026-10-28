import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Tests for group providers
///
/// These tests verify:
/// 1. Providers return empty/null when no tenant is set (hasTenantId == false)
/// 2. Providers call repository when tenant is set
/// 3. Cache invalidation works correctly after mutations
/// 4. keepAlive is used correctly for stable data
void main() {
  late String groupProvidersSource;

  setUpAll(() {
    final file = File('lib/core/providers/group_providers.dart');
    groupProvidersSource = file.readAsStringSync();
  });

  group('Group Providers', () {
    group('Tenant Guard Pattern', () {
      test('groupsProvider returns empty when no tenant', () {
        expect(
          groupProvidersSource,
          matches(RegExp(r'groupsProvider.*if \(!repo\.hasTenantId\) return \[\]',
              dotAll: true)),
          reason: 'groupsProvider must return empty list when no tenant',
        );
      });

      test('groupsMapProvider returns empty map when no tenant', () {
        expect(
          groupProvidersSource,
          contains('if (!repo.hasTenantId) return {};'),
          reason: 'groupsMapProvider must return empty map when no tenant',
        );
      });

      test('mainGroupProvider returns null when no tenant', () {
        expect(
          groupProvidersSource,
          matches(RegExp(
              r'mainGroupProvider.*if \(!repo\.hasTenantId\) return null',
              dotAll: true)),
          reason: 'mainGroupProvider must return null when no tenant',
        );
      });

      test('groupCategoriesProvider returns empty when no tenant', () {
        expect(
          groupProvidersSource,
          matches(RegExp(
              r'groupCategoriesProvider.*if \(!repo\.hasTenantId\) return \[\]',
              dotAll: true)),
          reason: 'groupCategoriesProvider must check hasTenantId',
        );
      });
    });

    group('Repository Integration', () {
      test('groupRepositoryWithTenantProvider binds tenant', () {
        expect(
          groupProvidersSource,
          contains('groupRepositoryForTenantProvider(tenant)'),
          reason: 'groupRepositoryWithTenantProvider must use a bound '
              'per-tenant instance',
        );
        expect(groupProvidersSource, contains('repo.bindTenantId(key.tenantId!)'));
      });

      test('groupRepositoryWithTenantProvider watches currentTenantIdProvider',
          () {
        expect(
          groupProvidersSource,
          contains('ref.watch(currentTenantIdProvider)'),
          reason: 'groupRepositoryWithTenantProvider must watch tenant changes',
        );
      });
    });

    group('Cache Behavior', () {
      test('groupsProvider uses keepAlive for performance', () {
        expect(
          groupProvidersSource,
          matches(RegExp(r'groupsProvider.*ref\.keepAlive\(\)', dotAll: true)),
          reason: 'groupsProvider should use keepAlive for stable data',
        );
      });

      test('groupsMapProvider uses keepAlive for performance', () {
        expect(
          groupProvidersSource,
          matches(RegExp(r'groupsMapProvider.*ref\.keepAlive\(\)', dotAll: true)),
          reason: 'groupsMapProvider should use keepAlive for stable data',
        );
      });

      test('groupsProvider watches tenant changes for cache invalidation', () {
        // The provider should watch currentTenantIdProvider to invalidate
        // when tenant switches
        final groupsSection = _extractProviderBody(groupProvidersSource, 'groupsProvider');
        expect(groupsSection, isNotNull);
        expect(groupsSection, contains('ref.watch(currentTenantIdProvider)'));
      });
    });

    group('Cache Invalidation - Group Operations', () {
      test('createGroup invalidates groupsProvider', () {
        final section =
            _extractMethodFromClass(groupProvidersSource, 'createGroup');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(groupsProvider)'));
      });

      test('createGroup invalidates groupsMapProvider', () {
        final section =
            _extractMethodFromClass(groupProvidersSource, 'createGroup');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(groupsMapProvider)'));
      });

      test('updateGroup invalidates groupsProvider', () {
        final section =
            _extractMethodFromClass(groupProvidersSource, 'updateGroup');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(groupsProvider)'));
      });

      test('updateGroup invalidates groupsMapProvider', () {
        final section =
            _extractMethodFromClass(groupProvidersSource, 'updateGroup');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(groupsMapProvider)'));
      });

      test('deleteGroup invalidates groupsProvider', () {
        final section =
            _extractMethodFromClass(groupProvidersSource, 'deleteGroup');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(groupsProvider)'));
      });

      test('deleteGroup invalidates groupsMapProvider', () {
        final section =
            _extractMethodFromClass(groupProvidersSource, 'deleteGroup');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(groupsMapProvider)'));
      });
    });

    group('Cache Invalidation - Group Category Operations', () {
      test('createGroupCategory invalidates groupCategoriesProvider', () {
        final section =
            _extractMethodFromClass(groupProvidersSource, 'createGroupCategory');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(groupCategoriesProvider)'));
      });

      test('deleteGroupCategory invalidates groupCategoriesProvider', () {
        final section =
            _extractMethodFromClass(groupProvidersSource, 'deleteGroupCategory');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(groupCategoriesProvider)'));
      });
    });

    group('Provider Patterns', () {
      test('uses FutureProvider for data loading', () {
        final futureProviderCount =
            RegExp(r'FutureProvider<').allMatches(groupProvidersSource).length;
        expect(
          futureProviderCount,
          greaterThanOrEqualTo(4),
          reason: 'Should use FutureProvider for async data loading',
        );
      });

      test('uses NotifierProvider for mutations', () {
        expect(
          groupProvidersSource,
          contains('NotifierProvider<GroupNotifier'),
          reason: 'Should use NotifierProvider for mutations',
        );
      });
    });

    group('Error Handling', () {
      test('createGroup sets error state on failure', () {
        final section =
            _extractMethodFromClass(groupProvidersSource, 'createGroup');
        expect(section, isNotNull);
        expect(section, contains('AsyncValue.error(e, stack)'));
      });

      test('updateGroup sets error state on failure', () {
        final section =
            _extractMethodFromClass(groupProvidersSource, 'updateGroup');
        expect(section, isNotNull);
        expect(section, contains('AsyncValue.error(e, stack)'));
      });

      test('deleteGroup sets error state on failure', () {
        final section =
            _extractMethodFromClass(groupProvidersSource, 'deleteGroup');
        expect(section, isNotNull);
        expect(section, contains('AsyncValue.error(e, stack)'));
      });
    });
  });
}

/// Extract a method from the GroupNotifier class
String? _extractMethodFromClass(String source, String methodName) {
  final pattern = RegExp(
    'Future<[^>]*>\\s+$methodName\\s*\\([^)]*\\)\\s*async\\s*\\{',
  );
  final match = pattern.firstMatch(source);

  if (match == null) return null;

  final startIndex = match.start;
  int braceIndex = source.indexOf('{', match.end - 1);

  int braceCount = 0;
  int endIndex = braceIndex;

  for (int i = braceIndex; i < source.length; i++) {
    if (source[i] == '{') {
      braceCount++;
    } else if (source[i] == '}') {
      braceCount--;
      if (braceCount == 0) {
        endIndex = i + 1;
        break;
      }
    }
  }

  return source.substring(startIndex, endIndex);
}

/// Extract a FutureProvider body
String? _extractProviderBody(String source, String providerName) {
  final pattern = RegExp(
    'final\\s+$providerName\\s*=\\s*FutureProvider[^(]*\\([^)]*\\)\\s*async\\s*\\{',
  );
  final match = pattern.firstMatch(source);

  if (match == null) return null;

  final startIndex = match.start;
  int braceIndex = source.indexOf('{', match.end - 1);

  int braceCount = 0;
  int endIndex = braceIndex;

  for (int i = braceIndex; i < source.length; i++) {
    if (source[i] == '{') {
      braceCount++;
    } else if (source[i] == '}') {
      braceCount--;
      if (braceCount == 0) {
        endIndex = i + 1;
        break;
      }
    }
  }

  return source.substring(startIndex, endIndex);
}
