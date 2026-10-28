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
      expect(perTenant.length,
          queries.length - kUserWideNotificationMethods.length);
      for (final q in perTenant) {
        final hasTenantFilter = q.contains(".eq('tenantId', currentTenantId)") ||
            q.contains(".eq('tenantId', n.tenantId)") ||
            q.contains(".inFilter('tenantId', tenantIds)");
        expect(hasTenantFilter, isTrue, reason: q);
      }
    });

    test('documented exception: user-wide methods reference RLS', () {
      // CLAUDE.md rule 1 exception (REVIEW_FIX3): these methods are keyed on
      // user_id only and rely on the RLS policies user_id = auth.uid().
      // Do not "fix" them back to a tenant filter (Ionic parity: entries of
      // left instances stay visible / are cleared too).
      for (final method in kUserWideNotificationMethods) {
        final start = source.indexOf('> $method(');
        expect(start, greaterThan(-1), reason: '$method missing');
        final docStart = source.lastIndexOf('\n\n', start);
        final doc = source.substring(docStart, start);
        expect(doc, contains('MULTI-TENANT EXCEPTION'), reason: method);
        expect(doc, contains('RLS'), reason: method);
        expect(doc, contains('auth.uid()'), reason: method);
      }
      // Nothing else may drop the tenant filter.
      final userWide = queries.where((q) => _isUserWide(q, source)).toList();
      expect(userWide, hasLength(kUserWideNotificationMethods.length));
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

/// Allow-list of the documented multi-tenant exception (CLAUDE.md rule 1):
/// cross-tenant feed methods keyed on `user_id` only, protected by the RLS
/// policies `user_id = auth.uid()` on `user_notifications`.
const kUserWideNotificationMethods = {
  'getAllNotifications',
  'markAllReadAllTenants',
  'deleteAllAllTenants',
};

/// True for the cross-tenant feed queries (method name precedes them).
bool _isUserWide(String query, String source) {
  final idx = source.indexOf(query);
  final head = source.substring(0, idx);
  final method = RegExp(r'Future<[^>]*>+\s+(\w+)\(').allMatches(head).last.group(1);
  return kUserWideNotificationMethods.contains(method);
}
