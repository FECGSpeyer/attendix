import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOL_FIX7: merging a pending registration into an existing person loads
/// both attendance histories completely and only deletes the source person
/// when every row was transferred.
void main() {
  final source =
      File('lib/data/repositories/player_repository.dart').readAsStringSync();

  /// Body of a method: from its signature up to the next method doc comment.
  String body(String name) {
    final start = source.indexOf(RegExp('(Future<[^>]*>+|void|bool) $name\\('));
    expect(start, isNot(-1), reason: 'method $name not found');
    final next = source.indexOf('\n  ///', start + 1);
    return source.substring(start, next == -1 ? source.length : next);
  }

  group('Multi-Tenant Security - merge persons (SOL_FIX7)', () {
    test('both attendance histories are loaded with fetchAllPages, ordered by id', () {
      final reassign = body('_reassignPersonAttendances');
      expect(RegExp(r'_personAttendanceRows\(').allMatches(reassign).length, 2);
      expect(reassign, isNot(contains(".select('id, attendance_id')\n        .eq('person_id', fromId);")));
      final rows = body('_personAttendanceRows');
      expect(rows, contains('fetchAllPages<Map<String, dynamic>>'));
      expect(rows, contains(".order('id', ascending: true)"));
      expect(rows, contains('.range(from, to)'));
    });

    test('writes are the Ionic writes (delete conflicts, re-point rest), chunked', () {
      final reassign = body('_reassignPersonAttendances');
      final del = reassign.indexOf('.delete()');
      final upd = reassign.indexOf(".update({'person_id': toId})");
      expect(del, greaterThan(0));
      expect(upd, greaterThan(del));
      expect(RegExp(r"\.inFilter\('id', chunk\)").allMatches(reassign).length, 2);
      expect(RegExp(r"\.eq\('person_id', fromId\)").allMatches(reassign).length, 2);
    });

    test('source person is deleted only after the transfer was verified', () {
      final merge = body('mergePendingPlayerIntoExisting');
      final transfer = merge.indexOf('_reassignPersonAttendances(pendingId, targetId)');
      final absences = merge.indexOf(".from('player_absences')");
      final verify = merge.indexOf('_ensureNothingLeftToTransfer(');
      final adopt = merge.indexOf("'appId': pending.appId");
      final delete = merge.indexOf(".from('player')\n          .delete()");
      expect(transfer, greaterThan(0));
      expect(absences, greaterThan(transfer));
      expect(verify, greaterThan(absences));
      expect(adopt, greaterThan(verify), reason: 'abort before adopting the account');
      expect(delete, greaterThan(adopt));
      // No catch around the verification: a failure aborts the whole merge.
      expect(merge.substring(verify, adopt), isNot(contains('catch')));
    });

    test('verification checks attendances and tenant-scoped absences', () {
      final check = body('_ensureNothingLeftToTransfer');
      expect(check, contains(".from('person_attendances')"));
      expect(check, contains(".from('player_absences')"));
      expect(check, contains(".eq('tenant_id', currentTenantId)"));
      expect(check, contains('throw RepositoryException('));
    });
  });
}
