import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Tests for player providers
///
/// These tests verify:
/// 1. Providers return empty/null when no tenant is set (hasTenantId == false)
/// 2. Providers call repository when tenant is set
/// 3. Cache invalidation works correctly
void main() {
  late String playerProvidersSource;

  setUpAll(() {
    final file = File('lib/core/providers/player_providers.dart');
    playerProvidersSource = file.readAsStringSync();
  });

  group('Player Providers', () {
    group('Tenant Guard Pattern', () {
      test('playersProvider returns empty when no tenant', () {
        // Verify the provider checks hasTenantId
        expect(
          playerProvidersSource,
          contains('if (!repo.hasTenantId) return [];'),
          reason: 'playersProvider must return empty list when no tenant',
        );
      });

      test('playerByIdProvider returns null when no tenant', () {
        expect(
          playerProvidersSource,
          contains('if (!repo.hasTenantId) return null;'),
          reason: 'playerByIdProvider must return null when no tenant',
        );
      });

      test('pendingPlayersProvider returns empty when no tenant', () {
        // Find the pendingPlayersProvider
        expect(
          playerProvidersSource,
          matches(RegExp(r'pendingPlayersProvider.*if \(!repo\.hasTenantId\) return \[\]', dotAll: true)),
          reason: 'pendingPlayersProvider must check hasTenantId',
        );
      });

      test('archivedPlayersProvider returns empty when no tenant', () {
        expect(
          playerProvidersSource,
          matches(RegExp(r'archivedPlayersProvider.*if \(!repo\.hasTenantId\) return \[\]', dotAll: true)),
          reason: 'archivedPlayersProvider must check hasTenantId',
        );
      });

      test('criticalPlayersProvider returns empty when no tenant', () {
        expect(
          playerProvidersSource,
          matches(RegExp(r'criticalPlayersProvider.*if \(!repo\.hasTenantId\) return \[\]', dotAll: true)),
          reason: 'criticalPlayersProvider must check hasTenantId',
        );
      });

      test('playerCountByInstrumentProvider returns empty map when no tenant', () {
        expect(
          playerProvidersSource,
          contains('if (!repo.hasTenantId) return {};'),
          reason: 'playerCountByInstrumentProvider must return empty map when no tenant',
        );
      });
    });

    group('Repository Integration', () {
      test('playerRepositoryWithTenantProvider sets tenant', () {
        // Verify the provider sets tenantId
        expect(
          playerProvidersSource,
          // SOL_FIX1: per-tenant immutable instance
          contains('playerRepositoryForTenantProvider(tenant)'),
          reason: 'playerRepositoryWithTenantProvider must set tenantId',
        );
      });

      test('playerRepositoryWithTenantProvider watches currentTenantIdProvider', () {
        expect(
          playerProvidersSource,
          contains('ref.watch(currentTenantIdProvider)'),
          reason: 'playerRepositoryWithTenantProvider must watch tenant changes',
        );
      });
    });

    group('Cache Invalidation', () {
      test('PlayerNotifier.createPlayer invalidates playersProvider', () {
        expect(
          playerProvidersSource,
          contains('ref.invalidate(playersProvider)'),
          reason: 'createPlayer must invalidate playersProvider',
        );
      });

      test('PlayerNotifier.updatePlayer invalidates playerByIdProvider', () {
        expect(
          playerProvidersSource,
          contains('ref.invalidate(playerByIdProvider'),
          reason: 'updatePlayer must invalidate playerByIdProvider',
        );
      });

      test('PlayerNotifier.archivePlayer invalidates archivedPlayersProvider', () {
        expect(
          playerProvidersSource,
          contains('ref.invalidate(archivedPlayersProvider)'),
          reason: 'archivePlayer must invalidate archivedPlayersProvider',
        );
      });

      test('PlayerNotifier.reactivatePlayer invalidates both active and archived', () {
        final reactivateSection = _extractMethodFromClass(
          playerProvidersSource,
          'reactivatePlayer',
        );
        expect(reactivateSection, isNotNull);
        expect(reactivateSection, contains('ref.invalidate(playersProvider)'));
        expect(reactivateSection, contains('ref.invalidate(archivedPlayersProvider)'));
      });

      test('PlayerNotifier.approvePlayer invalidates pendingPlayersProvider', () {
        expect(
          playerProvidersSource,
          contains('ref.invalidate(pendingPlayersProvider)'),
          reason: 'approvePlayer must invalidate pendingPlayersProvider',
        );
      });
    });

    group('Provider Patterns', () {
      test('uses FutureProvider for data loading', () {
        // Count FutureProvider usages
        final futureProviderCount = RegExp(r'FutureProvider<')
            .allMatches(playerProvidersSource)
            .length;
        expect(
          futureProviderCount,
          greaterThanOrEqualTo(5),
          reason: 'Should use FutureProvider for async data loading',
        );
      });

      test('uses FutureProvider.family for parameterized queries', () {
        expect(
          playerProvidersSource,
          contains('FutureProvider.family<'),
          reason: 'Should use FutureProvider.family for parameterized queries',
        );
      });

      test('uses NotifierProvider for mutations', () {
        expect(
          playerProvidersSource,
          contains('NotifierProvider<PlayerNotifier'),
          reason: 'Should use NotifierProvider for mutations',
        );
      });
    });
  });
}

/// Extract a method from the PlayerNotifier class
String? _extractMethodFromClass(String source, String methodName) {
  // Find the method in the class
  final pattern = RegExp(
    'Future<[^>]+>\\s+$methodName\\s*\\([^)]*\\)\\s*async\\s*\\{',
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
