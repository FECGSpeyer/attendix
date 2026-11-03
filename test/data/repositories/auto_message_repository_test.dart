import 'dart:io';

import 'package:attendix/data/models/auto_message/auto_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// Automatische Nachrichten (Ionic 4.18): source analysis of the repository
/// plus the placeholder helper used for personalised messages.
void main() {
  final src = File('lib/data/repositories/auto_message_repository.dart').readAsStringSync();

  /// Body of every `supabase.from('<table>')` chain up to its terminating `;`.
  List<(String, String)> queries() => RegExp(r"\.from\('(\w+)'\)([\s\S]*?);")
      .allMatches(src)
      .map((m) => (m.group(1)!, m.group(2)!))
      .toList();

  group('Multi-Tenant Security - AutoMessageRepository', () {
    test('every table query filters by tenantId', () {
      final qs = queries();
      expect(qs, isNotEmpty);
      for (final (table, body) in qs) {
        final filtered =
            body.contains("'tenantId'") || body.contains("'attendance.tenantId'");
        expect(filtered, isTrue, reason: '$table query without tenantId filter');
      }
    });

    test('updates and deletes filter by id and tenantId', () {
      for (final (table, body) in queries()) {
        if (!body.contains('.update(') && !body.contains('.delete(')) continue;
        expect(body, contains(".eq('id',"), reason: table);
        expect(body, contains(".eq('tenantId', currentTenantId)"), reason: table);
      }
    });

    test('inserts stamp the current tenant', () {
      for (final (table, body) in queries()) {
        if (!body.contains('.insert(')) continue;
        expect(body, contains('currentTenantId'), reason: table);
      }
    });

    test('all mutations are demo guarded', () {
      for (final name in [
        'saveRule',
        'setEnabled',
        'deleteRule',
        'suspend',
        'unsuspend',
        'submitResponse',
        'decideResponse',
      ]) {
        final start = src.indexOf(RegExp('Future<[^>]*>+ $name\\('));
        expect(start, isNot(-1), reason: name);
        final head = src.substring(start, start + 200);
        expect(head, contains('ensureNotDemo('), reason: name);
      }
    });
  });

  group('fillPlaceholders', () {
    test('replaces known placeholders and keeps unknown ones', () {
      expect(
        fillPlaceholders('Hallo {vorname}, {unbekannt}', {'vorname': 'Anna'}),
        'Hallo Anna, {unbekannt}',
      );
    });

    test('escapes values in HTML mode', () {
      expect(
        fillPlaceholders('<p>{vorname}</p>', {'vorname': '<b>A&B</b>'}, html: true),
        '<p>&lt;b&gt;A&amp;B&lt;/b&gt;</p>',
      );
    });
  });
}
