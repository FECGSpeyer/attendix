import 'dart:io';

import 'package:attendix/data/repositories/message_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Extracts every Supabase query chain (`supabase.from('<table>')...;`) for [table].
List<String> _queries(String source, String table) {
  return RegExp("\\.from\\('$table'\\)[^;]*;", dotAll: true)
      .allMatches(source)
      .map((m) => m.group(0)!)
      .toList();
}

void main() {
  group('MessageRepository - Multi-Tenant Security', () {
    late String source;

    setUpAll(() {
      source = File('lib/data/repositories/message_repository.dart').readAsStringSync();
    });

    test('extends BaseRepository with TenantAwareRepository', () {
      expect(source, contains('extends BaseRepository with TenantAwareRepository'));
    });

    test('all messages queries include tenantId filter', () {
      final queries = _queries(source, 'messages');
      expect(queries, isNotEmpty);
      for (final q in queries) {
        // getMessageById: current tenant or another tenant of the user
        // (Ionic message-detail switches the instance); currentTenantId is
        // always part of tenantIds.
        final ok = q.contains(".eq('tenantId', currentTenantId)") ||
            q.contains(".inFilter('tenantId', tenantIds)");
        expect(ok, isTrue, reason: q);
      }
      expect(source, contains('final tenantIds = {currentTenantId, ...userTenantIds}.toList();'));
    });

    test('all message_recipients queries include tenantId filter', () {
      final queries = _queries(source, 'message_recipients');
      expect(queries, isNotEmpty);
      for (final q in queries) {
        // SOL_FIX3: paged queries capture `final tenantId = currentTenantId`.
        expect(
          q.contains(".eq('tenantId', currentTenantId)") ||
              q.contains(".eq('tenantId', tenantId)"),
          isTrue,
          reason: q,
        );
      }
    });

    test('DELETE filters by id AND tenantId', () {
      final deletes = _queries(source, 'messages').where((q) => q.contains('.delete()'));
      expect(deletes, isNotEmpty);
      for (final q in deletes) {
        expect(q, contains(".eq('id', messageId)"));
        expect(q, contains(".eq('tenantId', currentTenantId)"));
      }
    });

    test('no direct INSERT/UPDATE (rows are written by Edge Functions)', () {
      expect(source, isNot(contains('.insert(')));
      expect(source, isNot(contains('.update(')));
    });

    test('send-message calls pass the current tenant', () {
      final invokes = RegExp(r"functions\.invoke\([^;]*;", dotAll: true).allMatches(source);
      expect(invokes, hasLength(2));
      for (final m in invokes) {
        expect(m.group(0), contains("'tenantId': currentTenantId"));
      }
    });
  });

  group('MessageRepository.aggregateStats', () {
    test('counts read (in-app or email opened) and problems per message', () {
      final stats = MessageRepository.aggregateStats([
        {'message_id': 'a', 'read_at': '2026-01-01', 'email_opened_at': null, 'push_failed': false, 'email_failed': false},
        {'message_id': 'a', 'read_at': null, 'email_opened_at': '2026-01-01', 'push_failed': true, 'email_failed': false},
        {'message_id': 'a', 'read_at': null, 'email_opened_at': null, 'push_failed': false, 'email_failed': false},
        {'message_id': 'b', 'read_at': null, 'email_opened_at': null, 'push_failed': false, 'email_failed': true},
      ]);
      expect(stats['a']!.read, 2);
      expect(stats['a']!.problems, 1);
      expect(stats['b']!.read, 0);
      expect(stats['b']!.problems, 1);
    });

    test('empty input yields empty map', () {
      expect(MessageRepository.aggregateStats([]), isEmpty);
    });
  });
}
