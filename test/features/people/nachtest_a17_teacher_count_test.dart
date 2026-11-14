import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// NACHTEST-A-17 (PERSONEN-84): the teacher list counts students from
/// playersProvider; saving a person must reload it, otherwise a new teacher
/// assignment shows "0 Spieler" until the app is reloaded.
void main() {
  test('saving a person reloads playersProvider for the teacher counts', () {
    final src = File(
            'lib/features/people/presentation/pages/person_detail_page.dart')
        .readAsStringSync();
    final save = src.indexOf("'additional_fields': localAdditional");
    expect(save, isNonNegative);
    final after = src.substring(save);
    final close = after.indexOf('_closePage();');
    expect(close, isNonNegative);
    expect(after.substring(0, close), contains('ref.invalidate(playersProvider);'));
  });
}
