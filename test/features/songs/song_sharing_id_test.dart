import 'dart:io';

import 'package:attendix/features/songs/presentation/utils/song_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('public Werke link id (EINST-60 / OEFF-38)', () {
    test('only UUIDs count as sharing ids', () {
      expect(SongUtils.isValidSharingId('00000000-0000-4000-8000-000000000000'), isTrue);
      expect(SongUtils.isValidSharingId('xyz-unbekannt'), isFalse);
      expect(SongUtils.isValidSharingId(''), isFalse);
      expect(SongUtils.isValidSharingId(null), isFalse);
    });

    test('router sends signed-in users of a non-UUID address to the start page', () {
      final src = File('lib/core/router/app_router.dart').readAsStringSync();
      final route = src.indexOf("path: '/:songSharingId',");
      expect(route, isNonNegative);
      final block = src.substring(route, src.indexOf('builder:', route));
      expect(block, contains('SongUtils.isValidSharingId'));
      expect(block, contains('homeRouteFor('));
    });
  });
}
