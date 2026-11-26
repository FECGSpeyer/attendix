import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// NACHTEST-A-17 (PERSONEN-84): the teacher list counts students from
/// playersProvider; saving a person must reload it, otherwise a new teacher
/// assignment shows "0 Spieler" until the app is reloaded.
void main() {
  test('saving a person reloads playersProvider for the teacher counts', () {
    final src = File(
            'lib/features/redesign/presentation/pages/rd_person_edit_page.dart')
        .readAsStringSync();
    expect(src, contains('invalidate(playersProvider)'));
  });
}
