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

    test('every query filters by tenantId', () {
      for (final q in queries) {
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
