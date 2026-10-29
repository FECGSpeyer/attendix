import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Security tests for SignInOutRepository (self-service sign in / sign out).
///
/// Source-code analysis: every query on a tenant table filters by tenantId,
/// and every person_attendances mutation is validated first.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/data/repositories/sign_in_out_repository.dart').readAsStringSync();
  });

  String body(String method) {
    final start = source.indexOf(RegExp('\\s$method\\('));
    expect(start, isNot(-1), reason: '$method not found');
    final next = source.indexOf(RegExp(r'\n  (Future<|[A-Za-z<>?]+ get |///)'), start + 1);
    return source.substring(start, next == -1 ? source.length : next);
  }

  group('Multi-Tenant Security - SignInOutRepository', () {
    test('repository is tenant aware', () {
      expect(source, contains('extends BaseRepository with TenantAwareRepository'));
    });

    test('all SELECTs on the attendance table filter by tenantId', () {
      final queries = RegExp(
        r"\.from\('attendance'\)[^;]*;",
        multiLine: true,
      ).allMatches(source);
      expect(queries, isNotEmpty);
      for (final m in queries) {
        expect(m.group(0), contains(".eq('tenantId', currentTenantId)"),
            reason: 'attendance query without tenantId:\n${m.group(0)}');
      }
    });

    test('person_attendances reads join attendance and filter attendance.tenantId', () {
      final b = body('getPersonAttendances');
      expect(b, contains('attendance_id!inner'));
      expect(b, contains(".eq('attendance.tenantId', currentTenantId)"));
    });

    test('tenants.files_shared is read for the current tenant only', () {
      final b = body('getTenantFilesShared');
      expect(b, contains(".eq('id', currentTenantId)"));
    });

    for (final method in ['signIn', 'signOut', 'updateAttendanceNote', 'updateRegistrationAnswers']) {
      test('$method validates the person attendance before updating', () {
        expect(body(method), contains('_validatePersonAttendanceIds'),
            reason: '$method must validate ids against the tenant / own person');
      });
    }

    test('validation checks tenant or own appId', () {
      final b = body('_validatePersonAttendanceIds');
      expect(b, contains('currentTenantId'));
      expect(b, contains('appId'));
    });

    test('all person_attendances updates go through the validated helper', () {
      final updates = RegExp(r"\.from\('person_attendances'\)\s*\.update\(").allMatches(source);
      expect(updates.length, 1,
          reason: 'Only _updatePersonAttendances may update person_attendances directly');
      expect(body('_updatePersonAttendances'), contains("inFilter('id'"));
    });
  });
}
