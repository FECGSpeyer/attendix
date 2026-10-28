import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserNotificationRepository - Multi-Tenant Security', () {
    late String source;
    late List<String> queries;

    setUpAll(() {
      source = File('lib/data/repositories/user_notification_repository.dart').readAsStringSync();
      queries = RegExp(r"\.from\('user_notifications'\)[^;]*;", dotAll: true)
          .allMatches(source)
          .map((m) => m.group(0)!)
          .toList();
    });

    test('extends BaseRepository with TenantAwareRepository', () {
      expect(source, contains('extends BaseRepository with TenantAwareRepository'));
    });

    test('every query is scoped to the signed-in user', () {
      expect(queries, isNotEmpty);
      for (final q in queries) {
        expect(q, contains(".eq('user_id', _userId)"), reason: q);
      }
    });

    test('every query filters by tenantId (except the user-wide feed variants)', () {
      // Ionic getAllNotifications / *AllTenants: keyed on user_id only, so
      // entries of left instances stay visible.
      final perTenant = queries.where((q) => !_isUserWide(q, source)).toList();
      expect(perTenant.length, queries.length - 3);
      for (final q in perTenant) {
        final hasTenantFilter = q.contains(".eq('tenantId', currentTenantId)") ||
            q.contains(".eq('tenantId', n.tenantId)") ||
            q.contains(".inFilter('tenantId', tenantIds)");
        expect(hasTenantFilter, isTrue, reason: q);
      }
    });

    test('single-row mutations filter by id AND tenantId', () {
      final single = queries.where((q) => q.contains(".eq('id', n.id)")).toList();
      expect(single, hasLength(2)); // setRead + deleteOne
      for (final q in single) {
        expect(q, contains(".eq('tenantId', n.tenantId)"));
      }
    });

    test('no INSERT from the client (feed rows come from Edge Functions)', () {
      expect(source, isNot(contains('.insert(')));
    });
  });
}

/// True for the three cross-tenant feed queries (method name precedes them).
bool _isUserWide(String query, String source) {
  final idx = source.indexOf(query);
  final head = source.substring(0, idx);
  final method = RegExp(r'Future<[^>]*>+\s+(\w+)\(').allMatches(head).last.group(1);
  return const {'getAllNotifications', 'markAllReadAllTenants', 'deleteAllAllTenants'}.contains(method);
}
