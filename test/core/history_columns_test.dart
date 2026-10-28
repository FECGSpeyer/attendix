import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `history` table uses the Ionic column names: `songId` (camelCase),
/// `person_id`, `otherConductor`, `visible`. `conductorName` and `count` are
/// computed client-side and must never be selected or written.
void main() {
  group('history table column names', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.dart') &&
            !f.path.endsWith('.g.dart') &&
            !f.path.endsWith('.freezed.dart'))
        .toList();

    test('no source file references the non-existent song_id column', () {
      final offenders = files
          .where((f) => f.readAsStringSync().contains("song_id"))
          .map((f) => f.path)
          .toList();
      expect(offenders, isEmpty);
    });

    test('history inserts do not write the computed conductorName column', () {
      for (final f in files) {
        final src = f.readAsStringSync();
        if (!src.contains(".from('history')")) continue;
        expect(src, isNot(contains("'conductorName': entry")),
            reason: '${f.path} writes conductorName into history');
      }
    });
  });
}
