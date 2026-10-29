import 'package:attendix/features/teachers/presentation/pages/teachers_list_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// ASTRA_TEACH_STATS: Ionic validates only when creating a teacher
/// (teachers.page addTeacher); teacher.page editTeacher saves unchecked.
void main() {
  group('isTeacherFormValid - create (Ionic addTeacher)', () {
    test('rejects names shorter than 3 chars', () {
      expect(isTeacherFormValid(isNew: true, name: 'Al', instruments: [1]),
          isFalse);
    });

    test('rejects missing instruments', () {
      expect(
          isTeacherFormValid(isNew: true, name: 'Anna', instruments: const []),
          isFalse);
    });

    test('accepts name >= 3 chars with an instrument', () {
      expect(isTeacherFormValid(isNew: true, name: 'Ann', instruments: [1]),
          isTrue);
    });
  });

  group('isTeacherFormValid - edit (Ionic editTeacher)', () {
    test('saves an existing teacher without instrument', () {
      expect(
          isTeacherFormValid(isNew: false, name: 'Anna', instruments: const []),
          isTrue);
    });

    test('saves an existing teacher with a short name', () {
      expect(isTeacherFormValid(isNew: false, name: 'A', instruments: [2]),
          isTrue);
    });
  });
}
