
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/source_reader.dart';

/// P10_PEOPLE (final parity sweep): source checks for Ionic behaviour that is
/// hard to reach in widget tests.
void main() {
  String read(String path) => readDartLibrary(path);

  test('members list watches persisted list filter provider', () {
    final src = read('lib/features/people/presentation/pages/members_page.dart');
    expect(src, contains('rdMembersListFilterProvider'));
  });

  test('teachers: only admins open the edit page, add sheet without main group', () {
    final listSrc = read('lib/features/teachers/presentation/pages/teachers_page.dart');
    final sheetSrc = read('lib/features/teachers/presentation/widgets/teacher_create_sheet.dart');
    expect(listSrc, contains('onTap: isAdmin'));
    expect(sheetSrc, contains('.where((g) => g.maingroup != true'));
  });

  test('person create asks before discarding input (Ionic dismiss)', () {
    final src = read('lib/features/people/presentation/pages/person_create_page.dart');
    expect(src, contains('_confirmDiscard()'));
    expect(src, contains('context.l10n.personDiscardChanges'));
  });

  test('person actions section has header and closes after a transfer', () {
    final src = read('lib/features/people/presentation/pages/person_edit_page.dart');
    expect(src, contains('RdGroupLabel(l10n.personActions)'));
    expect(src, contains('if (!copy) {'));
    expect(src, contains('context.go(RedesignRoutes.members);'));
  });

  test('late warning card uses the Ionic texts', () {
    final src = read(
        'lib/features/people/presentation/pages/person_edit_page.dart');
    expect(src, contains('personLateWarningTitle'));
    expect(src, contains('personLateExcusedExtra'));
    expect(src, contains('personResetTalked'));
  });
}
