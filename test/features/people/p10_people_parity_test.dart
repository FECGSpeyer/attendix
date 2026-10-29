import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// P10_PEOPLE (final parity sweep): source checks for Ionic behaviour that is
/// hard to reach in widget tests.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('people list remembers the filter per tenant (Ionic filterOpt)', () {
    final src = read('lib/features/people/presentation/pages/people_list_page.dart');
    expect(src, contains("'filterOpt_\${tenant.id}'"));
    expect(src, contains("'filterOptAdd_\${tenant.id}'"));
    expect(src, contains('_restoreOtherInstanceFilter'));
  });

  test('teachers: only admins open the edit page, add sheet without main group', () {
    final src = read('lib/features/teachers/presentation/pages/teachers_list_page.dart');
    expect(src, contains('onTap: isAdmin'));
    expect(src, contains('.where((g) => g.maingroup != true)'));
  });

  test('person create asks before discarding input (Ionic dismiss)', () {
    final src = read('lib/features/people/presentation/pages/person_create_page.dart');
    expect(src, contains('onPressed: _close'));
    expect(src, contains('l10n.personDiscardChanges'));
  });

  test('person more menu has the Ionic header and closes after a transfer', () {
    final src = read('lib/features/people/presentation/pages/person_detail_page.dart');
    expect(src, contains('title: context.l10n.personActions'));
    expect(src, contains('updated.left != null)) context.pop()'));
  });

  test('late warning card uses the Ionic texts', () {
    final src = read(
        'lib/features/people/presentation/widgets/person_detail/late_warning_card.dart');
    expect(src, contains('personLateWarningTitle'));
    expect(src, contains('personLateExcusedExtra'));
    expect(src, contains('personResetTalked'));
  });
}
