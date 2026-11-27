
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/source_reader.dart';

/// RT-001/002/003: Force Unwrap auf tenant.id! und criticalRules! ohne null-Check
/// These tests verify that no force-unwrap on tenant.id! or criticalRules! exists
/// in the affected files (source code analysis pattern).
void main() {
  group('RT-001/002/003: No force-unwrap on tenant fields', () {
    test('rd_members_page.dart has no tenant.id! force-unwrap', () {
      final source = readDartLibrary('lib/features/people/presentation/pages/members_page.dart');

      expect(
        source.contains('tenant.id!'),
        isFalse,
        reason:
            'rd_members_page.dart still uses tenant.id! force-unwrap. '
            'Use local variable with null-check instead.',
      );
    });

    test('rd_person_page.dart has no tenant.id! force-unwrap', () {
      final source = readDartLibrary('lib/features/people/presentation/pages/person_page.dart');

      expect(
        source.contains('tenant.id!'),
        isFalse,
        reason:
            'rd_person_page.dart still uses tenant.id! force-unwrap. '
            'Use local variable with null-check instead.',
      );
    });

    test('rd_person_edit_page.dart has no tenant!.criticalRules! force-unwrap',
        () {
      final source = readDartLibrary('lib/features/people/presentation/pages/person_edit_page.dart');

      expect(
        source.contains('tenant!.criticalRules!'),
        isFalse,
        reason:
            'rd_person_edit_page.dart still uses tenant!.criticalRules! '
            'force-unwrap. Use local variable with null-check instead.',
      );
    });
  });
}
