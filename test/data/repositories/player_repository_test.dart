import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Security tests for PlayerRepository
///
/// These tests verify that ALL operations include tenantId filtering
/// to prevent cross-tenant data access.
///
/// Security Model:
/// - SELECT: Must have .eq('tenantId', currentTenantId) OR targetTenantId (handover)
/// - UPDATE: Must have .eq('tenantId', currentTenantId)
/// - DELETE: Must have .eq('tenantId', currentTenantId)
/// - INSERT: Must set tenantId in the data object (not as filter)
void main() {
  late String playerRepoSource;

  setUpAll(() {
    final file = File('lib/data/repositories/player_repository.dart');
    playerRepoSource = file.readAsStringSync();
  });

  group('Multi-Tenant Security - PlayerRepository', () {
    test('createPlayer sets tenantId in data', () {
      // INSERT operations set tenantId in the data, not as filter
      expect(
        playerRepoSource,
        contains("data['tenantId'] = currentTenantId"),
        reason: 'createPlayer must set tenantId in insert data',
      );
    });

    group('Write Operations - CRITICAL', () {
      test('all UPDATE operations on player table include tenantId filter', () {
        // Find all UPDATE operations
        final updateQueries = RegExp(
          r"supabase[^;]*\.from\('player'\)[^;]*\.update\([^;]+",
          multiLine: true,
        ).allMatches(playerRepoSource);

        expect(updateQueries, isNotEmpty, reason: 'Should have update queries');

        for (final match in updateQueries) {
          final query = match.group(0)!;
          // LOGIC_PEOPLE: the handover reactivates a row in the explicit
          // target tenant (cross-tenant by design, Ionic handoverPerson).
          expect(
            query.contains(".eq('tenantId', currentTenantId)") ||
                query.contains(".eq('tenantId', targetTenantId)"),
            isTrue,
            reason: 'UPDATE query missing tenantId filter:\n$query',
          );
        }
      });

      test('all DELETE operations on player table include tenantId filter', () {
        // Find all DELETE operations
        final deleteQueries = RegExp(
          r"supabase[^;]*\.from\('player'\)[^;]*\.delete\(\)[^;]+",
          multiLine: true,
        ).allMatches(playerRepoSource);

        expect(deleteQueries, isNotEmpty, reason: 'Should have delete queries');

        for (final match in deleteQueries) {
          final query = match.group(0)!;
          expect(
            query,
            contains(".eq('tenantId', currentTenantId)"),
            reason: 'DELETE query missing tenantId filter:\n$query',
          );
        }
      });
    });

    group('Read Operations', () {
      test('all SELECT operations include a tenantId filter', () {
        // Find SELECT operations (excluding insert chains)
        final selectQueries = RegExp(
          r"supabase[^;]*\.from\('player'\)\s*\n?\s*\.select\([^;]+",
          multiLine: true,
        ).allMatches(playerRepoSource);

        // Filter out INSERT chains (they have .insert before .select)
        final readQueries = selectQueries.where((m) {
          final query = m.group(0)!;
          return !query.contains('.insert(');
        }).toList();

        expect(readQueries, isNotEmpty, reason: 'Should have select queries');

        for (final match in readQueries) {
          final query = match.group(0)!;
          // Must have EITHER currentTenantId OR targetTenantId (for handover checks)
          final hasTenantFilter =
              query.contains(".eq('tenantId', currentTenantId)") ||
              query.contains(".eq('tenantId', targetTenantId)");
          expect(
            hasTenantFilter,
            isTrue,
            reason: 'SELECT query missing tenantId filter:\n$query',
          );
        }
      });
    });

    group('Core Mutation Methods', () {
      test('deletePlayer has both id and tenantId filter', () {
        final section = _extractMethodBody(playerRepoSource, 'deletePlayer');
        expect(section, isNotNull, reason: 'deletePlayer should exist');
        expect(section, contains(".eq('id', playerId)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('updatePlayer has both id and tenantId filter', () {
        final section = _extractMethodBody(playerRepoSource, 'updatePlayer');
        expect(section, isNotNull, reason: 'updatePlayer should exist');
        expect(section, contains(".eq('id', player.id!)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('updatePlayerFields includes tenantId filter', () {
        final section = _extractMethodBody(playerRepoSource, 'updatePlayerFields');
        expect(section, isNotNull, reason: 'updatePlayerFields should exist');
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('archivePlayer has both id and tenantId filter', () {
        final section = _extractMethodBody(playerRepoSource, 'archivePlayer');
        expect(section, isNotNull);
        expect(section, contains(".eq('id', player.id!)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('reactivatePlayer has both id and tenantId filter', () {
        final section = _extractMethodBody(playerRepoSource, 'reactivatePlayer');
        expect(section, isNotNull);
        expect(section, contains(".eq('id', player.id!)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('pausePlayer has both id and tenantId filter', () {
        final section = _extractMethodBody(playerRepoSource, 'pausePlayer');
        expect(section, isNotNull);
        expect(section, contains(".eq('id', player.id!)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('unpausePlayer has both id and tenantId filter', () {
        final section = _extractMethodBody(playerRepoSource, 'unpausePlayer');
        expect(section, isNotNull);
        expect(section, contains(".eq('id', player.id!)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('approvePlayer has both id and tenantId filter', () {
        final section = _extractMethodBody(playerRepoSource, 'approvePlayer');
        expect(section, isNotNull);
        expect(section, contains(".eq('id', player.id!)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('declinePlayer has both id and tenantId filter', () {
        final section = _extractMethodBody(playerRepoSource, 'declinePlayer');
        expect(section, isNotNull);
        expect(section, contains(".eq('id', player.id!)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('updatePlayerInstrument has both id and tenantId filter', () {
        final section = _extractMethodBody(playerRepoSource, 'updatePlayerInstrument');
        expect(section, isNotNull);
        expect(section, contains(".eq('id', player.id!)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('getPlayersByInstrument filters by tenantId and instrument', () {
        final section = _extractMethodBody(playerRepoSource, 'getPlayersByInstrument');
        expect(section, isNotNull, reason: 'getPlayersByInstrument should exist');
        expect(section, contains(".eq('instrument', instrumentId)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('getChildrenForParent filters by tenantId and parent_id', () {
        final section = _extractMethodBody(playerRepoSource, 'getChildrenForParent');
        expect(section, isNotNull, reason: 'getChildrenForParent should exist');
        expect(section, contains(".eq('tenantId', currentTenantId)"));
        expect(section, contains(".eq('parent_id', parentId)"));
        expect(
          section,
          contains(".isFilter('pending', false)"),
          reason: 'getChildrenForParent must exclude pending players '
              '(Ionic: pending IS false; approved players have pending=false)',
        );
        expect(
          section,
          contains(".isFilter('left', null)"),
          reason: 'getChildrenForParent must exclude left players',
        );
      });
    });

    group('Handover Operations', () {
      test('handoverPlayer sets target tenantId for new player', () {
        expect(
          playerRepoSource,
          contains("'tenantId': targetTenantId"),
          reason: 'Handover should set target tenantId for new player',
        );
      });

      test('handoverPlayer updates source player with currentTenantId', () {
        final section = _extractMethodBody(playerRepoSource, 'handoverPlayer');
        expect(section, isNotNull);
        expect(
          section,
          contains(".eq('tenantId', currentTenantId)"),
          reason: 'Source player update must use currentTenantId',
        );
      });
    });

    group('Helper Operations', () {
      test('removeFromUpcomingAttendances filters attendance by tenantId', () {
        final section = _extractMethodBody(playerRepoSource, 'removeFromUpcomingAttendances');
        expect(section, isNotNull);
        expect(
          section,
          contains(".eq('tenantId', currentTenantId)"),
          reason: 'removeFromUpcomingAttendances must filter attendances by tenantId',
        );
      });

      test('addToUpcomingAttendances filters attendance by tenantId', () {
        final section = _extractMethodBody(playerRepoSource, 'addToUpcomingAttendances');
        expect(section, isNotNull);
        expect(
          section,
          contains(".eq('tenantId', currentTenantId)"),
          reason: 'addToUpcomingAttendances must filter attendances by tenantId',
        );
      });

      test('checkAndUnpausePlayers filters by tenantId', () {
        final section = _extractMethodBody(playerRepoSource, 'checkAndUnpausePlayers');
        expect(section, isNotNull);
        // Should have tenantId filter
        expect(
          section,
          contains(".eq('tenantId', currentTenantId)"),
          reason: 'checkAndUnpausePlayers must filter by tenantId',
        );
      });
    });

    group('Summary Statistics', () {
      test('high tenantId filter coverage', () {
        // Count all queries on player table
        final allPlayerQueries = RegExp(
          r"\.from\('player'\)",
        ).allMatches(playerRepoSource).length;

        // Count queries with tenantId filter (current or target)
        final withCurrentTenant = RegExp(
          r"\.from\('player'\)[^;]*\.eq\('tenantId',\s*currentTenantId\)",
          multiLine: true,
        ).allMatches(playerRepoSource).length;

        final withTargetTenant = RegExp(
          r"\.from\('player'\)[^;]*\.eq\('tenantId',\s*targetTenantId\)",
          multiLine: true,
        ).allMatches(playerRepoSource).length;

        final insertWithTenant = playerRepoSource.contains("data['tenantId'] = currentTenantId")
            ? 1
            : 0;

        final handoverInsertWithTenant = playerRepoSource.contains("'tenantId': targetTenantId")
            ? 1
            : 0;

        final totalCovered = withCurrentTenant + withTargetTenant + insertWithTenant + handoverInsertWithTenant;

        // Log for visibility
        // ignore: avoid_print
        print('Total player queries: $allPlayerQueries');
        // ignore: avoid_print
        print('With currentTenantId: $withCurrentTenant');
        // ignore: avoid_print
        print('With targetTenantId: $withTargetTenant');
        // ignore: avoid_print
        print('Insert with tenant: $insertWithTenant');
        // ignore: avoid_print
        print('Handover insert: $handoverInsertWithTenant');
        // ignore: avoid_print
        print('Total covered: $totalCovered');

        // At least 80% coverage
        final coverage = totalCovered / allPlayerQueries;
        expect(
          coverage,
          greaterThanOrEqualTo(0.8),
          reason: 'Expected at least 80% tenantId coverage, got ${(coverage * 100).toStringAsFixed(1)}%',
        );
      });
    });
  });
}

/// Extract method body from source code (finds method and extracts until next method)
String? _extractMethodBody(String source, String methodName) {
  // Find method declaration. Supports up to two levels of nested generics
  // in the return type (e.g. Future<List<Map<String, dynamic>>>) by allowing
  // optional nested `<...>` groups, while restricting matches to a single line
  // so the engine cannot greedily span an earlier method's signature.
  final methodStart = RegExp(
    '(Future<[^\\n>]*(?:<[^\\n>]*(?:<[^\\n>]*>[^\\n>]*)?>[^\\n>]*)?>|void)\\s+$methodName\\s*[(<]',
  ).firstMatch(source);

  if (methodStart == null) return null;

  final startIndex = methodStart.start;

  // Find the opening brace of the method body (skip parameter block braces)
  int braceIndex = startIndex;
  int parenCount = 0;
  bool foundMethodBrace = false;

  for (int i = startIndex; i < source.length && !foundMethodBrace; i++) {
    final char = source[i];
    if (char == '(' || char == '{' && parenCount > 0) {
      parenCount++;
    } else if (char == ')' || char == '}' && parenCount > 1) {
      parenCount--;
    } else if (char == '{' && parenCount == 0) {
      braceIndex = i;
      foundMethodBrace = true;
    }
  }

  if (!foundMethodBrace) return null;

  // Count braces to find method end
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
